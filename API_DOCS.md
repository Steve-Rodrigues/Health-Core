# HealthCore API Reference

Reference for the frontend: every backend endpoint, what to send, and what comes back.

> Tip: while the backend is running, FastAPI also serves interactive docs at `http://<host>:8000/docs`, where you can try requests in the browser.

---

## Basics

### Authentication

**Every request** to every endpoint except `GET /` must include the Supabase access token of the signed-in user in this header:

```
Authorization: Bearer <supabase_access_token>
```

The backend doesn't keep sessions or remember who you are between requests. Each request is checked on its own, so a request without the header is rejected even if the previous one worked. This includes `POST /users/signup`.

The backend reads the user's ID from the token, so **you never send a `user_id`** in a body, query string or path. Sending one does nothing; the ID always comes from the token.

#### Set it up once, not on every page

Don't add the header by hand in each screen. Put it in one shared API helper and have every page use that helper:

```dart
// lib/services/api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

const baseUrl = 'http://<host>:8000';

Map<String, String> _headers() {
  // Read the session on every call, so a refreshed token is always used.
  final token = Supabase.instance.client.auth.currentSession?.accessToken;
  return {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };
}

Future<http.Response> apiGet(String path) =>
    http.get(Uri.parse('$baseUrl$path'), headers: _headers());

Future<http.Response> apiPost(String path, Map<String, dynamic> body) =>
    http.post(Uri.parse('$baseUrl$path'), headers: _headers(), body: jsonEncode(body));
```

A page then only calls, for example, `apiPost('/nutrition/create-meal', {...})`.

- **Don't store the token yourself.** Access tokens expire after about an hour, and `supabase_flutter` refreshes them in the background. Always read `currentSession` at request time, as above.
- **On a `401`, send the user back to the login screen.** It means the token is missing, expired or invalid.

| Problem | Status |
|---|---|
| Header missing | `401` — `{"detail": "Not authenticated"}` |
| Token expired | `401` — `{"detail": "JWT token is expired"}` |
| Token invalid | `401` — `{"detail": "Token is not valid"}` |

### Request / response format

- Send bodies as JSON with `Content-Type: application/json`.
- Dates are strings in `"YYYY-MM-DD"` format, e.g. `"2026-10-20"`.
- Times are strings in `"HH:MM"` or `"HH:MM:SS"` format, 24-hour clock, e.g. `"23:30"`. Responses always include seconds (`"23:30:00"`).
- Datetimes come back as ISO 8601 with a timezone, e.g. `"2026-10-20T14:03:11.123456Z"`.
- IDs are UUID strings.

### Errors

Every error has the same shape:

```json
{ "detail": "Human-readable message" }
```

If the body doesn't match what the endpoint expects (a missing field, wrong type, or value out of range), you get **`422`** with a list explaining each problem:

```json
{
  "detail": [
    { "loc": ["body", "username"], "msg": "String should have at least 3 characters", "type": "string_too_short" }
  ]
}
```

---

## Endpoint summary

| Method | Path | What it's for |
|---|---|---|
| GET | `/` | Health check |
| POST | `/users/signup` | Create the user's profile after Supabase sign-up |
| GET | `/users/me` | Fetch the logged-in user's profile (login check) |
| POST | `/users/welcome-survey` | Save onboarding survey answers |
| GET | `/nutrition/summary?day=YYYY-MM-DD` | Nutrition dashboard for one day |
| POST | `/nutrition/create-meal` | Log a meal (for today) |
| PUT | `/nutrition/goal` | Create or update macro goals |
| POST | `/sleep/log` | Log one night of sleep |
| POST | `/lifting/start-workout` | Start (or resume) today's workout |
| POST | `/lifting/{workout_id}/finish-exercise` | Record one finished exercise |
| POST | `/lifting/{workout_id}/finish-workout` | End the workout and get the summary |
| PATCH | `/lifting/{workout_id}/submit-workout` | Save notes from the summary screen |
| POST | `/lifting/generate-program` | Get the top 3 program matches from the program survey |
| POST | `/lifting/{program_id}/choose-program` | Assign the program the user picked |

