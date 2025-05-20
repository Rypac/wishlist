import Combine
import Foundation

extension DarwinNotification.Name: ExpressibleByStringLiteral {
  public init(stringLiteral: String) {
    self.init(stringLiteral)
  }
}

extension DarwinNotificationCenter {
  public func publisher(for notification: DarwinNotification.Name) -> Publisher {
    Publisher(notificationCenter: self, notification: notification)
  }

  public struct Publisher: Combine.Publisher {
    public typealias Output = Void
    public typealias Failure = Never

    private let notificationCenter: DarwinNotificationCenter
    private let notification: DarwinNotification.Name

    init(notificationCenter: DarwinNotificationCenter, notification: DarwinNotification.Name) {
      self.notificationCenter = notificationCenter
      self.notification = notification
    }

    public func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
      let observer = Observer(notificationCenter: notificationCenter, notification: notification)
      observer
        .subject
        .handleEvents(
          receiveSubscription: { _ in observer.start() },
          receiveCompletion: { _ in observer.stop() },
          receiveCancel: { observer.stop() }
        )
        .receive(subscriber: subscriber)
    }
  }

  private final class Observer {
    let subject = PassthroughSubject<Void, Never>()

    private let notificationCenter: DarwinNotificationCenter
    private let notification: DarwinNotification.Name

    init(notificationCenter: DarwinNotificationCenter, notification: DarwinNotification.Name) {
      self.notificationCenter = notificationCenter
      self.notification = notification
    }

    func start() {
      notificationCenter.addObserver(self, for: notification) { [subject] _ in
        subject.send()
      }
    }

    func stop() {
      notificationCenter.removeObserver(self, for: notification)
    }
  }
}
