# Login → live server guide (app)

How the app gets from "open the app" to "signed in on the school's own live server", what is
hidden today, what is **not** hidden, and what the website repo (`esvault` / `es_ldcu`) needs to
change for the school list to be private for real.

> Audit date: 2026-11-20. Everything about the app below was read from this repo. Nothing about the
> backend was verified: the `esvault` and `es_ldcu` code is not in this repo, so every backend item
> is a **recommendation to check**, not a fact.

## 1. The flow

```
app start
  └─ LoadingScreen                     lib/features/loading/loading_screen.dart
       ├─ GET esvault.essentiel.ph/api/getSchoolList   (whole list, to refresh schoolVersion)
       └─ saved user? → /home : /login
LoginScreen                            lib/features/auth/login_screen.dart
  ├─ no saved school → form shows only the "Select your school" field
  ├─ tap it → School finder sheet      lib/features/schools/school_finder_sheet.dart
  │     ├─ GET esvault.essentiel.ph/api/getSchoolList   (whole list, cached for the run)
  │     └─ SchoolMatcher.find()        lib/features/schools/school_matcher.dart  (filters on the phone)
  ├─ pick → saved to SharedPreferences: selectedSchool (eslink), selectedSchoolId, schoolVersion
  ├─ GET {eslink}/api/mobile/schoolinfo      name, colour, logo
  └─ Sign in → {eslink}/api/mobile/login  (v1)  or  {eslink}/api/mobile/v2/login  (v2, returns token)
```

- **Main server (directory):** `https://esvault.essentiel.ph/` (`lib/features/schools/api/school_api.dart`).
  It only knows *which schools exist and where they live*. It never sees a password.
- **School server (live):** each school's `eslink`. Username and password go **only** here, over
  HTTPS in release builds (`AppConfig.secureUrl` upgrades `http://`).
- **v1 vs v2** is decided per school by `GET {eslink}/api/mobile/v2/ping`
  (`lib/core/api/api_version.dart`). See `docs/MOBILE_API_V2.md`.

## 2. What the finder does now

`SchoolMatcher` (`school_matcher.dart`) never draws the list:

| Typed | Result |
|---|---|
| under 2 characters | nothing |
| exactly a school code (`HCB`) | that one school only |
| code prefix, or name contains the text (name needs 3+ characters) | at most 5 schools |
| no match | "No school matches that" |

Case, spaces and punctuation are ignored (`cmlc bc` finds `CMLC - BC`). A school with an empty
`eslink` shows "Currently unavailable" and cannot be picked.

## 3. Audit: is hiding the list the best approach?

**Short answer: it is the right user experience, but it is only cosmetic privacy.** To make it
private for real, the website needs a change.

### 3.1 Findings

| # | Severity | Finding | Where |
|---|---|---|---|
| 1 | **High** | The list is hidden on screen but **the full list is still downloaded by the phone**, and the endpoint is open. Anyone can `GET https://esvault.essentiel.ph/api/getSchoolList` and read every school's name, code, `eslink` (its live server address), logo, `anydesk` id and version. Hiding it in the app does not hide it from them. | `school_finder_sheet.dart:76`, `school_api.dart` |
| 2 | **Medium** | The splash downloads the **entire list on every launch** just to read one school's `system_version`. That is the same exposure, plus wasted data and a slower start. `ApiVersion` (ping) already learns the version from the school itself. | `loading_screen.dart:29-49` |
| 3 | Medium | Matching happens on the phone, so the client holds every `eslink`. Anyone who unpacks the running app or intercepts the response gets the full list. Obfuscation in `tool/build_release.ps1` does not change this. | `school_finder_sheet.dart:38` |
| 4 | Low | The finder's `anydesk` field is downloaded for every school although the login flow never uses it. Remote-support ids should not be in a public response. | `models/schools.dart` |
| 5 | Low | If `getSchoolInfo()` fails (for example the phone is offline) the message always says the school is "undergoing setup" and the bad choice stays saved. A network error is not a school problem. | `login_screen.dart:91-96`, `:253-273` |
| 6 | Low | `print('Loaded school eslink: …')` writes the school address to the log. | `shared/utils/school_utils.dart:86` |
| 7 | Info | `docs/LOGIN_AND_SCHOOL_LIST.md` is out of date: it describes an "All schools" grid, a search bar in the header, an "S/P username" note and old file paths. The screens no longer work that way. | `docs/` |
| 8 | Info | Good: test schools are compiled out of release builds (`!kReleaseMode`), release forces HTTPS, tokens use secure storage, 401 and 429 have their own messages. | `app_config.dart` |

