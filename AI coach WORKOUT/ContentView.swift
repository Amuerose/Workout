import SwiftUI

public struct ContentView: View {
    @State private var chat = AIChatState()
    @State private var selectedTab: Tab = .chat

    public init() {}

    enum Tab: Hashable {
        case chat
        case tasks
        case profile
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            CoachScreen(chat: chat)
                .tabItem {
                    Label("Чат", systemImage: "bubble.left.and.bubble.right.fill")
                }
                .tag(Tab.chat)

            TasksPlaceholder()
                .tabItem {
                    Label("Задачи", systemImage: "checklist")
                }
                .tag(Tab.tasks)

            ProfilePlaceholder()
                .tabItem {
                    Label("Профиль", systemImage: "person.crop.circle")
                }
                .tag(Tab.profile)
        }
        // Liquid Glass effect for the tab bar background where supported
        .background(.ultraThinMaterial)
    }
}

private struct CoachScreen: View {
    var chat: AIChatState
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(chat.messages) { msg in
                                HStack {
                                    if msg.isUser { Spacer() }
                                    Text(msg.text)
                                        .padding(12)
                                        .background(msg.isUser ? .thinMaterial : .ultraThinMaterial)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                    if !msg.isUser { Spacer() }
                                }
                                .id(msg.id)
                            }
                        }
                        .padding(12)
                    }
                    .onChange(of: chat.messages.count) { _, _ in
                        if let last = chat.messages.last?.id { withAnimation { proxy.scrollTo(last, anchor: .bottom) } }
                    }
                }
            }
            .navigationTitle("ИИ‑коуч")
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Divider().opacity(0.2)
                    HStack(spacing: 8) {
                        TextField("Сообщение коучу", text: Binding(get: { chat.draft }, set: { chat.draft = $0 }), axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .submitLabel(.send)
                            .onSubmit { chat.send() }
                        Button { chat.send() } label: {
                            Image(systemName: "paperplane.fill")
                                .font(.title3)
                                .symbolRenderingMode(.hierarchical)
                        }
                        .disabled(chat.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        if chat.isSending { ProgressView() }
                    }
                    .padding()
                    // Liquid Glass input bar
                    .background(.ultraThinMaterial)
                }
            }
        }
    }
}

// Simple placeholders for other tabs with Liquid Glass styling
private struct TasksPlaceholder: View {
    var body: some View {
        NavigationStack {
            ZStack {
                // Background to better show the glass effect
                LinearGradient(colors: [.blue.opacity(0.3), .purple.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                VStack(spacing: 16) {
                    Text("Задачи")
                        .font(.largeTitle.bold())
                        .padding()
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    Text("Здесь будет список задач")
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding()
            }
            .navigationTitle("Задачи")
        }
    }
}
private struct ProfilePlaceholder: View {
    var body: some View {
        NavigationStack {
            ZStack {
                RadialGradient(colors: [.orange.opacity(0.25), .red.opacity(0.25)], center: .center, startRadius: 50, endRadius: 400)
                    .ignoresSafeArea()
                VStack(spacing: 16) {
                    Text("Профиль")
                        .font(.largeTitle.bold())
                        .padding()
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    Text("Настройки профиля и статистика")
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding()
            }
            .navigationTitle("Профиль")
        }
    }
}

