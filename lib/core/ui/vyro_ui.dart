/// VYRO UI kit — import this one file to get every shared building block.
///
/// ```dart
/// import 'package:vyro/core/ui/vyro_ui.dart';
/// ```
///
/// Catalogue (details in `docs/COMPONENTS.md`, live in `/design-system`):
///
/// * Foundations — `VyroTheme` (colours, typography, Material theme).
/// * Page structure — `VyroPageScaffold` (tab page with collapsing large
///   title), `VyroSubpageScaffold` (pushed page with back button and sticky
///   footer), `VyroPageBody`, `VyroBackdrop`, `VyroNavBar`.
/// * Surfaces — `VyroCard`, `VyroGlass`, `VyroGroupedSection` +
///   `VyroListRow`.
/// * Actions — `VyroPrimaryButton`, `VyroRoundButton`, `VyroActionTile`,
///   `VyroChoiceCard`, `VyroPillChip`, `VyroSegmentedControl`.
/// * Data — `VyroRing`, `VyroMacroBar`, `MetricCard`, `ActionCard`.
/// * Brand — `VyroBrandTile`, `VyroMarkPainter`, `VyroBrandRow`.
/// * Flow — `VyroStepRail`, `VyroStepPill`, `VyroStepHeader`, `VyroDots`,
///   `VyroFooter`, `VyroSectionTitle`, `DemoBadge`.
library;

export '../../app/theme/vyro_chrome.dart';
export '../../app/theme/vyro_shell.dart';
export '../../app/theme/vyro_theme.dart';
export '../widgets/vyro_widgets.dart';
export 'components/vyro_action_tile.dart';
export 'components/vyro_glass.dart';
export 'components/vyro_grouped_list.dart';
export 'components/vyro_progress.dart';
export 'components/vyro_segmented_control.dart';
