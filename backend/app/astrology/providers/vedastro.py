import logging
from datetime import datetime, timezone, timedelta
from typing import List, Optional

from ..domain.models import (
    BirthData,
    WesternChart,
    VedicChart,
    VedicPlanetPosition,
    PlanetName,
    ZodiacSign,
    Nakshatra,
    AstrologySystem,
    SynastryResult,
    VedicCompatibilityResult,
    PlanetToPlanetAspect,
    AspectType,
    HouseOverlay,
    PlanetPosition,
)
from ..domain.provider import AstrologyProvider

logger = logging.getLogger(__name__)

try:
    from vedastro import Calculate, Time, GeoLocation, PlanetName as VedPlanetName, Ayanamsa
    VEDASTRO_AVAILABLE = True
except ImportError:
    VEDASTRO_AVAILABLE = False

VEDIC_PLANET_MAP = {
    PlanetName.SUN: "Sun",
    PlanetName.MOON: "Moon",
    PlanetName.MERCURY: "Mercury",
    PlanetName.VENUS: "Venus",
    PlanetName.MARS: "Mars",
    PlanetName.JUPITER: "Jupiter",
    PlanetName.SATURN: "Saturn",
    PlanetName.RAHU: "Rahu",
    PlanetName.KETU: "Ketu",
}

VEDIC_AYANAMSA_MAP = {
    "Lahiri": "Lahiri",
    "Raman": "Raman",
    "Krishnamurti": "Krishnamurti",
    "Fagan-Bradley": "Fagan_Bradley",
    "Yukteswar": "Yukteswar",
}

NAKSHATRA_NAMES = [
    "Ashwini", "Bharani", "Krittika", "Rohini", "Mrigashira",
    "Ardra", "Punarvasu", "Pushya", "Ashlesha", "Magha",
    "Purva Phalguni", "Uttara Phalguni", "Hasta", "Chitra",
    "Swati", "Vishakha", "Anuradha", "Jyeshta", "Mula",
    "Purva Ashadha", "Uttara Ashadha", "Shravana", "Dhanishta",
    "Shatabhisha", "Purva Bhadra", "Uttara Bhadra", "Revati",
]


def _format_degree(deg: float) -> str:
    d = int(deg)
    m = int((deg - d) * 60)
    s = int(((deg - d) * 60 - m) * 60)
    return f"{d}°{m:02d}'{s:02d}\""


def _get_sign_and_degree(absolute_deg: float):
    signs = [
        ZodiacSign.ARIES, ZodiacSign.TAURUS, ZodiacSign.GEMINI,
        ZodiacSign.CANCER, ZodiacSign.LEO, ZodiacSign.VIRGO,
        ZodiacSign.LIBRA, ZodiacSign.SCORPIO, ZodiacSign.SAGITTARIUS,
        ZodiacSign.CAPRICORN, ZodiacSign.AQUARIUS, ZodiacSign.PISCES,
    ]
    sign_idx = int(absolute_deg / 30) % 12
    degree_in_sign = absolute_deg % 30
    return signs[sign_idx], degree_in_sign


def _offset_to_hours(offset_str: str) -> float:
    if "+" in offset_str:
        parts = offset_str.split("+")
        sign = 1
    elif offset_str.startswith("-"):
        parts = offset_str.split("-")
        sign = -1
    else:
        return 0.0
    h, m = map(int, parts[1].split(":"))
    return sign * (h + m / 60.0)


