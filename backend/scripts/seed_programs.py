#builds our library of premade workout programs from the exercises table so we dont have to write them by hand
#run from backend/: python scripts/seed_programs.py            -> writes programs to the db + regenerates the preview
#                   python scripts/seed_programs.py --dry-run  -> only writes data-eval/programs_preview.md for review
#safe to rerun-- programs are matched by name and their exercises get replaced
import argparse
import sys
from dataclasses import dataclass
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1])) #lets us import app.* when run as a script

from sqlalchemy import select, delete
from app.database import SessionLocal
from app.models import Exercise, Program, Program_Exercise

PREVIEW_PATH = Path(__file__).resolve().parents[1] / 'data-eval' / 'programs_preview.md'

#********* Equipment / level rules ****************

#each level includes everything from the level before it-- exercises with null/other/foam roll equipment are left out since we cant tell what they need
BODYWEIGHT_EQUIPMENT = {'body only', 'bands'}
HOME_EQUIPMENT = BODYWEIGHT_EQUIPMENT | {'dumbbell', 'kettlebells', 'medicine ball', 'exercise ball'}
GYM_EQUIPMENT = HOME_EQUIPMENT | {'barbell', 'cable', 'machine', 'e-z curl bar'}
EQUIPMENT_LEVELS = {'bodyweight': BODYWEIGHT_EQUIPMENT, 'home': HOME_EQUIPMENT, 'gym': GYM_EQUIPMENT}

#exercises the dataset left with null equipment that are clearly bodyweight-- only used here, the db is not changed
EQUIPMENT_OVERRIDES = {'Inverted Row': 'body only', 'Bodyweight Walking Lunge': 'body only', 'Mountain Climbers': 'body only'}

LEVEL_RANK = {'beginner': 0, 'intermediate': 1, 'expert': 2}
#(max level for curated picks, max level for fallback picks)-- curated names are vetted so beginners can use a few lifts the dataset calls intermediate (ex: Romanian Deadlift)
EXPERIENCE_LEVEL_CAPS = {'beginner': (1, 0), 'intermediate': (1, 1), 'expert': (2, 2)}

#********* Slots ****************

@dataclass(frozen=True)
class Slot:
    muscles: tuple[str, ...] #primary muscles the fallback can pick from
    mechanic: str | None #compound/isolation filter for the fallback-- None means either
    preferred: tuple[str, ...] #best first-- the equipment level filters these so gym gets barbell lifts and bodyweight gets pushups etc
    categories: tuple[str, ...] = ('strength', 'powerlifting')

