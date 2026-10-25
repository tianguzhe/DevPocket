import SwiftUI

extension Notification.Name {
    static let focusToolSearch = Notification.Name("DevPocket.focusToolSearch")
}

@main
struct DevPocketApp: App {
    @StateObject private var store = WorkspaceStore()
    @AppStorage("appearance") private var appearance = "system"

    var body: some Scene {
        Window("DevPocket", id: "main") {
            ContentView().environmentObject(store)
                .preferredColorScheme(appearance == "dark" ? .dark : appearance == "light" ? .light : nil)
        }
        .defaultSize(width: 1120, height: 760)
        .defaultPosition(.center)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .toolbar) {
                Picker("外观", selection: $appearance) {
                    Text("跟随系统").tag("system")
                    Text("浅色").tag("light")
                    Text("深色").tag("dark")
                }
            }
            CommandMenu("工具") {
                Button("处理当前内容") { store.process() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(store.page.busy || store.input.isEmpty)
                Button("复制结果") { store.copyOutput() }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                    .disabled(!store.canCopy)
                Button("从剪贴板粘贴") { store.paste() }
                    .keyboardShortcut("v", modifiers: [.command, .shift])
                Divider()
                Button("搜索工具") { NotificationCenter.default.post(name: .focusToolSearch, object: nil) }
                    .keyboardShortcut("k", modifiers: .command)
                ForEach(Array(DeveloperTool.allCases.enumerated()), id: \.element.id) { index, tool in
                    Button(tool.title) { store.selected = tool }
                        .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: .command)
                }
            }
        }
    }
}
