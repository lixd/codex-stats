import json
from pathlib import Path
p=Path(__file__).resolve().parent
want=json.loads((p/'expected.json').read_text())
got=json.loads((p/'output.json').read_text())
for row in got:
    expected=want[row['case']]
    for key in ['input','output','total','records']:
        assert row[key]==expected[key],(row['case'],key)
    cost=row['cost']
    assert cost.get('amountUSD')==expected['usd'],(row['case'],cost)
    assert cost['estimatedTokens']==expected['estimated']
    assert cost['unestimatedTokens']==expected['unestimated']
    assert row['dailySum']==row['total']
    assert 'today' not in row['case'] or row['hourlySum']==row['total']
cli=json.loads((p/'report-cli.json').read_text())
assert cli['total']['input']==5200 and cli['total']['output']==350
assert cli['derived']['cost']==got[0]['cost']
assert len(cli['records'])==8
print('PASS: 6 fixed hand cases; exact USD/coverage/daily/hourly totals; actual Report CLI equals all-model overview')
