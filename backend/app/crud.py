from datetime import datetime, timedelta
from sqlalchemy.sql import func
from sqlalchemy.orm import Session, joinedload, load_only
from typing import List, Optional
from passlib.context import CryptContext
from fastapi import UploadFile

from . import models, schemas


# --- Password Management ---
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a plaintext password against a hashed password."""
    return pwd_context.verify(plain_password, hashed_password)

def hash_password(password: str) -> str:
    """Hash a plaintext password using bcrypt."""
    # bcrypt has a 72-byte limit for the password.
    if len(password.encode('utf-8')) > 72:
        password = password.encode('utf-8')[:72].decode('utf-8', 'ignore')
    return pwd_context.hash(password)

# --- User Management ---

def get_user_by_email(db: Session, email: str) -> Optional[models.SynoUser]:
    """Fetch a single user by their email address."""
    return db.query(models.SynoUser).filter(models.SynoUser.email == email).first()

def create_user(db: Session, user: schemas.UserCreate) -> models.SynoUser:
    """Create a new user with a hashed password."""
    hashed_password = hash_password(user.password)
    db_user = models.SynoUser(email=user.email, password_hash=hashed_password)
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

# --- Profile Management ---

def get_profile(db: Session, profile_id: int) -> Optional[models.Profile]:
    return db.query(models.Profile).filter(models.Profile.id == profile_id).first()

def get_profile_by_user_id(db: Session, user_id: int) -> Optional[models.Profile]:
    """Fetch a single profile by the user's ID."""
    return db.query(models.Profile).options(
        joinedload(models.Profile.location).joinedload(models.Location.parent),
        joinedload(models.Profile.sex),
        joinedload(models.Profile.orientation),
        joinedload(models.Profile.professions),
        joinedload(models.Profile.educations),
        joinedload(models.Profile.hobbies),
        joinedload(models.Profile.intentions),
        joinedload(models.Profile.core_values),
        joinedload(models.Profile.photos)
    ).filter(models.Profile.user_id == user_id).first()

async def create_profile(db: Session, profile_in: schemas.ProfileUpdate, user_id: int, photos: List[UploadFile]):
    """Creates a new profile for a user, including photos."""
    profile_data = profile_in.dict(exclude_unset=True)
    rel_keys = ['intention_ids', 'core_value_ids', 'hobby_ids', 'profession_ids', 'education_ids']
    profile_args = {k: v for k, v in profile_data.items() if k not in rel_keys}

    db_profile = models.Profile(**profile_args, user_id=user_id)
    db.add(db_profile)
    print('profile_data ',profile_data)
  

    # Handle relationships
    if 'intention_ids' in profile_data and profile_data['intention_ids']:
        db_profile.intentions = db.query(models.Intentions).filter(models.Intentions.id.in_(profile_data['intention_ids'])).all()
    if 'core_value_ids' in profile_data and profile_data['core_value_ids']:
        db_profile.core_values = db.query(models.CoreValue).filter(models.CoreValue.id.in_(profile_data['core_value_ids'])).all()
    if 'hobby_ids' in profile_data and profile_data['hobby_ids']:
        db_profile.hobbies = db.query(models.Hobby).filter(models.Hobby.id.in_(profile_data['hobby_ids'])).all()
    if 'profession_ids' in profile_data and profile_data['profession_ids']:
        db_profile.professions = db.query(models.Profession).filter(models.Profession.id.in_(profile_data['profession_ids'])).all()
    if 'education_ids' in profile_data and profile_data['education_ids']:
        db_profile.educations = db.query(models.Education).filter(models.Education.id.in_(profile_data['education_ids'])).all()    

    # Add photos
    for i, photo_file in enumerate(photos):
        photo_data = await photo_file.read()
        new_photo = models.UserPhoto(
            photo_data=photo_data,
            is_primary=(i == 0),
            upload_order=i
        )
        # By appending to the relationship, SQLAlchemy handles the linking
        # during the commit.
        db_profile.photos.append(new_photo)
    
    db.commit()
    db.refresh(db_profile)
    return db_profile

