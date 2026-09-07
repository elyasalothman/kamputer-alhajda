'use strict';

const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('kamputer', {
  getSystemInfo: () => ipcRenderer.invoke('system:info')
});
