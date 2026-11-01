// The Vitals tab's lead: how last night compares with YOUR usual.
//
// Two cards, both built only from numbers the pipeline already stored:
//
//   · "Compared with your usual" — readiness as a position around your own
//     normal (Polar's Nightly Recharge idea), not a grade. The centre of the
//     scale is the median of your own stored `readiness_z`, the band is the
//     same median ± 1.253 × MAD every other trend in the app draws. Under
//     [kUsualMinDays] nights there is no band and the card says so.
//
//   · "Overnight vitals" — resting HR, HRV, breathing rate and relative skin
//     temperature, each drawn against the pipeline's own baseline band
//     (`baselines` in the day bundle), with values outside it flagged
//     (Apple's Vitals idea). Skin temperature has no absolute unit on this
//     band, so it is drawn as a deviation only.
//
// Nothing here is computed from anything the pipeline did not publish, and a
// missing value is a StatusCard line, never a dash.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/day_label.dart';
import '../../data/local_repository.dart';
import '../ui2.dart';
import 'home_screen.dart' show go, pointsOf, repoOf;
import 'metric_detail.dart';
import 'readiness_detail.dart';

/// One vital's reading for one night.
@immutable
class VitalReading {
  final String key; // MetricDetail key
  final String name;
  final IconData icon;
  final Color color;
  final double? value;
  final String unit;
  final int decimals;

  /// The pipeline's own band, or null while it is still learning.
  final UsualRange? range;

  /// Baseline-relative z from the pipeline. For skin temperature this is the
  /// only reading there is.
  final double? z;
  final int nights;

  /// True when only the deviation can honestly be shown (no absolute unit).
  final bool relativeOnly;

  const VitalReading({
    required this.key,
    required this.name,
    required this.icon,
    required this.color,
    required this.value,
    required this.unit,
    this.decimals = 0,
    this.range,
    this.z,
    this.nights = 0,
    this.relativeOnly = false,
  });

  bool get hasValue => relativeOnly ? z != null : value != null;

  /// Outside the usual band. Null when there is no band to be outside of.
  bool? get outlier {
    if (relativeOnly) return z == null || nights < kUsualMinDays ? null : z!.abs() > 1;
    final r = range, v = value;
    if (r == null || v == null) return null;
    return r.side(v) != Side.inside;
  }
}

@immutable
class OvernightData {
  final String? day;
  final List<VitalReading> vitals;

  /// Today's composite readiness z and the band of your own past composites.
  final double? readinessZ;
  final UsualRange? readinessUsual;
  final int readinessNights;

  /// The last 30 nights of the composite, oldest first, null for a gap.
  final List<double?> readinessSeries;

  const OvernightData({
    this.day,
    this.vitals = const [],
    this.readinessZ,
    this.readinessUsual,
    this.readinessNights = 0,
    this.readinessSeries = const [],
  });

  static double? _num(Object? v) => v is num && v.isFinite ? v.toDouble() : null;

  static Future<OvernightData> load(LocalRepository repo, String? want) async {
    final day = want ?? todayLabel();
    final heart = await repo.getDayHeart(day);
    final base = heart['baselines'] is Map ? heart['baselines'] as Map : const {};

    VitalReading vital(String key, String name, IconData icon, Color color,
        Object? value, String baseKey, String unit,
        {int decimals = 0, bool relativeOnly = false}) {
      final b = base[baseKey];
      return VitalReading(
        key: key,
        name: name,
        icon: icon,
        color: color,
        value: _num(value),
        unit: unit,
        decimals: decimals,
        range: relativeOnly ? null : UsualRange.fromBaseline(b),
        z: b is Map ? _num(b['z']) : null,
        nights: b is Map ? ((b['n_valid'] as num?)?.toInt() ?? 0) : 0,
        relativeOnly: relativeOnly,
      );
    }

    final hrv = heart['hrv'] is Map ? heart['hrv'] as Map : const {};
    final resp = heart['resp'] is Map ? heart['resp'] as Map : const {};
    final skin = heart['skin_temp'] is Map ? heart['skin_temp'] as Map : const {};

    final vitals = [
      vital('resting_hr', 'Resting heart rate', LucideIcons.heart, C.red,
          heart['resting_hr'], 'resting_hr', 'bpm'),
      vital('hrv', 'Heart rate variability', LucideIcons.activity, C.green,
          hrv['rmssd'], 'hrv', 'ms'),
      vital('resp_rate', 'Breathing rate', LucideIcons.wind, C.teal,
          resp['value'], 'resp', 'br/min', decimals: 1),
      vital('skin_temp', 'Skin temperature', LucideIcons.thermometer,
          C.orange, skin['value'], 'skin_temp', '',
          relativeOnly: true),
    ];

    // The composite, by day. getChart returns every stored day; take this
    // night's value and the ones strictly before it.
    final pts = pointsOf(await repo.getChart('readiness_z'));
    double? today;
    final prior = <double>[];
    final byDay = <String, double>{};
    for (final p in pts) {
      final label =
          dayLabelOf(DateTime.fromMillisecondsSinceEpoch(p.t * 1000));
      byDay[label] = p.v;
      final cmp = label.compareTo(day);
      if (cmp == 0) today = p.v;
      if (cmp < 0) prior.add(p.v);
    }
    // priorTo() judges the newest against what came before it, so hand it the
    // prior nights followed by tonight (or a placeholder that is excluded).
    final usual = UsualRange.priorTo([...prior, today ?? double.nan]);
    final series = <double?>[
      for (var i = 29; i >= 0; i--) byDay[dayLabelBefore(day, i) ?? ''],
    ];

    return OvernightData(
      day: day,
      vitals: vitals,
      readinessZ: today,
      readinessUsual: usual,
      readinessNights: prior.length,
      readinessSeries: series,
    );
  }
}

