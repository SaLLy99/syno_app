import sys
import os
import pytest
from datetime import date, time
from pydantic import ValidationError

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from app.astrology.domain.models import (
    BirthData,
    PlanetPosition,
    AspectData,
    HouseCusp,
    WesternChart,
    SynastryResult,
    CompatibilityDimensions,
    InterpretationResult,
    AstrologySystem,
    ZodiacSign,
    PlanetName,
    AspectType,
)


class TestBirthData:
    def test_valid_birth_data(self):
        bd = BirthData(
            birth_date=date(1996, 6, 26),
            birth_time=time(22, 44),
            timezone="+04:00",
            latitude=41.7151,
            longitude=44.8271,
            location_name="Tbilisi",
        )
        assert bd.birth_date == date(1996, 6, 26)
        assert bd.birth_time == time(22, 44)
        assert bd.timezone == "+04:00"
        assert bd.latitude == 41.7151
        assert bd.longitude == 44.8271
        assert bd.location_name == "Tbilisi"

    def test_birth_data_without_location_name(self):
        bd = BirthData(
            birth_date=date(2000, 1, 1),
            birth_time=time(12, 0),
            timezone="+00:00",
            latitude=0.0,
            longitude=0.0,
        )
        assert bd.location_name is None

    def test_invalid_latitude(self):
        with pytest.raises(ValidationError):
            BirthData(
                birth_date=date(2000, 1, 1),
                birth_time=time(12, 0),
                timezone="+00:00",
                latitude=100.0,
                longitude=0.0,
            )

    def test_invalid_longitude(self):
        with pytest.raises(ValidationError):
            BirthData(
                birth_date=date(2000, 1, 1),
                birth_time=time(12, 0),
                timezone="+00:00",
                latitude=0.0,
                longitude=200.0,
            )


class TestPlanetPosition:
    def test_planet_position(self):
        pp = PlanetPosition(
            planet=PlanetName.SUN,
            sign= ZodiacSign.CANCER,
            degree=15.5,
            absolute_degree=105.5,
            house=4,
            retrograde=False,
            sign_degree="15°30'00\"",
        )
        assert pp.planet == PlanetName.SUN
        assert pp.sign == ZodiacSign.CANCER
        assert pp.degree == 15.5
        assert pp.house == 4
        assert pp.retrograde is False


class TestAspectData:
    def test_aspect_data(self):
        ad = AspectData(
            planet_a=PlanetName.SUN,
            planet_b=PlanetName.MOON,
            aspect=AspectType.CONJUNCTION,
            orb=2.5,
            applying=True,
        )
        assert ad.planet_a == PlanetName.SUN
        assert ad.planet_b == PlanetName.MOON
        assert ad.aspect == AspectType.CONJUNCTION
        assert ad.orb == 2.5
        assert ad.applying is True


class TestWesternChart:
    def test_western_chart(self):
        chart = WesternChart(
            system=AstrologySystem.WESTERN_TROPICAL,
            planets=[
                PlanetPosition(
                    planet=PlanetName.SUN,
                    sign=ZodiacSign.LEO,
                    degree=10.0,
                    absolute_degree=130.0,
                    house=5,
                )
            ],
            aspects=[],
            house_cusps=[],
        )
        assert chart.system == AstrologySystem.WESTERN_TROPICAL
        assert len(chart.planets) == 1
        assert chart.planets[0].planet == PlanetName.SUN


class TestCacheKeys:
    def test_chart_cache_key_deterministic(self):
        from app.astrology.cache.keys import generate_chart_cache_key

        bd = BirthData(
            birth_date=date(1996, 6, 26),
            birth_time=time(22, 44),
            timezone="+04:00",
            latitude=41.7151,
            longitude=44.8271,
        )

        key1 = generate_chart_cache_key(bd, AstrologySystem.WESTERN_TROPICAL)
        key2 = generate_chart_cache_key(bd, AstrologySystem.WESTERN_TROPICAL)
        assert key1 == key2

    def test_synastry_cache_key_order_independent(self):
        from app.astrology.cache.keys import generate_synastry_cache_key

        bd_a = BirthData(
            birth_date=date(1996, 6, 26),
            birth_time=time(22, 44),
            timezone="+04:00",
            latitude=41.7151,
            longitude=44.8271,
        )
        bd_b = BirthData(
            birth_date=date(1997, 8, 15),
            birth_time=time(14, 30),
            timezone="-05:00",
            latitude=40.7128,
            longitude=-74.0060,
        )

        key_ab = generate_synastry_cache_key(bd_a, bd_b, AstrologySystem.WESTERN_TROPICAL)
        key_ba = generate_synastry_cache_key(bd_b, bd_a, AstrologySystem.WESTERN_TROPICAL)
        assert key_ab == key_ba


