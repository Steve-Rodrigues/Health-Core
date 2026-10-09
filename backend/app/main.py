from app.auth_dependency import get_curr_user
from fastapi import FastAPI, Depends, Request, Response, HTTPException, status
from app.config import settings
from app.database import get_db #dependency for db operations(creates a session)


app = FastAPI()

@app.get('/')
def test():
    return {'msg': "Success"}
