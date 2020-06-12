import Foundation

public struct UserDefaultsAdapter<Value> {
  public let get: (UserDefaults, String) -> Value?
  public let set: (UserDefaults, String, Value) -> Void
  public let register: (UserDefaults, String, Value) -> Void

  public init(
    get: @escaping (UserDefaults, String) -> Value?,
    set: @escaping (UserDefaults, String, Value) -> Void,
    register: @escaping (UserDefaults, String, Value) -> Void
  ) {
    self.get = get
    self.set = set
    self.register = register
  }
}

private extension UserDefaultsAdapter {
  init(
    get: @escaping (UserDefaults, String) -> Value?,
    set: @escaping (UserDefaults, String, Value) -> Void
  ) {
    self.get = get
    self.set = set
    self.register = { defaults, key, value in
      defaults.register(defaults: [key: value])
    }
  }
}

public protocol UserDefaultsConvertible {
  static var userDefaultsAdapter: UserDefaultsAdapter<Self> { get }
}

extension Bool: UserDefaultsConvertible {
  public static let userDefaultsAdapter = UserDefaultsAdapter(
    get: { defaults, key in
      defaults.has(key) ? defaults.bool(forKey: key) : nil
    },
    set: { defaults, key, value in
      defaults.set(value, forKey: key)
    }
  )
}

extension Int: UserDefaultsConvertible {
  public static let userDefaultsAdapter = UserDefaultsAdapter(
    get: { defaults, key in
      defaults.has(key) ? defaults.integer(forKey: key) : nil
    },
    set: { defaults, key, value in
      defaults.set(value, forKey: key)
    }
  )
}

extension Float: UserDefaultsConvertible {
  public static let userDefaultsAdapter = UserDefaultsAdapter(
    get: { defaults, key in
      defaults.has(key) ? defaults.float(forKey: key) : nil
    },
    set: { defaults, key, value in
      defaults.set(value, forKey: key)
    }
  )
}

extension Double: UserDefaultsConvertible {
  public static let userDefaultsAdapter = UserDefaultsAdapter(
    get: { defaults, key in
      defaults.has(key) ? defaults.double(forKey: key) : nil
    },
    set: { defaults, key, value in
      defaults.set(value, forKey: key)
    }
  )
}

extension String: UserDefaultsConvertible {
  public static let userDefaultsAdapter = UserDefaultsAdapter(
    get: { defaults, key in
      defaults.string(forKey: key)
    },
    set: { defaults, key, value in
      defaults.set(value, forKey: key)
    }
  )
}

extension URL: UserDefaultsConvertible {
  public static let userDefaultsAdapter = UserDefaultsAdapter(
    get: { defaults, key in
      defaults.url(forKey: key)
    },
    set: { defaults, key, value in
      defaults.set(value, forKey: key)
    }
  )
}

extension Date: UserDefaultsConvertible {
  public static let userDefaultsAdapter = UserDefaultsAdapter(
    get: { defaults, key in
      defaults.object(forKey: key) as? Date
    },
    set: { defaults, key, value in
      defaults.set(value, forKey: key)
    }
  )
}

extension Data: UserDefaultsConvertible {
  public static let userDefaultsAdapter = UserDefaultsAdapter(
    get: { defaults, key in
      defaults.data(forKey: key)
    },
    set: { defaults, key, value in
      defaults.set(value, forKey: key)
    }
  )
}

extension Optional: UserDefaultsConvertible where Wrapped: UserDefaultsConvertible {
  public static var userDefaultsAdapter: UserDefaultsAdapter<Self> {
    UserDefaultsAdapter(
      get: { defaults, key in
        guard let value = Wrapped.userDefaultsAdapter.get(defaults, key) else {
          return nil
        }
        return value
      },
      set: { defaults, key, value in
        if let value = value {
          Wrapped.userDefaultsAdapter.set(defaults, key, value)
        } else {
          defaults.removeObject(forKey: key)
        }
      },
      register: { defaults, key, value in
        if let value = value {
          Wrapped.userDefaultsAdapter.register(defaults, key, value)
        }
      }
    )
  }
}

public extension UserDefaultsConvertible where Self: RawRepresentable, RawValue: UserDefaultsConvertible {
  static var userDefaultsAdapter: UserDefaultsAdapter<Self> {
    UserDefaultsAdapter(
      get: { defaults, key in
        guard let rawValue = RawValue.userDefaultsAdapter.get(defaults, key) else {
          return nil
        }
        return Self(rawValue: rawValue)
      },
      set: { defaults, key, value in
        RawValue.userDefaultsAdapter.set(defaults, key, value.rawValue)
      },
      register: { defaults, key, value in
        RawValue.userDefaultsAdapter.register(defaults, key, value.rawValue)
      }
    )
  }
}
