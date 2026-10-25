import AppKit
import SwiftUI

struct ToolPage {
    var input: String
    var mode: ToolMode
    var output = ""
    var error: String?
    var sortKeys = true
    var dirty = false
    var busy = false
    var timeZoneID = TimeZone.current.identifier
    var aes = AESOptions()
    var prettyAESJSON = true
    var jsonPreview: String?
}

private struct ProcessedOutput: Sendable {
    let raw: String
    let jsonPreview: String?
}

@MainActor
final class WorkspaceStore: ObservableObject {
    @Published var selected: DeveloperTool = .json
    @Published var pages: [DeveloperTool: ToolPage] = [:]
    @Published var toast: String?
    private var requests: [DeveloperTool: UUID] = [:]
    private var toastID = UUID()

    init() {
        for tool in DeveloperTool.allCases {
            pages[tool] = ToolPage(input: "", mode: tool.modes[0])
        }
    }

    var page: ToolPage { pages[selected]! }
    var input: String {
        get { page.input }
        set {
            guard newValue != page.input else { return }
            edit { $0.input = newValue }
        }
    }
    var mode: ToolMode {
        get { page.mode }
        set {
            guard newValue != page.mode else { return }
            edit { $0.mode = newValue }
        }
    }
    var sortKeys: Bool {
        get { page.sortKeys }
        set {
            guard newValue != page.sortKeys else { return }
            edit { $0.sortKeys = newValue }
        }
    }
    var timeZoneID: String {
        get { page.timeZoneID }
        set {
            guard newValue != page.timeZoneID else { return }
            edit { $0.timeZoneID = newValue }
        }
    }
    var aes: AESOptions {
        get { page.aes }
        set {
            guard newValue != page.aes else { return }
            edit { $0.aes = newValue }
        }
    }
    var prettyAESJSON: Bool {
        get { page.prettyAESJSON }
        set { pages[selected]?.prettyAESJSON = newValue }
    }
    var displayedOutput: String {
        if selected == .aes, mode == .aesDecrypt, page.prettyAESJSON, let preview = page.jsonPreview { return preview }
        return page.output
    }
    var actionTitle: String {
        selected == .aes ? (mode == .aesDecrypt ? "解密文本" : "加密文本") : selected.actionTitle
    }
    nonisolated private static func jsonPreview(_ text: String) -> String? {
        try? ToolEngine.run(ToolRequest(mode: .jsonPretty, input: text, sortKeys: false))
    }
    var canCopy: Bool { !page.output.isEmpty && !page.dirty && !page.busy && page.error == nil }

    private func edit(_ update: (inout ToolPage) -> Void) {
        var changed = page
        update(&changed)
        changed.dirty = true
        changed.error = nil
        changed.busy = false
        requests[selected] = UUID() // A result for older input must never replace this page.
        pages[selected] = changed
    }

    func process() {
        let tool = selected
        let snapshot = page
        let request = ToolRequest(mode: snapshot.mode, input: snapshot.input,
                                  sortKeys: snapshot.sortKeys, timeZoneID: snapshot.timeZoneID, aes: snapshot.aes)
        let requestID = UUID()
        requests[tool] = requestID
        pages[tool]?.busy = true
        pages[tool]?.error = nil
        Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) { () -> Result<ProcessedOutput, ToolFailure> in
                do {
                    let raw = try ToolEngine.run(request)
                    return .success(ProcessedOutput(raw: raw, jsonPreview: request.mode == .aesDecrypt ? Self.jsonPreview(raw) : nil))
                }
                catch {
                    let details = (error as NSError).userInfo[NSDebugDescriptionErrorKey] as? String
                    return .failure(ToolFailure(message: details ?? error.localizedDescription))
                }
            }.value
            guard let self, self.requests[tool] == requestID else { return }
            self.pages[tool]?.busy = false
            switch result {
            case .success(let output):
                self.pages[tool]?.output = output.raw
                self.pages[tool]?.jsonPreview = output.jsonPreview
                self.pages[tool]?.dirty = false
            case .failure(let error):
                self.pages[tool]?.error = error.message
                self.pages[tool]?.dirty = true
            }
        }
    }

    func paste() {
        guard let text = NSPasteboard.general.string(forType: .string) else {
            notify("剪贴板中没有文本")
            return
        }
        input = text
        notify("已从剪贴板粘贴")
    }

    func copyOutput() {
        guard canCopy else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(page.output, forType: .string)
        notify("已复制到剪贴板")
    }

    func clear() { input = "" }

    func useCurrentTime() {
        guard selected == .timestamp else { return }
        let now = Date()
        switch mode {
        case .seconds: input = "\(Int64(now.timeIntervalSince1970))"
        case .milliseconds: input = "\(Int64(now.timeIntervalSince1970 * 1000))"
        case .date: input = ISO8601DateFormatter().string(from: now)
        default: return
        }
        process()
    }

    func reverse() {
        guard canCopy, [.url, .base64, .aes].contains(selected) else { return }
        let result = page.output
        let nextMode: ToolMode
        switch mode {
        case .urlEncode: nextMode = .urlDecode
        case .urlDecode: nextMode = .urlEncode
        case .base64Encode: nextMode = .base64Decode
        case .aesDecrypt: nextMode = .aesEncrypt
        case .aesEncrypt: nextMode = .aesDecrypt
        default: nextMode = .base64Encode
        }
        input = result
        mode = nextMode
        process()
    }

    func selectAESKeyRule(_ rule: AESKeyRule) {
        var options = aes
        options.keyRule = rule
        // Reset on an explicit selection, even when Other is already selected.
        // Ordinary view updates and edits must never reset the user's key.
        if rule == .other { options.key = AESOptions.defaultKey }
        aes = options
    }

    private func notify(_ message: String) {
        let id = UUID()
        toastID = id
        toast = message
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard let self, self.toastID == id else { return }
            self.toast = nil
        }
    }
}
