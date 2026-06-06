const { contextBridge, ipcRenderer } = require('electron');
contextBridge.exposeInMainWorld('electronAPI', {
  send: (channel, data) => ipcRenderer.send(channel, data),
  on: (channel, func) => ipcRenderer.on(channel, (event, ...args) => func(...args)),
  listSerialPorts: async () => {
    try {
      const { SerialPort } = require('serialport');
      return await SerialPort.list();
    } catch (error) {
      console.error("SerialPort not available:", error);
      return [];
    }
  }
});
