import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthcore/screens/barcode_flow_screens.dart';

// Oreo-like food: 34 g serving, values per 100 g.
const food = {
  'barcode': '0000000000001',
  'name': 'Oreo',
  'serving_size_grams': 34,
  'calories_per_100': 480,
  'protein_per_100': 5,
  'carbs_per_100': 70,
  'fat_per_100': 20,
  'missing': <String>[],
};

void main() {
  test('formatAmount drops .0 and keeps one decimal', () {
    expect(formatAmount(244.8), '244.8');
    expect(formatAmount(45.900000000000006), '45.9');
    expect(formatAmount(163.2), '163.2');
    expect(formatAmount(34), '34');
    expect(formatAmount(12.0), '12');
  });

  testWidgets('log screen previews macros and updates with servings', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: BarcodeLogScreen(food: food)));

    // 1 serving = 34 g -> 163.2 kcal, 1.7 protein, 23.8 carbs, 6.8 fat
    expect(find.text('1 serving = 34 g'), findsOneWidget);
    expect(find.text('163.2 kcal'), findsOneWidget);
    expect(find.text('1.7 g'), findsOneWidget);
    expect(find.text('23.8 g'), findsOneWidget);
    expect(find.text('6.8 g'), findsOneWidget);

    // 1.5 servings = 51 g -> 244.8 kcal, 35.7 carbs, 10.2 fat (matches the backend test)
    await tester.enterText(find.byType(TextField).first, '1.5');
    await tester.pump();
    expect(find.text('51 g'), findsOneWidget);
    expect(find.text('244.8 kcal'), findsOneWidget);
    expect(find.text('35.7 g'), findsOneWidget);
    expect(find.text('10.2 g'), findsOneWidget);

    // invalid servings -> button disabled
    await tester.enterText(find.byType(TextField).first, '0');
    await tester.pump();
    final button = tester.widget<ButtonStyleButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('manual entry pre-fills per-serving values from per-100 g data', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: BarcodeManualEntryScreen(food: {
        'barcode': '0000000000001',
        'name': null,
        'serving_size_grams': 34,
        'calories_per_100': 480,
        'protein_per_100': null,
        'carbs_per_100': 70,
        'fat_per_100': 20,
        'missing': ['name', 'protein_per_100'],
      }),
    ));

    String fieldText(String label) => tester
        .widget<EditableText>(find.descendant(
          of: find.widgetWithText(TextFormField, label),
          matching: find.byType(EditableText),
        ))
        .controller
        .text;

    expect(fieldText('Food name'), '');
    expect(fieldText('Serving size'), '34');
    expect(fieldText('Calories'), '163.2'); // 480 * 34 / 100
    expect(fieldText('Protein'), ''); // missing -> blank for the user to fill
    expect(fieldText('Carbs'), '23.8');
    expect(fieldText('Fat'), '6.8');
    expect(find.textContaining('Some info for this product is missing'), findsOneWidget);
  });
}
