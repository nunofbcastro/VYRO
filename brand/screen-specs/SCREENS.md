# Screen map + visual layout rules

Every screen must be previewable at `/design-system`, with demo, empty, loading and error where relevant.

| Screen | Layout blueprint |
|---|---|
| Splash | Ink background, V monogram centered, discreet loading. |
| Onboarding (3) | Large editorial statement, one simple graphic, indicator dots, primary CTA bottom. |
| Profile setup | One topic per step, progress line, large selectable cards, sticky continue CTA. |
| Home | Greeting + date + avatar; large calorie ring; three thin macro bars; next-workout card; weekly snapshots. |
| Nutrition | Day selector, daily summary, four meal sections, sticky add button, scan/photo/manual choices. |
| Photo camera | Full camera preview, low-opacity framing guides, one central shutter, gallery import. |
| Food review | Photo thumbnail; candidate foods with confidence + editable portions; explicit save. |
| Barcode camera | Dark camera viewport with centered rectangle, torch, manual-code entry, failure state. |
| Product detail | Product hero, kcal headline, macro rows, quantity control, add CTA. |
| Training | Goal, today card, week-strip, workout history, create/edit plan. |
| Workout day | Exercise list, sets×reps×rest, muscle groups, reorder/edit. |
| Active session | Exercise hero, set table, +/- controls, rest timer, complete CTA. |
| Motion camera | Video preview + skeleton overlay, rep counter, supported-angle indicator, cautious hints. |
| Coach | Compact chat UI, suggested prompts, local/offline indicator, confirm plan changes. |
| Progress | Segment switcher 7/30/90/365 days; weight trend; volume chart; training streaks. |
| Profile | Header/avatar, goals, preferences, theme, privacy, export, model status. |
| Design system | Palette and typography, components grid, mini screen gallery and functional navigation to each. |

## Navigation tabs
Início · Nutrição · Treino · Progresso · Perfil. Scan and photo are actions inside Nutrição, not extra tabs.

## Home wireframe (top to bottom)
`status bar → date/greeting/avatar → calories ring and total → 3 macro mini-bars → today's workout card → weekly charts → bottom navigation`

## Important screens states
Photo recognition requires visible uncertainty and manual correction. Barcode missing fields show `Não disponível` rather than zero. Workout pose shows `Posição não detetada` if visibility is insufficient. No disguised mock-data.
