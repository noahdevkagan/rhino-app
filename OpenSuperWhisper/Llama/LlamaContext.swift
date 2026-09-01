//
//  LlamaContext.swift
//  Rhino
//
//  Swift wrapper over the llama.cpp C API (pinned tag b9878, 2026-07-05), mirroring
//  the structure of Whis/Whis.swift. Holds OpaquePointers for the llama_model and
//  llama_context and exposes a minimal text-generation API used by the built-in LLM
//  cleanup backend.
//
//  This file is written against the signatures declared in
//  libwhisper/llama.cpp/include/llama.h at tag b9878. The relevant declarations:
//
//    void                  llama_backend_init(void);
//    void                  llama_backend_free(void);
//    llama_model_params    llama_model_default_params(void);
//    llama_context_params  llama_context_default_params(void);
//    llama_model *         llama_model_load_from_file(const char * path_model,
//                                                     llama_model_params params);
//    void                  llama_model_free(llama_model * model);
//    llama_context *       llama_init_from_model(llama_model * model,
//                                                llama_context_params params);
//    void                  llama_free(llama_context * ctx);
//    const llama_vocab *   llama_model_get_vocab(const llama_model * model);
//    int32_t               llama_vocab_n_tokens(const llama_vocab * vocab);
//    bool                  llama_vocab_is_eog(const llama_vocab * vocab, llama_token token);
//    const char *          llama_model_chat_template(const llama_model * model, const char * name);
//    int32_t               llama_chat_apply_template(const char * tmpl,
//                                                    const llama_chat_message * chat,
//                                                    size_t n_msg, bool add_ass,
//                                                    char * buf, int32_t length);
//    int32_t               llama_tokenize(const llama_vocab * vocab, const char * text,
//                                         int32_t text_len, llama_token * tokens,
//                                         int32_t n_tokens_max, bool add_special,
//                                         bool parse_special);
//    int32_t               llama_token_to_piece(const llama_vocab * vocab, llama_token token,
//                                               char * buf, int32_t length, int32_t lstrip,
//                                               bool special);
//    llama_batch           llama_batch_get_one(llama_token * tokens, int32_t n_tokens);
//    int32_t               llama_decode(llama_context * ctx, llama_batch batch);
//    uint32_t              llama_n_ctx(const llama_context * ctx);
//    llama_memory_t        llama_get_memory(const llama_context * ctx);
//    void                  llama_memory_clear(llama_memory_t mem, bool data);
//    void                  llama_sampler_reset(llama_sampler * smpl);
//    llama_sampler_chain_params llama_sampler_chain_default_params(void);
//    llama_sampler *       llama_sampler_chain_init(llama_sampler_chain_params params);
//    void                  llama_sampler_chain_add(llama_sampler * chain, llama_sampler * smpl);
//    llama_sampler *       llama_sampler_init_greedy(void);
//    llama_sampler *       llama_sampler_init_temp(float t);
//    llama_sampler *       llama_sampler_init_top_k(int32_t k);
//    llama_sampler *       llama_sampler_init_top_p(float p, size_t min_keep);
//    llama_sampler *       llama_sampler_init_dist(uint32_t seed);
//    llama_token           llama_sampler_sample(llama_sampler * smpl, llama_context * ctx, int32_t idx);
//    void                  llama_sampler_accept(llama_sampler * smpl, llama_token token);
//    void                  llama_sampler_free(llama_sampler * smpl);
//
//  struct llama_chat_message { const char * role; const char * content; }
//
//  NOTE: the signatures above are copied verbatim from the pinned header; if the
//  submodule is bumped, re-verify them.
//

import Foundation

/// NOT thread-safe: `llama_context` holds the KV cache and must be used by one caller at a
/// time. Every access goes through `BuiltInLlamaBackend`'s serial inference queue, which is
/// also what owns this object's lifetime.
public final class LlamaContext {

    public typealias LlamaToken = Int32

    // llama_model* and llama_context* are opaque in llama.h, so they import as OpaquePointer.
    // llama_sampler is a complete struct, so it imports as UnsafeMutablePointer<llama_sampler>.
    private var model: OpaquePointer?
    private var ctx: OpaquePointer?
    private var sampler: UnsafeMutablePointer<llama_sampler>?
    private let vocab: OpaquePointer?

    /// The tokens currently resident in the context's KV cache (sequence 0), in position order.
    /// Maintained by `clearMemory` / `decodeAppending` so `generate` can keep the KV of a shared
    /// prompt prefix across calls instead of re-evaluating it: the cleanup system prompt is
    /// identical for every dictation and dominates the prompt, so dictation N+1 only pays for its
    /// own transcript tokens. `prefill` decodes that shared prefix ahead of time (during
    /// recording), making even the FIRST cleanup after a load cheap.
    private var kvTokens: [LlamaToken] = []

