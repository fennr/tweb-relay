// Merge the Vite build output (dist/) into the static public/ tree.
//
// tweb sets `copyPublicDir: false` and its own build.js copies dist/ over
// public/ and then deletes bundles left over from previous builds. This does the
// same, without running the upstream test/typecheck pipeline.

import fs from 'node:fs';
import path from 'node:path';
import {createRequire} from 'node:module';

const require = createRequire(import.meta.url);
const keepAsset = require(path.resolve('keepAsset.js'));

const publicDir = 'public';
const distDir = 'dist';

if (!fs.existsSync(distDir)) {
  throw new Error('dist/ is missing — run `pnpm exec vite build` first');
}

const fresh = new Set(fs.readdirSync(distDir));
let removed = 0;

for (const entry of fs.readdirSync(publicDir, {withFileTypes: true})) {
  if (entry.isDirectory()) continue;
  if (fresh.has(entry.name) || keepAsset(entry.name)) continue;
  fs.rmSync(path.join(publicDir, entry.name));
  removed++;
}

function overlay(from, to) {
  for (const entry of fs.readdirSync(from, {withFileTypes: true})) {
    const source = path.join(from, entry.name);
    const target = path.join(to, entry.name);

    if (entry.isFile()) {
      fs.copyFileSync(source, target);
    } else {
      fs.mkdirSync(target, {recursive: true});
      overlay(source, target);
    }
  }
}

overlay(distDir, publicDir);

const index = fs.readFileSync(path.join(publicDir, 'index.html'), 'utf8');
if (!index.includes('./index-')) {
  throw new Error('public/index.html was not replaced by the build output');
}

console.log(`assembled public/ (removed ${removed} stale files)`);
