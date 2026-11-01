// Today, hero + feed.
//
// One big readiness number in a coloured glow, the one sentence that says
// what it means, then a vertical feed of large cards — Sleep, Strain, Steps,
// Vitals — each a door into its own screen. Replaces the three equal rings:
// the day has one headline, and the rest is supporting detail.
//
// Reads only HomeData. A card whose metric is absent is not drawn; the hero
// with no readiness is the caller's StatusCard, as before.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/decimal_text.dart' show displayFixed;
import '../ui2.dart';
import 'home_screen.dart' show HomeData, hm, readinessBand;

enum HeroDoor { readiness, sleep, strain, steps, vitals }

class HeroScore extends StatelessWidget {
  final HomeData d;
  final void Function(HeroDoor)? onOpen;
  const HeroScore({super.key, required this.d, this.onOpen});

  static bool has(HomeData d) => d.readiness.value != null;

  String _summary(AppLocalizations? l) {
    final parts = <String>[];
    final s = d.sleepMin.value;
    if (s != null) parts.add('slept ${hm(s)}');
    final r = d.rhr.value;
    if (r != null) parts.add('resting HR ${r.round()} bpm');
    if (d.recoveryState == 'provisional') parts.add('still finishing up');
    if (parts.isEmpty) return '';
    final t = parts.join(' · ');
    return t[0].toUpperCase() + t.substring(1);
  }

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final l = AppLocalizations.of(c);
    final v = d.readiness.value!;
    final band = readinessBand(v, l);
    final col = band.color;
    final summary = _summary(l);
    return Pressable(
      onTap: onOpen == null ? null : () => onOpen!(HeroDoor.readiness),
      semanticLabel: 'Readiness ${v.round()}, ${band.label}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: S.x4),
        child: Column(children: [
          SizedBox(
            width: 230,
            height: 230,
            child: Stack(alignment: Alignment.center, children: [
              // The glow: the state colour fading to nothing.
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    col.withValues(alpha: p.dark ? .30 : .20),
                    col.withValues(alpha: 0),
                  ]),
                ),
              ),
              SizedBox(
                width: 190,
                height: 190,
                child: CustomPaint(
                  painter: Ring(v / 100, p.on(col), p.track,
                      stroke: 9, t: animate(c, 1), solid: true),
                ),
              ),
              Column(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(
                  height: 84,
                  child: FittedBox(
                    child: Text('${v.round()}',
                        style: F.n48.copyWith(color: p.ink)),
                  ),
                ),
                const SizedBox(height: S.x1),
                Text('READINESS',
                    style: F.over.copyWith(color: p.ink3, letterSpacing: 1.6)),
              ]),
            ]),
          ),
          const SizedBox(height: S.x3),
          Text(band.label,
              textAlign: TextAlign.center,
              style: F.t2.copyWith(color: p.on(col))),
          if (summary.isNotEmpty) ...[
            const SizedBox(height: S.x1),
            Text(summary,
                textAlign: TextAlign.center,
                style: F.body.copyWith(color: p.ink2)),
          ],
        ]),
      ),
    );
  }
}

class TodayFeed extends StatelessWidget {
  final HomeData d;
  final void Function(HeroDoor)? onOpen;
  const TodayFeed({super.key, required this.d, this.onOpen});

