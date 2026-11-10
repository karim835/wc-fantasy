import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wc_fantasy/services/locale_notifier.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('LocaleNotifier', () {
    test('starts in French by default', () {
      final notifier = LocaleNotifier();
      expect(notifier.locale.languageCode, 'fr');
      expect(notifier.isFrench, isTrue);
    });

    test('setLocale changes locale and notifies', () async {
      final notifier = LocaleNotifier();
      await Future<void>.delayed(Duration.zero); // let _load() finish with empty prefs
      var callCount = 0;
      notifier.addListener(() => callCount++);
      await notifier.setLocale('en');
      expect(notifier.locale.languageCode, 'en');
      expect(notifier.isFrench, isFalse);
      expect(callCount, 1);
    });

    test('setLocale to same code does nothing', () async {
      final notifier = LocaleNotifier();
      var callCount = 0;
      notifier.addListener(() => callCount++);
      await notifier.setLocale('fr'); // already fr
      expect(callCount, 0);
    });
  });
}
