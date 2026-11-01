// Training load: the last four weeks and the next one.
//
// Form (fitness − fatigue) over 28 days, then seven projected days under the
// scenario the user picks — rest, keep going at your usual daily load, or
// push 50% harder — drawn dashed and labelled as a projection. Gentler
// Streak's "activity path" idea, on the Banister numbers this app already
// computes. See lib/compute/load_forecast.dart for the arithmetic.

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';

import '../../compute/load_forecast.dart';
import '../ui2.dart';
import 'home_screen.dart' show pointsOf, repoOf;

class LoadForecastCard extends StatefulWidget {
  /// Injected in the gallery; read from the repo otherwise.
  final LoadForecast? data;
  const LoadForecastCard({super.key, this.data});

  @override
  State<LoadForecastCard> createState() => _LoadForecastCardState();
}

class _LoadForecastCardState extends State<LoadForecastCard>
    with RevisionReload {
  LoadForecast? _f;
  bool _loaded = false;
  LoadScenario _s = LoadScenario.keep;

  @override
  bool get revisionReloads => widget.data == null;

  @override
  void reload() => _load();

  @override
  void initState() {
    super.initState();
    if (widget.data != null) {
      _f = widget.data;
      _loaded = true;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _load() async {
    final repo = repoOf(context);
    if (repo == null) return;
    final t = beginRead(#load);
    try {
      final pts = pointsOf(await repo.getChart('trimp'));
      final byDay = <DateTime, double>{};
      for (final p in pts) {
        final d = DateTime.fromMillisecondsSinceEpoch(p.t * 1000);
        byDay[DateTime(d.year, d.month, d.day)] = p.v;
      }
      final f = buildLoadForecast(byDay, DateTime.now());
      if (stillNewest(#load, t)) setState(() => (_f = f, _loaded = true));
    } catch (_) {
      if (stillNewest(#load, t)) setState(() => _loaded = true);
    }
  }

  String _scenarioName(LoadScenario s) => switch (s) {
        LoadScenario.rest => 'Rest',
        LoadScenario.keep => 'Keep going',
        LoadScenario.push => 'Push',
      };

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    if (!_loaded) return const SizedBox.shrink();
    final f = _f;
    if (f == null) {
      return const StatusCard(
        'No forecast yet',
        'The forecast replays your fitness and fatigue day by day. It needs '
            'two weeks of history.',
        icon: LucideIcons.trendingUp,
      );
    }

    final past = f.history.length > 28
        ? f.history.sublist(f.history.length - 28)
        : f.history;
    final path = f.next[_s]!;
    final all = [...past, ...path];
    final tsb = [for (final d in all) d.tsb];
    final axis = AxisSpec.of([...tsb, 0], ticks: 3);
    final fresh = firstFreshDay(path);
    final end = path.last;
    final dayFmt = DateFormat.E();

    final String story;
    if (f.today.tsb >= 0) {
      story = switch (_s) {
        LoadScenario.rest =>
          'You’re fresh now. Resting keeps you fresh, but fitness slowly drops.',
        LoadScenario.keep =>
          'At your usual ${f.typicalDay.round()} points a day, form ends the '
              'week at ${end.tsb.round()}.',
        LoadScenario.push => end.tsb < 0
            ? 'Pushing 50% harder would turn form negative — '
                'fatigue builds faster than fitness.'
            : 'You have room to push: form stays positive all week.',
      };
    } else {
      story = fresh == null
          ? '${_scenarioName(_s)} for a week and form stays below zero — '
              'fatigue is still ahead of fitness.'
          : '${_scenarioName(_s)}: form is back above zero by '
              '${dayFmt.format(fresh.day)}.';
    }

    return Surface(
      pad: const EdgeInsets.all(S.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(LucideIcons.route, size: 18, color: p.on(C.purple)),
            const SizedBox(width: S.x2),
            Text('Next 7 days', style: F.over.copyWith(color: p.ink2)),
          ]),
          const SizedBox(height: S.x3),
          SubTabs([for (final s in LoadScenario.values) _scenarioName(s)],
              _s.index, (i) => setState(() => _s = LoadScenario.values[i]),
              color: C.purple),
          const SizedBox(height: S.x4),
          Text(story, style: F.body.copyWith(color: p.ink)),
          const SizedBox(height: S.x4),
          ChartFrame(
            title: 'Form',
            unit: 'fitness − fatigue',
            height: 120,
            yAxis: axis,
            // Two labels at the true ends. Today is the dot where the solid
            // line turns dashed — a middle label would sit at the midpoint,
            // which is not today.
            xLabels: [
              DateFormat.MMMd().format(past.first.day),
              DateFormat.MMMd().format(end.day),
            ],
            legend: [
              ('Measured to today', p.on(C.purple)),
              ('Projected', p.on(C.purple).withValues(alpha: .55)),
            ],
            footnote: 'Projection assumes '
                '${switch (_s) {
              LoadScenario.rest => 'no training',
              LoadScenario.keep => '${f.typicalDay.round()} heart points a day, your 4-week average',
              LoadScenario.push => '${(f.typicalDay * 1.5).round()} heart points a day, 50% above your average',
            }}. Above zero: fresher than your recent training; below: carrying fatigue.',
            series: tsb,
            empty: axis == null ? const NoData() : null,
            child: axis == null
                ? const SizedBox.shrink()
                : CustomPaint(
                    size: Size.infinite,
                    painter: _FormPainter(
                      tsb,
                      measured: past.length,
                      axis: axis,
                      color: p.on(C.purple),
                      zero: p.ink3,
                      good: p.wash(C.green, strength: .5),
                    ),
                  ),
          ),
          const SizedBox(height: S.x4),
          Row(children: [
            _stat(p, 'Fitness', f.today.ctl, end.ctl),
            _stat(p, 'Fatigue', f.today.atl, end.atl),
            _stat(p, 'Form', f.today.tsb, end.tsb),
          ]),
        ],
      ),
    );
  }

  Widget _stat(P p, String label, double now, double then) {
    final up = then - now;
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: F.over.copyWith(color: p.ink3)),
        const SizedBox(height: S.x1),
        Text(now.round().toString(), style: F.n24.copyWith(color: p.ink)),
        Text(
          '${up >= 0 ? '↑' : '↓'} ${then.round()} in 7 d',
          style: F.cap.copyWith(color: p.ink2),
        ),
      ]),
    );
  }
}

