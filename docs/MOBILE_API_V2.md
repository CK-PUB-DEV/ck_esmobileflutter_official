# Mobile API v2 (app)

How the Essentiel app (Flutter, `pushtrial`) talks to a school's server, and what it does
differently when that server has the v2 API. Companion document in the backend repo (`es_ldcu`):
`docs/MOBILE_API_V2.md` (routes, security model, tests, how to add v2 to another project).

## 1. v1 and v2 side by side

- **v1** `/api/mobile/*`: what every school server has had. Open, no sign-in token.
- **v2** `/api/mobile/v2/*`: token sign-in, per-student access, alerts, messages, grading setup.

The app finds out per school, once per run: `GET {school}/api/mobile/v2/ping`
(`lib/api/api_version.dart`, `ApiVersion.of(domain)`):

| Answer | Meaning |
|---|---|
| 200 `{"api":2,...}` | v2 server: use `/api/mobile/v2/*`, sign in with a token |
| 404 | v1-only server: use `/api/mobile/*` exactly as older apps did |
| no connection | use the version learned last time (`api_version_<domain>` pref), else v1 |

`lib/api/api.dart` builds every address through `_p(path)`, which inserts `v2/` after `api/mobile/`
when the school is v2. v1 addresses are left exactly as they were. A new endpoint should be added as
`String get _x => _p("/api/mobile/<name>")`.

A school on a v1 server keeps working, but gets none of the v2 features (token login, app-owned
alerts without Firebase, term-aware report card, data-driven billing screen).

## 2. Token sign-in (v2 only)

- `lib/api/auth_token.dart` (`AuthToken`): keeps the token in `flutter_secure_storage` (Android
  Keystore), cached in memory. `headersFor(url)` returns `Authorization: Bearer` + `X-Mobile-Token`
  for v2 addresses except `ping`, `login`, `schoolinfo`; empty for v1 and for those.
- `lib/api/authed_http.dart`: a drop-in for `package:http` (`get`, `post`, `MultipartRequest`) that
  adds those headers. `api.dart` and `school_alerts.dart` import it as `http`, so the ~65 call sites
  needed no change. The `Dio` upload sets the headers itself. `api_version.dart` and the school-list
  API (`lib/schools/api/school_api.dart`) use raw `http` on purpose (no token needed).
- Login (`lib/auth/login.dart` -> `CallApi.login`): v2 `POST /api/mobile/v2/login` with JSON
  `{username, pword}`; v1 the original GET. On v2 the reply's `token` is saved; on v1 any old token
  is cleared. 401 / 429 show their own messages.
- Any 401 on a request that needs the token (expired, password changed, or a phone that was signed
  in before the app kept tokens) calls `AuthToken.reject()`: the token and saved student are cleared
  and `main.dart` (`_sessionEnded`) shows the sign-in screen with "Your session ended."
- Logout (`profile.dart`) clears the token, the saved student and the alert state.

## 3. What each screen calls

Names are the same on v1 and v2. On v2 every one needs the token except `schoolinfo`; the student
is always the token's, so the `studid` the app sends is only for v1.

| Screen | Endpoints |
|---|---|
| Login | `schoolinfo`, `login` |
| Home | `api_enrolledstud`, ledger (see 5), `alerts` / `messages` (bell) |
| Report card | `schoolinfo`, `api_sysem`, `api_enrolledstud`, `grading_setup` (v2), `api_getgrade`, `api_attendance`, `api_observedvalues` |
| Billing | `api_studledger` (v1 layout) or `api_student_ledger_v2` (v2 layout) |
| Class schedule | `api_getschedule` or `api_class_schedule_v2` |
| Payments | `api_get_transactions`, `api_get_onlinepayments`, `api_get_onlinepaymentoptions`, `api_send_payment` |
| Tap history | `api_get_taphistory` |
| Calendar | `api_get_events`, `api_sysem` |
| Scholarship | `api_getscholarshipsetup`, `api_getrequirement`, `api_uploadrequirement`, `api_savescholarship` |
| Notifications | `messages` (v2) or the legacy list (v1) |

## 4. Report card: terms or quarters (`lib/services/grading_setup.dart`)

