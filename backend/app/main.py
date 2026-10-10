from uuid import UUID

from app.auth_dependency import get_curr_user
from fastapi import FastAPI, Depends, Request, Response, HTTPException, status
from app.config import settings
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError
from sqlalchemy import select
from app.schemas import User_Signup_In, User_Signup_Out, User_Login_Out
from app.database import get_db #dependency for db operations(creates a session) and gives us user id from token payload
from app.models import User


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


    

    

