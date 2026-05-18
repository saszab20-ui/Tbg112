import 'package:flutter_test/flutter_test.dart';
import 'package:tarnobrzeg112/routes/route_paths.dart';

void main() {
  test('Route helpers build stable paths', () {
    expect(RoutePaths.unitChat('osp-gorzyce'), '/chat/unit/osp-gorzyce');
    expect(RoutePaths.invite('ABC123'), '/chat/invite/ABC123');
    expect(RoutePaths.privateChat('a_b'), '/private/a_b');
    expect(RoutePaths.chatSettings('group_1'), '/chat-settings/group_1');
  });
}
