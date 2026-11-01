// Strength progress: volume, personal records and per-lift history.
//
// Built only from what the live strength logger stored in `strength_set`.
// The one derived number is the estimated one-rep max (Epley:
// load × (1 + reps / 30)), labelled as an estimate everywhere it appears and
// computed only for sets of 1–12 reps, where the formula is meant to be used.
// A bodyweight set has no load and contributes reps, never a zero-kilo set.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/db.dart';
import '../../state/units_controller.dart';
import '../activity/catalogue.dart' show exerciseByKey;
import '../ui2.dart';
import 'home_screen.dart' show go, unitsOf;
import 'metric_detail.dart' show detailScaffold;

/// Epley, for 1–12 reps with a load. Null otherwise.
double? estimatedOneRepMax(num? loadKg, num? reps) {
  if (loadKg == null || reps == null || loadKg <= 0) return null;
  if (reps < 1 || reps > 12) return null;
  return reps == 1 ? loadKg.toDouble() : loadKg * (1 + reps / 30);
}

@immutable
class LiftSet {
  final String session, exercise;
  final int? reps;
  final double? kg;
  final DateTime at;
  const LiftSet(this.session, this.exercise, this.reps, this.kg, this.at);
  double? get e1rm => estimatedOneRepMax(kg, reps);
  double get volume => (kg ?? 0) * (reps ?? 0);
}

/// One session of one lift.
@immutable
class LiftSession {
  final String session;
  final DateTime day;
  final List<LiftSet> sets;

  /// This session's best estimate beat every earlier session's.
  final bool pr;
  const LiftSession(this.session, this.day, this.sets, {this.pr = false});

  double? get bestE1rm => sets
      .map((s) => s.e1rm)
      .whereType<double>()
      .fold<double?>(null, (a, b) => a == null || b > a ? b : a);
  double? get topKg => sets
      .map((s) => s.kg)
      .whereType<double>()
      .fold<double?>(null, (a, b) => a == null || b > a ? b : a);
  double get volume => sets.fold(0, (a, s) => a + s.volume);
  int get reps => sets.fold(0, (a, s) => a + (s.reps ?? 0));
}

@immutable
class LiftHistory {
  final String key, label;
  final List<LiftSession> sessions; // oldest first
  const LiftHistory(this.key, this.label, this.sessions);

  LiftSession get last => sessions.last;
  double? get bestE1rm => sessions
      .map((s) => s.bestE1rm)
      .whereType<double>()
      .fold<double?>(null, (a, b) => a == null || b > a ? b : a);
}

@immutable
class StrengthData {
  final List<LiftHistory> lifts; // most recently trained first
  /// Volume (kg × reps) per week, last 8 weeks, oldest first; week starts Monday.
  final List<double> weeklyVolume;
  final DateTime weekEnd;
  const StrengthData(this.lifts, this.weeklyVolume, this.weekEnd);

  List<(LiftHistory, LiftSession)> get recentPrs {
    final out = <(LiftHistory, LiftSession)>[];
    for (final l in lifts) {
      for (final s in l.sessions) {
        if (s.pr) out.add((l, s));
      }
    }
    out.sort((a, b) => b.$2.day.compareTo(a.$2.day));
    return out;
  }

  static StrengthData fromRows(List<Map<String, Object?>> rows, DateTime now,
      {String Function(String key)? labelOf}) {
    final sets = [
      for (final r in rows)
        LiftSet(
          (r['session_id'] as String?) ?? '',
          (r['exercise_key'] as String?) ?? '',
          (r['reps'] as num?)?.toInt(),
          (r['load_kg'] as num?)?.toDouble(),
          DateTime.fromMillisecondsSinceEpoch(
              ((r['at_ts'] as num?) ?? 0).toInt() * 1000),
        ),
    ];

    final byLift = <String, Map<String, List<LiftSet>>>{};
    for (final s in sets) {
      (byLift.putIfAbsent(s.exercise, () => {}))
          .putIfAbsent(s.session, () => [])
          .add(s);
    }

    final lifts = <LiftHistory>[];
    for (final e in byLift.entries) {
      final raw = e.value.values.toList()
        ..sort((a, b) => a.first.at.compareTo(b.first.at));
      double? best;
      final sessions = <LiftSession>[];
      for (final ss in raw) {
        final s = LiftSession(ss.first.session, ss.first.at, ss);
        final b = s.bestE1rm;
        // The first session cannot be a record: there is nothing to beat.
        final pr = b != null && best != null && b > best + 1e-9;
        if (b != null && (best == null || b > best)) best = b;
        sessions.add(LiftSession(s.session, s.day, ss, pr: pr));
      }
      lifts.add(LiftHistory(
          e.key, labelOf?.call(e.key) ?? e.key, sessions));
    }
    lifts.sort((a, b) => b.last.day.compareTo(a.last.day));

    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final weekly = List<double>.filled(8, 0);
    // Whole days in UTC so a DST change cannot shift a set into a neighbour.
    final m0 = DateTime.utc(monday.year, monday.month, monday.day);
    for (final s in sets) {
      final d = DateTime.utc(s.at.year, s.at.month, s.at.day);
      final start = DateTime.utc(d.year, d.month, d.day - (s.at.weekday - 1));
      final idx = 7 - m0.difference(start).inDays ~/ 7;
      if (idx >= 0 && idx < 8) weekly[idx] += s.volume;
    }
    return StrengthData(lifts, weekly, monday);
  }
}

