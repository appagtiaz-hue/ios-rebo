import 'package:agtiaz/widgets/agtiaz_brand_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shared brand logo keeps a circular fixed-size layout', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: AgtiazBrandLogo(size: 104))),
      ),
    );
    await tester.runAsync(
      () => precacheImage(
        const AssetImage(AgtiazBrandLogo.asset),
        tester.element(find.byType(AgtiazBrandLogo)),
      ),
    );
    await tester.pumpAndSettle();
    final logo = find.byType(AgtiazBrandLogo);
    expect(tester.getSize(logo), const Size(104, 104));
    expect(
      find.descendant(of: logo, matching: find.byType(ClipOval)),
      findsOneWidget,
    );
    final image = tester.widget<Image>(
      find.descendant(of: logo, matching: find.byType(Image)),
    );
    expect((image.image as AssetImage).assetName, AgtiazBrandLogo.asset);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
