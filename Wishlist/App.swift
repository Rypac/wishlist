import SwiftUI

@main
final class Wishlist: App {
  @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate

  var body: some Scene {
    WindowGroup { [handleURLScheme = appDelegate.urlSchemeHandler.handle] in
      ContentView(
        environment: ContentViewEnvironment(
          repository: AppListRepository(
            apps: appDelegate.appRepository.appsPublisher,
            app: appDelegate.appRepository.appPublisher(forId:),
            versionHistory: appDelegate.appRepository.versionsPublisher(forId:),
            recordViewed: appDelegate.appRepository.recordAppViewed,
            deleteApps: appDelegate.appRepository.deleteApps(ids:),
            deleteAllApps: appDelegate.appRepository.deleteAllApps
          ),
          theme: appDelegate.settings.$theme,
          sortOrderState: appDelegate.settings.sortOrderStatePublisher,
          refresh: appDelegate.appRepository.refresh,
          checkForUpdates: appDelegate.updateChecker.update,
          scheduleBackgroundTasks: appDelegate.backgroundAppUpdater.scheduleTask,
          system: appDelegate.system
        )
      )
      .onOpenURL { url in
        if let urlScheme = URLScheme(rawValue: url) {
          handleURLScheme(urlScheme)
        }
      }
    }
  }
}
