"""DEPRECATED sandbox-exec feasibility probe, not a shipping sandbox policy."""
import json,pathlib,subprocess,sys,tempfile,time
root=pathlib.Path(__file__).resolve().parent
python=pathlib.Path(sys.executable).resolve()
with tempfile.TemporaryDirectory(prefix='quelyt-isolation-',dir='/tmp') as d:
    tmp=pathlib.Path(d).resolve();allowed=tmp/'selected.csv';denied=tmp/'unselected.csv';output=tmp/'write.txt'
    allowed.write_text('region,amount\nWest,10\nEast,20\n');denied.write_text('synthetic unselected data')
    # Keep the diagnostic policy intentionally outside production code.
    read_roots=[str(pathlib.Path(sys.base_prefix).resolve()),str(root),str(root.parents[1]/'src'),str(pathlib.Path(sys.prefix).resolve()),'/System','/usr/lib','/private/var/db/dyld']
    rules=' '.join('(subpath '+json.dumps(p)+')' for p in read_roots)
    literals=' '.join('(literal '+json.dumps(p)+')' for p in [str(allowed),'/', '/dev/urandom','/dev/null','/dev/random',str(python)])
    profile='(version 1)\n(deny default)\n(allow file-read-metadata)\n(allow process*)\n(allow sysctl-read)\n(allow mach-lookup)\n(allow file-read* '+rules+' '+literals+')\n'
    (root/'profile-used.sb').write_text(profile.replace(str(tmp),'SYNTHETIC_TEMP_DIRECTORY'))
    start=time.perf_counter()
    p=subprocess.run(['/usr/bin/sandbox-exec','-p',profile,str(python),'-I','-B',str(root/'probe.py'),str(allowed),str(denied),str(output)],capture_output=True,text=True,timeout=15)
    result={'platform':sys.platform,'python':str(python),'exit_code':p.returncode,'elapsed_ms':round((time.perf_counter()-start)*1000,2),'stderr':p.stderr[:3000],'checks':json.loads(p.stdout) if p.returncode==0 else None,'output_file_exists':output.exists(),'production_ready':False}
    worker=subprocess.run(['/usr/bin/sandbox-exec','-p',profile,sys.executable,'-I','-B',str(root.parents[1]/'src/quelyt/worker.py')],input=json.dumps({'path':str(allowed),'sql':'SELECT sum(amount) AS total FROM dataset'}),capture_output=True,text=True,timeout=15)
    result['worker']={'exit_code':worker.returncode,'response':json.loads(worker.stdout) if worker.stdout else None,'stderr':worker.stderr[:3000]}
    (root/'results.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2))
