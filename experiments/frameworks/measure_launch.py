"""Fresh-process warm-cache launch + approximate resident-memory comparison.

Only emits Quelyt descendants/new WebKit helper paths, never unrelated app argv.
"""
import json,os,pathlib,selectors,signal,subprocess,time
ROOT=pathlib.Path(__file__).resolve().parents[2]
HERE=pathlib.Path(__file__).resolve().parent
candidates={
 'native':[str(ROOT/'.build/Quelyt.app/Contents/MacOS/Quelyt'),str(ROOT/'experiments/discovery/data/sales.parquet')],
 'tauri':[str(HERE/'src-tauri/target/release/quelyt-tauri-probe')],
 'electron':[str(HERE/'node_modules/electron/dist/Electron.app/Contents/MacOS/Electron'),str(HERE/'electron.cjs')],
}
def processes():
    p=subprocess.run(['/bin/ps','-axo','pid=,ppid=,rss=,comm='],capture_output=True,text=True,check=True)
    out={}
    for line in p.stdout.splitlines():
        fields=line.strip().split(None,3)
        if len(fields)==4:
            pid,ppid,rss,comm=fields;out[int(pid)]={'pid':int(pid),'ppid':int(ppid),'rss_kib':int(rss),'executable':comm}
    return out
results=[]
# Alternate framework order to reduce a fixed-order cache/temperature bias.
for run,order in enumerate([['native','tauri','electron'],['electron','native','tauri'],['tauri','electron','native']]):
    for name in order:
        before=processes();started=time.perf_counter();env=os.environ.copy();env['QUELYT_BENCHMARK']='1'
        p=subprocess.Popen(candidates[name],stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,env=env,start_new_session=True)
        selector=selectors.DefaultSelector();selector.register(p.stdout,selectors.EVENT_READ)
        ready=False
        try:
            deadline=started+20
            while time.perf_counter()<deadline:
                if selector.select(.1):
                    line=p.stdout.readline()
                    if b'QUELYT_READY' in line:ready=True;break
                    if not line and p.poll() is not None:break
            elapsed=(time.perf_counter()-started)*1000
            time.sleep(.4)
            after=processes();owned={p.pid}
            for _ in range(6):owned.update(pid for pid,v in after.items() if v['ppid'] in owned)
            new_webkit={pid for pid,v in after.items() if pid not in before and any(s in v['executable'] for s in ['com.apple.WebKit.WebContent','com.apple.WebKit.GPU','com.apple.WebKit.Networking'])}
            selected=[v for pid,v in after.items() if pid in owned or (name=='tauri' and pid in new_webkit)]
            row={'framework':name,'run':run+1,'ready':ready,'fresh_process_to_dataset_ready_ms':round(elapsed,2),'rss_kib_sum':sum(v['rss_kib'] for v in selected),'processes':selected,'attribution':'descendants plus newly created WebKit XPC helpers; RSS sum may double-count shared pages'}
            results.append(row);print(json.dumps(row),flush=True)
        finally:
            selector.close()
            try:os.killpg(p.pid,signal.SIGTERM)
            except ProcessLookupError:pass
            try:p.wait(timeout=3)
            except subprocess.TimeoutExpired:os.killpg(p.pid,signal.SIGKILL);p.wait()
            time.sleep(.5)
        (HERE/'launch-results.json').write_text(json.dumps(results,indent=2))
