// My Health's hero: the last 30 days in four tiles, and the monthly report.
//
// Each tile is the 30-day mean of stored days (gaps left out, never filled),
// the change against the 30 days before it, and a sparkline of the window.
// A tile with fewer than 7 recorded days in the window is not drawn: a mean
// of three nights is not a month.

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../ui2.dart';
import 'home_screen.dart' show go, hm;
import 'metric_detail.dart' show MetricDetail;
import 'monthly_report.dart';

/// One tile's input: the last 60 dense days, oldest first.
typedef TrendInput = ({
  String key,
  String title,
  IconData icon,
  Color color,
  bool? higherBetter,
  String Function(double) fmt,
  List<double?> days60,
});

class HealthTrendsHero extends StatelessWidget {
  final List<TrendInput> inputs;
  const HealthTrendsHero({super.key, required this.inputs});

  static List<TrendInput> standard(List<double?> Function(String, int) spark) => [
        (
          key: 'hrv',
          title: 'HRV',
          icon: LucideIcons.activity,
          color: C.green,
          higherBetter: true,
          fmt: (v) => '${v.round()} ms',
          days60: spark('hrv', 60),
        ),
        (
          key: 'resting_hr',
          title: 'Resting HR',
          icon: LucideIcons.heart,
          color: C.red,
          higherBetter: false,
          fmt: (v) => '${v.round()} bpm',
          days60: spark('resting_hr', 60),
        ),
        (
          key: 'sleep',
          title: 'Sleep',
          icon: LucideIcons.moon,
          color: C.indigo,
          higherBetter: true,
          fmt: (v) => hm(v),
          days60: spark('sleep', 60),
        ),
        (
          key: 'readiness',
          title: 'Recovery',
          icon: LucideIcons.batteryCharging,
          color: C.teal,
          higherBetter: true,
          fmt: (v) => '${v.round()}%',
          days60: spark('recovery', 60),
        ),
      ];

  @override
  Widget build(BuildContext c) {
    final tiles = [
      for (final i in inputs)
        if (i.days60.skip(30).whereType<double>().length >= 7) i,
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (tiles.isNotEmpty)
        LayoutBuilder(builder: (c, box) {
          final w = (box.maxWidth - S.x3) / 2;
          return Wrap(spacing: S.x3, runSpacing: S.x3, children: [
            for (final t in tiles) SizedBox(width: w, child: _Tile(t)),
          ]);
        })
      else
        const StatusCard(
          'Trends need a week',
          'Each trend tile appears once 7 of the last 30 days have a reading.',
          icon: LucideIcons.chartLine,
        ),
      const SizedBox(height: S.x3),
      const _ReportDoor(),
    ]);
  }
}

double? _mean(Iterable<double?> v) {
  final x = v.whereType<double>().toList();
  return x.isEmpty ? null : x.reduce((a, b) => a + b) / x.length;
}

class _Tile extends StatelessWidget {
  final TrendInput t;
  const _Tile(this.t);

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final cur = t.days60.skip(30).toList();
    final now = _mean(cur)!;
    final before = t.days60.take(30).whereType<double>().length >= 7
        ? _mean(t.days60.take(30))
        : null;
    final delta = before == null ? null : now - before;
    final steady = delta == null ||
        (before!.abs() > 0 && delta.abs() / before.abs() < .02);
    final good = steady || t.higherBetter == null
        ? null
        : (delta > 0) == t.higherBetter;
    final tone = good == null ? C.blue : (good ? C.green : C.orange);
    final line = [for (final v in cur) ?v];
    return Surface(
      onTap: () => go(c, MetricDetail(t.key)),
      semanticLabel: '${t.title}, 30-day average ${t.fmt(now)}',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(t.icon, size: 16, color: p.on(t.color)),
          const SizedBox(width: S.x2),
          Expanded(
            child: Text(t.title,
                style: F.cap.copyWith(color: p.ink2),
                overflow: TextOverflow.ellipsis),
          ),
        ]),
        const SizedBox(height: S.x2),
        Text(t.fmt(now), style: F.n24.copyWith(color: p.ink)),
        const SizedBox(height: S.x1),
        Text(
          delta == null
              ? '30-day average'
              : steady
                  ? 'Steady vs prior 30 d'
                  : '${delta > 0 ? '↑' : '↓'} ${t.fmt(delta.abs())} vs prior',
          style: F.over.copyWith(color: p.on(tone)),
          maxLines: 2,
        ),
        if (line.length >= 2) ...[
          const SizedBox(height: S.x3),
          SizedBox(
            height: 34,
            width: double.infinity,
            child: CustomPaint(
              painter: LineChart(line, p.on(t.color),
                  fill: true, t: animate(c, 1)),
            ),
          ),
        ],
      ]),
    );
  }
}

class _ReportDoor extends StatelessWidget {
  const _ReportDoor();

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    return Surface(
      pad: const EdgeInsets.all(S.x5),
      color: p.wash(C.indigo),
      elevation: 0,
      onTap: () => go(c, const MonthlyReportScreen()),
      semanticLabel: 'Open your monthly report',
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: p.fill(C.indigo), borderRadius: R.rMd),
          child: Icon(LucideIcons.calendarRange, size: 22, color: p.inkOnFill),
        ),
        const SizedBox(width: S.x4),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Your monthly report',
                style: F.head.copyWith(color: p.ink)),
            Text('This month against last, and your standout days',
                style: F.cap.copyWith(color: p.ink2)),
          ]),
        ),
        Icon(LucideIcons.chevronRight, size: 20, color: p.ink2),
      ]),
    );
  }
}