---

## General

### `GET /`

Health check. Needs no auth.

**Response `200`**
```json
{ "msg": "Success" }
```

---

## Users / onboarding

### `POST /users/signup`

Call this **once**, right after the user signs up in Supabase, to create their profile row in our database.

**Body**
| Field | Type | Required | Rules |
|---|---|---|---|
| `username` | string | yes | 3–20 characters, must be unique |

```json
{ "username": "steve" }
```

**Response `201`**
```json
{
  "id": "6f1c2a7e-1234-4cde-9abc-0f1e2d3c4b5a",
  "username": "steve",
  "created_at": "2026-10-20T14:03:11.123456Z"
}
```

**Errors**
- `409` `"User already exists in the database"`: this account already called signup.
- `409` `"Username is already in use"`: someone else has that username.
- `422`: username too short or too long.

---

### `GET /users/me`

Fetches the logged-in user's profile. Call it after login: a `404` means the account has no profile yet, so send the user to signup or onboarding.

**Body:** none

**Response `200`**
```json
{
  "username": "steve",
  "created_at": "2026-10-20T14:03:11.123456Z",
  "current_weight": 180.5,
  "goal_weight": 170.0,
  "workouts_per_week_goal": 4,
  "sleep_goal": 8.0
}
```
The four goal fields are `null` until the welcome survey is submitted. `height` is **not** returned here, even though the survey saves it.

**Errors**
- `404` `"User not found"`

---

### `POST /users/welcome-survey`

Saves the onboarding survey answers. Every field is optional, but **any field you leave out is set to `null`**, so send all of the answers in one request.

**Body**
| Field | Type | Required | Notes |
|---|---|---|---|
| `current_weight` | number | no | |
| `goal_weight` | number | no | |
| `workouts_per_week_goal` | integer | no | |
| `sleep_goal` | number | no | hours per night |
| `height` | number | no | |

```json
{
  "current_weight": 180.5,
  "goal_weight": 170,
  "workouts_per_week_goal": 4,
  "sleep_goal": 8,
  "height": 70
}
```

**Response `200`:** same shape as `GET /users/me`.

**Errors**
- `404` `"User not found"`: call `/users/signup` first.
- `409` `"Does not follow database constraints"`

---

## Nutrition

### `GET /nutrition/summary`

Data for the nutrition dashboard for a single day. Use it with the calendar's day buttons.

**Query parameter**
| Param | Type | Required |
|---|---|---|
| `day` | date `YYYY-MM-DD` | yes |

```
GET /nutrition/summary?day=2026-10-20
```

**Response `200`: user has set goals**
```json
{
  "date": "2026-10-20",
  "macros_consumed_counts": { "calories": 1450.0, "protein": 95.0, "carbs": 160.0, "fat": 40.0 },
  "macro_goals":            { "calories": 2200.0, "protein": 150.0, "carbs": 250.0, "fat": 70.0 },
  "macro_consumed_percentage": { "calories": 65.9, "protein": 63.3, "carbs": 64.0, "fat": 57.1 },
  "macro_score": 62.6
}
```
- `macro_consumed_percentage` values are 0–100, rounded to 1 decimal, and **capped at 100** (going over the goal still shows 100).
- `macro_score` is the average of the four percentages, rounded to 1 decimal.
- All numbers in this response are decimals (e.g. `1450.0`), so read them as `num`/`double`, not `int`.

**Response `200`: user has not set goals yet**
```json
{
  "date": "2026-10-20",
  "macros_consumed_counts": { "calories": 1450.0, "protein": 95.0, "carbs": 160.0, "fat": 40.0 },
  "macro_goals": null,
  "macro_consumed_percentage": null,
  "macro_score": null
}
```
If `macro_goals` is `null`, prompt the user to set goals with `PUT /nutrition/goal`.

---

### `POST /nutrition/create-meal`

Logs a meal. The meal is always saved under **today's date** (server time). You can't log a meal for a past day yet.

