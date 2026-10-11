import XCTest

final class PeekPictureTests: XCTestCase {
    func testThereAreThreeMoods() {
        XCTAssertEqual(Mood.allCases.count, 3)
    }
}
