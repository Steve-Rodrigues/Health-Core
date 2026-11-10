from datetime import date, time, datetime, timedelta
from uuid import UUID

from app.auth_dependency import get_curr_user
from fastapi import FastAPI, Depends, Request, Response, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from app.config import settings
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError
from sqlalchemy import Date, cast, select, func, exists
from statistics import median
from app.schemas import User_Signup_In, User_Signup_Out, User_Login_Out, User_Profile_Survey, User_Goals_Update, Nutrition_Summary_Out, Create_Meal_Out, Create_Meal_In, Create_Nutrition_Goal_In, Create_Nutrition_Goal_Out, Log_Sleep_In, Log_Sleep_Out,Start_Workout_Out ,Exercise_Data_In,Exercise_Data_Out, Workout_Summary_Out, Finalize_Workout_In,Top_3_Programs_Out,Survey_Results_In, Program_In, My_Program_Out, Manually_Enter_Barcode_Food_In, Logging_Barcode_Food_Out, Log_Meal_In,Scan_Barcode_Food_Out,Send_Weekly_Lifts_Out,Newest_PRs
from app.database import get_db #dependency for db operations(creates a session) and gives us user id from token payload
from app.models import User, Meal, User_Goal_Nutrition, Sleep, Workout, Exercise, Program_Exercise, Program, User_Program, Workout_Set, Barcode_Cache, Personal_Record
from app.helper_funcs import get_nutrition_stats, get_equipment_level, score_program, Experience_Buckets, Equipment_Buckets, normalize_barcode, fetch_barcode, close_stale_workouts


app = FastAPI()

#allows the flutter web app (served from a different localhost port) to call the api because we are running over browser during testing
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"http://(localhost|127\.0\.0\.1)(:\d+)?",
    allow_methods=["*"],
    allow_headers=["*"],
)

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

#updating the user's personal goals 
@app.put('/users/update-goals', status_code=status.HTTP_200_OK)
def update_goals(body: User_Goals_Update, db: Session = Depends(get_db), user_id: UUID = Depends(get_curr_user)):
    user = db.scalar(select(User).where(User.id==user_id))
    if not user: raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    user.current_weight = body.current_weight
    user.goal_weight = body.goal_weight
    user.workouts_per_week_goal = body.workouts_per_week_goal
    user.sleep_goal = body.sleep_goal
    user.height = body.height
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Could not update")
    return {"status": "success"}
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
            'fat':sum(meal.fat for meal in all_meals_day)}
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
    macro_goals = {'calories':user_goals.calories_goal, 'protein':user_goals.protein_goal,'carbs':user_goals.carbs_goal,'fat':user_goals.fat_goal}
    ##Get progress made on goal based on what was done for each macro
    macro_progress_percent = {'calories':get_nutrition_stats(macros['calories'],user_goals.calories_goal), 
                      'protein':get_nutrition_stats(macros['protein'], user_goals.protein_goal), 
                      'carbs':get_nutrition_stats(macros['carbs'],user_goals.carbs_goal), 
                      'fat':get_nutrition_stats(macros['fat'],user_goals.fat_goal)}
    total_progress_percent = round(sum(macro_progress_percent.values())/len(macro_progress_percent), 1) #computes score as percentage for all macros
    return_data = {
        'date': day,
        'macros_consumed_counts': macros,
        'macro_goals': macro_goals,
        'macro_consumed_percentage': macro_progress_percent,
        'macro_score': total_progress_percent
    }
    return return_data

#endpoint to add a meal from user
@app.post('/nutrition/create-meal', response_model=Create_Meal_Out, status_code=status.HTTP_201_CREATED)
def create_meal(body: Create_Meal_In, user_id: UUID = Depends(get_curr_user), db: Session = Depends(get_db)):
    meal = Meal(meal_name=body.meal_name, protein=body.protein, carbs=body.carbs, calories=body.calories, fat=body.fat, meal_type=body.meal_type, meal_date=date.today(),user_id=user_id)
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

#****Barcode scanning section of nutrition ******

