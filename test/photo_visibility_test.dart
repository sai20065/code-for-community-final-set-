import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praja_dhvani/core/models/photo_visibility.dart';
import 'package:praja_dhvani/features/citizen/privacy/photo_visibility_picker.dart';
import 'package:praja_dhvani/l10n/app_localizations.dart';

Widget _wrap(Widget child) => MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  group('PhotoVisibility', () {
    test('private is not public and has no blur mode', () {
      expect(PhotoVisibility.private.isPublic, isFalse);
      expect(PhotoVisibility.private.blurMode, isNull);
    });

    test('the two public choices map to faces / full', () {
      expect(PhotoVisibility.publicFaces.blurMode, 'faces');
      expect(PhotoVisibility.publicFull.blurMode, 'full');
      expect(PhotoVisibilityFields.from(photoPublic: true, blur: 'full'),
          PhotoVisibility.publicFull);
      expect(PhotoVisibilityFields.from(photoPublic: true, blur: null),
          PhotoVisibility.publicFaces);
      expect(PhotoVisibilityFields.from(photoPublic: false, blur: 'full'),
          PhotoVisibility.private);
    });
  });

  group('PhotoVisibilityPicker', () {
    testWidgets('shows the three choices, private selected', (t) async {
      await t.pumpWidget(_wrap(PhotoVisibilityPicker(
        value: PhotoVisibility.private,
        consented: false,
        onChanged: (_, {agreed = false}) {},
      )));
      expect(find.text('Who can see this photo?'), findsOneWidget);
      expect(find.text('Private'), findsOneWidget);
      expect(find.text('Public, faces and number plates blurred'), findsOneWidget);
      expect(find.text('Public, whole photo blurred'), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_checked_rounded), findsOneWidget);
    });

    testWidgets('a public choice asks for the terms and stays private until agreed',
        (t) async {
      final picked = <(PhotoVisibility, bool)>[];
      await t.pumpWidget(_wrap(PhotoVisibilityPicker(
        value: PhotoVisibility.private,
        consented: false,
        onChanged: (c, {agreed = false}) => picked.add((c, agreed)),
      )));

      await t.tap(find.text('Public, faces and number plates blurred'));
      await t.pumpAndSettle();
      expect(find.text('Photo privacy terms'), findsOneWidget);
      expect(picked, isEmpty);

      // The button is disabled until the box is ticked.
      FilledButton button() => t.widget<FilledButton>(find.byType(FilledButton));
      expect(button().onPressed, isNull);
      await t.tap(find.byType(Checkbox));
      await t.pump();
      expect(button().onPressed, isNotNull);

      await t.tap(find.text('Agree and continue'));
      await t.pumpAndSettle();
      expect(picked, [(PhotoVisibility.publicFaces, true)]);
    });

    testWidgets('closing the terms without agreeing changes nothing', (t) async {
      final picked = <PhotoVisibility>[];
      await t.pumpWidget(_wrap(PhotoVisibilityPicker(
        value: PhotoVisibility.private,
        consented: false,
        onChanged: (c, {agreed = false}) => picked.add(c),
      )));
      await t.tap(find.text('Public, whole photo blurred'));
      await t.pumpAndSettle();
      expect(find.text('Photo privacy terms'), findsOneWidget);
      await t.tapAt(const Offset(10, 10)); // tap the barrier to dismiss
      await t.pumpAndSettle();
      expect(picked, isEmpty);
    });

    testWidgets('already agreed: a public choice applies straight away', (t) async {
      final picked = <(PhotoVisibility, bool)>[];
      await t.pumpWidget(_wrap(PhotoVisibilityPicker(
        value: PhotoVisibility.private,
        consented: true,
        onChanged: (c, {agreed = false}) => picked.add((c, agreed)),
      )));
      await t.tap(find.text('Public, whole photo blurred'));
      await t.pumpAndSettle();
      expect(find.text('Photo privacy terms'), findsNothing);
      expect(picked, [(PhotoVisibility.publicFull, false)]);
    });

    testWidgets('going back to private never needs the terms', (t) async {
      final picked = <PhotoVisibility>[];
      await t.pumpWidget(_wrap(PhotoVisibilityPicker(
        value: PhotoVisibility.publicFaces,
        consented: false,
        onChanged: (c, {agreed = false}) => picked.add(c),
      )));
      await t.tap(find.text('Private'));
      await t.pumpAndSettle();
      expect(find.text('Photo privacy terms'), findsNothing);
      expect(picked, [PhotoVisibility.private]);
    });
  });
}
