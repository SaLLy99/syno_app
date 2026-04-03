import pytest
from app import crud, schemas
from unittest.mock import MagicMock, patch
from passlib.context import CryptContext

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def test_verify_password():
    """
    Unit test for password verification.
    """
    password = "password123"
    hashed_password = pwd_context.hash(password)
    assert crud.verify_password(password, hashed_password)
    assert not crud.verify_password("wrongpassword", hashed_password)

def test_authenticate_user():
    """
    Unit test for user authentication logic.
    """
    mock_db = MagicMock()
    user_in_db = MagicMock()
    user_in_db.password_hash = pwd_context.hash("Password1")

    # Mock get_user_by_email to return our mock user
    with patch("app.crud.get_user_by_email", return_value=user_in_db):
        # Test successful authentication
        authenticated_user = crud.authenticate_user(mock_db, "test@example.com", "Password1")
        assert authenticated_user == user_in_db

        # Test failed authentication (wrong password)
        authenticated_user = crud.authenticate_user(mock_db, "test@example.com", "wrongpassword")
        assert not authenticated_user