#endpoint to get information regarding a scanned barcode
#check if barcode in cache, if not go to the api and send back all of the recieved info along with a missing list of what was not found
@app.get('/nutrition/scan-food/{barcode}', response_model=Scan_Barcode_Food_Out)
def get_food_info_barcode(barcode:str, user_id: UUID = Depends(get_curr_user), db: Session = Depends(get_db)):
    barcode = normalize_barcode(barcode) #put barcode into our standard notation
    cached_barcode = db.scalar(select(Barcode_Cache).where(Barcode_Cache.barcode==barcode))
    processed_data = {'barcode':barcode,'name':None,'serving_size_grams':None,'calories_per_100':None,'fat_per_100':None,'carbs_per_100':None,'protein_per_100':None,'missing':[]}#object we send back to the client
    #grab from the api and store in both the db along with the return object
    if not cached_barcode:
        data = fetch_barcode(barcode) #gets the barcode using the api request
        product = data.get('product',{}) #everything we need is in the product nested dict
        #using the loop through and add-- the keys are the api keys and the values are the db cols and the return data obj keys
        api_db_matching = {'product_name':'name',
                           'serving_quantity':'serving_size_grams',
                           "carbohydrates_100g":'carbs_per_100',
                           "energy-kcal_100g":'calories_per_100',
                           "proteins_100g":'protein_per_100',
                           "fat_100g":'fat_per_100'}
        #go through and add to the return data object to then add to the db as well
        for k,v in api_db_matching.items():
            if '100' in k:
                curr_macro = product.get('nutriments',{}).get(k,-1) #macros are inside the nutriments dict
                if curr_macro != -1: processed_data[v] = curr_macro
            else:
                curr_api_val = product.get(k,-1) #if it's -1 it means its missing so we'll leave as None
                if curr_api_val != -1: 
                    processed_data[v] = curr_api_val
        #now add to the db what we have so far
        try:
            serving_size = processed_data['serving_size_grams']
            try:
                processed_data['serving_size_grams'] = float(serving_size) if serving_size is not None else None
            except (TypeError,ValueError):
                processed_data['serving_size_grams'] = None #cant convert it
            if processed_data['serving_size_grams'] is not None and processed_data['serving_size_grams'] <= 0:
                processed_data['serving_size_grams'] = None #a 0 or negative serving size would make every logged meal 0 so treat it as missing
            name = processed_data['name']
            processed_data['name'] = name.strip() if isinstance(name, str) and name.strip() else None #blank names count as missing
            enter_barcode = Barcode_Cache(barcode=barcode,name=processed_data['name'],serving_size_grams=processed_data['serving_size_grams'],calories_per_100=processed_data['calories_per_100'],protein_per_100=processed_data['protein_per_100'],fat_per_100=processed_data['fat_per_100'],carbs_per_100=processed_data['carbs_per_100'])
            db.add(enter_barcode)
            db.commit()
        except IntegrityError:
            db.rollback()
    else:
        #go through all the keys in our obj and grab from db if its in there
        #any values that are None in the end are put into missing
        for key in processed_data.keys():
            if key in ('barcode','missing'): continue #dont need these
            if getattr(cached_barcode,key,None) is not None:
                processed_data[key] = getattr(cached_barcode,key) #stores the value in the cache 
    for k,v in processed_data.items():
        if v is None: processed_data['missing'].append(k) #add to missing if still none
    return processed_data

#endpoint to manually enter the info for the missing fields from the barcode info given-- either updating or creating a db entry depending if there was enough info to create one with the barcode 
#send back the barcode, serving size, name, and 4 macros per 100 grams so they can fill in the logging screen
@app.put('/nutrition/manual-barcode/{barcode}',response_model=Logging_Barcode_Food_Out)
def manually_enter_barcode_food(barcode:str,body: Manually_Enter_Barcode_Food_In, user_id: UUID = Depends(get_curr_user), db: Session = Depends(get_db)):
    barcode = normalize_barcode(barcode)
    food = db.scalar(select(Barcode_Cache).where(Barcode_Cache.barcode==barcode))
    if food is None:
        food = Barcode_Cache(barcode=barcode)
        db.add(food)
    food.name,food.serving_size_grams,food.calories_per_100,food.protein_per_100,food.fat_per_100,food.carbs_per_100 = body.name,body.serving_size_grams,body.calories,body.protein,body.fat,body.carbs
    try:
        db.commit()
        db.refresh(food)
    except IntegrityError:
        db.rollback()
        raise HTTPException(500, 'Could not save the food')
    return food
    
