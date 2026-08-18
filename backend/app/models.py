import json
from sqlalchemy import Column, Integer, String, Date, Text, TIMESTAMP, ForeignKey, Table, LargeBinary, Boolean, Float, func, Enum as SAEnum
from sqlalchemy.dialects import postgresql
from sqlalchemy.types import TypeDecorator, TEXT
from sqlalchemy.orm import relationship
from .database import Base
import enum

# Custom type for handling ARRAY in both PostgreSQL and SQLite
class ArrayAsJSON(TypeDecorator):
    """
    Platform-independent ARRAY type.

    Uses PostgreSQL's native ARRAY type, and TEXT with JSON for other backends
    like SQLite.
    """
    impl = TEXT
    cache_ok = True

    def load_dialect_impl(self, dialect):
        if dialect.name == 'postgresql':
            return dialect.type_descriptor(postgresql.ARRAY(String))
        else:
            return dialect.type_descriptor(TEXT)

    def process_bind_param(self, value, dialect):
        if dialect.name == 'postgresql' or value is None:
            return value
        return json.dumps(value)

    def process_result_value(self, value, dialect):
        if dialect.name == 'postgresql' or value is None:
            return value
        return json.loads(value)


class SynoUser(Base):
    __tablename__ = "syno_users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True, nullable=False)
    password_hash = Column(String, nullable=False)
    is_deactivated = Column(Boolean, default=False, nullable=False)
    deactivated_at = Column(TIMESTAMP, nullable=True)
    last_active_at = Column(TIMESTAMP, server_default=func.now())
    created_at = Column(TIMESTAMP, server_default=func.now())
    updated_at = Column(TIMESTAMP, server_default=func.now(), onupdate=func.now())

user_blocks = Table('user_blocks', Base.metadata,
    Column('blocker_id', Integer, ForeignKey('syno_users.id', ondelete="CASCADE"), primary_key=True),
    Column('blocked_id', Integer, ForeignKey('syno_users.id', ondelete="CASCADE"), primary_key=True),
    Column('created_at', TIMESTAMP, server_default=func.now())
)

class Settings(Base):
    __tablename__ = "settings"

    id = Column(Integer, primary_key=True, index=True)
    # The ForeignKeyViolation error indicates this FK must point to a record
    # in the `profiles` table. The constraint is on `profiles.id`, but the column is misnamed.
    user_id = Column(Integer, ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False, unique=True)
    theme_id = Column(String(50))
    background_color = Column(String(50))
    accent_color = Column(String(50))
    layout = Column(String(50))
    created_at = Column(TIMESTAMP, server_default=func.now())
    updated_at = Column(TIMESTAMP, server_default=func.now(), onupdate=func.now())

class Location(Base):
    __tablename__ = "locations"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, nullable=False)
    type = Column(String(10), nullable=False) # 'country' or 'city'
    parent_id = Column(Integer, ForeignKey('locations.id'), nullable=True)
    parent = relationship("Location", remote_side=[id])
    translation_key = Column(String, nullable=True)
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)


profile_hobbies = Table('profile_hobbies', Base.metadata,
    Column('profile_id', Integer, ForeignKey('profiles.id', ondelete="CASCADE"), primary_key=True),
    Column('hobby_id', Integer, ForeignKey('hobbies.id', ondelete="CASCADE"), primary_key=True)
)

profile_educations = Table('profile_educations', Base.metadata,
    Column('profile_id', Integer, ForeignKey('profiles.id', ondelete="CASCADE"), primary_key=True),
    Column('education_id', Integer, ForeignKey('educations.id', ondelete="CASCADE"), primary_key=True)
)

profile_professions = Table('profile_professions', Base.metadata,
    Column('profile_id', Integer, ForeignKey('profiles.id', ondelete="CASCADE"), primary_key=True),
    Column('profession_id', Integer, ForeignKey('professions.id', ondelete="CASCADE"), primary_key=True)
)

profile_core_values = Table('profile_core_values', Base.metadata,
    Column('profile_id', Integer, ForeignKey('profiles.id', ondelete="CASCADE"), primary_key=True),
    Column('core_value_id', Integer, ForeignKey('core_values.id', ondelete="CASCADE"), primary_key=True)
)

profile_intentions= Table('profile_intentions',Base.metadata,
                    Column('profile_id', Integer, ForeignKey('profiles.id', ondelete="CASCADE"), primary_key=True),
                    Column('intention_id', Integer, ForeignKey('intentions.id', ondelete="CASCADE"), primary_key=True)         
    )

