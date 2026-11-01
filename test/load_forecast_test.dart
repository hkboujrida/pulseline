import 'package:flutter_test/flutter_test.dart';
import 'package:openstrap_analytics/onehz.dart' as ana;
import 'package:openstrap_edge/compute/load_forecast.dart';
import 'package:openstrap_edge/ui2/screens/strength_progress.dart';

void main() {
  test('replayed EWMA ends where analytics ctlAtlTsb ends', () {
    final byDay = <DateTime, double>{};
    final dense = <double>[];
    for (var i = 0; i < 60; i++) {
      final v = i % 4 == 3 ? 0.0 : 50.0 + (i * 7) % 40;
      // Leave rest days out of the map: they must count as zero.
      if (v > 0) byDay[DateTime(2026, 9, 1 + i)] = v;
      dense.add(v);
    }
    final f = buildLoadForecast(byDay, DateTime(2026, 9, 60))!;
    final ref = ana.ctlAtlTsb(dense).value!;
    expect(f.history.length, 60);
    expect(f.today.ctl, closeTo(ref.ctl, 1e-9));
    expect(f.today.atl, closeTo(ref.atl, 1e-9));
    // Resting lowers fatigue faster than fitness, so form rises.
    expect(f.next[LoadScenario.rest]!.last.tsb, greaterThan(f.today.tsb));
  });

  test('abstains under two weeks', () {
    expect(buildLoadForecast({DateTime(2026, 10, 1): 80}, DateTime(2026, 10, 5)),
        isNull);
  });

  test('strength records and Epley', () {
    expect(estimatedOneRepMax(100, 1), 100);
    expect(estimatedOneRepMax(100, 10), closeTo(133.33, .01));
    expect(estimatedOneRepMax(100, 15), isNull);
    expect(estimatedOneRepMax(null, 5), isNull);
    int ts(int d) => DateTime(2026, 10, d, 18).millisecondsSinceEpoch ~/ 1000;
    final rows = [
      {'session_id': 'a', 'exercise_key': 'bench', 'reps': 5, 'load_kg': 80, 'at_ts': ts(1)},
      {'session_id': 'b', 'exercise_key': 'bench', 'reps': 5, 'load_kg': 85, 'at_ts': ts(8)},
      {'session_id': 'c', 'exercise_key': 'bench', 'reps': 5, 'load_kg': 82, 'at_ts': ts(15)},
    ];
    final d = StrengthData.fromRows(rows, DateTime(2026, 10, 16));
    final s = d.lifts.single.sessions;
    expect([for (final x in s) x.pr], [false, true, false]);
    expect(d.weeklyVolume.last, 82 * 5);
  });
}
