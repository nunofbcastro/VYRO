# VYRO logo and app icon

The mark is a solid geometric V in off-white (ink on light backgrounds). Its right arm ends in a lime "progress" cap, separated by a thin cut. Lime is used only as a signal, never for the whole mark, and there is no glow or gradient, so it stays sober at any size.

| File | Use |
| --- | --- |
| `vyro-mark-dark.svg` | Monogram on near-black (primary, app icon master). |
| `vyro-mark-lime.svg` | Monogram on light background (ink V, dark-green cap). |
| `vyro-wordmark.svg` | Full logo (monogram + "VYRO") on dark. |
| `vyro-wordmark-light.svg` | Full logo on light. |
| `vyro-app-icon-1024.png` | Rendered master icon. |

The wordmark text is set in Inter/SF/Arial; convert it to outlines before final print or store use.

In the app:
- `VyroBrandTile`: the monogram tile (splash, onboarding).
- `VyroWordmark`: the compact full logo at the top-left of every tab page.
- `VyroMarkPainter`: draws the mark, with optional animated drawing for the splash.

Geometry in a unit box:
- V body: (0.04,0.14) (0.33,0.14) (0.50,0.60) (0.67,0.14) (0.96,0.14) (0.63,0.88) (0.37,0.88).
- Lime cap: the right arm above y = 0.27, with a cut down to y = 0.296.

Colours: body `#F5F7F8` (dark) or `#171A20` (light); cap `#B8F36B` (dark) or `#4A741A` (light); background `#0B0D10`.

Launcher icons (`android/.../mipmap-*`, including the adaptive foreground, `ios/.../AppIcon.appiconset` and `web/icons`) are rendered from the same geometry.

These are original provisional concepts; check trademark availability before release.
