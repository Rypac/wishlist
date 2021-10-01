import XCTest
@testable import Toolbox

final class UserDefaultsTests: XCTestCase {
  private var userDefaults: UserDefaults!

  override func setUp() {
    super.setUp()
    userDefaults = UserDefaults(suiteName: #file)
  }

  override func tearDown() {
    super.tearDown()
    UserDefaults().removeSuite(named: #file)
  }

  func testBooleanKey() {
    let key = UserDefaultsKey(#function, defaultValue: true)

    XCTAssertFalse(userDefaults.has(key))
    XCTAssertTrue(userDefaults[key])

    userDefaults[key] = false

    XCTAssertTrue(userDefaults.has(key))
    XCTAssertFalse(userDefaults[key])

    userDefaults[key] = true

    XCTAssertTrue(userDefaults.has(key))
    XCTAssertTrue(userDefaults[key])

    userDefaults.remove(key)

    XCTAssertFalse(userDefaults.has(key))
    XCTAssertTrue(userDefaults[key])
  }

  func testOptionalBooleanKey() {
    let key = UserDefaultsKey<Bool?>(#function, defaultValue: false)

    XCTAssertFalse(userDefaults.has(key))
    XCTAssertEqual(userDefaults[key], false)

    userDefaults[key] = true

    XCTAssertTrue(userDefaults.has(key))
    XCTAssertEqual(userDefaults[key], true)

    userDefaults[key] = nil

    XCTAssertFalse(userDefaults.has(key))
    XCTAssertEqual(userDefaults[key], false)

    userDefaults.remove(key)

    XCTAssertFalse(userDefaults.has(key))
    XCTAssertEqual(userDefaults[key], false)
  }

  func testOptionalBooleanDefaultNilKey() {
    let key = UserDefaultsKey<Bool?>(#function, defaultValue: nil)

    XCTAssertFalse(userDefaults.has(key))
    XCTAssertNil(userDefaults[key])

    userDefaults[key] = true

    XCTAssertTrue(userDefaults.has(key))
    XCTAssertEqual(userDefaults[key], true)

    userDefaults[key] = false

    XCTAssertTrue(userDefaults.has(key))
    XCTAssertEqual(userDefaults[key], false)

    userDefaults.remove(key)

    XCTAssertFalse(userDefaults.has(key))
    XCTAssertNil(userDefaults[key])
  }

  func testStringArrayKey() {
    let key = UserDefaultsKey<[String]>(#function, defaultValue: [])

    XCTAssertFalse(userDefaults.has(key))
    XCTAssertEqual(userDefaults[key], [])

    userDefaults[key] = ["one", "two", "three"]

    XCTAssertTrue(userDefaults.has(key))
    XCTAssertEqual(userDefaults[key], ["one", "two", "three"])

    userDefaults.remove(key)

    XCTAssertFalse(userDefaults.has(key))
    XCTAssertEqual(userDefaults[key], [])
  }

  func testIntegerSetKey() {
    let key = UserDefaultsKey<Set<Int>>(#function, defaultValue: [])

    XCTAssertFalse(userDefaults.has(key))
    XCTAssertEqual(userDefaults[key], Set())

    userDefaults[key] = Set(arrayLiteral: 1, 2, 3)

    XCTAssertTrue(userDefaults.has(key))
    XCTAssertEqual(userDefaults[key], Set(arrayLiteral: 1, 2, 3))

    userDefaults.remove(key)

    XCTAssertFalse(userDefaults.has(key))
    XCTAssertEqual(userDefaults[key], Set())
  }

  static var allTests = [
    ("testBooleanKey", testBooleanKey),
    ("testOptionalBooleanKey", testOptionalBooleanKey),
    ("testOptionalBooleanDefaultNilKey", testOptionalBooleanDefaultNilKey),
    ("testStringArrayKey", testStringArrayKey),
    ("testIntegerSetKey", testIntegerSetKey)
  ]
}
