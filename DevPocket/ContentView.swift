import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: WorkspaceStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var selection
    @State private var query = ""
    @FocusState private var searchFocused: Bool

    private let groups: [(String, [DeveloperTool])] = [
        ("数据与时间", [.json, .timestamp]),
        ("编码与转换", [.url, .base64, .qrcode]),
        ("加密与安全", [.aes])
    ]
    private var motion: Animation? {
        reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.94)
    }
    private var groupTitle: String { groups.first { $0.1.contains(store.selected) }?.0 ?? "工具箱" }
    private var outputPending: Bool { store.page.dirty || !store.hasOutput }
    private var outputStatus: String {
        store.page.busy ? "处理中" : store.page.dirty ? "待处理" : !store.hasOutput ? "等待输入" : "已就绪"
    }
    private func matches(_ tool: DeveloperTool) -> Bool {
        query.isEmpty || tool.title.localizedStandardContains(query) || tool.rawValue.localizedStandardContains(query)
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 212)
            Rectangle().fill(PocketStyle.line).frame(width: 1)
            ZStack {
                workspace.id(store.selected)
                    .transition(.opacity)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(PocketStyle.canvas)
        }
        .frame(minWidth: 980, minHeight: 680)
        .tint(PocketStyle.mint)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: store.selected)
        .animation(motion, value: store.page.error)
        .overlay(alignment: .bottom) {
            if let toast = store.toast {
                Label(toast, systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(PocketStyle.ink)
                    .padding(.horizontal, 16).padding(.vertical, 11)
                    .background(.regularMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(PocketStyle.ink.opacity(0.12)))
                    .shadow(color: .black.opacity(0.07), radius: 16, y: 5)
                    .padding(.bottom, 22)
                    .transition(.opacity.combined(with: .offset(y: reduceMotion ? 0 : 5)))
                    .allowsHitTesting(false).accessibilityAddTraits(.updatesFrequently)
            }
        }
        .animation(motion, value: store.toast)
        .onReceive(NotificationCenter.default.publisher(for: .focusToolSearch)) { _ in searchFocused = true }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                Image("BrandIcon").resizable().interpolation(.high).frame(width: 44, height: 44)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("DevPocket").font(.system(size: 16, weight: .semibold, design: .rounded)).tracking(-0.3)
                    Text("开发者的随身工具箱").font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14).padding(.top, 27).padding(.bottom, 21)

            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass").font(.system(size: 11)).foregroundStyle(.secondary)
                TextField("搜索工具", text: $query)
                    .textFieldStyle(.plain).focused($searchFocused)
                    .accessibilityLabel("搜索开发者工具")
                    .onSubmit {
                        if let first = DeveloperTool.allCases.first(where: matches) {
                            store.selected = first
                            query = ""
                            searchFocused = false
                        }
                    }
                    .onExitCommand { query = ""; searchFocused = false }
                if query.isEmpty {
                    Text("⌘K").font(.system(size: 9, design: .monospaced)).foregroundStyle(.tertiary)
                } else {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).foregroundStyle(.secondary).accessibilityLabel("清除搜索")
                }
            }
            .font(.system(size: 11)).padding(.horizontal, 10).frame(height: 34)
            .background(PocketStyle.surface.opacity(0.65), in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(PocketStyle.line.opacity(0.7)))
            .padding(.horizontal, 16).padding(.bottom, 23)

            ScrollView {
                VStack(alignment: .leading, spacing: 21) {
                    ForEach(groups, id: \.0) { title, tools in
                        let visible = tools.filter(matches)
                        if !visible.isEmpty {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(title).font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.secondary).padding(.leading, 12).padding(.bottom, 3)
                                ForEach(visible) { tool in
                                    ToolNavigationRow(tool: tool, selected: store.selected == tool, namespace: selection) {
                                        store.selected = tool
                                    }
                                }
                            }
                        }
                    }
                    if !DeveloperTool.allCases.contains(where: matches) {
                        Label("没有找到匹配的工具", systemImage: "magnifyingglass")
                            .font(.system(size: 11)).foregroundStyle(.secondary).padding(12)
                    }
                }
                .padding(.horizontal, 12)
            }
            .scrollIndicators(.hidden)
            Spacer(minLength: 16)
            VStack(alignment: .leading, spacing: 12) {
                Rectangle().fill(PocketStyle.line).frame(height: 1)
                HStack(spacing: 6) {
                    Image(systemName: "lock.shield").font(.system(size: 11))
                    Text("本地处理")
                    Spacer()
                    Text("v0.1.0").fontDesign(.monospaced).foregroundStyle(.tertiary)
                }
                .font(.system(size: 10)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20).padding(.bottom, 22)
        }
        .background(PocketStyle.sidebar)
    }

    private var workspace: some View {
        VStack(alignment: .leading, spacing: 16) {
            workspaceHeader
            if store.selected == .qrcode {
                QRCodeConfigurationView()
            } else {
                conversionBar
            }
            if store.selected == .aes { AESConfigurationView() }
            HStack(spacing: 14) {
                editorPanel(title: inputTitle, symbol: "square.and.pencil", input: true)
                if store.selected == .qrcode {
                    QRCodePreviewPanel()
                } else {
                    editorPanel(title: outputTitle, symbol: "text.alignleft", input: false)
                }
            }
            .frame(maxHeight: .infinity)
            if let error = store.page.error { errorNotice(error) }
            actionBar
        }
    }

    private var workspaceHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            PocketToolIcon(symbol: store.selected.symbol, emphasized: true, size: 40)
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    Text(store.selected.title).font(.system(size: 23, weight: .semibold)).tracking(-0.5)
                    Text(groupTitle).font(.system(size: 10)).foregroundStyle(.tertiary)
                }
                Text(store.selected.subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            HStack(spacing: 5) {
                Circle().fill(PocketStyle.ink).frame(width: 5, height: 5)
                Text("离线运行").font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(PocketStyle.ink)
        }
        .frame(height: 55)
    }

    private var conversionBar: some View {
        HStack(spacing: 12) {
            PocketSegmentedPicker(title: "转换方式", choices: store.selected.modes,
                                  selection: Binding(get: { store.mode }, set: { store.mode = $0 }), label: { $0.title })
                .frame(width: store.selected == .timestamp ? 296 : 174)
            Spacer(minLength: 4)
            if store.selected == .json {
                Toggle("按键名排序", isOn: Binding(get: { store.sortKeys }, set: { store.sortKeys = $0 }))
                    .toggleStyle(.checkbox).font(.system(size: 11))
            }
            if store.selected == .timestamp {
                Picker("显示时区", selection: Binding(get: { store.timeZoneID }, set: { store.timeZoneID = $0 })) {
                    Text("系统时区").tag(TimeZone.current.identifier)
                    if TimeZone.current.identifier != "UTC" { Text("UTC").tag("UTC") }
                    if TimeZone.current.identifier != "Asia/Shanghai" { Text("Asia/Shanghai").tag("Asia/Shanghai") }
                }
                .labelsHidden().controlSize(.small).frame(width: 142)
                Button(action: store.useCurrentTime) { Label("当前时间", systemImage: "clock") }
                    .buttonStyle(.plain).font(.system(size: 11, weight: .medium)).foregroundStyle(PocketStyle.ink)
                    .help("使用当前时间并按所选方式转换")
            }
        }
        .frame(height: 36)
    }

    private var actionBar: some View {
        HStack(spacing: 8) {
            HStack(alignment: .top, spacing: 5) {
                Image(systemName: "info.circle")
                Text(footnote).lineLimit(2)
            }
            .font(.system(size: 10)).foregroundStyle(.secondary)
            Spacer(minLength: 8)
            if [.url, .base64, .aes].contains(store.selected) {
                Button(action: store.reverse) { Image(systemName: "arrow.triangle.2.circlepath") }
                    .buttonStyle(PocketButtonStyle()).disabled(!store.canCopy)
                    .help("将结果作为输入，执行反向转换").accessibilityLabel("反向转换")
            }
            Button(action: store.copyOutput) { Label(store.selected == .qrcode ? "复制图片" : "复制结果", systemImage: "doc.on.doc") }
                .buttonStyle(PocketButtonStyle()).disabled(!store.canCopy)
                .help(store.selected == .aes ? "复制原始结果（⌘⇧C）；JSON 格式化仅影响显示" : "复制结果（⌘⇧C）")
            Button(action: store.process) {
                HStack(spacing: 9) {
                    if store.page.busy { ProgressView().controlSize(.mini) }
                    Text(store.actionTitle).fontWeight(.semibold)
                    Text("⌘↩").font(.system(size: 10, design: .monospaced)).opacity(0.65)
                }
                .padding(.horizontal, 2)
            }
            .buttonStyle(PocketButtonStyle(prominent: true))
            .disabled(store.page.busy || store.input.isEmpty)
        }
    }

    private func errorNotice(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
            Text(message).font(.system(size: 11)).textSelection(.enabled).lineLimit(3)
            Spacer(minLength: 0)
        }
        .padding(11).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.065), in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Color.orange.opacity(0.15)))
        .transition(.opacity)
    }

    private var inputTitle: String {
        store.selected == .aes ? (store.mode == .aesDecrypt ? "密文输入" : "明文输入") : "输入"
    }
    private var outputTitle: String {
        store.selected == .aes ? (store.mode == .aesDecrypt ? "解密结果" : "加密结果") : "结果"
    }
    private var inputPrompt: String {
        switch store.selected {
        case .json: return "输入需要整理的 JSON"
        case .timestamp: return store.mode == .date ? "输入日期或 ISO 8601 时间" : "输入需要转换的时间戳"
        case .url: return store.mode == .urlEncode ? "输入需要编码的文本" : "输入需要解码的 URL 内容"
        case .base64: return store.mode == .base64Encode ? "输入需要编码的文本" : "输入 Base64 文本"
        case .aes: return store.mode == .aesDecrypt ? "输入需要解密的密文" : "输入需要加密的明文"
        case .qrcode: return "输入文本或网址，生成二维码"
        }
    }

    private func editorPanel(title: String, symbol: String, input: Bool) -> some View {
        let text = input ? store.input : store.displayedOutput
        return VStack(spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: symbol).font(.system(size: 12)).foregroundStyle(.secondary)
                Text(title).font(.system(size: 12, weight: .medium))
                Spacer(minLength: 4)
                if input {
                    Button(action: store.paste) { Image(systemName: "doc.on.clipboard") }
                        .help("从剪贴板粘贴（⌘⇧V）").accessibilityLabel("粘贴输入")
                    Button(action: store.clear) { Image(systemName: "trash") }
                        .disabled(text.isEmpty).help("清空输入").accessibilityLabel("清空输入")
                } else {
                    if store.selected == .aes && store.mode == .aesDecrypt {
                        Toggle("格式化 JSON", isOn: Binding(get: { store.prettyAESJSON }, set: { store.prettyAESJSON = $0 }))
                            .toggleStyle(.checkbox).font(.system(size: 10))
                            .help("仅调整显示，复制始终使用原始文本")
                    }
                    HStack(spacing: 5) {
                        Circle().fill(outputPending ? Color.secondary.opacity(0.4) : PocketStyle.ink)
                            .frame(width: 5, height: 5)
                        Text(outputStatus).font(.system(size: 10))
                    }
                    .foregroundStyle(outputPending ? Color.secondary : PocketStyle.ink)
                }
            }
            .buttonStyle(PocketIconButtonStyle())
            .padding(.horizontal, 14).frame(height: 44)
            Rectangle().fill(PocketStyle.line).frame(height: 1)
            CodeEditor(text: input ? Binding(get: { store.input }, set: { store.input = $0 }) : .constant(text),
                       editable: input, label: input ? "输入文本" : "转换结果",
                       json: store.selected == .json || (!input && store.selected == .aes && store.mode == .aesDecrypt && store.prettyAESJSON && store.page.jsonPreview != nil))
                .frame(minHeight: 110)
                .opacity(!input && store.page.dirty ? 0.42 : 1)
                .overlay {
                    if text.isEmpty { emptyEditorState(input: input).allowsHitTesting(false) }
                }
            Rectangle().fill(PocketStyle.line.opacity(0.7)).frame(height: 1)
            HStack {
                Text("\(text.isEmpty ? 0 : text.components(separatedBy: "\n").count) 行")
                Text("·").foregroundStyle(.tertiary)
                Text("\(text.count) 字符")
                Spacer()
                Text(store.selected == .aes && (input == (store.mode == .aesDecrypt)) ? store.aes.format.title : "UTF-8")
                    .fontDesign(.monospaced)
            }
            .font(.system(size: 9)).foregroundStyle(.secondary)
            .padding(.horizontal, 14).frame(height: 27)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .pocketCard()
    }

    private func emptyEditorState(input: Bool) -> some View {
        VStack(spacing: 10) {
            Image(systemName: input ? "text.cursor" : "text.alignleft")
                .font(.system(size: 18, weight: .light)).foregroundStyle(PocketStyle.ink.opacity(0.48))
                .frame(width: 42, height: 42)
                .background(PocketStyle.field, in: RoundedRectangle(cornerRadius: 12))
            Text(input ? inputPrompt : "结果将显示在这里")
                .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
            Text(input ? "⌘V 粘贴内容，或直接输入" : "完成处理后即可复制结果")
                .font(.system(size: 10)).foregroundStyle(.tertiary)
        }
        .padding(16).multilineTextAlignment(.center)
    }

    private var footnote: String {
        switch store.selected {
        case .json: return "支持对象、数组和 JSON 标量"
        case .timestamp: return "支持 ISO 8601 与本地日期"
        case .url: return "URL 组件编码 · + 保留为加号"
        case .base64: return "UTF-8 文本 · 允许 Base64 换行"
        case .aes: return "CBC / PKCS7 · 不含完整性校验"
        case .qrcode: return "停止输入 1 秒后自动生成"
        }
    }
}

private struct ToolNavigationRow: View {
    let tool: DeveloperTool
    let selected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    @State private var hovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                PocketToolIcon(symbol: tool.symbol, emphasized: selected, size: 28)
                Text(tool.title).font(.system(size: 11, weight: selected ? .semibold : .medium))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text("⌘\((DeveloperTool.allCases.firstIndex(of: tool) ?? 0) + 1)")
                    .font(.system(size: 9, design: .monospaced)).foregroundStyle(.tertiary)
                    .opacity(selected || hovered ? 1 : 0)
            }
            .foregroundStyle(selected ? PocketStyle.ink : Color.primary.opacity(0.75))
            .padding(.horizontal, 10).frame(height: 43)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 10).fill(PocketStyle.surface)
                        .shadow(color: .black.opacity(0.025), radius: 3, y: 1)
                        .matchedGeometryEffect(id: "tool-selection", in: namespace)
                } else if hovered {
                    RoundedRectangle(cornerRadius: 10).fill(PocketStyle.surface.opacity(0.55))
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(selected ? PocketStyle.ink.opacity(0.09) : .clear))
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain).onHover { hovered = $0 }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: hovered)
        .accessibilityLabel(tool.title).accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
