import 'package:flutter_test/flutter_test.dart';
import 'package:talentmesh/main.dart';

void main() {
  testWidgets('App renders login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const TalentMeshApp());
    expect(find.text('TALENT MESH'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
