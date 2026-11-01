// "More for you" on Today: doors into the parts of the app that used to be
// two or three screens deep — the journal, breathing, the monthly report,
// strength records and the body clock. Doors only: no numbers, no previews.

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../ui2.dart';
import 'circadian_detail.dart';
import 'home_screen.dart' show go;
import 'journal_compose.dart';
import 'monthly_report.dart';
import 'strength_progress.dart';
import 'wellness_screen.dart';

class ExploreGrid extends StatelessWidget {
  const ExploreGrid({super.key});

  @override
  Widget build(BuildContext c) {
    final doors = <(IconData, Color, String, String, Widget Function())>[
      (LucideIcons.notebookPen, C.teal, 'Journal', 'Log today: caffeine, alcohol, mood',
          () => const JournalCompose()),
      (LucideIcons.wind, C.blue, 'Mind', 'Breathing, mood and journal history',
          () => const WellnessScreen(initialTab: 0)),
      (LucideIcons.calendarRange, C.indigo, 'Monthly report', 'This month vs last',
          () => const MonthlyReportScreen()),
      (LucideIcons.trophy, C.yellow, 'Strength', 'Records and 1RM',
          () => const StrengthProgressScreen()),
      (LucideIcons.sunMoon, C.orange, 'Body clock', 'Chronotype and regularity',
          () => const CircadianDetail()),
      (LucideIcons.bedDouble, C.pink, 'Sleep plan', 'Need, debt and bedtime',
          () => const WellnessScreen(initialTab: 1)),
    ];
    return LayoutBuilder(builder: (c, box) {
      final w = (box.maxWidth - S.x3) / 2;
      return Wrap(
        spacing: S.x3,
        runSpacing: S.x3,
        children: [
          for (final (icon, color, title, sub, open) in doors)
            SizedBox(width: w, child: _Door(icon, color, title, sub, open)),
        ],
      );
    });
  }
}

class _Door extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, sub;
  final Widget Function() open;
  const _Door(this.icon, this.color, this.title, this.sub, this.open);

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    return Surface(
      onTap: () => go(c, open()),
      semanticLabel: title,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: p.wash(color), borderRadius: R.rMd),
          child: Icon(icon, size: 18, color: p.on(color)),
        ),
        const SizedBox(height: S.x3),
        Text(title, style: F.head.copyWith(color: p.ink)),
        const SizedBox(height: S.x1),
        Text(sub,
            style: F.cap.copyWith(color: p.ink3),
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}