**Body**
| Field | Type | Required | Default |
|---|---|---|---|
| `meal_name` | string | yes | |
| `meal_type` | string | yes | e.g. `"breakfast"`, `"lunch"`, `"dinner"`, `"snack"` |
| `calories` | integer | no | `0` |
| `protein` | integer | no | `0` |
| `carbs` | integer | no | `0` |
| `fat` | integer | no | `0` |

```json
{
  "meal_name": "Chicken & rice",
  "meal_type": "lunch",
  "calories": 650,
  "protein": 45,
  "carbs": 70,
  "fat": 15
}
```

**Response `201`**
```json
{
  "meal_date": "2026-10-20",
  "created_at": "2026-10-20T17:22:05.551Z",
  "meal_name": "Chicken & rice",
  "meal_type": "lunch",
  "calories": 650,
  "protein": 45,
  "carbs": 70,
  "fat": 15
}
```

**Errors**
- `400` `"Could not add meal"`

---

### `PUT /nutrition/goal`

Creates the user's macro goals, or replaces the existing ones. Use the same call for both. Send all four fields.

**Body**
| Field | Type | Required | Rules |
|---|---|---|---|
| `calories_goal` | integer | yes | > 0 |
| `protein_goal` | integer | yes | > 0 |
| `carbs_goal` | integer | yes | > 0 |
| `fat_goal` | integer | yes | > 0 |

```json
{
  "calories_goal": 2200,
  "protein_goal": 150,
  "carbs_goal": 250,
  "fat_goal": 70
}
```

**Response `200`**
```json
{
  "protein_goal": 150,
  "carbs_goal": 250,
  "fat_goal": 70,
  "calories_goal": 2200
}
```

**Errors**
- `409` `"Could not add user goal"`
- `422`: a field is missing, or is `0` or negative.

---

## Sleep

### `POST /sleep/log`

Logs one night of sleep. The entry is stored under the **wake-up date**. If `bed_time` is later than `wake_time` (e.g. 23:30 → 07:00), the backend assumes the user went to bed the night before and calculates the duration to match.

There can only be **one sleep entry per user per day**. Logging the same `wake_date` twice returns `409`.

**Body**
| Field | Type | Required | Notes |
|---|---|---|---|
| `wake_date` | date `YYYY-MM-DD` | yes | the morning they woke up |
| `bed_time` | time `HH:MM` | yes | 24-hour clock |
| `wake_time` | time `HH:MM` | yes | 24-hour clock |
| `quality` | integer | yes | rating 1–5 (anything else returns `422`) |
| `notes` | string | yes | send `""` if the user wrote nothing |

```json
{
  "wake_date": "2026-10-20",
  "bed_time": "23:30",
  "wake_time": "07:15",
  "quality": 4,
  "notes": "Woke up once"
}
```

**Response `200`**
```json
{
  "sleep_date": "2026-10-20",
  "bed_time": "23:30:00",
  "wake_time": "07:15:00",
  "duration_mins": 465,
  "quality": 4,
  "notes": "Woke up once",
  "created_at": "2026-10-20T07:20:44.010Z"
}
```

**Errors**
- `409` `"Could not create sleep record"`: usually means that day already has an entry.
- `422`: a field is missing or `quality` is outside 1–5.

---

## Lifting

A workout goes through these calls in order:

```
POST /lifting/start-workout                      → gives you workout_id + exercise list
  └─ POST /lifting/{workout_id}/finish-exercise  → once per exercise the user completes
POST /lifting/{workout_id}/finish-workout        → ends the workout, returns summary screen data
PATCH /lifting/{workout_id}/submit-workout       → saves optional notes when the user taps Save
```

Keep the `workout_id` from `start-workout`. Every later call needs it in the URL.

---

### `POST /lifting/start-workout`

Starts the user's next workout day in their program and returns that day's exercises.

If a workout is **already in progress** (started but not finished), this returns that same workout instead of creating a new one, so double taps and app restarts are safe.

**Body:** none

