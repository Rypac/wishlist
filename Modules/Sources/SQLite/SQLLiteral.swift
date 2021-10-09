public struct SQLLiteral: ExpressibleByStringLiteral, ExpressibleByStringInterpolation, CustomStringConvertible {
  public struct StringInterpolation: StringInterpolationProtocol {
    var sql = ""
    var bindings: [StatementBindable?] = []

    public init(literalCapacity: Int, interpolationCount: Int) {
      sql.reserveCapacity(literalCapacity + interpolationCount)
      bindings.reserveCapacity(interpolationCount)
    }

    public mutating func appendLiteral(_ literal: String) {
      sql.append(literal)
    }

    public mutating func appendInterpolation(_ value: StatementBindable?) {
      sql.append("?")
      bindings.append(value)
    }
  }

  public let description: String
  public let bindings: [StatementBindable?]

  public init(stringLiteral value: String) {
    description = value
    bindings = []
  }

  public init(stringInterpolation: StringInterpolation) {
    description = stringInterpolation.sql
    bindings = stringInterpolation.bindings
  }
}
