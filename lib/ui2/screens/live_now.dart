// "Right now" on Today: what the band is telling us this minute.
//
//   · live heart rate and its recent trace (LiveHrCard)
//   · the heart-rate zone that beat falls in, from YOUR zone table
//   · moving or still, from the wrist's smoothed movement (ENMO)
//   · today's strain, kept fresh by a sync every 10 minutes while open
//   · "HRV right now": a one-minute still measurement on demand
//   · band connection, wear and battery
//
// ON DEMAND. The live stream costs band and phone battery, so the card starts
// off every time. "Go live" turns it on; it turns itself off again when Today
// stops being the visible tab (TickerMode — the shell's IndexedStack turns it
// off for hidden tabs), when the app leaves the foreground, or after
// [_kLiveFor]. An HRV measurement in progress holds its own stream.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../l10n/decimal_text.dart' show displayFixed;
import '../../state/app_state.dart';
import '../activity/zones.dart' show ZoneRow, ZonesData;
import '../ui2.dart';

/// How long one "Go live" lasts before it switches itself off.
const _kLiveForMinutes = 15;

/// Wrist ENMO thresholds (g), Hildebrand et al. 2014, wrist-worn
/// accelerometers: sedentary < 0.046, light < 0.093, moderate < 0.418.
String _movementWord(double g) => g < .046
    ? 'Still'
    : g < .093
        ? 'Light movement'
        : g < .418
            ? 'Moving'
            : 'Very active';

class LiveNow extends StatefulWidget {
  /// Today's strain as last derived, and the bound of its scale. Passed in by
  /// Today, which reloads after every derive.
  final double? strain;
  const LiveNow({super.key, this.strain});

  @override
  State<LiveNow> createState() => _LiveNowState();
}

class _LiveNowState extends State<LiveNow> with WidgetsBindingObserver {
  AppState? _app;
  bool _on = false;
  Timer? _autoOff;
  bool _held = false;
  bool _foreground = true;
  Timer? _resync;
  List<ZoneRow> _zones = const [];
  Map<String, dynamic>? _spot;
  DateTime? _spotAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_app == null) {
      try {
        _app = context.read<AppState>();
        _loadZones();
      } catch (_) {
        _app = null; // gallery / goldens
      }
    }
    _sync();
  }

  Future<void> _loadZones() async {
    final repo = _app?.repo;
    if (repo == null) return;
    try {
      final z = await ZonesData.load(repo);
      if (mounted) setState(() => _zones = z.zones);
    } catch (_) {/* no zones: the zone strip just is not drawn */}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    _foreground = s == AppLifecycleState.resumed;
    _sync();
    if (mounted) setState(() {}); // show "Go live" again after a background
  }

  void _sync() {
    final app = _app;
    final visible = _foreground && TickerMode.valuesOf(context).enabled;
    // On demand: leaving the screen ends the live session, it does not pause
    // it. Coming back shows "Go live" again.
    if (_on && !visible) {
      _on = false;
      _autoOff?.cancel();
    }
    final want = app != null && _on && visible;
    if (want == _held) return;
    _held = want;
    if (want) {
      app.retainLiveHrView();
      // Strain is derived from synced history; a sync every 10 minutes while
      // someone is looking keeps it close to live without a second formula.
      _resync = Timer.periodic(Motion.tick * 600, (_) => app.syncNow());
    } else {
      app!.releaseLiveHrView();
      _resync?.cancel();
      _resync = null;
    }
  }

  void _toggle(bool on) {
    _autoOff?.cancel();
    if (on) {
      _autoOff = Timer(Motion.tick * 60 * _kLiveForMinutes, () {
        if (mounted) _toggle(false);
      });
    }
    setState(() => _on = on);
    _sync();
  }

  Future<void> _measureHrv() async {
    final app = _app;
    if (app == null) return;
    setState(() => _spot = null);
    final r = await app.runHrvSpotCheck();
    if (mounted) setState(() => (_spot = r, _spotAt = DateTime.now()));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _resync?.cancel();
    _autoOff?.cancel();
    if (_held) _app?.releaseLiveHrView();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    if (_app == null) return const SizedBox.shrink();
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(S.x1, S.x8, 0, S.x2),
      child: Row(children: [
        Expanded(
            child: Text('Right now', style: F.head.copyWith(color: p.ink))),
        Text(_on ? 'Live · $_kLiveForMinutes min' : 'Off',
            style: F.cap.copyWith(color: p.ink3)),
        const SizedBox(width: S.x2),
        Switch.adaptive(
          value: _on,
          onChanged: _toggle,
          activeTrackColor: p.fill(C.green),
        ),
      ]),
    );
    if (!_on) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        header,
        Surface(
          onTap: () => _toggle(true),
          semanticLabel: 'Go live',
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration:
                  BoxDecoration(color: p.fill(C.red), shape: BoxShape.circle),
              child: Icon(LucideIcons.radio, size: 20, color: p.inkOnFill),
            ),
            const SizedBox(width: S.x3),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Go live', style: F.head.copyWith(color: p.ink)),
                    Text(
                      'Heart rate, zone, movement, strain and HRV now. '
                      'Stops after $_kLiveForMinutes min or when you leave, to '
                      'save battery.',
                      style: F.cap.copyWith(color: p.ink2),
                    ),
                  ]),
            ),
          ]),
        ),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      header,
      const LiveHrCard(),
      const SizedBox(height: S.x3),
      _ZoneStrip(zones: _zones),
      _LiveTiles(
        strain: widget.strain,
        spot: _spot,
        spotAt: _spotAt,
        onMeasure: _measureHrv,
      ),
      const SizedBox(height: S.x3),
      const _BandChips(),
    ]);
  }
}

