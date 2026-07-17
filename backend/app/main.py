from datetime import timedelta
from functools import lru_cache
import json
from twilio.rest import Client
import os
import functools
import secrets
import logging
import re
import smtplib
from email.mime.text import MIMEText
from typing import List, Optional
from pydantic import BaseModel, EmailStr, Field
from datetime import date, datetime
from passlib.context import CryptContext
from fastapi import FastAPI, Depends, Form, HTTPException, Response, status, File, UploadFile, BackgroundTasks
from sqlalchemy.orm import Session, joinedload, load_only
from sqlalchemy import text

from . import models, schemas, crud
from .database import engine, Base, get_db
from .auth import create_access_token, get_current_active_user
from .config import settings

# Create database tables
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="SYNO Backend",
    description="API for the SYNO application.",
    version="1.0.0",
)

# Run startup migrations to fix schema issues on existing databases
@app.on_event("startup")
def run_startup_migrations():
    """Fix settings FK and populate translation_key values on existing databases."""
    from .database import SessionLocal
    db = SessionLocal()
    try:
        # Fix settings table FK constraint (syno_users -> profiles)
        db.execute(text("""
            DO $$ BEGIN
                IF EXISTS (
                    SELECT 1 FROM pg_constraint 
                    WHERE conname = 'fk_user_settings' 
                    AND conrelid = 'settings'::regclass
                ) THEN
                    ALTER TABLE settings DROP CONSTRAINT fk_user_settings;
                END IF;
            END $$;
        """))
        db.execute(text("""
            DELETE FROM settings WHERE user_id NOT IN (SELECT id FROM profiles);
        """))
        db.execute(text("""
            DO $$ BEGIN
                IF NOT EXISTS (
                    SELECT 1 FROM pg_constraint 
                    WHERE conname = 'fk_user_settings_profiles' 
                    AND conrelid = 'settings'::regclass
                ) THEN
                    ALTER TABLE settings ADD CONSTRAINT fk_user_settings_profiles 
                        FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;
                END IF;
            END $$;
        """))
        # Ensure translation_key columns exist
        for table in ['locations', 'educations', 'professions', 'hobbies', 'orientations', 'sexes']:
            db.execute(text(f"ALTER TABLE {table} ADD COLUMN IF NOT EXISTS translation_key VARCHAR(150);"))
        # Populate translation keys
        db.execute(text("""
            UPDATE educations SET translation_key = CASE name
                WHEN 'High School' THEN 'profile.educations.high_school'
                WHEN 'Associate' THEN 'profile.educations.associate'
                WHEN 'Bachelor' THEN 'profile.educations.bachelor'
                WHEN 'Master' THEN 'profile.educations.master'
                WHEN 'PhD' THEN 'profile.educations.phd'
                WHEN 'Trade School' THEN 'profile.educations.trade_school'
            END WHERE translation_key IS NULL;
        """))
        db.execute(text("""
            UPDATE professions SET translation_key = CASE name
                WHEN 'Engineer' THEN 'profile.professions.engineer'
                WHEN 'Doctor' THEN 'profile.professions.doctor'
                WHEN 'Artist' THEN 'profile.professions.artist'
                WHEN 'Teacher' THEN 'profile.professions.teacher'
                WHEN 'Developer' THEN 'profile.professions.developer'
                WHEN 'Manager' THEN 'profile.professions.manager'
                WHEN 'Student' THEN 'profile.professions.student'
            END WHERE translation_key IS NULL;
        """))
        db.execute(text("""
            UPDATE hobbies SET translation_key = CASE name
                WHEN 'Yoga' THEN 'profile.hobbies.yoga'
                WHEN 'Meditation' THEN 'profile.hobbies.meditation'
                WHEN 'Astrology' THEN 'profile.hobbies.astrology'
                WHEN 'Hiking' THEN 'profile.hobbies.hiking'
                WHEN 'Reading' THEN 'profile.hobbies.reading'
                WHEN 'Music' THEN 'profile.hobbies.music'
            END WHERE translation_key IS NULL;
        """))
        db.execute(text("""
            UPDATE orientations SET translation_key = CASE name
                WHEN 'Straight' THEN 'profile.orientations.straight'
                WHEN 'Gay' THEN 'profile.orientations.gay'
                WHEN 'Bisexual' THEN 'profile.orientations.bisexual'
                WHEN 'Pansexual' THEN 'profile.orientations.pansexual'
                WHEN 'Asexual' THEN 'profile.orientations.asexual'
                WHEN 'Other' THEN 'profile.orientations.other'
            END WHERE translation_key IS NULL;
        """))
        db.execute(text("""
            UPDATE sexes SET translation_key = CASE name
                WHEN 'Male' THEN 'profile.sexes.male'
                WHEN 'Female' THEN 'profile.sexes.female'
                WHEN 'Non-binary' THEN 'profile.sexes.non_binary'
                WHEN 'Other' THEN 'profile.sexes.other'
            END WHERE translation_key IS NULL;
        """))
        db.execute(text("""
            UPDATE locations SET translation_key = CASE name
                WHEN 'USA' THEN 'profile.locations.usa'
                WHEN 'UK' THEN 'profile.locations.uk'
                WHEN 'France' THEN 'profile.locations.france'
                WHEN 'Japan' THEN 'profile.locations.japan'
                WHEN 'Australia' THEN 'profile.locations.australia'
                WHEN 'Germany' THEN 'profile.locations.germany'
                WHEN 'Canada' THEN 'profile.locations.canada'
            END WHERE type = 'country' AND translation_key IS NULL;
        """))
        db.execute(text("""
            UPDATE locations SET translation_key = CASE name
                WHEN 'New York' THEN 'profile.locations.new_york'
                WHEN 'Los Angeles' THEN 'profile.locations.los_angeles'
                WHEN 'London' THEN 'profile.locations.london'
                WHEN 'Paris' THEN 'profile.locations.paris'
                WHEN 'Tokyo' THEN 'profile.locations.tokyo'
                WHEN 'Sydney' THEN 'profile.locations.sydney'
                WHEN 'Berlin' THEN 'profile.locations.berlin'
                WHEN 'Toronto' THEN 'profile.locations.toronto'
            END WHERE type = 'city' AND translation_key IS NULL;
        """))
        db.commit()
        logging.info("Startup migrations completed successfully.")
    except Exception as e:
        db.rollback()
        logging.warning(f"Startup migration skipped: {e}")
    finally:
        db.close()

