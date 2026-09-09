const {contextBridge,ipcRenderer}=require('electron');
contextBridge.exposeInMainWorld('probe',{
 query: args=>ipcRenderer.invoke('query',args), cancel:()=>ipcRenderer.invoke('cancel'),
 record: data=>ipcRenderer.invoke('record',data), ready:()=>ipcRenderer.invoke('ready')
});
