import XCTest

final class MeowTabStoreTests: XCTestCase {
    func testThereAreThreeMoods() {
        XCTAssertEqual(Mood.allCases.count, 3)
    }
}
