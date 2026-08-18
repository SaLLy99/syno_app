# auth.py
from datetime import datetime, timedelta
from typing import Optional
import base64
import json

from fastapi import Depends, HTTPException, status
import logging
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import JWTError, jwt
from sqlalchemy.orm import Session

from . import schemas, crud, models
from .database import get_db
from .config import settings

logger = logging.getLogger("syno.auth")

# --- JWT setup ---
def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    """Create a JWT token with expiration."""
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta if expires_delta else timedelta(minutes=settings.access_token_expire_minutes))
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, settings.secret_key, algorithm=settings.algorithm)
    return encoded_jwt

def _extract_email_from_token_payload(token: str) -> Optional[str]:
    """
    Extract the 'sub' (email) claim from a JWT token WITHOUT verifying the signature.
    Used only to check if a user with an invalid/expired token is deactivated,
    so we can provide a user-friendly recovery message.
    """
    try:
        parts = token.split(".")
        if len(parts) != 3:
            return None
        payload_b64 = parts[1]
        # Add padding if needed
        padding = 4 - len(payload_b64) % 4
        if padding != 4:
            payload_b64 += "=" * padding
        payload_bytes = base64.urlsafe_b64decode(payload_b64)
        payload = json.loads(payload_bytes)
        return payload.get("sub")
    except Exception:
        return None

# --- HTTPBearer setup for Swagger / API ---
bearer_scheme = HTTPBearer()

def get_current_active_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: Session = Depends(get_db)
) -> models.SynoUser:
    """Get the current active user from a JWT token."""
    token = credentials.credentials
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, settings.secret_key, algorithms=[settings.algorithm])
        email: str = payload.get("sub")
        if not email:
            logger.warning("JWT token missing 'sub' claim. Payload: %s", payload)
            raise credentials_exception
        token_data = schemas.TokenData(email=email)
    except JWTError:
        # Token signature is invalid or token expired.
        # Try to extract email without verification to check if user is deactivated.
        # This gives deactivated users a clear recovery path instead of a cryptic error.
        email = _extract_email_from_token_payload(token)
        if email:
            user = crud.get_user_by_email(db, email=email.lower())
            if user and user.is_deactivated:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="account.deactivated_token_invalid"
                )
        logger.warning("JWT decode failed for token: %s", token)
        raise credentials_exception

    user = crud.get_user_by_email(db, email=token_data.email)
    if not user:
        raise credentials_exception
    if user.is_deactivated:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="account.deactivated"
        )
    user.last_active_at = datetime.utcnow()
    db.commit()
    return user
