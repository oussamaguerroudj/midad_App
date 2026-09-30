import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midad/app.dart';
import 'package:midad/core/settings/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Arabic locale renders RTL; switching to English renders LTR', (tester) async {
    SharedPreferences.setMockInitialValues({'locale': 'ar'});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const MidadApp()));
    await tester.pumpAndSettle();
    // No session in Phase 0 => login placeholder is shown (no fake session).
    expect(Directionality.of(tester.element(find.byType(Scaffold).first)), TextDirection.rtl);

    await container.read(settingsProvider.notifier).setLocale(const Locale('en'));
    await tester.pumpAndSettle();
    expect(Directionality.of(tester.element(find.byType(Scaffold).first)), TextDirection.ltr);
  });
}
