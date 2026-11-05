import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patara_ai/features/anak_mini_games.dart';
import 'package:patara_ai/features/play_mechanics.dart';
import 'package:patara_ai/features/toddler_mini_games.dart';
import 'package:patara_ai/services/game_sound_service.dart';
import 'package:patara_ai/widgets/mini_game_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // Layar kecil untuk memastikan tidak ada overflow.
  Future<void> pumpSmall(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: screen));
  }

  testWidgets('toddler game ends on a result screen and can be replayed', (
    tester,
  ) async {
    await pumpSmall(
      tester,
      const ToddlerMiniGameScreen(
        gameType: ToddlerGameType.colorMatch,
        childId: 'child-1',
      ),
    );

    for (var round = 0; round < 6; round++) {
      expect(find.text('$round/6'), findsOneWidget);
      // Ketukan kedua selama jeda tidak boleh dihitung sebagai jawaban.
      await tester.tap(find.byType(MiniGameOption).first);
      await tester.tap(find.byType(MiniGameOption).last);
      await tester.pump();
      expect(find.text('${round + 1}/6'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1200));
    }
    await tester.pumpAndSettle();

    expect(find.text('Selesai!'), findsOneWidget);
    expect(find.text('Main Lagi'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    final saved =
        jsonDecode(prefs.getString('toddler_game_colorMatch_summary')!)
            as Map<String, dynamic>;
    expect(saved['completed'], true);
    expect(saved['progress'], 100);

    await tester.tap(find.text('Main Lagi'));
    await tester.pump();
    expect(find.text('Selesai!'), findsNothing);
    expect(find.text('0/6'), findsOneWidget);
  });

  testWidgets('number order game gives full score for a perfect run', (
    tester,
  ) async {
    await pumpSmall(
      tester,
      const AnakMiniGameScreen(
        gameType: AnakGameType.connectDots,
        childId: 'child-1',
      ),
    );

    for (var value = 1; value <= 6; value++) {
      await tester.tap(find.widgetWithText(MiniGameOption, '$value'));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.text('Selesai!'), findsOneWidget);
    expect(find.text('Skor 60'), findsOneWidget);
    expect(find.text('Tanpa kesalahan'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
  });

  testWidgets('quiz games render every question without overflow', (
    tester,
  ) async {
    for (final type in [
      AnakGameType.alphabetQuiz,
      AnakGameType.numberCount,
      AnakGameType.wordMatch,
    ]) {
      await pumpSmall(
        tester,
        AnakMiniGameScreen(key: ValueKey(type), gameType: type, childId: 'c'),
      );
      for (var round = 0; round < 6; round++) {
        await tester.tap(find.byType(MiniGameOption).first);
        await tester.pump(const Duration(milliseconds: 1100));
      }
      await tester.pumpAndSettle();
      expect(find.text('Selesai!'), findsOneWidget, reason: type.name);
    }
  });

  testWidgets('hub lists every game and shows saved stars', (tester) async {
    SharedPreferences.setMockInitialValues({
      'anak_game_wordMatch_summary': jsonEncode({
        'bestScore': 60,
        'stars': 3,
        'completed': true,
        'progress': 100,
      }),
    });
    // Karakter di sambutan beranimasi tanpa henti; dimatikan agar pumpAndSettle selesai.
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpSmall(tester, const AnakMiniGameHubScreen(childId: 'child-1'));
    await tester.pumpAndSettle();

    expect(find.text('Ayo main!'), findsOneWidget);
    // Delapan kuis ditambah kartu memori, seret dan cocokkan, dan mewarnai.
    expect(find.text('Bintang terkumpul: 3 dari ${(AnakGameType.values.length + 3) * 3}'), findsOneWidget);
    for (final title in ['Kartu Memori', 'Seret & Cocokkan', 'Mewarnai']) {
      // Kartu "Tantangan hari ini" berganti tiap hari dan bisa memuat judul yang sama; petak permainannya
      // selalu yang terakhir.
      await tester.scrollUntilVisible(find.text(title).last, 80);
    }
    for (final type in AnakGameType.values) {
      final tile = find.byKey(ValueKey('game-${type.summaryKey}'));
      await tester.scrollUntilVisible(tile, 80);
      expect(find.descendant(of: tile, matching: find.text(type.title)), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('memory game keeps matched pairs open and ends when every pair is found', (tester) async {
    await pumpSmall(tester, const MemoryGameScreen(pairs: 3, summaryKey: 'memory_test', seed: 7));
    // Kunci tiap kartu memuat gambarnya, jadi tes dapat memasangkan kartu tanpa menebak.
    final faces = <String, List<Finder>>{};
    for (final element in find.byWidgetPredicate((widget) => widget.key is ValueKey<String> && (widget.key! as ValueKey<String>).value.startsWith('memory-')).evaluate()) {
      final key = element.widget.key! as ValueKey<String>;
      faces.putIfAbsent(key.value.split('-').last, () => []).add(find.byKey(key));
    }
    expect(faces.length, 3);
    final pairs = faces.values.toList();

    // Dua kartu berbeda dihitung satu kesalahan dan tertutup kembali.
    await tester.tap(pairs[0][0]);
    await tester.tap(pairs[1][0]);
    await tester.pump();
    expect(find.text('Belum sama, coba lagi.'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1000));

    for (final pair in pairs) {
      await tester.tap(pair[0]);
      await tester.pump();
      await tester.tap(pair[1]);
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('Selesai!'), findsOneWidget);
    expect(find.text('Salah 1 kali'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect((jsonDecode(prefs.getString('memory_test')!) as Map)['stars'], 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('drag game accepts an item only in its own basket', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: DragMatchScreen(toddler: true, summaryKey: 'drag_test', seed: 3)));
    Finder items() => find.byWidgetPredicate((widget) => widget is Draggable<int>);
    String targetOf(Finder item) => (tester.widget(item).key! as ValueKey<String>).value.split('-').last;
    Future<void> dragTo(Finder item, String target) async {
      final gesture = await tester.startGesture(tester.getCenter(item));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveTo(tester.getCenter(find.byKey(ValueKey('drop-$target'))));
      await tester.pump();
      await gesture.up();
      await tester.pump();
    }

    final first = items().first;
    final wrong = ['merah', 'biru', 'kuning'].firstWhere((key) => key != targetOf(first));
    await dragTo(first, wrong);
    expect(find.text('Bukan di sini, coba tempat lain.'), findsOneWidget);
    expect(items(), findsNWidgets(6));

    while (items().evaluate().isNotEmpty) {
      final item = items().first;
      await dragTo(item, targetOf(item));
    }
    await tester.pumpAndSettle();
    expect(find.text('Selesai!'), findsOneWidget);
    expect(find.text('Salah 1 kali'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('coloring can be finished only after every part has a colour', (tester) async {
    await pumpSmall(tester, const ColoringScreen(summaryKey: 'coloring_test'));
    ElevatedButton done() => tester.widget<ElevatedButton>(find.ancestor(of: find.text('Selesai'), matching: find.bySubtype<ElevatedButton>()));
    expect(done().onPressed, isNull);
    final canvas = tester.getRect(find.byKey(const ValueKey('coloring-canvas')));
    for (var index = 0; index < coloringRegions.length; index++) {
      await tester.tap(find.byKey(ValueKey('coloring-color-${index % 8}')));
      final anchor = coloringRegions[index].anchor;
      await tester.tapAt(canvas.topLeft + Offset(canvas.width * anchor.dx, canvas.height * anchor.dy));
      await tester.pump();
      expect(find.textContaining('${index + 1} dari ${coloringRegions.length}').evaluate().isNotEmpty || index == coloringRegions.length - 1, isTrue, reason: coloringRegions[index].name);
    }
    expect(done().onPressed, isNotNull);
    await tester.tap(find.text('Selesai'));
    await tester.pumpAndSettle();
    expect(find.text('Gambarmu selesai. Bagus sekali!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sound button turns game sounds off and remembers it', (tester) async {
    await pumpSmall(
      tester,
      const AnakMiniGameScreen(gameType: AnakGameType.connectDots, childId: 'child-1'),
    );
    await tester.pump();
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);

    await tester.tap(find.byTooltip('Matikan suara'));
    await tester.pump();
    expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('game_sound_enabled'), false);

    await tester.tap(find.byTooltip('Nyalakan suara'));
    await tester.pump();
    expect(GameSoundService.enabled.value, true);
    expect(prefs.getBool('game_sound_enabled'), true);
  });
}
