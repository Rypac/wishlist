import Foundation
import Combine

@propertyWrapper
public struct UserDefault<Value> {
  private let key: UserDefaults.Key<Value>
  private let defaults: UserDefaults
  private let adapter: UserDefaultsAdapter<Value>

  private init(
    key: String,
    defaultValue: Value,
    adapter: UserDefaultsAdapter<Value>,
    userDefaults: UserDefaults = .standard
  ) {
    self.key = UserDefaults.Key(key: key, defaultValue: defaultValue)
    self.adapter = adapter
    self.defaults = userDefaults
  }

  public var wrappedValue: Value {
    get { adapter.get(defaults, key.key) ?? key.defaultValue }
    set { adapter.set(defaults, key.key, newValue) }
  }

  public var projectedValue: UserDefault<Value> { self }

  public var defaultValue: Value { key.defaultValue }

  public var exists: Bool { defaults.has(key.key) }

  public func register() {
    adapter.register(defaults, key.key, key.defaultValue)
  }

  public func publisher(initialValue: UserDefaults.InitialValueStrategy = .include) -> UserDefaults.Publisher<Value> {
    defaults.publisher(for: key, adapter: adapter, initialValue: initialValue)
  }
}

public extension UserDefault where Value: UserDefaultsConvertible {
  init(key: String, defaultValue: Value, userDefaults: UserDefaults = .standard) {
    self.init(key: key, defaultValue: defaultValue, adapter: Value.userDefaultsAdapter, userDefaults: userDefaults)
  }
}

public extension UserDefault {
  init<T>(key: String, defaultValue: [T], userDefaults: UserDefaults = .standard) where Value == [T], T: PropertyListSerializable {
    self.init(key: key, defaultValue: defaultValue, adapter: builtInArrayAdapter(), userDefaults: userDefaults)
  }
}

public extension UserDefault {
  init<T>(key: String, defaultValue: [T], userDefaults: UserDefaults = .standard) where Value == [T], T: RawRepresentable {
    self.init(key: key, defaultValue: defaultValue, adapter: rawRepresentableArrayAdapter(), userDefaults: userDefaults)
  }
}

public extension UserDefault {
  init<T>(key: String, defaultValue: Set<T>, userDefaults: UserDefaults = .standard) where Value == Set<T>, T: RawRepresentable {
    self.init(key: key, defaultValue: defaultValue, adapter: rawRepresentableSetAdapter(), userDefaults: userDefaults)
  }
}

// MARK: - Adapters

private func rawRepresentableArrayAdapter<T: RawRepresentable>() -> UserDefaultsAdapter<[T]> {
  UserDefaultsAdapter(
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

private func rawRepresentableSetAdapter<T: RawRepresentable>() -> UserDefaultsAdapter<Set<T>> {
  UserDefaultsAdapter(
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

public protocol PropertyListSerializable {}

extension Bool: PropertyListSerializable {}
extension Int: PropertyListSerializable {}
extension Float: PropertyListSerializable {}
extension Double: PropertyListSerializable {}
extension String: PropertyListSerializable {}
extension URL: PropertyListSerializable {}
extension Date: PropertyListSerializable {}
extension Data: PropertyListSerializable {}

func builtInArrayAdapter<T: PropertyListSerializable>() -> UserDefaultsAdapter<[T]> {
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
