// Disposable comparison. Fixed synthetic files, no arbitrary renderer filesystem API.
const {app, BrowserWindow, ipcMain, Menu} = require('electron');
const {spawn} = require('node:child_process');
const path = require('node:path');
const fs = require('node:fs');
const root = path.resolve(__dirname, '../..');
let worker = null;
app.setName('Quelyt Electron Probe');
ipcMain.handle('query', async (_, {sql, format}) => {
  if(worker || !['csv','parquet'].includes(format) || typeof sql !== 'string' || sql.length>32000) throw Error('Busy or invalid query');
  return new Promise((resolve,reject) => {
    const p=spawn(path.join(root,'.venv/bin/python'),['-I','-B',path.join(root,'src/quelyt/worker.py')],{env:{PATH:'/usr/bin:/bin'},stdio:['pipe','pipe','ignore']});
    worker=p; let chunks=[],size=0;
    const deadline=setTimeout(()=>p.kill('SIGKILL'),30000);
    p.stdout.on('data', b=>{size+=b.length;if(size>2*1024*1024){p.kill('SIGKILL');return;}chunks.push(b);});
    p.on('error',e=>{clearTimeout(deadline);worker=null;reject(e);});
    p.on('close',()=>{clearTimeout(deadline);worker=null;try{resolve(JSON.parse(Buffer.concat(chunks).toString()));}catch{reject(Error('Cancelled or worker exited'));}});
    p.stdin.on('error',()=>{});
    p.stdin.end(JSON.stringify({path:path.join(root,`experiments/discovery/data/sales.${format}`),sql,timeout_seconds:15}));
  });
});
ipcMain.handle('cancel',()=>worker?.kill('SIGKILL'));
ipcMain.handle('record',(_,data)=>fs.writeFileSync(path.join(__dirname,'electron-results.json'),JSON.stringify(data,null,2)));
ipcMain.handle('ready',()=>console.log('QUELYT_READY'));
app.whenReady().then(()=>{
  Menu.setApplicationMenu(Menu.buildFromTemplate([{label:'Quelyt',submenu:[{role:'quit'}]},{label:'Edit',submenu:[{role:'undo'},{role:'redo'},{role:'cut'},{role:'copy'},{role:'paste'},{role:'selectAll'}]}]));
  const win=new BrowserWindow({width:1140,height:760,title:'Quelyt · Electron comparison',webPreferences:{preload:path.join(__dirname,'preload.cjs'),contextIsolation:true,nodeIntegration:false,sandbox:true}});
  win.webContents.setWindowOpenHandler(()=>({action:'deny'}));
  win.webContents.on('will-navigate',e=>e.preventDefault());
  win.loadFile(path.join(__dirname,'dist/index.html'));
});
app.on('window-all-closed',()=>app.quit());
app.on('before-quit',()=>worker?.kill('SIGKILL'));