async def update_profile(db: Session, db_profile: models.Profile, profile_in: schemas.ProfileUpdate):
    """Updates a user's profile."""
    update_data = profile_in.dict(exclude_unset=True)

    for key, value in update_data.items():
        # Exclude relationship keys from direct setattr, as they are handled separately
        if hasattr(db_profile, key) and key not in ['intention_ids', 'core_value_ids', 'hobby_ids', 'profession_ids', 'education_ids']:
            setattr(db_profile, key, value)

    # Handle relationships (many-to-many) by clearing existing and adding new ones
    if 'intention_ids' in update_data:
        db_profile.intentions.clear()
        if update_data.get('intention_ids'):
            new_intentions = db.query(models.Intentions).filter(models.Intentions.id.in_(update_data['intention_ids'])).all()
            db_profile.intentions.extend(new_intentions)

    if 'core_value_ids' in update_data:
        db_profile.core_values.clear()
        if update_data.get('core_value_ids'):
            db_profile.core_values.extend(db.query(models.CoreValue).filter(models.CoreValue.id.in_(update_data['core_value_ids'])).all())

    if 'hobby_ids' in update_data:
        db_profile.hobbies.clear()
        if update_data.get('hobby_ids'):
            db_profile.hobbies.extend(db.query(models.Hobby).filter(models.Hobby.id.in_(update_data['hobby_ids'])).all())

    if 'profession_ids' in update_data:
        db_profile.professions.clear()
        if update_data.get('profession_ids'):
            db_profile.professions.extend(db.query(models.Profession).filter(models.Profession.id.in_(update_data['profession_ids'])).all())

    if 'education_ids' in update_data:
        db_profile.educations.clear()
        if update_data.get('education_ids'):
            db_profile.educations.extend(db.query(models.Education).filter(models.Education.id.in_(update_data['education_ids'])).all())

    db.add(db_profile)
    db.commit()
    db.refresh(db_profile)
    return db_profile

# Note: The `create_profile` function already correctly handles the initial assignment
# of these many-to-many relationships and photos, so no changes are needed there.

# --- Static Data ---

def get_sexes(db: Session) -> List[models.Sex]:
    return db.query(models.Sex).all()

def get_orientations(db: Session) -> List[models.Orientation]:
    return db.query(models.Orientation).all()

def get_hobbies(db: Session, query: Optional[str] = None) -> List[models.Hobby]:
    db_query = db.query(models.Hobby)
    if query:
        db_query = db_query.filter(models.Hobby.name.ilike(f"%{query}%"))
    return db_query.all()

def get_educations(db: Session, query: Optional[str] = None) -> List[models.Education]:
    db_query = db.query(models.Education)
    if query:
        db_query = db_query.filter(models.Education.name.ilike(f"%{query}%"))
    return db_query.all()

def get_professions(db: Session, query: Optional[str] = None) -> List[models.Profession]:
    db_query = db.query(models.Profession)
    if query:
        db_query = db_query.filter(models.Profession.name.ilike(f"%{query}%"))
    return db_query.all()

def get_core_values(db: Session) -> List[models.CoreValue]:
    return db.query(models.CoreValue).all()

def get_intentions(db: Session) -> List[models.Intentions]:
   return db.query(models.Intentions).all()

def search_locations(db: Session, query: Optional[str] = None) -> List[models.Location]:
    """
    Search for city locations by name.
    If no query is provided, it returns a default list of cities.
    """
    # Base query to only include cities that have a parent (country)
    db_query = db.query(models.Location).options(joinedload(models.Location.parent)).filter(
        models.Location.type.ilike('city'),
        models.Location.parent_id.isnot(None)
    )

    if query:
        # If a search query is provided, filter by name
        db_query = db_query.filter(models.Location.name.ilike(f"%{query}%"))

    return db_query.limit(20).all()

# --- Photo Management ---

async def update_primary_photo(db: Session, db_profile: models.Profile, primary_photo: UploadFile):
    existing_primary = db.query(models.UserPhoto).filter(models.UserPhoto.profile_id == db_profile.id, models.UserPhoto.is_primary == True).first()
    if existing_primary:
        existing_primary.is_primary = False
        db.add(existing_primary)
    photo_data = await primary_photo.read()
    db.add(models.UserPhoto(profile_id=db_profile.id, photo_data=photo_data, is_primary=True, upload_order=0))
    db.commit()