SLOTS = {
    'squat': Slot(('quadriceps',), 'compound', ('Barbell Squat', 'Front Squat (Clean Grip)', 'Leg Press', 'Hack Squat', 'Goblet Squat', 'Dumbbell Squat', 'Front Squats With Two Kettlebells', 'Squats - With Bands', 'Bodyweight Squat')),
    'lunge': Slot(('quadriceps', 'glutes'), 'compound', ('Barbell Walking Lunge', 'Split Squat with Dumbbells', 'Dumbbell Lunges', 'Dumbbell Step Ups', 'Bodyweight Walking Lunge', 'Step-up with Knee Raise')),
    'hinge': Slot(('hamstrings', 'glutes', 'lower back'), 'compound', ('Barbell Deadlift', 'Romanian Deadlift', 'Stiff-Legged Dumbbell Deadlift', 'Kettlebell One-Legged Deadlift', 'One-Arm Kettlebell Swings', 'Band Good Morning', 'Single Leg Glute Bridge', 'Butt Lift (Bridge)')),
    'hip_accessory': Slot(('hamstrings', 'glutes'), None, ('Barbell Hip Thrust', 'Lying Leg Curls', 'Seated Leg Curl', 'Romanian Deadlift', 'Stiff-Legged Dumbbell Deadlift', 'Ball Leg Curl', 'Hip Lift with Band', 'Single Leg Glute Bridge', 'Butt Lift (Bridge)')),
    'calves': Slot(('calves',), None, ('Standing Calf Raises', 'Seated Calf Raise', 'Standing Dumbbell Calf Raise', 'Calf Raises - With Bands')),
    'horizontal_push': Slot(('chest',), 'compound', ('Barbell Bench Press - Medium Grip', 'Dumbbell Bench Press', 'Machine Bench Press', 'One-Arm Kettlebell Floor Press', 'Pushups', 'Push-Ups With Feet Elevated', 'Bench Press - With Bands')),
    'incline_push': Slot(('chest',), None, ('Barbell Incline Bench Press - Medium Grip', 'Incline Dumbbell Press', 'Dumbbell Flyes', 'Cable Crossover', 'Cross Over - With Bands', 'Push-Ups With Feet Elevated', 'Incline Push-Up')),
    'vertical_push': Slot(('shoulders',), 'compound', ('Standing Military Press', 'Seated Dumbbell Press', 'Dumbbell Shoulder Press', 'Two-Arm Kettlebell Military Press', 'Shoulder Press - With Bands', 'Handstand Push-Ups')),
    'vertical_pull': Slot(('lats',), 'compound', ('Wide-Grip Lat Pulldown', 'Pullups', 'Close-Grip Front Lat Pulldown', 'Chin-Up')),
    'row': Slot(('middle back', 'lats'), 'compound', ('Bent Over Barbell Row', 'Seated Cable Rows', 'One-Arm Dumbbell Row', 'Bent Over Two-Dumbbell Row', 'One-Arm Kettlebell Row', 'Inverted Row')),
    'lateral_raise': Slot(('shoulders',), 'isolation', ('Side Lateral Raise', 'Cable Seated Lateral Raise', 'Lateral Raise - With Bands')),
    'rear_delt': Slot(('shoulders',), None, ('Face Pull', 'Reverse Flyes', 'Band Pull Apart', 'Cable Rear Delt Fly', 'Back Flyes - With Bands')),
    'biceps': Slot(('biceps',), 'isolation', ('Barbell Curl', 'Dumbbell Bicep Curl', 'Hammer Curls', 'EZ-Bar Curl', 'Standing Biceps Cable Curl', 'Chin-Up')),
    'triceps': Slot(('triceps',), None, ('Triceps Pushdown - Rope Attachment', 'EZ-Bar Skullcrusher', 'Close-Grip Barbell Bench Press', 'Standing Dumbbell Triceps Extension', 'Tricep Dumbbell Kickback', 'Band Skull Crusher', 'Bench Dips', 'Dips - Triceps Version')),
    'core': Slot(('abdominals',), None, ('Cable Crunch', 'Hanging Leg Raise', 'Plank', 'Dead Bug', 'Reverse Crunch', 'Crunches')),
    'core_rotation': Slot(('abdominals',), None, ('Pallof Press', 'Russian Twist', 'Exercise Ball Crunch', 'Bent-Knee Hip Raise', 'Side Bridge', 'Cross-Body Crunch')),
    'finisher': Slot(('quadriceps', 'hamstrings', 'lats', 'chest', 'abdominals'), None, ('Mountain Climbers', 'One-Arm Kettlebell Swings', 'Overhead Slam', 'Knee Tuck Jump', 'Split Jump', 'Star Jump', 'Freehand Jump Squat'), ('plyometrics',)),
}

#********* Day templates ****************
#(slot, role)-- main lifts go first and get the heavier set/rep scheme

