import Foundation

public extension Dictionary {
  subscript<Key>(key: Key) -> Value? where Key: RawRepresentable, Key.RawValue == Self.Key {
    get { self[key.rawValue]}
    set { self[key.rawValue] = newValue }
  }
}
