import SwiftUI
import Observation

// MARK: - Models
public enum CoachInputKind: Equatable {
    case options([String])
    case slider(range: ClosedRange<Double>, step: Double, unit: String)
    case date
    case none
}

public struct CoachMessage: Identifiable, Equatable {
    public enum Role { case coach, system }
    public let id: UUID = UUID()
    public var role: Role
    public var text: String
    public var input: CoachInputKind = .none
    public init(role: Role, text: String, input: CoachInputKind = .none) { self.role = role; self.text = text; self.input = input }
}

@Observable
public final class TodayChatCoachStore {
    public var messages: [CoachMessage] = []
    public var currentInput: CoachInputKind = .none
    public var sliderValue: Double = 5
    public var selectedDate: Date = Date()

    public init() {
        // Seed conversation
        append(.init(role: .system, text: "Сегодня"))
        askRecommendation()
    }

    public func append(_ msg: CoachMessage) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            messages.append(msg)
        }
    }

    public func askRecommendation() {
        let m1 = CoachMessage(role: .coach, text: "Как ты сегодня? Выбери вариант:", input: .options(["Отлично", "Нормально", "Устал"]))
        append(m1)
        currentInput = m1.input
    }

    public func handleOption(_ title: String) {
        // Echo selection and branch next
        append(.init(role: .system, text: "Ответ: \(title)"))
        switch title {
        case "Отлично":
            let msg = CoachMessage(role: .coach, text: "Выбери длительность сессии", input: .slider(range: 5...40, step: 5, unit: "мин"))
            append(msg); currentInput = msg.input; sliderValue = 20
        case "Нормально":
            let msg = CoachMessage(role: .coach, text: "Запланируем время?", input: .date)
            append(msg); currentInput = msg.input
        default:
            let msg = CoachMessage(role: .coach, text: "Сделаем восстановление 8 минут?", input: .options(["Да", "Нет"]))
            append(msg); currentInput = msg.input
        }
    }

    public func handleSliderConfirm() {
        append(.init(role: .system, text: "Длительность: \(Int(sliderValue)) мин"))
        recommendWorkout(duration: Int(sliderValue))
        currentInput = .none
    }

    public func handleDateConfirm() {
        let f = DateFormatter(); f.dateStyle = .none; f.timeStyle = .short
        append(.init(role: .system, text: "Время: \(f.string(from: selectedDate))"))
        append(.init(role: .coach, text: "Запланировал. Готов к небольшому разогреву?", input: .options(["Да", "Позже"])) )
        currentInput = .options(["Да", "Позже"]) // keep panel visible
    }

    public func handleSimpleConfirm(_ answer: String) {
        append(.init(role: .system, text: answer))
        if answer == "Да" { recommendWorkout(duration: 8) } else { append(.init(role: .coach, text: "Хорошо, вернёмся позже.")) }
        currentInput = .none
    }

    private func recommendWorkout(duration: Int) {
        append(.init(role: .coach, text: "Рекомендация: \(duration) мин • лёгкая • цель: техника"))
        append(.init(role: .coach, text: "Начинаем?", input: .options(["Старт", "Изменить"])) )
        currentInput = .options(["Старт", "Изменить"]) // show next choices
    }
}

// MARK: - View
public struct TodayChatCoachView: View {
    @State private var store = TodayChatCoachStore()
    @Namespace private var ns
    @State private var showInput: Bool = true

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            messagesList
            inputPanel
        }
        .animation(.easeInOut(duration: 0.25), value: store.currentInput)
        .onChange(of: store.currentInput) { _, newValue in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { showInput = newValue != .none }
        }
    }

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(store.messages) { msg in
                        MessageBubble(message: msg)
                            .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
                            .id(msg.id)
                    }
                }
                .padding(16)
            }
            .onChange(of: store.messages.count) { _, _ in
                if let last = store.messages.last?.id { withAnimation { proxy.scrollTo(last, anchor: .bottom) } }
            }
        }
    }

    // MARK: - Input Panel
    private var inputPanel: some View {
        Group {
            switch store.currentInput {
            case .options(let items): OptionsPanel(options: items) { title in store.handleOption(title) }
            case .slider(let range, let step, let unit): SliderPanel(value: $store.sliderValue, range: range, step: step, unit: unit) { store.handleSliderConfirm() }
            case .date: DatePanel(date: $store.selectedDate) { store.handleDateConfirm() }
            case .none: EmptyView()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, showInput ? 12 : 0)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .opacity(showInput ? 1 : 0)
        .offset(y: showInput ? 0 : 16)
    }
}

// MARK: - Message Bubble
private struct MessageBubble: View {
    let message: CoachMessage
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message.text)
                .font(message.role == .system ? .subheadline : .body)
                .foregroundStyle(message.role == .system ? .secondary : .primary)
        }
        .padding(12)
        .background(message.role == .system ? .ultraThinMaterial : .thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Input Panels
private struct OptionsPanel: View {
    let options: [String]
    var select: (String) -> Void
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options, id: \.self) { title in
                    Button(action: { select(title) }) {
                        Text(title)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

private struct SliderPanel: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String
    var confirm: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(Int(value)) \(unit)").font(.headline)
                Spacer()
                Button("Ок") { confirm() }.buttonStyle(.borderedProminent)
            }
            Slider(value: $value, in: range, step: step)
        }
        .padding(.horizontal, 4)
    }
}

private struct DatePanel: View {
    @Binding var date: Date
    var confirm: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(date, style: .time).font(.headline)
                Spacer()
                Button("Ок") { confirm() }.buttonStyle(.borderedProminent)
            }
            DatePicker("Время", selection: $date, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
        }
        .padding(.horizontal, 4)
    }
}

#Preview {
    TodayChatCoachView()
}