async def add_additional_photos(db: Session, db_profile: models.Profile, photos: List[UploadFile]):
    max_order = db.query(func.max(models.UserPhoto.upload_order)).filter(models.UserPhoto.profile_id == db_profile.id).scalar() or 0
    for i, photo_file in enumerate(photos):
        photo_data = await photo_file.read()
        db.add(models.UserPhoto(profile_id=db_profile.id, photo_data=photo_data, is_primary=False, upload_order=max_order + i + 1))
    db.commit()

def update_core_values(update_data: schemas.CoreValuAddition, db: Session) -> Optional[List[models.CoreValue]]:
    """Replaces the core values for a given profile with a new list of IDs."""
    profile = db.query(models.Profile).filter(models.Profile.id == update_data.profile_id).first()
    if not profile:
        return None  # Let the endpoint handle the 404

    # Fetch the CoreValue objects for the given IDs
    new_values = db.query(models.CoreValue).filter(models.CoreValue.id.in_(update_data.core_value_id)).all()

    # Replace the existing collection with the new one.
    profile.core_values = new_values

    db.commit()
    db.refresh(profile)
    return profile.core_values
def get_photo_by_id(db: Session, photo_id: int, user_id: int) -> Optional[models.UserPhoto]:
    return db.query(models.UserPhoto).join(models.Profile).filter(models.UserPhoto.id == photo_id, models.Profile.user_id == user_id).first()

def delete_photo(db: Session, photo_id: int, user_id: int) -> bool:
    photo = get_photo_by_id(db, photo_id, user_id)
    if not photo: return False
    if photo.is_primary:
        next_photo = db.query(models.UserPhoto).filter(models.UserPhoto.profile_id == photo.profile_id, models.UserPhoto.id != photo_id).order_by(models.UserPhoto.upload_order).first()
        if next_photo:
            next_photo.is_primary = True
            db.add(next_photo)
    db.delete(photo)
    db.commit()
    return True

# --- User Actions ---

def deactivate_user(db: Session, user_id: int) -> bool:
    """Soft-delete: flag the user as deactivated instead of hard-deleting."""
    user = db.query(models.SynoUser).filter(models.SynoUser.id == user_id).first()
    if not user:
        return False
    user.is_deactivated = True
    user.deactivated_at = datetime.utcnow()
    db.commit()
    return True

def reactivate_user(db: Session, user_id: int) -> bool:
    """Restore a deactivated user's account to active status."""
    user = db.query(models.SynoUser).filter(models.SynoUser.id == user_id).first()
    if not user or not user.is_deactivated:
        return False
    user.is_deactivated = False
    user.deactivated_at = None
    db.commit()
    return True

def permanently_delete_user(db: Session, user_id: int) -> bool:
    """Hard-delete a user account (used after recovery window expires)."""
    user = db.query(models.SynoUser).filter(models.SynoUser.id == user_id).first()
    if not user:
        return False
    db.delete(user)
    db.commit()
    return True

def cleanup_expired_deactivated_accounts(db: Session, days: int = 30) -> int:
    """Permanently delete deactivated accounts older than the recovery window."""
    cutoff = datetime.utcnow() - timedelta(days=days)
    expired = db.query(models.SynoUser).filter(
        models.SynoUser.is_deactivated == True,
        models.SynoUser.deactivated_at < cutoff
    ).all()
    count = len(expired)
    for user in expired:
        db.delete(user)
    if count > 0:
        db.commit()
    return count

def block_user(db: Session, blocker_id: int, blocked_id: int) -> Optional[bool]:
    if blocker_id == blocked_id: return None
    if not db.query(models.SynoUser).filter(models.SynoUser.id == blocked_id).first(): return None
    existing = db.execute(models.user_blocks.select().where((models.user_blocks.c.blocker_id == blocker_id) & (models.user_blocks.c.blocked_id == blocked_id))).first()
    if not existing:
        db.execute(models.user_blocks.insert().values(blocker_id=blocker_id, blocked_id=blocked_id))
        db.commit()
    return True

def unblock_user(db: Session, blocker_id: int, blocked_id: int):
    db.execute(models.user_blocks.delete().where((models.user_blocks.c.blocker_id == blocker_id) & (models.user_blocks.c.blocked_id == blocked_id)))
    db.commit()

