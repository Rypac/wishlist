public func pipe<A, B, C>(
  _ f: @escaping (A) -> B,
  _ g: @escaping (B) -> C
) -> (A) -> C {
  { (a: A) -> C in
    g(f(a))
  }
}

public func compose<A, B, C>(
  _ f: @escaping (B) -> C,
  _ g: @escaping (A) -> B
) -> (A) -> C {
  { (a: A) -> C in
    f(g(a))
  }
}

public func chain<A, B, C>(
  _ f: @escaping (A) -> B?,
  _ g: @escaping (B) -> C?
) -> (A) -> C? {
  { (a: A) -> C? in
    f(a).flatMap(g)
  }
}

public func curry<A, B, C> (
  _ f: @escaping (A, B) -> C
) -> (A) -> (B) -> C {
  { (a: A) -> (B) -> C in
    { (b: B) -> C in
      f(a, b)
    }
  }
}