    // llama_backend_init() must be called once per process before loading any model.
    // Use a static token so repeated LlamaContext creations don't re-init the backend.
    private static let backendInit: Void = {
        llama_backend_init()
        return ()
    }()

    // MARK: - Initialization

    /// Loads a GGUF model from disk and creates an inference context.
    /// GPU offload is enabled (all layers) so Metal is used, matching the whisper path.
    public init?(modelPath: String, contextLength: UInt32 = 4096, gpuLayers: Int32 = 999) {
        _ = LlamaContext.backendInit

        // --- Load the model ---
        var modelParams = llama_model_default_params()
        // 999 ≈ "offload everything"; llama clamps to the model's actual layer count.
        modelParams.n_gpu_layers = gpuLayers
        modelParams.use_mmap = true

        let loadedModel = modelPath.withCString { cPath in
            llama_model_load_from_file(cPath, modelParams)
        }
        guard let loadedModel else {
            print("LlamaContext: failed to load model at \(modelPath)")
            return nil
        }
        self.model = loadedModel
        self.vocab = llama_model_get_vocab(loadedModel)

        // --- Create the context ---
        var ctxParams = llama_context_default_params()
        ctxParams.n_ctx = contextLength
        ctxParams.n_batch = contextLength
        let cpuCount = Int32(max(1, ProcessInfo.processInfo.activeProcessorCount))
        ctxParams.n_threads = cpuCount
        ctxParams.n_threads_batch = cpuCount

        guard let createdCtx = llama_init_from_model(loadedModel, ctxParams) else {
            print("LlamaContext: failed to create context")
            llama_model_free(loadedModel)
            self.model = nil
            return nil
        }
        self.ctx = createdCtx

        // --- Build a greedy (temperature-0) sampler chain ---
        // For deterministic cleanup we want greedy decoding.
        let samplerParams = llama_sampler_chain_default_params()
        guard let chain = llama_sampler_chain_init(samplerParams) else {
            print("LlamaContext: failed to init sampler chain")
            llama_free(createdCtx)
            llama_model_free(loadedModel)
            self.ctx = nil
            self.model = nil
            return nil
        }
        // Greedy = argmax. Deterministic, no temperature.
        llama_sampler_chain_add(chain, llama_sampler_init_greedy())
        self.sampler = chain
    }

    deinit {
        if let sampler { llama_sampler_free(sampler) }
        if let ctx { llama_free(ctx) }
        if let model { llama_model_free(model) }
        // We intentionally do NOT call llama_backend_free() here: ggml/Metal global
        // state is shared process-wide (and also used by whisper.cpp via the same
        // ggml). Freeing it on a single context teardown would be unsafe.
    }

    // MARK: - Chat prompt formatting

    /// Formats a system+user pair into the model's chat template. Falls back to a
    /// minimal ChatML-ish template if the model carries no built-in template.
    private func formatChatPrompt(system: String, user: String) -> String {
        guard let model else { return fallbackTemplate(system: system, user: user) }

        // Keep the C strings alive for the duration of the llama_chat_apply_template call.
        return system.withCString { sysC -> String in
            user.withCString { usrC -> String in
                let messages = [
                    llama_chat_message(role: strdup("system"), content: sysC),
                    llama_chat_message(role: strdup("user"), content: usrC),
                ]
                defer {
                    free(UnsafeMutableRawPointer(mutating: messages[0].role))
                    free(UnsafeMutableRawPointer(mutating: messages[1].role))
                }

                // Use the model's own template (tmpl == nil -> model default).
                let tmpl: UnsafePointer<CChar>? = llama_model_chat_template(model, nil)

                // First call to size the buffer, then realloc if needed.
                var bufSize = Int32((system.utf8.count + user.utf8.count) * 2 + 256)
                var buffer = [CChar](repeating: 0, count: Int(bufSize))
                var written = messages.withUnsafeBufferPointer { msgPtr in
                    llama_chat_apply_template(tmpl, msgPtr.baseAddress, msgPtr.count,
                                              true, &buffer, bufSize)
                }
                if written < 0 {
                    return fallbackTemplate(system: system, user: user)
                }
                if written > bufSize {
                    bufSize = written + 1
                    buffer = [CChar](repeating: 0, count: Int(bufSize))
                    written = messages.withUnsafeBufferPointer { msgPtr in
                        llama_chat_apply_template(tmpl, msgPtr.baseAddress, msgPtr.count,
                                                  true, &buffer, bufSize)
                    }
                    if written < 0 {
                        return fallbackTemplate(system: system, user: user)
                    }
                }
                let count = Int(min(written, bufSize))
                return String(decoding: buffer.prefix(count).map { UInt8(bitPattern: $0) },
                              as: UTF8.self)
            }
        }
    }

