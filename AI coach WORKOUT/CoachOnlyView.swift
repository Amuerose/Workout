import SwiftUI
import HealthKit

struct CoachOnlyView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = TodayCoachStore()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Coach")
                .onAppear { store.onAppear() }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active { store.sceneBecameActive() }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch store.state {
        case .needsPermissions:
            VStack(spacing: 16) {
                Text("Нужен доступ к Здоровью для персонализации плана.")
                    .multilineTextAlignment(.center)
                Button("Разрешить доступ") {
                    Task { await store.refreshIfNeeded() }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        case .loading:
            ProgressView("Готовим план на сегодня...")
                .padding()
        case .noData:
            VStack(alignment: .leading, spacing: 12) {
                summarySection
                noDataPlanSection
            }
            .padding()
        case .ready(let plan):
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    summarySection
                    todayPlanSection(plan)
                    sessionSection(plan)
                    whySection(plan)
                }
                .padding()
            }
        case .error(let message):
            VStack(spacing: 12) {
                Text("Ошибка: \(message)")
                Button("Повторить") { Task { await store.refreshIfNeeded() } }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }

    // MARK: Sections
    private var summarySection: some View {
        Group {
            if let snap = store.snapshot {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Today Summary").font(.headline)
                    HStack(spacing: 16) {
                        Label("Steps: \(snap.stepsToday)", systemImage: "figure.walk")
                        Label("Sleep: \(snap.sleepHoursLastNight.map{ String(format: "%.1f h", $0) } ?? "—")", systemImage: "bed.double.fill")
                        Label("RHR: \(snap.restingHeartRate.map{ String(format: "%.0f", $0) } ?? "—")", systemImage: "heart.fill")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private func todayPlanSection(_ plan: AIPlan) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today Plan").font(.headline)
            Text(plan.title).font(.subheadline)
            if plan.priorities.count >= 1 {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(plan.priorities.prefix(3), id: \.self) { p in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            Text(p)
                        }
                    }
                }
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func sessionSection(_ plan: AIPlan) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("One Session").font(.headline)
            HStack {
                Text("Рекомендуемая сессия: \(plan.session.durationMin) мин")
                Spacer()
                Button("Start \(plan.session.durationMin)–\(max(plan.session.durationMin, plan.session.durationMin+2)) min session") {
                    // TODO: hook into workout session start
                }
                .buttonStyle(.borderedProminent)
            }
            Text("Цель по шагам: \(plan.session.steps)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    private func whySection(_ plan: AIPlan) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Why this plan").font(.headline)
            Text(plan.explanation)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // No data fallback UI
    private var noDataPlanSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today Plan").font(.headline)
            Text("Базовый день: лёгкая прогулка 10–15 минут, вода перед приёмами пищи, растяжка вечером.")
            Button("Start 8–10 min session") { /* start lightweight session */ }
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview { CoachOnlyView() }

