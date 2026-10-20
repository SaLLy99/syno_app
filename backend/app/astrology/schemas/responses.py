from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import date, time


class PlanetPositionResponse(BaseModel):
    planet: str
    sign: str
    degree: float
    absolute_degree: float
    house: Optional[int] = None
    retrograde: bool = False
    sign_degree: str = ""


class AspectResponse(BaseModel):
    planet_a: str
    planet_b: str
    aspect: str
    orb: float
    applying: Optional[bool] = None


class HouseCuspResponse(BaseModel):
    house_number: int
    sign: str
    degree: float
    absolute_degree: float


class WesternChartResponse(BaseModel):
    system: str = "western_tropical"
    planets: List[PlanetPositionResponse] = []
    aspects: List[AspectResponse] = []
    house_cusps: List[HouseCuspResponse] = []
    ascendant: Optional[PlanetPositionResponse] = None
    mc: Optional[PlanetPositionResponse] = None


class PlanetToPlanetAspectResponse(BaseModel):
    planet_a: str
    planet_b: str
    aspect: str
    orb: float
    sign_a: str
    sign_b: str
    house_a: Optional[int] = None
    house_b: Optional[int] = None


class HouseOverlayResponse(BaseModel):
    planet: str
    overlay_house: int
    sign: str
    degree: float


class SynastryResponse(BaseModel):
    person_a_chart: Optional[WesternChartResponse] = None
    person_b_chart: Optional[WesternChartResponse] = None
    planet_aspects: List[PlanetToPlanetAspectResponse] = []
    house_overlays_a_to_b: List[HouseOverlayResponse] = []
    house_overlays_b_to_a: List[HouseOverlayResponse] = []
    conjunctions: List[PlanetToPlanetAspectResponse] = []
    oppositions: List[PlanetToPlanetAspectResponse] = []
    trines: List[PlanetToPlanetAspectResponse] = []
    squares: List[PlanetToPlanetAspectResponse] = []
    sextiles: List[PlanetToPlanetAspectResponse] = []


class CompatibilityDimensionsResponse(BaseModel):
    emotional: float = 50.0
    communication: float = 50.0
    values: float = 50.0
    attraction: float = 50.0
    conflict: float = 50.0
    stability: float = 50.0
    growth: float = 50.0
    overall: float = 50.0


class InterpretationResponse(BaseModel):
    summary: str = ""
    strengths: List[str] = []
    challenges: List[str] = []
    communication: str = ""
    emotional_dynamic: str = ""
    values: str = ""
    growth_dynamic: str = ""
    important_aspects: List[dict] = []
    ai_used: bool = False
    personality_a: str = ""
    personality_b: str = ""
    love_language: str = ""
    trust_loyalty: str = ""
    intimacy_text: str = ""
    conflict_style: str = ""
    overall_verdict: str = ""
    coach_tips: List[str] = []


class CompatibilityResponse(BaseModel):
    western_synastry: Optional[SynastryResponse] = None
    dimensions: Optional[CompatibilityDimensionsResponse] = None
    interpretation: Optional[InterpretationResponse] = None
    ai_used: bool = False
