import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The two languages say the same things.
///
/// easy_localization fails silently in both directions, which is what makes
/// this worth a test rather than a glance:
///
///   * a key missing from Arabic renders **the key itself** — an Egyptian user
///     reads `meals_empty_mine_body` in the middle of an otherwise Arabic
///     screen;
///   * a `{placeholder}` dropped in translation renders the literal braces, so
///     somebody is told they have `{count}` meals left.
///
/// Neither shows up in English, neither throws, and neither is visible to
/// anybody reviewing the diff in a language they read.
void main() {
  Map<String, dynamic> load(String locale) => jsonDecode(
        File('assets/translations/$locale.json').readAsStringSync(),
      ) as Map<String, dynamic>;

  late final Map<String, dynamic> en = load('en-US');
  late final Map<String, dynamic> ar = load('ar-EG');

  test('both files are there and not empty', () {
    expect(en, isNotEmpty);
    expect(ar, isNotEmpty);
  });

  test('Arabic has every key English has', () {
    final List<String> missing =
        en.keys.where((String k) => !ar.containsKey(k)).toList();

    expect(missing, isEmpty,
        reason: 'these would render as their own key on an Arabic screen');
  });

  test('and no keys English does not', () {
    // A key only Arabic has is dead weight, and usually a rename applied to
    // one file and not the other.
    final List<String> extra =
        ar.keys.where((String k) => !en.containsKey(k)).toList();

    expect(extra, isEmpty);
  });

  test('every placeholder survives translation', () {
    final RegExp placeholder = RegExp(r'\{(\w+)\}');
    final List<String> broken = <String>[];

    for (final String key in en.keys) {
      if (!ar.containsKey(key)) continue;

      final Set<String> expected = placeholder
          .allMatches('${en[key]}')
          .map((RegExpMatch m) => m.group(1)!)
          .toSet();
      final Set<String> actual = placeholder
          .allMatches('${ar[key]}')
          .map((RegExpMatch m) => m.group(1)!)
          .toSet();

      if (expected.length != actual.length ||
          !expected.every(actual.contains)) {
        broken.add('$key: en=$expected ar=$actual');
      }
    }

    expect(broken, isEmpty,
        reason: 'a dropped placeholder renders its own braces to the reader; '
            'an invented one is never filled in');
  });

  test('nothing was left in English', () {
    // Not a spell check — a check that the file was translated rather than
    // copied. A few values are identical on purpose: brand names, store
    // names, and the purely numeric formats.
    const Set<String> sameInBoth = <String>{
      'app_name',
      'premium_store_apple',
      'premium_store_google',
      'meals_count_capped',
      'challenge_rank',
      'challenge_score_of_goal',
      'challenge_gained',
    };

    final List<String> untranslated = en.keys
        .where((String k) => !sameInBoth.contains(k))
        .where((String k) => '${ar[k]}' == '${en[k]}')
        .toList();

    expect(untranslated, isEmpty,
        reason: 'these are byte-identical to the English, which usually means '
            'a key was added to one file and copied into the other');
  });
}