### 3.2 Recommendation

Keep the type-a-code-or-name screen. Add a **server-side lookup** so the phone never receives the
list. Do both halves; the app alone cannot fix finding 1.

**Website repo (`esvault`) — ask for:**

1. `GET /api/schools/search?q=<text>`
   - require `q` of 2+ characters (3+ for a name match), return **at most 5** rows;
   - exact code match returns that one school alone (same rule as `SchoolMatcher`);
   - return only what the app uses: `id`, `schoolname`, `schoolabrv`, `schoollogo`, `eslink`,
     `system_version`. Drop `anydesk`;
   - rate-limit per IP (for example 30 requests a minute) so it cannot be walked `aa`, `ab`, `ac`…
2. `GET /api/schools/{id}` (or `?id=`) returning that one school, for the splash's version refresh.
   Better still: delete that refresh and rely on the ping.
3. Keep `getSchoolList` working **only for old installed apps**, then restrict or remove it once
   the minimum app version is raised (force-update). Until then finding 1 stays open for those apps.
4. Make sure a school with no live server returns an empty `eslink` or is left out, not a broken
   address.
5. Confirm CORS and caching are off for the list (it should not be cacheable by a proxy).

**App repo — after the website change:**

1. `SchoolApi`: add `searchSchools(String q)` and `getSchool(int id)`.
2. `school_finder_sheet.dart`: debounce typing (about 300 ms), call search, drop the `_cache` of the
   whole list. `SchoolMatcher` becomes a fallback or is deleted.
3. `loading_screen.dart`: remove `_refreshSchoolVersion` or switch it to `getSchool(id)`.
4. Keep the test-school path (`AppConfig.useTestSchools`) as it is.
5. Fix findings 5 and 6, and refresh `LOGIN_AND_SCHOOL_LIST.md`.

### 3.3 If the website cannot change yet

The current approach is still worth keeping: it stops casual browsing and gives a shorter, clearer
sign-in. Treat it as "tidy", not "secure", and do not tell schools the list is private.

## 4. How to connect to the main live server

1. **Release build** (talks to the real directory and real schools):
   ```
   .\tool\build_release.ps1
   ```
   No `TEST_SCHOOLS_JSON`, no `ALLOW_HTTP`, so the real `esvault` list is used and school addresses
   are forced to HTTPS.
2. **Check the directory is reachable** (PowerShell):
   ```
   Invoke-WebRequest https://esvault.essentiel.ph/api/getSchoolList | Select-Object StatusCode
   ```
3. **Check one school is live and which API it speaks:**
   ```
   Invoke-WebRequest https://<school-eslink>/api/mobile/v2/ping   # 200 = v2, 404 = v1
   Invoke-WebRequest https://<school-eslink>/api/mobile/schoolinfo
   ```
4. **Run against a local backend instead** (debug only): see `docs/MOBILE_API_V2.md` section 7
   (`tool/test_schools.json`, `dart run tool/make_test_defines.dart`,
   `flutter run --dart-define-from-file=tool/test_schools.define.json`). It is ignored in release.
5. **Sign-in check:** pick a school, sign in with a real student or parent account. v2 saves a
   token in secure storage; v1 saves none. A wrong password shows "Incorrect username or password."

### Troubleshooting

