#!/usr/bin/env node
/*
 * Reads a JavaScript literal (array/object) on stdin and prints it as JSON.
 *
 * TFT Academy ships its comp list inside the SvelteKit boot script as a plain JS
 * literal (unquoted keys, `void 0`, …), which json.loads cannot read. Evaluating it
 * in a throw-away vm context is the cheapest correct parser.
 */
const vm = require("vm");

let source = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => { source += chunk; });
process.stdin.on("end", () => {
  try {
    const value = vm.runInNewContext("(" + source + ")", Object.create(null), { timeout: 15000 });
    process.stdout.write(JSON.stringify(value));
  } catch (error) {
    process.stderr.write(String((error && error.message) || error));
    process.exit(1);
  }
});
