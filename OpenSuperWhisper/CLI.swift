import AppKit
import Foundation

/// Headless command-line transcription (#150). Reached from the app's entry point when the first
/// argument is `transcribe`, so it reuses the exact same engines as the GUI without a second target.
///
///   Rhino transcribe <audio-file> [--json]
///
/// Uses whatever engine/model is configured in the app. Prints the transcription to stdout (plain
/// text, or a JSON object with `--json`) and exits — no dock icon, no menu bar, no windows.
enum CLI {
    static let usage = """
    Rhino — command-line transcription

    Usage:
      Rhino transcribe <audio-file> [--json]
      Rhino bench <dir-of-wavs>
      Rhino cleanup <text> [--repeat <n>]
      Rhino cleanup --stdin

    Options:
      --json       Print a JSON object ({ "file", "text" }) instead of plain text.
      --repeat n   (cleanup) Run the pass n times in one process, timing each run on stderr —
                   run 1 includes the model load; later runs show warm in-process latency.
      --stdin      (cleanup) Clean each line of stdin in order in ONE process — consecutive
                   dictations sharing the loaded model exactly like the app — and print a JSON
                   array of { "input", "text", "ms" }.
      -h, --help   Show this help.

    `bench` loads the configured model once and transcribes every .wav in the directory, printing a
    JSON array of { "file", "ms" (transcription time), "text", "stages" } — used to benchmark
    engines ("stages" breaks the time into load/inference/postprocess, FluidAudio engine only).

    `cleanup` skips audio entirely and runs the app's LLM cleanup pass (honoring its settings,
    including smart formatting and spoken edits) over the given text — for testing cleanup
    without recording.

    All use the engine and settings configured in the app. Set up a model in the app first.
    """

    /// Returns true if these arguments are a CLI invocation (and the GUI should not launch).
    static func shouldHandle(_ args: [String]) -> Bool {
        guard args.count >= 2 else { return false }
        return ["transcribe", "bench", "cleanup", "--help", "-h"].contains(args[1])
    }

