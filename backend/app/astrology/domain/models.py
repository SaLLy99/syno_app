from datetime import date, time
from enum import Enum
from typing import Optional, List
from pydantic import BaseModel, Field


class AstrologySystem(str, Enum):
    WESTERN_TROPICAL = "western_tropical"


class ZodiacSign(str, Enum):
    ARIES = "Aries"
    TAURUS = "Taurus"
    GEMINI = "Gemini"
    CANCER = "Cancer"
    LEO = "Leo"
    VIRGO = "Virgo"
    LIBRA = "Libra"
    SCORPIO = "Scorpio"
    SAGITTARIUS = "Sagittarius"
    CAPRICORN = "Capricorn"
    AQUARIUS = "Aquarius"
    PISCES = "Pisces"


class PlanetName(str, Enum):
    SUN = "Sun"
    MOON = "Moon"
    MERCURY = "Mercury"
    VENUS = "Venus"
    MARS = "Mars"
    JUPITER = "Jupiter"
    SATURN = "Saturn"
    URANUS = "Uranus"
    NEPTUNE = "Neptune"
    PLUTO = "Pluto"
    ASCENDANT = "Ascendant"


class AspectType(str, Enum):
    CONJUNCTION = "conjunction"
    OPPOSITION = "opposition"
    TRINE = "trine"
    SQUARE = "square"
    SEXTILE = "sextile"
    QUINCUNX = "quincunx"
    SEMI_SEXTILE = "semi_sextile"
    SEMI_SQUARE = "semi_square"


class BirthData(BaseModel):
    birth_date: date
    birth_time: time
    timezone: str
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    location_name: Optional[str] = None


class PlanetPosition(BaseModel):
    planet: PlanetName
    sign: ZodiacSign
    degree: float = Field(ge=0, le=30)
    absolute_degree: float = Field(ge=0, le=360)
    house: Optional[int] = Field(None, ge=1, le=12)
    retrograde: bool = False
    sign_degree: str = ""


class AspectData(BaseModel):
    planet_a: PlanetName
    planet_b: PlanetName
    aspect: AspectType
    orb: float = Field(ge=0)
    applying: Optional[bool] = None


class HouseCusp(BaseModel):
    house_number: int = Field(ge=1, le=12)
    sign: ZodiacSign
    degree: float = Field(ge=0, le=30)
    absolute_degree: float = Field(ge=0, le=360)


class WesternChart(BaseModel):
    system: AstrologySystem = AstrologySystem.WESTERN_TROPICAL
    planets: List[PlanetPosition] = []
    aspects: List[AspectData] = []
    house_cusps: List[HouseCusp] = []
    ascendant: Optional[PlanetPosition] = None
    mc: Optional[PlanetPosition] = None


class PlanetToPlanetAspect(BaseModel):
    planet_a: PlanetName
    planet_b: PlanetName
    aspect: AspectType
    orb: float = Field(ge=0)
    sign_a: ZodiacSign
    sign_b: ZodiacSign
    house_a: Optional[int] = None
    house_b: Optional[int] = None


class HouseOverlay(BaseModel):
    planet: PlanetName
    overlay_house: int = Field(ge=1, le=12)
    sign: ZodiacSign
    degree: float = Field(ge=0, le=30)


class SynastryResult(BaseModel):
    person_a_chart: Optional[WesternChart] = None
    person_b_chart: Optional[WesternChart] = None
    planet_aspects: List[PlanetToPlanetAspect] = []
    house_overlays_a_to_b: List[HouseOverlay] = []
    house_overlays_b_to_a: List[HouseOverlay] = []
    conjunctions: List[PlanetToPlanetAspect] = []
    oppositions: List[PlanetToPlanetAspect] = []
    trines: List[PlanetToPlanetAspect] = []
    squares: List[PlanetToPlanetAspect] = []
    sextiles: List[PlanetToPlanetAspect] = []


class CompatibilityDimensions(BaseModel):
    emotional: float = Field(default=50.0, ge=0, le=100)
    communication: float = Field(default=50.0, ge=0, le=100)
    values: float = Field(default=50.0, ge=0, le=100)
    attraction: float = Field(default=50.0, ge=0, le=100)
    conflict: float = Field(default=50.0, ge=0, le=100)
    stability: float = Field(default=50.0, ge=0, le=100)
    growth: float = Field(default=50.0, ge=0, le=100)
    overall: float = Field(default=50.0, ge=0, le=100)


class InterpretationResult(BaseModel):
    summary: str = ""
    strengths: List[str] = []
    challenges: List[str] = []
    communication: str = ""
    emotional_dynamic: str = ""
    values: str = ""
    growth_dynamic: str = ""
    important_aspects: List[dict] = []
    personality_a: str = ""
    personality_b: str = ""
    love_language: str = ""
    trust_loyalty: str = ""
    intimacy_text: str = ""
    conflict_style: str = ""
    overall_verdict: str = ""
    coach_tips: List[str] = []
