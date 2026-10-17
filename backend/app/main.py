from datetime import date, time, datetime, timedelta
from uuid import UUID

from app.auth_dependency import get_curr_user
from fastapi import FastAPI, Depends, Request, Response, HTTPException, status
from app.config import settings
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError
from sqlalchemy import select
from app.schemas import User_Signup_In, User_Signup_Out, User_Login_Out, User_Profile_Survey, Nutrition_Summary_Out, Create_Meal_Out, Create_Meal_In, Create_Nutrition_Goal_In, Create_Nutrition_Goal_Out, Log_Sleep_In, Log_Sleep_Out,Start_Workout_Out ,Exercise_Data_In,Exercise_Data_Out
from app.database import get_db #dependency for db operations(creates a session) and gives us user id from token payload
from app.models import User, Meal, User_Goal_Nutrition, Sleep, Workout, Exercise, Program_Exercise, Program, User_Program, Workout_Set
from app.helper_funcs import get_nutrition_stats


app = FastAPI()

@app.get('/')
def test():
    return {'msg': "Success"}

#************************ Signup / Login / Onboarding *****************************

#signup route-- creates a User in the DB with id from jwt and username they entered in the form
@app.post('/users/signup', response_model=User_Signup_Out, status_code=status.HTTP_201_CREATED)
def signup(body: User_Signup_In, db: Session = Depends(get_db), user_id: UUID = Depends(get_curr_user)):
    if db.scalars(select(User).where(User.id == user_id)).first():
        raise HTTPException(status_code = status.HTTP_409_CONFLICT, detail="User already exists in the database")
    user = User(id=user_id, username=body.username) #creating user obj
    db.add(user)
    try:
        db.commit()
    except IntegrityError:
        db.rollback() #sets the Session back for next db connection
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Username is already in use") #db rejects the username b/c not unique
    db.refresh(user) #get finalized user to return
    return user
#login route-- returns the user info if its in the db so frontend can move to dashboard
@app.get('/users/me', response_model=User_Login_Out, status_code=status.HTTP_200_OK)
def get_profile(user_id:UUID = Depends(get_curr_user), db: Session = Depends(get_db)):
    user = db.scalar(select(User).where(User.id == user_id))
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return user

#profile onboarding survey results
@app.post('/users/welcome-survey', response_model=User_Login_Out)
def onboardSurvey(body: User_Profile_Survey, db: Session= Depends(get_db), user_id: UUID = Depends(get_curr_user)):
    user = db.scalar(select(User).where(User.id == user_id))
    if not user: 
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    user.current_weight = body.current_weight
    user.goal_weight = body.goal_weight
    user.workouts_per_week_goal = body.workouts_per_week_goal
    user.sleep_goal = body.sleep_goal
    user.height = body.height
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Does not follow database constraints")

    db.refresh(user)
    return user

# *********************** Nutrition Section ******************************

#Nutrition summary page by day from our calender switch buttons
#pass in date as a query parameter to this route from frontend
@app.get('/nutrition/summary', response_model=Nutrition_Summary_Out)
def get_nutrition_summary(day:date, user_id: UUID = Depends(get_curr_user), db: Session=Depends(get_db)):
    user_goals = db.scalar(select(User_Goal_Nutrition).where(User_Goal_Nutrition.user_id==user_id))
    all_meals_day = db.scalars(select(Meal).where(Meal.user_id==user_id, Meal.meal_date==day).order_by(Meal.created_at)).all() #grabs all meals for the chosen day
    ##Get total count for each macro from the meals eaten that day
    macros={'calories':sum(meal.calories for meal in all_meals_day), 
            'protein':sum(meal.protein for meal in all_meals_day), 
            'carbs':sum(meal.carbs for meal in all_meals_day), 
            'fats':sum(meal.fat for meal in all_meals_day)}
    #nothing to display in this case
    if user_goals is None:
        return {
            "date": day,
            "macros_consumed_counts": macros,
            "macro_goals": None,
            "macro_consumed_percentage": None,
            "macro_score": None,
        }
    ##Get goal of each macro
    macro_goals = {'calories':user_goals.calories_goal, 'protein':user_goals.protein_goal,'carbs':user_goals.carbs_goal,'fats':user_goals.fat_goal}
    ##Get progress made on goal based on what was done for each macro
    macro_progress_percent = {'calories':get_nutrition_stats(macros['calories'],user_goals.calories_goal), 
                      'protein':get_nutrition_stats(macros['protein'], user_goals.protein_goal), 
                      'carbs':get_nutrition_stats(macros['carbs'],user_goals.carbs_goal), 
                      'fats':get_nutrition_stats(macros['fats'],user_goals.fat_goal)}
    total_progress_percent = (sum(macro_progress_percent.values())/len(macro_progress_percent)) #computes score as percentage for all macros
    return_data = {
        'date': day,
        'macros_consumed_counts': macros,
        'macro_goals_counts': macro_goals,
        'macro_consumed_percentage': macro_progress_percent,
        'macro_score': total_progress_percent
    }
    return return_data

#endpoint to add a meal from user
@app.post('/nutrition/create-meal', response_model=Create_Meal_Out, status_code=status.HTTP_201_CREATED)
def create_meal(body: Create_Meal_In, user_id: UUID = Depends(get_curr_user), db: Session = Depends(get_db)):
    meal = Meal(meal_name=body.meal_name, protein=body.protein, carbs=body.carbs, calories=body.calories, fat=body.fats, meal_type=body.meal_type, meal_date=date.today(),user_id=user_id)
    try:
        db.add(meal)
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Could not add meal")
    db.refresh(meal)
    return meal
