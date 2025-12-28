# AI Fitness Coach (Today Tab)

A SwiftUI iOS app showcasing a modern "Today" experience for an AI fitness coach.

## Features
- Liquid glass visual style using existing project components (GlassCard, Primary/SecondaryButtonStyle)
- Modular Today feed with dynamic cards:
  - ActivitySummaryCard (steps, active minutes, calories, distance)
  - SleepAdviceCard (sleep hours, quality score + CTA to stretching)
  - StressCard (HRV/stress + breathing CTA)
  - CycleCard (PMS/Ovulation guidance)
  - PregnancyCard (safe recommendations)
  - HydrationCard (progress + add glass)
  - ScheduleCard (calendar reminder)
  - AchievementCard (weekly streak, readiness)
- TodayStore with mock context and ready integration points for HealthKit and AI
- AI Coach chat screen (TodayChatCoachView) with dynamic bottom input (options/slider/date picker)

## Structure
- `WorkoutComponents.swift` — shared UI components (GlassCard, button styles, etc.)
- `TodayStore.swift` — models and business logic for the Today tab
- `TodayView.swift` — main Today feed (modular cards + hero/readiness/plan/quick actions/AI/miniprogress)
- `TodayCards.swift` — reusable card components for the feed
- `TodayChatCoachView.swift` — chat-style AI coach screen
- `ContentView.swift` — app container with TabView (Today tab uses TodayView)
- `CoreInterfaces.swift` — protocols for future integrations (HealthDataProviding, AIChatServing)

## Requirements
- iOS 17+
- Xcode 15+

## Run
1. Open the Xcode project.
2. Build & Run on iOS simulator or device.
3. Open the Today tab.

## GitHub Setup (Quick)
If you haven't pushed yet:
