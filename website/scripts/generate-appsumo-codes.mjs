import { createHash, randomBytes } from "node:crypto";
import { access, mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { pathToFileURL } from "node:url";

const ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const DEFAULT_COUNT = 10_000;

function randomGroup(length = 4) {
  const bytes = randomBytes(length);
  let group = "";

  for (const byte of bytes) {
    group += ALPHABET[byte & 31];
  }

  return group;
}

export function generateCode() {
  return `RH-${randomGroup()}-${randomGroup()}-${randomGroup()}`;
}

export function generateCodeBatch(count = DEFAULT_COUNT, existingHashes = new Set()) {
  const codes = new Set();
  const seenHashes = new Set(existingHashes);

  while (codes.size < count) {
    const code = generateCode();
    const hash = hashCode(code);

    if (seenHashes.has(hash)) continue;

    seenHashes.add(hash);
    codes.add(code);
  }

  return [...codes];
}

export function hashCode(code) {
  return createHash("sha256").update(code).digest("hex");
}

async function assertDoesNotExist(path) {
  try {
    await access(path);
  } catch {
    return;
  }

  throw new Error(`${path} already exists; pass --force to replace this batch`);
}

function parseArguments(args) {
  const options = {
    count: DEFAULT_COUNT,
    codes: resolve("../.context/rhino-appsumo-codes.csv"),
    hashes: resolve("public/appsumo-hashes.json"),
    force: false,
    append: false,
  };

  for (let index = 0; index < args.length; index += 1) {
    const argument = args[index];

    if (argument === "--force") {
      options.force = true;
    } else if (argument === "--append") {
      options.append = true;
    } else if (argument === "--count") {
      options.count = Number.parseInt(args[++index] ?? "", 10);
    } else if (argument === "--codes") {
      options.codes = resolve(args[++index] ?? "");
    } else if (argument === "--hashes") {
      options.hashes = resolve(args[++index] ?? "");
    } else {
      throw new Error(`Unknown argument: ${argument}`);
    }
  }

  if (!Number.isSafeInteger(options.count) || options.count < 1) {
    throw new Error("--count must be a positive integer");
  }

  return options;
}

async function main() {
  const options = parseArguments(process.argv.slice(2));

  if (!options.force) {
    const checks = [assertDoesNotExist(options.codes)];
    if (!options.append) checks.push(assertDoesNotExist(options.hashes));
    await Promise.all(checks);
  }

  const existingHashes = options.append
    ? JSON.parse(await readFile(options.hashes, "utf8"))
    : [];
  const codes = generateCodeBatch(options.count, new Set(existingHashes));
  const hashes = [...existingHashes, ...codes.map(hashCode)].sort();

  await Promise.all([
    mkdir(dirname(options.codes), { recursive: true }),
    mkdir(dirname(options.hashes), { recursive: true }),
  ]);
  await Promise.all([
    writeFile(options.codes, `${codes.join("\n")}\n`, { mode: 0o600 }),
    writeFile(options.hashes, `${JSON.stringify(hashes)}\n`),
  ]);

  process.stdout.write(
    `Created ${codes.length} codes in ${options.codes}\n` +
      `Published ${hashes.length} SHA-256 hashes in ${options.hashes}\n`,
  );
}

const isMain =
  process.argv[1] &&
  pathToFileURL(resolve(process.argv[1])).href === import.meta.url;

if (isMain) {
  main().catch((error) => {
    process.stderr.write(`${error.message}\n`);
    process.exitCode = 1;
  });
}
