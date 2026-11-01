// The monthly report: one calendar month against the one before it.
//
// Averages of stored daily values only — a day the band did not record is
// left out of the mean, and the count of days behind every average is
// printed beside it, so a month with nine recorded days cannot pass for a
// full one. Highlights name a real day and its real value.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/local_repository.dart';
import '../ui2.dart';
import 'home_screen.dart' show go, pointsOf, repoOf;
import 'metric_detail.dart' show MetricDetail, detailScaffold;

/// One metric in the report.
class ReportMetric {
  final String alias, title, unit;
  final IconData icon;
  final Color color;

  /// Which way is good news. Null: no verdict, direction only.
  final bool? higherBetter;
  final String Function(double) fmt;
  const ReportMetric(this.alias, this.title, this.unit, this.icon, this.color,
      this.higherBetter, this.fmt);
}

String _int(double v) => v.round().toString();
String _hm(double min) => '${min ~/ 60}h ${(min % 60).round().toString().padLeft(2, '0')}m';

final kReportMetrics = <ReportMetric>[
  ReportMetric('recovery', 'Recovery', '%', LucideIcons.batteryCharging,
      C.green, true, _int),
  ReportMetric('hrv', 'HRV', 'ms', LucideIcons.activity, C.green, true, _int),
  ReportMetric('resting_hr', 'Resting heart rate', 'bpm', LucideIcons.heart,
      C.red, false, _int),
  ReportMetric(
      'sleep', 'Sleep', '', LucideIcons.moon, C.indigo, true, _hm),
  ReportMetric('efficiency', 'Sleep efficiency', '%', LucideIcons.bedDouble,
      C.indigo, true, _int),
  ReportMetric('strain', 'Strain', '', LucideIcons.flame, C.purple, null,
      (v) => v.toStringAsFixed(1)),
  ReportMetric('steps', 'Steps', '', LucideIcons.footprints, C.teal, true,
      (v) => NumberFormat.decimalPattern().format(v.round())),
];

class MonthStat {
  final ReportMetric m;
  final double? mean, prevMean;
  final int days, prevDays;
  final (DateTime, double)? best, worst;
  const MonthStat(this.m, this.mean, this.prevMean, this.days, this.prevDays,
      this.best, this.worst);
}

class MonthReport {
  final DateTime month; // first of month
  final List<MonthStat> stats;
  final int workouts;
  final double workoutMin;
  final int prevWorkouts;
  const MonthReport(this.month, this.stats, this.workouts, this.workoutMin,
      this.prevWorkouts);

  static bool _in(DateTime d, DateTime month) =>
      d.year == month.year && d.month == month.month;

  static Future<MonthReport> load(LocalRepository repo, DateTime month) async {
    final prev = DateTime(month.year, month.month - 1);
    final stats = <MonthStat>[];
    for (final m in kReportMetrics) {
      final pts = pointsOf(await repo.getChart(m.alias));
      final cur = <(DateTime, double)>[], old = <double>[];
      for (final p in pts) {
        final d = DateTime.fromMillisecondsSinceEpoch(p.t * 1000);
        if (_in(d, month)) cur.add((d, p.v));
        if (_in(d, prev)) old.add(p.v);
      }
      double? mean(Iterable<double> v) =>
          v.isEmpty ? null : v.reduce((a, b) => a + b) / v.length;
      (DateTime, double)? pick(bool max) => cur.isEmpty
          ? null
          : cur.reduce((a, b) => (max ? b.$2 > a.$2 : b.$2 < a.$2) ? b : a);
      final hb = m.higherBetter ?? true;
      stats.add(MonthStat(m, mean(cur.map((e) => e.$2)), mean(old), cur.length,
          old.length, pick(hb), pick(!hb)));
    }

    var n = 0, pn = 0;
    var mins = 0.0;
    final rows = (await repo.getWorkouts(range: 'all'))['workouts'];
    if (rows is List) {
      for (final r in rows) {
        if (r is! Map || r['start_ts'] is! num) continue;
        final d = DateTime.fromMillisecondsSinceEpoch(
            (r['start_ts'] as num).toInt() * 1000);
        if (_in(d, month)) {
          n++;
          mins += (r['duration_min'] as num?)?.toDouble() ?? 0;
        } else if (_in(d, prev)) {
          pn++;
        }
      }
    }
    return MonthReport(month, stats, n, mins, pn);
  }
}

