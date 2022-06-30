import SwiftUI

@main
final class Wishlist: App {
  @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate

  var body: some Scene {
    WindowGroup { [appRepository = appDelegate.appRepository, handleURLScheme = appDelegate.urlSchemeHandler.handle] in
      ContentView(
        environment: ContentViewEnvironment(
          repository: AppListRepository(
            apps: appRepository.appsPublisher.eraseToAnyPublisher(),
            app: { appRepository.appPublisher(forId: $0).eraseToAnyPublisher() },
            versionHistory: { appRepository.versionsPublisher(forId: $0).eraseToAnyPublisher() },
            checkForUpdates: appDelegate.updateChecker.update,
            recordViewed: appRepository.recordAppViewed,
            addApps: appDelegate.appAdder.addApps(from:),
            deleteApps: appRepository.deleteApps(ids:),
            deleteAllApps: appRepository.deleteAllApps
          ),
          theme: appDelegate.settings.$theme,
          notificationsEnabled: appDelegate.settings.$enableNotificaitons,
          sortOrderState: appDelegate.settings.sortOrderStatePublisher.eraseToAnyPublisher(),
          refresh: appRepository.refresh,
          checkForUpdates: appDelegate.updateChecker.updateIfNeeded,
          scheduleBackgroundTasks: appDelegate.scheduleBackgroundTasks,
          system: appDelegate.system
        )
      )
      .onOpenURL { url in
        if let urlScheme = URLScheme(rawValue: url) {
          try? handleURLScheme(urlScheme)
        }
      }
    }
  }
}
