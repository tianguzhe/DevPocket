import SwiftUI

struct AESConfigurationView: View {
    @EnvironmentObject private var store: WorkspaceStore
    @State private var choosingSource = false
    private var rule: AESKeyRule { store.aes.keyRule }
    private var key: Data? { try? AESEngine.effectiveKey(store.aes) }
    private var effectiveKey: String { key.flatMap { String(data: $0, encoding: .utf8) } ?? "等待有效输入" }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: "key.horizontal").foregroundStyle(PocketStyle.ink)
                Text("密钥配置").fontWeight(.medium)
                Spacer()
                Text(key.map { "AES-\($0.count * 8) · CBC · PKCS7" } ?? "AES · CBC · PKCS7")
                    .font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(PocketStyle.field, in: Capsule())
            }
            .font(.system(size: 11)).frame(height: 20)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 7) {
                    fieldLabel("密钥来源")
                    Button { choosingSource.toggle() } label: {
                        HStack(spacing: 8) {
                            Text(rule.title).font(.system(size: 11, weight: .medium))
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 8, weight: .semibold)).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity).pocketField()
                    }
                    .buttonStyle(.plain).accessibilityLabel("密钥来源").accessibilityValue(rule.title)
                    .popover(isPresented: $choosingSource, arrowEdge: .bottom) {
                        VStack(spacing: 3) {
                            ForEach(AESKeyRule.allCases) { source in
                                Button {
                                    store.selectAESKeyRule(source)
                                    choosingSource = false
                                } label: {
                                    HStack(spacing: 9) {
                                        Text(source.title).font(.system(size: 12, weight: .medium))
                                        Text(source.inputLabel).font(.system(size: 10)).foregroundStyle(.secondary)
                                        Spacer()
                                        if source == rule {
                                            Image(systemName: "checkmark").font(.system(size: 10, weight: .semibold))
                                                .foregroundStyle(PocketStyle.ink)
                                        }
                                    }
                                    .padding(.horizontal, 10).frame(height: 34)
                                    .background(source == rule ? PocketStyle.accentWash : Color.clear,
                                                in: RoundedRectangle(cornerRadius: 7))
                                    .contentShape(RoundedRectangle(cornerRadius: 7))
                                }
                                .buttonStyle(.plain).accessibilityLabel(source.title)
                                .accessibilityAddTraits(source == rule ? [.isSelected] : [])
                            }
                        }
                        .padding(7).frame(width: 220)
                    }
                }
                .frame(width: 142)

                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        fieldLabel(rule.inputLabel)
                        Spacer()
                        if rule == .other {
                            Text("\(store.aes.key.utf8.count) 字节").font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(key == nil ? Color.orange : Color.secondary)
                        }
                    }
                    .frame(height: 12)
                    TextField(rule.placeholder, text: Binding(get: { store.aes.sourceText }, set: { store.aes.sourceText = $0 }))
                        .textFieldStyle(.plain).font(.system(size: 11, design: .monospaced))
                        .autocorrectionDisabled(true).pocketField()
                        .accessibilityLabel(rule.inputLabel).id(rule)
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        fieldLabel("初始向量 IV")
                        Spacer()
                        if store.aes.iv.utf8.count != 16 {
                            Text("\(store.aes.iv.utf8.count) / 16 字节").font(.system(size: 9)).foregroundStyle(.orange)
                        }
                        Button { store.aes.iv = AESOptions.defaultIV } label: {
                            Image(systemName: "arrow.counterclockwise").font(.system(size: 9))
                        }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                        .help("还原默认 IV").accessibilityLabel("还原默认 IV")
                    }
                    .frame(height: 12)
                    TextField("16 字节 UTF-8 向量", text: Binding(get: { store.aes.iv }, set: { store.aes.iv = $0 }))
                        .textFieldStyle(.plain).font(.system(size: 11, design: .monospaced))
                        .autocorrectionDisabled(true).pocketField().accessibilityLabel("AES 初始向量 IV")
                }
                .frame(width: 178)
            }

            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    if rule == .packageName || rule == .channel {
                        HStack(spacing: 6) {
                            Text("有效密钥").foregroundStyle(.secondary)
                            Text(effectiveKey).fontDesign(.monospaced)
                                .foregroundStyle(key == nil ? Color.secondary : PocketStyle.ink)
                                .textSelection(.enabled).lineLimit(1).truncationMode(.middle)
                        }
                        .font(.system(size: 10))
                    } else {
                        Label(key == nil ? "检查密钥长度" : (store.aes.key == AESOptions.defaultKey ? "Other 默认密钥" : "已使用自定义密钥"),
                              systemImage: key == nil ? "circle.dashed" : "checkmark.circle")
                            .font(.system(size: 10)).foregroundStyle(key == nil ? Color.secondary : PocketStyle.ink)
                    }
                    Text(rule.hint).font(.system(size: 9)).foregroundStyle(.secondary)
                        .lineLimit(2).help(rule.hint)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 8) {
                    fieldLabel("密文格式")
                    PocketSegmentedPicker(title: "密文格式", choices: AESCipherFormat.allCases,
                                          selection: Binding(get: { store.aes.format }, set: { store.aes.format = $0 }), label: { $0.title })
                        .frame(width: 124)
                }
            }
            .frame(minHeight: 34)
        }
        .padding(14).pocketCard()
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary).frame(height: 12)
    }
}
