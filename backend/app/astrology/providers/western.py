import math
from datetime import datetime, timezone, timedelta
from typing import List, Optional, Tuple

from ..domain.models import (
    BirthData,
    WesternChart,
    PlanetPosition,
    AspectData,
    HouseCusp,
    PlanetName,
    ZodiacSign,
    AspectType,
    AstrologySystem,
    SynastryResult,
    PlanetToPlanetAspect,
    HouseOverlay,
    VedicChart,
    VedicPlanetPosition,
    VedicCompatibilityResult,
)
from ..domain.provider import AstrologyProvider

try:
    import swisseph as swe
    SWISSEPH_AVAILABLE = True
except ImportError:
    try:
        import libephemeris as swe
        SWISSEPH_AVAILABLE = True
    except ImportError:
        SWISSEPH_AVAILABLE = False

ZODIAC_SIGNS = [
    ZodiacSign.ARIES, ZodiacSign.TAURUS, ZodiacSign.GEMINI,
    ZodiacSign.CANCER, ZodiacSign.LEO, ZodiacSign.VIRGO,
    ZodiacSign.LIBRA, ZodiacSign.SCORPIO, ZodiacSign.SAGITTARIUS,
    ZodiacSign.CAPRICORN, ZodiacSign.AQUARIUS, ZodiacSign.PISCES,
]

ASPECT_ANGLES = {
    AspectType.CONJUNCTION: (0, 10),
    AspectType.OPPOSITION: (180, 10),
    AspectType.TRINE: (120, 10),
    AspectType.SQUARE: (90, 10),
    AspectType.SEXTILE: (60, 6),
    AspectType.QUINCUNX: (150, 3),
    AspectType.SEMI_SEXTILE: (30, 3),
    AspectType.SEMI_SQUARE: (45, 3),
}

PLANET_MAP = {
    PlanetName.SUN: swe.SUN if SWISSEPH_AVAILABLE else None,
    PlanetName.MOON: swe.MOON if SWISSEPH_AVAILABLE else None,
    PlanetName.MERCURY: swe.MERCURY if SWISSEPH_AVAILABLE else None,
    PlanetName.VENUS: swe.VENUS if SWISSEPH_AVAILABLE else None,
    PlanetName.MARS: swe.MARS if SWISSEPH_AVAILABLE else None,
    PlanetName.JUPITER: swe.JUPITER if SWISSEPH_AVAILABLE else None,
    PlanetName.SATURN: swe.SATURN if SWISSEPH_AVAILABLE else None,
    PlanetName.URANUS: swe.URANUS if SWISSEPH_AVAILABLE else None,
    PlanetName.NEPTUNE: swe.NEPTUNE if SWISSEPH_AVAILABLE else None,
    PlanetName.PLUTO: swe.PLUTO if SWISSEPH_AVAILABLE else None,
}


def _format_degree(deg: float) -> str:
    d = int(deg)
    m = int((deg - d) * 60)
    s = int(((deg - d) * 60 - m) * 60)
    return f"{d}°{m:02d}'{s:02d}\""


def _get_sign_and_degree(absolute_deg: float) -> Tuple[ZodiacSign, float]:
    sign_idx = int(absolute_deg / 30) % 12
    degree_in_sign = absolute_deg % 30
    return ZODIAC_SIGNS[sign_idx], degree_in_sign


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