# Password hashing context
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

logger = logging.getLogger("syno.auth")

# Define TRANSLATIONS_DIR relative to the current file
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
TRANSLATIONS_DIR = os.path.join(BASE_DIR, "translations")

# Ensure the directory exists so the app doesn't crash, and log the path for debugging
if not os.path.exists(TRANSLATIONS_DIR):
    os.makedirs(TRANSLATIONS_DIR, exist_ok=True)
    logger.info(f"Created translations directory at: {TRANSLATIONS_DIR}")
else:
    logger.info(f"Translations directory identified at: {TRANSLATIONS_DIR}")

@lru_cache(maxsize=128)
def _load_translations(lang: str) -> dict:
    """Loads translation data for a given language from a JSON file."""
    filepath = os.path.join(TRANSLATIONS_DIR, f"{lang}.json")
    if not os.path.exists(filepath):
        logger.warning(f"Translation file not found: {filepath}")
        return {}
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            return json.load(f)
    except Exception as e:
        logger.error(f"Error loading translation file {filepath}: {e}")
        return {}

def send_otp_email(to_email: str, subject: str, html_content: str) -> bool:
    """Sends an OTP email to the specified recipient."""
    try:
        msg = MIMEText(html_content, "html")
        msg["Subject"] = subject
        msg["From"] = settings.smtp_user
        msg["To"] = to_email

        if settings.smtp_port == 465:
            with smtplib.SMTP_SSL(settings.smtp_server, settings.smtp_port) as server:
                server.login(settings.smtp_user, settings.smtp_password)
                server.send_message(msg)
        else:
            with smtplib.SMTP(settings.smtp_server, settings.smtp_port) as server:
                server.starttls()  # Secure the connection
                server.login(settings.smtp_user, settings.smtp_password)
                server.send_message(msg)

        logger.info(f"Email sent successfully to {to_email}")
        return True
    except Exception as e:
        logger.error(f"Failed to send email: {e}")
        return False

def send_sms_otp(phone_number: str, message: str) -> bool:
    try:
        # These values must be in your .env / settings.py
        if not settings.twilio_sid or not settings.twilio_auth_token:
            logger.error("Twilio credentials are missing in settings. Skipping SMS.")
            return False
            
        client = Client(settings.twilio_sid, settings.twilio_auth_token)
        
        client.messages.create(
            body=message,
            from_=settings.twilio_phone, # Your purchased Twilio number
            to=phone_number
        )
        
        logger.info(f"Actual SMS sent to {phone_number}")
        return True
    except Exception as e:
        logger.error(f"Failed to send SMS: {e}")
        return False

def validate_phone_number(phone: str):
    """Validates European and Georgian phone numbers."""
    # Basic sanitization
    clean_phone = re.sub(r'[^\d+]', '', phone)
    
    # European Country Codes and typical lengths (min, max)
    # +995 (GE), +49 (DE), +33 (FR), +44 (GB), etc.
    country_codes = {
        "995": (9, 9),   # Georgia
        "49": (10, 11),  # Germany
        "33": (9, 9),    # France
        "44": (10, 10),  # UK
    }
    
    for code, (min_l, max_l) in country_codes.items():
        pattern = rf"^\+?{code}\d{{{min_l},{max_l}}}$"
        if re.match(pattern, clean_phone):
            # Remove + for uniform storage if preferred, 
            # but usually keeping + is better for internationalization
            return True, clean_phone
            
    return False, None

# Define a schema for the complete registration form data

# ----------------- AUTH -----------------

def tr(key: str, lang: str = "en", **kwargs) -> str:
    """
    Helper to translate keys using the JSON files, supporting dot notation
    and string formatting. Falls back to English if the translation is missing.
    """
    # 1. Try requested language
    val = _get_value_from_json(key, lang)

    # 2. Fallback to English if not found
    if not val and lang != "en":
        val = _get_value_from_json(key, "en")

    if not val:
        return key

    if isinstance(val, str):
        try: return val.format(**kwargs).strip()
        except (KeyError, ValueError, IndexError): return val
    return str(val)

