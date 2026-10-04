#creating the db tables in here that will be accessed/managed using sqlalchemy-- the python orm for using db
#orm is like a middleman between the user and the actual db, it allows you to write python object code and it translates into SQL for the real db
from sqlalchemy.orm import declarative_base
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy import String, ForeignKey, DateTime, func
from datetime import datetime
from uuid import UUID #the type of UUID for the type hints
from sqlalchemy.dialects.postgresql import UUID as PGUUID #this is the true UUID column data type

Base = declarative_base() #creates the Base call to put in the table class parameters so it knows it is a orm table

class User(Base):
    __tablename__ = 'users'
    id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), primary_key=True)
    username: Mapped[str] = mapped_column(String(30), unique=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())