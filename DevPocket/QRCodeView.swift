import SwiftUI

struct QRCodeConfigurationView: View {
    @EnvironmentObject private var store: WorkspaceStore

    var body: some View {
        HStack(spacing: 12) {
            Text("图片尺寸").font(.system(size: 11)).foregroundStyle(.secondary)
            PocketSegmentedPicker(title: "二维码图片尺寸", choices: QRCodeSize.allCases,
                                  selection: Binding(get: { store.qrCodeOptions.size }, set: { store.qrCodeOptions.size = $0 }),
                                  label: { $0.title })
                .frame(width: 215)
            Spacer(minLength: 8)
            Text("纠错等级").font(.system(size: 11)).foregroundStyle(.secondary)
            Picker("纠错等级", selection: Binding(get: { store.qrCodeOptions.correction }, set: { store.qrCodeOptions.correction = $0 })) {
                ForEach(QRCodeCorrection.allCases) { level in
                    Text(level.title).tag(level)
                }
            }
            .labelsHidden().controlSize(.small).frame(width: 100)
            .help("纠错等级越高，越能应对污损，可容纳的文本越少；百分比为近似可恢复比例")
        }
        .frame(height: 36)
    }
}

struct QRCodePreviewPanel: View {
    @EnvironmentObject private var store: WorkspaceStore

    private var status: String {
        store.page.busy ? "生成中" : store.page.error != nil ? "生成失败" : store.canCopy ? "已就绪" : store.input.isEmpty ? "等待输入" : "等待生成"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: "qrcode").font(.system(size: 12)).foregroundStyle(.secondary)
                Text("二维码预览").font(.system(size: 12, weight: .medium))
                Spacer(minLength: 4)
                Circle().fill(store.canCopy ? PocketStyle.ink : Color.secondary.opacity(0.4))
                    .frame(width: 5, height: 5)
                Text(status).font(.system(size: 10))
                    .foregroundStyle(store.canCopy ? PocketStyle.ink : Color.secondary)
            }
            .padding(.horizontal, 14).frame(height: 44)
            Rectangle().fill(PocketStyle.line).frame(height: 1)
            Group {
                if store.canCopy, let code = store.page.qrCode, let image = NSImage(data: code.pngData) {
                    Image(nsImage: image).resizable().interpolation(.none).scaledToFit()
                        .frame(maxWidth: 340, maxHeight: 340)
                        .accessibilityLabel("生成的二维码，\(code.pixelSize) 乘 \(code.pixelSize) 像素")
                        .padding(20)
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "qrcode")
                            .font(.system(size: 22, weight: .light)).foregroundStyle(PocketStyle.ink.opacity(0.48))
                            .frame(width: 50, height: 50)
                            .background(PocketStyle.field, in: RoundedRectangle(cornerRadius: 12))
                        Text(store.page.busy ? "正在生成二维码" : store.page.error != nil ? "请调整输入后重试" : store.page.qrCode != nil ? "内容或参数已更新" : "二维码将显示在这里")
                            .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                        Text(store.input.isEmpty ? "输入文本或网址，停顿 1 秒后自动生成" : "停止输入 1 秒后自动生成，可直接扫描或复制")
                            .font(.system(size: 10)).foregroundStyle(.tertiary)
                    }
                    .multilineTextAlignment(.center).padding(16)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Rectangle().fill(PocketStyle.line.opacity(0.7)).frame(height: 1)
            HStack {
                if store.canCopy, let code = store.page.qrCode {
                    Text("\(code.pixelSize) × \(code.pixelSize) px")
                } else {
                    Text("白色背景 · 保留扫码留白")
                }
                Spacer()
                Text("PNG").fontDesign(.monospaced)
            }
            .font(.system(size: 9)).foregroundStyle(.secondary)
            .padding(.horizontal, 14).frame(height: 27)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .pocketCard()
    }
}
