import Combine

extension Result.Publisher where Failure == Error {
  public init(catching body: () throws -> Success) {
    do {
      self.init(try body())
    } catch {
      self.init(error)
    }
  }
}
