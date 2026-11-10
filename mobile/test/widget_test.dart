import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wc_fantasy/theme/app_colors.dart';
import 'package:wc_fantasy/theme/app_theme.dart';

void main() {
  // Note: a full-app render test isn't used here — the app's global singletons
  // (e.g. connectivity) start periodic timers on boot that leak into test
  // teardown. Instead we validate the core design-system deliverable directly.
  group('AppTheme', () {
    testWidgets('dark theme renders with brand tokens', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: Center(child: Text('WC Fantasy'))),
      ));

      expect(find.text('WC Fantasy'), findsOneWidget);

      final ctx = tester.element(find.text('WC Fantasy'));
      final theme = Theme.of(ctx);
      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, AppColors.gold);
      expect(theme.scaffoldBackgroundColor, AppColors.background);
    });
  });
}
