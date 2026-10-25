import Foundation

@main
struct WorkspaceStoreTests {
    @MainActor
    static func finish(_ store: WorkspaceStore) async throws {
        let deadline = Date().addingTimeInterval(5)
        while store.page.busy && Date() < deadline { try await Task.sleep(for: .milliseconds(10)) }
        precondition(!store.page.busy && !store.page.dirty && store.page.error == nil)
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
        print("PASS: blank workspaces, AES raw/JSON preview, no-op edits, reverse conversions, stale requests, independent scenario inputs, editable Other/reset, current time and page retention")
    }
}
