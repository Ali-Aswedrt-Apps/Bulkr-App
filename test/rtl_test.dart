import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Nothing in the app is laid out in physical left and right.
///
/// ## Why a lint and not a widget test
///
/// Arabic reads right to left, so every inset, alignment and overlay has to be
/// expressed as *start* and *end* rather than left and right.
/// `EdgeInsetsDirectional.fromSTEB` renders identically to
/// `EdgeInsets.fromLTRB` in English — which is exactly the problem. A screen
/// that goes back to physical padding looks correct in English, correct in a
/// screenshot, correct in review, and is wrong only in the language nobody
/// writing the code is reading it in.
///
/// No widget test catches that, because catching it means rendering every
/// screen in Arabic and looking at it. So it is caught here, in the one place
/// it is cheap: where somebody types the wrong widget.
///
/// ## The two that stay physical, and why
///
/// Both are symmetric, so they are the same in either direction, and both are
/// typed `EdgeInsets` rather than `EdgeInsetsGeometry` by the API that takes
/// them — a directional value does not compile there.
///
///   * `SnackBarThemeData.insetPadding` in `main.dart`
///   * `SnackBar.margin` in `bulkr_snack_bar.dart`, which `snack_bar_test.dart`
///     also casts to `EdgeInsets` — so "fixing" it fails a test for a reason
///     that has nothing to do with what broke.
void main() {
  /// file -> the substring identifying the one allowed line in it.
  const Map<String, String> allowed = <String, String>{
    'lib/main.dart': 'insetPadding',
    'lib/widgets/bulkr_snack_bar.dart': 'margin:',
  };

  /// What to look for, and what to use instead.
  const Map<String, String> banned = <String, String>{
    'EdgeInsets.fromLTRB': 'EdgeInsetsDirectional.fromSTEB',
    'EdgeInsets.only(left:': 'EdgeInsetsDirectional.only(start:',
    'EdgeInsets.only(right:': 'EdgeInsetsDirectional.only(end:',
    'Alignment.centerLeft': 'AlignmentDirectional.centerStart',
    'Alignment.centerRight': 'AlignmentDirectional.centerEnd',
    'TextAlign.left': 'TextAlign.start',
    'TextAlign.right': 'TextAlign.end',
    'Border(left:': 'BorderDirectional(start:',
    'Border(right:': 'BorderDirectional(end:',
  };

  List<File> dartFiles() => Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((File f) => f.path.endsWith('.dart'))
      .toList();

  test('the lint is reading real files', () {
    // A source scan whose directory moved passes by finding nothing.
    expect(dartFiles().length, greaterThan(50));
  });

  test('nothing is laid out in physical left and right', () {
    final List<String> offenders = <String>[];

    for (final File file in dartFiles()) {
      final String path = file.path.replaceAll(r'\', '/');
      final String? exempt = allowed[path];
      final List<String> lines = file.readAsLinesSync();

      for (int i = 0; i < lines.length; i++) {
        final String line = lines[i];
        if (exempt != null && line.contains(exempt)) continue;

        // Comments discuss these names freely — this file's own doc does.
        final String trimmed = line.trimLeft();
        if (trimmed.startsWith('//')) continue;

        banned.forEach((String bad, String good) {
          if (line.contains(bad)) {
            offenders.add('$path:${i + 1}  $bad -> $good');
          }
        });
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'these lay out in physical left/right, which Arabic mirrors '
          'wrongly. They render identically in English, so nothing else will '
          'ever catch them',
    );
  });

  test('Positioned uses start and end', () {
    // Its own check because `Positioned(` is fine — it is `left:` and `right:`
    // inside one that are not, and those words are ordinary elsewhere.
    final List<String> offenders = <String>[];

    for (final File file in dartFiles()) {
      final String source = file.readAsStringSync();
      final String path = file.path.replaceAll(r'\', '/');

      for (final RegExpMatch m
          in RegExp(r'(?<![\w.])Positioned\(').allMatches(source)) {
        // Enough of the argument list to reach the named arguments, without
        // parsing the whole child tree.
        final int end = m.end + 200;
        final String head =
            source.substring(m.end, end > source.length ? source.length : end);

        if (RegExp(r'^[^)]*\b(left|right):').hasMatch(head)) {
          final int line =
              '\n'.allMatches(source.substring(0, m.start)).length + 1;
          offenders.add('$path:$line  Positioned(left:/right:) -> '
              'PositionedDirectional(start:/end:)');
        }
      }
    }

    expect(offenders, isEmpty);
  });
}
