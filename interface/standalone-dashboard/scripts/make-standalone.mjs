import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const indexPath = join(process.cwd(), "dist", "index.html");
const html = readFileSync(indexPath, "utf8");

const standaloneHtml = html
  .replace(/<script type="module" crossorigin src="(\.\/assets\/[^"]+\.js)"><\/script>/g, '<script defer src="$1"></script>')
  .replace(/<link rel="stylesheet" crossorigin href="(\.\/assets\/[^"]+\.css)">/g, '<link rel="stylesheet" href="$1">');

writeFileSync(indexPath, standaloneHtml, "utf8");
