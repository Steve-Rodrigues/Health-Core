#creating the db tables in here that will be accessed/managed using sqlalchemy-- the python orm for using db
#orm is like a middleman between the user and the actual db, it allows you to write python object code and it translates into SQL for the real db
from datetime import date

from sqlalchemy.orm import declarative_base
from sqlalchemy.orm import Mapped, MappedColumn

Base = declarative_base() #creates the Base call to put in the table class parameters so it knows it is a orm table

class Workout(Base):
    __tablename__ = "workout"

    id = Mapped[int] = MappedColumn(primary_key=True) #this is the primary key for the table, it is an integer and it is auto incremented
    user_id = Mapped[int] = MappedColumn() #this is a column for the user ID associated with the workout, it is a string
    program_id = Mapped[int] = MappedColumn() #this is a column for the program ID associated with the workout, it is an integer
    started_at = Mapped[date] = MappedColumn() #this is a column for the date and time the workout was started, it is a date
    completed_at = Mapped[date] = MappedColumn() #this is a column for the date and time the workout was completed, it is a date
    notes = Mapped[str] = MappedColumn() #this is a column for any notes associated with the workout, it is a string
    
class Workout_Set(Base): 
    __tablename__ = "workout_set" 

    id = Mapped[int] = MappedColumn(primary_key=True)
    workout_id = Mapped[int] = MappedColumn() #this is a column for the workout ID associated with the set, it is an integer
    exercise_id = Mapped[int] = MappedColumn() #this is a column for the exercise ID associated with the set, it is an integer
    reps = Mapped[int] = MappedColumn() #this is a column for the number of reps in the set, it is an integer
    weight = Mapped[float] = MappedColumn() #this is a column for the weight used in the set, it is a float

class Exercise(Base): 
    __tablename__ = "exercise" 

    id = Mapped[int] = MappedColumn(primary_key=True)
    name = Mapped[str] = MappedColumn() #this is a column for the name of the exercise, it is a string
    instructions = Mapped[str] = MappedColumn() #this is a column for the instructions of the exercise, it is a string
    equipment = Mapped[bool] = MappedColumn() #this is a column for the equipment needed for the exercise, it is a boolean
    level = Mapped[str] = MappedColumn() #this is a column for the level of the exercise, it is a string

class Program_Exercise(Base): 
    __tablename__ = "program_exercise" 

    id = Mapped[int] = MappedColumn(primary_key=True)
    program_id = Mapped[int] = MappedColumn() #this is a column for the program ID associated with the exercise, it is an integer
    exercise_id = Mapped[int] = MappedColumn() #this is a column for the exercise ID associated with the program, it is an integer
    day = Mapped[int] = MappedColumn() #this is a column for the day of the exercise in the program, it is an integer
    sets = Mapped[int] = MappedColumn() #this is a column for the number of sets in the exercise, it is an integer
    reps = Mapped[int] = MappedColumn() #this is a column for the number of reps in the exercise, it is an integer