Schools grade in 4 quarters, in 3 terms (configured per school year in `ibed_term_config`), or, for
college, Prelim / Midterm / Pre-final / Final. On a v2 server the report card asks
`grading_setup?syid=&levelid=` and draws exactly those periods with the school's own names (e.g.
"First Term"); the Final rating waits only for the school's own periods (a 3-term school used to wait
for a Q4 that never exists). On a v1 server there is no answer and the app shows 4 quarters. The
setup is per school year: an older year with no config is shown as quarters.

The grade rows themselves still come from `api_getgrade` (`q1..q4`, a status per period, `finalrating`);
a period is shown only when its status is `4` (released).

## 5. Billing screen choice

Two layouts exist: **v1** a flat ledger (`studledger`) and **v2** fees by category + monthly
schedule (`student_ledger`). `ApiVersion.billingVersion()` picks:
the server's `ledger` hint from `ping` (what the school's data really is) -> else the school list's
`system_version` -> else v1. Used by Home's balance card, the Billing button and the Home button.
The Home card asks for semester 1 when the enrollment semester is 0 (basic education), which the v1
ledger otherwise reads as "no rows".

## 6. Alerts without Firebase (v2 servers)

`lib/services/school_alerts.dart`, `lib/services/messages_repository.dart`,
`lib/services/message_read_store.dart`, `lib/screens/notifications.dart`.

- Taps and announcements are fetched from `GET /api/mobile/v2/alerts` with per-school and per-student
  cursors (SharedPreferences), by a foreground service every 30 s (the parent chooses it in Profile)
  with a 15-minute WorkManager fallback. Android only.
- A pop-up is shown only for items newer than 24 h (age is computed on the server, so a wrong phone
  clock can't matter); older ones are only listed.
- Read/unread is kept only on the phone (`msg_read_<school>_<studid>`); the app never writes backend
  status.
- Firebase push is automatic per school (`AppConfig.firebasePushMode`): off on v2 servers (the token
  is removed), on for v1 servers. Notification ids use fixed blocks (taps 0, announcements 4e8,
  SMS 8e8, blast 1.2e9).

## 7. Build, release and test tooling

- Test school list: `tool/test_schools.json` (private IPs, **never** put it under `assets/`; it is
  git-ignored, so each developer keeps their own copy: a JSON array in the same shape as the school list).
  `tool/make_test_defines.dart` generates `tool/test_schools.define.json` (git-ignored), passed with
  `--dart-define-from-file`. Without it the app shows the real school list. `AppConfig.useTestSchools`
  is false in release builds.
- `tool/build_release.ps1`: release APK/AAB with obfuscation and debug info split; release upgrades
  `http://` school addresses to `https://` (`AppConfig.secureUrl`, `_upgradeSavedSchoolToHttps`).
- Android: `allowBackup=false` + `dataExtractionRules`, `POST_NOTIFICATIONS`, foreground service
  (special use), `firebase_messaging_auto_init_enabled=false`.
- Local server on the phone: `adb reverse tcp:8000 tcp:8000` and a test school whose `eslink` is
  `http://127.0.0.1:8000/`. Run a school project with `php -S 0.0.0.0:8000 server.php`. To try one
  project's code on another school's database, start `php -S` with a small router that sets
  `database.connections.mysql.database` after the config loads (cached config ignores `.env` overrides).
- Tests: `flutter test` (`test/api_versioning_test.dart`, `test/auth_token_test.dart`, widget test).
  `dart analyze lib` should report no errors.
- Dependencies of note: `shadcn_ui` (UI), `flutter_secure_storage` (token), `workmanager` pinned to
  0.9.0 (newer needs Flutter >= 3.38), `flutter_local_notifications`.

## 8. When a school server is updated

Nothing to do in the app: the next run's ping returns 200, the phone is asked to sign in again
(its old session has no token), and the v2 features switch on. If a school is rolled back to v1 the
ping returns 404 and the app returns to v1 behaviour.

## 9. Known gaps

- v1 servers stay open and unauthenticated (by design, for old apps).
- A token can't be revoked from the server side except by changing the password; logout only clears
  the phone.
- Alerts/Firebase behaviour and the foreground service are Android only.
- HEIC photos from iPhones would be refused by the v2 upload check.
- The grade, ledger and schedule calculations on v2 are still the v1 code (see the backend doc, section 4).
