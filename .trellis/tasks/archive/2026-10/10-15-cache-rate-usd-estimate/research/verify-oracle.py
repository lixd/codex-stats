from pathlib import Path
import json
from decimal import Decimal
r=Path(__file__).resolve().parent
j=json.loads((r/'independent-cli-final.json').read_text())
e=json.loads((r/'independent-oracle-expected.json').read_text())['all']
assert (j['total']['input'],j['total']['output'])==(2800,340)
c=j['derived']['cost']
assert (c['state'],Decimal(c['amountUSD']),c['estimatedTokens'],c['unestimatedTokens'])==('partial',Decimal(e['usd']),1830,1310)
assert j['derived']['cacheRate']['state']=='incomplete'
assert j['derived']['cacheRate']['cachedInput'] is None and j['derived']['cacheRate']['fraction'] is None
for collection in (j['models'],j['sessions'],j['recordDerived'].values()):
 values=[x['derived']['cost'] if 'derived' in x else x['cost'] for x in collection]
 assert sum((Decimal(x['amountUSD'] or '0') for x in values),Decimal(0))==Decimal(e['usd'])
 assert sum(x['estimatedTokens'] for x in values)==1830
 assert sum(x['unestimatedTokens'] for x in values)==1310
for s in j['sessions']:
 assert sum((Decimal(x['derived']['cost']['amountUSD'] or '0') for x in s['models']),Decimal(0))==Decimal(s['derived']['cost']['amountUSD'])
assert len(j['records'])==6
for rec in j['records']:
 d=j['recordDerived'][rec['id']]
 if rec['usage']['input']==0:
  assert d['cacheRate']['state']=='noInput' and d['cacheRate']['fraction'] is None
  assert Decimal(d['cost']['amountUSD'])==Decimal('0.00005')
 if rec['model']=='unpriced-test-model':
  assert d['cost']['state']=='unavailable' and d['cost']['amountUSD'] is None
result='PASS final source: six accepted synthetic records; total3140=input2800+output340; exactUSD0.00693; coverage1830/1310; total/model/session/session-model/record sums identical; unavailable amount/null and incomplete cachedInput/fraction null; output-only USD0.00005 and noInput cache state.\n'
(r/'independent-oracle-final-result.txt').write_text(result)
print(result)
