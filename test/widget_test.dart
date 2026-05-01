import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:health_project/main.dart';

void main() {
  testWidgets('Home page renders core ERP shell', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('Health+ MEDICAL STORE'), findsOneWidget);
    expect(find.text('Master'), findsWidgets);
  });
}
