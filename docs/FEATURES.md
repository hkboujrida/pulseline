# Features

Everything below is computed and stored on your phone.

## Pulseline additions

- **Right now (on demand):** live heart rate, heart-rate zone, movement, today's
  strain (refreshed every 10 minutes), a one-minute HRV spot check, and band status.
  Off by default; stops after 15 minutes or when you leave Today.
- **Readiness against your usual:** last night's readiness on a scale centred on your
  own typical night, with your usual range marked.
- **Overnight vitals:** resting HR, HRV, breathing rate and relative skin temperature
  against your usual range (14 nights of history), outliers flagged.
- **Training-load forecast:** fitness, fatigue and form for the next 7 days under
  rest / keep going / push, replaying the same Banister model the app already uses.
- **Strength progress:** personal records, estimated 1RM (Epley, sets of 1–12 reps)
  and weekly volume, from sets logged in strength workouts.
- **Monthly report:** this month's averages against last month, with standout days.
- **30-day trends:** HRV, resting HR, sleep and recovery against the previous 30 days.

## Devices

- **WHOOP 4.0, 5.0 and MG:** full support. Every metric below is computed from these.
- **Any standard Bluetooth heart-rate strap:** pairs for workout tracking (heart rate
  and beat timing, stored and shown). Feeding it into recovery and strain is planned.
- **Oura Ring:** experimental. Pairs and syncs the ring's history to the phone; that
  history is stored but doesn't feed any score yet.
- **Being built:** Garmin, Pebble, Colmi, Ultrahuman, Mi Band and more. The pairing
  screen marks these **Experimental**. They can pair and store what they send, but none
  of it becomes a number in the app until the decoding is confirmed on a real device.

## Health

Heart rate, HRV, sleep staging, recovery/readiness, strain, stress, an HRV spot-check,
and real-time breathing coherence.

Strain is scored against your own quiet waking heart rate, not a population constant,
so a workout counts the same for a fit person with a low resting HR as for anyone else.
It needs three days of your data before it shows a number. Nightly HRV is RMSSD from one
estimator, and a night where the beat detector over-counts is refused rather than scored.

## Activity

Auto-detected workouts, live workout tracking with GPS routes, heart-rate zones you can
edit, and GPX export.

## Your data, elsewhere

- Writes to **Apple Health** (HealthKit) and **Google Health Connect**: sleep stages,
  resting HR, HRV, respiratory rate, active energy and workouts. Only things the device
  measures, never derived scores, which have no native type. Exports are idempotent, so
  re-deriving a day never duplicates samples.
- Export the entire local SQLite database to a file whenever you like.
- Scheduled local backups, which run when you open the app and one is due. On Android
  you can point them at a folder of your choice.

## Everything else

- Trends and history
- A journal with on-device correlation insights ("what actually moves your numbers")
- Lab-result CSV import
- Cycle tracking
- A deterministic coach and a bring-your-own-key AI assistant (see
  [guides/AI_COACH.md](../guides/AI_COACH.md))
- A shareable weekly recap
- Home-screen widgets, iOS Live Activities, and Siri shortcuts, including
  [Sync Data](../guides/IOS_SHORTCUTS.md) for on-demand or scheduled sync
- A smart alarm that buzzes the device on a weekly repeating schedule, with a wake
  window that catches you in light sleep
- Languages: English, German, Spanish, French, Hindi, Russian and Chinese

## Known limits

- iOS background sync is best-effort. Apple doesn't give third-party apps a real
  background service, so the OS decides when sync tasks run. Android has no such limit.
- Metrics are approximations based on published research. They are not medical-grade,
  not validated against a lab, and not a diagnosis.
- Not on the App Store or Play Store. Pulseline is Android only, as an APK from
  GitHub Releases.
- WHOOP 5.0 and MG support is newer than 4.0's and has had less daily wear. Open an
  issue when something looks wrong.
- Don't switch back and forth between this app and the device maker's app. A firmware
  update pushed from there could change the records this app depends on.
