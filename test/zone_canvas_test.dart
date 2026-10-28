import 'package:chromapulse/providers/settings.dart';
import 'package:chromapulse/show.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const colors = [Color(0xFFFF0000), Color(0xFF0000FF)];

  Future<List<Rect>> pumpCanvas(WidgetTester tester, ZoneLayout layout) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ZoneCanvas(colors: colors, layout: layout),
      ),
    );
    return [
      for (final box in tester.widgetList<AnimatedContainer>(
        find.byType(AnimatedContainer),
      ))
        tester.getRect(find.byWidget(box)),
    ];
  }

  testWidgets('columns split the screen side by side', (tester) async {
    expect(await pumpCanvas(tester, ZoneLayout.columns), [
      const Rect.fromLTWH(0, 0, 400, 600),
      const Rect.fromLTWH(400, 0, 400, 600),
    ]);
  });

  testWidgets('rows stack the zones top to bottom', (tester) async {
    expect(await pumpCanvas(tester, ZoneLayout.rows), [
      const Rect.fromLTWH(0, 0, 800, 300),
      const Rect.fromLTWH(0, 300, 800, 300),
    ]);
  });
}