class MonthlyReportScreen extends StatefulWidget {
  final MonthReport? data;
  const MonthlyReportScreen({super.key, this.data});

  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportState();
}

class _MonthlyReportState extends State<MonthlyReportScreen> {
  late DateTime _month;
  MonthReport? _r;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = widget.data?.month ?? DateTime(now.year, now.month);
    _r = widget.data;
    if (_r == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _load() async {
    final repo = repoOf(context);
    if (repo == null) return;
    final want = _month;
    setState(() => (_r = null, _failed = false));
    try {
      final r = await MonthReport.load(repo, want);
      if (mounted && want == _month) setState(() => _r = r);
    } catch (_) {
      if (mounted && want == _month) setState(() => _failed = true);
    }
  }

  void _step(int by) {
    final now = DateTime.now();
    final next = DateTime(_month.year, _month.month + by);
    if (next.isAfter(DateTime(now.year, now.month))) return;
    _month = next;
    _load();
  }

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final now = DateTime.now();
    final isCurrent = _month.year == now.year && _month.month == now.month;
    final r = _r;

    final header = Surface(
      pad: const EdgeInsets.symmetric(horizontal: S.x2, vertical: S.x1),
      child: Row(children: [
        Pressable(
          onTap: () => _step(-1),
          semanticLabel: 'Previous month',
          child: Padding(
            padding: const EdgeInsets.all(S.x2),
            child: Icon(LucideIcons.chevronLeft, color: p.ink),
          ),
        ),
        Expanded(
          child: Text(DateFormat.yMMMM().format(_month),
              textAlign: TextAlign.center,
              style: F.head.copyWith(color: p.ink)),
        ),
        Pressable(
          onTap: isCurrent ? null : () => _step(1),
          semanticLabel: 'Next month',
          child: Padding(
            padding: const EdgeInsets.all(S.x2),
            child: Icon(LucideIcons.chevronRight,
                color: isCurrent ? p.track : p.ink),
          ),
        ),
      ]),
    );

    final List<Widget> body;
    if (_failed) {
      body = [
        StatusCard('Could not build this report',
            'The stored rows failed to load. Nothing was deleted.',
            fix: 'Try again', icon: LucideIcons.databaseZap, onFix: _load),
      ];
    } else if (r == null) {
      body = const [
        SizedBox(height: S.x8),
        Center(child: CircularProgressIndicator()),
      ];
    } else if (r.stats.every((s) => s.days == 0)) {
      body = const [
        StatusCard('Nothing recorded this month',
            'No day in this month has a stored reading yet.',
            icon: LucideIcons.calendarX),
      ];
    } else {
      body = [
        if (isCurrent)
          Padding(
            padding: const EdgeInsets.only(top: S.x3),
            child: Text(
              'Month in progress — ${now.day} of '
              '${DateUtils.getDaysInMonth(now.year, now.month)} days so far.',
              style: F.cap.copyWith(color: p.ink3),
            ),
          ),
        Section(
          'Averages',
          Surface(
            child: Column(children: [
              for (final s in r.stats)
                if (s.mean != null) _row(c, s),
            ]),
          ),
        ),
        Section('Highlights', _highlights(c, r)),
        Section(
          'Training',
          Row(children: [
            Expanded(
              child: SignalCard(LucideIcons.dumbbell, C.purple, 'Workouts',
                  '${r.workouts}',
                  sub: r.prevWorkouts == 0
                      ? 'this month'
                      : '${r.workouts - r.prevWorkouts >= 0 ? '+' : ''}'
                          '${r.workouts - r.prevWorkouts} vs last month'),
            ),
            const SizedBox(width: S.x3),
            Expanded(
              child: SignalCard(LucideIcons.timer, C.orange, 'Time active',
                  _hm(r.workoutMin),
                  sub: 'in workouts'),
            ),
          ]),
        ),
        const SizedBox(height: S.x8),
      ];
    }

    return detailScaffold(c, 'Monthly report', [header, ...body]);
  }

