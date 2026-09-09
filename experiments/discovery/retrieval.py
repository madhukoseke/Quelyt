"""Synthetic retrieval sanity check, deliberately includes synonym mismatch."""
import math,re,time,json,pathlib
qs=[('orders amount',['orders']),('customer email',['customers']),('product category',['products']),('revenue by customer',['orders','customers']),('refund rate',['returns','orders'])]
base={'orders':'orders order_id customer_id amount order_date','customers':'customers customer_id email country','products':'products product_id category price','returns':'returns order_id returned_amount'}
links={'orders':['customers'],'returns':['orders']}
token=lambda s:re.findall(r'[a-z]+',s.lower())
results=[]
for n in [10,100,1000,5000]:
    docs={**base,**{f'noise_{i}':f'archive_{i} event_id payload status timestamp' for i in range(n-4)}}
    tokens={k:token(v) for k,v in docs.items()};avg=sum(map(len,tokens.values()))/n
    df={w:sum(w in ts for ts in tokens.values()) for w in set(sum(tokens.values(),[]))}
    for method in ['full','lexical','bm25','bm25_graph']:
        rows=[];start=time.perf_counter()
        for q,gold in qs:
            terms=token(q)
            def score(ts):
                if method=='lexical':return sum(w in ts for w in terms)
                return sum(math.log(1+(n-df.get(w,0)+.5)/(df.get(w,0)+.5))*ts.count(w)*2.2/(ts.count(w)+1.2*(.25+.75*len(ts)/avg)) for w in terms if w in ts)
            selected=list(docs) if method=='full' else [k for k in sorted(docs,key=lambda k:score(tokens[k]),reverse=True) if score(tokens[k])>0][:2]
            if method=='bm25_graph':selected=list(dict.fromkeys(selected+[v for k in selected for v in links.get(k,[])]))
            rows.append({'question':q,'recall':len(set(gold)&set(selected))/len(gold),'selected':selected if method!='full' else f'all {n}','context_chars':sum(len(docs[k]) for k in selected)})
        results.append({'tables':n,'method':method,'elapsed_ms':round((time.perf_counter()-start)*1000,3),'mean_recall':sum(r['recall'] for r in rows)/len(rows),'mean_context_chars':sum(r['context_chars'] for r in rows)/len(rows),'cases':rows})
pathlib.Path(__file__).with_name('retrieval-results.json').write_text(json.dumps(results,indent=2))
print(json.dumps([{k:v for k,v in r.items() if k!='cases'} for r in results],indent=2))
