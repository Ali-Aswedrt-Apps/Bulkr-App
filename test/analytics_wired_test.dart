import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every event this app defines is actually sent by it.
///
/// ## The bug this exists for
///
/// `analytics_events.dart` is a carefully argued file. Its header names the
/// questions each event answers — where onboarding loses people, whether the
/// three-tier food search is worth its complexity, whether sharing does
/// anything — and thirty of its seventy-two constructors had never been called
/// from anywhere. Not disabled, not behind a flag: written, reviewed, and
/// never wired to a call site.
///
/// That failure is completely invisible. The app builds, the telemetry
/// pipeline works, forty-two other events arrive, and the console simply has
/// no row for `meal_logged` — which reads exactly like nobody logging meals.
/// The only way to notice is to go looking, and nobody goes looking at a file
/// that compiles.
///
/// So: defining an event is a promise to send it. This holds the promise.
///
/// ## What to do when this fails
///
/// Two honest answers, and "add an ignore" is neither:
///
///   * Wire it. The event answers a question somebody thought was worth
///     asking, and the call site is usually obvious from its name.
///   * Delete it. `moderationModelReady` and `moderationModelFailed` measured
///     the Android on-device moderation model, which no longer exists — an
///     event nothing can ever fire is not a gap waiting to be filled, it is a
///     question about a thing that is gone.
void main() {
  final File definitions = File('lib/core/analytics_events.dart');

  test('the file this reads is where it was', () {
    // A source scan whose target moved passes by finding nothing.
    expect(definitions.existsSync(), isTrue);
  });

  test('every event has a call site outside its own definition', () {
    final String source = definitions.readAsStringSync();

    final List<String> names = RegExp(r'factory AnalyticsEvent\.(\w+)\(')
        .allMatches(source)
        .map((RegExpMatch m) => m.group(1)!)
        .toList();

    expect(names.length, greaterThan(20),
        reason: 'the pattern no longer matches how events are declared');

    final String app = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((File f) =>
            f.path.endsWith('.dart') &&
            !f.path.endsWith('analytics_events.dart'))
        .map((File f) => f.readAsStringSync())
        .join('\n');

    final List<String> unsent = names
        .where((String n) => !RegExp('AnalyticsEvent\\.$n\\b').hasMatch(app))
        .toList();

    expect(
      unsent,
      isEmpty,
      reason: 'these are defined and never sent, so the console has no row for '
          'them and that reads exactly like the thing never happening. Wire '
          'each one to its call site, or delete it',
    );
  });
}
