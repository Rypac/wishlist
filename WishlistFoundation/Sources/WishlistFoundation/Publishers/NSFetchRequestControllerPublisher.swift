import Combine
import CoreData

public struct NSFetchRequestPublisher<Entity: NSManagedObject>: Publisher {
  public typealias Output = [Entity]
  public typealias Failure = Never

  private let request: NSFetchRequest<Entity>
  private let context: NSManagedObjectContext
  private let refresh: DarwinNotification.Name?

  public init(request: NSFetchRequest<Entity>, context: NSManagedObjectContext, refresh: DarwinNotification.Name? = nil) {
    self.request = request
    self.context = context
    self.refresh = refresh
  }

  public func receive<S>(subscriber: S) where S: Subscriber, Output == S.Input, Failure == S.Failure {
    subscriber.receive(subscription: NSFetchedResultsSubscription(request: request, context: context, refresh: refresh, downstream: subscriber))
  }
}

private final class NSFetchedResultsSubscription<Entity: NSManagedObject, Downstream: Subscriber>: NSObject, Subscription, NSFetchedResultsControllerDelegate where Downstream.Input == [Entity], Downstream.Failure == Never {
  private var controller: NSFetchedResultsController<Entity>?
  private var refresh: DarwinNotification.Name?
  private let downstream: Downstream

  private var demand = Subscribers.Demand.none
  private let lock = NSRecursiveLock()

  init(request: NSFetchRequest<Entity>, context: NSManagedObjectContext, refresh: DarwinNotification.Name?, downstream: Downstream) {
    let controller = NSFetchedResultsController(fetchRequest: request, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)
    self.controller = controller
    self.refresh = refresh
    self.downstream = downstream
    super.init()

    controller.delegate = self
    do {
      try controller.performFetch()
    } catch {
      print("Failed to perform fetch")
    }

    if let refreshNotfication = refresh {
      DarwinNotificationCenter.shared.addObserver(self, for: refreshNotfication) { [weak self] _ in
        self?.refreshController()
      }
    }
  }

  // MARK: Subscription

  func request(_ demand: Subscribers.Demand) {
    lock.synchronized {
      self.demand += demand

      if let controller = self.controller as? NSFetchedResultsController<NSFetchRequestResult> {
        controllerDidChangeContent(controller)
      }
    }
  }

  func cancel() {
    lock.synchronized {
      controller?.delegate = nil
      controller = nil

      if let refreshNotfication = refresh {
        DarwinNotificationCenter.shared.removeObserver(self, for: refreshNotfication)
        refresh = nil
      }
    }
  }

  // MARK: NSFetchedResultsControllerDelegate

  func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
    lock.synchronized {
      guard demand > 0 else {
        return
      }

      if let items = controller.fetchedObjects as? Downstream.Input {
        demand += downstream.receive(items)
      }
    }
  }

  // MARK: DarwinNotificationCenter

  func refreshController() {
    do {
      try controller?.performFetch()
    } catch {
      print("Failed to perform fetch after external refresh")
    }

    if let controller = controller as? NSFetchedResultsController<NSFetchRequestResult> {
      controllerDidChangeContent(controller)
    }
  }
}
