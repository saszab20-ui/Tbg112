import 'package:flutter_test/flutter_test.dart';
import 'package:tarnobrzeg112/services/notification_service.dart';

void main() {
  test('notification data resolves exact chat routes', () {
    expect(
      NotificationService.routeForNotificationData({
        'type': 'message',
        'chatId': 'main',
        'chatType': 'main',
        'messageId': 'm1',
      }),
      '/chat/global?messageId=m1',
    );
    expect(
      NotificationService.routeForNotificationData({
        'type': 'message',
        'chatId': 'unit_osp_gorzyce',
        'chatType': 'unit',
      }),
      '/chat/unit/osp_gorzyce',
    );
    expect(
      NotificationService.routeForNotificationData({
        'type': 'message',
        'chatId': 'private_a_b',
        'chatType': 'private',
      }),
      '/private/private_a_b',
    );
  });
}
