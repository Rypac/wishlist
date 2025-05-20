import SwiftUI

@main
struct Wishlist: App {
  @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate

  var body: some Scene {
    WindowGroup { [appRepository = appDelegate.appRepository, handleURLScheme = appDelegate.urlSchemeHandler.handle] in
      ContentView(
        environment: ContentViewEnvironment(
          repository: AppListRepository(
            apps: appRepository.appsPublisher.eraseToAnyPublisher(),
            app: { appRepository.appPublisher(forId: $0).eraseToAnyPublisher() },
            versionHistory: { appRepository.versionsPublisher(forId: $0).eraseToAnyPublisher() },
            checkForUpdates: self.appDelegate.updateChecker.update,
            recordViewed: appRepository.recordAppViewed,
            addApps: self.appDelegate.appAdder.addApps(from:),
            deleteApps: appRepository.deleteApps(ids:),
            deleteAllApps: appRepository.deleteAllApps
          ),
          theme: self.appDelegate.settings.$theme,
          notificationsEnabled: self.appDelegate.settings.$enableNotificaitons,
          sortOrderState: self.appDelegate.settings.sortOrderStatePublisher.eraseToAnyPublisher(),
          refresh: appRepository.refresh,
          checkForUpdates: self.appDelegate.updateChecker.updateIfNeeded,
          scheduleBackgroundTasks: self.appDelegate.scheduleBackgroundTasks,
          system: self.appDelegate.system
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
