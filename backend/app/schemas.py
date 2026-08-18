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
    translation_key: Optional[str] = None

class Orientation(OrmBaseModel):
    id: int
    name: str
    translation_key: Optional[str] = None

class Hobby(OrmBaseModel):
    id: int
    name: str
    translation_key: Optional[str] = None

class Education(OrmBaseModel):
    id: int
    name: str
    translation_key: Optional[str] = None

class Profession(OrmBaseModel):
    id: int
    name: str
    translation_key: Optional[str] = None

class LocationParent(OrmBaseModel):
    id: int
    name: str
    translation_key: Optional[str] = None

class Location(OrmBaseModel):
    id: int
    name: str
    type: str
    parent_id: Optional[int] = None
    parent: Optional[LocationParent] = None
    translation_key: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None

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

class UserPreferencesCreate(BaseModel):
    min_age: Optional[int] = 18
    max_age: Optional[int] = 50
    max_distance: Optional[int] = 100
    genders: Optional[List[str]] = []
    orientations: Optional[List[str]] = []
    looking_for: Optional[List[str]] = []
    verified_only: Optional[bool] = False
    online_recently: Optional[bool] = False
    min_compatibility: Optional[int] = 0
    priority_type: Optional[str] = 'balanced'
    weight_romance: Optional[int] = 50
    weight_emotional: Optional[int] = 50
    weight_communication: Optional[int] = 50
    weight_long_term: Optional[int] = 50
    weight_marriage: Optional[int] = 50
    weight_friendship: Optional[int] = 50
    weight_chemistry: Optional[int] = 50
    weight_spiritual: Optional[int] = 50
    birth_time_requirement: Optional[str] = 'optional'
    wants_children: Optional[str] = None
    smoking: Optional[str] = None
    drinking: Optional[str] = None
    religion: Optional[str] = None
    political: Optional[str] = None
    education: Optional[str] = None
    languages: Optional[List[str]] = []
    pets: Optional[str] = None
    min_height: Optional[int] = None
    max_height: Optional[int] = None
    hide_swiped: Optional[bool] = True
    hide_inactive: Optional[bool] = False
    show_traveling: Optional[bool] = False
    global_search: Optional[bool] = False
    photos_only: Optional[bool] = False
    complete_profiles_only: Optional[bool] = False

class UserPreferencesResponse(OrmBaseModel):
    id: int
    profile_id: int
    min_age: int
    max_age: int
    max_distance: int
    genders: List[str]
    orientations: List[str]
    looking_for: List[str]
    verified_only: bool
    online_recently: bool
    min_compatibility: int
    priority_type: str
    weight_romance: int
    weight_emotional: int
    weight_communication: int
    weight_long_term: int
    weight_marriage: int
    weight_friendship: int
    weight_chemistry: int
    weight_spiritual: int
    birth_time_requirement: str
    wants_children: Optional[str]
    smoking: Optional[str]
    drinking: Optional[str]
    religion: Optional[str]
    political: Optional[str]
    education: Optional[str]
    languages: List[str]
    pets: Optional[str]
    min_height: Optional[int]
    max_height: Optional[int]
    hide_swiped: bool
    hide_inactive: bool
    show_traveling: bool
    global_search: bool
    photos_only: bool
    complete_profiles_only: bool

class AccountDeactivationRequest(BaseModel):
    reason: Optional[str] = None

class AccountReactivationRequest(BaseModel):
    email: Optional[EmailStr] = None
    phone_number: Optional[str] = None

class AccountReactivationVerify(BaseModel):
    email: Optional[EmailStr] = None
    phone_number: Optional[str] = None
    code: str

class AccountReactivationResponse(BaseModel):
    message: str
    access_token: Optional[str] = None
    token_type: Optional[str] = None

class BlockByNameRequest(BaseModel):
    name: str

class UserByEmailRequest(BaseModel):
    email: EmailStr


# --- Schemas for Matches ---

class MatchCreate(BaseModel):
    matched_user_id: int
    status: str = "pending"
    compatibility_score: Optional[int] = None

class MatchUpdate(BaseModel):
    status: str

class MatchResponse(OrmBaseModel):
    id: int
    user_id: int
    matched_user_id: int
    status: str
    compatibility_score: Optional[int]
    created_at: datetime
    updated_at: datetime

class MatchWithProfileResponse(OrmBaseModel):
    id: int
    user_id: int
    matched_user_id: int
    status: str
    compatibility_score: Optional[int]
    created_at: datetime
    updated_at: datetime
    matched_profile: Optional[dict] = None

class MutualMatchCheck(BaseModel):
    is_mutual: bool
    match_id: Optional[int] = None


# --- Schemas for Messages ---

class MessageCreate(BaseModel):
    match_id: int
    content: Optional[str] = None
    image_url: Optional[str] = None
    video_url: Optional[str] = None
    gif_url: Optional[str] = None
    message_type: str = "text"

class MessageResponse(OrmBaseModel):
    id: int
    match_id: int
    sender_id: int
    content: Optional[str] = None
    image_url: Optional[str] = None
    video_url: Optional[str] = None
    gif_url: Optional[str] = None
    message_type: str
    is_read: bool
    is_edited: bool
    created_at: datetime

class MessageEdit(BaseModel):
    content: str

class MessageForward(BaseModel):
    target_match_id: int

class ChatListResponse(OrmBaseModel):
    match_id: int
    matched_user_id: int
    matched_profile: Optional[dict] = None
    compatibility_score: Optional[int] = None
    last_message: Optional[str] = None
    last_message_at: Optional[datetime] = None
    last_message_sender_id: Optional[int] = None
    is_read: bool = True
    unread_count: int = 0

class ReceivedLikeResponse(OrmBaseModel):
    match_id: int
    user_id: int
    compatibility_score: Optional[int] = None
    created_at: datetime
    profile: Optional[dict] = None


class SmartDiscoverItem(OrmBaseModel):
    id: int
    user_id: int
    name: str
    last_name: str
    birth_date: Optional[str] = None
    birth_time: Optional[str] = None
    bio: Optional[str] = None
    height: Optional[int] = None
    location: Optional[dict] = None
    sex: Optional[dict] = None
    orientation: Optional[dict] = None
    photos: List[dict] = []
    hobbies: List[dict] = []
    intentions: List[dict] = []
    core_values: List[dict] = []
    professions: List[dict] = []
    educations: List[dict] = []
    compatibility_score: int = 0
    weighted_score: int = 0
    top_reasons: List[str] = []
    cosmic_insight: str = ""
    liked_by_user: bool = False


class RecommendationResponse(OrmBaseModel):
    id: int
    recommended_user_id: int
    score: int
    reasons: List[str] = []
    cosmic_insight: str = ""
    recommendation_date: str
    profile: Optional[dict] = None