#endpoint to create nutrition goals-- PUT so it just adds whatever is there, checks if alr an entry first to update
@app.put('/nutrition/goal', response_model=Create_Nutrition_Goal_Out, status_code=status.HTTP_200_OK)
def nutrition_goal(body: Create_Nutrition_Goal_In, user_id: UUID = Depends(get_curr_user), db: Session = Depends(get_db)):
    nutrition_goal = db.scalar(select(User_Goal_Nutrition).where(User_Goal_Nutrition.user_id == user_id))
    #not previous entry, so we create a db entry using request body data
    if not nutrition_goal:
        nutrition_goal = User_Goal_Nutrition(protein_goal=body.protein_goal,carbs_goal=body.carbs_goal,fat_goal=body.fat_goal,calories_goal=body.calories_goal,user_id=user_id)
        try:
            db.add(nutrition_goal)
            db.commit()
        except IntegrityError:
            db.rollback()
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Could not add user goal")
    else:
        nutrition_goal.calories_goal = body.calories_goal
        nutrition_goal.carbs_goal = body.carbs_goal
        nutrition_goal.fat_goal = body.fat_goal
        nutrition_goal.protein_goal = body.protein_goal
        db.commit()
    db.refresh(nutrition_goal)
    return nutrition_goal

#********************************* Health Section ****************************

#endpoint to log sleep data for a given night
@app.post('/sleep/log', response_model=Log_Sleep_Out)
def log_sleep(body: Log_Sleep_In, user_id: UUID = Depends(get_curr_user), db: Session = Depends(get_db)):
    start_date_time = datetime.combine(body.wake_date, body.bed_time) #turns into datetime to get duration
    end_date_time = datetime.combine(body.wake_date, body.wake_time) #turns time into datetime to get duration
    #went to bed past midnight so the time is technically less than the end on the same day
    if start_date_time >= end_date_time:
        start_date_time -= timedelta(days=1) #moves back 1 day so the end is always bigger because cant sleep before u wake up
    duration_mins = int((end_date_time-start_date_time).total_seconds()//60)
    sleep_log = Sleep(user_id=user_id, sleep_date=body.wake_date, bed_time=body.bed_time, wake_time=body.wake_time, duration_mins=duration_mins, quality=body.quality, notes=body.notes)
    try:
        db.add(sleep_log)
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Could not create sleep record")
    db.refresh(sleep_log)
    return sleep_log

#********************************* Fitness Section ****************************

#start-workout endpoint
@app.post('/lifting/start-workout', response_model=Start_Workout_Out, status_code=status.HTTP_201_CREATED)
def start_workout(user_id: UUID = Depends(get_curr_user), db: Session = Depends(get_db)):
    result_obj = {} #store the result in here
    user_program = db.scalar(select(User_Program).where(User_Program.user_id==user_id))
    if user_program is None: raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail='No active programs for the user')
    program = db.scalar(select(Program).where(Program.id==user_program.program_id))
    if program is None: raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail='No active programs for the user')
    #check if there is an active workout before creating another-- tests for double clicks
    workout = db.scalar(select(Workout).where(Workout.user_id==user_id, Workout.completed_at.is_(None)))
    if workout is None: 
        workout = Workout(user_id=user_id, program_id=program.id)
        if user_program.current_day >= program.number_of_days: user_program.current_day = 1
        else: user_program.current_day += 1

    result_obj['name'], result_obj['description'], result_obj['goal'],result_obj['lift_data'] = program.name, program.description, program.goal,[]

    try:
        db.add(workout)
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail='Unable to create workout')
    #getting all the exercises/sets/reps from the db for the day and program id
    all_exercises = db.execute(select(Program_Exercise,Exercise)
                               .join(Exercise, Program_Exercise.exercise_id==Exercise.id)
                               .where(Program_Exercise.program_id==program.id, Program_Exercise.day==user_program.current_day)).all()
    for program_exercise, exercise in all_exercises:
        curr_exercise = {} #build this and append to lift_data each time-- stores {exercise, exercise_id, sets, reps}
        curr_exercise['exercise'], curr_exercise['exercise_id'], curr_exercise['sets'], curr_exercise['reps'] = exercise.name,exercise.id,program_exercise.sets,program_exercise.reps
        result_obj['lift_data'].append(curr_exercise)
    db.refresh(workout)
    result_obj['workout_id'] = workout.id
    return result_obj

#Endpoint for when a user completes an exercise-- sends the sets/reps/weight they used. 
# NOTE: Might change this so they send data after every set they complete
@app.post('/lifting/{workout_id}/finish-exercise', response_model=Exercise_Data_Out)
def finish_exercise(body: Exercise_Data_In,workout_id: UUID, user_id: UUID = Depends(get_curr_user), db: Session = Depends(get_db)):
    current_workout = db.scalar(select(Workout).where(Workout.id==workout_id, Workout.user_id==user_id)) #checking to see if there is an active workout
    if current_workout is None: raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail='Could not find workout with that ID')
    if current_workout.completed_at is not None: raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail='There is not an active workout to record in')
    workout_set = Workout_Set(workout_id=body.workout_id,exercise_id=body.exercise_id,reps=body.reps,sets=body.sets,weight=body.weight) #create the set
    try:
        db.add(workout_set)
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail='Could not create set')
    db.refresh(workout_set)
    return workout_set



    
    

