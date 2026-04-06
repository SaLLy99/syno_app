from datetime import timedelta
import json
from typing import List, Optional
from pydantic import BaseModel, EmailStr
from datetime import date
from fastapi import FastAPI, Depends, Form, HTTPException, Response, status, File, UploadFile
from sqlalchemy.orm import Session

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

# Define a schema for the complete registration form data
class RegisterCompleteForm(BaseModel):
    email: EmailStr
    password: str
    name: str
    last_name: str
    birth_date: date
    birth_time: Optional[str] = None
    location_id: Optional[int] = None
    sex_id: int
    orientation_id: int
    height: Optional[int] = None
    bio: Optional[str] = None
    # These will be JSON strings from the frontend
    intention_ids: Optional[str] = None
    core_value_ids: Optional[str] = None
    hobby_ids: Optional[str] = None
    profession_ids: Optional[str] = None
    education_ids: Optional[str] = None

    @classmethod
    def as_form(
        cls,
        email: EmailStr = Form(...),
        password: str = Form(...),
        name: str = Form(...),
        last_name: str = Form(...),
        birth_date: date = Form(...),
        birth_time: Optional[str] = Form(None),
        location_id: Optional[int] = Form(None),
        sex_id: int = Form(...),
        orientation_id: int = Form(...),
        height: Optional[int] = Form(None),
        bio: Optional[str] = Form(None),
        intention_ids: Optional[str] = Form(None),
        core_value_ids: Optional[str] = Form(None),
        hobby_ids: Optional[str] = Form(None),
        profession_ids: Optional[str] = Form(None),
        education_ids: Optional[str] = Form(None),
    ):
        return cls(
            email=email, password=password, name=name, last_name=last_name, birth_date=birth_date, birth_time=birth_time,
            location_id=location_id, sex_id=sex_id, orientation_id=orientation_id, height=height, bio=bio,
            intention_ids=intention_ids, core_value_ids=core_value_ids, hobby_ids=hobby_ids,
            profession_ids=profession_ids, education_ids=education_ids,
        )

# ----------------- AUTH -----------------

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
def request_otp(user_data: schemas.UserBase, db: Session = Depends(get_db)):
    """
    Endpoint to request a One-Time Password (OTP) for login/registration.
    In a production environment, this would integrate with an email/SMS provider.
    """
    # For now, we just simulate the process. 
    # In the future, logic to generate and store/send a code goes here.
    return {"message": f"OTP successfully requested for {user_data.email}"}


@app.post("/api/auth/register-complete", response_model=schemas.Token, status_code=status.HTTP_201_CREATED)
async def register_complete_user(
    form_data: RegisterCompleteForm = Depends(RegisterCompleteForm.as_form),
    photos: List[UploadFile] = File(...), # Expect at least one photo
    db: Session = Depends(get_db)
):
    # 1. Check if email already registered
    db_user = crud.get_user_by_email(db, email=form_data.email)
    if db_user:
        raise HTTPException(status_code=400, detail="Email already registered")

    # 2. Create the user
    user_create_schema = schemas.UserCreate(email=form_data.email, password=form_data.password)
    new_user = crud.create_user(db=db, user=user_create_schema)

    # 3. Prepare profile data for crud.create_profile
    profile_data_dict = form_data.dict(exclude={'email', 'password'})

    # Parse JSON string fields back into lists of integers
    list_fields_to_parse = ['intention_ids', 'core_value_ids', 'hobby_ids', 'profession_ids', 'education_ids']
    for field in list_fields_to_parse:
        if profile_data_dict.get(field) and isinstance(profile_data_dict[field], str):
            try:
                parsed_value = json.loads(profile_data_dict[field])
                if isinstance(parsed_value, list):
                    profile_data_dict[field] = parsed_value
                elif isinstance(parsed_value, int):
                    # If a single integer is provided for a list field, wrap it in a list
                    profile_data_dict[field] = [parsed_value]
                else:
                    # If it's neither a list nor an int after JSON parsing,
                    # it's likely an invalid JSON string for a list, so keep the original string
                    # to potentially try comma-separated parsing or let Pydantic validate.
                    pass
            except (json.JSONDecodeError, TypeError):
                # If JSON parsing fails, it might be a plain comma-separated string, e.g., "1,2,3"
                value_str = profile_data_dict[field]
                if value_str:
                    try:
                        profile_data_dict[field] = [int(i.strip()) for i in value_str.split(',') if i.strip()]
                    except (ValueError, TypeError):
                        pass # Let Pydantic handle the original string if conversion fails
                else:
                    profile_data_dict[field] = [] # Treat empty string as an empty list

    # Create a ProfileUpdate schema instance from the parsed data
    profile_create_schema = schemas.ProfileUpdate(**profile_data_dict)

    # 4. Create the profile with photos
    await crud.create_profile(db=db, profile_in=profile_create_schema, user_id=new_user.id, photos=photos)

    # 5. Generate and return access token
    access_token_expires = timedelta(minutes=settings.access_token_expire_minutes)
    access_token = create_access_token(data={"sub": new_user.email}, expires_delta=access_token_expires)
    return {"access_token": access_token, "token_type": "bearer"}