class VedAstroProvider(AstrologyProvider):
    """Vedic astrology provider using the VedAstro Python library."""

    def __init__(self, api_key: str = "FreeAPIUser"):
        self.api_key = api_key
        if VEDASTRO_AVAILABLE:
            Calculate.SetAPIKey(api_key)

    def _birth_data_to_vedastro_time(self, birth_data: BirthData):
        if not VEDASTRO_AVAILABLE:
            raise ImportError("vedastro library is not installed. Run: pip install vedastro")

        offset_hours = _offset_to_hours(birth_data.timezone)
        offset_sign = "+" if offset_hours >= 0 else "-"
        abs_hours = abs(offset_hours)
        h = int(abs_hours)
        m = int((abs_hours - h) * 60)
        offset_str = f"{offset_sign}{h:02d}:{m:02d}"

        time_str = f"{birth_data.birth_time.hour:02d}:{birth_data.birth_time.minute:02d} {birth_data.birth_date.day:02d}/{birth_data.birth_date.month:02d}/{birth_data.birth_date.year:04d} {offset_str}"
        geo = GeoLocation(
            birth_data.location_name or "Unknown",
            birth_data.longitude,
            birth_data.latitude,
        )
        return Time(time_str, geo)

    def _set_ayanamsa(self, ayanamsa: str):
        if not VEDASTRO_AVAILABLE:
            return
        vedastro_name = VEDIC_AYANAMSA_MAP.get(ayanamsa, "Lahiri")
        try:
            ayanamsa_enum = getattr(Ayanamsa, vedastro_name, None)
            if ayanamsa_enum:
                Calculate.SetAyanamsa(ayanamsa_enum)
        except Exception as e:
            logger.warning(f"Failed to set ayanamsa {ayanamsa}: {e}")

    def _get_nakshatra(self, moon_longitude: float) -> Optional[Nakshatra]:
        nakshatra_size = 360 / 27
        idx = int(moon_longitude / nakshatra_size) % 27
        try:
            return Nakshatra(NAKSHATRA_NAMES[idx])
        except (ValueError, IndexError):
            return None

    def _get_pada(self, moon_longitude: float) -> int:
        nakshatra_size = 360 / 27
        pada_size = nakshatra_size / 4
        position_in_nakshatra = moon_longitude % nakshatra_size
        return int(position_in_nakshatra / pada_size) + 1

    def get_western_chart(self, birth_data: BirthData) -> WesternChart:
        raise NotImplementedError(
            "Western tropical charts require the SwissEph provider. "
            "Use SwissEphProvider for Western charts."
        )

    def get_vedic_chart(
        self,
        birth_data: BirthData,
        ayanamsa: str = "Lahiri",
    ) -> VedicChart:
        vedastro_time = self._birth_data_to_vedastro_time(birth_data)
        self._set_ayanamsa(ayanamsa)

        planets = []
        moon_longitude = 0.0

        vedic_planets = [
            (PlanetName.SUN, "Sun"),
            (PlanetName.MOON, "Moon"),
            (PlanetName.MERCURY, "Mercury"),
            (PlanetName.VENUS, "Venus"),
            (PlanetName.MARS, "Mars"),
            (PlanetName.JUPITER, "Jupiter"),
            (PlanetName.SATURN, "Saturn"),
            (PlanetName.RAHU, "Rahu"),
            (PlanetName.KETU, "Ketu"),
        ]

        for planet_name, ved_name in vedic_planets:
            try:
                if VEDASTRO_AVAILABLE:
                    sign_name = Calculate.PlanetSignName(
                        getattr(VedPlanetName, ved_name, None),
                        vedastro_time,
                    )
                    longitude = Calculate.PlanetNirayanaLongitude(
                        getattr(VedPlanetName, ved_name, None),
                        vedastro_time,
                    )
                    retrograde = Calculate.IsPlanetRetrograde(
                        getattr(VedPlanetName, ved_name, None),
                        vedastro_time,
                    )
                    house_num = Calculate.PlanetHouseName(
                        getattr(VedPlanetName, ved_name, None),
                        vedastro_time,
                    )

                    sign, degree = _get_sign_and_degree(longitude)

                    if planet_name == PlanetName.MOON:
                        moon_longitude = longitude

                    planets.append(VedicPlanetPosition(
                        planet=planet_name,
                        sign=sign,
                        degree=round(degree, 4),
                        absolute_degree=round(longitude, 4),
                        house=self._parse_house_number(house_num),
                        retrograde=retrograde,
                        sign_degree=_format_degree(degree),
                    ))
            except Exception as e:
                logger.warning(f"Failed to calculate {ved_name}: {e}")
                continue

        ascendant = None
        try:
            if VEDASTRO_AVAILABLE:
                asc_sign = Calculate.HouseSignName(
                    getattr(VedPlanetName, "House1", None),
                    vedastro_time,
                )
                asc_longitude = Calculate.HouseSignLongitude(
                    getattr(VedPlanetName, "House1", None),
                    vedastro_time,
                )
                sign, degree = _get_sign_and_degree(asc_longitude)
                ascendant = VedicPlanetPosition(
                    planet=PlanetName.ASCENDANT,
                    sign=sign,
                    degree=round(degree, 4),
                    absolute_degree=round(asc_longitude, 4),
                    house=1,
                    retrograde=False,
                    sign_degree=_format_degree(degree),
                )
        except Exception as e:
            logger.warning(f"Failed to calculate ascendant: {e}")

        nakshatra = self._get_nakshatra(moon_longitude)
        pada = self._get_pada(moon_longitude)

        moon_sign = None
        sun_sign = None
        for p in planets:
            if p.planet == PlanetName.MOON:
                moon_sign = p.sign
            elif p.planet == PlanetName.SUN:
                sun_sign = p.sign

        if ascendant and ascendant not in planets:
            planets.insert(0, ascendant)

        return VedicChart(
            system=AstrologySystem.VEDIC_SIDEREAL,
            ayanamsa=ayanamsa,
            planets=planets,
            ascendant=ascendant,
            moon_sign=moon_sign,
            sun_sign=sun_sign,
        )

    def _parse_house_number(self, house_str) -> Optional[int]:
        if house_str is None:
            return None
        try:
            s = str(house_str)
            for i in range(1, 13):
                if str(i) in s or f"House{i}" in s:
                    return i
        except Exception:
            pass
        return None

    def get_synastry(
        self,
        person_a: BirthData,
        person_b: BirthData,
    ) -> SynastryResult:
        raise NotImplementedError(
            "Synastry requires the SwissEph provider for Western aspects. "
            "Use SwissEphProvider.get_synastry() for synastry calculations."
        )

    def get_vedic_compatibility(
        self,
        person_a: BirthData,
        person_b: BirthData,
        ayanamsa: str = "Lahiri",
    ) -> VedicCompatibilityResult:
        vedastro_time_a = self._birth_data_to_vedastro_time(person_a)
        vedastro_time_b = self._birth_data_to_vedastro_time(person_b)
        self._set_ayanamsa(ayanamsa)

        chart_a = self.get_vedic_chart(person_a, ayanamsa)
        chart_b = self.get_vedic_chart(person_b, ayanamsa)

        kuta_score = None
        kuta_details = {}
        summary = None

        try:
            if VEDASTRO_AVAILABLE:
                match_report = Calculate.MatchReport(
                    vedastro_time_a, vedastro_time_b
                )
                if match_report and isinstance(match_report, dict):
                    kuta_score = match_report.get("KutaScore")
                    summary_data = match_report.get("Summary", {})
                    if isinstance(summary_data, dict):
                        summary = summary_data.get("ScoreSummary", "")

                    predictions = match_report.get("PredictionList", [])
                    if isinstance(predictions, list):
                        for pred in predictions:
                            if isinstance(pred, dict):
                                name = pred.get("Name", "")
                                nature = pred.get("Nature", "")
                                info = pred.get("Info", "")
                                kuta_details[name] = {
                                    "nature": nature,
                                    "info": info,
                                }
        except Exception as e:
            logger.warning(f"Failed to calculate Vedic compatibility: {e}")

        return VedicCompatibilityResult(
            person_a_chart=chart_a,
            person_b_chart=chart_b,
            kuta_score=kuta_score,
            kuta_details=kuta_details,
            summary=summary,
        )
