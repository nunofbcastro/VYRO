import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_services.dart';
import '../../app/l10n/strings.dart';
import '../../core/ui/vyro_ui.dart';
import 'device_health.dart';
import 'device_health_reader.dart';
import 'device_health_store.dart';

class DeviceHealthPage extends StatefulWidget {
  const DeviceHealthPage({super.key, this.reader});

  /// Test double. The real reader talks to Health Connect or Apple Health.
  final DeviceHealthReader? reader;

  @override
  State<DeviceHealthPage> createState() => _DeviceHealthPageState();
}

class _DeviceHealthPageState extends State<DeviceHealthPage> {
  DeviceHealthStore? _store;
  DeviceHealthReader? _reader;
  var _enabled = false;
  var _busy = false;
  DeviceHealthAvailability _availability = DeviceHealthAvailability.ready;
  DeviceHealthDay? _day;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final database = AppServicesScope.of(context).database;
    if (_store == null) {
      _store = DeviceHealthStore(database);
      _reader = widget.reader ?? DeviceHealthReader();
      _load();
    }
  }

  Future<void> _load() async {
    final store = _store;
    final reader = _reader;
    if (store == null || reader == null) return;
    final enabled = await store.isEnabled();
    final day = await store.read();
    final availability = await reader.availability();
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _day = day;
      _availability = availability;
    });
  }

  Future<void> _setEnabled(bool value) async {
    final store = _store;
    final reader = _reader;
    if (store == null || reader == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (value) {
        if (_availability == DeviceHealthAvailability.needsInstall) {
          await reader.installHealthConnect();
          return;
        }
        final granted = await reader.requestAccess();
        if (!granted) {
          if (mounted) setState(() => _error = 'healthDenied');
          return;
        }
      }
      await store.setEnabled(value);
      if (mounted) setState(() => _enabled = value);
      if (value) await _read();
    } on PlatformException {
      if (mounted) setState(() => _error = 'healthReadFailed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _read() async {
    final store = _store;
    final reader = _reader;
    if (store == null || reader == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final day = await reader.readToday(DateTime.now());
      await store.save(day);
      if (mounted) setState(() => _day = day);
    } on PlatformException {
      if (mounted) setState(() => _error = 'healthReadFailed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final day = _day;
    final today = day != null && day.sameDay(DateTime.now());
    return ContentPage(
      title: t.get('healthTitle'),
      children: [
        Text(t.get('healthBody')),
        const SizedBox(height: 16),
        Card(
          child: SwitchListTile(
            title: Text(t.get('healthEnable')),
            subtitle: Text(
              _availability == DeviceHealthAvailability.unsupported
                  ? t.get('healthUnavailable')
                  : _availability == DeviceHealthAvailability.needsInstall
                  ? t.get('healthInstall')
                  : t.get('healthOnDevice'),
            ),
            value: _enabled,
            onChanged:
                _busy || _availability == DeviceHealthAvailability.unsupported
                ? null
                : _setEnabled,
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            t.get(_error!),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (_enabled && _availability == DeviceHealthAvailability.ready) ...[
          const SizedBox(height: 16),
          VyroPrimaryButton(
            label: t.get('healthRead'),
            icon: Icons.refresh_rounded,
            loading: _busy,
            onPressed: _busy ? null : _read,
          ),
          const SizedBox(height: 16),
          if (day == null || !today || day.isEmpty)
            Text(t.get('healthEmpty'))
          else
            _Reading(day: day),
        ],
        const SizedBox(height: 16),
        Text(
          t.get('healthNotSent'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _Reading extends StatelessWidget {
  const _Reading({required this.day});

  final DeviceHealthDay day;

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final rows = <(String, String)>[
      if (day.steps != null) (t.get('healthSteps'), '${day.steps}'),
      if (day.distanceMeters != null)
        (t.get('healthDistance'), _distance(day.distanceMeters!)),
      if (day.activeKcal != null)
        (t.get('healthActive'), '${day.activeKcal!.round()} kcal'),
      if (day.weightKg != null)
        (t.get('healthWeight'), '${day.weightKg!.toStringAsFixed(1)} kg'),
    ];
    return VyroGroupedSection(
      children: [
        for (final row in rows) VyroListRow(title: row.$1, value: row.$2),
      ],
    );
  }
}

String _distance(double meters) {
  if (meters >= 1000) {
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }
  return '${meters.round()} m';
}

/// Home card for today's opted-in reading. Hidden when health is off.
class DeviceHealthHomeCard extends StatefulWidget {
  const DeviceHealthHomeCard({super.key});

  @override
  State<DeviceHealthHomeCard> createState() => _DeviceHealthHomeCardState();
}

class _DeviceHealthHomeCardState extends State<DeviceHealthHomeCard> {
  DeviceHealthStore? _store;
  Future<DeviceHealthDay?>? _today;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final database = AppServicesScope.of(context).database;
    if (_store == null || !identical(_store!.database, database)) {
      DeviceHealthStore.changes.removeListener(_reload);
      _store = DeviceHealthStore(database);
      DeviceHealthStore.changes.addListener(_reload);
      _today = _store!.todayIfEnabled(DateTime.now());
    }
  }

  @override
  void dispose() {
    DeviceHealthStore.changes.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    final store = _store;
    if (store == null || !mounted) return;
    setState(() => _today = store.todayIfEnabled(DateTime.now()));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DeviceHealthDay?>(
      future: _today,
      builder: (context, snapshot) {
        final day = snapshot.data;
        if (day == null) return const SizedBox.shrink();
        final t = stringsOf(context);
        final parts = <String>[
          if (day.steps != null) '${day.steps} ${t.get('healthSteps')}',
          if (day.activeKcal != null) '${day.activeKcal!.round()} kcal',
        ];
        return Padding(
          padding: const EdgeInsets.only(top: 20),
          child: ActionCard(
            icon: Icons.directions_walk_rounded,
            title: t.get('healthTitle'),
            subtitle: parts.join(' · '),
            onTap: () => Navigator.pushNamed(context, '/device-health'),
          ),
        );
      },
    );
  }
}
