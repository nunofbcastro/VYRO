# VYRO logo and app icon

The logo is a heavy geometric lettering, V Y R O, with a separate accent "progress" cap on the V's right arm. The V monogram on its own is the app icon, the splash tile and the widget mark. The cap is a thin cut away from the body, and there is no glow or gradient, so it stays sober at any size.

| File | Use |
| --- | --- |
| `vyro-wordmark.svg` | Full lettering (V Y R O) for dark backgrounds: white body, cap `#A3E635`. Copied from `source/vyro-letterieng-white.svg`. |
| `vyro-wordmark-light.svg` | Full lettering for light backgrounds: ink body `#18191C`, cap `#4D7C0F`. Copied from `source/vyro-letterieng-dark.svg`. |
| `vyro-mark-dark.svg` | V monogram alone on `#0B0D10` (viewBox `2.5 0 110 110`). App icon source. |
| `vyro-mark-lime.svg` | V monogram alone on no background, for light surfaces (ink body, `#4D7C0F` cap). |
| `vyro-app-icon-1024.png` | Rendered app icon master (opaque). |
| `source/` | The supplied lettering files, unchanged (`vyro-letterieng-dark.svg`, `vyro-letterieng-white.svg`). |

All logo files are outlined paths, so they need no fonts.

Geometry (lettering viewBox `0 0 500 120`, tight box `(10,10)`–`(482,102)`):
- V body strokes: `(10,24) (40,24) (68,100) (38,100)` and `(40,100) (70,100) (95,34) (65,34)`.
- V cap: `(67,28) (97,28) (105,10) (75,10)`. It sits above the right arm with a gap of 6 units.
- Y, R and O are the paths in the files. R and O have counters (holes).

Colours:
- Dark backgrounds: body `#FFFFFF`, logo cap `#A3E635`, icon background `#0B0D10`.
- Light backgrounds: body `#18191C`, logo cap `#4D7C0F`.
- The logo cap is not the UI accent. The UI lime `#B8F36B` (dark) and `#4A741A` (light) in `brand/tokens/tokens.json` are unchanged.

In the app (`lib/app/theme/vyro_chrome.dart`, `vyro_shell.dart`):
- `VyroWordmarkPainter` paints the full lettering from the path data above. `VyroWordmark` (header, height 22 px) uses it.
- `VyroMarkPainter` paints the V monogram, with the animated `progress` used by the splash (body strokes draw top-down, then the cap slides in).
- `VyroBrandTile` is the monogram tile (splash, onboarding).
- `android/app/src/main/res/drawable/vyro_mark.xml` is the same V for the home-screen widgets.

Launcher and web icons are rendered from `vyro-mark-dark.svg`. Regenerate them with:

```
py tool/brand/render_icons.py                 # all icons (needs Pillow)
py tool/brand/render_icons.py --previews DIR  # also SVG reference previews
VYRO_RENDER_ICONS=1 VYRO_PREVIEW_DIR=DIR flutter test tool/brand/render_previews_test.dart
```

- Android legacy (`mipmap-*/ic_launcher.png`, 48–192 px): V at 60% of the width, full bleed on `#0B0D10`.
- Android adaptive (`mipmap-*/ic_launcher_foreground.png`, 108 dp layer): V at 43% of the width (0.43 × 108 dp), transparent, centred on the bounding box. The furthest point of the mark, the lime cap included, is 31.99 dp from the centre, inside the 33 dp circular mask. The script prints and checks this value. Background colour is `@color/vyro_ink` (`#0B0D10`).
- Android 13+ themed icon (`drawable/ic_launcher_monochrome.xml`, vector, 108 dp): one-colour silhouette of the V body and cap, no background, referenced as `<monochrome>` in `mipmap-anydpi-v26/ic_launcher.xml`. Geometry is the mark above scaled by 0.49 and centred (`x' = 54 + (x - 57.5) × 0.49`, `y' = 54 + (y - 55) × 0.49`), so the furthest point is 32.1 dp from the centre, inside the 66 dp safe zone. Android tints it, so the fill colour is ignored. It is a vector, so `render_icons.py` does not produce it: edit the file by hand if the mark changes.
- iOS (`ios/Runner/Assets.xcassets/AppIcon.appiconset`): every size in `Contents.json`, opaque, V at 60%.
- Web (`web/favicon.png`, `web/icons/Icon-*.png`): standard and maskable icons, V at 60%.

These are original provisional concepts; check trademark availability before release.