**Response `201`**
```json
{
  "name": "Beginner Full Body",
  "description": "3-day full body program for new lifters",
  "goal": "strength",
  "workout_id": "0b9f6a3e-5c1d-4e2f-8a7b-9c0d1e2f3a4b",
  "lift_data": [
    {
      "exercise": "Barbell Squat",
      "exercise_id": "a1b2c3d4-0000-4000-8000-000000000001",
      "sets": 3,
      "reps": 8
    },
    {
      "exercise": "Bench Press",
      "exercise_id": "a1b2c3d4-0000-4000-8000-000000000002",
      "sets": 3,
      "reps": 10
    }
  ]
}
```
`sets` and `reps` are the program's **targets**. Use them to pre-fill the inputs.

**Errors**
- `404` `"No active programs for the user"`: the user has no program assigned.
- `409` `"Unable to create workout"`

---

### `POST /lifting/{workout_id}/finish-exercise`

Call when the user finishes an exercise. Send what they **actually did**, not the targets.

**Path:** `workout_id` from `start-workout`.

**Body**
| Field | Type | Required | Default | Rules |
|---|---|---|---|---|
| `exercise_id` | UUID | yes | | from `lift_data` |
| `sets` | integer | no | `0` | ≥ 0 |
| `reps` | integer | no | `0` | ≥ 0, reps **per set** |
| `weight` | number | no | `0` | ≥ 0 |

```json
{
  "exercise_id": "a1b2c3d4-0000-4000-8000-000000000001",
  "sets": 3,
  "reps": 8,
  "weight": 185
}
```

**Response `201`**
```json
{
  "workout_id": "0b9f6a3e-5c1d-4e2f-8a7b-9c0d1e2f3a4b",
  "exercise_id": "a1b2c3d4-0000-4000-8000-000000000001",
  "sets": 3,
  "reps": 8,
  "weight": 185.0
}
```

**Errors**
- `404` `"Could not find workout with that ID"`
- `409` `"There is not an active workout to record in"`: the workout was already finished.
- `409` `"Could not create set"`: usually an invalid `exercise_id`.

---

### `POST /lifting/{workout_id}/finish-workout`

Call when the user taps **Finish Workout**. This ends the workout and returns the data for the summary screen. **It can only be called once per workout.** A second call returns `409`.

**Path:** `workout_id`
**Body:** none

**Response `200`**
```json
{
  "workout_name": "Beginner Full Body",
  "workout_day": 2,
  "total_days": 3,
  "duration": 47.5,
  "number_exercises": 4,
  "number_sets": 12,
  "total_volume": 14820.0,
  "best_exercise": {
    "exercise_name": "Barbell Squat",
    "sets": 3,
    "reps": 8,
    "weight": 185.0
  }
}
```
| Field | Meaning |
|---|---|
| `workout_day` / `total_days` | e.g. "Day 2 of 3" |
| `duration` | minutes, rounded to 1 decimal |
| `number_exercises` | distinct exercises logged |
| `number_sets` | total sets across all exercises |
| `total_volume` | sum of `weight × reps × sets` |
| `best_exercise` | the exercise logged with the highest weight; `null` if nothing was logged |

**Errors**
- `404` `"Workout does not exist"`
- `404` `"Program for this workout not found"`
- `409` `"Workout is not active"`: already finished.

---

### `PATCH /lifting/{workout_id}/submit-workout`

Call when the user taps **Save** on the summary screen. Saves the optional notes. Call it after `finish-workout`.

**Path:** `workout_id`

**Body**
| Field | Type | Required |
|---|---|---|
| `notes` | string or null | no |

```json
{ "notes": "Felt strong today, up 10 lbs on squat" }
```
With no notes, send `{}` or `{ "notes": null }`. The body itself is still required.

**Response `200`**
```json
{ "data": "success" }
```

**Errors**
- `404` `"Workout not found"`
- `409` `"Can not save a non-finished workout"`: call `finish-workout` first.

---

### `POST /lifting/generate-program`

Takes the answers from the create-program survey and returns the **3 programs that best match** them, best match first.

