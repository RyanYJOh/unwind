import OneSignalExtension
import UserNotifications

/// OneSignal 푸시의 Notification Service Extension (2026-09-15).
/// 이미지 첨부·수신 확인(Confirmed Delivery)·배지 카운트를 OneSignal이
/// 처리하도록 받은 알림을 그대로 넘긴다. 로컬 알림(flutter_local_notifications)
/// 은 이 확장을 거치지 않는다 — 원격 푸시에 mutable-content가 있을 때만 돈다.
class NotificationService: UNNotificationServiceExtension {
  var contentHandler: ((UNNotificationContent) -> Void)?
  var receivedRequest: UNNotificationRequest!
  var bestAttemptContent: UNMutableNotificationContent?

  override func didReceive(
    _ request: UNNotificationRequest,
    withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
  ) {
    self.receivedRequest = request
    self.contentHandler = contentHandler
    self.bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

    if let bestAttemptContent = bestAttemptContent {
      OneSignalExtension.didReceiveNotificationExtensionRequest(
        self.receivedRequest, with: bestAttemptContent, withContentHandler: self.contentHandler)
    }
  }

  override func serviceExtensionTimeWillExpire() {
    if let contentHandler = contentHandler, let bestAttemptContent = bestAttemptContent {
      OneSignalExtension.serviceExtensionTimeWillExpireRequest(
        self.receivedRequest, with: self.bestAttemptContent)
      contentHandler(bestAttemptContent)
    }
  }
}
