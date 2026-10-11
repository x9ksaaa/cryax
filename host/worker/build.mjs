import { mkdirSync, readFileSync, writeFileSync, existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import { desugarLuau } from "./desugar.mjs";

const workerDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(workerDir, "..", "..");
const names = ["cryax.lua", "cryax src.lua", "cryax src.txt"];

let srcPath = join(repoRoot, "cryax src.lua");
for (const name of names) {
  const candidate = join(repoRoot, name);
  if (existsSync(candidate)) {
    srcPath = candidate;
    break;
  }
}
if (!existsSync(srcPath)) {
  throw new Error(`client script missing: ${srcPath}`);
}

function desugar(text) {
  const py = spawnSync(
    "python3",
    [
      "-c",
      "import sys; sys.path.insert(0, sys.argv[1]); from cryax_host.luau_compat import desugar_luau; sys.stdout.write(desugar_luau(sys.stdin.read()))",
      join(repoRoot, "host"),
    ],
    { input: text, encoding: "utf8", maxBuffer: 32 * 1024 * 1024 },
  );
  if (py.status === 0 && py.stdout && py.stdout.includes("SCRIPT_VERSION")) {
    return py.stdout;
  }
  return desugarLuau(text);
}

const outDir = join(workerDir, "src");
mkdirSync(outDir, { recursive: true });
const outPath = join(outDir, "script.generated.js");
const text = desugar(readFileSync(srcPath, "utf8"));
writeFileSync(outPath, "export const CLIENT_SCRIPT = " + JSON.stringify(text) + ";\n", "utf8");
console.log(`wrote ${outPath}`);
