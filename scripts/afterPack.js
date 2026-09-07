'use strict';

const fs = require('fs');
const path = require('path');

const EXE = 'Kamputer-Alhajda.exe';

/**
 * electron-builder should already emit Kamputer-Alhajda.exe via executableName.
 * If a pack still leaves electron.exe as the launcher, rename it so Task Manager
 * / shortcuts never show «Electron».
 */
module.exports = async function afterPack(context) {
  const dir = context.appOutDir;
  const wanted = path.join(dir, EXE);
  const leftover = path.join(dir, 'electron.exe');

  if (fs.existsSync(leftover) && !fs.existsSync(wanted)) {
    fs.renameSync(leftover, wanted);
  }

  if (!fs.existsSync(wanted)) {
    throw new Error(`afterPack: ${EXE} missing in ${dir}`);
  }
  if (fs.existsSync(leftover)) {
    throw new Error(`afterPack: electron.exe must not remain as a user-facing launcher in ${dir}`);
  }
};
