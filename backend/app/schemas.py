#Holds all of the pydantic schemas which are going to validate JSON data coming in and out of the backend
from datetime import datetime, date, time
from uuid import UUID
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
    calories: int = 0
    protein: int = 0
    carbs: int = 0
    fat: int = 0
#format to send create meal data back to client
class Create_Meal_Out(BaseModel):
    meal_date: date
    created_at: datetime
    meal_name: str
    meal_type: str
    calories: int = 0
    protein: int = 0
    carbs: int = 0
    fat: int = 0
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
    program_length: int | None
    equipment_level: str
    split: str
    score: float
#format to send the 3 programs over to the client after we find the top 3 matches
class Top_3_Programs_Out(BaseModel):
    programs:list[Program_Out]
