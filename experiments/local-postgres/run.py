"""Exercise only an isolated synthetic cluster, no TCP listener or existing service."""
import pathlib, subprocess, tempfile, time, json
BIN=pathlib.Path('/Library/PostgreSQL/15/bin')
results={'binary':str(BIN),'cycles':[]}
with tempfile.TemporaryDirectory(prefix='quelyt-pg-',dir='/tmp') as tmp:
    root=pathlib.Path(tmp); data=root/'data'
    def run(args):
        t=time.perf_counter();p=subprocess.run([str(BIN/args[0]),*args[1:]],capture_output=True,text=True,timeout=60)
        if p.returncode:raise RuntimeError(p.stderr+p.stdout)
        return round((time.perf_counter()-t)*1000,2),p.stdout
    results['init_ms']=run(['initdb','-D',str(data),'-A','trust','--no-locale','-E','UTF8'])[0]
    started=False
    try:
        for i in range(3):
            start=run(['pg_ctl','-D',str(data),'-l',str(root/'log'),'-o',f"-k {root} -c listen_addresses='' -p 55439",'-w','start'])[0];started=True
            value=run(['psql','-h',str(root),'-p','55439','-d','postgres','-Atc','SELECT 42'])[1].strip()
            stop=run(['pg_ctl','-D',str(data),'-m','fast','-w','stop'])[0];started=False
            results['cycles'].append({'start_ms':start,'query_result':value,'stop_ms':stop})
    finally:
        if started: run(['pg_ctl','-D',str(data),'-m','fast','-w','stop'])
pathlib.Path(__file__).with_name('results.json').write_text(json.dumps(results,indent=2));print(json.dumps(results,indent=2))
