# ayna-app

The Flutter client for **Ayna** (آئینہ, "mirror" in Urdu) — an AI skin analysis
app. You take a selfie, a vision model scores it, and you watch the result move
week over week.

> Part of a four-repo project:
> **[ayna-app](https://github.com/mburhankhan101-glitch/ayna-app)** (you are here) ·
> [ayna-backend](https://github.com/mburhankhan101-glitch/ayna-backend) ·
> [ayna-spike](https://github.com/mburhankhan101-glitch/ayna-spike) ·
> [ayna-docs](https://github.com/mburhankhan101-glitch/ayna-docs)
>
> Start with [ayna-docs](https://github.com/mburhankhan101-glitch/ayna-docs) for
> why any of this is shaped the way it is.

Portfolio project, not a business. Nobody is being sold anything.

## Running it

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=https://ayna-api-5gn25pfjrq-uw.a.run.app
```

Requires an Auth0 tenant configured for PKCE; see
[ayna-backend](https://github.com/mburhankhan101-glitch/ayna-backend) for the
matching API.

### The design harness

```bash
flutter run -t lib/main_preview.dart
```

**Use this for any UI work.** Every result state, the paywall, the trend chart,
the capture-to-report morph, the name screen and every rejection outcome — with
no auth, no network, no camera and no credits.

It exists because the result screen is only reachable in the real app by
completing a scan, and every scan is a paid vendor call plus one of the user's
weekly allowance. Iterating on a layout through that path costs real money per
look, which is an absurd price for moving a number four pixels — and it makes
you avoid iterating, which is the worse cost.

## Layout

```
lib/
  screens/     one file per destination; capture, analysing, result, trend…
  widgets/     painters and shared pieces (scan_morph, redness_overlay…)
  state/       ChangeNotifier per flow — no state-management package
  services/    api_client, auth_service
  models/      wire types, decoded from the OpenAPI contract
  theme/       colour, type, spacing, radius and motion tokens
  dev/         sample reports for the preview harness
test/          71 tests: layout, motion, reduced-motion, copy guarantees
```

No state-management package, deliberately. The surface is three flows and a
session; `ChangeNotifier` is honest about that, and a DI container would be
scaffolding around a problem this app does not have.

## Five things here that are decisions, not boilerplate

**`theme/ayna_motion.dart` — tokens for time.** The theme had space, radius and
colour but nothing for duration or curve, and that was the actual reason every
screen read as static. Motion is a design token like any other. Every value
also passes through `AynaMotion.of(context, …)`, which collapses to zero when
the platform asks for reduced motion — so accessibility is the default path,
not a branch someone has to remember.

**`widgets/scan_morph.dart` — the capture oval becomes the score arc.** One
painter interpolating shape, position, stroke width, sweep and colour across a
single 0→1 value. Not a Flutter `Hero`: the two screens do not share a widget,
they share a *shape*, and hand-authoring the interpolation is what lets the
ring unwind into the user's actual score rather than cross-fading between two
unrelated pictures.

**Bars, not a line, in the trend chart.** A line implies the value existed
continuously between two readings. It did not — there is one measurement a
week and nothing in between. The y-axis is anchored at zero for the same
reason: starting it at the lowest reading would make a two-point rise fill the
panel, which is how a chart lies without a single wrong number in it.

**The report screen has no containers.** It went from eight stacked bordered
cards to zero. One controller with staggered intervals drives the whole screen,
so the score, the arc and each concern arrive in sequence instead of appearing
as a wall.

**Error copy follows a rule that cost a real user real money.** An earlier
version hardcoded "Nothing was charged" on the branch that, by definition,
cannot know what happened — and told a user exactly that while their scan had
succeeded and been billed. The rule now: *only claim something was not charged
when the server said `allowanceSpent` is false.* Anywhere else, say what is
actually known. See `screens/main_shell.dart`.

## Privacy

The clean photograph is never stored. The redness overlay is composited
server-side and only the marked-up copy is kept, so there is no unmarked
picture of anyone's face in the database — and account deletion cannot forget
to delete one.

Photo retention is a real user setting (7 days / 30 days / a year / keep),
enforced by a scheduled sweep in the backend. It was a placeholder for a while
and onboarding was promising it worked, which is a bad way to run a privacy
screen; the promise is kept now.

## Not done yet

- **Store billing.** The paywall's upgrade button says "Plus is not on sale
  yet" and does nothing, deliberately.
- **Email OTP.** Sign-in still uses Auth0's Google connection and shows a
  development-keys warning.
- **Weekly reminder.** Still marked `SOON` on the settings screen, which is
  better than a toggle that flips and does not persist.
