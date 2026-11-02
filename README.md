# Pulseline

A health app for your WHOOP band: recovery, strain, sleep and overnight vitals, computed on
your phone. No subscription, no account, nothing uploaded.

**Pulseline is based on [OpenStrap](https://github.com/OpenStrap)** (the Edge app, its
protocol decoder and analytics). It is an independent fork with a redesigned interface and
extra features. It is not made, endorsed or supported by the OpenStrap project; please
don't take Pulseline issues to OpenStrap's channels. Report them here instead.

## Download

Android: grab the APK from [Releases](../../releases/latest).

## What's in it

**Four tabs, each with its own headline:**

- **Today:** your readiness score in a large ring, then cards for Sleep (against the
  sleep you need), Strain (with your target), Steps and Overnight vitals. Below them,
  "More for you" shortcuts to the journal, mind, monthly report, strength, body clock
  and sleep plan.
- **Right now (on Today, on demand):** tap *Go live* for live heart rate, your current
  heart-rate zone, whether you're still or moving, today's strain (refreshed every
  10 minutes), a one-minute "HRV right now" measurement, and band connection, wear and
  battery. It stops by itself after 15 minutes, when you switch tabs or when you leave
  the app, to save battery.
- **Vitals:** last night in a ring against your sleep need, with bed and wake times and
  time in each stage; readiness against *your own* usual level; resting HR, HRV,
  breathing rate and skin temperature against your usual range, with anything outside
  it flagged; then the full night.
- **Activity:** this week's workouts and how fresh or fatigued you are, the start
  buttons, a 7-day training-load forecast (rest / keep going / push), and Strength
  progress (personal records, estimated 1RM, weekly volume).
- **My Health:** the last 30 days as four trend tiles (HRV, resting HR, sleep,
  recovery) compared with the 30 days before, and a monthly report.

Everything else from upstream Edge is still there: sleep staging, recovery, strain,
stress, journal with correlation insights, cycle tracking, AI coach, smart alarm,
Health Connect export and backups. See [docs/FEATURES.md](docs/FEATURES.md) and
[CHANGELOG.md](CHANGELOG.md).

### Good to know

- **Usual ranges need history.** The Vitals comparisons need 14 nights of your own
  data; trend tiles need 7 recorded days in the last 30. Until then they say they're
  still learning instead of guessing.
- **Live values are only what the band streams live:** heart rate, beat timing and
  motion. HRV, recovery, sleep and skin temperature are computed from synced history.

## Moving from OpenStrap Edge

Pulseline installs alongside Edge (different app id). In Edge: Profile → Data → *Export
the database*. In Pulseline: Profile → Data → *Import a file*. Then uninstall Edge so the
two apps don't compete for the band's Bluetooth connection. Don't open the band maker's
own app with the band afterwards: a firmware update could change the data format.

## Building

Flutter 3.41.6, JDK 17, Android SDK 36:

```bash
flutter pub get
flutter build apk --release
```

Upstream's development guide still applies: [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).
The original README is kept as [README.upstream.md](README.upstream.md).

## License and trademarks

AGPL-3.0, same as upstream (see [LICENSE](LICENSE) and [NOTICE](NOTICE)). "OpenStrap" is
the OpenStrap project's name; this fork uses it only to credit where the code comes from.
WHOOP is a trademark of its owner; Pulseline is not affiliated with WHOOP.

Not a medical device. Metrics are approximations from published research.
