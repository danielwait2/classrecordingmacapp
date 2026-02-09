//
//  CalendarService.swift
//  Sponge
//

import Foundation
import EventKit

class CalendarService: ObservableObject {

    static let shared = CalendarService()

    private let eventStore = EKEventStore()
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined

    private init() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    // MARK: - Authorization

    func requestCalendarAccess() async -> Bool {
        return await withCheckedContinuation { continuation in
            eventStore.requestAccess(to: .event) { granted, _ in
                Task { @MainActor in
                    self.authorizationStatus = granted ? .authorized : .denied
                }
                continuation.resume(returning: granted)
            }
        }
    }

    // MARK: - Class Detection

    /// Detect which class is currently happening based on calendar events
    func detectCurrentClass(from classes: [SDClass]) -> SDClass? {
        guard isAuthorized else { return nil }

        let now = Date()
        let currentEvent = findEventAtTime(now)

        guard let event = currentEvent else { return nil }

        // Try to match calendar event to a class
        return matchEventToClass(event, classes: classes)
    }

    /// Find upcoming class within the next hour
    func detectUpcomingClass(from classes: [SDClass], within minutes: Int = 60) -> (classModel: SDClass, startsIn: TimeInterval)? {
        guard isAuthorized else { return nil }

        let now = Date()
        let futureDate = now.addingTimeInterval(TimeInterval(minutes * 60))

        let upcomingEvents = findEventsInRange(start: now, end: futureDate)

        // Find the earliest upcoming event that matches a class
        for event in upcomingEvents.sorted(by: { $0.startDate < $1.startDate }) {
            if let matchedClass = matchEventToClass(event, classes: classes) {
                let timeUntilStart = event.startDate.timeIntervalSince(now)
                return (matchedClass, timeUntilStart)
            }
        }

        return nil
    }

    // MARK: - Private Helpers

    private var isAuthorized: Bool {
        return authorizationStatus == .authorized
    }

    private func findEventAtTime(_ date: Date) -> EKEvent? {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = eventStore.predicateForEvents(
            withStart: startOfDay,
            end: endOfDay,
            calendars: nil
        )

        let events = eventStore.events(matching: predicate)

        // Find event that contains the current time
        return events.first { event in
            event.startDate <= date && event.endDate >= date
        }
    }

    private func findEventsInRange(start: Date, end: Date) -> [EKEvent] {
        let predicate = eventStore.predicateForEvents(
            withStart: start,
            end: end,
            calendars: nil
        )

        return eventStore.events(matching: predicate)
    }

    private func matchEventToClass(_ event: EKEvent, classes: [SDClass]) -> SDClass? {
        let eventTitle = event.title.lowercased()

        // Try to find exact or partial match
        for classModel in classes {
            let className = classModel.name.lowercased()

            // Check for exact match
            if eventTitle == className {
                return classModel
            }

            // Check if event title contains class name
            if eventTitle.contains(className) {
                return classModel
            }

            // Check if class name contains event title (for abbreviated names)
            if className.contains(eventTitle) && eventTitle.count > 3 {
                return classModel
            }

            // Check for common abbreviations and course codes
            // e.g., "CS 101" matches "Computer Science 101"
            let eventWords = eventTitle.components(separatedBy: .whitespaces)
            let classWords = className.components(separatedBy: .whitespaces)

            // Look for course code patterns (e.g., "CS101", "MATH 205")
            for eventWord in eventWords {
                for classWord in classWords {
                    if eventWord == classWord && eventWord.count >= 3 {
                        return classModel
                    }
                }
            }
        }

        return nil
    }
}