def _get_value_from_json(key: str, lang: str) -> Optional[str]:
    """Internal helper to traverse the JSON dictionary."""
    translations = _load_translations(lang)
    val = translations
    for part in key.split('.'):
        if isinstance(val, dict):
            val = val.get(part)
        else:
            return None
    return val if isinstance(val, str) else None

@app.post("/api/auth/login", response_model=schemas.Token)
def login_for_access_token(user_credentials: schemas.UserLogin, db: Session = Depends(get_db)):
    user = crud.get_user_by_email(db, email=user_credentials.email)
    if not user or not crud.verify_password(user_credentials.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token_expires = timedelta(minutes=settings.access_token_expire_minutes)
    access_token = create_access_token(
        data={"sub": user.email}, expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer"}


@app.post("/api/auth/register", response_model=schemas.Token, status_code=status.HTTP_201_CREATED)
def register_user(user: schemas.UserCreate, db: Session = Depends(get_db)):
    db_user = crud.get_user_by_email(db, email=user.email)
    if db_user:
        raise HTTPException(status_code=400, detail="Email already registered")
    
    new_user = crud.create_user(db=db, user=user)

    access_token_expires = timedelta(minutes=settings.access_token_expire_minutes)
    access_token = create_access_token(
        data={"sub": new_user.email}, expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer"}


@app.post("/api/auth/check-email", status_code=status.HTTP_200_OK)
def check_email_availability(user_data: schemas.UserBase, db: Session = Depends(get_db)):
    user = crud.get_user_by_email(db, email=user_data.email)
    if user:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Email already registered"
        )
    return {"message": "Email is available"}

@app.post("/api/auth/request-otp", status_code=status.HTTP_200_OK)
async def request_otp(otp_data: schemas.OTPRequest, background_tasks: BackgroundTasks, db: Session = Depends(get_db)):
    """
    REST API endpoint to receive email submission, generate 6-digit secure OTP,
    store in PostgreSQL, and send localized email.
    """
    # Branch to phone logic if phone number is provided instead of email
    if otp_data.phone_number and not otp_data.email:
        return await request_otp_phone(
            schemas.SMSOTPRequest(phone_number=otp_data.phone_number, lang=otp_data.lang), 
            background_tasks, 
            db
        )

    # Periodic cleanup trigger (could also be a cron job)
    if secrets.randbelow(10) == 0: # 10% chance to run cleanup on request to keep table slim
        crud.cleanup_otps(db)

    if not otp_data.email:
        raise HTTPException(status_code=400, detail="Email or Phone Number is required")

    email = otp_data.email.lower()
    # 0. Basic Rate Limiting: Prevent more than 1 request per minute per email
    last_otp = db.query(models.OTP).filter(
        models.OTP.email == email,
        models.OTP.created_at > datetime.utcnow() - timedelta(minutes=1)
    ).first()
    
    if last_otp:
        logger.warning(f"Rate limit hit for {email}")
        raise HTTPException(status_code=429, detail="otp.rate_limit_error")

    lang = otp_data.lang if otp_data.lang in ["en", "ru", "ka"] else "en"
    logger.info(f"OTP request received for email: {email} (lang: {lang})")

    try:
        # 1. Generate Secure 6-digit OTP inside the try block
        otp_code = "".join([str(secrets.randbelow(10)) for _ in range(6)])
        # 2. Prepare localized email content and HTML template
        subject = tr("otp.otp_subject", lang)
        message_text = tr("otp.otp_message", lang, code=otp_code, minutes=10)
        
        html_template = f"""
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>{subject}</title>
        </head>
        <body style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f4f4f9; padding: 20px;">
            <div style="max-width: 500px; margin: auto; background: #ffffff; padding: 40px; border-radius: 12px; box-shadow: 0 4px 15px rgba(0,0,0,0.1);">
                <h1 style="color: #6200ee; text-align: center; margin-bottom: 30px;">SYNO</h1>
                <div style="font-size: 18px; line-height: 1.6; color: #333; text-align: center;">
                    {message_text}
                </div>
                <div style="margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee; font-size: 12px; color: #888; text-align: center;">
                    &copy; {datetime.now().year} SYNO. All rights reserved.
                </div>
            </div>
        </body>
        </html>
        """

        # 3. Store the OTP in the database. crud handles hashing internally.
        crud.create_otp(db, email=email, code=otp_code)

        # 4. Send the HTML email in the background
        background_tasks.add_task(send_otp_email, email, subject, html_template)

        if getattr(settings, "debug", False):
            logger.info(f"DEBUG: OTP for {email} is {otp_code}")

    except Exception as e:
        logger.error(f"OTP Email Error: {e}")
        if isinstance(e, HTTPException):
            raise e
        raise HTTPException(status_code=500, detail="An error occurred while processing your request")
    
    return {"message": "OTP requested successfully"}

@app.post("/api/auth/request-otp-phone", status_code=status.HTTP_200_OK)
async def request_otp_phone(otp_data: schemas.SMSOTPRequest, background_tasks: BackgroundTasks, db: Session = Depends(get_db)):
    """Sends a 6-digit OTP via SMS to the provided phone number."""
    is_valid, formatted_phone = validate_phone_number(otp_data.phone_number)
    if not is_valid:
        raise HTTPException(status_code=400, detail="otp.invalid_phone_format")

    # Rate limiting: 1 request per minute
    last_otp = db.query(models.OTP).filter(
        models.OTP.phone_number == formatted_phone,
        models.OTP.created_at > datetime.utcnow() - timedelta(minutes=1)
    ).first()
    
    if last_otp:
        raise HTTPException(status_code=429, detail="otp.rate_limit_error")

    lang = otp_data.lang if otp_data.lang in ["en", "ru", "ka"] else "en"
    otp_code = "".join([str(secrets.randbelow(10)) for _ in range(6)])
    
    # Format as XXX-XXX for the SMS
    display_code = f"{otp_code[:3]}-{otp_code[3:]}"
    logger.info(f"Generated SMS OTP for {formatted_phone}: {otp_code}")

    sms_message = tr("otp.sms_message", lang, code=display_code)
    
    crud.create_otp_phone(db, phone=formatted_phone, code=otp_code)
    background_tasks.add_task(send_sms_otp, formatted_phone, sms_message)
    
    return {"message": "otp.success"}

@app.post("/api/auth/verify-otp-phone", response_model=schemas.OTPVerifyResponse)
async def verify_otp_phone(otp_data: schemas.SMSOTPVerify, db: Session = Depends(get_db)):
    """Verifies phone OTP and links it to user/profile."""
    is_valid, formatted_phone = validate_phone_number(otp_data.phone_number)
    if not is_valid:
        raise HTTPException(status_code=400, detail="otp.invalid_phone_format")
    
    success, msg_key = crud.verify_otp_phone_logic(db, formatted_phone, otp_data.code)
    if not success:
        raise HTTPException(status_code=400, detail=msg_key)

    # Check if a profile already uses this phone
    existing_profile = db.query(models.Profile).filter(models.Profile.phone_number == formatted_phone).first()
    
    if existing_profile and existing_profile.user_id:
        # If profile exists, find the associated user to issue a token
        db_user = db.query(models.SynoUser).filter(models.SynoUser.id == existing_profile.user_id).first()
        
        if db_user:
            access_token_expires = timedelta(minutes=settings.access_token_expire_minutes)
            access_token = create_access_token(
                data={"sub": db_user.email}, expires_delta=access_token_expires
            )
            return {
                "message": "otp.verified_success",
                "is_registered": True,
                "access_token": access_token,
                "token_type": "bearer"
            }

    # New Phone User: Create a placeholder user account to allow token issuance
    temp_email = f"phone_{formatted_phone.replace('+', '')}@syno.app".lower()
    db_user = crud.get_user_by_email(db, temp_email)
    if not db_user:
        db_user = crud.create_user(
            db, 
            schemas.UserCreate(email=temp_email, password=secrets.token_urlsafe(16))
        )

    access_token_expires = timedelta(minutes=settings.access_token_expire_minutes)
    access_token = create_access_token(
        data={"sub": db_user.email}, expires_delta=access_token_expires
    )
    return {
        "message": "otp.verified_success",
        "is_registered": False,
        "access_token": access_token,
        "token_type": "bearer"
    }

@app.post("/api/auth/verify-otp", response_model=schemas.OTPVerifyResponse)
async def verify_otp(otp_data: schemas.OTPVerify, db: Session = Depends(get_db)):
    # Branch to phone verification if phone number is provided
    if otp_data.phone_number and not otp_data.email:
        return await verify_otp_phone(
            schemas.SMSOTPVerify(phone_number=otp_data.phone_number, code=otp_data.code), 
            db
        )

    if not otp_data.email:
        raise HTTPException(status_code=400, detail="Email or Phone Number is required")

    email = otp_data.email.lower()
    logger.info(f"OTP verification attempt for: {email}")

    # 1. Verification Logic via CRUD
    is_valid, msg_key = crud.verify_otp_logic(db, email, otp_data.code)
    
    if not is_valid:
        logger.warning(f"OTP failed for {email}: {msg_key}")
        raise HTTPException(status_code=400, detail=msg_key)

    # 2. Check if user is registered
    db_user = crud.get_user_by_email(db, email.lower())
    db_profile = crud.get_profile_by_user_id(db, db_user.id) if db_user else None
    
    if db_user and db_profile:
        # Existing User with Profile - Issue login token
        access_token_expires = timedelta(minutes=settings.access_token_expire_minutes)
        access_token = create_access_token(
            data={"sub": db_user.email}, expires_delta=access_token_expires
        )
        return {
            "message": "otp.verified_success",
            "is_registered": True,
            "access_token": access_token,
            "token_type": "bearer"
        }
    elif db_user:
        # User exists but no profile - Issue token so they can create a profile in Step 2
        access_token_expires = timedelta(minutes=settings.access_token_expire_minutes)
        access_token = create_access_token(
            data={"sub": db_user.email}, expires_delta=access_token_expires
        )
        return {
            "message": "otp.verified_success",
            "is_registered": False,
            "access_token": access_token,
            "token_type": "bearer"
        }
    else:
        # New User - Create user record and return token for Step 2
        new_user = crud.create_user(
            db, 
            schemas.UserCreate(email=email, password=secrets.token_urlsafe(16))
        )
        access_token_expires = timedelta(minutes=settings.access_token_expire_minutes)
        access_token = create_access_token(
            data={"sub": new_user.email}, expires_delta=access_token_expires
        )
        return {
            "message": "otp.verified_success",
            "is_registered": False,
            "access_token": access_token,
            "token_type": "bearer"
        }


@app.get("/api/sexes/", response_model=List[schemas.Sex])
def read_sexes(db: Session = Depends(get_db)):
    return crud.get_sexes(db)


@app.get("/api/orientations/", response_model=List[schemas.Orientation])
def read_orientations(db: Session = Depends(get_db)):
    return crud.get_orientations(db)


@app.get("/api/hobbies/", response_model=List[schemas.Hobby])
def read_hobbies(q: Optional[str] = None, db: Session = Depends(get_db)):
    return crud.get_hobbies(db, query=q)

@app.get("/api/educations/", response_model=List[schemas.Education])
def read_educations(q: Optional[str] = None, db: Session = Depends(get_db)):
    return crud.get_educations(db, query=q)

@app.get("/api/professions/", response_model=List[schemas.Profession])
def read_professions(q: Optional[str] = None, db: Session = Depends(get_db)):
    return crud.get_professions(db, query=q)

@app.get("/api/core-values/", response_model=List[schemas.CoreValue])
def read_core_values(db: Session = Depends(get_db)):
    return crud.get_core_values(db)

@app.get("/api/intentions/", response_model=List[schemas.Intention])
def read_intentions(db: Session = Depends(get_db)):
    return crud.get_intentions(db)

@app.get("/api/location/search", response_model=List[schemas.Location])
def search_locations(q: Optional[str] = None, db: Session = Depends(get_db)):
    return crud.search_locations(db, query=q)


# ----------------- USER PROFILE -----------------

@app.patch("/api/users/me", response_model=schemas.Profile, summary="Create or partially update user profile with photos")
async def create_or_update_user_profile_patch(
    profile_in: schemas.ProfileUpdateForm = Depends(schemas.ProfileUpdateForm.as_form_patch),
    primary_photo: Optional[UploadFile] = File(None),
    uploaded_photos: List[UploadFile] = File([]),
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    """
    Handles both creation and partial updates for a user's profile.
    """
    # profile_in is already parsed and validated by ProfileUpdateForm.as_form_patch
    update_data = profile_in.dict(exclude_unset=True)

    db_profile = crud.get_profile_by_user_id(db, user_id=current_user.id)
    

    if db_profile:
        # This is an update (PATCH)
        
        # Filter out theme-related fields to ensure independence. 
        # Profile updates should not modify theme settings.
        theme_keys = {'theme_id', 'background_color', 'accent_color', 'layout', 'theme_preferences'}
        filtered_data = {k: v for k, v in update_data.items() if k not in theme_keys}
        profile_update_schema = schemas.ProfileUpdate(**filtered_data)
        
        await crud.update_profile(db=db, db_profile=db_profile, profile_in=profile_update_schema)

        # 2. Handle Primary Photo Update (if provided)
        if primary_photo and primary_photo.filename:
            await crud.update_primary_photo(db, db_profile, primary_photo)

        # 3. Handle Additional Photos Append (if provided)
        valid_additional_photos = [p for p in uploaded_photos if p and p.filename]
        if valid_additional_photos:
            await crud.add_additional_photos(db, db_profile, valid_additional_photos)

        # Fetch the complete profile with all relationships loaded (intentions, professions, etc.)
        # We need to reload using the CRUD getter that has 'joinedload' options to populate nested objects for the response
        db_profile = crud.get_profile_by_user_id(db, user_id=current_user.id)

        # Construct the response manually to ensure theme_preferences are included.
        # This prevents the frontend from losing theme state after a profile update.
        profile_dict = schemas.Profile.model_validate(db_profile).model_dump()
        user_theme_settings = db.query(models.Settings).filter(models.Settings.user_id == db_profile.id).first()
        if user_theme_settings:
            profile_dict['theme_preferences'] = {
                'theme_id': user_theme_settings.theme_id,
                'background_color': user_theme_settings.background_color,
                'accent_color': user_theme_settings.accent_color,
                'layout': user_theme_settings.layout
            }
        return profile_dict
    else:
        # This is a creation (POST-like behavior on a PATCH)
        # Combine photos into a single list for creation logic
        all_photos: List[UploadFile] = []
        if primary_photo and primary_photo.filename:
            all_photos.append(primary_photo)
        all_photos.extend([p for p in uploaded_photos if p and p.filename])

        if not all_photos:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="A primary photo is required to create a profile.")
        
        # For creation, use the parsed data.
        create_data = schemas.ProfileUpdate(**update_data) # Use the parsed data

        
        # Ensure 'name' is present and not None
        if not create_data.name: raise HTTPException(status_code=400, detail="Name cannot be empty.")
        await crud.create_profile(db=db, profile_in=create_data, user_id=current_user.id, photos=all_photos)

        # Fetch the complete profile with all relationships loaded
        new_profile = crud.get_profile_by_user_id(db, user_id=current_user.id)
        
        # Attach default theme preferences for new profiles if needed
        profile_dict = schemas.Profile.model_validate(new_profile).model_dump()
        profile_dict['theme_preferences'] = {
            'theme_id': 'deep_space', # Default
            'background_color': '#000000',
            'accent_color': '#FFFFFF',
            'layout': 'default'
        }
        return profile_dict


@app.get("/api/users/me", response_model=schemas.Profile)
def read_users_me(
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    profile = crud.get_profile_by_user_id(db, user_id=current_user.id)
    if profile is None:
        raise HTTPException(status_code=404, detail="Profile not found for the current user.")
    # The response model `schemas.Profile` should be configured to serialize
    # the relationships (intentions, core_values) from the `profile` ORM object.
    # Pydantic's `model_validate` with `from_attributes=True` on the schema handles this.
    profile_dict = schemas.Profile.model_validate(profile).model_dump()
    user_theme_settings = db.query(models.Settings).filter(models.Settings.user_id == profile.id).first()
    if user_theme_settings:
        profile_dict['theme_preferences'] = {
            'theme_id': user_theme_settings.theme_id,
            'background_color': user_theme_settings.background_color,
            'accent_color': user_theme_settings.accent_color,
            'layout': user_theme_settings.layout
        }
    prefs = db.query(models.UserPreferences).filter(
        models.UserPreferences.profile_id == profile.id
    ).first()
    if prefs:
        profile_dict['preferences'] = {
            'min_age': prefs.min_age,
            'max_age': prefs.max_age,
            'max_distance': prefs.max_distance,
            'genders': prefs.genders or [],
        }
    else:
        profile_dict['preferences'] = {
            'min_age': 18,
            'max_age': 50,
            'max_distance': 100,
            'genders': [],
        }
    return profile_dict

@app.get("/api/photos/{photo_id}", summary="Get a user's photo")
def get_photo(
    photo_id: int,
    db: Session = Depends(get_db),
):
    """Retrieves and serves a photo by ID. No auth required for viewing."""
    photo = db.query(models.UserPhoto).filter(models.UserPhoto.id == photo_id).first()
    if not photo:
        raise HTTPException(status_code=404, detail="Photo not found.")
    return Response(content=photo.photo_data, media_type="image/jpeg")

@app.delete("/api/photos/{photo_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Delete a user's photo")
def delete_a_photo(
    photo_id: int,
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    """Deletes a specific photo by its ID."""
    success = crud.delete_photo(db, photo_id=photo_id, user_id=current_user.id)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Photo not found or you don't have permission to delete it."
        )
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@app.delete("/api/users/me", status_code=status.HTTP_204_NO_CONTENT, summary="Deactivate or delete your account permanently")
def delete_current_user(
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    success = crud.delete_user(db, user_id=current_user.id)
    if not success:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found.")
    return Response(status_code=status.HTTP_204_NO_CONTENT)


# ----------------- BLOCK / UNBLOCK -----------------

@app.post("/api/users/{user_id}/block", status_code=status.HTTP_204_NO_CONTENT, summary="Block another user")
def block_a_user(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    result = crud.block_user(db, blocker_id=current_user.id, blocked_id=user_id)
    if result is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User to block not found or you cannot block yourself."
        )
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@app.delete("/api/users/{user_id}/unblock", status_code=status.HTTP_204_NO_CONTENT, summary="Unblock another user")
def unblock_user(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    crud.unblock_user(db, blocker_id=current_user.id, blocked_id=user_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@app.get("/api/users/me/blocked", response_model=List[schemas.Profile], summary="Get list of blocked users")
def get_blocked_list(
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    return crud.get_blocked_users(db, blocker_id=current_user.id)


@app.get("/api/users/profile-search/{name}", response_model=schemas.Profile, summary="Search for a user profile by name")
def search_user_by_name_endpoint(
    name: str,
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    profile = crud.get_profile_by_name(db, name)
    if not profile:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return profile


@app.post("/api/users/block-by-name", status_code=status.HTTP_204_NO_CONTENT, summary="Block user by profile name")
def block_user_by_name(
    name_data: schemas.BlockByNameRequest,
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    profile = crud.get_profile_by_name(db, name_data.name)
    if not profile:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    
    result = crud.block_user(db, blocker_id=current_user.id, blocked_id=profile.user_id)
    if result is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot block yourself")
    return Response(status_code=status.HTTP_204_NO_CONTENT)


# ----------------- USER PREFERENCES -----------------

@app.get("/api/users/me/preferences", response_model=schemas.UserPreferencesResponse)
def get_user_preferences(
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    db_profile = crud.get_profile_by_user_id(db, user_id=current_user.id)
    if not db_profile:
        raise HTTPException(status_code=404, detail="Profile not found")

    prefs = db.query(models.UserPreferences).filter(
        models.UserPreferences.profile_id == db_profile.id
    ).first()

    if not prefs:
        prefs = models.UserPreferences(profile_id=db_profile.id)
        db.add(prefs)
        db.commit()
        db.refresh(prefs)

    return prefs


@app.put("/api/users/me/preferences", response_model=schemas.UserPreferencesResponse)
def update_user_preferences(
    prefs_data: schemas.UserPreferencesCreate,
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    db_profile = crud.get_profile_by_user_id(db, user_id=current_user.id)
    if not db_profile:
        raise HTTPException(status_code=404, detail="Profile not found")

    prefs = db.query(models.UserPreferences).filter(
        models.UserPreferences.profile_id == db_profile.id
    ).first()

    if not prefs:
        prefs = models.UserPreferences(profile_id=db_profile.id)
        db.add(prefs)

    update_dict = prefs_data.model_dump(exclude_unset=True)
    for key, value in update_dict.items():
        setattr(prefs, key, value)

    try:
        db.commit()
        db.refresh(prefs)
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to save preferences: {str(e)}")

    return prefs


@app.get("/api/discover")
def get_discover(
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    db_profile = crud.get_profile_by_user_id(db, user_id=current_user.id)
    if not db_profile:
        return []

    blocked_ids_query = db.query(models.user_blocks.c.blocked_id).filter(
        models.user_blocks.c.blocker_id == current_user.id
    )
    blocked_ids = [r[0] for r in blocked_ids_query.all()]

    query = db.query(models.Profile).options(
        joinedload(models.Profile.location),
        joinedload(models.Profile.sex),
        joinedload(models.Profile.orientation),
        joinedload(models.Profile.photos).load_only(models.UserPhoto.id, models.UserPhoto.is_primary, models.UserPhoto.upload_order),
        joinedload(models.Profile.hobbies),
        joinedload(models.Profile.intentions),
        joinedload(models.Profile.core_values),
        joinedload(models.Profile.professions),
        joinedload(models.Profile.educations),
    ).filter(
        models.Profile.user_id != current_user.id,
        ~models.Profile.user_id.in_(blocked_ids) if blocked_ids else True,
    )

    profiles = query.all()

    received_like_ids = set(crud.get_received_like_user_ids(db, user_id=current_user.id))

    profile_list = [
        {
            "id": p.id,
            "user_id": p.user_id,
            "name": p.name,
            "last_name": p.last_name,
            "birth_date": p.birth_date.isoformat() if p.birth_date else None,
            "birth_time": p.birth_time,
            "bio": p.bio,
            "height": p.height,
            "location": {"id": p.location.id, "name": p.location.name, "type": p.location.type, "translation_key": p.location.translation_key or ''} if p.location else None,
            "sex": {"id": p.sex.id, "name": p.sex.name, "translation_key": p.sex.translation_key or ''} if p.sex else None,
            "orientation": {"id": p.orientation.id, "name": p.orientation.name, "translation_key": p.orientation.translation_key or ''} if p.orientation else None,
            "photos": [{"id": ph.id, "is_primary": ph.is_primary, "upload_order": ph.upload_order, "url": f"/api/photos/{ph.id}"} for ph in p.photos],
            "hobbies": [{"id": h.id, "name": h.name, "translation_key": h.translation_key or ''} for h in p.hobbies],
            "intentions": [{"id": i.id, "key": i.key, "translation_key": i.translation_key} for i in p.intentions],
            "core_values": [{"id": cv.id, "key": cv.key, "translation_key": cv.translation_key or ''} for cv in p.core_values],
            "professions": [{"id": pr.id, "name": pr.name, "translation_key": pr.translation_key or ''} for pr in p.professions],
            "educations": [{"id": e.id, "name": e.name, "translation_key": e.translation_key or ''} for e in p.educations],
            "liked_by_user": p.user_id in received_like_ids,
        }
        for p in profiles
    ]

    profile_list.sort(key=lambda x: (not x["liked_by_user"], x["user_id"]))

    return profile_list


@app.put("/api/users/me/settings", response_model=schemas.Profile)
def update_theme_settings(
    settings_data: schemas.ThemeSettingsUpdate,
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    # First, ensure a profile exists. The database schema requires a profile
    # before settings can be saved, which is the cause of the ForeignKeyViolation.
    db_profile = crud.get_profile_by_user_id(db, user_id=current_user.id)
    if not db_profile:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="A user profile must be created before theme settings can be saved."
        )

    # 1. Upsert (Update or Create) Settings
    user_settings = db.query(models.Settings).filter(models.Settings.user_id == db_profile.id).first()
    if not user_settings:
        user_settings = models.Settings(user_id=db_profile.id)
        db.add(user_settings)

    user_settings.theme_id = settings_data.theme_id
    user_settings.background_color = settings_data.background_color
    user_settings.accent_color = settings_data.accent_color
    user_settings.layout = settings_data.layout

    # 2. Update legacy theme_id on the Profile table. This is now guaranteed to exist.
    theme_map = {
        'deep_space': '3',   # Maps to old Purple/Dark
        'starlight': '1',    # Maps to old Light
        'nebula_dream': '2', # Maps to old System/Default
    }
    db_profile.theme_id = theme_map.get(settings_data.theme_id, settings_data.theme_id)

    try:
        db.commit()
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to save theme settings: {str(e)}"
        )
    db.refresh(db_profile)
    db.refresh(user_settings)

    profile_dict = schemas.Profile.model_validate(db_profile).model_dump()
    profile_dict['theme_preferences'] = {
        'theme_id': user_settings.theme_id,
        'background_color': user_settings.background_color,
        'accent_color': user_settings.accent_color,
        'layout': user_settings.layout
    }
    return profile_dict


# ============================================================
# MATCHES ENDPOINTS
# ============================================================

@app.post("/api/matches", response_model=schemas.MatchResponse, summary="Create or update a match (swipe)")
def create_or_update_match(
    match_data: schemas.MatchCreate,
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    if match_data.matched_user_id == current_user.id:
        raise HTTPException(status_code=400, detail="Cannot match with yourself")

    target_user = db.query(models.SynoUser).filter(models.SynoUser.id == match_data.matched_user_id).first()
    if not target_user:
        raise HTTPException(status_code=404, detail="Target user not found")

    target_profile = crud.get_profile_by_user_id(db, user_id=match_data.matched_user_id)
    if not target_profile:
        raise HTTPException(status_code=404, detail="Target user has no profile")

    match = crud.create_match(
        db,
        user_id=current_user.id,
        matched_user_id=match_data.matched_user_id,
        status=match_data.status,
        compatibility_score=match_data.compatibility_score
    )
    return match


@app.get("/api/matches", response_model=List[schemas.MatchResponse], summary="Get all matches for current user")
def get_my_matches(
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    return crud.get_matches_for_user(db, user_id=current_user.id)


@app.patch("/api/matches/{match_id}", response_model=schemas.MatchResponse, summary="Update match status")
def update_match_status(
    match_id: int,
    update_data: schemas.MatchUpdate,
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    match = crud.update_match_status(db, match_id=match_id, user_id=current_user.id, status=update_data.status)
    if not match:
        raise HTTPException(status_code=404, detail="Match not found")
    return match


@app.get("/api/matches/mutual/{other_user_id}", response_model=schemas.MutualMatchCheck, summary="Check if mutual match exists")
def check_mutual_match(
    other_user_id: int,
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    mutual = crud.get_mutual_match(db, user_id=current_user.id, other_user_id=other_user_id)
    return schemas.MutualMatchCheck(
        is_mutual=mutual is not None,
        match_id=mutual.id if mutual else None
    )


@app.delete("/api/matches/{match_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Delete a match")
def delete_match(
    match_id: int,
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    success = crud.delete_match(db, match_id=match_id, user_id=current_user.id)
    if not success:
        raise HTTPException(status_code=404, detail="Match not found")


# ============================================================
# MESSAGES ENDPOINTS
# ============================================================

@app.get("/api/messages/{match_id}", response_model=List[schemas.MessageResponse], summary="Get messages for a match")
def get_messages(
    match_id: int,
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    messages = crud.get_messages_for_match(db, match_id=match_id, user_id=current_user.id)
    return messages


@app.post("/api/messages", response_model=schemas.MessageResponse, summary="Send a message")
def send_message(
    msg_data: schemas.MessageCreate,
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    match = db.query(models.Match).filter(models.Match.id == msg_data.match_id).first()
    if not match:
        raise HTTPException(status_code=404, detail="Match not found")

    if match.user_id != current_user.id and match.matched_user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not part of this match")

    other_user_id = match.matched_user_id if match.user_id == current_user.id else match.user_id
    mutual = crud.get_mutual_match(db, user_id=current_user.id, other_user_id=other_user_id)
    if not mutual:
        raise HTTPException(status_code=403, detail="Messaging requires a mutual match")

    message = crud.create_message(db, match_id=msg_data.match_id, sender_id=current_user.id, content=msg_data.content)
    if not message:
        raise HTTPException(status_code=400, detail="Failed to send message")
    return message


@app.patch("/api/messages/{match_id}/read", status_code=status.HTTP_204_NO_CONTENT, summary="Mark messages as read")
def mark_read(
    match_id: int,
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    crud.mark_messages_read(db, match_id=match_id, user_id=current_user.id)


@app.get("/api/chats", response_model=List[schemas.ChatListResponse], summary="Get chat list (mutual matches)")
def get_chat_list(
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    return crud.get_chat_list(db, user_id=current_user.id)


# ============================================================
# LIKES ENDPOINTS
# ============================================================

@app.get("/api/likes/received", response_model=List[schemas.ReceivedLikeResponse], summary="Get incoming likes (people who liked you)")
def get_received_likes(
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    return crud.get_received_likes(db, user_id=current_user.id)


@app.post("/api/likes/{match_id}/accept", response_model=schemas.MatchResponse, summary="Accept an incoming like")
def accept_incoming_like(
    match_id: int,
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    result = crud.accept_incoming_like(db, match_id=match_id, user_id=current_user.id)
    if not result:
        raise HTTPException(status_code=404, detail="Like not found")
    return result


@app.post("/api/likes/{match_id}/decline", status_code=status.HTTP_204_NO_CONTENT, summary="Decline an incoming like")
def decline_incoming_like(
    match_id: int,
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    success = crud.decline_incoming_like(db, match_id=match_id, user_id=current_user.id)
    if not success:
        raise HTTPException(status_code=404, detail="Like not found")