/// The five zones as a bar, the live beat's zone lit. Not drawn without a
/// zone table or a live beat.
class _ZoneStrip extends StatelessWidget {
  final List<ZoneRow> zones;
  const _ZoneStrip({required this.zones});

  static const _cols = [C.blue, C.teal, C.green, C.orange, C.red];

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final hr = c.select<AppState, int?>((a) => a.liveHr);
    if (hr == null || zones.length != 5) return const SizedBox.shrink();
    int? at;
    for (final z in zones) {
      if (hr >= z.lo && hr <= z.hi) at = z.zone;
    }
    if (at == null && hr > zones.last.hi) at = zones.last.zone;
    final name = at == null
        ? 'Below zone 1 · resting'
        : 'Zone $at · ${zones[at - 1].name}';
    return Padding(
      padding: const EdgeInsets.only(bottom: S.x3),
      child: Surface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
              style: F.body.copyWith(
                  color: at == null ? p.ink2 : p.on(_cols[at - 1]),
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: S.x2),
          Row(children: [
            for (var i = 0; i < 5; i++) ...[
              if (i > 0) const SizedBox(width: S.x1),
              Expanded(
                child: Container(
                  height: at == i + 1 ? 12 : 8,
                  decoration: BoxDecoration(
                    color: at == i + 1 ? p.on(_cols[i]) : p.wash(_cols[i]),
                    borderRadius: R.rPill,
                  ),
                ),
              ),
            ],
          ]),
          const SizedBox(height: S.x1),
          Row(children: [
            for (final z in zones)
              Expanded(
                child: Text('${z.lo}',
                    style: F.over.copyWith(color: p.ink3)),
              ),
          ]),
        ]),
      ),
    );
  }
}

class _LiveTiles extends StatelessWidget {
  final double? strain;
  final Map<String, dynamic>? spot;
  final DateTime? spotAt;
  final VoidCallback onMeasure;
  const _LiveTiles(
      {required this.strain,
      required this.spot,
      required this.spotAt,
      required this.onMeasure});

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final g = c.select<AppState, double?>((a) => a.liveMovementG);
    final measuring = c.select<AppState, bool>((a) => a.hrvSpotCheckActive);
    final connected = c.select<AppState, bool>((a) => a.isConnected);

    Widget tile(IconData icon, Color col, String label, String value,
            String sub,
            {VoidCallback? onTap}) =>
        Surface(
          onTap: onTap,
          semanticLabel: '$label, $value',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, size: 16, color: p.on(col)),
              const SizedBox(width: S.x2),
              Expanded(
                child: Text(label,
                    style: F.cap.copyWith(color: p.ink2),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
            const SizedBox(height: S.x2),
            Text(value, style: F.n24.copyWith(color: p.ink)),
            const SizedBox(height: S.x1),
            Text(sub, style: F.over.copyWith(color: p.ink3), maxLines: 2),
          ]),
        );

    // HRV right now.
    final String hrvValue, hrvSub;
    if (measuring) {
      hrvValue = 'Measuring…';
      hrvSub = 'Sit still for one minute';
    } else if (spot?['ok'] == true && spot?['rmssd'] != null) {
      final at = spotAt;
      hrvValue = '${spot!['rmssd']} ms';
      hrvSub = at == null
          ? 'Tap to measure again'
          : 'At ${TimeOfDay.fromDateTime(at).format(c)} · tap to redo';
    } else if (spot != null) {
      hrvValue = 'Too noisy';
      hrvSub = 'Not enough clean beats — keep still and retry';
    } else {
      hrvValue = 'Measure';
      hrvSub = connected ? 'One minute, sitting still' : 'Connect your band';
    }

    final tiles = [
      tile(LucideIcons.activity, C.green, 'HRV right now', hrvValue, hrvSub,
          onTap: measuring || !connected ? null : onMeasure),
      if (g != null)
        tile(LucideIcons.footprints, C.teal, 'Movement', _movementWord(g),
            'From the wrist, last ~10 s'),
      if (strain != null)
        tile(LucideIcons.zap, C.purple, 'Strain today',
            displayFixed(strain!, 1), 'Refreshed every 10 min while open'),
    ];
    return LayoutBuilder(builder: (c, box) {
      final w = (box.maxWidth - S.x3) / 2;
      return Wrap(spacing: S.x3, runSpacing: S.x3, children: [
        for (final t in tiles) SizedBox(width: w, child: t),
      ]);
    });
  }
}

class _BandChips extends StatelessWidget {
  const _BandChips();

  @override
  Widget build(BuildContext c) {
    final connected = c.select<AppState, bool>((a) => a.isConnected);
    final wrist = c.select<AppState, bool?>((a) => a.device.wristOn);
    final pct = c.select<AppState, double?>((a) => a.device.batteryPct);
    final charging = c.select<AppState, bool?>((a) => a.device.charging);
    return Wrap(spacing: S.x2, runSpacing: S.x2, children: [
      Pill(connected ? 'Band connected' : 'Band not connected',
          connected ? C.green : C.orange,
          icon: connected ? LucideIcons.bluetooth : LucideIcons.bluetoothOff),
      if (connected && wrist != null)
        Pill(wrist ? 'On wrist' : 'Off wrist', wrist ? C.teal : C.orange,
            icon: LucideIcons.watch),
      if (pct != null)
        Pill(
            charging == true
                ? 'Charging · ${pct.round()}%'
                : 'Battery ${pct.round()}%',
            pct < 20 && charging != true ? C.red : C.blue,
            icon: charging == true
                ? LucideIcons.batteryCharging
                : LucideIcons.batteryMedium),
    ]);
  }
}