| Symptom | Likely cause |
|---|---|
| "Could not load schools" | `esvault` unreachable, or non-200. Check step 2. |
| "No school matches that" | wrong code or spelling; school missing from the directory |
| "Currently unavailable" on a result | the school's `eslink` is empty in the directory |
| "School unavailable… undergoing setup" | `schoolinfo` failed or returned an empty list (or the phone is offline) |
| Signs in, then "Your session ended." | a v2 token was rejected (401): sign in again |
| Works in debug, fails in release | the school address is `http://` and is upgraded to `https://`; the school needs a valid certificate |

## 5. One repo per school: what it changes

Each school has its own repo and server (`es_ldcu`, `es_sbc_local`, `es_ndm_online`, `es_sva`,
`es_ndsc_online`, `mslu_local`, `es_hcbi`, `es_bcc`, `es_pcc`, `hchscp_online`, …). That does **not**
block the fix, because there are two different jobs:

| Job | Where it lives | Change needed for a private list? |
|---|---|---|
| **Directory**: which schools exist, their codes, and their `eslink` | **One** place: `esvault.essentiel.ph` | **Yes, once.** Add `search` and `{id}` there. |
| **School API**: `ping`, `schoolinfo`, `login`, grades, billing | Every school's own repo | **No.** Search never touches them. |

So the work is one change in one repo, not one change per school. The school repos only matter
for the v2 rollout (`docs/MOBILE_API_V2.md` section 8): a school still on v1 keeps working, with
no token sign-in and no rate-limited login.

**Open question (I could not check this):** which repo serves `esvault.essentiel.ph`? It is not in
the list you showed, nor in `C:\laragon\www` on this machine (`esvault` is not there; no school
repo is either). It is one of: a separate repo you did not screenshot, or one of the school repos
acting as the directory. Whoever owns that repo makes the change in section 3.2.

**Keeping the directory correct with many repos:** each school's `eslink`, code and
`system_version` has to be entered in the directory by hand today. Findings to check there:
a school that moves domain, or upgrades to v2, needs its directory row updated, or the app
points at a dead address or the wrong API version. The app's ping (`ApiVersion`) corrects the
version on its own; it cannot correct a wrong `eslink`.

**Alternative with no directory lookup at all:** if every school had a predictable address
(for example `https://<code>.essentiel.ph`), the app could build the address from the typed code
and call that school's `schoolinfo` directly. Nothing would be listed anywhere. It needs a
uniform subdomain scheme and DNS for every school, which per-school repos on different hosts
probably do not have, so the directory search is the more realistic route.

## 5b. Status of the fix (2026-11-20)

**Done in the app** (`school_api.dart`, `school_matcher.dart`, `school_finder_sheet.dart`,
`loading_screen.dart`):

- The finder now calls `GET /api/schools/search?q=` (300 ms after typing stops, newest answer wins)
  and shows what the server returns, at most 5.
- **Until `esvault` has that endpoint** it answers 404, and the app falls back to the old
  `getSchoolList` and matches on the phone, exactly as before. Nothing breaks, but nothing is
  private yet either.
- The splash no longer downloads the list. The school's version comes from the choice made at
  sign-in and the per-school `ping`.
- `flutter test` passes (31 tests); `dart analyze` shows no new issues.

**Still to do on `esvault`** (the one repo that serves `esvault.essentiel.ph`). Laravel sketch:

```php
// routes/api.php
Route::get('schools/search', [SchoolDirectoryController::class, 'search'])
    ->middleware('throttle:30,1');

// SchoolDirectoryController
public function search(Request $request)
{
    $q = preg_replace('/[^a-z0-9]/', '', strtolower((string) $request->query('q')));
    if (strlen($q) < 2) return response()->json([]);

    // Normalise the stored column the same way (or keep a generated `code_key` column).
    $norm = fn ($col) => "LOWER(REGEXP_REPLACE($col, '[^A-Za-z0-9]', ''))";
    $cols = ['id', 'eslink', 'schoolabrv', 'schoolname', 'schoollogo', 'system_version'];

    $exact = School::whereRaw($norm('schoolabrv').' = ?', [$q])->first($cols);
    if ($exact) return response()->json([$exact]);

    $rows = School::query()
        ->where(fn ($w) => $w->whereRaw($norm('schoolabrv').' LIKE ?', [$q.'%'])
            ->orWhere(fn ($n) => strlen($q) >= 3
                ? $n->whereRaw($norm('schoolname').' LIKE ?', ['%'.$q.'%']) : $n->whereRaw('0=1')))
        ->orderBy('schoolname')->limit(5)->get($cols);

    return response()->json($rows)->header('Cache-Control', 'no-store');
}
```

