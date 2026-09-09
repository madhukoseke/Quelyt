"""Deterministic evidence experiment, NOT an LLM agent-quality result."""
import duckdb,json,pathlib
c=duckdb.connect()
c.execute("CREATE TABLE sales(period VARCHAR,region VARCHAR,segment VARCHAR,revenue INTEGER)")
c.executemany('INSERT INTO sales VALUES (?,?,?,?)', [('July','West','Enterprise',1000),('July','West','SMB',500),('July','East','Enterprise',1000),('July','East','SMB',500),('August','West','Enterprise',600),('August','West','SMB',500),('August','East','Enterprise',1100),('August','East','SMB',500)])
queries=["SELECT period,sum(revenue) revenue FROM sales GROUP BY period ORDER BY period", "SELECT region,sum(CASE WHEN period='August' THEN revenue ELSE -revenue END) delta FROM sales GROUP BY region ORDER BY delta", "SELECT segment,sum(CASE WHEN period='August' THEN revenue ELSE -revenue END) delta FROM sales WHERE region='West' GROUP BY segment ORDER BY delta"]
trace=[{'sql':q,'rows':c.execute(q).fetchall()} for q in queries]
result={'kind':'deterministic scripted investigation, not model evaluation','trace':trace,'net_delta':-300,'percent_change':-10,'west_enterprise_delta':-400,'east_enterprise_offset':100,'conclusion':'West Enterprise accounts for a -400 change offset by +100 East Enterprise. Descriptive contribution, not proof of business causality.'}
assert sum(r[1] for r in trace[1]['rows'])==-300
pathlib.Path(__file__).with_name('investigation-results.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2))
