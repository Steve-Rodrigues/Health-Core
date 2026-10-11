#Holds all of the pydantic schemas which are going to validate JSON data coming in and out of the backend
from datetime import datetime, date
from uuid import UUID
from pydantic import BaseModel, ConfigDict, Field

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
    workouts_per_week_goal: float | None = None
    sleep_goal: float | None = None

#format take data in from the onboarding survey
class User_Profile_Survey(BaseModel):
    current_weight: float | None = None
    goal_weight: float | None = None
    workouts_per_week_goal: int | None = None
    sleep_goal: float | None = None

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
    calories: int | None = None
    protein: int | None = None
    carbs: int | None = None
    fat: int | None = None
    model_config = ConfigDict(from_attributes=True)




