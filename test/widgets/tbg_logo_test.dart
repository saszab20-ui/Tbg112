import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tarnobrzeg112/themes/app_theme.dart';
import 'package:tarnobrzeg112/widgets/tbg_logo.dart';

void main() {
  testWidgets('TbgLogo renders app name', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(body: TbgLogo()),
      ),
    );

    expect(find.text('Tarnobrzeg 112'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });
}