String _liftLabel(String key) => exerciseByKey(key)?.label ?? key;

class StrengthProgressScreen extends StatefulWidget {
  final StrengthData? data;
  const StrengthProgressScreen({super.key, this.data});

  @override
  State<StrengthProgressScreen> createState() => _StrengthProgressState();
}

class _StrengthProgressState extends State<StrengthProgressScreen> {
  StrengthData? _d;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _d = widget.data;
    if (_d == null) _load();
  }

  Future<void> _load() async {
    try {
      final rows = await LocalDb.allStrengthSets();
      final d =
          StrengthData.fromRows(rows, DateTime.now(), labelOf: _liftLabel);
      if (mounted) setState(() => (_d = d, _failed = false));
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final u = unitsOf(c) ?? UnitsController.seed(UnitSystem.metric);
    String w(double kg) => u.weight(kg);
    final d = _d;

    final List<Widget> body;
    if (_failed) {
      body = [
        StatusCard('Could not read your sets',
            'The stored rows failed to load. Nothing was deleted.',
            fix: 'Try again', icon: LucideIcons.databaseZap, onFix: _load),
      ];
    } else if (d == null) {
      body = const [
        SizedBox(height: S.x8),
        Center(child: CircularProgressIndicator()),
      ];
    } else if (d.lifts.isEmpty) {
      body = const [
        StatusCard(
          'No strength sessions yet',
          'Start a strength workout from the Activity tab and log your sets. '
              'Records and trends appear here after your second session of a '
              'lift.',
          icon: LucideIcons.dumbbell,
        ),
      ];
    } else {
      final prs = d.recentPrs;
      final vol = [for (final v in d.weeklyVolume) u.weightValue(v)];
      final axis = AxisSpec.of(vol, floor: 0,
          format: (v) => v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}k' : axisInt(v));
      body = [
        Row(children: [
          Expanded(
              child: SignalCard(LucideIcons.trophy, C.yellow, 'Records',
                  '${prs.where((e) => DateTime.now().difference(e.$2.day).inDays < 30).length}',
                  sub: 'last 30 days')),
          const SizedBox(width: S.x3),
          Expanded(
              child: SignalCard(LucideIcons.dumbbell, C.purple, 'Lifts',
                  '${d.lifts.length}',
                  sub: 'logged')),
        ]),
        Section(
          'Weekly volume',
          Surface(
            child: ChartFrame(
              title: 'Total lifted',
              unit: u.isImperial ? 'lb' : 'kg',
              height: 110,
              yAxis: axis,
              xLabels: [
                DateFormat.MMMd().format(DateTime(
                    d.weekEnd.year, d.weekEnd.month, d.weekEnd.day - 49)),
                'This week',
              ],
              footnote: 'Weighted sets only — bodyweight sets add reps, not '
                  'load, so a week of pull-ups is not an easy week.',
              series: vol,
              child: CustomPaint(
                size: Size.infinite,
                painter: Bars(vol, p.on(C.purple),
                    highlight: 7, axis: axis, t: animate(c, 1)),
              ),
            ),
          ),
        ),
        if (prs.isNotEmpty)
          Section(
            'Recent records',
            Surface(
              child: Column(children: [
                for (final (l, s) in prs.take(5))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: S.x2),
                    child: Row(children: [
                      Icon(LucideIcons.trophy, size: 18, color: p.on(C.yellow)),
                      const SizedBox(width: S.x3),
                      Expanded(
                        child: Text(l.label,
                            style: F.body.copyWith(color: p.ink),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      Text('${w(s.bestE1rm!)} est. 1RM',
                          style: F.cap.copyWith(color: p.ink2)),
                    ]),
                  ),
              ]),
            ),
          ),
        Section(
          'Your lifts',
          Column(children: [
            for (final l in d.lifts) ...[
              _LiftRow(l, w),
              const SizedBox(height: S.x3),
            ],
          ]),
        ),
      ];
    }
    return detailScaffold(c, 'Strength progress', body);
  }
}

