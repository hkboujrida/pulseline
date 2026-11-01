# Pulseline

A health app for your WHOOP band: recovery, strain, sleep and overnight vitals, computed on
your phone. No subscription, no account, nothing uploaded.

**Pulseline is based on [OpenStrap](https://github.com/OpenStrap)** (the Edge app, its
protocol decoder and analytics). It is an independent fork with a redesigned interface and
extra features. It is not made, endorsed or supported by the OpenStrap project; please
don't take Pulseline issues to OpenStrap's channels. Report them here instead.

## Download

Android: grab the APK from [Releases](../../releases/latest).

## What's different from upstream Edge

- **Redesign:** calmer near-black / warm-white surfaces, flat cards, lighter numerals.
- **Tabs:** Today · Vitals · Activity · My Health.
- **Vitals:** readiness shown against *your own* usual level (centred scale), and overnight
  resting HR, HRV, breathing rate and skin temperature against your usual range, with
  anything outside it flagged.
- **Training-load forecast:** the next 7 days of fitness, fatigue and form under
  rest / keep going / push.
- **Strength progress:** personal records, estimated 1RM (Epley) and weekly volume, from
  the sets you log in a strength workout.
- **Monthly report:** this month against last month, with your standout days.
- **"More for you"** on Today: journal, mind, monthly report, strength, body clock and
  sleep plan one tap away.

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
