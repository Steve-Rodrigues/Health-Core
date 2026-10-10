#Holds all of the pydantic schemas which are going to validate JSON data coming in and out of the backend
from datetime import datetime
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
    





