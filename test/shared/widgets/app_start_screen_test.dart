import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granite_climbing_app/shared/widgets/app_start_screen.dart';

void main() {
  testWidgets('app start screen keeps the spinner rotating', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppStartScreen(),
      ),
    );

    final spinnerRotation = find.descendant(
      of: find.byType(GraniteLoadingSpinner),
      matching: find.byType(RotationTransition),
    );
    final initialTurns = tester.widget<RotationTransition>(spinnerRotation);
    final initialValue = initialTurns.turns.value;

    await tester.pump(const Duration(milliseconds: 250));

    final laterTurns = tester.widget<RotationTransition>(spinnerRotation);

    expect(laterTurns.turns.value, isNot(initialValue));
  });
}
