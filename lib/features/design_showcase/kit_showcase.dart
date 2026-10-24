import 'package:flutter/material.dart';

import '../../core/ui/vyro_ui.dart';

/// Live examples of the shared UI kit, shown at the top of `/design-system`.
/// Values are demo data; every widget here is the real component.
class KitShowcase extends StatefulWidget {
  const KitShowcase({super.key});

  @override
  State<KitShowcase> createState() => _KitShowcaseState();
}

class _KitShowcaseState extends State<KitShowcase> {
  int _range = 30;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const VyroSectionTitle(label: 'UI kit · lib/core/ui/vyro_ui.dart'),
        Row(
          children: [
            const VyroBrandTile(size: 56),
            const SizedBox(width: 16),
            VyroRing(
              value: 0.62,
              size: 72,
              stroke: 6,
              child: Text('62%', style: theme.textTheme.titleSmall),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: [
                  VyroMacroBar(
                    label: 'Proteína',
                    value: 82,
                    goal: 140,
                    color: scheme.primary,
                  ),
                  const SizedBox(height: 8),
                  VyroMacroBar(
                    label: 'Hidratos',
                    value: 150,
                    goal: 260,
                    color: scheme.tertiary,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        VyroSegmentedControl<int>(
          value: _range,
          segments: const {7: '7D', 30: '30D', 90: '90D', 365: '1A'},
          onChanged: (value) => setState(() => _range = value),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: VyroActionTile(
                icon: Icons.barcode_reader,
                label: 'Código',
                primary: true,
                onTap: () {},
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: VyroActionTile(
                icon: Icons.photo_camera_outlined,
                label: 'Foto',
                onTap: () {},
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: VyroActionTile(
                icon: Icons.edit_note_rounded,
                label: 'Manual',
                onTap: () {},
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        VyroGroupedSection(
          header: 'VyroGroupedSection',
          footer:
              'VyroListRow com ícone, valor, chevron e variante destrutiva.',
          children: [
            VyroListRow(
              icon: Icons.palette_outlined,
              title: 'Aspeto',
              value: 'Escuro',
              onTap: () {},
            ),
            VyroListRow(
              icon: Icons.language_rounded,
              iconColor: scheme.secondary,
              title: 'Idioma',
              value: 'PT',
              onTap: () {},
            ),
            VyroListRow(
              icon: Icons.delete_outline_rounded,
              title: 'Apagar dados',
              destructive: true,
              onTap: () {},
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 70,
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: VyroTheme.ctaGradient(
                    darkMode: theme.brightness == Brightness.dark,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: VyroGlass(
                  borderRadius: BorderRadius.circular(14),
                  child: Center(
                    child: Text('VyroGlass', style: theme.textTheme.titleSmall),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