MAIN, ACC = 'main', 'accessory'
DAY_TEMPLATES = {
    'Full Body A': [('squat', MAIN), ('horizontal_push', MAIN), ('row', MAIN), ('hip_accessory', ACC), ('lateral_raise', ACC), ('core', ACC)],
    'Full Body B': [('hinge', MAIN), ('vertical_push', MAIN), ('vertical_pull', MAIN), ('lunge', ACC), ('triceps', ACC), ('core_rotation', ACC)],
    'Upper A': [('horizontal_push', MAIN), ('row', MAIN), ('vertical_push', ACC), ('vertical_pull', ACC), ('triceps', ACC), ('biceps', ACC)],
    'Upper B': [('vertical_push', MAIN), ('vertical_pull', MAIN), ('incline_push', ACC), ('row', ACC), ('lateral_raise', ACC), ('rear_delt', ACC)],
    'Lower A': [('squat', MAIN), ('hip_accessory', ACC), ('lunge', ACC), ('calves', ACC), ('core', ACC)],
    'Lower B': [('hinge', MAIN), ('squat', ACC), ('hip_accessory', ACC), ('calves', ACC), ('core_rotation', ACC)],
    'Push': [('horizontal_push', MAIN), ('vertical_push', MAIN), ('incline_push', ACC), ('lateral_raise', ACC), ('triceps', ACC), ('triceps', ACC)],
    'Pull': [('vertical_pull', MAIN), ('row', MAIN), ('row', ACC), ('rear_delt', ACC), ('biceps', ACC), ('biceps', ACC)],
    'Legs': [('squat', MAIN), ('hinge', ACC), ('lunge', ACC), ('calves', ACC), ('core', ACC)],
}

#(split, day templates in order)
WEEKS = {
    'full_body_2': ('full_body', ['Full Body A', 'Full Body B']),
    'full_body_3': ('full_body', ['Full Body A', 'Full Body B', 'Full Body A']),
    'upper_lower_4': ('upper_lower', ['Upper A', 'Lower A', 'Upper B', 'Lower B']),
    'hybrid_5_gym': ('hybrid', ['Push', 'Pull', 'Legs', 'Upper B', 'Lower B']),
    'hybrid_5_home': ('hybrid', ['Upper A', 'Lower A', 'Full Body B', 'Upper B', 'Lower B']),
    'ppl_6': ('push_pull_legs', ['Push', 'Pull', 'Legs', 'Push', 'Pull', 'Legs']),
}
SPLIT_LABELS = {'full_body': 'Full Body', 'upper_lower': 'Upper/Lower', 'hybrid': 'Hybrid Split', 'push_pull_legs': 'Push/Pull/Legs'}

#********* Goals ****************

#(sets, reps) per role
GOAL_SCHEMES = {
    'get_stronger': {MAIN: (5, 5), ACC: (3, 8)},
    'build_muscle': {MAIN: (4, 8), ACC: (3, 12)},
    'lose_fat': {MAIN: (3, 12), ACC: (3, 15)},
    'general_fitness': {MAIN: (3, 10), ACC: (2, 12)},
}
FINISHER_GOALS = {'lose_fat', 'general_fitness'} #these get a plyo finisher at the end of each day
FINISHER_SCHEME = (3, 20)
STATIC_HOLD_SECONDS = 30 #for static holds like Plank the reps value means seconds
MAX_MAIN_SETS = 5
GOAL_LABELS = {'get_stronger': 'Get Stronger', 'build_muscle': 'Build Muscle', 'lose_fat': 'Lose Fat', 'general_fitness': 'General Fitness'}
GOAL_BLURBS = {
    'get_stronger': 'Heavy, low-rep main lifts to build strength',
    'build_muscle': 'Moderate reps and steady volume to build muscle',
    'lose_fat': 'Higher reps and a conditioning finisher each day to burn more calories',
    'general_fitness': 'A balanced mix of strength work and conditioning',
}
LEVEL_LABELS = {'bodyweight': 'Bodyweight', 'home': 'Home', 'gym': 'Gym'}
EQUIPMENT_BLURBS = {'bodyweight': 'only your bodyweight, bands and a pull-up bar', 'home': 'dumbbells, kettlebells and other home equipment', 'gym': 'a full gym'}