#endpoint to log the food for a users meal after they submit the servings they had for a given barcoded food
#we take the barcode, servings consumed, meal type and then calculate the rest using that
@app.post('/nutrition/log-meal/{barcode}',status_code=status.HTTP_201_CREATED, response_model=Create_Meal_Out)
def log_meal(barcode: str, body:Log_Meal_In, user_id:UUID = Depends(get_curr_user), db: Session = Depends(get_db)):
    barcode = normalize_barcode(barcode) #just in case
    cached_food = db.scalar(select(Barcode_Cache).where(Barcode_Cache.barcode==barcode))
    if cached_food is None: raise HTTPException(404,'Food not in cache yet, redirecting to manual entry')
    #make sure all the macros are there for math safety
    needed_macros = [cached_food.fat_per_100,cached_food.protein_per_100,cached_food.carbs_per_100,cached_food.calories_per_100,cached_food.serving_size_grams,cached_food.name]
    if any(m is None for m in needed_macros): raise HTTPException(422,'Food is missing needed macro values')
    total_grams_consumed = cached_food.serving_size_grams * body.servings_consumed #givs the number of grams we had 
    calories = round((total_grams_consumed*cached_food.calories_per_100)/100,1)
    carbs = round((total_grams_consumed*cached_food.carbs_per_100)/100,1)
    protein = round((total_grams_consumed*cached_food.protein_per_100)/100,1)
    fat = round((total_grams_consumed*cached_food.fat_per_100)/100,1)
    meal = Meal(user_id=user_id,meal_name=cached_food.name,meal_type=body.meal_type,protein=protein,carbs=carbs,fat=fat,calories=calories)
    try:
        db.add(meal)
        db.commit()
        db.refresh(meal)
    except IntegrityError:
        db.rollback()
        raise HTTPException(500, 'Could not save meal')
    return meal


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

#*********************************** Lifting Section ***************************************

#displaying workouts completed this week along with the days they were completed and the total workouts to do for a visual of workouts this week
@app.get('/lifting/current-workouts', response_model=Send_Weekly_Lifts_Out)
def get_this_weeks_workouts(start_day: datetime, user_id: UUID = Depends(get_curr_user), db: Session = Depends(get_db)):
    if start_day.tzinfo is None: raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail='start_day must include a timezone')
    end_day = start_day + timedelta(days=7) #doesnt include this day-- this is 7 days out from the weeks start (next sunday)
    week_summary = {
        'completed_lifts':0,
        'total_lifts':0,
        'completed_lift_array':[]
    } #this is the object that will be sent back to give the summary of what was done so far
    user_program = db.scalar(select(User_Program).where(User_Program.user_id==user_id)) #gets the program associated with the user
    if user_program is None: return week_summary #not enrolled in a program so everything is 0
    completed_lifts = db.scalars(select(Workout).where(Workout.user_id==user_id,Workout.program_id==user_program.program_id,Workout.completed_at.is_not(None),start_day<=Workout.completed_at,Workout.completed_at<end_day).order_by(Workout.completed_at)).all()#grabs each completed workout that is either after or on Sunday(start of week) and at most the next Saturday(before next sunday)
    #now lets fill the summary with the results of the users workouts 
    week_summary['completed_lifts'] = len(completed_lifts) #only grabbed completed workouts, so the length of the list is the number of completed workouts
    #getting the number of lifts in their program by going through User_Program and then accessing the Program table
    week_summary['total_lifts'] = user_program.program.number_of_days
    #filling in the completed lifts now with their id and the day of the week it was done 
    for lift in completed_lifts:
        week_summary['completed_lift_array'].append({
            'workout_id':lift.id,
            'day_completed': lift.completed_at
        })
    return week_summary