def get_blocked_users(db: Session, blocker_id: int) -> List[models.Profile]:
    """Fetch profiles of users blocked by the current user."""
    stmt = models.user_blocks.select().where(models.user_blocks.c.blocker_id == blocker_id)
    result = db.execute(stmt).fetchall()
    blocked_ids = [row.blocked_id for row in result]
    
    if not blocked_ids:
        return []
        
    return db.query(models.Profile).options(
        joinedload(models.Profile.sex),
        joinedload(models.Profile.photos).load_only(models.UserPhoto.id, models.UserPhoto.is_primary, models.UserPhoto.upload_order)
    ).filter(models.Profile.user_id.in_(blocked_ids)).all()


def get_blocked_user_ids(db: Session, user_id: int) -> set:
    """Get set of user IDs that are blocked by or have blocked the given user."""
    blocked_by_me = db.query(models.user_blocks.c.blocked_id).filter(
        models.user_blocks.c.blocker_id == user_id
    ).all()
    blocked_me = db.query(models.user_blocks.c.blocker_id).filter(
        models.user_blocks.c.blocked_id == user_id
    ).all()
    return {r[0] for r in blocked_by_me} | {r[0] for r in blocked_me}

def get_profile_by_name(db: Session, name: str) -> Optional[models.Profile]:
    return db.query(models.Profile).filter(models.Profile.name.ilike(name)).first()

def create_otp(db: Session, email: str, code: str, expires_in_minutes: int = 10):
    """Store a new OTP in the database."""
    # Securely hash the OTP before storing
    otp_hash = hash_password(code)
    expires_at = datetime.utcnow() + timedelta(minutes=expires_in_minutes)
    db_otp = models.OTP(email=email.lower(), code=code, otp_hash=otp_hash, expires_at=expires_at)
    db.add(db_otp)
    db.commit()
    db.refresh(db_otp)
    return db_otp

def create_otp_phone(db: Session, phone: str, code: str, expires_in_minutes: int = 10):
    """Store a new phone OTP in the database."""
    otp_hash = hash_password(code)
    expires_at = datetime.utcnow() + timedelta(minutes=expires_in_minutes)
    db_otp = models.OTP(phone_number=phone, code=code, otp_hash=otp_hash, expires_at=expires_at)
    db.add(db_otp)
    db.commit()
    db.refresh(db_otp)
    return db_otp

def cleanup_otps(db: Session):
    """
    Removes expired or already used OTP records from the database.
    """
    now = datetime.utcnow()
    db.query(models.OTP).filter(
        (models.OTP.expires_at < now) | (models.OTP.used_flag == True)
    ).delete(synchronize_session=False)
    db.commit()

def verify_otp_logic(db: Session, email: str, provided_code: str):
    """
    Business logic for OTP verification.
    Returns (success_bool, translation_key)
    """
    otp_record = db.query(models.OTP).filter(
        models.OTP.email == email.lower(),
        models.OTP.used_flag == False
    ).order_by(models.OTP.created_at.desc()).first()

    if not otp_record:
        return False, "otp.invalid_code"
    
    if otp_record.expires_at < datetime.utcnow():
        return False, "otp.expired_code"

    if otp_record.attempts >= 3:
        return False, "otp.rate_limit_error"

    # Increment attempts even if password fails
    otp_record.attempts += 1
    
    if not pwd_context.verify(provided_code, otp_record.otp_hash):
        db.commit()
        return False, "otp.invalid_code"

    # Success
    otp_record.used_flag = True
    db.commit()
    return True, "otp.success"


# --- Incoming Likes ---