/// The Vitals tab lead for one night. Re-reads when [day] changes.
class OvernightLead extends StatefulWidget {
  final String? day;
  const OvernightLead({super.key, this.day});

  @override
  State<OvernightLead> createState() => _OvernightLeadState();
}

class _OvernightLeadState extends State<OvernightLead> with RevisionReload {
  OvernightData? _d;
  bool _failed = false;

  @override
  bool get revisionReloads => true;

  @override
  void reload() => _load();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(OvernightLead old) {
    super.didUpdateWidget(old);
    if (old.day != widget.day) _load();
  }

  Future<void> _load() async {
    final repo = repoOf(context);
    if (repo == null) return;
    final t = beginRead(#overnight);
    try {
      final d = await OvernightData.load(repo, widget.day);
      if (stillNewest(#overnight, t)) {
        setState(() => (_d = d, _failed = false));
      }
    } catch (_) {
      if (stillNewest(#overnight, t)) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext c) {
    final d = _d;
    if (_failed) {
      return Padding(
        padding: const EdgeInsets.only(bottom: S.x4),
        child: StatusCard(
          'Could not read last night’s vitals',
          'The stored rows failed to load. Nothing was deleted.',
          fix: 'Try again',
          icon: LucideIcons.databaseZap,
          onFix: _load,
        ),
      );
    }
    if (d == null) return const SizedBox(height: S.x2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BaselineReadinessCard(data: d),
        const SizedBox(height: S.x3),
        OvernightVitalsCard(data: d),
        const SizedBox(height: S.x2),
      ],
    );
  }
}

// ─────────────────────── compared with your usual ───────────────────────

String _zWords(double rel) {
  final a = rel.abs();
  if (a < .5) return 'Right at your usual';
  final dir = rel > 0 ? 'above' : 'below';
  if (a < 1) return 'Slightly $dir your usual';
  if (a < 2) return 'Clearly $dir your usual';
  return 'Far $dir your usual';
}

class BaselineReadinessCard extends StatelessWidget {
  final OvernightData data;
  const BaselineReadinessCard({super.key, required this.data});

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final z = data.readinessZ;
    final usual = data.readinessUsual;

    final Widget body;
    if (z == null) {
      body = Text(
        'No readiness for this night yet. It needs a night of sleep with '
        'clean heart-rate data, plus a few nights of history.',
        style: F.body.copyWith(color: p.ink2),
      );
    } else if (usual == null) {
      final need = math.max(0, kUsualMinDays - data.readinessNights);
      body = Text(
        'Learning your usual. $need more '
        '${need == 1 ? 'night' : 'nights'} and this shows where each night '
        'sits against it.',
        style: F.body.copyWith(color: p.ink2),
      );
    } else {
      // Half a band = one "usual step". The scale shows ±3 of them.
      final half = (usual.hi - usual.lo) / 2;
      final rel = half > 0 ? (z - usual.usual) / half : 0.0;
      final good = rel >= 0;
      final accent = rel.abs() < .5 ? C.blue : (good ? C.green : C.orange);
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: S.x3,
            runSpacing: S.x1,
            children: [
              Text(
                '${rel >= 0 ? '+' : '−'}${rel.abs().toStringAsFixed(1)}',
                style: F.n48.copyWith(color: p.on(accent)),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: S.x1),
                child: Text(_zWords(rel),
                    style: F.head.copyWith(color: p.ink)),
              ),
            ],
          ),
          const SizedBox(height: S.x4),
          _CentredScale(value: rel, color: p.on(accent)),
          const SizedBox(height: S.x2),
          Row(
            children: [
              Expanded(
                  child: Text('Below', style: F.over.copyWith(color: p.ink3))),
              Expanded(
                  child: Text('Usual',
                      textAlign: TextAlign.center,
                      style: F.over.copyWith(color: p.ink3))),
              Expanded(
                  child: Text('Above',
                      textAlign: TextAlign.right,
                      style: F.over.copyWith(color: p.ink3))),
            ],
          ),
          const SizedBox(height: S.x3),
          Text(
            '0 is your own typical night over the last '
            '${math.min(data.readinessNights, 60)} nights; ±1 is the edge of '
            'your usual range.',
            style: F.cap.copyWith(color: p.ink3),
          ),
        ],
      );
    }