Rules the app already assumes: a JSON list (or `{"data": [...]}`) of the same school shape as
`getSchoolList`; empty list for no match; no `anydesk`. `REGEXP_REPLACE` needs MySQL 8 / MariaDB
10.0.5+; on older MySQL store a normalised `code_key` / `name_key` column instead.

**How to roll it out safely**

1. Deploy `search` on `esvault`; check `GET /api/schools/search?q=hcb` returns one school.
2. Ship this app version. New installs stop downloading the list.
3. Wait until most phones are updated, then raise the minimum app version.
4. Restrict `getSchoolList` (token or remove). Phones that never updated lose the finder, so
   force-update first.
5. In the app, delete the fallback (`_localList` in `school_finder_sheet.dart`) and
   `SchoolApi.getSchoolList`.

## 6. Server-side fix: full guide

Do this in the **directory repo**, the one that serves `esvault.essentiel.ph`. Nothing here is
needed in the school repos. Assumption (not verified): it is a Laravel app with a `schools` table
and a model that `getSchoolList` already reads. If it is plain PHP or another framework, keep the
same rules and translate the code.

### 6.1 Find the repo and read the current code

1. GitHub → search `getSchoolList user:Jayvan123` (or `org:<org>`), tab **Code**. Or on the live
   server: `grep -rl "getSchoolList" routes app` then `git remote -v` in that folder.
2. Open `routes/api.php` and find the `getSchoolList` route. Note which controller, model and
   table it uses, and the column names (`schoolabrv`, `schoolname`, `eslink`, `schoollogo`,
   `system_version`, `anydesk`). **Use the real names you see**, not the sketch's.
3. Work on a new branch, never directly on the branch the live server deploys from:
   `git checkout -b feature/school-search`.

### 6.2 Add the search route

In `routes/api.php`, next to the existing list route:

```php
Route::get('schools/search', [SchoolDirectoryController::class, 'search'])
    ->middleware('throttle:30,1');
```

`throttle:30,1` = 30 requests a minute per IP. Do not skip it: without it someone can type
`aa`, `ab`, `ac`… and rebuild the whole list.

### 6.3 Add the controller method

Use the code in section 5b. Rules it must keep (the app depends on them):

- fewer than 2 letters/digits typed → return `[]`;
- text equals a school code (ignoring case, spaces, punctuation) → return **only** that school;
- otherwise code starts with the text, or (3+ characters) name contains it → **at most 5**, sorted
  by name;
- return only `id, eslink, schoolabrv, schoolname, schoollogo, system_version`. **Never** `anydesk`;
- send `Cache-Control: no-store`.

If the server is older than MySQL 8 / MariaDB 10.0.5 (no `REGEXP_REPLACE`), add two columns and
fill them once instead:

```php
// migration
$table->string('code_key')->nullable()->index();
$table->string('name_key')->nullable();
// backfill (tinker or a seeder)
School::each(fn ($s) => $s->update([
    'code_key' => strtolower(preg_replace('/[^A-Za-z0-9]/', '', $s->schoolabrv)),
    'name_key' => strtolower(preg_replace('/[^A-Za-z0-9]/', '', $s->schoolname)),
]));
```

Then search on `code_key` / `name_key` and keep them updated whenever a school is saved
(model `saving` hook).

### 6.4 Test before deploying

Add `tests/Feature/SchoolSearchTest.php` (adapt the factory):