#********* Program list ****************

@dataclass
class ProgramSpec:
    goal: str
    equipment_level: str
    difficulty: str
    week: str
    program_length: int

def build_specs() -> list[ProgramSpec]:
    specs = []
    for goal in GOAL_SCHEMES:
        for level in EQUIPMENT_LEVELS:
            specs.append(ProgramSpec(goal, level, 'beginner', 'full_body_3', 8))
            specs.append(ProgramSpec(goal, level, 'intermediate', 'upper_lower_4', 10))
            specs.append(ProgramSpec(goal, level, 'expert', 'hybrid_5_gym' if level == 'gym' else 'hybrid_5_home', 12))
            if goal in ('general_fitness', 'lose_fat'):
                specs.append(ProgramSpec(goal, level, 'beginner', 'full_body_2', 8)) #covers users who only have 2 days
    for goal in ('build_muscle', 'get_stronger'):
        specs.append(ProgramSpec(goal, 'gym', 'expert', 'ppl_6', 12)) #covers users who have 6 days
    return specs

#********* Exercise picking ****************

def equipment_of(ex: Exercise) -> str | None:
    return EQUIPMENT_OVERRIDES.get(ex.name, ex.equipment)

def candidates(slot: Slot, spec: ProgramSpec, exercises: list[Exercise], by_name: dict[str, Exercise]) -> tuple[list[Exercise], list[Exercise]]:
    #(curated picks, deterministic fallback by name from the same muscles)
    allowed_equipment = EQUIPMENT_LEVELS[spec.equipment_level]
    curated_cap, fallback_cap = EXPERIENCE_LEVEL_CAPS[spec.difficulty]
    curated = [by_name[n] for n in slot.preferred if n in by_name]
    curated = [ex for ex in curated if equipment_of(ex) in allowed_equipment and LEVEL_RANK[ex.level] <= curated_cap]
    fallback = [ex for ex in exercises
                if ex.primary_muscle in slot.muscles and ex.exercise_category in slot.categories
                and (slot.mechanic is None or ex.mechanic == slot.mechanic)
                and equipment_of(ex) in allowed_equipment and LEVEL_RANK[ex.level] <= fallback_cap and ex not in curated]
    return curated, sorted(fallback, key=lambda ex: ex.name)

def build_days(spec: ProgramSpec, exercises: list[Exercise], by_name: dict[str, Exercise]) -> list[tuple[str, list[tuple[Exercise, int, int]]]]:
    split, templates = WEEKS[spec.week]
    scheme = GOAL_SCHEMES[spec.goal]
    filled = {} #template name -> picks, so repeated templates (Full Body A twice) get the same exercises
    used_in_program = set()
    days = []
    for template in templates:
        if template not in filled:
            picks = []
            used_today = set()
            slots = DAY_TEMPLATES[template] + ([('finisher', 'finisher')] if spec.goal in FINISHER_GOALS else [])
            for slot_name, role in slots:
                curated, fallback = (
                    [ex for ex in group if ex.id not in used_today] for group in candidates(SLOTS[slot_name], spec, exercises, by_name))
                #prefer a curated pick not used on another day, then reuse a curated pick, and only then fall back
                ordered = ([ex for ex in curated if ex.id not in used_in_program] + curated
                           + [ex for ex in fallback if ex.id not in used_in_program] + fallback)
                if not ordered:
                    print(f'  warning: no {slot_name} exercise for {program_name(spec)} ({template})-- skipping slot')
                    continue
                ex = ordered[0]
                if role == 'finisher':
                    sets, reps = FINISHER_SCHEME
                else:
                    sets, reps = scheme[role]
                    if role == MAIN and spec.difficulty == 'expert':
                        sets = min(sets + 1, MAX_MAIN_SETS) #experienced lifters get an extra set on main lifts
                if ex.movement_type == 'static':
                    reps = STATIC_HOLD_SECONDS
                picks.append((ex, sets, reps))
                used_today.add(ex.id)
            used_in_program |= used_today
            filled[template] = picks
        days.append((template, filled[template]))
    return days

