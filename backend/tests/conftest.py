import sys
import os
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

# Add the project root directory to the Python path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from app.main import app
from app.database import Base, get_db
from app import models, crud, schemas

# Use an in-memory SQLite database for testing
SQLALCHEMY_DATABASE_URL = "sqlite:///:memory:"

engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Dependency override to use the test database
def override_get_db():
    try:
        db = TestingSessionLocal()
        yield db
    finally:
        db.close()

# Apply the dependency override to the app
app.dependency_overrides[get_db] = override_get_db

@pytest.fixture(scope="function")
def db_session():
    """
    Fixture to provide a clean database session for each test function.
    It creates the tables, yields the session, and then drops the tables.
    """
    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()
        Base.metadata.drop_all(bind=engine)

@pytest.fixture(scope="function")
def seed_db(db_session):
    """
    Fixture to seed the database with necessary lookup data for tests.
    """
    db_session.execute("INSERT INTO sexes (id, name) VALUES (1, 'Male'), (2, 'Female')")
    db_session.execute("INSERT INTO orientations (id, name) VALUES (1, 'Straight'), (2, 'Gay')")
    db_session.execute("INSERT INTO locations (id, name,type,parent_id) VALUES (2, 'USA', 'country', null)")
    db_session.execute("INSERT INTO locations (id, name,type,parent_id) VALUES (3, 'New York', 'city', 2)")
    db_session.execute("INSERT INTO hobbies (id, name) VALUES (1, 'Yoga'), (2, 'Hiking')")
    db_session.commit()
    return db_session


@pytest.fixture(scope="module")
def client():
    """
    Fixture to provide a TestClient instance for making API requests.
    """
    with TestClient(app) as c:
        yield c

@pytest.fixture(scope="function")
def test_user(db_session):
    """
    Fixture to create a standard test user in the database.
    """
    user_create = schemas.UserCreate(email="user@example.com", password="password123")
    return crud.create_user(db=db_session, user=user_create)

@pytest.fixture(scope="function")
def test_user2(db_session):
    """
    Fixture to create a second test user for interaction tests (e.g., blocking).
    """
    user_create = schemas.UserCreate(email="user2@example.com", password="password123")
    return crud.create_user(db=db_session, user=user_create)
