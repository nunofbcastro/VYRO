# VYRO UI kit

Every screen is built from a small set of shared components. Import them all with one line:

```dart
import 'package:vyro/core/ui/vyro_ui.dart';
```

The live catalogue is at the `/design-system` route (Perfil → Sistema de design). Each class also has dartdoc with a usage example.

## Visual rules (iOS-inspired, VYRO brand)

- **Large titles.** Tab pages open with a 32 pt title that slides away on scroll; a compact centred title then fades in on a frosted-glass bar.
- **Glass for chrome only.** The tab bar and collapsed header use `VyroGlass` (blur + translucent fill + hairline). Content surfaces stay solid.
- **Grouped lists for settings.** Use `VyroGroupedSection` + `VyroListRow`, not stacked cards.
- **One lime action per area.** `VyroPrimaryButton` and `VyroActionTile(primary: true)` carry the gradient; everything else stays neutral.
- **Hairlines, not shadows,** in dark mode. Light mode can add a soft shadow.
- **Tabular numbers** for every changing value (calories, grams, reps).
- Spacing follows the 8 pt grid; tap targets are at least 44 pt.

## Where things live

| File | Contents |
| --- | --- |
| `lib/app/theme/vyro_theme.dart` | Colour tokens, typography, Material theme (light/dark). |
| `lib/app/theme/vyro_shell.dart` | Page structure: `VyroPageScaffold`, `VyroSubpageScaffold`, `VyroPageBody`, `VyroSectionTitle`, `VyroNavBar`. |
| `lib/app/theme/vyro_chrome.dart` | Brand and onboarding pieces: `VyroBackdrop`, `VyroBrandTile`, `VyroMarkPainter`, `VyroPrimaryButton`, `VyroRoundButton`, `VyroCard`, `VyroChoiceCard`, `VyroPillChip`, step indicators, `VyroFooter`. |
| `lib/core/ui/components/` | Newer generic components: `VyroGlass`, `VyroGroupedSection`/`VyroListRow`, `VyroSegmentedControl`, `VyroRing`, `VyroMacroBar`, `VyroActionTile`. |
| `lib/core/widgets/vyro_widgets.dart` | Legacy data cards: `MetricCard`, `ActionCard`, `ContentPage`, `DemoBadge`. |
| `lib/core/ui/vyro_ui.dart` | Barrel that exports all of the above. |

## Page structure

### `VyroPageScaffold`: tab pages
```dart
VyroPageScaffold(
  title: 'Nutrição',
  eyebrow: 'Hoje',                    // optional accent label
  actions: [VyroRoundButton(icon: Icons.barcode_reader, onPressed: scan)],
  body: VyroPageBody(children: [...]),
)
```
The header height reaches the body as top `MediaQuery` padding, and the tab bar height as bottom padding. `VyroPageBody` applies both, so content never hides under the chrome. If the body is not a `VyroPageBody`, apply `MediaQuery.paddingOf(context)` yourself. When the page is pushed (rather than shown as a tab), a back button appears automatically.

### `VyroSubpageScaffold`: pushed pages
Back button, compact title, optional `footer` pinned above the safe area (put the primary action there).
```dart
VyroSubpageScaffold(
  title: 'Detalhe do produto',
  body: ListView(...),
  footer: VyroPrimaryButton(label: 'Adicionar ao diário', onPressed: save),
)
```

## Surfaces
- `VyroCard`: the default content card (`tint` for highlighted cards, `radius`, `padding`).
- `VyroGlass`: frosted glass; `opacity` 0–1 fades it in.
- `VyroGroupedSection(header, footer, children)` with `VyroListRow(icon, iconColor, title, subtitle, value, trailing, onTap, destructive)`.

## Actions
- `VyroPrimaryButton`: full-width pill CTA with the lime gradient; supports `loading`.
- `VyroRoundButton`: circular icon button for header actions and back.
- `VyroActionTile`: icon-over-label shortcut, as in Início → "Registar alimento".
- `VyroSegmentedControl<T>(value, segments, onChanged)`: iOS-style switcher.
- `VyroPillChip`, `VyroChoiceCard`: single or multi-select options.

## Data display
- `VyroRing(value, size, stroke, child)`: animated progress ring.
- `VyroMacroBar(label, value, goal, color)`: thin macro progress bar with "82 / 140 g".
- `MetricCard`: label + big number + optional progress.

## Motion
All motion lives in `components/vyro_motion.dart`. Every animation runs once, lasts 450 ms or less and is skipped when the OS asks to reduce motion.
- `VyroPageBody` staggers its children in automatically (fade + 14 px rise, 45 ms apart, capped at 360 ms). Pass `animate: false` to turn it off.
- `VyroFadeSlideIn(delay, child)`: entrance for a single widget; `vyroStagger(children)` for a list.
- `VyroAnimatedNumber(value)`: counts to new values (calories, grams).
- `VyroPressable`: scales to 0.97 while pressed and gives a light haptic tick. `VyroActionTile` and `ActionCard` already use it.
- `VyroFadeIndexedStack`: the tab shell fades and lifts the newly selected tab in, keeping each tab's state.
- `VyroRing` and `VyroMacroBar` animate their progress; the tab bar icon bounces when selected.
- Splash: the V draws itself, the letters rise one by one, and rings pulse while data loads (`lib/app/splash_page.dart`).

## Brand
- `VyroBrandTile(size)`: the monogram tile used in the splash, onboarding and brand row.
- `VyroMarkPainter(body, accent, progress)`: draws the V monogram (two body strokes plus the accent cap). The geometry matches `brand/logos/vyro-mark-*.svg` and the launcher icons.

## Feature-level shared widgets
These belong to a feature but are reused across screens:
- `QuickLogRow` (`features/nutrition/nutrition_diary_page.dart`): barcode / photo / manual shortcuts.
- `portionKindName`, `portionCountLabel`, `entryAmountLabel` (`features/nutrition/portion_labels.dart`): "2 unidades · 50 g".
- `mealTypes`, `mealLabel`, `mealIcon`, `mealForTime` (`features/nutrition/meals.dart`).

## Adding a component
1. Put generic widgets in `lib/core/ui/components/` and export them from `vyro_ui.dart`.
2. Add a dartdoc comment with a short example.
3. Add a live example to `features/design_showcase/kit_showcase.dart`.
4. Use theme colours (`Theme.of(context).colorScheme`, `VyroTheme.accentTextOf`), never raw hex in feature code, so light and dark both work.