    static func run(_ args: [String]) -> Never {
        if args.count >= 2, args[1] == "--help" || args[1] == "-h" {
            print(usage); exit(0)
        }
        let mode = args[1]
        guard ["transcribe", "bench", "cleanup"].contains(mode), args.count >= 3 else {
            fail(usage, code: 2)
        }
        let json = args.dropFirst(3).contains("--json")

        // The engines + FluidAudio's logger print to stdout. Keep stdout clean & pipeable by
        // redirecting it to stderr, and writing only the final result to the real stdout.
        let realStdout = dup(STDOUT_FILENO)
        resultOut = FileHandle(fileDescriptor: realStdout, closeOnDealloc: false)
        dup2(STDERR_FILENO, STDOUT_FILENO)

        // No dock icon / activation for a CLI run.
        NSApplication.shared.setActivationPolicy(.prohibited)

        if mode == "cleanup" {
            // No ASR engine involved: run the post-transcription cleanup pass alone. `process`
            // silently passes text through when it can't run, which is right for dictation but
            // misleading in a test command — surface those cases on stderr.
            // --stdin: clean every line of stdin sequentially in one process. This is the
            // app's real usage pattern — dictation after dictation against one loaded model
            // (and, with prefix caching, one KV cache) — so it's the mode parity/regression
            // harnesses use to prove consecutive cleanups can't contaminate each other.
            if args[2] == "--stdin" {
                let lines = (String(data: FileHandle.standardInput.readDataToEndOfFile(),
                                    encoding: .utf8) ?? "")
                    .split(separator: "\n", omittingEmptySubsequences: true)
                    .map(String.init)
                Task { @MainActor in
                    if !AppPreferences.shared.aiPostProcessingEnabled {
                        warn("note: LLM cleanup is off in settings — text passes through unchanged")
                    } else if !BuiltInLlamaBackend.shared.isReady {
                        warn("note: built-in model not downloaded — text passes through unchanged")
                    }
                    var rows: [[String: Any]] = []
                    for line in lines {
                        let start = CFAbsoluteTimeGetCurrent()
                        let cleaned = await LLMPostProcessor.process(line)
                        let ms = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
                        warn("cleanup line \(rows.count + 1)/\(lines.count): \(ms)ms")
                        rows.append(["input": line, "text": cleaned, "ms": ms])
                    }
                    let data = (try? JSONSerialization.data(
                        withJSONObject: rows, options: [.sortedKeys])) ?? Data()
                    resultOut.write(data)
                    resultOut.write(Data("\n".utf8))
                    exit(0)
                }
                dispatchMain()
            }

            let input = args[2]
            // --repeat N: run the pass N times in one process. Run 1 pays the context load;
            // later runs measure warm latency (and, with prompt prefill, the KV-reuse path) —
            // the number a mid-session dictation actually sees.
            var repeats = 1
            if let flagIndex = args.firstIndex(of: "--repeat"), args.indices.contains(flagIndex + 1),
               let n = Int(args[flagIndex + 1]) {
                repeats = max(1, n)
            }
            Task { @MainActor in
                if !AppPreferences.shared.aiPostProcessingEnabled {
                    warn("note: LLM cleanup is off in settings — text passes through unchanged")
                } else if !BuiltInLlamaBackend.shared.isReady {
                    warn("note: built-in model not downloaded — text passes through unchanged")
                }
                var result = ""
                for run in 1...repeats {
                    let start = CFAbsoluteTimeGetCurrent()
                    result = await LLMPostProcessor.process(input)
                    let ms = (CFAbsoluteTimeGetCurrent() - start) * 1000
                    warn(String(format: "cleanup run %d/%d: %.0fms", run, repeats, ms))
                }
                emit(result, file: "-", json: json)
                exit(0)
            }
            dispatchMain()
        }

        let target = URL(fileURLWithPath: (args[2] as NSString).expandingTildeInPath)
        guard FileManager.default.fileExists(atPath: target.path) else {
            fail("error: not found: \(target.path)")
        }

        Task { @MainActor in
            let service = TranscriptionService.shared
            // Wait for the configured engine to finish loading (model load can take a moment).
            var waited = 0.0
            while service.isLoading && waited < 120 {
                try? await Task.sleep(nanoseconds: 100_000_000)
                waited += 0.1
            }
            if let engineError = service.engineError {
                fail("error: \(engineError)\n(set up a model in the app first)")
            }
            if mode == "transcribe" {
                do {
                    // Same post pipeline as a real dictation (filler removal +
                    // AI cleanup, honoring the app's settings) — so the corpus
                    // benchmark measures what users actually get, not raw ASR.
                    var text = try await service.transcribeAudio(url: target, settings: Settings())
                    text = AppPreferences.shared.cleanTranscription(text)
                    text = await LLMPostProcessor.process(text)
                    emit(text, file: target.path, json: json)
                    exit(0)
                } catch {
                    fail("error: \(error.localizedDescription)")
                }
            } else {
                await runBench(dir: target, service: service)
                exit(0)
            }
        }
        // Keep the process alive on the main dispatch queue (where the @MainActor task runs) until
        // the task calls exit(). dispatchMain() never returns, satisfying the -> Never contract.
        dispatchMain()
    }

    /// Transcribe every .wav in `dir` with the already-loaded engine, timing each transcription.
    /// Prints a JSON array of { file, ms, text } — the model is loaded once, so timings reflect
    /// steady-state transcription speed (not per-run model load).
    @MainActor
    private static func runBench(dir: URL, service: TranscriptionService) async {
        let files = ((try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension.lowercased() == "wav" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        var results: [[String: Any]] = []
        for file in files {
            let start = CFAbsoluteTimeGetCurrent()
            let text = (try? await service.transcribeAudio(url: file, settings: Settings())) ?? ""
            let ms = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            var row: [String: Any] = [
                "file": file.lastPathComponent, "ms": ms,
                "text": text.trimmingCharacters(in: .whitespacesAndNewlines),
            ]
            // Per-stage breakdown (FluidAudio engine only) so a bench run shows WHERE the
            // time went, not just the total — see TranscriptionStageTimings.
            if let stages = service.lastStageTimings {
                row["stages"] = stages.asJSON
            }
            results.append(row)
        }
        let data = (try? JSONSerialization.data(withJSONObject: results, options: [.sortedKeys])) ?? Data()
        resultOut.write(data)
        resultOut.write(Data("\n".utf8))
    }

    /// The real stdout (engine/library logs are redirected away from it during a run).
    private static var resultOut = FileHandle.standardOutput

    private static func emit(_ text: String, file: String, json: Bool) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let out: Data
        if json {
            out = (try? JSONSerialization.data(
                withJSONObject: ["file": file, "text": trimmed],
                options: [.prettyPrinted, .sortedKeys])) ?? Data()
        } else {
            out = Data(trimmed.utf8)
        }
        resultOut.write(out)
        resultOut.write(Data("\n".utf8))
    }

    private static func warn(_ message: String) {
        FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
    }

    private static func fail(_ message: String, code: Int32 = 1) -> Never {
        FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
        exit(code)
    }
}
