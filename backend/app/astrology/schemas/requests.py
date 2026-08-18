from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import date, time


class BirthDataRequest(BaseModel):
    birth_date: date
    birth_time: time
    timezone: str = Field(..., description="Timezone offset, e.g. +05:30, -05:00, Asia/Tbilisi")
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    location_name: Optional[str] = None


class ChartRequest(BaseModel):
    birth_data: BirthDataRequest
    system: str = Field(default="western_tropical", description="western_tropical or vedic_sidereal")
    ayanamsa: Optional[str] = Field(default="Lahiri", description="Ayanamsa for Vedic charts")


class SynastryRequest(BaseModel):
    person_a: BirthDataRequest
    person_b: BirthDataRequest


class CompatibilityRequest(BaseModel):
    person_a: BirthDataRequest
    person_b: BirthDataRequest
    ayanamsa: Optional[str] = Field(default="Lahiri")


class InterpretationRequest(BaseModel):
    person_a: BirthDataRequest
    person_b: BirthDataRequest
    ayanamsa: Optional[str] = Field(default="Lahiri")
    include_vedic: bool = Field(default=True)
