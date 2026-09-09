"""20 denotation-scored local text-to-SQL cases, no real user data."""
import duckdb, urllib.request, json, time, pathlib, sqlglot
from sqlglot import exp
ROOT=pathlib.Path(__file__).parent
c=duckdb.connect()
c.execute("CREATE TABLE orders AS SELECT i id, CASE WHEN i%2=0 THEN 'West' ELSE 'East' END region, (i%10+1)::INTEGER amount, CASE WHEN i%4=0 THEN 'returned' ELSE 'completed' END status, DATE '2026-07-01' + (i%62)::INTEGER order_date FROM range(100) t(i)")
cases=[
('How many orders are there?','SELECT count(*) FROM orders'),
('What is the sum of amount for all orders?','SELECT sum(amount) FROM orders'),
('What is the average amount?','SELECT avg(amount) FROM orders'),
('What is the minimum amount?','SELECT min(amount) FROM orders'),
('What is the maximum amount?','SELECT max(amount) FROM orders'),
('How many orders are in West?',"SELECT count(*) FROM orders WHERE region='West'"),
('Sum amount by region.','SELECT region,sum(amount) FROM orders GROUP BY region'),
('Count orders by status.','SELECT status,count(*) FROM orders GROUP BY status'),
('How many completed orders?',"SELECT count(*) FROM orders WHERE status='completed'"),
('Sum amount of completed orders.',"SELECT sum(amount) FROM orders WHERE status='completed'"),
('How many returned orders in West?',"SELECT count(*) FROM orders WHERE status='returned' AND region='West'"),
('Count distinct regions.','SELECT count(DISTINCT region) FROM orders'),
('Earliest order date?','SELECT min(order_date) FROM orders'),
('Latest order date?','SELECT max(order_date) FROM orders'),
('Count orders in August 2026.',"SELECT count(*) FROM orders WHERE order_date >= DATE '2026-08-01' AND order_date < DATE '2026-09-01'"),
('Sum amount by calendar month, return month as YYYY-MM text.',"SELECT strftime(order_date,'%Y-%m'),sum(amount) FROM orders GROUP BY 1"),
('Return IDs of the three highest amount orders, breaking ties by lowest ID.','SELECT id FROM orders ORDER BY amount DESC,id LIMIT 3'),
('How many orders have amount greater than 5?','SELECT count(*) FROM orders WHERE amount>5'),
('Average amount by status.','SELECT status,avg(amount) FROM orders GROUP BY status'),
('Sum amount for completed West orders.',"SELECT sum(amount) FROM orders WHERE status='completed' AND region='West'"),
]
(ROOT/'ai-cases.json').write_text(json.dumps([{'question':q,'expected_sql':s} for q,s in cases],indent=2))
system="Return JSON with one key sql containing exactly one DuckDB SELECT query. No markdown. Schema: orders(id BIGINT, region VARCHAR [West,East], amount INTEGER, status VARCHAR [completed,returned], order_date DATE). Treat amount as the requested measure."
results=[]
for question,gold in cases:
    t=time.perf_counter()
    body={'model':'llama3.2:1b','stream':False,'format':'json','options':{'temperature':0,'num_predict':256,'num_ctx':2048},'messages':[{'role':'system','content':system},{'role':'user','content':question}]}
    row={'question':question,'expected_sql':gold}
    try:
        req=urllib.request.Request('http://127.0.0.1:11434/api/chat',data=json.dumps(body).encode(),headers={'Content-Type':'application/json'})
        with urllib.request.urlopen(req,timeout=90) as r: response=json.load(r)
        sql=json.loads(response['message']['content'])['sql'];row['sql']=sql
        trees=sqlglot.parse(sql,read='duckdb')
        if len(trees)!=1 or not isinstance(trees[0],exp.Select):raise ValueError('not single SELECT')
        # Synthetic disposable DB only. Disable external access before generated query.
        c.execute('SET enable_external_access=false')
        actual=c.execute(sql).fetchmany(1001); expected=c.execute(gold).fetchall()
        norm=lambda rows:sorted([tuple(str(v) for v in r) for r in rows])
        row['correct']=norm(actual)==norm(expected)
        row['eval_count']=response.get('eval_count');row['eval_duration_ns']=response.get('eval_duration');row['load_duration_ns']=response.get('load_duration')
    except Exception as e:row.update(correct=False,error=str(e))
    row['elapsed_ms']=round((time.perf_counter()-t)*1000,2);results.append(row)
    print(json.dumps(row),flush=True)
    (ROOT/'ai-results.json').write_text(json.dumps({'model':'llama3.2:1b','cases':results,'correct':sum(r['correct'] for r in results),'total':len(results)},indent=2))
