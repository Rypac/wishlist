import XCTest
@testable import WishlistModel

final class WishlistModelTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(WishlistModel().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
