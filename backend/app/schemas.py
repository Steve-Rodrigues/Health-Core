#Holds all of the pydantic schemas which are going to validate JSON data coming in and out of the backend
from datetime import datetime, date, time
from uuid import UUID
import uuid
from pydantic import BaseModel, ConfigDict, Field
from typing import Literal #values in the Literal array must be only what we set
#on signup the backend is only expecting the client to send over the username because we get the id from the dependency
class User_Signup_In(BaseModel):
    username: str = Field(min_length=3, max_length=20)
#format we return the user signup to the client 
class User_Signup_Out(BaseModel):
    id: UUID
    username: str
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)

#format we return user data in after login
class User_Login_Out(BaseModel):
    username: str
    created_at: datetime
    height: float | None = None
    current_weight: float | None = None
    goal_weight: float | None = None
    workouts_per_week_goal: int | None = None
    sleep_goal: float | None = None

#format take data in from the onboarding survey
class User_Profile_Survey(BaseModel):
    current_weight: float | None = None
    goal_weight: float | None = None
    workouts_per_week_goal: int | None = None
    sleep_goal: float | None = None
    height: float | None = None

#updating goals from the profile page, frontend sends every field so none are optional
class User_Goals_Update(BaseModel):
    current_weight: float
    goal_weight: float
    workouts_per_week_goal: int
    sleep_goal: float
    height: float

#for the macros dict
class Macros(BaseModel):
    calories: float
    protein: float
    carbs: float
    fat: float

#format to send data for the summary of nutrition page
class Nutrition_Summary_Out(BaseModel):
    date: date
    macros_consumed_counts: Macros
    macro_goals: Macros | None = None
    macro_consumed_percentage: Macros | None = None
    macro_score: float | None = None

#format to take in the create meal data 
class Create_Meal_In(BaseModel):
    meal_name: str
    meal_type: str
    calories: float = 0
    protein: float = 0
    carbs: float = 0
    fat: float = 0
#format to send create meal data back to client
class Create_Meal_Out(BaseModel):
    meal_date: date
    created_at: datetime
    meal_name: str
    meal_type: str
    calories: float = 0
    protein: float = 0
    carbs: float = 0
    fat: float = 0
    model_config = ConfigDict(from_attributes=True)
#format to take in user nutrition goals
class Create_Nutrition_Goal_In(BaseModel):
    protein_goal: int = Field(gt=0) #goal must be greater or equal to 0
    carbs_goal: int = Field(gt=0)
    fat_goal: int = Field(gt=0)
    calories_goal: int = Field(gt=0)
#format to send user nutrition goals back to the client
class Create_Nutrition_Goal_Out(BaseModel):
    protein_goal: int 
    carbs_goal: int 
    fat_goal: int 
    calories_goal: int
    model_config = ConfigDict(from_attributes=True)

#format to take in the sleep data
class Log_Sleep_In(BaseModel):
    wake_date: date
    bed_time: time
    wake_time: time
    quality: int = Field(ge=1, le=5) #1-5 rating
    notes: str
#format to send back sleep data 
class Log_Sleep_Out(BaseModel):
    sleep_date: date
    bed_time: time
    wake_time: time
    duration_mins: int
    quality: int = Field(ge=1,le=5)
    notes: str
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)
#format to send the object with the workout data in
class Workout_Exercises_Out(BaseModel):
    exercise:str
    exercise_id: UUID
    sets: int
    reps: int
#format to send start workout data in response to the client 
class Start_Workout_Out(BaseModel):
    name: str
    description: str
    goal: str
    workout_id: UUID
    lift_data: list[Workout_Exercises_Out]

#format to recieve the info from a user's exercise after completion
class Exercise_Data_In(BaseModel):
    exercise_id: UUID
    sets: int = Field(default=0, ge=0)
    reps: int = Field(default=0, ge=0)
    weight: float = Field(default=0, ge=0)
#format to send the data back to the client-side
class Exercise_Data_Out(BaseModel):
    workout_id: UUID
    exercise_id: UUID
    sets: int = Field(default=0, ge=0)
    reps: int = Field(default=0, ge=0)
    weight: float = Field(default=0, ge=0)
    model_config = ConfigDict(from_attributes=True)

#format for the object being used in the schema below for the best workout of the day
class Best_Workout_Today(BaseModel):
    exercise_name: str
    sets: int
    reps: int
    weight: float
