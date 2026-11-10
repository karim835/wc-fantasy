import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wc_fantasy/widgets/player_avatar.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('PlayerAvatar', () {
    testWidgets('shows initials when no imageUrl', (tester) async {
      await tester.pumpWidget(wrap(
        const PlayerAvatar(name: 'Kylian Mbappé'),
      ));
      expect(find.text('KM'), findsOneWidget);
    });

    testWidgets('shows single initial for single-word name', (tester) async {
      await tester.pumpWidget(wrap(
        const PlayerAvatar(name: 'Ronaldo'),
      ));
      expect(find.text('R'), findsOneWidget);
    });

    testWidgets('shows flag when showFlag=true and nationality provided', (tester) async {
      await tester.pumpWidget(wrap(
        const PlayerAvatar(name: 'Test Player', nationality: 'France', showFlag: true),
      ));
      // Flag emoji should appear
      expect(find.text('🇫🇷'), findsOneWidget);
    });

    testWidgets('does not show flag when showFlag=false', (tester) async {
      await tester.pumpWidget(wrap(
        const PlayerAvatar(name: 'Test Player', nationality: 'France', showFlag: false),
      ));
      expect(find.text('🇫🇷'), findsNothing);
    });

    testWidgets('handles empty name gracefully', (tester) async {
      await tester.pumpWidget(wrap(
        const PlayerAvatar(name: ''),
      ));
      expect(find.text('?'), findsOneWidget);
    });
  });

  group('flagEmoji', () {
    test('returns correct flag for known country', () {
      expect(flagEmoji('France'), '🇫🇷');
      expect(flagEmoji('Brazil'), '🇧🇷');
      expect(flagEmoji('Argentina'), '🇦🇷');
    });

    test('returns globe for unknown country', () {
      expect(flagEmoji('Unknown Country'), '🌍');
      expect(flagEmoji(null), '🌍');
    });
  });
}
