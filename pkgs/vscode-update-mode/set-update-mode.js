// Set "update.mode" in a VS Code settings.json, keeping it a writable file.
// Usage: vscode-update-mode SETTINGS_FILE [MODE]
//
// settings.json is JSONC, so it is edited with jsonc-parser, the library
// VS Code itself uses: only the key changes, and comments, trailing commas
// and formatting stay. The file is not rewritten when the key already has
// the wanted value, and a file that is not a valid JSONC object is refused,
// never overwritten.
const fs = require("fs");
const path = require("path");
const jsonc = require(process.env.JSONC_PARSER);

const KEY = "update.mode";
const args = process.argv.slice(2);
if (args.length < 1 || args.length > 2) {
  console.error("usage: vscode-update-mode SETTINGS_FILE [MODE]");
  process.exit(2);
}
const [settings, mode = "none"] = args;

function fail(reason) {
  console.error(`vscode-update-mode: ${settings}: ${reason}`);
  console.error(
    `vscode-update-mode: left unchanged; set "${KEY}": "${mode}" by hand or fix the file and re-run.`,
  );
  process.exit(1);
}

// Parses JSONC as VS Code does; returns the root object or fails.
function parseObject(text, what) {
  const errors = [];
  const root = jsonc.parse(text, errors, { allowTrailingComma: true });
  if (errors.length > 0) {
    const { error, offset } = errors[0];
    fail(`${what}: ${jsonc.printParseErrorCode(error)} at offset ${offset}`);
  }
  if (root === null || typeof root !== "object" || Array.isArray(root)) {
    fail(`${what}: not a JSON object`);
  }
  return root;
}

let stat;
try {
  stat = fs.lstatSync(settings);
} catch (err) {
  if (err.code !== "ENOENT") throw err;
}

if (stat === undefined) {
  fs.mkdirSync(path.dirname(settings), { recursive: true });
  fs.writeFileSync(settings, JSON.stringify({ [KEY]: mode }, null, 2) + "\n", {
    flag: "wx",
  });
  console.log(
    `vscode-update-mode: created ${settings} with "${KEY}": "${mode}"`,
  );
  process.exit(0);
}
if (stat.isSymbolicLink()) fail("is a symlink, so something else manages it");
if (!stat.isFile()) fail("is not a regular file");

// An empty or whitespace-only file is what VS Code leaves after clearing it.
const text = fs.readFileSync(settings, "utf8");
const source = text.trim() === "" ? "{}" : text;
const before = parseObject(source, "is not a valid JSONC object");
if (before[KEY] === mode) process.exit(0);

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
  fail("edit changed more than the key");
}

const tmp = `${settings}.${process.pid}.tmp`;
try {
  fs.writeFileSync(tmp, updated, { flag: "wx", mode: stat.mode & 0o7777 });
  fs.chmodSync(tmp, stat.mode & 0o7777);
  fs.renameSync(tmp, settings);
} catch (err) {
  fs.rmSync(tmp, { force: true });
  throw err;
}
console.log(`vscode-update-mode: set "${KEY}": "${mode}" in ${settings}`);