#start-workout endpoint
@app.post('/lifting/start-workout', response_model=Start_Workout_Out, status_code=status.HTTP_201_CREATED)
def start_workout(user_id: UUID = Depends(get_curr_user), db: Session = Depends(get_db)):
    result_obj = {} #store the result in here
    user_program = db.scalar(select(User_Program).where(User_Program.user_id==user_id))
    if user_program is None: raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail='No active programs for the user')
    program = db.scalar(select(Program).where(Program.id==user_program.program_id))
    if program is None: raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail='No active programs for the user')
    close_stale_workouts(db, user_id, keep_program_id=program.id) #clear out open workouts left over from a program they switched off of
    #check if there was already a workout completed today-- if so then dont allow to continue because only allow 1 workout per day
    today_date = func.current_date() #this is to check if the workout is the same date as today
    same_day_lift = db.scalar(select(Workout).where(Workout.user_id==user_id,cast(Workout.completed_at,Date())==today_date))
    if same_day_lift is not None: raise HTTPException(409, 'Can not complete 2 workouts in 1 day')
    #check if there is an active workout for this program before creating another-- tests for double clicks
    workout = db.scalar(select(Workout).where(Workout.user_id==user_id, Workout.program_id==program.id, Workout.completed_at.is_(None)))
    is_new_workout = workout is None
    if is_new_workout:
        workout = Workout(user_id=user_id, program_id=program.id)
    #move to the next day for a new workout, or if the day is still 0 (no real day yet, e.g. right after choosing a program)
    if is_new_workout or user_program.current_day < 1:
        if user_program.current_day >= program.number_of_days: user_program.current_day = 1
        else: user_program.current_day += 1
    result_obj['name'], result_obj['description'], result_obj['goal'],result_obj['lift_data'] = program.name, program.description, program.goal,[]
    workout.day = user_program.current_day #holds the day in the user's workout table 
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
        #get the last weight the user used for this exercise so we can give them a recommendation
        last_used_weight = db.scalar(select(Workout_Set.weight)
                                     .join(Workout,Workout.id==Workout_Set.workout_id)
                                     .where(Workout.user_id==user_id,Workout_Set.exercise_id==exercise.id)
                                     .order_by(Workout.started_at.desc())
                                     .limit(1))
        curr_exercise['recommended_weight'] = last_used_weight
        result_obj['lift_data'].append(curr_exercise)
    db.refresh(workout)
    result_obj['workout_id'] = workout.id
    return result_obj

#Endpoint for when a user completes an exercise-- sends the sets/reps/weight they used. 
# NOTE: Might change this so they send data after every set they complete
@app.post('/lifting/{workout_id}/finish-exercise', response_model=Exercise_Data_Out, status_code=status.HTTP_201_CREATED)
def finish_exercise(body: Exercise_Data_In,workout_id: UUID, user_id: UUID = Depends(get_curr_user), db: Session = Depends(get_db)):
    current_workout = db.scalar(select(Workout).where(Workout.id==workout_id, Workout.user_id==user_id)) #checking to see if there is an active workout
    if current_workout is None: raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail='Could not find workout with that ID')
    if current_workout.completed_at is not None: raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail='There is not an active workout to record in')
    workout_set = Workout_Set(workout_id=workout_id,exercise_id=body.exercise_id,reps=body.reps,sets=body.sets,weight=body.weight) #create the set
    db.add(workout_set) #always save the set, PR or not
    #check if it is PR by comparing estimated 1 rep maxes using the Epley formula: weight * (1 + reps/30)
    current_pr = db.scalar(select(Personal_Record).where(Personal_Record.exercise_id==workout_set.exercise_id, Personal_Record.user_id==user_id))
    if current_pr is None: #first time doing this exercise so it is automatically the PR
        db.add(Personal_Record(user_id=user_id, exercise_id=workout_set.exercise_id, weight=workout_set.weight, reps=workout_set.reps))
    else:
        current_max = current_pr.weight * (1 + current_pr.reps/30)
        #new max so overwrite the old one in place
        if current_max < (workout_set.weight * (1 + workout_set.reps/30)):
            current_pr.weight = workout_set.weight
            current_pr.reps = workout_set.reps
            current_pr.achieved_at = func.now()
    try:
        db.commit() #set and PR saved together so neither is saved without the other
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail='Could not save set')
    db.refresh(workout_set)
    return workout_set