    /// Minimal ChatML-style fallback (Qwen2.5 uses ChatML) if no template is available.
    private func fallbackTemplate(system: String, user: String) -> String {
        return """
        <|im_start|>system
        \(system)<|im_end|>
        <|im_start|>user
        \(user)<|im_end|>
        <|im_start|>assistant

        """
    }

    // MARK: - Tokenization helpers

    private func tokenize(_ text: String, addSpecial: Bool) -> [LlamaToken] {
        guard let vocab else { return [] }
        let utf8Count = Int32(text.utf8.count)
        // Upper bound: one token per byte + a couple for specials.
        let maxTokens = utf8Count + 8
        var tokens = [LlamaToken](repeating: 0, count: Int(maxTokens))

        let n = text.withCString { cText -> Int32 in
            llama_tokenize(vocab, cText, utf8Count, &tokens, maxTokens,
                           addSpecial, /* parse_special */ true)
        }
        if n < 0 {
            // Negative return = required count; resize and retry.
            let needed = -n
            tokens = [LlamaToken](repeating: 0, count: Int(needed))
            let n2 = text.withCString { cText -> Int32 in
                llama_tokenize(vocab, cText, utf8Count, &tokens, needed,
                               addSpecial, true)
            }
            guard n2 > 0 else { return [] }
            return Array(tokens.prefix(Int(n2)))
        }
        return Array(tokens.prefix(Int(n)))
    }

    /// Raw UTF-8 bytes of a token's piece. Deliberately NOT decoded per token: a BPE token can end
    /// mid-character (accented text, CJK, emoji), so decoding each piece on its own turns the split
    /// character into U+FFFD. Callers accumulate the bytes and decode the whole run once.
    private func pieceBytes(for token: LlamaToken) -> [UInt8] {
        guard let vocab else { return [] }
        var buf = [CChar](repeating: 0, count: 128)
        let n = llama_token_to_piece(vocab, token, &buf, Int32(buf.count), 0, /* special */ false)
        if n < 0 {
            buf = [CChar](repeating: 0, count: Int(-n))
            let n2 = llama_token_to_piece(vocab, token, &buf, Int32(buf.count), 0, false)
            guard n2 > 0 else { return [] }
            return buf.prefix(Int(n2)).map { UInt8(bitPattern: $0) }
        }
        guard n > 0 else { return [] }
        return buf.prefix(Int(n)).map { UInt8(bitPattern: $0) }
    }

    private func isEndOfGeneration(_ token: LlamaToken) -> Bool {
        guard let vocab else { return true }
        return llama_vocab_is_eog(vocab, token)
    }

    // MARK: - KV-cache bookkeeping

    /// Empties the KV cache (and the mirror of what it holds).
    private func clearMemory() {
        guard let ctx else { return }
        llama_memory_clear(llama_get_memory(ctx), true)
        kvTokens.removeAll()
    }

    /// Rewinds the KV cache to its first `keep` tokens so the next decode continues from there
    /// (`llama_batch_get_one` carries no positions; llama continues from the sequence's max
    /// position). Falls back to a full clear if the backend can't do a partial removal.
    /// Returns the number of tokens actually kept.
    private func rewindMemory(keepingFirst keep: Int) -> Int {
        guard let ctx else { return 0 }
        guard keep > 0 else {
            clearMemory()
            return 0
        }
        if keep >= kvTokens.count { return kvTokens.count }
        if llama_memory_seq_rm(llama_get_memory(ctx), 0, llama_pos(keep), -1) {
            kvTokens.removeLast(kvTokens.count - keep)
            return keep
        }
        clearMemory()
        return 0
    }

    /// Decodes `tokens` as one batch appended to the current KV contents. On success the KV
    /// mirror grows by exactly these tokens.
    private func decodeAppending(_ tokens: [LlamaToken]) -> Bool {
        if tokens.isEmpty { return true }
        guard let ctx else { return false }
        var batchTokens = tokens
        let ok = batchTokens.withUnsafeMutableBufferPointer { buf -> Bool in
            let batch = llama_batch_get_one(buf.baseAddress, Int32(buf.count))
            return llama_decode(ctx, batch) == 0
        }
        if ok { kvTokens.append(contentsOf: tokens) }
        return ok
    }