    return Surface(
      pad: const EdgeInsets.all(S.x5),
      onTap: () => go(c, ReadinessDetail(day: data.day)),
      semanticLabel: 'Readiness compared with your usual',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(LucideIcons.gauge, size: 18, color: p.on(C.green)),
            const SizedBox(width: S.x2),
            Expanded(
              child: Text('Compared with your usual',
                  style: F.over.copyWith(color: p.ink2)),
            ),
            Icon(LucideIcons.chevronRight, size: 18, color: p.ink3),
          ]),
          const SizedBox(height: S.x3),
          body,
        ],
      ),
    );
  }
}

/// A −3…+3 track with the usual band (−1…+1) shaded and a dot at [value].
class _CentredScale extends StatelessWidget {
  final double value;
  final Color color;
  const _CentredScale({required this.value, required this.color});

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    return SizedBox(
      height: 18,
      width: double.infinity,
      child: CustomPaint(
        painter: _ScalePainter(
          t: ((value.clamp(-3.0, 3.0) + 3) / 6).toDouble(),
          bandLo: 2 / 6,
          bandHi: 4 / 6,
          track: p.track,
          band: p.wash(C.blue, strength: 1),
          tick: p.ink3,
          dot: color,
          ring: p.card,
        ),
      ),
    );
  }
}

class _ScalePainter extends CustomPainter {
  final double t, bandLo, bandHi;
  final Color track, band, tick, dot, ring;
  const _ScalePainter({
    required this.t,
    required this.bandLo,
    required this.bandHi,
    required this.track,
    required this.band,
    required this.tick,
    required this.dot,
    required this.ring,
  });

  @override
  void paint(Canvas canvas, Size s) {
    final cy = s.height / 2;
    final r = RRect.fromLTRBR(0, cy - 3, s.width, cy + 3, const Radius.circular(3));
    canvas.drawRRect(r, Paint()..color = track);
    canvas.drawRRect(
        RRect.fromLTRBR(s.width * bandLo, cy - 5, s.width * bandHi, cy + 5,
            const Radius.circular(5)),
        Paint()..color = band);
    canvas.drawLine(Offset(s.width / 2, cy - 7), Offset(s.width / 2, cy + 7),
        Paint()
          ..color = tick
          ..strokeWidth = 1.5);
    final x = (s.width * t).clamp(8.0, s.width - 8.0);
    canvas.drawCircle(Offset(x, cy), 8, Paint()..color = ring);
    canvas.drawCircle(Offset(x, cy), 6, Paint()..color = dot);
  }

  @override
  bool shouldRepaint(_ScalePainter o) =>
      o.t != t || o.dot != dot || o.track != track || o.band != band;
}

// ─────────────────────────── overnight vitals ───────────────────────────

class OvernightVitalsCard extends StatelessWidget {
  final OvernightData data;
  const OvernightVitalsCard({super.key, required this.data});

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final measured = data.vitals.where((v) => v.hasValue).toList();
    final judged = measured.where((v) => v.outlier != null).toList();
    final outliers = judged.where((v) => v.outlier == true).toList();

