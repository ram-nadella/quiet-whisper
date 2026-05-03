import XCTest
@testable import QuietWhisper

final class DateGroupingTests: XCTestCase {

    private let calendar = Calendar.current

    private func date(daysAgo: Int, hour: Int = 12, relativeTo now: Date) -> Date {
        let startOfNow = calendar.startOfDay(for: now)
        let day = startOfNow.addingTimeInterval(TimeInterval(-daysAgo * 86_400))
        return calendar.date(byAdding: .hour, value: hour, to: day) ?? day
    }

    func testEmptyInputProducesEmptyOutput() {
        let groups = DateGrouping.group([Date](), by: { $0 })
        XCTAssertTrue(groups.isEmpty)
    }

    func testTodayBucketContainsAllOfToday() {
        let now = Date()
        let items = [
            date(daysAgo: 0, hour: 1, relativeTo: now),
            date(daysAgo: 0, hour: 23, relativeTo: now)
        ]
        let groups = DateGrouping.group(items, by: { $0 }, now: now)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].0, .today)
        XCTAssertEqual(groups[0].1.count, 2)
    }

    func testYesterdayBoundaryIsInclusiveAt23_59() {
        let now = Date()
        let yesterdayLate = calendar.startOfDay(for: now).addingTimeInterval(-1)
        let groups = DateGrouping.group([yesterdayLate], by: { $0 }, now: now)
        XCTAssertEqual(groups.first?.0, .yesterday)
    }

    func testThisWeekContainsThreeDaysAgo() {
        let now = Date()
        let groups = DateGrouping.group(
            [date(daysAgo: 3, relativeTo: now)],
            by: { $0 },
            now: now
        )
        XCTAssertEqual(groups.first?.0, .thisWeek)
    }

    func testEarlierContainsEightDaysAgo() {
        let now = Date()
        let groups = DateGrouping.group(
            [date(daysAgo: 8, relativeTo: now)],
            by: { $0 },
            now: now
        )
        XCTAssertEqual(groups.first?.0, .earlier)
    }

    func testGroupOrderIsTodayThenYesterdayThenWeekThenEarlier() {
        let now = Date()
        let items = [
            date(daysAgo: 30, relativeTo: now),
            date(daysAgo: 0, relativeTo: now),
            date(daysAgo: 1, relativeTo: now),
            date(daysAgo: 4, relativeTo: now)
        ]
        let groups = DateGrouping.group(items, by: { $0 }, now: now)
        XCTAssertEqual(groups.map(\.0), [.today, .yesterday, .thisWeek, .earlier])
    }

    func testItemOrderWithinAGroupPreservesInputOrder() {
        let now = Date()
        let a = date(daysAgo: 0, hour: 8, relativeTo: now)
        let b = date(daysAgo: 0, hour: 18, relativeTo: now)
        let groups = DateGrouping.group([b, a], by: { $0 }, now: now)
        XCTAssertEqual(groups.first?.1, [b, a])
    }

    // MARK: - formatTime / formatDuration

    func testFormatTimeUsesLowercaseAmPmAndTwelveHourClock() {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 1; comps.day = 1
        comps.hour = 0; comps.minute = 5
        let midnight = calendar.date(from: comps)!
        XCTAssertEqual(formatTime(midnight), "12:05 am")

        comps.hour = 13; comps.minute = 0
        let onePm = calendar.date(from: comps)!
        XCTAssertEqual(formatTime(onePm), "1:00 pm")

        comps.hour = 23; comps.minute = 7
        let late = calendar.date(from: comps)!
        XCTAssertEqual(formatTime(late), "11:07 pm")
    }

    func testFormatDurationShortAndLong() {
        XCTAssertEqual(formatDuration(0), "0s")
        XCTAssertEqual(formatDuration(42), "42s")
        XCTAssertEqual(formatDuration(60), "1:00")
        XCTAssertEqual(formatDuration(83), "1:23")
        XCTAssertEqual(formatDuration(3725), "62:05")
    }
}
