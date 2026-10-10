from datetime import date
from uuid import UUID

from app.auth_dependency import get_curr_user
from fastapi import FastAPI, Depends, Request, Response, HTTPException, status
from app.config import settings
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError
from sqlalchemy import select
from app.schemas import User_Signup_In, User_Signup_Out, User_Login_Out, User_Profile_Survey, Nutrition_Summary_Out
from app.database import get_db #dependency for db operations(creates a session) and gives us user id from token payload
from app.models import User, Meal, User_Goal_Nutrition
from app.helper_funcs import get_nutrition_stats


app = FastAPI()

@app.get('/')
def test():
    return {'msg': "Success"}

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
    db.commit()
    db.refresh(user)
    return user

#Nutrition summary page
@app.get('/nutrition/summary', response_model=Nutrition_Summary_Out)
def get_nutrition_summary(day:date, user_id: UUID = Depends(get_curr_user), db: Session=Depends(get_db)):
    user_goals = db.scalar(select(User_Goal_Nutrition).where(User_Goal_Nutrition.user_id==user_id))
    all_meals_day = db.scalars(select(Meal).where(Meal.user_id==user_id, Meal.meal_date==day).order_by(Meal.created_at)).all() #grabs all meals for the chosen day
    ##Get total count for each macro from the meals eaten that day
    macros={'Calories':sum(meal.calories for meal in all_meals_day), 
            'Protein':sum(meal.protein for meal in all_meals_day), 
            'Carbs':sum(meal.carbs for meal in all_meals_day), 
            'Fats':sum(meal.fat for meal in all_meals_day)}
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
    macro_goals = {'Calories':user_goals.calories_goal, 'Protein':user_goals.protein_goal,'Carbs':user_goals.carbs_goal,'Fats':user_goals.fat_goal}
    ##Get progress made on goal based on what was done for each macro
    macro_progress_percent = {'Calories':get_nutrition_stats(macros['Calories'],user_goals.calories_goal), 
                      'Protein':get_nutrition_stats(macros['Protein'], user_goals.protein_goal), 
                      'Carbs':get_nutrition_stats(macros['Carbs'],user_goals.carbs_goal), 
                      'Fats':get_nutrition_stats(macros['Fats'],user_goals.fat_goal)}
    total_progress_percent = (sum(macro_progress_percent.values())/len(macro_progress_percent)) #computes score as percentage for all macros
    return_data = {
        'date': day,
        'macros_consumed_counts': macros,
        'macro_goals': macro_goals,
        'macro_consumed_percentage': macro_progress_percent,
        'macro_score': total_progress_percent
    }
    return return_data





    

    

