extension Dictionary {
  public subscript<RawRepresentableKey>(key: RawRepresentableKey) -> Value?
  where RawRepresentableKey: RawRepresentable, RawRepresentableKey.RawValue == Self.Key {
    get { self[key.rawValue] }
    set { self[key.rawValue] = newValue }
  }
}
