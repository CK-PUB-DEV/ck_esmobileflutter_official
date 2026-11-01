# Login and school list screens (app)

The two screens a person sees before signing in: the school list (`Find your school`) and the
login (`Welcome back`). Both share one look: a gradient header with soft circles, the circular
Essentiel logo, and a rounded white sheet that overlaps the header.

Sign-in behaviour (API calls, token saving, error messages, the "school unavailable" dialog) is
**unchanged**. Only how the screens are drawn changed.

## 1. Files

| File | What it holds |
|---|---|
| `lib/schools/screens/schools.dart` | `SchoolScreen`: header, search, school grid, school card |
| `lib/auth/login.dart` | `LoginScreen`: header, form, "What you can do" row |
| `lib/widgets/ui/essentiel_mark.dart` | `EssentielEmblem` and `EssentielMark` (shared by both screens) |
| `lib/widgets/ui/ui.dart` | exports `essentiel_mark.dart` with the other shared widgets |
| `assets/essentiel.png` | the source logo (1080px square) |

## 2. Layout

```
┌────────────────────────────┐
│ header: gradient + circles │   login: the school's own colour
│ [logo]            [button] │   school list: Essentiel red
│ title / school name        │
│ (search bar)               │   school list only
├╮                          ╭┤
│ ╰── rounded white sheet ──╯│   28px (list) / 32px (login) radius
│ login form  or  school grid│
└────────────────────────────┘
```

- **School list**: logo + theme toggle, "Student & Parent Portal" badge, title, search bar floating
  in the header. Below, "All schools" (becomes "Results" while searching) with a count pill, then a
  2 / 3 / 4 column grid (width under 600 / 600+ / 900+). Each card: circular school logo, name (3
  lines), school code chip, red arrow button. Pull to refresh still works.
- **Login**: logo + "Change school" pill, the school's logo in a white circle, school name and the
  portal badge. In the sheet: "Welcome back", username and password fields, a note that student
  usernames start with `S` and parent usernames with `P`, the Sign in button, and a "What you can
  do" row (Report card, Class schedule, Billing, Tap history).
- **Keyboard open**: the logo, name and badge fold away (login), or the title block does (school
  list), so the fields and the Sign in button stay above the keyboard.
- **Entrance**: the login screen fades and slides up over 650 ms.

## 3. Colour

- **Login** uses the colour the school sets in its settings (`schoolcolor` from `schoolinfo`).
  The header runs from that colour to a darker shade of it; the Sign in button, focused field
  outline and feature icons use the same colour. If the colour is missing or invalid it falls back
  to `0xFFD71920`. Text on the header turns dark when the school colour is light.
- **School list** has no school yet, so it uses Essentiel's red (`0xFFD71920`).
- Light and dark mode both work; the header stays coloured in both, only the sheet and cards follow
  the theme.

## 4. The Essentiel logo

`assets/essentiel.png` is a 1080px square with wide white margins and a wordmark that cannot be read
at small sizes. `EssentielEmblem` crops it to the block emblem; `EssentielMark(size:)` puts that in a
white circle with a soft shadow.

- The crop is fixed to the blocks' bounding box in the image (`Alignment(0, -0.51)`, width factor
  0.63, height factor 0.583). If `essentiel.png` is replaced, re-measure those numbers.
- A school with no logo of its own shows `EssentielEmblem` in its place (list cards and login).
  This used to be `assets/cklogo.png`.

## 5. What was left out on purpose

- Forgot password, sign up, Google and fingerprint sign-in: the servers have no endpoints for them.
- Illustrations: none fit every school's branding. The circles in the header are drawn in code
  (`_HeaderDecorPainter`).

## 6. Checks done

On an Android phone against the HCB server (v2) with a student account:

- School list: load, scroll, search ("HCB"), keyboard open, tap a school, dark mode.
- Login: normal and keyboard-open layout, wrong password (`Incorrect username or password.`),
  successful sign-in to Home.
- `flutter analyze` reports no issues for `lib/auth`, `lib/schools` and `lib/widgets/ui`.

Not checked: tablet or landscape widths, a school with a very light or very dark colour, the
"No schools found" and load-error states under the new theme, text scaling above 1.3.

## 7. Known limits

- The username note ("start with S / P") comes from the accounts seen on HCB and ACFI. A school
  that names usernames differently would show a wrong hint.
- Long school codes are shortened on the card (for example `CMLC - …`).
- The Essentiel mark on the school list screen is not tappable.