def get_received_likes(db: Session, user_id: int) -> List[dict]:
    blocked_ids = get_blocked_user_ids(db, user_id)
    matches = db.query(models.Match).filter(
        models.Match.matched_user_id == user_id,
        models.Match.status == "accepted",
        ~models.Match.user_id.in_(blocked_ids) if blocked_ids else True,
    ).order_by(models.Match.created_at.desc()).all()
    result = []
    for match in matches:
        reverse = db.query(models.Match).filter(
            models.Match.user_id == user_id,
            models.Match.matched_user_id == match.user_id,
            models.Match.status == "accepted"
        ).first()
        if reverse:
            continue
        profile = db.query(models.Profile).options(
            joinedload(models.Profile.photos).load_only(models.UserPhoto.id, models.UserPhoto.is_primary, models.UserPhoto.upload_order),
            joinedload(models.Profile.sex),
            joinedload(models.Profile.location),
        ).filter(models.Profile.user_id == match.user_id).first()
        if not profile:
            continue
        primary_photo = next((p for p in profile.photos if p.is_primary), (profile.photos[0] if profile.photos else None))
        result.append({
            "match_id": match.id,
            "user_id": match.user_id,
            "compatibility_score": match.compatibility_score,
            "created_at": match.created_at,
            "profile": {
                "id": profile.user_id,
                "user_id": profile.user_id,
                "name": profile.name,
                "last_name": profile.last_name,
                "birth_date": profile.birth_date.isoformat() if profile.birth_date else None,
                "bio": profile.bio,
                "location": {"id": profile.location.id, "name": profile.location.name, "latitude": profile.location.latitude, "longitude": profile.location.longitude} if profile.location else None,
                "sex": {"id": profile.sex.id, "name": profile.sex.name} if profile.sex else None,
                "photo_url": f"/api/photos/{primary_photo.id}" if primary_photo else None,
            }
        })
    return result


def get_received_like_user_ids(db: Session, user_id: int) -> List[int]:
    blocked_ids = get_blocked_user_ids(db, user_id)
    matches = db.query(models.Match).filter(
        models.Match.matched_user_id == user_id,
        models.Match.status == "accepted",
        ~models.Match.user_id.in_(blocked_ids) if blocked_ids else True,
    ).all()
    user_ids = []
    for match in matches:
        reverse = db.query(models.Match).filter(
            models.Match.user_id == user_id,
            models.Match.matched_user_id == match.user_id,
            models.Match.status == "accepted"
        ).first()
        if not reverse:
            user_ids.append(match.user_id)
    return user_ids


def accept_incoming_like(db: Session, match_id: int, user_id: int) -> Optional[models.Match]:
    incoming = db.query(models.Match).filter(
        models.Match.id == match_id,
        models.Match.matched_user_id == user_id,
        models.Match.status == "accepted"
    ).first()
    if not incoming:
        return None
    reverse = db.query(models.Match).filter(
        models.Match.user_id == user_id,
        models.Match.matched_user_id == incoming.user_id
    ).first()
    if reverse:
        reverse.status = "accepted"
        if incoming.compatibility_score is not None:
            reverse.compatibility_score = incoming.compatibility_score
        db.commit()
        db.refresh(reverse)
        return reverse
    new_match = models.Match(
        user_id=user_id,
        matched_user_id=incoming.user_id,
        status="accepted",
        compatibility_score=incoming.compatibility_score
    )
    db.add(new_match)
    db.commit()
    db.refresh(new_match)
    return new_match


def decline_incoming_like(db: Session, match_id: int, user_id: int) -> bool:
    incoming = db.query(models.Match).filter(
        models.Match.id == match_id,
        models.Match.matched_user_id == user_id,
        models.Match.status == "accepted"
    ).first()
    if not incoming:
        return False
    incoming.status = "declined"
    db.commit()
    return True


# --- Match Management ---

def create_match(db: Session, user_id: int, matched_user_id: int, status: str = "pending", compatibility_score: int = None) -> Optional[models.Match]:
    if user_id == matched_user_id:
        return None
    existing = db.query(models.Match).filter(
        models.Match.user_id == user_id,
        models.Match.matched_user_id == matched_user_id
    ).first()
    if existing:
        existing.status = status
        if compatibility_score is not None:
            existing.compatibility_score = compatibility_score
        db.commit()
        db.refresh(existing)
        return existing
    match = models.Match(
        user_id=user_id,
        matched_user_id=matched_user_id,
        status=status,
        compatibility_score=compatibility_score
    )
    db.add(match)
    db.commit()
    db.refresh(match)
    return match

def update_match_status(db: Session, match_id: int, user_id: int, status: str) -> Optional[models.Match]:
    match = db.query(models.Match).filter(
        models.Match.id == match_id,
        models.Match.user_id == user_id
    ).first()
    if not match:
        return None
    match.status = status
    db.commit()
    db.refresh(match)
    return match

def get_matches_for_user(db: Session, user_id: int) -> List[models.Match]:
    return db.query(models.Match).filter(
        models.Match.user_id == user_id
    ).order_by(models.Match.created_at.desc()).all()

