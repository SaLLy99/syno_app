from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import date, time


class BirthDataRequest(BaseModel):
    birth_date: date
    birth_time: time
    timezone: str = Field(..., description="Timezone offset, e.g. +05:30, -05:00, Asia/Tbilisi")
    latitude: Optional[float] = Field(None, ge=-90, le=90)
    longitude: Optional[float] = Field(None, ge=-180, le=180)
    location_name: Optional[str] = None


class ChartRequest(BaseModel):
    birth_data: BirthDataRequest


class SynastryRequest(BaseModel):
    person_a: BirthDataRequest
    person_b: BirthDataRequest
    person_a_name: Optional[str] = None
    person_b_name: Optional[str] = None


class CompatibilityRequest(BaseModel):
    person_a: BirthDataRequest
    person_b: BirthDataRequest
    person_a_name: Optional[str] = None
    person_b_name: Optional[str] = None


class InterpretationRequest(BaseModel):
    person_a: BirthDataRequest
    person_b: BirthDataRequest
    person_a_name: Optional[str] = None
    person_b_name: Optional[str] = None
