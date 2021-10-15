import Foundation

public protocol Cursor {
  associatedtype Element

  func next() throws -> Element?
}

extension RangeReplaceableCollection {
  public init<C: Cursor>(_ cursor: C) throws where C.Element == Element {
    self.init()
    while let element = try cursor.next() {
      append(element)
    }
  }
}

extension Set {
  public init<C: Cursor>(_ cursor: C) throws where C.Element == Element {
    self.init()
    while let element = try cursor.next() {
      insert(element)
    }
  }
}