@app.post("/api/post/core-values", response_model=List[schemas.CoreValue], status_code=status.HTTP_200_OK)
def update_core_values_for_profile(core_values_update: schemas.CoreValuAddition, db: Session = Depends(get_db)):
    """Updates (replaces) the core values for a profile."""
    updated_values = crud.update_core_values(update_data=core_values_update, db=db)
    if updated_values is None:
        raise HTTPException(status_code=404, detail="Profile not found")
    return updated_values


# ----------------- STATIC DATA -----------------

@app.get("/api/sexes/", response_model=List[schemas.Sex])
def read_sexes(db: Session = Depends(get_db)):
    return crud.get_sexes(db)


@app.get("/api/orientations/", response_model=List[schemas.Orientation])
def read_orientations(db: Session = Depends(get_db)):
    return crud.get_orientations(db)


@app.get("/api/hobbies/", response_model=List[schemas.Hobby])
def read_hobbies(db: Session = Depends(get_db)):
    return crud.get_hobbies(db)

@app.get("/api/educations/", response_model=List[schemas.Education])
def read_educations(db: Session = Depends(get_db)):
    return crud.get_educations(db)

@app.get("/api/professions/", response_model=List[schemas.Profession])
def read_professions(db: Session = Depends(get_db)):
    return crud.get_professions(db)

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
    update_data_dict = profile_in.dict(exclude_unset=True)

    # Parse JSON string fields back into lists of integers for relationship fields
    list_fields_to_parse = ['intention_ids', 'core_value_ids', 'hobby_ids', 'profession_ids', 'education_ids']
    for field in list_fields_to_parse:
        if update_data_dict.get(field) and isinstance(update_data_dict[field], str):
            try:
                parsed_value = json.loads(update_data_dict[field])
                if isinstance(parsed_value, list):
                    update_data_dict[field] = parsed_value
                elif isinstance(parsed_value, int):
                    # If a single integer is provided for a list field, wrap it in a list
                    update_data_dict[field] = [parsed_value]
                else:
                    # If it's neither a list nor an int after JSON parsing,
                    # it's likely an invalid JSON string for a list, so keep the original string
                    # to potentially try comma-separated parsing or let Pydantic validate.
                    pass
            except (json.JSONDecodeError, TypeError):
                # If JSON parsing fails, it might be a plain comma-separated string, e.g., "1,2,3"
                value_str = update_data_dict[field]
                if value_str:
                    try:
                        update_data_dict[field] = [int(i.strip()) for i in value_str.split(',') if i.strip()]
                    except (ValueError, TypeError):
                        pass # Let Pydantic handle the original string if conversion fails
                else:
                    update_data_dict[field] = [] # Treat empty string as an empty list

    # Re-create ProfileUpdate with parsed lists
    profile_in_parsed = schemas.ProfileUpdate(**update_data_dict)
    update_data = profile_in_parsed.dict(exclude_unset=True)

    db_profile = crud.get_profile_by_user_id(db, user_id=current_user.id)
    

    if db_profile:
        # This is an update (PATCH)
        
        # Filter out theme-related fields to ensure independence. 
        # Profile updates should not modify theme settings.
        theme_keys = {'theme_id', 'background_color', 'accent_color', 'layout', 'theme_preferences'}
        filtered_data = {k: v for k, v in update_data_dict.items() if k not in theme_keys}

        update_data = schemas.ProfileUpdate(**filtered_data) # Use the filtered and parsed data
        
        # 1. Update profile fields and relationships (like intentions, core_values)
        await crud.update_profile(db=db, db_profile=db_profile, profile_in=update_data)

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
        settings = db.query(models.Settings).filter(models.Settings.user_id == db_profile.id).first()
        if settings:
            profile_dict['theme_preferences'] = {
                'theme_id': settings.theme_id,
                'background_color': settings.background_color,
                'accent_color': settings.accent_color,
                'layout': settings.layout
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
        create_data = schemas.ProfileUpdate(**update_data_dict) # Use the parsed data

        
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

    settings = db.query(models.Settings).filter(models.Settings.user_id == profile.id).first()
    if settings:
        profile_dict['theme_preferences'] = {
            'theme_id': settings.theme_id,
            'background_color': settings.background_color,
            'accent_color': settings.accent_color,
            'layout': settings.layout
        }
    return profile_dict

@app.get("/api/photos/{photo_id}", summary="Get a user's photo")
def get_photo(
    photo_id: int,
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    """Retrieves and serves a photo from the database."""
    photo = crud.get_photo_by_id(db, photo_id=photo_id, user_id=current_user.id)
    if not photo:
        raise HTTPException(status_code=404, detail="Photo not found or you don't have permission to view it.")
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

    db.commit()
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
