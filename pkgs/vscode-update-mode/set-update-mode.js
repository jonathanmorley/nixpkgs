// Set "update.mode" in a VS Code settings.json, keeping it a writable file.
// Usage: vscode-update-mode [--strict] SETTINGS_FILE [MODE]
//
// settings.json is JSONC, so it is edited with jsonc-parser, the library
// VS Code itself uses: only the key changes, and comments, trailing commas
// and formatting stay. The file is not rewritten when the key already has
// the wanted value. A file that is not a valid JSONC object, a symlink, or a
// file another program changes meanwhile is left alone.
//
// This runs during Home Manager activation, so by default a file it cannot
// update only prints a warning and exits 0; --strict makes that exit 1.
const fs = require("fs");
const path = require("path");
const jsonc = require(process.env.JSONC_PARSER);

const KEY = "update.mode";
const args = process.argv.slice(2);
const strict = args[0] === "--strict";
if (strict) args.shift();
if (
  args.length < 1 ||
  args.length > 2 ||
  args.some((a) => a.startsWith("--"))
) {
  console.error("usage: vscode-update-mode [--strict] SETTINGS_FILE [MODE]");
  process.exit(2);
}
const [settings, mode = "none"] = args;

class Skip extends Error {}

function skip(reason) {
  throw new Skip(reason);
}

// Parses JSONC as VS Code does; returns the root object or skips.
function parseObject(text, what) {
  const errors = [];
  const root = jsonc.parse(text, errors, { allowTrailingComma: true });
  if (errors.length > 0) {
    const { error, offset } = errors[0];
    skip(`${what}: ${jsonc.printParseErrorCode(error)} at offset ${offset}`);
  }
  if (root === null || typeof root !== "object" || Array.isArray(root)) {
    skip(`${what}: not a JSON object`);
  }
  return root;
}

function create() {
  fs.mkdirSync(path.dirname(settings), { recursive: true });
  // wx: if VS Code created the file meanwhile, fail rather than replace it.
  fs.writeFileSync(settings, JSON.stringify({ [KEY]: mode }, null, 2) + "\n", {
    flag: "wx",
  });
  return `created ${settings} with "${KEY}": "${mode}"`;
}

function update(stat) {
  if (stat.isSymbolicLink()) skip("is a symlink, so something else manages it");
  if (!stat.isFile()) skip("is not a regular file");

  // An empty or whitespace-only file is what VS Code leaves after clearing it.
  const text = fs.readFileSync(settings, "utf8");
  const source = text.trim() === "" ? "{}" : text;
  const before = parseObject(source, "is not a valid JSONC object");
  if (before[KEY] === mode) return null;

  const indent = /^\t/m.test(source)
    ? { insertSpaces: false, tabSize: 1 }
    : { insertSpaces: true, tabSize: 2 };
  const edits = jsonc.modify(source, [KEY], mode, {
    formattingOptions: {
      ...indent,
      eol: source.includes("\r\n") ? "\r\n" : "\n",
    },
    getInsertionIndex: () => 0,
  });
  const updated = jsonc.applyEdits(source, edits);

  // Check the edit changed only the key before replacing the file.
  const after = parseObject(updated, "edit produced invalid JSONC");
  delete before[KEY];
  const { [KEY]: written, ...rest } = after;
  if (written !== mode || JSON.stringify(rest) !== JSON.stringify(before)) {
    skip("edit changed more than the key");
  }

  const tmp = `${settings}.${process.pid}.tmp`;
  try {
    const fd = fs.openSync(tmp, "wx", stat.mode & 0o7777);
    try {
      fs.writeFileSync(fd, updated);
      fs.fsyncSync(fd);
    } finally {
      fs.closeSync(fd);
    }
    fs.chmodSync(tmp, stat.mode & 0o7777);
    // VS Code may have saved the file since it was read; its write wins.
    const now = fs.lstatSync(settings);
    if (
      now.ino !== stat.ino ||
      now.size !== stat.size ||
      now.mtimeMs !== stat.mtimeMs
    ) {
      skip("changed while it was being updated");
    }
    fs.renameSync(tmp, settings);
  } finally {
    fs.rmSync(tmp, { force: true });
  }
  return `set "${KEY}": "${mode}" in ${settings}`;
}

try {
  let stat;
  try {
    stat = fs.lstatSync(settings);
  } catch (err) {
    if (err.code !== "ENOENT") throw err;
  }
  const done = stat === undefined ? create() : update(stat);
  if (done) console.log(`vscode-update-mode: ${done}`);
} catch (err) {
  const reason = err instanceof Skip ? err.message : String(err);
  console.error(`vscode-update-mode: warning: ${settings}: ${reason}`);
  console.error(
    `vscode-update-mode: warning: left unchanged; set "${KEY}": "${mode}" by hand to stop VS Code's own updates.`,
  );
  process.exit(strict ? 1 : 0);
}
