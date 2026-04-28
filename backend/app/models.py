import json
from sqlalchemy import Column, Integer, String, Date, Text, TIMESTAMP, ForeignKey, Table, LargeBinary, Boolean, func
from sqlalchemy.dialects import postgresql
from sqlalchemy.types import TypeDecorator, TEXT
from sqlalchemy.orm import relationship
from .database import Base

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
    
    profiles = relationship(
        "Profile",
        secondary=profile_hobbies,
        back_populates="hobbies"
    )

class Education(Base):
    __tablename__ = "educations"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, nullable=False)

class Profession(Base):
    __tablename__ = "professions"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, nullable=False)

class Orientation(Base):
    __tablename__ = "orientations"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, nullable=False)

class Sex(Base):
    __tablename__ = "sexes"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, nullable=False)

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



class UserPhoto(Base):
    __tablename__ = "user_photos"

    id = Column(Integer, primary_key=True, index=True)
    profile_id = Column(Integer, ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False)
    photo_data = Column(LargeBinary, nullable=False)
    is_primary = Column(Boolean, default=False)
    upload_order = Column(Integer, default=0)
    created_at = Column(TIMESTAMP, server_default=func.now())
    profile = relationship("Profile", back_populates="photos")