class Hobby(Base):
    __tablename__ = "hobbies"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, nullable=False)
    translation_key = Column(String, nullable=True)
    
    profiles = relationship(
        "Profile",
        secondary=profile_hobbies,
        back_populates="hobbies"
    )

class Education(Base):
    __tablename__ = "educations"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, nullable=False)
    translation_key = Column(String, nullable=True)

class Profession(Base):
    __tablename__ = "professions"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, nullable=False)
    translation_key = Column(String, nullable=True)

class Orientation(Base):
    __tablename__ = "orientations"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, nullable=False)
    translation_key = Column(String, nullable=True)

class Sex(Base):
    __tablename__ = "sexes"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, nullable=False)
    translation_key = Column(String, nullable=True)

class CoreValue(Base):
    __tablename__ = "core_values"
    id = Column(Integer, primary_key=True, index=True)
    key = Column(String, unique=True, nullable=False)
    translation_key = Column(String, nullable=False)

    profiles = relationship(
        "Profile",
        secondary=profile_core_values,
        back_populates="core_values"
    )

class Intentions(Base):
    __tablename__ = "intentions"
    id = Column(Integer, primary_key=True, index=True)
    key = Column(String, unique=True, nullable=False)
    translation_key = Column(String, nullable=False)

    profiles = relationship(
        "Profile",
        secondary=profile_intentions,
        back_populates="intentions"
    )

class Profile(Base):
    __tablename__ = "profiles"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("syno_users.id", ondelete="CASCADE"), nullable=False, unique=True)
    name = Column(String, nullable=False)
    last_name = Column(String, nullable=False)
    birth_date = Column(Date, nullable=False)
    birth_time = Column(String(5))
    location_id = Column(Integer, ForeignKey("locations.id", ondelete="SET NULL"))
    sex_id = Column(Integer, ForeignKey("sexes.id", ondelete="RESTRICT"), nullable=False)
    orientation_id = Column(Integer, ForeignKey("orientations.id", ondelete="RESTRICT"), nullable=False)
    theme_id = Column(String(50))
    height = Column(Integer, nullable=True)
    phone_number = Column(String(20), unique=True, nullable=True)
    bio = Column(Text)
    created_at = Column(TIMESTAMP, server_default=func.now())
    updated_at = Column(TIMESTAMP, server_default=func.now(), onupdate=func.now())

    hobbies = relationship(
        "Hobby",
        secondary=profile_hobbies,
        back_populates="profiles"
    )
    core_values = relationship(
        "CoreValue",
        secondary=profile_core_values,
        back_populates="profiles"
    )
    intentions = relationship(
        "Intentions",
        secondary=profile_intentions,
        back_populates="profiles"
    )
    educations = relationship("Education", secondary=profile_educations)
    professions = relationship("Profession", secondary=profile_professions)
    sex = relationship("Sex", uselist=False)
    orientation = relationship("Orientation", uselist=False)
    photos = relationship("UserPhoto", back_populates="profile", cascade="all, delete-orphan")
    location = relationship("Location")

class OTP(Base):
    __tablename__ = "otps"
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, index=True, nullable=True)
    phone_number = Column(String(20), index=True, nullable=True)
    code = Column(String, nullable=False)
    otp_hash = Column(String, nullable=False)
    expires_at = Column(TIMESTAMP, nullable=False)
    used_flag = Column(Boolean, default=False)
    attempts = Column(Integer, default=0)
    created_at = Column(TIMESTAMP, server_default=func.now())



class UserPreferences(Base):
    __tablename__ = "user_preferences"

    id = Column(Integer, primary_key=True, index=True)
    profile_id = Column(Integer, ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False, unique=True)

    # Basic Filters
    min_age = Column(Integer, default=18)
    max_age = Column(Integer, default=50)
    max_distance = Column(Integer, default=100)
    genders = Column(postgresql.ARRAY(String), default=[])
    orientations = Column(postgresql.ARRAY(String), default=[])
    looking_for = Column(postgresql.ARRAY(String), default=[])
    verified_only = Column(Boolean, default=False)
    online_recently = Column(Boolean, default=False)

    # Astrology Preferences
    min_compatibility = Column(Integer, default=0)
    priority_type = Column(String(50), default='balanced')
    weight_romance = Column(Integer, default=50)
    weight_emotional = Column(Integer, default=50)
    weight_communication = Column(Integer, default=50)
    weight_long_term = Column(Integer, default=50)
    weight_marriage = Column(Integer, default=50)
    weight_friendship = Column(Integer, default=50)
    weight_chemistry = Column(Integer, default=50)
    weight_spiritual = Column(Integer, default=50)
    birth_time_requirement = Column(String(20), default='optional')

    # Lifestyle
    wants_children = Column(String(20), nullable=True)
    smoking = Column(String(20), nullable=True)
    drinking = Column(String(20), nullable=True)
    religion = Column(String(50), nullable=True)
    political = Column(String(50), nullable=True)
    education = Column(String(50), nullable=True)
    languages = Column(postgresql.ARRAY(String), default=[])
    pets = Column(String(20), nullable=True)
    min_height = Column(Integer, nullable=True)
    max_height = Column(Integer, nullable=True)

    # Advanced
    hide_swiped = Column(Boolean, default=True)
    hide_inactive = Column(Boolean, default=False)
    show_traveling = Column(Boolean, default=False)
    global_search = Column(Boolean, default=False)
    photos_only = Column(Boolean, default=False)
    complete_profiles_only = Column(Boolean, default=False)

    created_at = Column(TIMESTAMP, server_default=func.now())
    updated_at = Column(TIMESTAMP, server_default=func.now(), onupdate=func.now())

    profile = relationship("Profile", backref="user_preferences")


