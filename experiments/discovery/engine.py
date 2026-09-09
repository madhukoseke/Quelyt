"""Disposable reproducible engine/safety benchmark; synthetic data only."""
import duckdb, json, time, statistics, resource, pathlib, threading
ROOT = pathlib.Path(__file__).resolve().parent
DATA = ROOT / 'data'; DATA.mkdir(exist_ok=True)
c = duckdb.connect(config={'threads': 4, 'memory_limit':'512MB'})
def timed(fn, n=5):
    times=[]
    for _ in range(n):
        t=time.perf_counter(); fn(); times.append((time.perf_counter()-t)*1000)
    return {'first_ms':round(times[0],2),'median_ms':round(statistics.median(times),2),'runs_ms':[round(x,2) for x in times]}
c.execute("CREATE TABLE sales AS SELECT i id, DATE '2026-07-01' + (i%62)::INTEGER sale_date, CASE WHEN i%3=0 THEN 'West' ELSE 'East' END region, (i%100)::INTEGER amount FROM range(1000000) t(i)")
results={'duckdb':duckdb.__version__,'rows':1000000,'threads':4,'memory_limit':'512MB','formats':{}}
for ext,fmt in [('csv','CSV, HEADER'),('parquet','PARQUET'),('json','JSON')]:
    p=DATA/f'sales.{ext}'
    c.execute(f"COPY sales TO '{p}' (FORMAT {fmt})")
    results['formats'][ext]={'bytes':p.stat().st_size, 'aggregate':timed(lambda:c.execute(f"SELECT region,sum(amount) FROM '{p}' GROUP BY region").fetchall()),'preview':timed(lambda:c.execute(f"SELECT * FROM '{p}' LIMIT 200").fetchall())}
p=DATA/'readonly.duckdb'
if p.exists(): p.unlink()
w=duckdb.connect(str(p)); w.execute('CREATE TABLE sales AS SELECT * FROM range(100)'); w.close()
r=duckdb.connect(str(p),read_only=True)
probes={
'write': 'DELETE FROM sales',
'file_read':f"SELECT count(*) FROM read_csv('{DATA / 'sales.csv'}')",
'file_write':f"COPY sales TO '{DATA / 'escape.csv'}' (HEADER)",
'config':'SET threads=1',
}
results['readonly_probes']={}
for label,sql in probes.items():
    try:r.execute(sql).fetchall(); results['readonly_probes'][label]='ALLOWED'
    except Exception as e:results['readonly_probes'][label]=str(e).splitlines()[0]
r.close()
r=duckdb.connect(str(p),read_only=True,config={'enable_external_access':False,'autoinstall_known_extensions':False,'autoload_known_extensions':False,'threads':2,'memory_limit':'256MB'})
r.execute('SET lock_configuration=true')
results['hardened_probes']={}
for label,sql in probes.items():
    try:r.execute(sql).fetchall(); results['hardened_probes'][label]='ALLOWED'
    except Exception as e:results['hardened_probes'][label]=str(e).splitlines()[0]
t=time.perf_counter(); timer=threading.Timer(.1,r.interrupt);timer.start()
try:r.execute('SELECT sum(a.range*b.range) FROM range(10000000) a CROSS JOIN range(10000000) b').fetchall(); outcome='unexpected completion'
except Exception as e:outcome=str(e).splitlines()[0]
finally:timer.cancel()
results['cancel']={'elapsed_ms':round((time.perf_counter()-t)*1000,2),'outcome':outcome}
results['peak_process_rss_bytes']=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
(ROOT/'engine-results.json').write_text(json.dumps(results,indent=2));print(json.dumps(results,indent=2))