  @override
  Widget build(BuildContext c) {
    final cards = <Widget>[];

    final sleep = d.sleepMin.value;
    if (sleep != null) {
      final need = d.sleepNeedMin.value;
      cards.add(_FeedCard(
        icon: LucideIcons.moon,
        color: C.indigo,
        title: 'Sleep',
        value: hm(sleep),
        sub: need != null ? 'of ${hm(need)} needed' : 'last night',
        frac: need != null && need > 0 ? sleep / need : null,
        onTap: onOpen == null ? null : () => onOpen!(HeroDoor.sleep),
      ));
    }

    final strain = d.strain.value;
    if (strain != null) {
      final aim = d.strainTarget?['value'];
      cards.add(_FeedCard(
        icon: LucideIcons.zap,
        color: C.purple,
        title: 'Strain',
        value: displayFixed(strain, 1),
        sub: aim is num
            ? (strain >= aim
                ? 'Target ${displayFixed(aim, 1)} met'
                : 'Target ${displayFixed(aim, 1)}')
            : 'of 21',
        frac: strain / 21,
        mark: aim is num ? aim / 21 : null,
        onTap: onOpen == null ? null : () => onOpen!(HeroDoor.strain),
      ));
    }

    final steps = d.steps.value;
    if (steps != null) {
      cards.add(_FeedCard(
        icon: LucideIcons.footprints,
        color: C.teal,
        title: 'Steps',
        value: NumberFormat.decimalPattern().format(steps.round()),
        sub: 'of ${NumberFormat.decimalPattern().format(d.stepGoal)} goal',
        frac: d.stepGoal > 0 ? steps / d.stepGoal : null,
        onTap: onOpen == null ? null : () => onOpen!(HeroDoor.steps),
      ));
    }

    cards.add(_FeedCard(
      icon: LucideIcons.heartPulse,
      color: C.red,
      title: 'Overnight vitals',
      value: d.rhr.value != null ? '${d.rhr.value!.round()} bpm' : 'Open',
      sub: d.rhr.value != null
          ? 'resting HR · HRV, breathing, skin temp'
          : 'HRV, breathing, skin temp vs your usual',
      onTap: onOpen == null ? null : () => onOpen!(HeroDoor.vitals),
    ));

    return Column(children: [
      for (var i = 0; i < cards.length; i++) ...[
        if (i > 0) const SizedBox(height: S.x3),
        cards[i],
      ],
    ]);
  }
}

class _FeedCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, value, sub;
  final double? frac, mark;
  final VoidCallback? onTap;
  const _FeedCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.sub,
    this.frac,
    this.mark,
    this.onTap,
  });

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final ink = p.on(color);
    return Surface(
      pad: const EdgeInsets.all(S.x5),
      onTap: onTap,
      semanticLabel: '$title, $value, $sub',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: p.wash(color), borderRadius: R.rMd),
            child: Icon(icon, size: 18, color: ink),
          ),
          const SizedBox(width: S.x3),
          Expanded(
              child: Text(title, style: F.head.copyWith(color: p.ink))),
          Icon(LucideIcons.chevronRight, size: 18, color: p.ink3),
        ]),
        const SizedBox(height: S.x4),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: S.x2,
          children: [
            Text(value, style: F.n34.copyWith(color: p.ink)),
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(sub, style: F.cap.copyWith(color: p.ink2)),
            ),
          ],
        ),
        if (frac != null) ...[
          const SizedBox(height: S.x3),
          SizedBox(
            height: 10,
            width: double.infinity,
            child: CustomPaint(
              painter: _Bar(frac!.clamp(0.0, 1.0).toDouble(), mark,
                  fill: ink, track: p.track, markInk: p.ink),
            ),
          ),
        ],
      ]),
    );
  }
}

class _Bar extends CustomPainter {
  final double t;
  final double? mark;
  final Color fill, track, markInk;
  const _Bar(this.t, this.mark,
      {required this.fill, required this.track, required this.markInk});

  @override
  void paint(Canvas canvas, Size s) {
    final r = Radius.circular(s.height / 2);
    canvas.drawRRect(RRect.fromLTRBR(0, 0, s.width, s.height, r),
        Paint()..color = track);
    if (t > 0) {
      canvas.drawRRect(
          RRect.fromLTRBR(0, 0, (s.width * t).clamp(s.height, s.width), s.height, r),
          Paint()..color = fill);
    }
    final m = mark;
    if (m != null && m > 0 && m < 1) {
      final x = s.width * m;
      canvas.drawLine(Offset(x, -3), Offset(x, s.height + 3),
          Paint()
            ..color = markInk
            ..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(_Bar o) => o.t != t || o.mark != mark || o.fill != fill;
}