class SwissEphProvider(AstrologyProvider):
    """Western astrology provider using Swiss Ephemeris."""

    def __init__(self):
        if SWISSEPH_AVAILABLE:
            swe.set_ephe_path(None)

    def _birth_data_to_jd(self, birth_data: BirthData) -> float:
        offset_hours = _offset_to_hours(birth_data.timezone)
        local_dt = datetime(
            birth_data.birth_date.year,
            birth_data.birth_date.month,
            birth_data.birth_date.day,
            birth_data.birth_time.hour,
            birth_data.birth_time.minute,
            birth_data.birth_time.second,
        )
        utc_dt = local_dt - timedelta(hours=offset_hours)

        if SWISSEPH_AVAILABLE:
            jd = swe.julday(
                utc_dt.year, utc_dt.month, utc_dt.day,
                utc_dt.hour + utc_dt.minute / 60.0 + utc_dt.second / 3600.0,
            )
        else:
            jd = self._julian_day_manual(
                utc_dt.year, utc_dt.month, utc_dt.day,
                utc_dt.hour + utc_dt.minute / 60.0 + utc_dt.second / 3600.0,
            )
        return jd

    @staticmethod
    def _julian_day_manual(year: int, month: int, day: int, hour: float) -> float:
        if month <= 2:
            year -= 1
            month += 12
        A = int(year / 100)
        B = 2 - A + int(A / 4)
        jd = int(365.25 * (year + 4716)) + int(30.6001 * (month + 1)) + day + hour / 24.0 + B - 1524.5
        return jd

    def _calculate_planet(self, planet_name: PlanetName, jd: float) -> Optional[PlanetPosition]:
        if not SWISSEPH_AVAILABLE:
            return None

        swe_planet = PLANET_MAP.get(planet_name)
        if swe_planet is None:
            return None

        try:
            result = swe.calc_ut(jd, swe_planet)
            if result and len(result) > 0:
                lon = result[0][0]
                flag = result[0][1] if len(result[0]) > 1 else 0
                retrograde = flag < 0

                sign, degree = _get_sign_and_degree(lon)
                house = None

                return PlanetPosition(
                    planet=planet_name,
                    sign=sign,
                    degree=round(degree, 4),
                    absolute_degree=round(lon, 4),
                    house=house,
                    retrograde=retrograde,
                    sign_degree=_format_degree(degree),
                )
        except Exception:
            pass
        return None

    def _calculate_ascendant(self, jd: float, latitude: float, longitude: float) -> Optional[PlanetPosition]:
        if not SWISSEPH_AVAILABLE:
            return None

        try:
            house_cusps, ascmc = swe.houses(jd, latitude, longitude, b'P')
            asc_lon = ascmc[0]
            sign, degree = _get_sign_and_degree(asc_lon)

            return PlanetPosition(
                planet=PlanetName.ASCENDANT,
                sign=sign,
                degree=round(degree, 4),
                absolute_degree=round(asc_lon, 4),
                house=1,
                retrograde=False,
                sign_degree=_format_degree(degree),
            )
        except Exception:
            pass
        return None

    def _calculate_houses(self, jd: float, latitude: float, longitude: float) -> List[HouseCusp]:
        if not SWISSEPH_AVAILABLE:
            return []

        try:
            house_cusps, ascmc = swe.houses(jd, latitude, longitude, b'P')
            cusps = []
            for i, cusp_lon in enumerate(house_cusps[:12]):
                sign, degree = _get_sign_and_degree(cusp_lon)
                cusps.append(HouseCusp(
                    house_number=i + 1,
                    sign=sign,
                    degree=round(degree, 4),
                    absolute_degree=round(cusp_lon, 4),
                ))
            return cusps
        except Exception:
            return []

    def _calculate_aspects(self, planets: List[PlanetPosition]) -> List[AspectData]:
        aspects = []
        for i, p1 in enumerate(planets):
            for p2 in planets[i + 1:]:
                for aspect_type, (exact_angle, orb_limit) in ASPECT_ANGLES.items():
                    diff = abs(p1.absolute_degree - p2.absolute_degree)
                    if diff > 180:
                        diff = 360 - diff
                    orb = abs(diff - exact_angle)
                    if orb <= orb_limit:
                        aspects.append(AspectData(
                            planet_a=p1.planet,
                            planet_b=p2.planet,
                            aspect=aspect_type,
                            orb=round(orb, 2),
                            applying=None,
                        ))
        return aspects

    def _assign_houses_to_planets(
        self, planets: List[PlanetPosition], house_cusps: List[HouseCusp]
    ) -> List[PlanetPosition]:
        if not house_cusps:
            return planets

        for planet in planets:
            for i, cusp in enumerate(house_cusps):
                next_cusp = house_cusps[(i + 1) % 12]
                cusp_start = cusp.absolute_degree
                cusp_end = next_cusp.absolute_degree

                if cusp_start < cusp_end:
                    if cusp_start <= planet.absolute_degree < cusp_end:
                        planet.house = cusp.house_number
                        break
                else:
                    if planet.absolute_degree >= cusp_start or planet.absolute_degree < cusp_end:
                        planet.house = cusp.house_number
                        break
        return planets

    def get_western_chart(self, birth_data: BirthData) -> WesternChart:
        jd = self._birth_data_to_jd(birth_data)

        planets = []
        for planet_name in [
            PlanetName.SUN, PlanetName.MOON, PlanetName.MERCURY,
            PlanetName.VENUS, PlanetName.MARS, PlanetName.JUPITER,
            PlanetName.SATURN, PlanetName.URANUS, PlanetName.NEPTUNE,
            PlanetName.PLUTO,
        ]:
            pos = self._calculate_planet(planet_name, jd)
            if pos:
                planets.append(pos)

        ascendant = self._calculate_ascendant(
            jd, birth_data.latitude, birth_data.longitude
        )
        if ascendant:
            planets.append(ascendant)

        house_cusps = self._calculate_houses(
            jd, birth_data.latitude, birth_data.longitude
        )

        planets = self._assign_houses_to_planets(planets, house_cusps)

        aspects = self._calculate_aspects(
            [p for p in planets if p.planet != PlanetName.ASCENDANT]
        )

        mc = None
        if SWISSEPH_AVAILABLE:
            try:
                _, ascmc = swe.houses(jd, birth_data.latitude, birth_data.longitude, b'P')
                mc_lon = ascmc[1]
                sign, degree = _get_sign_and_degree(mc_lon)
                mc = PlanetPosition(
                    planet=PlanetName.MC if hasattr(PlanetName, 'MC') else PlanetName.SUN,
                    sign=sign,
                    degree=round(degree, 4),
                    absolute_degree=round(mc_lon, 4),
                    house=10,
                    retrograde=False,
                    sign_degree=_format_degree(degree),
                )
            except Exception:
                pass

        return WesternChart(
            system=AstrologySystem.WESTERN_TROPICAL,
            planets=planets,
            aspects=aspects,
            house_cusps=house_cusps,
            ascendant=ascendant,
            mc=mc,
        )

    def get_vedic_chart(
        self,
        birth_data: BirthData,
        ayanamsa: str = "Lahiri",
    ) -> VedicChart:
        raise NotImplementedError(
            "Vedic calculations require the VedAstro provider. "
            "Use VedAstroProvider for Vedic charts."
        )

    def get_synastry(
        self,
        person_a: BirthData,
        person_b: BirthData,
    ) -> SynastryResult:
        chart_a = self.get_western_chart(person_a)
        chart_b = self.get_western_chart(person_b)

        planet_aspects = self._calculate_synastry_aspects(
            chart_a.planets, chart_b.planets
        )

        overlays_a_to_b = self._calculate_house_overlays(
            chart_a.planets, chart_b.house_cusps
        )
        overlays_b_to_a = self._calculate_house_overlays(
            chart_b.planets, chart_a.house_cusps
        )

        conjunctions = [a for a in planet_aspects if a.aspect == AspectType.CONJUNCTION]
        oppositions = [a for a in planet_aspects if a.aspect == AspectType.OPPOSITION]
        trines = [a for a in planet_aspects if a.aspect == AspectType.TRINE]
        squares = [a for a in planet_aspects if a.aspect == AspectType.SQUARE]
        sextiles = [a for a in planet_aspects if a.aspect == AspectType.SEXTILE]

        return SynastryResult(
            person_a_chart=chart_a,
            person_b_chart=chart_b,
            planet_aspects=planet_aspects,
            house_overlays_a_to_b=overlays_a_to_b,
            house_overlays_b_to_a=overlays_b_to_a,
            conjunctions=conjunctions,
            oppositions=oppositions,
            trines=trines,
            squares=squares,
            sextiles=sextiles,
        )

    def _calculate_synastry_aspects(
        self,
        planets_a: List[PlanetPosition],
        planets_b: List[PlanetPosition],
    ) -> List[PlanetToPlanetAspect]:
        aspects = []
        for pa in planets_a:
            for pb in planets_b:
                if pa.planet == PlanetName.ASCENDANT and pb.planet == PlanetName.ASCENDANT:
                    continue

                for aspect_type, (exact_angle, orb_limit) in ASPECT_ANGLES.items():
                    diff = abs(pa.absolute_degree - pb.absolute_degree)
                    if diff > 180:
                        diff = 360 - diff
                    orb = abs(diff - exact_angle)
                    if orb <= orb_limit:
                        aspects.append(PlanetToPlanetAspect(
                            planet_a=pa.planet,
                            planet_b=pb.planet,
                            aspect=aspect_type,
                            orb=round(orb, 2),
                            sign_a=pa.sign,
                            sign_b=pb.sign,
                            house_a=pa.house,
                            house_b=pb.house,
                        ))
        return aspects

    def _calculate_house_overlays(
        self,
        planets: List[PlanetPosition],
        house_cusps: List[HouseCusp],
    ) -> List[HouseOverlay]:
        overlays = []
        if not house_cusps:
            return overlays

        for planet in planets:
            if planet.planet == PlanetName.ASCENDANT:
                continue

            for i, cusp in enumerate(house_cusps):
                next_cusp = house_cusps[(i + 1) % 12]
                cusp_start = cusp.absolute_degree
                cusp_end = next_cusp.absolute_degree

                in_house = False
                if cusp_start < cusp_end:
                    in_house = cusp_start <= planet.absolute_degree < cusp_end
                else:
                    in_house = planet.absolute_degree >= cusp_start or planet.absolute_degree < cusp_end

                if in_house:
                    overlays.append(HouseOverlay(
                        planet=planet.planet,
                        overlay_house=cusp.house_number,
                        sign=planet.sign,
                        degree=planet.degree,
                    ))
                    break

        return overlays

    def get_vedic_compatibility(
        self,
        person_a: BirthData,
        person_b: BirthData,
        ayanamsa: str = "Lahiri",
    ) -> VedicCompatibilityResult:
        raise NotImplementedError(
            "Vedic compatibility requires the VedAstro provider. "
            "Use VedAstroProvider for Vedic compatibility."
        )
