'use strict';

const { app, BrowserWindow, ipcMain, shell } = require('electron');
const os = require('os');
const path = require('path');

const OWNER_NAME = 'إلياس بن عثمان العثمان';
const PRODUCT_NAME = 'كمبيوتر الهجدة';
const APP_USER_MODEL_ID = 'com.elyasalothman.kamputeralhajda';

app.setName(PRODUCT_NAME);
if (process.platform === 'win32') {
  app.setAppUserModelId(APP_USER_MODEL_ID);
}

function createWindow() {
  const win = new BrowserWindow({
    width: 1024,
    height: 720,
    minWidth: 820,
    minHeight: 560,
    backgroundColor: '#0b1020',
    title: PRODUCT_NAME,
    show: false,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: false
    }
  });

  win.removeMenu();
  win.loadFile(path.join(__dirname, '..', 'renderer', 'index.html'));

  win.once('ready-to-show', () => win.show());

  win.webContents.setWindowOpenHandler(({ url }) => {
    shell.openExternal(url);
    return { action: 'deny' };
  });
}

function collectSystemInfo() {
  const totalGib = os.totalmem() / 1024 ** 3;
  const freeGib = os.freemem() / 1024 ** 3;
  const cpus = os.cpus();
  return {
    owner: OWNER_NAME,
    appVersion: app.getVersion(),
    electron: process.versions.electron,
    chrome: process.versions.chrome,
    node: process.versions.node,
    platform: `${os.type()} ${os.release()}`,
    arch: os.arch(),
    hostname: os.hostname(),
    cpuModel: cpus.length ? cpus[0].model.trim() : 'غير معروف',
    cpuCount: cpus.length,
    totalMemGib: Number(totalGib.toFixed(2)),
    freeMemGib: Number(freeGib.toFixed(2)),
    uptimeSeconds: Math.floor(os.uptime())
  };
}

ipcMain.handle('system:info', () => collectSystemInfo());

app.whenReady().then(() => {
  createWindow();
  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});