    final String headline;
    final Color tone;
    if (measured.isEmpty) {
      headline = 'No vitals for this night';
      tone = C.blue;
    } else if (judged.isEmpty) {
      headline = 'Still learning your ranges';
      tone = C.blue;
    } else if (outliers.isEmpty) {
      headline = judged.length == measured.length
          ? 'All vitals in your usual range'
          : '${judged.length} of ${measured.length} in your usual range';
      tone = C.green;
    } else {
      headline = outliers.length == 1
          ? '1 vital outside your usual range'
          : '${outliers.length} vitals outside your usual range';
      tone = C.orange;
    }

    return Surface(
      pad: const EdgeInsets.all(S.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(LucideIcons.heartPulse, size: 18, color: p.on(C.red)),
            const SizedBox(width: S.x2),
            Text('Overnight vitals', style: F.over.copyWith(color: p.ink2)),
          ]),
          const SizedBox(height: S.x2),
          Text(headline, style: F.t2.copyWith(color: p.on(tone))),
          const SizedBox(height: S.x4),
          for (final v in data.vitals) ...[
            _VitalRow(v),
            if (v != data.vitals.last)
              Divider(height: S.x6, thickness: .5, color: p.line),
          ],
        ],
      ),
    );
  }
}

class _VitalRow extends StatelessWidget {
  final VitalReading v;
  const _VitalRow(this.v);

  String _fmt(double x) => x.toStringAsFixed(v.decimals);

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);

    final String value;
    final String status;
    Color statusColor = C.blue;
    double? t; // 0…1 on the row's scale
    double bandLo = 1 / 3, bandHi = 2 / 3;

    if (!v.hasValue) {
      value = 'Not measured';
      status = '';
    } else if (v.relativeOnly) {
      final z = v.z!;
      value = z.abs() < .05
          ? 'At usual'
          : '${z > 0 ? '+' : '−'}${z.abs().toStringAsFixed(1)} vs usual';
      if (v.nights < kUsualMinDays) {
        status = 'Learning · ${v.nights} of $kUsualMinDays nights';
      } else {
        t = ((z.clamp(-3.0, 3.0) + 3) / 6).toDouble();
        final out = z.abs() > 1;
        status = out ? (z > 0 ? 'Above usual' : 'Below usual') : 'Typical';
        statusColor = out ? C.orange : C.green;
      }
    } else {
      final x = v.value!;
      value = '${_fmt(x)} ${v.unit}';
      final r = v.range;
      if (r == null) {
        status = 'Learning · ${math.min(v.nights, kUsualMinDays)} of '
            '$kUsualMinDays nights';
      } else {
        // The band takes the middle third; the row spans one band-width
        // either side of it.
        final w = r.hi - r.lo;
        final lo = r.lo - w, hi = r.hi + w;
        t = ((x - lo) / (hi - lo)).clamp(0.0, 1.0).toDouble();
        final side = r.side(x);
        status = switch (side) {
          Side.inside => 'Typical · ${_fmt(r.lo)}–${_fmt(r.hi)}',
          Side.above => 'Above usual · ${_fmt(r.lo)}–${_fmt(r.hi)}',
          Side.below => 'Below usual · ${_fmt(r.lo)}–${_fmt(r.hi)}',
        };
        statusColor = side == Side.inside ? C.green : C.orange;
      }
    }

    return Pressable(
      onTap: () => go(c, MetricDetail(v.key)),
      semanticLabel: '${v.name}, $value. $status',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 32,
              height: 32,
              decoration:
                  BoxDecoration(color: p.wash(v.color), borderRadius: R.rMd),
              child: Icon(v.icon, size: 16, color: p.on(v.color)),
            ),
            const SizedBox(width: S.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(v.name, style: F.cap.copyWith(color: p.ink2)),
                  Text(value,
                      style: F.n17.copyWith(
                          color: v.hasValue ? p.ink : p.ink3)),
                ],
              ),
            ),
            if (status.isNotEmpty)
              Flexible(
                child: Text(
                  status,
                  textAlign: TextAlign.right,
                  style: F.cap.copyWith(
                      color: t == null ? p.ink3 : p.on(statusColor),
                      fontWeight: FontWeight.w600),
                ),
              ),
          ]),
          if (t != null) ...[
            const SizedBox(height: S.x3),
            SizedBox(
              height: 14,
              width: double.infinity,
              child: CustomPaint(
                painter: _ScalePainter(
                  t: t,
                  bandLo: bandLo,
                  bandHi: bandHi,
                  track: p.track,
                  band: p.wash(C.green),
                  tick: p.track,
                  dot: p.on(statusColor),
                  ring: p.card,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