def get_accepted_matches_for_user(db: Session, user_id: int) -> List[models.Match]:
    return db.query(models.Match).filter(
        models.Match.user_id == user_id,
        models.Match.status == "accepted"
    ).order_by(models.Match.created_at.desc()).all()

def get_mutual_match(db: Session, user_id: int, other_user_id: int) -> Optional[models.Match]:
    match_a = db.query(models.Match).filter(
        models.Match.user_id == user_id,
        models.Match.matched_user_id == other_user_id,
        models.Match.status == "accepted"
    ).first()
    match_b = db.query(models.Match).filter(
        models.Match.user_id == other_user_id,
        models.Match.matched_user_id == user_id,
        models.Match.status == "accepted"
    ).first()
    if match_a and match_b:
        return match_a
    return None

def is_mutual_match(db: Session, user_id: int, other_user_id: int) -> bool:
    return get_mutual_match(db, user_id, other_user_id) is not None

def delete_match(db: Session, match_id: int, user_id: int) -> bool:
    match = db.query(models.Match).filter(
        models.Match.id == match_id,
        models.Match.user_id == user_id
    ).first()
    if not match:
        return False
    db.delete(match)
    db.commit()
    return True


# --- Message Management ---

def create_message(db: Session, match_id: int, sender_id: int, content: str = None, image_url: str = None, video_url: str = None, gif_url: str = None, message_type: str = "text") -> Optional[models.Message]:
    match = db.query(models.Match).filter(models.Match.id == match_id).first()
    if not match:
        return None
    if match.user_id != sender_id and match.matched_user_id != sender_id:
        return None
    message = models.Message(
        match_id=match_id,
        sender_id=sender_id,
        content=content,
        image_url=image_url,
        video_url=video_url,
        gif_url=gif_url,
        message_type=message_type
    )
    db.add(message)
    db.commit()
    db.refresh(message)
    return message

def get_messages_for_match(db: Session, match_id: int, user_id: int) -> List[models.Message]:
    match = db.query(models.Match).filter(models.Match.id == match_id).first()
    if not match:
        return []
    if match.user_id != user_id and match.matched_user_id != user_id:
        return []
    reverse_match = db.query(models.Match).filter(
        models.Match.user_id == match.matched_user_id,
        models.Match.matched_user_id == match.user_id,
    ).first()
    match_ids = [match_id]
    if reverse_match and reverse_match.id != match_id:
        match_ids.append(reverse_match.id)
    messages = db.query(models.Message).filter(
        models.Message.match_id.in_(match_ids)
    ).order_by(models.Message.created_at.asc()).all()
    return messages

def mark_messages_read(db: Session, match_id: int, user_id: int):
    match = db.query(models.Match).filter(models.Match.id == match_id).first()
    match_ids = [match_id]
    if match:
        reverse_match = db.query(models.Match).filter(
            models.Match.user_id == match.matched_user_id,
            models.Match.matched_user_id == match.user_id
        ).first()
        if reverse_match and reverse_match.id != match_id:
            match_ids.append(reverse_match.id)
    db.query(models.Message).filter(
        models.Message.match_id.in_(match_ids),
        models.Message.sender_id != user_id,
        models.Message.is_read == False
    ).update({"is_read": True})
    db.commit()

def delete_chat_messages(db: Session, match_id: int, user_id: int) -> bool:
    match = db.query(models.Match).filter(models.Match.id == match_id).first()
    if not match:
        return False
    if match.user_id != user_id and match.matched_user_id != user_id:
        return False
    db.query(models.Message).filter(models.Message.match_id == match_id).delete()
    reverse_match = db.query(models.Match).filter(
        models.Match.user_id == match.matched_user_id,
        models.Match.matched_user_id == match.user_id
    ).first()
    if reverse_match:
        db.query(models.Message).filter(models.Message.match_id == reverse_match.id).delete()
    db.commit()
    return True


def delete_single_message(db: Session, message_id: int, user_id: int) -> Optional[models.Message]:
    message = db.query(models.Message).filter(models.Message.id == message_id).first()
    if not message:
        return None
    if message.sender_id != user_id:
        return None
    db.delete(message)
    db.commit()
    return message