  Widget _row(BuildContext c, MonthStat s) {
    final p = P.of(c);
    final m = s.m;
    final delta = s.prevMean == null ? null : s.mean! - s.prevMean!;
    // Changes smaller than 2% of the previous month read as "steady".
    final steady = delta == null ||
        (s.prevMean!.abs() > 0 && (delta.abs() / s.prevMean!.abs()) < .02);
    final good = steady || m.higherBetter == null
        ? null
        : (delta > 0) == m.higherBetter;
    final tone = good == null ? C.blue : (good ? C.green : C.orange);
    final unit = m.unit.isEmpty ? '' : ' ${m.unit}';
    return Pressable(
      onTap: () => go(c, MetricDetail(m.alias == 'recovery' ? 'readiness' : m.alias)),
      semanticLabel: m.title,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: S.x3),
        child: Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration:
                BoxDecoration(color: p.wash(m.color), borderRadius: R.rMd),
            child: Icon(m.icon, size: 16, color: p.on(m.color)),
          ),
          const SizedBox(width: S.x3),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.title, style: F.cap.copyWith(color: p.ink2)),
              Text('${m.fmt(s.mean!)}$unit',
                  style: F.n17.copyWith(color: p.ink)),
              Text('${s.days} ${s.days == 1 ? 'day' : 'days'} recorded',
                  style: F.over.copyWith(color: p.ink3)),
            ]),
          ),
          if (delta != null)
            Pill(
              steady
                  ? 'Steady'
                  : '${delta > 0 ? '↑' : '↓'} ${m.fmt(delta.abs())}$unit',
              tone,
            )
          else
            Text('No prior month', style: F.cap.copyWith(color: p.ink3)),
        ]),
      ),
    );
  }

  Widget _highlights(BuildContext c, MonthReport r) {
    final p = P.of(c);
    final df = DateFormat.MMMEd();
    final items = <(IconData, Color, String, String)>[];
    MonthStat? st(String a) {
      for (final s in r.stats) {
        if (s.m.alias == a) return s;
      }
      return null;
    }

    final rec = st('recovery');
    if (rec?.best != null) {
      items.add((LucideIcons.batteryCharging, C.green, 'Best recovery',
          '${rec!.m.fmt(rec.best!.$2)}% · ${df.format(rec.best!.$1)}'));
    }
    final sl = st('sleep');
    if (sl?.best != null) {
      items.add((LucideIcons.moon, C.indigo, 'Longest sleep',
          '${_hm(sl!.best!.$2)} · ${df.format(sl.best!.$1)}'));
    }
    final str = st('strain');
    if (str?.best != null) {
      items.add((LucideIcons.flame, C.purple, 'Hardest day',
          '${str!.m.fmt(str.best!.$2)} strain · ${df.format(str.best!.$1)}'));
    }
    final steps = st('steps');
    if (steps?.best != null) {
      items.add((LucideIcons.footprints, C.teal, 'Most steps',
          '${steps!.m.fmt(steps.best!.$2)} · ${df.format(steps.best!.$1)}'));
    }
    if (rec?.worst != null && (rec!.days) > 3) {
      items.add((LucideIcons.batteryLow, C.orange, 'Lowest recovery',
          '${rec.m.fmt(rec.worst!.$2)}% · ${df.format(rec.worst!.$1)}'));
    }
    if (items.isEmpty) {
      return const StatusCard('No highlights yet',
          'Highlights need at least one recorded day this month.');
    }
    return Surface(
      child: Column(children: [
        for (final (icon, color, label, value) in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: S.x2),
            child: Row(children: [
              Icon(icon, size: 18, color: p.on(color)),
              const SizedBox(width: S.x3),
              Expanded(
                child: Text(label, style: F.body.copyWith(color: p.ink2)),
              ),
              Flexible(
                child: Text(value,
                    textAlign: TextAlign.right,
                    style: F.body.copyWith(
                        color: p.ink, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
      ]),
    );
  }
}
