#creating the db tables in here that will be accessed/managed using sqlalchemy-- the python orm for using db
#orm is like a middleman between the user and the actual db, it allows you to write python object code and it translates into SQL for the real db
from sqlalchemy.orm import declarative_base
from sqlalchemy.orm import Mapped, MappedColumn

Base = declarative_base() #creates the Base call to put in the table class parameters so it knows it is a orm table