    /// Length of the shared leading run of two token sequences.
    private static func commonPrefixLength(_ a: [LlamaToken], _ b: [LlamaToken]) -> Int {
        var n = 0
        while n < a.count && n < b.count && a[n] == b[n] { n += 1 }
        return n
    }

    // MARK: - Generation

    /// Decodes the prompt prefix shared by every completion with this system prompt — the chat
    /// template applied to (system, user) up to where the user text diverges, computed from two
    /// sentinel user variants — so a later `generate` only evaluates the tokens after it (the
    /// transcript). Called from the recording flow while the user is still speaking; a no-op when
    /// the prefix is already resident. Correctness never depends on this: `generate` re-checks
    /// token-for-token what is in the KV cache and re-decodes anything that doesn't match.
    public func prefill(system: String, userVariantA: String, userVariantB: String) {
        let a = formatChatPrompt(system: system, user: userVariantA)
        let b = formatChatPrompt(system: system, user: userVariantB)
        let prefix = a.commonPrefix(with: b)
        guard !prefix.isEmpty else { return }

        let prefixTokens = tokenize(prefix, addSpecial: true)
        guard !prefixTokens.isEmpty, let ctx, prefixTokens.count < Int(llama_n_ctx(ctx)) else { return }

        let shared = Self.commonPrefixLength(kvTokens, prefixTokens)
        if shared == prefixTokens.count { return }  // already resident (possibly with more after it)
        let kept = rewindMemory(keepingFirst: shared)
        if !decodeAppending(Array(prefixTokens[kept...])) {
            // Leave a clean slate rather than a half-decoded mirror; generate will start over.
            clearMemory()
        }
    }

    /// Runs a single-shot chat completion: formats the prompt, decodes the prompt
    /// tokens, then greedily samples up to `maxTokens` tokens, stopping at EOG.
    ///
    /// The KV cache is NOT unconditionally cleared between calls. Positions matter
    /// (`llama_batch_get_one` continues from wherever the sequence ends), so the cache is instead
    /// rewound to the longest token-for-token prefix it shares with this call's prompt and only
    /// the rest is decoded. For back-to-back cleanups that prefix is the entire system prompt +
    /// user-wrapper preamble (`prefill` puts it there even for the first call), which is what
    /// makes warm cleanup fast; for an unrelated prompt the shared run is 0 and this degrades to
    /// exactly the old clear-and-decode-everything behavior. Earlier dictations can never leak
    /// in: whatever doesn't match this prompt's tokens is removed before decoding. The sampler
    /// is still reset every call — its accepted-token history belongs to the previous generation.
    public func generate(system: String, user: String, maxTokens: Int = 512) -> String {
        guard let ctx, let sampler else { return "" }

        llama_sampler_reset(sampler)

        let prompt = formatChatPrompt(system: system, user: user)
        var promptTokens = tokenize(prompt, addSpecial: true)
        guard !promptTokens.isEmpty else { return "" }

        let nCtx = Int(llama_n_ctx(ctx))
        if promptTokens.count >= nCtx {
            // Truncate the prompt if it doesn't fit; leave room for the response. A truncated
            // prompt's tokens don't line up with any cached prefix, so start clean.
            promptTokens = Array(promptTokens.suffix(nCtx - 1))
            clearMemory()
        }

        // Keep at most promptTokens.count - 1 cached tokens: the final prompt token must be
        // decoded by THIS call so the logits the first sampling step reads are its own.
        let shared = min(Self.commonPrefixLength(kvTokens, promptTokens), promptTokens.count - 1)
        let kept = rewindMemory(keepingFirst: shared)

        var outputBytes: [UInt8] = []
        guard decodeAppending(Array(promptTokens[kept...])) else {
            clearMemory()
            return ""
        }

        var generated = 0
        let budget = min(maxTokens, max(0, nCtx - promptTokens.count))
        while generated < budget {
            // Sample the next token from the logits of the last decoded position.
            let nextToken = llama_sampler_sample(sampler, ctx, -1)

            if isEndOfGeneration(nextToken) { break }

            llama_sampler_accept(sampler, nextToken)
            outputBytes.append(contentsOf: pieceBytes(for: nextToken))

            // Feed the sampled token back in for the next step.
            if !decodeAppending([nextToken]) { break }

            generated += 1
        }

        // One decode over the whole byte run, so multi-byte characters that straddled two tokens
        // survive intact.
        return String(decoding: outputBytes, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