#Endpoint for getting the workout summary page info. Happens once the user clicks finish workout
@app.post('/lifting/{workout_id}/finish-workout', response_model= Workout_Summary_Out, status_code=status.HTTP_200_OK)
def get_workout_summary(workout_id: UUID, user_id: UUID = Depends(get_curr_user), db: Session = Depends(get_db)):
    current_workout = db.scalar(select(Workout).where(Workout.id==workout_id,Workout.user_id==user_id))
    if current_workout is None: raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail='Workout does not exist')
    if current_workout.completed_at is not None: raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail='Workout is not active')

    user_program = db.scalar(select(User_Program).where(User_Program.user_id==user_id)) #by user only so a workout started before switching programs can still be finished
    if user_program is None: raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail='Program for this workout not found')

    current_workout.completed_at = func.now() #gets the postgres version of the date, consistent to how we do the start time
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail='Could not update the workout end time')
    db.refresh(current_workout) #gets the updated current workout back with the end time
    summary_stats = {} #going to hold all of the summary stats from the workout
    workout_duration = round((current_workout.completed_at - current_workout.started_at).total_seconds() / 60,1) #gets the timedelta obj and gets the total minutes from this calculation
    summary_stats['duration'] = workout_duration
    #now get the rest through querying jumps
    all_completed_exercises = db.scalars(select(Workout_Set).where(Workout_Set.workout_id==workout_id)).all() #gets list of each exercise done
    summary_stats['number_exercises'] = len({s.exercise_id for s in all_completed_exercises})
    summary_stats['number_sets'] = sum(s.sets for s in all_completed_exercises)
    summary_stats['total_volume'] = sum(e.weight*e.reps*e.sets for e in all_completed_exercises)
    best_exercise = {} #going to hold the exercise of the day-- highest weight used {name, sets, reps, weight}
    highest_weight = max(all_completed_exercises,key=lambda x: x.weight, default=None) #finds the one with highest weight
    if highest_weight is not None:
        best_exercise['sets'],best_exercise['reps'], best_exercise['weight'] = highest_weight.sets, highest_weight.reps, highest_weight.weight
        e_name = db.scalar(select(Exercise).where(Exercise.id==highest_weight.exercise_id))
        if e_name is not None: 
            best_exercise['exercise_name'] = e_name.name
            summary_stats['best_exercise'] = best_exercise
        else: summary_stats['best_exercise'] = None
    #get the workout name and the current day and total days
    summary_stats['workout_name'],summary_stats['workout_day'],summary_stats['total_days'] = user_program.program.name,user_program.current_day,user_program.program.number_of_days
    return summary_stats

#endpoint for finalizing the workout-- clicking the save/finish workout button on the summary screen. Only thing being added is the optional notes section to the existing workout row in the db
@app.patch('/lifting/{workout_id}/submit-workout', status_code=status.HTTP_200_OK)
def finalize_workout(body: Finalize_Workout_In,workout_id:UUID, user_id: UUID = Depends(get_curr_user), db: Session=Depends(get_db)):
    workout = db.scalar(select(Workout).where(Workout.user_id==user_id, Workout.id==workout_id))
    if workout is None: raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail='Workout not found')
    elif workout.completed_at is None: raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail='Can not save a non-finished workout')
    if body.notes is not None:
        workout.notes = body.notes
        db.commit()
    return {"data": "success"}

#endpoint that takes in the program-creation survey results and gives the top 3 matches through a weighted algorithm
@app.post('/lifting/generate-program', response_model=Top_3_Programs_Out)
def find_program_matches(body:Survey_Results_In, user_id: UUID = Depends(get_curr_user), db: Session = Depends(get_db)):
    equipment_level = get_equipment_level(body.equipment) #stores the bracket the user is put into for their level of equipment they have available
    equipment_threshold, experience_threshold = Equipment_Buckets[equipment_level], Experience_Buckets[body.experience] #gets the threshold for what the programs must be less than or equal to

    allowed_equipment = [k for k,v in Equipment_Buckets.items() if v <= equipment_threshold]
    allowed_experience = [k for k,v in Experience_Buckets.items() if v <= experience_threshold]
    candidates = db.scalars(select(Program).where(Program.equipment_level.in_(allowed_equipment), Program.difficulty.in_(allowed_experience),Program.number_of_days<=body.days_available)).all()#gets programs that meet the min requirements-- the user is elegible for all of them
    if not candidates: raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail='Program does not exist')
    scored_programs = [
        (score_program(p,equipment_level,body.experience,body.days_available,body.goal),p) for p in candidates
    ]
    scored_programs.sort(key=lambda p: p[0], reverse=True) #sorts the programs in order of best match to worst (highest to lowest score)
    return {
        "programs": [
            {
                "program_id": p.id,
                "name": p.name,
                "description": p.description,
                "difficulty": p.difficulty,
                "number_of_days": p.number_of_days,
                "goal": p.goal,
                "program_length": p.program_length,
                "equipment_level": p.equipment_level,
                'split': p.split,
                "score": round(score),
            }
            for score, p in scored_programs[:3]
        ]
    }
