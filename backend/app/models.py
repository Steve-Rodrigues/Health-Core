#creating the db tables in here that will be accessed/managed using sqlalchemy-- the python orm for using db
#orm is like a middleman between the user and the actual db, it allows you to write python object code and it translates into SQL for the real db
from datetime import datetime, date, time

from sqlalchemy.orm import declarative_base
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy import String, ForeignKey, DateTime, UniqueConstraint, func, Integer, Float, Boolean, Date, Time
from uuid import UUID, uuid4 #UUID is the type for the type hints, uuid4 generates new ids
from sqlalchemy.dialects.postgresql import UUID as PGUUID #this is the true UUID column data type

Base = declarative_base() #creates the Base call to put in the table class parameters so it knows it is a orm table

#Stores all info about each user including goals they made from our onboarding survey
class User(Base):
    __tablename__ = 'users'
    id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), primary_key=True) #id is set to the one from supabase
    username: Mapped[str] = mapped_column(String(30), unique=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    current_weight: Mapped[float] = mapped_column(Float(), nullable=True)
    height: Mapped[float] = mapped_column(Float(), nullable=True)
    goal_weight: Mapped[float] = mapped_column(Float(), nullable=True)
    workouts_per_week_goal: Mapped[int | None] = mapped_column(Integer(), nullable=True)
    sleep_goal: Mapped[float] = mapped_column(Float(), nullable=True)
    #one-to-many sides of the relationships-- cascade lives here on the parent so deleting a user deletes their rows too
    workouts: Mapped[list["Workout"]] = relationship(back_populates='user', cascade='all, delete-orphan', passive_deletes=True)
    user_programs: Mapped[list["User_Program"]] = relationship(back_populates='user', cascade='all, delete-orphan', passive_deletes=True)
    meals: Mapped[list["Meal"]] = relationship(back_populates='user', cascade='all, delete-orphan', passive_deletes=True)
    nutrition_goal: Mapped["User_Goal_Nutrition"] = relationship(back_populates='user', cascade='all, delete-orphan', passive_deletes=True)
    sleeps: Mapped[list["Sleep"]] = relationship(back_populates='user', cascade='all, delete-orphan', passive_deletes=True)

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

#Tracks each set a user completes-- As of rn it only sends the data for once an entire exercise is done. So sends sets/reps/weight used
class Workout_Set(Base):
    __tablename__ = "workout_sets"

    id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    workout_id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), ForeignKey('workouts.id', ondelete='RESTRICT')) #links set to an active workout
    exercise_id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), ForeignKey('exercises.id', ondelete='RESTRICT')) #links exersice to an exersice in our db
    reps: Mapped[int] = mapped_column(Integer(), default=0) #this is a column for the number of reps in the set, it is an integer
    weight: Mapped[float] = mapped_column(Float(), default=0) #this is a column for the weight used in the set, it is a float
    sets: Mapped[int] = mapped_column(Integer(), default=0)

#Holds all exersices we store for use
class Exercise(Base):
    __tablename__ = "exercises"

    id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    name: Mapped[str] = mapped_column(String(), nullable=False, unique=True) #exersice name
    instructions: Mapped[str] = mapped_column(String(), nullable=False) #exersice instructions
    equipment: Mapped[str | None] = mapped_column(String()) #holds the equipment needed
    level: Mapped[str] = mapped_column(String()) #level of exersice-- beginner, intermiediate, expert
    movement_type: Mapped[str | None] = mapped_column(String())#holds type of movement(push/pull/static)
    primary_muscle: Mapped[str] = mapped_column(String())#holds the primary muscle its hitting
    exercise_category: Mapped[str] = mapped_column(String())#holds category of exercise-- like strength, plyos, powerlifting
    mechanic: Mapped[str | None] = mapped_column(String(), nullable=True)#compound or isolation-- used to pick main lifts vs accessories


#Stores the program using an exersice along with reps/sets and day used on the program
class Program_Exercise(Base):
    __tablename__ = "program_exercises"

    id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    program_id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), ForeignKey('programs.id', ondelete='CASCADE')) #the program this exercise belongs to
    exercise_id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), ForeignKey('exercises.id', ondelete='CASCADE')) #the exercise used in the program
    day: Mapped[int] = mapped_column(Integer(), nullable=False) #this is a column for the day of the exercise in the program, it is an integer
    sets: Mapped[int] = mapped_column(Integer(), nullable=False) #this is a column for the number of sets in the exercise, it is an integer
    reps: Mapped[int] = mapped_column(Integer(), nullable=False) #this is a column for the number of reps in the exercise, it is an integer
    order: Mapped[int] = mapped_column(Integer(), nullable=False, server_default='0') #position of the exercise within its day-- main lifts first

