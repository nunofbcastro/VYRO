import 'package:flutter/material.dart';

import '../../app/l10n/strings.dart';
import '../../core/widgets/vyro_widgets.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    return ContentPage(
      title: t.get('privacyPolicy'),
      children: [
        for (final section in [
          ('policyStorageTitle', 'policyStorageBody'),
          ('policyNetworkTitle', 'policyNetworkBody'),
          ('policyMediaTitle', 'policyMediaBody'),
          ('policyControlTitle', 'policyControlBody'),
          ('policyBackupTitle', 'policyBackupBody'),
        ]) ...[
          SectionTitle(t.get(section.$1)),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(t.get(section.$2)),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
