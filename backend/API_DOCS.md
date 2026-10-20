# HealthCore API Reference

Reference for the frontend: every backend endpoint, what to send, and what comes back.

> Tip: while the backend is running, FastAPI also serves interactive docs at `http://<host>:8000/docs`, where you can try requests in the browser.

---

## Basics

### Authentication

Every endpoint except `GET /` needs the Supabase access token of the signed-in user:

```
Authorization: Bearer <supabase_access_token>
```

The backend reads the user's ID from the token, so **you never send a `user_id` in a request body**.

| Problem | Status |
|---|---|
| Header missing | `403` (or `401`, depending on the FastAPI version) |
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
  "macros_consumed_counts": { "calories": 1450, "protein": 95, "carbs": 160, "fat": 40 },
  "macro_goals":            { "calories": 2200, "protein": 150, "carbs": 250, "fat": 70 },
  "macro_consumed_percentage": { "calories": 65.9, "protein": 63.3, "carbs": 64.0, "fat": 57.1 },
  "macro_score": 62.6
}
```
- `macro_consumed_percentage` values are 0–100 and **capped at 100** (going over the goal still shows 100).
- `macro_score` is the average of the four percentages.

**Response `200`: user has not set goals yet**
```json
{
  "date": "2026-10-20",
  "macros_consumed_counts": { "calories": 1450, "protein": 95, "carbs": 160, "fat": 40 },
  "macro_goals": null,
  "macro_consumed_percentage": null,
  "macro_score": null
}
```
If `macro_goals` is `null`, prompt the user to set goals with `PUT /nutrition/goal`.

> ⚠️ Currently broken on the backend (key-name mismatch). See "Known backend issues" below.

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

> ⚠️ Currently broken on the backend. See "Known backend issues" below.

---

### `PUT /nutrition/goal`

Creates the user's macro goals, or replaces the existing ones. Use the same call for both. Send all four fields.

**Body**
| Field | Type | Required | Rules |
|---|---|---|---|
| `calories_goal` | integer | yes | ≥ 0 |
| `protein_goal` | integer | yes | ≥ 0 |
| `carbs_goal` | integer | yes | ≥ 0 |
| `fat_goal` | integer | yes | ≥ 0 |

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
- `422`: a field is missing or negative.

> Don't allow a goal of `0` in the UI. A 0 goal currently crashes the summary endpoint.

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
| `quality` | integer | yes | rating 1–5 |
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

> ⚠️ Currently broken on the backend. See "Known backend issues" below.

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

## Known backend issues

These are backend bugs, listed so nobody wastes time debugging the frontend. The contract documented above is how the endpoints **will** behave once they're fixed.

| Endpoint | Symptom | Cause |
|---|---|---|
| `GET /nutrition/summary` | `500` | Builds the macros with the key `fats`, but the response schema expects `fat`. The goals are also built under `macro_goals_counts` instead of `macro_goals`. |
| `GET /nutrition/summary` | `500` if any goal is `0` | Divide by zero in the percentage calculation |
| `POST /nutrition/create-meal` | `500` | Reads `body.fats`, but the request field is `fat` |
| `POST /sleep/log` | `500` after the row is saved | Response schema has `quality: Field(le=1, ge=5)`, which is impossible (should be `ge=1, le=5`) |