#endpoint to save the chosen program in the database for the user
@app.post('/lifting/{program_id}/choose-program', status_code = status.HTTP_201_CREATED)
def choose_program(program_id:UUID, user_id: UUID = Depends(get_curr_user), db: Session = Depends(get_db)):
    existing = db.scalar(select(User_Program).where(User_Program.user_id==user_id))
    if existing: db.delete(existing) #cant have more than one program at a time
    program = db.scalar(select(Program).where(Program.id == program_id))
    if not program: raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail='Program not found')
    user_program = User_Program(goal=program.goal,program_id=program_id,user_id=user_id,experience_level=program.difficulty,days_available=program.number_of_days)
    close_stale_workouts(db, user_id) #new program starts fresh so clean up any unfinished workouts from before
    try:
        db.add(user_program)
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail='Could not save program')
    return {'status':'success'}

#endpoint to get the program the user is currently on so the client can show it
@app.get('/lifting/my-program', response_model=My_Program_Out)
def get_my_program(user_id: UUID = Depends(get_curr_user), db: Session = Depends(get_db)):
    user_program = db.scalar(select(User_Program).where(User_Program.user_id==user_id))
    if user_program is None: raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail='No active programs for the user')
    program = user_program.program
    #logic for giving the estimated time of completion for the upcoming workout based on the median of the past-- if done this workout at least once
    #if a workout is in progress the user is on current_day, otherwise start-workout will bump them to the next day
    has_open_workout = db.scalar(select(exists().where(Workout.user_id==user_id,
                                                       Workout.program_id==user_program.program_id,
                                                       Workout.completed_at.is_(None))))
    target_day = user_program.current_day if has_open_workout else user_program.current_day % program.number_of_days + 1
    past_workout_for_day = db.scalars(select(Workout).where(Workout.user_id==user_id,
                                                           Workout.program_id==user_program.program_id,
                                                           Workout.completed_at.is_not(None),
                                                           Workout.day==target_day)).all()#grabs finished workouts for the same day
    #median instead of mean so a stale workout auto-closed days later doesnt blow up the estimate
    durations = [(w.completed_at-w.started_at).total_seconds()/60 for w in past_workout_for_day]
    median_completion_time = round(median(durations),1) if durations else None #None means they have not done this day yet
    return {
        "program_id": program.id,
        "name": program.name,
        "description": program.description,
        "difficulty": program.difficulty,
        "number_of_days": program.number_of_days,
        "goal": program.goal,
        "program_length": program.program_length,
        "equipment_level": program.equipment_level,
        "split": program.split,
        "current_day": user_program.current_day,
        "next_day": user_program.current_day % program.number_of_days + 1, #same wraparound start-workout uses
        "estimated_completion_time": median_completion_time
    }
#endpoint to return the 3 newest PR's recorded so the lifting dasboard can display them
@app.get('/lifting/newest-records', response_model=Newest_PRs)
def get_newest_records(user_id: UUID = Depends(get_curr_user), db: Session= Depends(get_db)):
    newest_records = {'records':[]} #going to hold the 3 newest PR's if there are 3
    top_3_records = db.execute(select(Exercise.name,Personal_Record.weight, Personal_Record.reps)
                               .join(Exercise,Exercise.id==Personal_Record.exercise_id)
                               .where(Personal_Record.user_id==user_id)
                               .order_by(Personal_Record.achieved_at.desc()).
                               limit(3)).all()
    for pr in top_3_records:
        newest_records['records'].append({'lift_name':pr.name,'weight':pr.weight,'reps':pr.reps})
    return newest_records