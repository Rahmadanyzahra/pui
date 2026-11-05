import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patara_ai/features/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<bool> pumpOnboarding(WidgetTester tester) async {
    var done = false;
    await tester.pumpWidget(MaterialApp(
      // Animasi berulang dimatikan supaya pumpAndSettle bisa selesai.
      home: MediaQuery(
        data: const MediaQueryData(size: Size(400, 860), disableAnimations: true),
        child: OnboardingScreen(onDone: () => done = true),
      ),
    ));
    await tester.pumpAndSettle();
    expect(done, isFalse);
    return done;
  }

  testWidgets('tiga halaman perkenalan, lalu Mulai menyimpan tanda sudah dilihat', (tester) async {
    await pumpOnboarding(tester);
    expect(find.text('Catat keseharian si kecil'), findsOneWidget);
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();
    expect(find.text('Libatkan pengasuh dengan tenang'), findsOneWidget);
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();
    expect(find.text('Tanya AI, selesaikan misi'), findsOneWidget);
    await tester.tap(find.text('Mulai'));
    await tester.pumpAndSettle();
    expect(await onboardingSeen(), isTrue);
  });

  testWidgets('Lewati langsung menutup perkenalan', (tester) async {
    await pumpOnboarding(tester);
    await tester.tap(find.text('Lewati'));
    await tester.pumpAndSettle();
    expect(await onboardingSeen(), isTrue);
  });
}
