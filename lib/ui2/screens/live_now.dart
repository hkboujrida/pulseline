// "Right now" on Today: the live heart rate and the band's state.
//
// The live HR stream costs band and phone battery, so the app only runs it
// while a screen that shows it is visible (`AppState.retainLiveHrView`). Today
// is kept alive by the tab shell even when another tab is on screen, so this
// widget owns the stream only while it is BOTH on the visible tab (TickerMode,
// which the shell's IndexedStack turns off for hidden tabs) AND the app is in
// the foreground. Leaving either releases it.

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../ui2.dart';

class LiveNow extends StatefulWidget {
  const LiveNow({super.key});

  @override
  State<LiveNow> createState() => _LiveNowState();
}

class _LiveNowState extends State<LiveNow> with WidgetsBindingObserver {
  AppState? _app;
  bool _held = false;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      _app ??= context.read<AppState>();
    } catch (_) {
      _app = null; // gallery / goldens: no AppState above
    }
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    _foreground = s == AppLifecycleState.resumed;
    _sync();
  }

  void _sync() {
    final want = _app != null && _foreground && TickerMode.valuesOf(context).enabled;
    if (want == _held) return;
    _held = want;
    if (want) {
      _app!.retainLiveHrView();
    } else {
      _app!.releaseLiveHrView();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_held) _app?.releaseLiveHrView();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    if (_app == null) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const LiveHrCard(),
      const SizedBox(height: S.x3),
      const _BandChips(),
    ]);
  }
}

class _BandChips extends StatelessWidget {
  const _BandChips();

  @override
  Widget build(BuildContext c) {
    // Selected individually so the 1 Hz HR tick does not rebuild this row.
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
