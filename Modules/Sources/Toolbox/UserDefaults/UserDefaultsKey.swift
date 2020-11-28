import Foundation

public struct UserDefaultsKey<Value> {
  public let key: String
  public let defaultValue: Value
  fileprivate let adapter: UserDefaultsAdapter<Value>
}

public extension UserDefaultsKey where Value: UserDefaultsConvertible {
  init(_ key: String, defaultValue: Value) {
    self.key = key
    self.defaultValue = defaultValue
    self.adapter = Value.userDefaultsAdapter
  }
}

public extension UserDefaultsKey {
  init<T>(_ key: String, defaultValue: [T]) where Value == [T], T: RawRepresentable {
    self.key = key
    self.defaultValue = defaultValue
    self.adapter = UserDefaultsAdapter(
      get: { defaults, key in
        guard let rawValues = defaults.array(forKey: key) as? [T.RawValue] else {
          return nil
        }
        return rawValues.compactMap(T.init)
      },
      set: { defaults, key, value in
        defaults.set(value.map(\.rawValue), forKey: key)
      },
      register: { defaults, key, value in
        defaults.register(defaults: [key: value.map(\.rawValue)])
      }
    )
  }

  init<T>(_ key: String, defaultValue: Value) where Value == Set<T>, T: Hashable & RawRepresentable {
    self.key = key
    self.defaultValue = defaultValue
    self.adapter = UserDefaultsAdapter(
      get: { defaults, key in
        guard let rawValues = defaults.array(forKey: key) as? [T.RawValue] else {
          return nil
        }
        return Set(rawValues.compactMap(T.init))
      },
      set: { defaults, key, value in
        defaults.set(value.map(\.rawValue), forKey: key)
      },
      register: { defaults, key, value in
        defaults.register(defaults: [key: value.map(\.rawValue)])
      }
    )
  }
}

public extension UserDefaultsKey where Value == [Bool] {
  init(_ key: String, defaultValue: Value) {
    self.key = key
    self.defaultValue = defaultValue
    self.adapter = propertyListArrayAdapter()
  }
}

public extension UserDefaultsKey where Value == [Int] {
  init(_ key: String, defaultValue: Value) {
    self.key = key
    self.defaultValue = defaultValue
    self.adapter = propertyListArrayAdapter()
  }
}

public extension UserDefaultsKey where Value == [Float] {
  init(_ key: String, defaultValue: Value) {
    self.key = key
    self.defaultValue = defaultValue
    self.adapter = propertyListArrayAdapter()
  }
}

public extension UserDefaultsKey where Value == [Double] {
  init(_ key: String, defaultValue: Value) {
    self.key = key
    self.defaultValue = defaultValue
    self.adapter = propertyListArrayAdapter()
  }
}

public extension UserDefaultsKey where Value == [String] {
  init(_ key: String, defaultValue: Value) {
    self.key = key
    self.defaultValue = defaultValue
    self.adapter = propertyListArrayAdapter()
  }
}

public extension UserDefaultsKey where Value == [URL] {
  init(_ key: String, defaultValue: Value) {
    self.key = key
    self.defaultValue = defaultValue
    self.adapter = propertyListArrayAdapter()
  }
}

public extension UserDefaultsKey where Value == [Date] {
  init(_ key: String, defaultValue: Value) {
    self.key = key
    self.defaultValue = defaultValue
    self.adapter = propertyListArrayAdapter()
  }
}

public extension UserDefaultsKey where Value == [Data] {
  init(_ key: String, defaultValue: Value) {
    self.key = key
    self.defaultValue = defaultValue
    self.adapter = propertyListArrayAdapter()
  }
}

public extension UserDefaultsKey where Value: Codable {
  init(_ key: String, defaultValue: Value, encoder: JSONEncoder = JSONEncoder(), decoder: JSONDecoder = JSONDecoder()) {
    self.key = key
    self.defaultValue = defaultValue
    self.adapter = UserDefaultsAdapter(
      get: { defaults, key in
        guard let data = defaults.data(forKey: key) else {
          return nil
        }
        return try? decoder.decode(Value.self, from: data)
      },
      set: { defaults, key, value in
        if let data = try? encoder.encode(value) {
          defaults.set(data, forKey: key)
        }
      },
      register: { defaults, key, value in
        if let data = try? encoder.encode(value) {
          defaults.register(defaults: [key: data])
        }
      }
    )
  }
}

private func propertyListArrayAdapter<T>() -> UserDefaultsAdapter<[T]> {
  UserDefaultsAdapter(
    get: { defaults, key in
      defaults.array(forKey: key) as? [T]
    },
    set: { defaults, key, value in
      defaults.set(value, forKey: key)
    },
    register: { defaults, key, value in
      defaults.register(defaults: [key: value])
    }
  )
}

public extension UserDefaults {
  func has<Value>(_ key: UserDefaultsKey<Value>) -> Bool {
    object(forKey: key.key) != nil
  }

  func register<Value>(_ key: UserDefaultsKey<Value>) {
    key.adapter.register(self, key.key, key.defaultValue)
  }

  func remove<Value>(_ key: UserDefaultsKey<Value>) {
    removeObject(forKey: key.key)
  }

  subscript<Value>(key: UserDefaultsKey<Value>) -> Value {
    get { key.adapter.get(self, key.key) ?? key.defaultValue }
    set { key.adapter.set(self, key.key, newValue) }
  }
}

extension UserDefaults {
  func has(_ key: String) -> Bool {
    object(forKey: key) != nil
  }
}
