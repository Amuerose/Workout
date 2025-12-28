import SwiftUI

public struct GlassCard<Content: View>: View {
    let title: String?
    let icon: String?
    @ViewBuilder var content: Content
    public init(title: String? = nil, icon: String? = nil, @ViewBuilder content: () -> Content) { self.title = title; self.icon = icon; self.content = content() }
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                HStack(spacing: 8) {
                    if let icon { Image(systemName: icon).foregroundStyle(.secondary) }
                    Text(title).font(.headline)
                    Spacer()
                }
            }
            content
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 6)
    }
}

public struct PrimaryButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.accentColor))
            .foregroundStyle(.white)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

public struct SecondaryButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 12).stroke(Color.accentColor, lineWidth: 1))
            .foregroundStyle(.accentColor)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

public struct ReadinessMiniCard: View {
    let title: String
    let value: String
    let systemImage: String
    public init(title: String, value: String, systemImage: String) { self.title = title; self.value = value; self.systemImage = systemImage }
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack { Image(systemName: systemImage).foregroundStyle(.secondary); Spacer() }
            Text(value).font(.title2).fontWeight(.semibold)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

public struct WeekDay: Identifiable, Hashable {
    public let id = UUID()
    public var date: Date
    public var state: State
    public enum State { case none, scheduled, done, missed }
}

public struct WeekCalendarView: View {
    @Binding var days: [WeekDay]
    var onSelect: (WeekDay) -> Void
    public init(days: Binding<[WeekDay]>, onSelect: @escaping (WeekDay) -> Void) { self._days = days; self.onSelect = onSelect }
    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(days) { day in
                    Button {
                        onSelect(day)
                    } label: {
                        VStack(spacing: 6) {
                            Text(shortWeekday(for: day.date)).font(.caption2).foregroundStyle(.secondary)
                            Text("\(Calendar.current.component(.day, from: day.date))").font(.headline)
                            Circle().fill(color(for: day.state)).frame(width: 8, height: 8)
                        }
                        .padding(10)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
    private func color(for state: WeekDay.State) -> Color {
        switch state {
        case .none: return .clear
        case .scheduled: return .blue
        case .done: return .green
        case .missed: return .orange
        }
    }
    private func shortWeekday(for date: Date) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = "EE"
        return f.string(from: date)
    }
}

public struct ExerciseRow: View {
    @State private var expanded: Bool = false
    public var item: WorkoutExerciseItem
    public var onReplace: (() -> Void)?
    public init(item: WorkoutExerciseItem, onReplace: (() -> Void)? = nil) { self.item = item; self.onReplace = onReplace }
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name).font(.headline)
                    Text("\(item.sets)×\(item.reps)" + (item.durationSec != nil ? " • \(item.durationSec!) сек" : "") )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(item.muscleGroup) • \(item.type)").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: { onReplace?() }) {
                    Image(systemName: "arrow.triangle.2.circlepath").imageScale(.medium)
                }
                .buttonStyle(.plain)
            }
            if expanded {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Техника: \(item.detail.technique)").font(.subheadline)
                    ForEach(item.detail.tips, id: \.self) { tip in Text("• \(tip)").font(.caption) }
                    RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.15)).frame(height: 120).overlay(Text("Видео").foregroundStyle(.secondary))
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            Divider().opacity(0.08)
            HStack {
                Button(expanded ? "Свернуть" : "Подробнее") { withAnimation(.easeInOut) { expanded.toggle() } }
                Spacer()
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
