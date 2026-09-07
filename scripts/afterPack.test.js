'use strict';

const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const afterPack = require('./afterPack');

async function withDir(fn) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'kamputer-pack-'));
  try {
    await fn(dir);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

async function main() {
  await withDir(async (dir) => {
    fs.writeFileSync(path.join(dir, 'electron.exe'), 'electron-bin');
    await afterPack({ appOutDir: dir });
    assert.ok(fs.existsSync(path.join(dir, 'Kamputer-Alhajda.exe')), 'renames leftover electron.exe');
    assert.ok(!fs.existsSync(path.join(dir, 'electron.exe')), 'removes electron.exe');
  });

  await withDir(async (dir) => {
    fs.writeFileSync(path.join(dir, 'Kamputer-Alhajda.exe'), 'app-bin');
    await afterPack({ appOutDir: dir });
    assert.ok(fs.existsSync(path.join(dir, 'Kamputer-Alhajda.exe')));
    assert.ok(!fs.existsSync(path.join(dir, 'electron.exe')));
  });

  await withDir(async (dir) => {
    fs.writeFileSync(path.join(dir, 'Kamputer-Alhajda.exe'), 'app-bin');
    fs.writeFileSync(path.join(dir, 'electron.exe'), 'leftover');
    await assert.rejects(() => afterPack({ appOutDir: dir }), /electron\.exe must not remain/);
  });

  const pkg = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'package.json'), 'utf8'));
  assert.strictEqual(pkg.build.productName, 'كمبيوتر الهجدة');
  assert.strictEqual(pkg.build.executableName, 'Kamputer-Alhajda');
  assert.notStrictEqual(pkg.build.executableName.toLowerCase(), 'electron');

  const start = fs.readFileSync(path.join(__dirname, '..', 'START.bat'), 'utf8');
  assert.match(start, /Kamputer-Alhajda\.exe/);
  assert.doesNotMatch(start, /start\s+.*electron\.exe/i);

  const shortcut = fs.readFileSync(path.join(__dirname, '..', 'put-shortcut.ps1'), 'utf8');
  assert.match(shortcut, /Kamputer-Alhajda\.exe/);
  assert.doesNotMatch(shortcut, /TargetPath\s*=\s*.*electron\.exe/i);

  console.log('afterPack + packaging names: ok');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
