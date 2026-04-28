from datetime import datetime, timedelta
from sqlalchemy.sql import func
from sqlalchemy.orm import Session, joinedload
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

def get_hobbies(db: Session) -> List[models.Hobby]:
    return db.query(models.Hobby).all()

def get_educations(db: Session) -> List[models.Education]:
    return db.query(models.Education).all()

def get_professions(db: Session) -> List[models.Profession]:
    return db.query(models.Profession).all()

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

def delete_user(db: Session, user_id: int) -> bool:
    user = db.query(models.SynoUser).filter(models.SynoUser.id == user_id).first()
    if not user: return False
    db.delete(user)
    db.commit()
    return True

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
        joinedload(models.Profile.photos)
    ).filter(models.Profile.user_id.in_(blocked_ids)).all()

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