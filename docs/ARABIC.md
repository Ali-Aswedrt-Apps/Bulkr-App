# Arabic

Bulkr ships in English and Egyptian Arabic. This file is what was decided and
why, so the next person changing either one knows what they are changing.

---

## The four decisions

They were settled before any translating started, because each one changes
every string rather than some of them.

**Egyptian, kept professional.** Not Modern Standard, which for a gym app
reads like a bank; not street slang, which narrows the audience and dates
badly. The register is roughly how a good Egyptian trainer writes: `كمّل`,
`سجّل`, `دوّر` — Egyptian structure and ordinary vocabulary, no `عايز يا معلم`.
The tone matches the English, which is direct and unsentimental, and that
carried over more easily than the vocabulary did.

**Western numerals.** 3400, not ٣٤٠٠. Calories, weights and macros are on
nearly every screen, Egypt reads both, and fitness apps there overwhelmingly
use Western digits. Arabic-Indic numerals appear in exactly two places, where
the number is prose rather than data: `١٠٠ جم` inside a sentence, and the
duration copy. Mixing them in the same figure would look careless; splitting
them by role does not.

**Cairo, for both roles.** Anton — the app's entire heading voice — has **no
Arabic glyphs at all**, so in Arabic every heading would have fallen back to
whatever the platform picked. Inter does cover Arabic, but a Latin-first face
next to a real Arabic one reads as two apps stapled together. Cairo was drawn
for Arabic and has a Latin companion good enough for the numbers beside it.
See `lib/styles/app_fonts.dart`, which is also where the weight substitution
lives: Anton has one weight and it is heavy, so Cairo is asked for 800 or the
headings come out the right typeface at the wrong volume.

**Review is the owner's.** These strings were written by a translator who is
not a native speaker of Egyptian Arabic. Walk the app in Arabic before
release; treat anything that reads oddly as wrong rather than as a dialect
choice.

---

## What was done

| | |
|---|---|
| `assets/translations/ar-EG.json` | 808 keys, same order as the English file so the two diff against each other |
| ~145 widget sites | physical left/right → `EdgeInsetsDirectional`, `AlignmentDirectional`, `PositionedDirectional`, `BorderDirectional` |
| 511 font call sites | `GoogleFonts.anton`/`inter` → `AppFonts.display`/`body` |
| `main.dart` | `ar-EG` added to `supportedLocales`; the Cairo switch is set from the locale on every build of the root |
| The account sheet | a language row, labelled in the language it switches *to* |

Directional Material icons — `arrow_back`, `chevron_left`, `chevron_right` —
carry `matchTextDirection: true` and mirror themselves under `Directionality`.
Nothing was changed for them, and they are the first thing to check on the
walkthrough, because a back arrow pointing the wrong way is the most obvious
RTL bug there is.

---

## What holds it together

- **`test/rtl_test.dart`** fails on physical left/right anywhere in `lib/`.
  This is the one that matters: `EdgeInsetsDirectional.fromSTEB` renders
  *identically* to `EdgeInsets.fromLTRB` in English, so a screen that regresses
  looks right in English, right in a screenshot, right in review, and is wrong
  only in the language nobody writing the code is reading it in.
- **`test/translation_parity_test.dart`** fails on a key missing from either
  file, a `{placeholder}` dropped in translation, or a value left byte-identical
  to the English. easy_localization fails silently at all three: a missing key
  renders as the key itself, and a dropped placeholder renders its own braces.

### The two things that stay physical

Both are symmetric, and both are typed `EdgeInsets` rather than
`EdgeInsetsGeometry` by the API taking them, so a directional value does not
compile there:

- `SnackBarThemeData.insetPadding` in `main.dart`
- `SnackBar.margin` in `bulkr_snack_bar.dart` — which `snack_bar_test.dart`
  also casts to `EdgeInsets`, so "fixing" it fails a test for a reason that has
  nothing to do with what broke.

Both are listed as exemptions in `rtl_test.dart` rather than left to be
rediscovered.

---

## Before release

1. Set a device to Arabic and walk every screen. The lint proves the widgets
   are directional; it cannot prove a screen *looks* right.
2. Check the back arrows and the chat bubbles first — the two places where
   getting the direction wrong is unmistakable and, for the bubbles, puts your
   own messages on the reader's wrong side.
3. Check the nav bar labels and the onboarding headings for overflow. Arabic
   runs longer than English in some places and much shorter in others, and
   Cairo sets wider than Anton.
4. Read the calorie and macro screens as a user, not as a reviewer. That is
   where a wrong word costs somebody their day's target.