class _FormPainter extends CustomPainter {
  final List<double> d;
  final int measured;
  final AxisSpec axis;
  final Color color, zero, good;
  const _FormPainter(this.d,
      {required this.measured,
      required this.axis,
      required this.color,
      required this.zero,
      required this.good});

  @override
  void paint(Canvas canvas, Size s) {
    if (d.length < 2) return;
    double x(int i) => s.width * i / (d.length - 1);
    double y(double v) => s.height * (1 - axis.t(v));

    // Above zero is shaded: "fresh" territory.
    final y0 = y(0);
    canvas.drawRect(Rect.fromLTRB(0, 0, s.width, y0.clamp(0, s.height)),
        Paint()..color = good);
    canvas.drawLine(Offset(0, y0), Offset(s.width, y0),
        Paint()
          ..color = zero
          ..strokeWidth = 1);

    final solid = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()..moveTo(x(0), y(d[0]));
    for (var i = 1; i < measured; i++) {
      path.lineTo(x(i), y(d[i]));
    }
    canvas.drawPath(path, solid);

    // Projection: dashed, lighter.
    final dash = Paint()
      ..color = color.withValues(alpha: .55)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (var i = measured - 1; i < d.length - 1; i++) {
      final a = Offset(x(i), y(d[i])), b = Offset(x(i + 1), y(d[i + 1]));
      for (var t = 0.0; t < 1; t += .34) {
        canvas.drawLine(
            Offset.lerp(a, b, t)!, Offset.lerp(a, b, (t + .18).clamp(0, 1))!, dash);
      }
    }
    // Today marker.
    final ti = measured - 1;
    canvas.drawCircle(Offset(x(ti), y(d[ti])), 4.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_FormPainter o) =>
      o.d != d || o.measured != measured || o.color != color;
}
