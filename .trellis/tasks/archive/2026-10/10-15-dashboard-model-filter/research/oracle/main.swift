import Foundation

@main struct Oracle {
 static func main() throws {
  let root = CommandLine.arguments[1]
  let zone = TimeZone(identifier: "Asia/Shanghai")!
  let now = ISO8601DateFormatter().date(from: "2026-10-15T08:00:00Z")!
  let report = try CodexLogScanner(timeZone: zone).scan(homePath: root)
  let index = OverviewIndex(report: report, timeZone: zone)
  let value = ValuationIndex(report: report)
  var rows: [[String:Any]] = []
  for (name, period, model) in [("all",UsagePeriod.all,Optional<String>.none),("today",.today,nil),("sol6_all",.all,"gpt-6-sol"),("sol6_today",.today,"gpt-6-sol"),("sol56_all",.all,"gpt-5.6-sol"),("review_all",.all,"codex-auto-review") ] {
   let s = index.summary(in: period, model: model, now: now, timeZone: zone)
   let c = value.summary(in: period, model: model, now: now, timeZone: zone).total
   let cost = try JSONSerialization.jsonObject(with: JSONEncoder().encode(c))
   let cache = try JSONSerialization.jsonObject(with: JSONEncoder().encode(CacheRate(usage:s.usage)))
   rows.append(["case":name,"input":s.usage.input,"output":s.usage.output,"total":s.usage.total,"records":s.recordCount,"cost":cost,"cacheRate":cache,"dailySum":s.dailyTotals.reduce(Int64(0)){$0+$1.usage.total},"hourlySum":s.hourlyTotals.reduce(Int64(0)){$0+$1.usage.total},"modelCount":s.models.count,"modelRecordCounts":s.modelRecordCounts])
  }
  let data = try JSONSerialization.data(withJSONObject: rows, options:[.prettyPrinted,.sortedKeys]);FileHandle.standardOutput.write(data)
 }
}