This only **suggests** programs. It does not assign one to the user, so `start-workout` will still return `404` until the user picks one with [`choose-program`](#post-liftingprogram_idchoose-program).

**How matching works**
1. The checked `equipment` is turned into an equipment level: `bodyweight`, `home` or `gym`.
2. Only programs the user can actually do are considered: equipment level and difficulty at or below the user's, and `number_of_days` ≤ `days_available`.
3. Each of those programs gets a 0–100 score. Goal is weighted most (55), then experience (25), days (12) and equipment (8). A program that matches exactly on all four scores 100.

**Body**
| Field | Type | Required | Allowed values |
|---|---|---|---|
| `goal` | string | yes | `"build_muscle"`, `"get_stronger"`, `"lose_fat"`, `"general_fitness"` |
| `experience` | string | yes | `"beginner"`, `"intermediate"`, `"expert"` |
| `days_available` | integer | yes | 2–6 (days per week) |
| `equipment` | array of strings | yes | any of `"machine"`, `"barbell"`, `"exercise ball"`, `"e-z curl bar"`, `"medicine ball"`, `"dumbbell"`, `"bands"`, `"foam roll"`, `"kettlebells"`, `"cable"` |

- Values are case-sensitive and must be spelled exactly as above (including spaces, e.g. `"e-z curl bar"`). Anything else returns `422`.
- `equipment` is every item the user checked. Send `[]` if they checked nothing; they'll get bodyweight programs. The field itself must still be sent.

```json
{
  "goal": "build_muscle",
  "experience": "intermediate",
  "days_available": 4,
  "equipment": ["dumbbell", "kettlebells", "barbell", "cable", "machine", "bands"]
}
```

**Response `200`**
```json
{
  "programs": [
    {
      "program_id": "3c7e9a10-2b4d-4f6e-8a1c-5d2e7f9b0a11",
      "name": "Gym Build Muscle - 4-Day Upper/Lower",
      "description": "Moderate reps and steady volume to build muscle. An intermediate 4-day upper/lower program using a full gym, run for 10 weeks.",
      "difficulty": "intermediate",
      "number_of_days": 4,
      "goal": "build_muscle",
      "program_length": 10,
      "equipment_level": "gym",
      "split": "upper_lower",
      "score": 100.0
    },
    { "...": "2nd best match, same shape" },
    { "...": "3rd best match, same shape" }
  ]
}
```
| Field | Meaning |
|---|---|
| `programs` | up to 3 programs, sorted by `score` highest first. Can be fewer than 3 if not enough programs qualify |
| `program_id` | send this to `choose-program` when the user picks the program |
| `difficulty` | `"beginner"`, `"intermediate"` or `"expert"` |
| `number_of_days` | workout days per week |
| `goal` | same values as the request's `goal` |
| `program_length` | length in weeks; can be `null` |
| `equipment_level` | `"bodyweight"`, `"home"` or `"gym"` |
| `split` | `"full_body"`, `"upper_lower"`, `"push_pull_legs"` or `"hybrid"` |
| `score` | match score 0–100, rounded to a whole number (comes back as e.g. `87.0`, so read it as `num`/`double`) |

**Errors**
- `404` `"Program does not exist"`: no program fits the user's equipment, experience and days.
- `422`: a field is missing, `days_available` is outside 2–6, or a value isn't one of the allowed options.

---

### `POST /lifting/{program_id}/choose-program`

Call when the user picks one of the programs from `generate-program`. This assigns that program to the user, so `start-workout` starts working afterwards.

A user can only have **one program at a time**. Choosing a new program replaces the old one, and the user starts again from day 1 of the new program.

**Path:** `program_id` from one of the programs returned by `generate-program`.
**Body:** none. Don't send the program details; the backend looks them up from `program_id`.

```
POST /lifting/3c7e9a10-2b4d-4f6e-8a1c-5d2e7f9b0a11/choose-program
```

```dart
final res = await apiPost('/lifting/${program['program_id']}/choose-program', {});
if (res.statusCode == 201) {
  // program saved: go to the lifting home / start-workout screen
}
```

**Response `201`**
```json
{ "status": "success" }
```

**Errors**
- `404` `"Program not found"`: no program has that ID. The user's current program is left unchanged.
- `409` `"Could not save program"`
- `422`: `program_id` in the URL isn't a valid UUID.