class UserPhoto(Base):
    __tablename__ = "user_photos"

    id = Column(Integer, primary_key=True, index=True)
    profile_id = Column(Integer, ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False)
    photo_data = Column(LargeBinary, nullable=False)
    is_primary = Column(Boolean, default=False)
    upload_order = Column(Integer, default=0)
    created_at = Column(TIMESTAMP, server_default=func.now())
    profile = relationship("Profile", back_populates="photos")


class Match(Base):
    __tablename__ = "matches"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("syno_users.id", ondelete="CASCADE"), nullable=False)
    matched_user_id = Column(Integer, ForeignKey("syno_users.id", ondelete="CASCADE"), nullable=False)
    status = Column(String(20), nullable=False, default="pending")
    compatibility_score = Column(Integer, nullable=True)
    created_at = Column(TIMESTAMP, server_default=func.now())
    updated_at = Column(TIMESTAMP, server_default=func.now(), onupdate=func.now())

    user = relationship("SynoUser", foreign_keys=[user_id])
    matched_user = relationship("SynoUser", foreign_keys=[matched_user_id])


class Message(Base):
    __tablename__ = "messages"

    id = Column(Integer, primary_key=True, index=True)
    match_id = Column(Integer, ForeignKey("matches.id", ondelete="CASCADE"), nullable=False)
    sender_id = Column(Integer, ForeignKey("syno_users.id", ondelete="CASCADE"), nullable=False)
    content = Column(Text, nullable=True)
    image_url = Column(String(500), nullable=True)
    video_url = Column(String(500), nullable=True)
    gif_url = Column(String(500), nullable=True)
    message_type = Column(String(20), default="text")
    is_read = Column(Boolean, default=False)
    is_edited = Column(Boolean, default=False)
    created_at = Column(TIMESTAMP, server_default=func.now())

    match = relationship("Match")
    sender = relationship("SynoUser")


class MatchCache(Base):
    __tablename__ = "match_cache"

    id = Column(Integer, primary_key=True, index=True)
    user_a_id = Column(Integer, ForeignKey("syno_users.id", ondelete="CASCADE"), nullable=False)
    user_b_id = Column(Integer, ForeignKey("syno_users.id", ondelete="CASCADE"), nullable=False)
    synastry_data = Column(Text, nullable=False)
    final_score = Column(Integer, nullable=False)
    weighted_score = Column(Integer, nullable=True)
    top_reasons = Column(Text, nullable=True)
    cosmic_insight = Column(Text, nullable=True)
    computed_at = Column(TIMESTAMP, server_default=func.now())

    __table_args__ = (
        {'sqlite_autoincrement': True},
    )


class Recommendation(Base):
    __tablename__ = "recommendations"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("syno_users.id", ondelete="CASCADE"), nullable=False)
    recommended_user_id = Column(Integer, ForeignKey("syno_users.id", ondelete="CASCADE"), nullable=False)
    score = Column(Integer, nullable=False)
    reasons = Column(Text, nullable=True)
    cosmic_insight = Column(Text, nullable=True)
    recommendation_date = Column(Date, nullable=False)
    created_at = Column(TIMESTAMP, server_default=func.now())

    user = relationship("SynoUser", foreign_keys=[user_id])
    recommended_user = relationship("SynoUser", foreign_keys=[recommended_user_id])


class AnalyticsEvent(Base):
    __tablename__ = "analytics_events"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("syno_users.id", ondelete="CASCADE"), nullable=False)
    event_type = Column(String(50), nullable=False)
    event_metadata = Column(Text, nullable=True)
    created_at = Column(TIMESTAMP, server_default=func.now())

    user = relationship("SynoUser")
