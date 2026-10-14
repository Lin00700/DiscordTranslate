import SwiftUI

struct RootView: View {
    @AppStorage("token") private var token = ""
    @State private var showSettings = false
    var body: some View {
        NavigationView {
            Group {
                if token.isEmpty {
                    VStack(spacing: 16) {
                        Text("请先填写 Discord Bot Token").font(.headline)
                        Button("打开设置") { showSettings = true }
                    }
                } else {
                    GuildListView()
                }
            }
            .navigationTitle("Discord翻译")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                }
            }
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: $showSettings) { SettingsView() }
        .onAppear { if token.isEmpty { showSettings = true } }
    }
}

struct GuildListView: View {
    @State private var guilds: [Guild] = []
    @State private var error: String?
    var body: some View {
        List {
            if let error { Text(error).foregroundColor(.red) }
            ForEach(guilds) { g in
                NavigationLink(g.name) { ChannelListView(guild: g) }
            }
        }
        .refreshable { await load() }
        .task { await load() }
    }
    func load() async {
        do { guilds = try await DiscordAPI.guilds(); error = nil }
        catch { self.error = error.localizedDescription }
    }
}

struct ChannelListView: View {
    let guild: Guild
    @State private var channels: [Channel] = []
    @State private var error: String?
    var body: some View {
        List {
            if let error { Text(error).foregroundColor(.red) }
            ForEach(channels) { c in
                NavigationLink("# " + (c.name ?? c.id)) { MessageListView(channel: c) }
            }
        }
        .navigationTitle(guild.name)
        .refreshable { await load() }
        .task { await load() }
    }
    func load() async {
        do { channels = try await DiscordAPI.channels(guild.id); error = nil }
        catch { self.error = error.localizedDescription }
    }
}

@MainActor
final class MessagesVM: ObservableObject {
    @Published var messages: [Message] = []
    @Published var translations: [String: String] = [:]
    @Published var error: String?
    private var inFlight = Set<String>()

    func load(channel: String, auto: Bool) async {
        do {
            messages = try await DiscordAPI.messages(channel)
            error = nil
        } catch { self.error = error.localizedDescription; return }
        if auto { for m in messages { await translate(m) } }
    }

    func translate(_ m: Message, force: Bool = false) async {
        guard !m.content.isEmpty else { return }
        if !force && (translations[m.id] != nil || inFlight.contains(m.id)) { return }
        inFlight.insert(m.id)
        defer { inFlight.remove(m.id) }
        if let t = try? await Translator.translate(m.content) { translations[m.id] = t }
    }
}

struct MessageListView: View {
    let channel: Channel
    @StateObject private var vm = MessagesVM()
    @AppStorage("autoTranslate") private var auto = true

    var body: some View {
        List {
            if let e = vm.error { Text(e).foregroundColor(.red) }
            ForEach(vm.messages) { m in
                VStack(alignment: .leading, spacing: 4) {
                    Text(m.author.global_name ?? m.author.username).font(.caption).foregroundColor(.secondary)
                    Text(m.content.isEmpty ? "（无文字内容）" : m.content)
                    if let t = vm.translations[m.id] {
                        Text(t).foregroundColor(.blue)
                    } else if !m.content.isEmpty {
                        Button("翻译") { Task { await vm.translate(m, force: true) } }
                            .font(.caption)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .navigationTitle("# " + (channel.name ?? ""))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Toggle("自动翻译", isOn: $auto).labelsHidden()
            }
        }
        .refreshable { await vm.load(channel: channel.id, auto: auto) }
        .task(id: auto) {
            await vm.load(channel: channel.id, auto: auto)
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 6_000_000_000)
                await vm.load(channel: channel.id, auto: auto)
            }
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("token") private var token = ""
    @AppStorage("targetLang") private var lang = "zh-CN"
    @AppStorage("engine") private var engine = "google"
    @AppStorage("libreURL") private var libreURL = ""
    @AppStorage("libreKey") private var libreKey = ""
    @AppStorage("autoTranslate") private var auto = true

    var body: some View {
        NavigationView {
            Form {
                Section("Discord Bot Token") {
                    SecureField("粘贴 Bot Token", text: $token)
                }
                Section("翻译") {
                    Toggle("自动翻译", isOn: $auto)
                    Picker("目标语言", selection: $lang) {
                        Text("简体中文").tag("zh-CN")
                        Text("繁體中文").tag("zh-TW")
                        Text("English").tag("en")
                        Text("日本語").tag("ja")
                        Text("한국어").tag("ko")
                    }
                    Picker("翻译引擎", selection: $engine) {
                        Text("Google（免费）").tag("google")
                        Text("LibreTranslate").tag("libre")
                    }
                    if engine == "libre" {
                        TextField("服务地址 https://...", text: $libreURL)
                            .autocapitalization(.none).disableAutocorrection(true)
                        SecureField("API Key（可选）", text: $libreKey)
                    }
                }
                Section(footer: Text("Bot 需在开发者后台开启 Message Content Intent，并被邀请进目标服务器。")) { EmptyView() }
            }
            .navigationTitle("设置")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
    }
}
