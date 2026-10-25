# Home-screen widgets

VYRO has two widgets. Both show local data only.

| Widget | Size | Content |
| --- | --- | --- |
| **Hoje** | 4×2 (Android), medium (iOS) | Calories eaten / goal with a progress bar, calories left (or over), protein, next workout with its day, workouts done this week. |
| **Calorias** | 2×2 (Android), small (iOS) | Calories left today with a progress bar. |

| **Treino da semana** | 4×2 (Android) | Monday to Sunday with each day's status (done ✓, today •, missed !, can't –, rest), the next workout and a **Começar** button. |

The **Hoje** widget has quick-add buttons: **+ Código**, **Foto** and **Manual**. Tapping Calorias opens the diary.

## Deep links and app-icon shortcuts
Widget buttons open `vyro://action/<id>`, where `<id>` is one of `scan`, `photo`, `manual`, `training` or `assistant`. A long press on the app icon shows the same shortcuts (Ler código de barras, Fotografar refeição, Treino de hoje, Assistente) through the `quick_actions` plugin.

Both go through `LaunchActions` (`lib/app/launch_actions.dart`), which waits until the user is past onboarding, then opens the screen. iOS registers the `vyro` URL scheme in `Info.plist`, and the medium widget shows the same three quick-add buttons.

## How data flows
1. `LiveHomePage` builds a `HomeWidgetSnapshot` from today's diary, the profile goals and the weekly schedule.
2. `VyroHomeWidgets.publish` (`lib/core/platform/home_widgets.dart`) saves it with the `home_widget` plugin and asks the widgets to redraw. It skips identical snapshots and ignores errors.
3. The native widgets read the saved keys (`kcal_eaten`, `kcal_goal`, `kcal_left`, `kcal_percent`, `protein_*`, `next_workout`, `next_when`, `week_done`, `week_total`, and translated `lbl_*` labels).

Widgets update whenever the app is running and data changes. On iOS the timeline also refreshes at midnight. Nothing is sent off the device.

## Android
Ready to use, no extra setup:
- Providers: `android/app/src/main/kotlin/com/nunofbcastro/vyro/widgets/VyroWidgets.kt`
- Layouts: `res/layout/widget_today.xml`, `res/layout/widget_calories.xml` (RemoteViews; avoid plain `View`)
- Metadata: `res/xml/widget_*_info.xml`; receivers are registered in `AndroidManifest.xml`.

## iOS (one-time Xcode setup, needs a Mac)
The widget code is in `ios/VyroWidget/VyroWidget.swift`. It cannot be added to the Xcode project from Windows, so:

1. Open `ios/Runner.xcworkspace` in Xcode.
2. **File → New → Target → Widget Extension**. Name it `VyroWidget`, untick "Include Configuration Intent", and finish. Do not activate the scheme if Xcode asks.
3. Delete the Swift file Xcode generated and add `ios/VyroWidget/VyroWidget.swift` to the `VyroWidget` target.
4. Add the **App Groups** capability to both the `Runner` and `VyroWidget` targets, with the group `group.com.nunofbcastro.vyro`. If you change the bundle id, update `VyroHomeWidgets.appGroupId` and `appGroupId` in the Swift file to match.
5. Set the widget target's deployment target to iOS 16 or later, then build.

The widget `kind` (`VyroWidget`) must match `_iosKind` in `home_widgets.dart`.
