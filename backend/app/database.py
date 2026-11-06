#set up connection to the postgresql db in this file
#works by creating engine(connection to the db), session(workspace for when using the db)
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.config import settings #needed for the db url

engine = create_engine(
    settings.database_url,
    connect_args={"sslmode": "require"},
    pool_pre_ping=True,
)

SessionLocal = sessionmaker(bind=engine) #calling this creates the workspace to use the db

#creating the dependency to be injected in our endpoint functions so we can perform db operations
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