#format we send the summary in for the completed workout page
class Workout_Summary_Out(BaseModel):
    workout_name: str
    workout_day: int
    total_days: int
    duration: float
    number_exercises: int
    number_sets: int
    total_volume: float
    best_exercise: Best_Workout_Today | None = None
    model_config = ConfigDict(from_attributes=True)

#format for recieving the notes from the client when finish workout is pressed in summary
class Finalize_Workout_In(BaseModel):
    notes: str | None = None

#format that we take in the create-program survey results 
class Survey_Results_In(BaseModel):
    goal: Literal['build_muscle','get_stronger','lose_fat','general_fitness'] #same goals the seeded programs use
    experience: Literal['beginner','intermediate','expert']
    days_available: int = Field(ge=2, le=6)
    equipment: list[Literal['machine','barbell','exercise ball','e-z curl bar','medicine ball','dumbbell','bands','foam roll','kettlebells','cable']] #every item the user checked-- can be empty

#format each program will be in that we send to the client after choosing the top matches
class Program_Out(BaseModel):
    program_id: UUID
    name: str
    description: str
    difficulty: str
    number_of_days: int
    goal: str
    program_length: int | None = None
    equipment_level: str
    split: str
    score: float
    model_config = ConfigDict(from_attributes=True)

#format to send the 3 programs over to the client after we find the top 3 matches
class Top_3_Programs_Out(BaseModel):
    programs:list[Program_Out]
    model_config = ConfigDict(from_attributes=True)

#format we send the users current program to the client-- next_day is the day start-workout will load next
class My_Program_Out(BaseModel):
    program_id: UUID
    name: str
    description: str
    difficulty: str
    number_of_days: int
    goal: str
    program_length: int | None = None
    equipment_level: str
    split: str
    current_day: int
    next_day: int
    estimated_completion_time: float | None  =None
    model_config = ConfigDict(from_attributes=True)

#format to take the chosen program in from the client after the user chooses one
class Program_In(BaseModel):
    program_id: UUID
    name: str
    description: str
    difficulty: str
    number_of_days: int
    goal: str
    program_length: int | None = None
    equipment_level: str
    split: str
    score: float   
#format to send the data from initial barcode get request
class Scan_Barcode_Food_Out(BaseModel):
    barcode: str
    name: str | None = None
    serving_size_grams: float|None = None #sends amount of grams in one serving size
    calories_per_100: float|None = None #sends the amount of calories per 100 grams 
    fat_per_100: float|None = None #sends the amount of fat per 100 grams 
    carbs_per_100: float|None = None #sends the amount of carbs per 100 grams 
    protein_per_100: float|None = None #sends the amount of protein per 100 grams 
    missing: list[str] = [] #holds all the info that was not found yet- send to manual enter page
    model_config = ConfigDict(from_attributes=True)

#format to take in the manually entered data for a given barcode food entry
class Manually_Enter_Barcode_Food_In(BaseModel):
    name: str
    serving_size_grams: float = Field(gt=0)
    calories: float = Field(ge=0)
    fat: float = Field(ge=0)
    carbs: float = Field(ge=0)
    protein: float = Field(ge=0)
#format to send the barcode food data to the frontend for the logging page
class Logging_Barcode_Food_Out(BaseModel):
    barcode: str
    name: str
    serving_size_grams: float #sends amount of grams in one serving size
    calories_per_100: float #sends the amount of calories per 100 grams 
    fat_per_100: float #sends the amount of fat per 100 grams 
    carbs_per_100: float #sends the amount of carbs per 100 grams 
    protein_per_100: float #sends the amount of protein per 100 grams 
    model_config = ConfigDict(from_attributes=True)

#format to take in the info for logging a user's barcoded meal-- only need the barcode and servings a user had along with the meal type to log as
class Log_Meal_In(BaseModel):
    servings_consumed: float = Field(gt=0) #number of servings they had
    meal_type: str #could be breakfast/lunch/dinner/snack

#format the lifts array will be in-- it has the workout id and the datetime it was completed at
class Lift_Array(BaseModel):
    workout_id: UUID
    day_completed: datetime

#format to send the weekly workouts completed out of total to the flutter client side
class Send_Weekly_Lifts_Out(BaseModel):
    completed_lifts: int #number of workouts finished
    total_lifts: int #number of lifts for that week in total
    completed_lift_array: list[Lift_Array]

#format the PR's array will be in Newest_PRs
class Newest_Prs_Array(BaseModel):
    lift_name: str
    weight: float
    reps: int
#format to get the top 3 newest PR's 
class Newest_PRs(BaseModel):
    records: list[Newest_Prs_Array]