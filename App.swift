import SwiftUI

@main
struct DiscordTranslateApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                DiscordWebView()
                    .tabItem { Label("账号登录", systemImage: "person.crop.circle") }
                RootView()
                    .tabItem { Label("Bot版", systemImage: "cpu") }
            }
        }
    }
}
