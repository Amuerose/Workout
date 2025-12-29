import SwiftUI

public struct ResponseBar: View {
    @ObservedObject var store: TodayCoachStore
    @State private var sliderValue: Double = 0
    @State private var numberText: String = ""
    @State private var dateValue: Date = Date()
    @State private var showDateSheet: Bool = false
    public var userStateProvider: () -> UserState

    public init(store: TodayCoachStore, userStateProvider: @escaping () -> UserState) {
        self.store = store
        self.userStateProvider = userStateProvider
    }

    public var body: some View {
        Group {
            switch store.activeWidget {
            case .none:
                EmptyView()
            case .some(let w):
                content(for: w)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .sheet(isPresented: $showDateSheet) {
            VStack {
                DatePicker("", selection: $dateValue, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                Button("Готово") {
                    showDateSheet = false
                    Task {
                        await store.submitReply(widgetId: currentId, value: AnyCodable(ISO8601DateFormatter().string(from: dateValue)), userState: userStateProvider())
                    }
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
            .presentationDetents([.medium])
        }
    }

    private var currentId: String {
        switch store.activeWidget {
        case .buttons(let id, _, _): return id
        case .slider(let id, _, _, _, _, _, _): return id
        case .number(let id, _, _, _, _, _): return id
        case .date_time(let id, _, _): return id
        case .none: return ""
        }
    }

    @ViewBuilder
    private func content(for widget: Widget) -> some View {
        switch widget {
        case .buttons(_, let title, let options):
            VStack(alignment: .leading, spacing: 10) {
                Text(title).font(.headline)
                ForEach(options, id: \.self) { opt in
                    Button(opt.label) {
                        Task {
                            await store.submitReply(widgetId: currentId, value: AnyCodable(opt.value), userState: userStateProvider())
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        case .slider(_, let title, let min, let max, let step, let unit, let def):
            VStack(alignment: .leading, spacing: 10) {
                Text(title).font(.headline)
                Slider(value: Binding(get: {
                    sliderValue == 0 && def != nil ? def! : sliderValue
                }, set: { newValue in
                    sliderValue = newValue
                }), in: min...max, step: step)
                HStack {
                    Text("Значение: \(Int(sliderValue == 0 && def != nil ? def! : sliderValue)) \(unit)")
                    Spacer()
                    Button("Готово") {
                        Task {
                            await store.submitReply(widgetId: currentId, value: AnyCodable(sliderValue == 0 && def != nil ? def! : sliderValue), userState: userStateProvider())
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        case .number(_, let title, let min, let max, let step, let unit):
            VStack(alignment: .leading, spacing: 10) {
                Text(title).font(.headline)
                TextField(unit ?? "", text: $numberText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                Button("Готово") {
                    let val = Double(numberText) ?? 0
                    Task {
                        await store.submitReply(widgetId: currentId, value: AnyCodable(val), userState: userStateProvider())
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        case .date_time(_, let title, _):
            VStack(alignment: .leading, spacing: 10) {
                Text(title).font(.headline)
                Button("Выбрать дату/время") {
                    showDateSheet = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}
