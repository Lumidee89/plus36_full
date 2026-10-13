import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_student/main.dart';

void main() {
  testWidgets('student login presents branded credentials form', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: LoginScreen(onLogin: () {})));
    expect(find.text('Welcome\nback.'), findsOneWidget);
    expect(find.text('Student login email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });
}