```php
public function test_short_text_returns_nothing()
{
    $this->getJson('/api/schools/search?q=a')->assertOk()->assertExactJson([]);
}
public function test_exact_code_returns_only_that_school()
{
    School::factory()->create(['schoolabrv' => 'HCB']);
    School::factory()->create(['schoolabrv' => 'HCHS']);
    $this->getJson('/api/schools/search?q=hcb')->assertOk()->assertJsonCount(1);
}
public function test_never_more_than_five_and_never_anydesk()
{
    School::factory()->count(9)->create(['schoolname' => 'Holy Cross School']);
    $r = $this->getJson('/api/schools/search?q=holy')->assertOk()->assertJsonCount(5);
    $this->assertArrayNotHasKey('anydesk', $r->json()[0]);
}
```

Run `php artisan test`. Also hit it by hand locally: `/api/schools/search?q=hcb`, `?q=a`, `?q=zzzz`.

### 6.5 Deploy and verify

1. Merge and deploy to the live server (run `php artisan route:clear` / `route:cache` if routes are cached).
2. Open `https://esvault.essentiel.ph/api/schools/search?q=hcb` → one school.
3. Run the Flutter app, open the finder, type a code. It now uses search (the old list is no
   longer downloaded). Quick proof: in the server access log you see `/api/schools/search` and no
   `/api/getSchoolList` from the new app.
4. **Rollback** if anything is wrong: revert the deploy. The app falls back to `getSchoolList`
   automatically (404 → old list), so users are not blocked.

### 6.6 Close the old open list (last, after phones update)

1. Ship the new app version and wait. Watch the access log: calls to `getSchoolList` should fall
   steadily as people update.
2. Raise the minimum app version / force-update the rest.
3. Then restrict `getSchoolList` (remove it, or require a secret/token) and return 404 or 410.
   Old apps that never updated will stop finding schools, which is why this step is last.
4. Remove the fallback in the app (`_localList` in `school_finder_sheet.dart`, and
   `SchoolApi.getSchoolList`).

### 6.7 Prompt to paste into Claude (in the directory repo)

Open the **directory repo** in VS Code, start Claude Code there, and paste:

```text
This is the directory server for the Essentiel school app (esvault.essentiel.ph). Today the route
getSchoolList returns the whole list of schools (names, codes, live server address `eslink`,
`anydesk`, etc.) to anyone. I need a private lookup instead. Do not break getSchoolList yet:
old installed apps still use it.

1. Audit first, change nothing: find the getSchoolList route, controller, model and table; list
   the real column names; tell me the Laravel and database versions and whether REGEXP_REPLACE
   is available. Report anything else that exposes the school list or `anydesk`.
2. Then add GET /api/schools/search?q= with these rules:
   - normalise text (lowercase, keep only a-z and 0-9) for the query and the stored code/name;
   - fewer than 2 characters -> return [];
   - text equals a school code -> return only that school;
   - else code starts with the text, or (3+ characters) name contains it -> at most 5, sorted by name;
   - return only id, eslink, schoolabrv, schoolname, schoollogo, system_version (never anydesk);
   - throttle:30,1 and Cache-Control: no-store;
   - response is a plain JSON array in the same shape as getSchoolList's items.
3. If REGEXP_REPLACE is unavailable, add code_key/name_key columns with a migration, a backfill,
   and a model saving hook.
4. Write feature tests: short text, exact code returns one, max five, no anydesk, no match -> [].
   Run them and show the output.
5. Keep getSchoolList working for now, but add a comment marking it deprecated.
6. Work on a new branch, make small commits, do not push or deploy. Finish with a summary of
   files changed, the test results, and the exact URL to check after deploying.

Mobile app contract (from the Flutter repo): it calls /api/schools/search?q=<text>, accepts a
JSON list or {"data": [...]}, and falls back to getSchoolList on 404.
```

## 7. Checklist before telling schools "the list is private"

- [ ] `search` and `{id}` endpoints live on `esvault`
- [ ] rate limit on `search` verified
- [ ] `anydesk` removed from public responses
- [ ] app updated to use search, splash no longer downloads the list
- [ ] minimum app version raised, then `getSchoolList` restricted
- [ ] `docs/LOGIN_AND_SCHOOL_LIST.md` rewritten