class TestCompatibilityDimensions:
    def test_default_dimensions(self):
        cd = CompatibilityDimensions()
        assert cd.emotional == 50.0
        assert cd.communication == 50.0
        assert cd.overall == 50.0

    def test_dimension_validation_rejects_out_of_bounds(self):
        with pytest.raises(ValidationError):
            CompatibilityDimensions(emotional=150.0)
        with pytest.raises(ValidationError):
            CompatibilityDimensions(communication=-10.0)


class TestInterpretationResult:
    def test_interpretation_result(self):
        ir = InterpretationResult(
            summary="Test summary",
            strengths=["Strength 1", "Strength 2"],
            challenges=["Challenge 1"],
            communication="Communication text",
            emotional_dynamic="Emotional text",
            values="Values text",
            growth_dynamic="Growth text",
            important_aspects=[{"planets": "Sun-Moon", "aspect": "conjunction"}],
        )
        assert ir.summary == "Test summary"
        assert len(ir.strengths) == 2
        assert len(ir.challenges) == 1
        assert len(ir.important_aspects) == 1


class TestWesternChartService:
    def test_western_chart_provider(self):
        from app.astrology.providers.western import SwissEphProvider, SWISSEPH_AVAILABLE
        from app.astrology.services.chart_service import ChartService

        provider = SwissEphProvider()
        chart_service = ChartService(provider)

        bd = BirthData(
            birth_date=date(1996, 6, 26),
            birth_time=time(22, 44),
            timezone="+04:00",
            latitude=41.7151,
            longitude=44.8271,
            location_name="Tbilisi",
        )

        chart = chart_service.get_western_chart(bd)
        assert chart.system == AstrologySystem.WESTERN_TROPICAL
        if SWISSEPH_AVAILABLE:
            assert len(chart.planets) > 0
            assert any(p.planet == PlanetName.SUN for p in chart.planets)
            assert any(p.planet == PlanetName.MOON for p in chart.planets)
        else:
            assert len(chart.planets) == 0

    def test_western_chart_caching(self):
        from app.astrology.providers.western import SwissEphProvider
        from app.astrology.services.chart_service import ChartService

        provider = SwissEphProvider()
        chart_service = ChartService(provider)

        bd = BirthData(
            birth_date=date(1996, 6, 26),
            birth_time=time(22, 44),
            timezone="+04:00",
            latitude=41.7151,
            longitude=44.8271,
        )

        chart1 = chart_service.get_western_chart(bd, use_cache=True)
        chart2 = chart_service.get_western_chart(bd, use_cache=True)
        assert chart1 is chart2


class TestSynastryCalculation:
    def test_synastry_result_structure(self):
        from app.astrology.providers.western import SwissEphProvider

        provider = SwissEphProvider()

        person_a = BirthData(
            birth_date=date(1996, 6, 26),
            birth_time=time(22, 44),
            timezone="+04:00",
            latitude=41.7151,
            longitude=44.8271,
        )
        person_b = BirthData(
            birth_date=date(1997, 8, 15),
            birth_time=time(14, 30),
            timezone="-05:00",
            latitude=40.7128,
            longitude=-74.0060,
        )

        result = provider.get_synastry(person_a, person_b)
        assert isinstance(result, SynastryResult)
        assert result.person_a_chart is not None
        assert result.person_b_chart is not None
        assert isinstance(result.planet_aspects, list)
        assert isinstance(result.conjunctions, list)
        assert isinstance(result.trines, list)
        assert isinstance(result.squares, list)
