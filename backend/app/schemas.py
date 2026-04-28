from pydantic import BaseModel, EmailStr, field_validator
from typing import List, Optional
from datetime import date, datetime
import json
from fastapi import Form


class OrmBaseModel(BaseModel):
    """Base model for schemas that are read from the database, enabling ORM mode."""
    class Config:
        from_attributes = True

# --- Schemas for Static Data ---

class Sex(OrmBaseModel):
    id: int
    name: str

class Orientation(OrmBaseModel):
    id: int
    name: str

class Hobby(OrmBaseModel):
    id: int
    name: str

class Education(OrmBaseModel):
    id: int
    name: str

class Profession(OrmBaseModel):
    id: int
    name: str

class LocationParent(OrmBaseModel):
    id: int
    name: str

class Location(OrmBaseModel):
    id: int
    name: str
    type: str
    parent_id: Optional[int] = None
    parent: Optional[LocationParent] = None

class UserPhoto(OrmBaseModel):
    id: int
    is_primary: bool
    upload_order: int

# --- Schemas for Core Values and Intentions ---

class CoreValue(OrmBaseModel):
    """Schema for a single core value."""
    id: int
    key: str
    translation_key: str

class CoreValuAddition(BaseModel):
    """Schema for adding a core value to a profile."""
    profile_id: int
    core_value_id: list[int]
   

class Intention(OrmBaseModel):
    """Schema for a single intention."""
    id: int
    key: str
    translation_key: str

# --- Schemas for Authentication ---

class UserBase(BaseModel):
    email: EmailStr

class OTPRequest(BaseModel):
    email: Optional[EmailStr] = None
    phone_number: Optional[str] = None
    lang: Optional[str] = "en"

class SMSOTPRequest(BaseModel):
    phone_number: str
    lang: Optional[str] = "en"

class SMSOTPVerify(BaseModel):
    phone_number: str
    code: str

class OTPVerify(BaseModel):
    email: Optional[EmailStr] = None
    phone_number: Optional[str] = None
    code: str

class OTPVerifyResponse(BaseModel):
    message: Optional[str] = None
    is_registered: bool
    access_token: Optional[str] = None
    token_type: Optional[str] = None

class UserCreate(UserBase):
    password: str
    full_name: Optional[str] = None

class UserLogin(UserBase):
    password: str

class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    email: Optional[str] = None

# --- Schemas for Profile ---

class ProfileBase(BaseModel):
    name: str
    last_name: Optional[str] = None
    birth_date: date
    birth_time: Optional[str] = None
    location_id: int
    sex_id: int
    orientation_id: int
    height: Optional[int] = None
    phone_number: Optional[str] = None
    bio: Optional[str] = None

class ProfileUpdate(BaseModel):
    """Schema for updating a profile. All fields are optional."""
    name: Optional[str] = None
    last_name: Optional[str] = None
    birth_date: Optional[date] = None
    birth_time: Optional[str] = None
    location_id: Optional[int] = None
    sex_id: Optional[int] = None
    orientation_id: Optional[int] = None
    height: Optional[int] = None
    phone_number: Optional[str] = None
    bio: Optional[str] = None
    intention_ids: Optional[List[int]] = None
    core_value_ids: Optional[List[int]] = None
    hobby_ids: Optional[List[int]] = None
    profession_ids: Optional[List[int]] = None
    education_ids: Optional[List[int]] = None

class ProfileUpdateForm(ProfileUpdate):
    """
    Helper class to correctly parse form data from the PATCH endpoint,
    especially for fields that come in as JSON strings.
    """
    @classmethod
    def as_form_patch(
        cls,
        name: Optional[str] = Form(None),
        last_name: Optional[str] = Form(None),
        birth_date: Optional[date] = Form(None),
        birth_time: Optional[str] = Form(None),
        location_id: Optional[int] = Form(None),
        sex_id: Optional[int] = Form(None),
        orientation_id: Optional[int] = Form(None),
        height: Optional[int] = Form(None),
        phone_number: Optional[str] = Form(None),
        bio: Optional[str] = Form(None),
        intention_ids: Optional[str] = Form(None),
        core_value_ids: Optional[str] = Form(None),
        hobby_ids: Optional[str] = Form(None),
        profession_ids: Optional[str] = Form(None),
        education_ids: Optional[str] = Form(None),
    ):
        # Filter out None values to ensure they are treated as unset by Pydantic.
        # This prevents overwriting existing database values with None.
        params = locals()
        data = {k: v for k, v in params.items() if k != 'cls' and v is not None}

        # Parse JSON strings for list fields if they are provided as strings
        list_fields = ['intention_ids', 'core_value_ids', 'hobby_ids', 'profession_ids', 'education_ids']
        for field in list_fields:
            if field in data and isinstance(data[field], str):
                try:
                    parsed_value = json.loads(data[field])
                    if isinstance(parsed_value, list):
                        data[field] = parsed_value
                    elif isinstance(parsed_value, int):
                        # If a single integer is provided for a list field, wrap it in a list
                        data[field] = [parsed_value]
                    else:
                        # If it's neither a list nor an int after JSON parsing,
                        # it's likely an invalid JSON string for a list, so keep the original string
                        # to potentially try comma-separated parsing or let Pydantic validate.
                        pass
                except (json.JSONDecodeError, TypeError):
                    # If JSON parsing fails, it might be a plain comma-separated string, e.g., "1,2,3"
                    value_str = data[field]
                    if value_str:
                        try:
                            # Split by comma, strip whitespace from each part, and convert to int
                            data[field] = [int(i.strip()) for i in value_str.split(',') if i.strip()]
                        except (ValueError, TypeError):
                            # If this conversion also fails, let Pydantic's validation handle the original string
                            pass
                    else:
                        data[field] = [] # Treat empty string as an empty list

        return cls(**data)

class Profile(ProfileBase, OrmBaseModel):
    """The main response model for a user's profile."""
    id: int
    user_id: int
    created_at: datetime
    updated_at: datetime
    
    location: Optional[Location] = None
    sex: Optional[Sex] = None
    orientation: Optional[Orientation] = None
    
    # Relationships that will be populated from the database
    intentions: List[Intention] = []
    core_values: List[CoreValue] = []
    hobbies: List[Hobby] = []
    professions: List[Profession] = []
    educations: List[Education] = []
    photos: List[UserPhoto] = []
    
    # This field is populated separately from the `settings` table
    theme_preferences: Optional[dict] = None

# --- Schema for Theme Settings ---

class ThemeSettingsUpdate(BaseModel):
    theme_id: str
    background_color: str
    accent_color: str
    layout: str

class BlockByNameRequest(BaseModel):
    name: str

class UserByEmailRequest(BaseModel):
    email: EmailStr