def edit_message(db: Session, message_id: int, user_id: int, new_content: str) -> Optional[models.Message]:
    message = db.query(models.Message).filter(
        models.Message.id == message_id,
        models.Message.sender_id == user_id
    ).first()
    if not message:
        return None
    message.content = new_content
    message.is_edited = True
    db.commit()
    db.refresh(message)
    return message


def get_unread_count(db: Session, match_id: int, user_id: int) -> int:
    return db.query(models.Message).filter(
        models.Message.match_id == match_id,
        models.Message.sender_id != user_id,
        models.Message.is_read == False
    ).count()

def get_chat_list(db: Session, user_id: int) -> List[dict]:
    blocked_ids = get_blocked_user_ids(db, user_id)
    matches = db.query(models.Match).filter(
        models.Match.user_id == user_id,
        models.Match.status == "accepted",
        ~models.Match.matched_user_id.in_(blocked_ids) if blocked_ids else True,
    ).order_by(models.Match.created_at.desc()).all()
    result = []
    seen_pairs = set()
    for match in matches:
        reverse_match = db.query(models.Match).filter(
            models.Match.user_id == match.matched_user_id,
            models.Match.matched_user_id == user_id,
            models.Match.status == "accepted"
        ).first()
        pair_key = (min(user_id, match.matched_user_id), max(user_id, match.matched_user_id))
        if pair_key in seen_pairs:
            continue
        seen_pairs.add(pair_key)
        if reverse_match:
            canonical_match_id = min(match.id, reverse_match.id)
            match_ids = [match.id, reverse_match.id]
        else:
            canonical_match_id = match.id
            match_ids = [match.id]
        other_profile = db.query(models.Profile).options(
            joinedload(models.Profile.photos).load_only(models.UserPhoto.id, models.UserPhoto.is_primary, models.UserPhoto.upload_order),
            joinedload(models.Profile.sex)
        ).filter(models.Profile.user_id == match.matched_user_id).first()
        last_msg = db.query(models.Message).filter(
            models.Message.match_id.in_(match_ids)
        ).order_by(models.Message.created_at.desc()).first()
        unread_count = db.query(models.Message).filter(
            models.Message.match_id.in_(match_ids),
            models.Message.sender_id != user_id,
            models.Message.is_read == False
        ).count()
        profile_dict = None
        if other_profile:
            primary_photo = next((p for p in other_profile.photos if p.is_primary), (other_profile.photos[0] if other_profile.photos else None))
            other_user = db.query(models.SynoUser).filter(models.SynoUser.id == match.matched_user_id).first()
            profile_dict = {
                "id": other_profile.user_id,
                "user_id": other_profile.user_id,
                "name": other_profile.name,
                "photo_url": f"/api/photos/{primary_photo.id}" if primary_photo else None,
                "sex": other_profile.sex.name if other_profile.sex else None,
                "last_active_at": other_user.last_active_at.isoformat() if other_user and other_user.last_active_at else None,
            }
        result.append({
            "match_id": canonical_match_id,
            "matched_user_id": match.matched_user_id,
            "matched_profile": profile_dict,
            "compatibility_score": match.compatibility_score,
            "last_message": last_msg.content if last_msg else None,
            "last_message_at": last_msg.created_at if last_msg else match.created_at,
            "last_message_sender_id": last_msg.sender_id if last_msg else None,
            "is_read": unread_count == 0,
            "unread_count": unread_count,
        })
    return result

def verify_otp_phone_logic(db: Session, phone: str, provided_code: str):
    """
    Business logic for Phone OTP verification.
    """
    otp_record = db.query(models.OTP).filter(
        models.OTP.phone_number == phone,
        models.OTP.used_flag == False
    ).order_by(models.OTP.created_at.desc()).first()

    if not otp_record:
        return False, "otp.invalid_code"
    
    if otp_record.expires_at < datetime.utcnow():
        return False, "otp.expired_code"

    if otp_record.attempts >= 3:
        return False, "otp.rate_limit_error"

    otp_record.attempts += 1
    
    # Clean code comparison (ignoring dashes if frontend sends XXX-XXX)
    clean_provided = provided_code.replace("-", "")
    if not pwd_context.verify(clean_provided, otp_record.otp_hash):
        db.commit()
        return False, "otp.invalid_code"

    # Success
    otp_record.used_flag = True
    db.commit()
    return True, "otp.success"