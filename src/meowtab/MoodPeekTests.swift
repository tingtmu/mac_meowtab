import XCTest

final class MoodPeekTests: XCTestCase {
    func testThereAreThreeMoods() {
        XCTAssertEqual(Mood.allCases.count, 3)
    }
}
