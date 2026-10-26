import Foundation

@main
struct WorkspaceStoreTests {
    @MainActor
    static func finish(_ store: WorkspaceStore) async throws {
        let deadline = Date().addingTimeInterval(5)
        while store.page.busy && Date() < deadline { try await Task.sleep(for: .milliseconds(10)) }
        precondition(!store.page.busy && !store.page.dirty && store.page.error == nil,
                     "Processing \(store.mode) failed: \(store.page.error ?? "timed out or remained dirty")")
    }

    @MainActor
    static func finishAutomaticQRCode(_ store: WorkspaceStore) async throws {
        let deadline = Date().addingTimeInterval(5)
        while let page = store.pages[.qrcode], (page.busy || page.dirty), page.error == nil, Date() < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        let page = store.pages[.qrcode]!
        precondition(!page.busy && !page.dirty && page.error == nil && page.qrCode != nil,
                     "Automatic QR generation failed: \(page.error ?? "timed out")")
    }

    @MainActor
    static func main() async throws {
        let plaintext = #"{"app":"DevPocket","message":"你好，开发者 👋","offline":true}"#
        let ciphertext = "571765f45cd92759afd597fcae4b620d9ca0e4d91b269f978e4b9c6acb6da5333d2567c8dbc173b8c268d9694143241ecd8afc9daec2e792b5ebf8031019553330226970c3dfb3ee19ad78f6e33afd1e"
        let store = WorkspaceStore()
        for tool in DeveloperTool.allCases {
            store.selected = tool
            precondition(store.input.isEmpty && store.page.output.isEmpty && !store.canCopy)
            precondition(store.page.error == nil && !store.page.busy)
        }
        store.selected = .aes
        store.input = ciphertext
        store.process()
        try await finish(store)
        precondition(store.canCopy && store.page.output == plaintext)
        precondition(store.displayedOutput.contains("\n"))
        store.prettyAESJSON = false
        precondition(store.displayedOutput == plaintext && store.canCopy)
        store.prettyAESJSON = true
        // Controls can echo unchanged values during SwiftUI view updates.
        store.input = store.input
        store.mode = store.mode
        store.aes = store.aes
        store.sortKeys = store.sortKeys
        store.timeZoneID = store.timeZoneID
        precondition(store.canCopy)
        store.reverse()
        try await finish(store)
        precondition(store.mode == .aesEncrypt && store.input == plaintext)
        precondition(store.page.output == ciphertext && store.canCopy)
        store.aes.format = .base64
        precondition(store.page.dirty && !store.canCopy)
        store.process()
        try await finish(store)
        store.reverse()
        try await finish(store)
        precondition(store.page.output == plaintext && store.canCopy)
        store.process()
        store.aes.iv = "invalid"
        try await Task.sleep(for: .milliseconds(100))
        precondition(store.page.dirty && !store.canCopy)
        store.aes.iv = AESOptions.defaultIV
        store.process()
        try await finish(store)
        precondition(store.aes.iv == AESOptions.defaultIV && store.aes.format == .base64)
        store.aes.packageName = "Com.Example.App"
        store.aes.channelName = "ExampleChannel"
        store.aes.keyRule = .packageName
        precondition(store.aes.sourceText == "Com.Example.App")
        store.aes.keyRule = .channel
        precondition(store.aes.sourceText == "ExampleChannel")
        store.aes.sourceText = "SecondChannel"
        precondition(store.aes.packageName == "Com.Example.App" && store.aes.channelName == "SecondChannel")
        store.selectAESKeyRule(.other)
        precondition(store.aes.keyRule == .other && store.aes.sourceText == AESOptions.defaultKey)
        precondition(store.aes.packageName == "Com.Example.App" && store.aes.channelName == "SecondChannel")
        // Other now doubles as direct-key input. Explicitly reselecting it
        // must reset the key, including when the source is already Other.
        store.aes.sourceText = "0123456789abcdef"
        precondition(store.aes.key == "0123456789abcdef" && store.aes.sourceText == "0123456789abcdef")
        precondition(store.page.dirty && !store.canCopy)
        store.aes = store.aes
        precondition(store.aes.key == "0123456789abcdef")
        store.aes.iv = "abcdefghijklmnop"
        store.selectAESKeyRule(.other)
        precondition(store.aes.key == AESOptions.defaultKey && store.aes.iv == "abcdefghijklmnop")
        precondition(store.aes.format == .base64)
        store.aes.sourceText = "abcdefghijklmnopqrstuvwx"
        store.selectAESKeyRule(.channel)
        precondition(store.aes.channelName == "SecondChannel")
        store.selectAESKeyRule(.other)
        precondition(store.aes.key == AESOptions.defaultKey)
        store.aes.sourceText = "0123456789abcdef0123456789abcdef"
        precondition(store.aes.keyRule == .other && store.aes.key.utf8.count == 32)
        store.selectAESKeyRule(.other)
        precondition(store.aes.key == AESOptions.defaultKey)
        precondition(AESKeyRule.allCases.count == 3)
        store.aes.keyRule = .packageName
        precondition(store.aes.sourceText == "Com.Example.App")
        store.selectAESKeyRule(.other)
        store.aes.iv = AESOptions.defaultIV
        store.aes.format = .hex
        store.input = ciphertext
        store.process()
        try await finish(store)
        store.selected = .json
        precondition(store.input.isEmpty && !store.canCopy)
        store.input = #"{"b":2,"a":1}"#
        store.process()
        try await finish(store)
        precondition(store.canCopy)
        store.selected = .timestamp
        for mode in [ToolMode.seconds, .milliseconds, .date] {
            store.mode = mode
            let before = Date().timeIntervalSince1970
            store.useCurrentTime()
            try await finish(store)
            precondition(store.canCopy)
            if mode == .seconds { precondition(abs(Double(store.input)! - before) < 5) }
            if mode == .milliseconds { precondition(abs(Double(store.input)! - before * 1000) < 5000) }
        }
        store.selected = .aes
        precondition(store.page.output == plaintext && store.canCopy)
        store.selected = .qrcode
        precondition(store.input.isEmpty && store.page.qrCode == nil && !store.canCopy)
        store.input = "https://example.com/二维码?hello=👋"
        store.process()
        try await finish(store)
        precondition(store.canCopy && store.page.qrCode?.pixelSize == 512)
        let originalPNG = store.page.qrCode!.pngData
        store.qrCodeOptions = store.qrCodeOptions
        precondition(store.canCopy)
        store.qrCodeOptions.size = .large
        precondition(store.page.dirty && !store.canCopy)
        store.process()
        try await finish(store)
        precondition(store.page.qrCode?.pixelSize == 1024 && store.page.qrCode?.pngData != originalPNG)
        store.qrCodeOptions.correction = .high
        precondition(!store.canCopy)
        store.process()
        store.input = "updated while generating"
        try await Task.sleep(for: .milliseconds(100))
        precondition(store.page.dirty && !store.canCopy)
        store.process()
        try await finish(store)
        let latestPNG = store.page.qrCode!.pngData
        store.selected = .json
        precondition(store.canCopy)
        store.selected = .qrcode
        precondition(store.input == "updated while generating" && store.page.qrCode?.pngData == latestPNG && store.canCopy)
        store.clear()
        precondition(!store.canCopy && store.input.isEmpty)
        store.input = String(repeating: "a", count: 1300)
        store.process()
        let deadline = Date().addingTimeInterval(5)
        while store.page.busy && Date() < deadline { try await Task.sleep(for: .milliseconds(10)) }
        precondition(!store.page.busy && store.page.error?.contains("容量") == true && !store.canCopy)
        store.input = "first automatic edit"
        try await Task.sleep(for: .milliseconds(600))
        store.input = "latest automatic edit"
        try await Task.sleep(for: .milliseconds(600))
        precondition(store.page.dirty && !store.page.busy && !store.canCopy, "Typing must reset the one-second delay")
        try await finishAutomaticQRCode(store)
        precondition(store.canCopy && store.input == "latest automatic edit")
        let expected = try QRCodeEngine.generate(store.input, options: store.qrCodeOptions)
        precondition(store.page.qrCode?.pngData == expected.pngData, "Generate the latest input")
        store.qrCodeOptions.size = .small
        precondition(!store.canCopy)
        try await finishAutomaticQRCode(store)
        precondition(store.page.qrCode?.pixelSize == 256)
        store.qrCodeOptions.correction = .low
        try await finishAutomaticQRCode(store)
        precondition(store.canCopy)
        store.input = "generate after switching tools"
        store.selected = .json
        try await finishAutomaticQRCode(store)
        precondition(store.selected == .json && store.canCopy)
        store.selected = .qrcode
        precondition(store.canCopy && store.input == "generate after switching tools")
        store.input = "cancel when clearing"
        store.clear()
        try await Task.sleep(for: .milliseconds(1200))
        precondition(store.input.isEmpty && store.page.qrCode == nil && !store.page.busy && store.page.error == nil)
        print("PASS: one-second QR debounce, latest input, automatic option updates, background page generation and clear cancellation")
        print("PASS: QR image state, size/correction edits, stale requests, page retention, clear and capacity errors")
        print("PASS: blank workspaces, AES raw/JSON preview, no-op edits, reverse conversions, stale requests, independent scenario inputs, editable Other/reset, current time and page retention")
    }
}
