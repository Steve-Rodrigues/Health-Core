#creating the db tables in here that will be accessed/managed using sqlalchemy-- the python orm for using db
#orm is like a middleman between the user and the actual db, it allows you to write python object code and it translates into SQL for the real db
from datetime import datetime

from sqlalchemy.orm import declarative_base
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy import String, ForeignKey, DateTime, func, Integer, Float, Boolean
from uuid import UUID, uuid4 #UUID is the type for the type hints, uuid4 generates new ids
from sqlalchemy.dialects.postgresql import UUID as PGUUID #this is the true UUID column data type

Base = declarative_base() #creates the Base call to put in the table class parameters so it knows it is a orm table

class User(Base):
    __tablename__ = 'users'
    id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    username: Mapped[str] = mapped_column(String(30), unique=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    #one-to-many sides of the relationships-- cascade lives here on the parent so deleting a user deletes their rows too
    workouts: Mapped[list["Workout"]] = relationship(back_populates='user', cascade='all, delete-orphan', passive_deletes=True)
    user_programs: Mapped[list["User_Program"]] = relationship(back_populates='user', cascade='all, delete-orphan', passive_deletes=True)

#********* Lifting Section Tables ****************

#tracks each workout a user completes
class Workout(Base):
    __tablename__ = "workouts"

    id : Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    user_id : Mapped[UUID] = mapped_column(PGUUID(as_uuid=True),ForeignKey('users.id', ondelete='CASCADE'))  #links to the user table for the correct user id-- cascade so if user deleted this row is deleted too
    program_id : Mapped[UUID | None] = mapped_column(PGUUID(as_uuid=True), ForeignKey('programs.id', ondelete='SET NULL'), nullable=True) #FK link to program the user doing this workout is following in our Program tb-- SET NULL so deleting a program keeps workout history
    started_at : Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    completed_at : Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True) #set when the user finishes the workout
    notes : Mapped[str | None] = mapped_column(String(),nullable=True) #this is a column for any notes associated with the workout, optional
    user: Mapped["User"] = relationship(back_populates='workouts')

#Tracks each set a user completes
class Workout_Set(Base):
    __tablename__ = "workout_sets"

    id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    workout_id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), ForeignKey('workouts.id', ondelete='CASCADE')) #links set to an active workout
    exercise_id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), ForeignKey('exercises.id', ondelete='CASCADE')) #links exersice to an exersice in our db
    reps: Mapped[int] = mapped_column(Integer, nullable=False) #this is a column for the number of reps in the set, it is an integer
    weight: Mapped[float] = mapped_column(Float, nullable=False) #this is a column for the weight used in the set, it is a float

#Holds all exersices we store for use
class Exercise(Base):
    __tablename__ = "exercises"

    id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    name: Mapped[str] = mapped_column(String(), nullable=False) #exersice name
    instructions: Mapped[str] = mapped_column(String(), nullable=False) #exersice instructions
    equipment: Mapped[bool] = mapped_column(Boolean(), default=False) #Marked true if equipment needed
    level: Mapped[int] = mapped_column(Integer()) #level of exersice-- rated on number system(1-5)

#Stores the program using an exersice along with reps/sets and day used on the program
class Program_Exercise(Base):
    __tablename__ = "program_exercises"

    id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    program_id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), ForeignKey('programs.id', ondelete='CASCADE')) #the program this exercise belongs to
    exercise_id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), ForeignKey('exercises.id', ondelete='CASCADE')) #the exercise used in the program
    day: Mapped[int] = mapped_column(Integer(), nullable=False) #this is a column for the day of the exercise in the program, it is an integer
    sets: Mapped[int] = mapped_column(Integer(), nullable=False) #this is a column for the number of sets in the exercise, it is an integer
    reps: Mapped[int] = mapped_column(Integer(), nullable=False) #this is a column for the number of reps in the exercise, it is an integer

#Stores all of the programs we create
class Program(Base):
    __tablename__ = 'programs'

    id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    name: Mapped[str] = mapped_column(String(), unique=True, nullable=False)
    description: Mapped[str] = mapped_column(String(), nullable=False)
    difficulty: Mapped[int]  = mapped_column(Integer(), nullable=False) #1-5
    days: Mapped[int] = mapped_column(Integer(), nullable=False) #per week
    goal: Mapped[str] = mapped_column(String(), nullable=False) # could be bulk, shredding, etc...
    program_length: Mapped[int | None] = mapped_column(Integer(), nullable=True) #***Might need to change the length convention
    equipment: Mapped[bool] = mapped_column(Boolean(), default=False) #if needed for this program

    user_programs: Mapped[list["User_Program"]] = relationship(back_populates='program') #users following this program-- no cascade since RESTRICT blocks deleting a program in use

#Stores the user profiles created from the onboarding quiz
class User_Profile(Base):
    __tablename__ = 'user_profiles'

    id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), ForeignKey('users.id', ondelete='CASCADE'), unique=True) #one profile per user
    goal: Mapped[str] = mapped_column(String(20), nullable=False) #takes in goal from frontend multiple choice
    experience_level:Mapped[int] = mapped_column(Integer(), nullable=False) #takes in level from frontend mult choice
    days_available: Mapped[int] = mapped_column(Integer(), nullable=False) #1-6 for days available to workout
    equipment_available: Mapped[bool] = mapped_column(Boolean(), nullable=False) #whether they have equipment available in their gym

#Stores program each user is using along with current day for them
class User_Program(Base):
    __tablename__ = 'user_programs'

    id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    program_id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), ForeignKey('programs.id', ondelete='RESTRICT')) #program it comes from-- CAN NOT DELETE PROGRAM IF IN USE HERE
    user_id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), ForeignKey('users.id', ondelete='CASCADE')) #user the program is for
    current_day: Mapped[int] = mapped_column(Integer(), default=1) #current day user is on--starts at first day
    program: Mapped["Program"] = relationship(back_populates='user_programs') #access to the program
    user: Mapped["User"] = relationship(back_populates='user_programs') #access to the user

#*********** Nutrition Section *****************

#Stores each meal a user logs 
class Meal(Base):
    __tablename__ = 'meals'

    id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), primary_key=True)
    user_id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), ForeignKey('users.id', ondelete='CASCADE'))
    protein: Mapped[int] = mapped_column(Integer(), nullable=False)
    carbs: Mapped[int] = mapped_column(Integer(), nullable=False)
    fat: Mapped[int] = mapped_column(Integer(), nullable=False)
    calories: Mapped[int] = mapped_column(Integer(), nullable=False)
    user: Mapped['User'] = relationship(back_populates='users') #access to the user for this meal entry

#Stores the users macro goals
def User_Goal(Base):
    __tablename__ = 'user_goals'

    id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), primary_key=True)
    user_id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), ForeignKey('users.id', ondelete='CASCADE'))
    protein_goal: Mapped[int] = mapped_column(Integer(), nullable=False)
    carbs_goal: Mapped[int] = mapped_column(Integer(), nullable=False)
    fat_goal: Mapped[int] = mapped_column(Integer(), nullable=False)
    calories_goal: Mapped[int] = mapped_column(Integer(), nullable=False)
    user: Mapped['User'] = relationship(back_populates='users') #access to the user for this goal

#************ Health Section *************