class _LiftRow extends StatelessWidget {
  final LiftHistory l;
  final String Function(double) w;
  const _LiftRow(this.l, this.w);

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final best = l.bestE1rm;
    final top = l.last.topKg;
    final ago = DateTime.now().difference(l.last.day).inDays;
    return Surface(
      onTap: () => go(c, LiftDetail(l)),
      semanticLabel: l.label,
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.label,
                style: F.head.copyWith(color: p.ink),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text(
              '${l.sessions.length} sessions · '
              '${ago == 0 ? 'today' : ago == 1 ? 'yesterday' : '$ago days ago'}'
              '${top != null ? ' · top set ${w(top)}' : ''}',
              style: F.cap.copyWith(color: p.ink3),
            ),
          ]),
        ),
        if (best != null)
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(w(best), style: F.n17.copyWith(color: p.ink)),
            Text('est. 1RM', style: F.over.copyWith(color: p.ink3)),
          ]),
        const SizedBox(width: S.x2),
        Icon(LucideIcons.chevronRight, size: 18, color: p.ink3),
      ]),
    );
  }
}

class LiftDetail extends StatelessWidget {
  final LiftHistory lift;
  const LiftDetail(this.lift, {super.key});

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final u = unitsOf(c) ?? UnitsController.seed(UnitSystem.metric);
    final pts = [
      for (final s in lift.sessions)
        if (s.bestE1rm != null) u.weightValue(s.bestE1rm!),
    ];
    final axis = pts.length >= 2 ? AxisSpec.of(pts) : null;
    final df = DateFormat.MMMd();
    return detailScaffold(c, lift.label, [
      Surface(
        child: ChartFrame(
          title: 'Estimated one-rep max',
          unit: u.isImperial ? 'lb' : 'kg',
          height: 140,
          yAxis: axis,
          xLabels: pts.length >= 2
              ? [df.format(lift.sessions.first.day), df.format(lift.last.day)]
              : const [],
          footnote: 'Best set each session, by the Epley formula '
              '(load × (1 + reps ÷ 30)), sets of 1–12 reps. An estimate, not '
              'a tested max.',
          series: pts,
          empty: axis == null
              ? const NoData(message: 'Two weighted sessions draw a trend')
              : null,
          child: axis == null
              ? const SizedBox.shrink()
              : CustomPaint(
                  size: Size.infinite,
                  painter: LineChart(pts, p.on(C.purple),
                      dots: true, axis: axis, t: animate(c, 1)),
                ),
        ),
      ),
      Section(
        'Sessions',
        Column(children: [
          for (final s in lift.sessions.reversed.take(20)) ...[
            Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(DateFormat.yMMMd().format(s.day),
                        style: F.head.copyWith(color: p.ink)),
                    const Spacer(),
                    if (s.pr) Pill('Record', C.yellow, icon: LucideIcons.trophy),
                  ]),
                  const SizedBox(height: S.x2),
                  Wrap(spacing: S.x2, runSpacing: S.x2, children: [
                    for (final set in s.sets)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: S.x3, vertical: S.x1),
                        decoration: BoxDecoration(
                            color: p.card2, borderRadius: R.rPill),
                        child: Text(
                          set.kg != null
                              ? '${u.weight(set.kg)} × ${set.reps ?? '?'}'
                              : '${set.reps ?? '?'} reps',
                          style: F.cap.copyWith(color: p.ink),
                        ),
                      ),
                  ]),
                  const SizedBox(height: S.x2),
                  Text(
                    '${s.sets.length} sets · ${s.reps} reps'
                    '${s.volume > 0 ? ' · ${u.weight(s.volume.round())} lifted' : ''}',
                    style: F.cap.copyWith(color: p.ink3),
                  ),
                ],
              ),
            ),
            const SizedBox(height: S.x3),
          ],
        ]),
      ),
      const SizedBox(height: S.x8),
    ]);
  }
}