#Stores all of the programs we create
class Program(Base):
    __tablename__ = 'programs'

    id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    name: Mapped[str] = mapped_column(String(), unique=True, nullable=False)
    description: Mapped[str] = mapped_column(String(), nullable=False)
    difficulty: Mapped[str]  = mapped_column(String(), nullable=False) #beginner/intermediate/expert
    number_of_days: Mapped[int] = mapped_column(Integer(), nullable=False) #per week-- use this to get the current day
    goal: Mapped[str] = mapped_column(String(), nullable=False) # could be bulk, shredding, etc...
    program_length: Mapped[int | None] = mapped_column(Integer(), nullable=True) #***Might need to change the length convention
    equipment_level: Mapped[str] = mapped_column(String(), nullable=False, server_default='gym') #bodyweight/home/gym-- each level includes the ones before it
    split: Mapped[str] = mapped_column(String(), nullable=False, server_default='full_body') #full_body/upper_lower/push_pull_legs/hybrid

    user_programs: Mapped[list["User_Program"]] = relationship(back_populates='program') #users following this program-- no cascade since RESTRICT blocks deleting a program in use

    
#Stores program each user is using along with current day for them and their goals that they filled out in the quiz
class User_Program(Base):
    __tablename__ = 'user_programs'

    id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    goal: Mapped[str] = mapped_column(String(), nullable=False) #purpose of the program
    program_id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), ForeignKey('programs.id', ondelete='RESTRICT')) #program it comes from-- CAN NOT DELETE PROGRAM IF IN USE HERE
    user_id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), ForeignKey('users.id', ondelete='CASCADE')) #user the program is for
    current_day: Mapped[int] = mapped_column(Integer(), default=0) #current day user is on-- always add 1 and check if adding 1 is over the number of days of our program, if so go back to day 1
    experience_level:Mapped[int] = mapped_column(Integer(), nullable=False) #takes in level from frontend mult choice
    days_available: Mapped[int] = mapped_column(Integer(), nullable=False) #1-6 for days available to workout
    equipment_available: Mapped[bool] = mapped_column(Boolean(), nullable=False) #whether they have equipment available in their gym
    program: Mapped["Program"] = relationship(back_populates='user_programs') #access to the program
    user: Mapped["User"] = relationship(back_populates='user_programs') #access to the user
#*********** Nutrition Section *****************

#Stores each meal a user logs 
class Meal(Base):
    __tablename__ = 'meals'

    id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    meal_date: Mapped[date] = mapped_column(Date(), index=True) #holds the yyyy-mm-dd for a meal so we can filter by day in the frontend
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    user_id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), ForeignKey('users.id', ondelete='CASCADE'))
    meal_name: Mapped[str] = mapped_column(String(), nullable=False) #name of meal
    meal_type: Mapped[str] = mapped_column(String(), nullable=False) #breakfast/lunch/dinner
    protein: Mapped[int] = mapped_column(Integer(), nullable=False, default=0)
    carbs: Mapped[int] = mapped_column(Integer(), nullable=False,default=0)
    fat: Mapped[int] = mapped_column(Integer(), nullable=False,default=0)
    calories: Mapped[int] = mapped_column(Integer(), nullable=False, default=0)
    user: Mapped['User'] = relationship(back_populates='meals') #access to the user for this meal entry

#Stores the users macro goals
class User_Goal_Nutrition(Base):
    __tablename__ = 'user_goals'

    id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), ForeignKey('users.id', ondelete='CASCADE'), unique=True)
    protein_goal: Mapped[int] = mapped_column(Integer(), nullable=False)
    carbs_goal: Mapped[int] = mapped_column(Integer(), nullable=False)
    fat_goal: Mapped[int] = mapped_column(Integer(), nullable=False)
    calories_goal: Mapped[int] = mapped_column(Integer(), nullable=False)
    user: Mapped['User'] = relationship(back_populates='nutrition_goal') #access to the user for this goal

#************ Health Section *************

#Stores the sleep data the user stores each night
class Sleep(Base):
    __tablename__ = 'sleeps'
    __table_args__ = (UniqueConstraint('user_id', 'sleep_date',name='uq_sleeps_user_id_sleep_date'),)  # one sleep per user per day

    id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), ForeignKey('users.id', ondelete='CASCADE')) #user this sleep entry belongs to
    sleep_date: Mapped[date] = mapped_column(Date()) #using the wake_date from client as this value. It's the day for this sleep record
    bed_time: Mapped[time] = mapped_column(Time()) #in format 00:00 from frontend
    wake_time: Mapped[time] = mapped_column(Time()) #in format 00:00 from frontend
    duration_mins: Mapped[int] = mapped_column(Integer()) #amount of mins that were slept that night
    quality: Mapped[int] = mapped_column(Integer()) #1-5 rating
    notes: Mapped[str|None] = mapped_column(String(), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    user: Mapped['User'] = relationship(back_populates='sleeps') #access to the user for this sleep entry-- can grab the goal from here

#Stores the health resources we offer
class Health_Resource(Base):
    __tablename__ = 'health_resources'

    id:Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    title:Mapped[str] = mapped_column(String(50), nullable=False, unique=True)
    description:Mapped[str] = mapped_column(String(), nullable=False)
    category: Mapped[str] = mapped_column(String, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

#Stores quotes we are holding
class Quote(Base):
    __tablename__ = 'quotes'

    id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    quote_text: Mapped[str] = mapped_column(String(), nullable=False, unique=True)
    author: Mapped[str] = mapped_column(String(), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

#Stores info we have on first-aid stuff
class First_Aid(Base):
    __tablename__ = 'first_aids'

    id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    name: Mapped[str] = mapped_column(String(), nullable=False)
    category: Mapped[str] = mapped_column(String(), nullable=False)
    summary: Mapped[str] = mapped_column(String())
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())



