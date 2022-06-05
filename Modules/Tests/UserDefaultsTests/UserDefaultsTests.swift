import XCTest
@testable import UserDefaults

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

  func testURLArrayKey() {
    let key = UserDefaultsKey<[URL]>(#function, defaultValue: [])

    XCTAssertFalse(userDefaults.has(key))
    XCTAssertEqual(userDefaults[key], [])

    userDefaults[key] = [URL(string: "http://example.com")!]

    XCTAssertTrue(userDefaults.has(key))
    XCTAssertEqual(userDefaults[key], [URL(string: "http://example.com")!])

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

  func testDictionaryStringIntKey() {
    let key = UserDefaultsKey<[String: Int]>(#function, defaultValue: [:])

    XCTAssertFalse(userDefaults.has(key))
    XCTAssertEqual(userDefaults[key], [:])

    userDefaults[key] = ["hello": 1, "world": 2]

    XCTAssertTrue(userDefaults.has(key))
    XCTAssertEqual(userDefaults[key], ["hello": 1, "world": 2])

    userDefaults.remove(key)

    XCTAssertFalse(userDefaults.has(key))
    XCTAssertEqual(userDefaults[key], [:])
  }

  func testEnumKey() {
    enum Test: String, UserDefaultsConvertible {
      case hello = "Hello"
      case world = "World"
    }

    let key = UserDefaultsKey<Test>(#function, defaultValue: .hello)

    XCTAssertFalse(userDefaults.has(key))
    XCTAssertEqual(userDefaults[key], .hello)

    userDefaults[key] = .world

    XCTAssertTrue(userDefaults.has(key))
    XCTAssertEqual(userDefaults[key], .world)

    userDefaults.remove(key)

    XCTAssertFalse(userDefaults.has(key))
    XCTAssertEqual(userDefaults[key], .hello)
  }

  func testArrayWithEnumElements() {
    enum Test: String, UserDefaultsConvertible {
      case hello = "Hello"
      case world = "World"
    }

    let key = UserDefaultsKey<[Test]>(#function, defaultValue: [])

    XCTAssertFalse(userDefaults.has(key))
    XCTAssertEqual(userDefaults[key], [])

    userDefaults[key] = [.hello, .world]

    XCTAssertTrue(userDefaults.has(key))
    XCTAssertEqual(userDefaults[key], [.hello, .world])

    userDefaults.remove(key)

    XCTAssertFalse(userDefaults.has(key))
    XCTAssertEqual(userDefaults[key], [])
  }

  static var allTests = [
    ("testBooleanKey", testBooleanKey),
    ("testOptionalBooleanKey", testOptionalBooleanKey),
    ("testOptionalBooleanDefaultNilKey", testOptionalBooleanDefaultNilKey),
    ("testStringArrayKey", testStringArrayKey),
    ("testURLArrayKey", testURLArrayKey),
    ("testIntegerSetKey", testIntegerSetKey),
    ("testDictionaryStringIntKey", testDictionaryStringIntKey),
    ("testArrayWithEnumElements", testArrayWithEnumElements)
  ]
}