def program_name(spec: ProgramSpec) -> str:
    split, templates = WEEKS[spec.week]
    return f'{LEVEL_LABELS[spec.equipment_level]} {GOAL_LABELS[spec.goal]} - {len(templates)}-Day {SPLIT_LABELS[split]}'

def program_description(spec: ProgramSpec) -> str:
    split, templates = WEEKS[spec.week]
    article = 'An' if spec.difficulty[0] in 'aeiou' else 'A'
    return (f'{GOAL_BLURBS[spec.goal]}. {article} {spec.difficulty} {len(templates)}-day {SPLIT_LABELS[split].lower()} program '
            f'using {EQUIPMENT_BLURBS[spec.equipment_level]}, run for {spec.program_length} weeks.')

#********* Output ****************

def write_preview(built: list[tuple[ProgramSpec, list]]):
    lines = ['# Program preview', '', f'Generated by `scripts/seed_programs.py`-- {len(built)} programs. For static holds (ex: Plank) reps means seconds.', '']
    for spec, days in built:
        split, _ = WEEKS[spec.week]
        lines += [f'## {program_name(spec)}', '', f'goal: `{spec.goal}` | difficulty: `{spec.difficulty}` | equipment: `{spec.equipment_level}` | split: `{split}` | {spec.program_length} weeks', '',
                  program_description(spec), '']
        for day_num, (template, picks) in enumerate(days, start=1):
            lines += [f'**Day {day_num} - {template}**', '', '| # | Exercise | Sets x Reps | Equipment | Level |', '|---|---|---|---|---|']
            for order, (ex, sets, reps) in enumerate(picks, start=1):
                lines.append(f'| {order} | {ex.name} | {sets} x {reps} | {equipment_of(ex)} | {ex.level} |')
            lines.append('')
    PREVIEW_PATH.write_text('\n'.join(lines), encoding='utf-8')
    print(f'wrote preview to {PREVIEW_PATH}')

def save_program(db, spec: ProgramSpec, days: list):
    split, templates = WEEKS[spec.week]
    fields = dict(description=program_description(spec), difficulty=spec.difficulty, number_of_days=len(templates), goal=spec.goal,
                  program_length=spec.program_length, equipment_level=spec.equipment_level, split=split)
    name = program_name(spec)
    program = db.execute(select(Program).where(Program.name == name)).scalar_one_or_none()
    if program is None:
        program = Program(name=name, **fields)
        db.add(program)
        db.flush() #gives us the program id
    else:
        for key, value in fields.items():
            setattr(program, key, value)
        db.execute(delete(Program_Exercise).where(Program_Exercise.program_id == program.id)) #replace the old exercises
    for day_num, (_, picks) in enumerate(days, start=1):
        for order, (ex, sets, reps) in enumerate(picks, start=1):
            db.add(Program_Exercise(program_id=program.id, exercise_id=ex.id, day=day_num, sets=sets, reps=reps, order=order))

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--dry-run', action='store_true', help='only write the preview file, dont touch the db')
    args = parser.parse_args()

    db = SessionLocal()
    try:
        exercises = list(db.execute(select(Exercise).order_by(Exercise.name)).scalars())
        by_name = {ex.name: ex for ex in exercises}
        missing = sorted({n for slot in SLOTS.values() for n in slot.preferred if n not in by_name})
        if missing:
            print(f'  warning: preferred exercises not in the db: {missing}')

        built = [(spec, build_days(spec, exercises, by_name)) for spec in build_specs()]
        write_preview(built)
        if args.dry_run:
            return
        for spec, days in built:
            save_program(db, spec, days)
        db.commit()
        print(f'saved {len(built)} programs')
    finally:
        db.close()

if __name__ == '__main__':
    main()
