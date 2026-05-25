import 'package:flutter_test/flutter_test.dart';

import 'package:phytonote/main.dart';

void main() {
  testWidgets('home screen renders main actions', (WidgetTester tester) async {
    await tester.pumpWidget(const PhytoNote());
    expect(find.text('PhytoNote'), findsOneWidget);
    expect(find.text('Nouvelle manip'), findsOneWidget);
    expect(find.text('Calibrations'), findsOneWidget);
    expect(find.text('Synchroniser'), findsOneWidget);
  });
}
