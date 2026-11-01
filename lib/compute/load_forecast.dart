// Fitness / fatigue / form, day by day, and where they go next.
//
// The cross-day rollup publishes only TODAY's CTL/ATL/TSB. This replays the
// exact same Banister EWMA (analytics `ctlAtlTsb`: τ 42 d / 7 d, primed with
// the mean of the first seven observed days, a day with no TRIMP is a rest
// day) over the same dense daily TRIMP series, keeping every step so the
// screen can draw the history, then continues it under a few stated
// scenarios. A projection is arithmetic on an assumption, and every place it
// is drawn says which assumption.
//
// Pure: no I/O, no Flutter. Unit-testable against `ctlAtlTsb`.

import 'dart:math' as math;

/// Same floor as analytics `ctlAtlMinDays`.
const int kLoadMinDays = 14;

class LoadDay {
  final DateTime day;
  final double trimp, ctl, atl;
  final bool projected;
  const LoadDay(this.day, this.trimp, this.ctl, this.atl,
      {this.projected = false});
  double get tsb => ctl - atl;
}

enum LoadScenario { rest, keep, push }

class LoadForecast {
  /// Every calendar day from the first observed one to today, oldest first.
  final List<LoadDay> history;

  /// Seven days after today under each scenario.
  final Map<LoadScenario, List<LoadDay>> next;

  /// Mean daily TRIMP over the last 28 days — the "keep going" assumption.
  final double typicalDay;

  const LoadForecast(this.history, this.next, this.typicalDay);

  LoadDay get today => history.last;
}

/// [byDay] maps local midnight → that day's TRIMP. Days absent from the map
/// inside the span are rest days, exactly as the rollup treats them.
/// Returns null under [kLoadMinDays] calendar days of span.
LoadForecast? buildLoadForecast(Map<DateTime, double> byDay, DateTime today,
    {int horizon = 7}) {
  if (byDay.isEmpty) return null;
  final t0 = DateTime(today.year, today.month, today.day);
  final first = byDay.keys.reduce((a, b) => a.isBefore(b) ? a : b);
  final days = <DateTime>[];
  for (var d = DateTime(first.year, first.month, first.day);
      !d.isAfter(t0);
      d = DateTime(d.year, d.month, d.day + 1)) {
    days.add(d);
  }
  if (days.length < kLoadMinDays) return null;
  final trimp = [for (final d in days) byDay[d] ?? 0.0];

  final lc = 1 - math.exp(-1 / 42);
  final la = 1 - math.exp(-1 / 7);
  final prime = math.min(7, trimp.length);
  final seed = trimp.sublist(0, prime).reduce((a, b) => a + b) / prime;
  var ctl = seed, atl = seed;
  final hist = <LoadDay>[];
  for (var i = 0; i < trimp.length; i++) {
    // The first [prime] days only seed; the EWMA runs over the remainder.
    if (i >= prime) {
      ctl += lc * (trimp[i] - ctl);
      atl += la * (trimp[i] - atl);
    }
    hist.add(LoadDay(days[i], trimp[i], ctl, atl));
  }

  final recent = trimp.sublist(math.max(0, trimp.length - 28));
  final typical = recent.reduce((a, b) => a + b) / recent.length;

  List<LoadDay> run(double perDay) {
    var c = ctl, a = atl;
    return [
      for (var k = 1; k <= horizon; k++)
        () {
          c += lc * (perDay - c);
          a += la * (perDay - a);
          return LoadDay(DateTime(t0.year, t0.month, t0.day + k), perDay, c, a,
              projected: true);
        }(),
    ];
  }

  return LoadForecast(
    hist,
    {
      LoadScenario.rest: run(0),
      LoadScenario.keep: run(typical),
      LoadScenario.push: run(typical * 1.5),
    },
    typical,
  );
}

/// First projected day whose form is back at or above zero, or null.
LoadDay? firstFreshDay(List<LoadDay> path) {
  for (final d in path) {
    if (d.tsb >= 0) return d;
  }
  return null;
}
