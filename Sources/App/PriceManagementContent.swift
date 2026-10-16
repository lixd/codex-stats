#if SWIFT_PACKAGE
import CodexStatsCore
#endif
import SwiftUI

struct PriceManagementContent: View {
    @EnvironmentObject private var store: UsageStore
    @Environment(\.self) private var environment
    @ViewState(initialValue: false) private var showingEditor: Bool
    @ViewState(initialValue: Optional<ModelPrice>.none) private var editingEntry: ModelPrice?
    var onBack: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Button(action: onBack) { Label("返回设置", systemImage: "chevron.left") }
                    .buttonStyle(.plain).foregroundStyle(CPTheme.accent)
                HStack(alignment: .top) {
                    SectionHeader(title: "模型价格", subtitle: "USD / 百万 Token · 全部历史按当前价格折算")
                    Spacer(minLength: 12)
                    Button { editingEntry = nil; showingEditor = true } label: { Label("添加价格", systemImage: "plus") }
                        .buttonStyle(.borderedProminent).tint(CPTheme.actionFill.resolve(in: environment))
                        .disabled(!store.canAddPrice)
                        .accessibilityIdentifier("add-model-price")
                }
                if let error = store.priceError {
                    StatusBanner(message: error)
                    if store.catalog == nil {
                        Button("重试读取价格配置") { Task { await store.reloadPrices() } }
                    }
                }
                if !store.newBuiltInPrices.isEmpty {
                    Surface(padding: 14) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("新增内置参考价").font(.system(size: 12, weight: .semibold))
                            Text(store.newBuiltInPrices.map(\.model).joined(separator: "、"))
                                .font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
                            Text("仅补充以上缺失条目，保留已有价格和其他已删除记录。gpt-5.6-sol 为促销参考价，官方称至少持续至 2026-11-21。")
                                .font(.system(size: 10)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                            Button("补充新增内置价") { Task { _ = await store.addNewBuiltInPrices() } }
                                .disabled(!store.canManagePrices).accessibilityIdentifier("import-new-built-in-prices")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                if store.savingPrices { ProgressView("正在保存并更新参考金额…").controlSize(.small) }
                Text(candidateStatus).font(.system(size: 11)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let catalog = store.catalog {
                    ForEach(catalog.entries) { entry in priceRow(entry) }
                    if catalog.entries.isEmpty {
                        ContentUnavailableView("尚未配置价格", systemImage: "dollarsign.circle", description: Text("从全部历史中出现过的模型添加价格。Token 统计不受影响。"))
                    }
                    Text("价表修订：" + catalog.revision)
                        .font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary).textSelection(.enabled)
                } else {
                    Text("价格配置尚不可用；Token 与缓存率仍可查看。")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Text("价格仅用于参考估算，非实际扣费或订阅余额。输入包含缓存输入，输出包含推理；不重复计费。缺价或缓存拆分不完整的记录仍明确列为未估算。")
                    .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .background(CPTheme.viewBackground)
        .sheet(isPresented: $showingEditor) {
            PriceEditor(entry: editingEntry).environmentObject(store)
                .environment(\.appPalette, store.palette)
        }
    }

    private var candidateStatus: String {
        if !store.hasReport { return "等待全部历史扫描完成后可添加模型；打开本页不会重新扫描日志。" }
        if store.catalog == nil { return "价格配置不可用，暂不能确定添加候选；请重试读取配置。" }
        if store.priceCandidates.isEmpty { return "所有已识别模型均已配置价格；未知模型标识不能手动猜价。" }
        return "添加候选来自全部历史，已过滤有价格的模型；共 \(store.priceCandidates.count) 个可配置模型。"
    }
    private func priceRow(_ entry: ModelPrice) -> some View {
        Surface(padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(entry.model).font(.system(size: 14, weight: .semibold))
                            .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                        Text(entry.source == .custom ? "自定义 · 未经官方核验" : "内置 · OpenAI Standard · 核验 " + (entry.verifiedOn ?? "未记录"))
                            .font(.system(size: 10)).foregroundStyle(.secondary)
                        if entry.source == .builtIn {
                            Text(entry.sourceURL ?? "来源未记录").font(.system(size: 10)).foregroundStyle(.secondary)
                                .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                            if entry.model == "gpt-5.6-sol" {
                                Text("促销参考价 · 官方称至少持续至 2026-11-21")
                                    .font(.system(size: 10)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    Spacer(minLength: 8)
                    Button("编辑") { editingEntry = entry; showingEditor = true }
                        .disabled(!store.canManagePrices).accessibilityIdentifier("edit-price-" + entry.model)
                    Button(role: .destructive) { Task { _ = await store.deletePrice(entry.model) } } label: { Image(systemName: "trash") }
                        .disabled(store.deletePriceBlockReason(entry.model) != nil)
                        .help(store.deletePriceBlockReason(entry.model) ?? "删除这条价格记录")
                        .accessibilityLabel("删除 " + entry.model + " 的价格")
                        .accessibilityIdentifier("delete-price-" + entry.model)
                }
                HStack(alignment: .top, spacing: 16) {
                    rate("输入", entry.input)
                    rate("缓存输入", entry.cachedInput)
                    rate("输出", entry.output)
                }
                if let reason = store.deletePriceBlockReason(entry.model) {
                    Label(reason, systemImage: "lock").font(.system(size: 10)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    private func rate(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
            Text("$" + value).font(.system(size: 14, weight: .medium, design: .monospaced))
                .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label + "价，" + value + " 美元每百万 Token")
    }
}

struct PriceEditor: View {
    @EnvironmentObject private var store: UsageStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.self) private var environment
    let entry: ModelPrice?
    @ViewState private var model: String
    @ViewState private var input: String
    @ViewState private var cachedInput: String
    @ViewState private var output: String
    @ViewState(initialValue: Optional<String>.none) private var formError: String?
    @ViewState(initialValue: false) private var submitting: Bool

    init(entry: ModelPrice?) {
        self.entry = entry
        _model = ViewState(initialValue: entry?.model ?? "")
        _input = ViewState(initialValue: entry?.input ?? "")
        _cachedInput = ViewState(initialValue: entry?.cachedInput ?? "")
        _output = ViewState(initialValue: entry?.output ?? "")
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(entry == nil ? "添加模型价格" : "调整模型价格").font(.system(size: 18, weight: .semibold))
            Text("USD / 百万 Token · 保存后用于全部历史的参考估算")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            if let entry {
                Text(entry.model).font(.system(size: 13, weight: .semibold)).textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Picker("模型", selection: $model) {
                    Text("选择模型").tag("")
                    ForEach(store.priceCandidates, id: \.self) { Text($0).tag($0) }
                }.pickerStyle(.menu).accessibilityIdentifier("price-model-picker")
            }
            field("输入价", text: $input, id: "price-input")
            field("缓存输入价", text: $cachedInput, id: "price-cached-input")
            field("输出价", text: $output, id: "price-output")
            Text("三项必填，允许 0。输入含缓存、输出含推理；保存后标记为自定义价格，不代表官方当前价格。")
                .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if let error = formError { Text(error).font(.system(size: 11)).foregroundStyle(CPTheme.orange).fixedSize(horizontal: false, vertical: true) }
            HStack {
                if submitting { ProgressView().controlSize(.small) }
                Spacer()
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction).disabled(submitting)
                Button("保存") { save() }.keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent).tint(CPTheme.actionFill.resolve(in: environment))
                    .disabled(submitting || !store.canManagePrices || model.isEmpty)
                    .accessibilityIdentifier("save-model-price")
            }
        }
        .padding(24).frame(width: 440, alignment: .leading).background(CPTheme.cardBackground)
        .interactiveDismissDisabled(submitting)
    }
    private func field(_ label: String, text: Binding<String>, id: String) -> some View {
        HStack {
            Text(label).font(.system(size: 12)).frame(width: 86, alignment: .leading)
            TextField("0.00", text: text).textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced)).accessibilityLabel(label + "，美元每百万 Token").accessibilityIdentifier(id)
        }
    }
    private func save() {
        do { _ = try ModelPrice(model: model, input: input, cachedInput: cachedInput, output: output) }
        catch { formError = error.localizedDescription; return }
        submitting = true; formError = nil
        Task { @MainActor in
            if await store.savePrice(model: model, input: input, cachedInput: cachedInput, output: output, adding: entry == nil) { dismiss() }
            else { formError = store.priceError ?? "未保存价格" }
            submitting = false
        }
    }
}
