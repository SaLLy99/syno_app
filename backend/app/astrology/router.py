import logging
from typing import Optional

from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.auth import get_current_active_user
from app import models
from app.config import settings

from .domain.models import BirthData, AstrologySystem
from .providers.base import create_astrology_provider
from .providers.western import SwissEphProvider
from .providers.vedastro import VedAstroProvider
from .services.chart_service import ChartService
from .services.synastry_service import SynastryService
from .services.compatibility_service import CompatibilityService
from .services.interpretation_service import ChartInterpreter
from .services.ai_interpretation_service import AIInterpretationService
from .schemas.requests import (
    BirthDataRequest,
    ChartRequest,
    SynastryRequest,
    CompatibilityRequest,
    InterpretationRequest,
)
from .schemas.responses import (
    WesternChartResponse,
    VedicChartResponse,
    SynastryResponse,
    VedicCompatibilityResponse,
    CompatibilityResponse,
    InterpretationResponse,
    CompatibilityDimensionsResponse,
    PlanetPositionResponse,
    AspectResponse,
    HouseCuspResponse,
    VedicPlanetPositionResponse,
    PlanetToPlanetAspectResponse,
    HouseOverlayResponse,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/astrology", tags=["astrology"])

_ai_service: Optional[AIInterpretationService] = None


def _get_ai_interpreter() -> ChartInterpreter:
    """Create a ChartInterpreter with optional Gemini AI backend."""
    global _ai_service
    if settings.ai_interpretation_enabled and settings.gemini_api_key and settings.gemini_api_key != "your_gemini_api_key_here":
        if _ai_service is None:
            _ai_service = AIInterpretationService(
                api_key=settings.gemini_api_key,
                model=settings.gemini_model,
            )
        return ChartInterpreter(ai_service=_ai_service)
    return ChartInterpreter()


def _birth_data_request_to_domain(req: BirthDataRequest) -> BirthData:
    return BirthData(
        birth_date=req.birth_date,
        birth_time=req.birth_time,
        timezone=req.timezone,
        latitude=req.latitude,
        longitude=req.longitude,
        location_name=req.location_name,
    )


def _planet_to_response(p) -> PlanetPositionResponse:
    return PlanetPositionResponse(
        planet=p.planet.value,
        sign=p.sign.value,
        degree=p.degree,
        absolute_degree=p.absolute_degree,
        house=p.house,
        retrograde=p.retrograde,
        sign_degree=p.sign_degree,
    )


def _aspect_to_response(a) -> AspectResponse:
    return AspectResponse(
        planet_a=a.planet_a.value,
        planet_b=a.planet_b.value,
        aspect=a.aspect.value,
        orb=a.orb,
        applying=a.applying,
    )


def _house_cusp_to_response(h) -> HouseCuspResponse:
    return HouseCuspResponse(
        house_number=h.house_number,
        sign=h.sign.value,
        degree=h.degree,
        absolute_degree=h.absolute_degree,
    )


def _vedic_planet_to_response(p) -> VedicPlanetPositionResponse:
    return VedicPlanetPositionResponse(
        planet=p.planet.value,
        sign=p.sign.value,
        degree=p.degree,
        absolute_degree=p.absolute_degree,
        house=p.house,
        retrograde=p.retrograde,
        nakshatra=p.nakshatra.value if p.nakshatra else None,
        pada=p.pada,
        sign_degree=p.sign_degree,
    )


def _synastry_aspect_to_response(a) -> PlanetToPlanetAspectResponse:
    return PlanetToPlanetAspectResponse(
        planet_a=a.planet_a.value,
        planet_b=a.planet_b.value,
        aspect=a.aspect.value,
        orb=a.orb,
        sign_a=a.sign_a.value,
        sign_b=a.sign_b.value,
        house_a=a.house_a,
        house_b=a.house_b,
    )


def _house_overlay_to_response(o) -> HouseOverlayResponse:
    return HouseOverlayResponse(
        planet=o.planet.value,
        overlay_house=o.overlay_house,
        sign=o.sign.value,
        degree=o.degree,
    )


@router.post("/chart", summary="Calculate natal chart")
def calculate_chart(
    request: ChartRequest,
    current_user: models.SynoUser = Depends(get_current_active_user),
):
    birth_data = _birth_data_request_to_domain(request.birth_data)

    try:
        if request.system == "vedic_sidereal":
            provider = VedAstroProvider()
            chart_service = ChartService(provider)
            vedic_chart = chart_service.get_vedic_chart(
                birth_data, request.ayanamsa or "Lahiri"
            )

            planets = [_vedic_planet_to_response(p) for p in vedic_chart.planets]
            ascendant = _vedic_planet_to_response(vedic_chart.ascendant) if vedic_chart.ascendant else None

            return VedicChartResponse(
                system=vedic_chart.system.value,
                ayanamsa=vedic_chart.ayanamsa,
                planets=planets,
                ascendant=ascendant,
                moon_sign=vedic_chart.moon_sign.value if vedic_chart.moon_sign else None,
                sun_sign=vedic_chart.sun_sign.value if vedic_chart.sun_sign else None,
            )
        else:
            provider = SwissEphProvider()
            chart_service = ChartService(provider)
            western_chart = chart_service.get_western_chart(birth_data)

            planets = [_planet_to_response(p) for p in western_chart.planets]
            aspects = [_aspect_to_response(a) for a in western_chart.aspects]
            house_cusps = [_house_cusp_to_response(h) for h in western_chart.house_cusps]
            ascendant = _planet_to_response(western_chart.ascendant) if western_chart.ascendant else None
            mc = _planet_to_response(western_chart.mc) if western_chart.mc else None

            return WesternChartResponse(
                system=western_chart.system.value,
                planets=planets,
                aspects=aspects,
                house_cusps=house_cusps,
                ascendant=ascendant,
                mc=mc,
            )

    except Exception as e:
        logger.error(f"Chart calculation failed: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Chart calculation failed: {str(e)}"
        )


@router.post("/synastry", summary="Calculate synastry between two people")
def calculate_synastry(
    request: SynastryRequest,
    current_user: models.SynoUser = Depends(get_current_active_user),
):
    person_a = _birth_data_request_to_domain(request.person_a)
    person_b = _birth_data_request_to_domain(request.person_b)

    try:
        provider = SwissEphProvider()
        synastry_service = SynastryService(provider)
        result = synastry_service.calculate_synastry(person_a, person_b)

        person_a_chart = None
        if result.person_a_chart:
            person_a_chart = WesternChartResponse(
                system=result.person_a_chart.system.value,
                planets=[_planet_to_response(p) for p in result.person_a_chart.planets],
                aspects=[_aspect_to_response(a) for a in result.person_a_chart.aspects],
                house_cusps=[_house_cusp_to_response(h) for h in result.person_a_chart.house_cusps],
                ascendant=_planet_to_response(result.person_a_chart.ascendant) if result.person_a_chart.ascendant else None,
                mc=_planet_to_response(result.person_a_chart.mc) if result.person_a_chart.mc else None,
            )

        person_b_chart = None
        if result.person_b_chart:
            person_b_chart = WesternChartResponse(
                system=result.person_b_chart.system.value,
                planets=[_planet_to_response(p) for p in result.person_b_chart.planets],
                aspects=[_aspect_to_response(a) for a in result.person_b_chart.aspects],
                house_cusps=[_house_cusp_to_response(h) for h in result.person_b_chart.house_cusps],
                ascendant=_planet_to_response(result.person_b_chart.ascendant) if result.person_b_chart.ascendant else None,
                mc=_planet_to_response(result.person_b_chart.mc) if result.person_b_chart.mc else None,
            )

        return SynastryResponse(
            person_a_chart=person_a_chart,
            person_b_chart=person_b_chart,
            planet_aspects=[_synastry_aspect_to_response(a) for a in result.planet_aspects],
            house_overlays_a_to_b=[_house_overlay_to_response(o) for o in result.house_overlays_a_to_b],
            house_overlays_b_to_a=[_house_overlay_to_response(o) for o in result.house_overlays_b_to_a],
            conjunctions=[_synastry_aspect_to_response(a) for a in result.conjunctions],
            oppositions=[_synastry_aspect_to_response(a) for a in result.oppositions],
            trines=[_synastry_aspect_to_response(a) for a in result.trines],
            squares=[_synastry_aspect_to_response(a) for a in result.squares],
            sextiles=[_synastry_aspect_to_response(a) for a in result.sextiles],
        )

    except Exception as e:
        logger.error(f"Synastry calculation failed: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Synastry calculation failed: {str(e)}"
        )


@router.post("/interpretation", summary="Get full interpretation with compatibility dimensions")
def calculate_interpretation(
    request: InterpretationRequest,
    current_user: models.SynoUser = Depends(get_current_active_user),
):
    person_a = _birth_data_request_to_domain(request.person_a)
    person_b = _birth_data_request_to_domain(request.person_b)

    try:
        western_provider = SwissEphProvider()
        vedic_provider = VedAstroProvider()

        synastry_service = SynastryService(western_provider)
        compatibility_service = CompatibilityService(western_provider)
        interpreter = _get_ai_interpreter()

        synastry = synastry_service.calculate_synastry(person_a, person_b)
        dimensions = compatibility_service.calculate_compatibility(
            person_a, person_b, request.ayanamsa or "Lahiri"
        )

        vedic_compatibility = None
        if request.include_vedic:
            try:
                vedic_compatibility = vedic_provider.get_vedic_compatibility(
                    person_a, person_b, request.ayanamsa or "Lahiri"
                )
            except Exception as e:
                logger.warning(f"Vedic compatibility failed: {e}")

        interpretation = interpreter.interpret_synastry(
            synastry, vedic_compatibility, dimensions
        )

        vedic_response = None
        if vedic_compatibility:
            vedic_response = VedicCompatibilityResponse(
                system="vedic_sidereal",
                ayanamsa=request.ayanamsa or "Lahiri",
                kuta_score=vedic_compatibility.kuta_score,
                kuta_details=vedic_compatibility.kuta_details,
                summary=vedic_compatibility.summary,
            )

        person_a_chart = None
        if synastry.person_a_chart:
            person_a_chart = WesternChartResponse(
                system=synastry.person_a_chart.system.value,
                planets=[_planet_to_response(p) for p in synastry.person_a_chart.planets],
                aspects=[_aspect_to_response(a) for a in synastry.person_a_chart.aspects],
                house_cusps=[_house_cusp_to_response(h) for h in synastry.person_a_chart.house_cusps],
                ascendant=_planet_to_response(synastry.person_a_chart.ascendant) if synastry.person_a_chart.ascendant else None,
            )

        person_b_chart = None
        if synastry.person_b_chart:
            person_b_chart = WesternChartResponse(
                system=synastry.person_b_chart.system.value,
                planets=[_planet_to_response(p) for p in synastry.person_b_chart.planets],
                aspects=[_aspect_to_response(a) for a in synastry.person_b_chart.aspects],
                house_cusps=[_house_cusp_to_response(h) for h in synastry.person_b_chart.house_cusps],
                ascendant=_planet_to_response(synastry.person_b_chart.ascendant) if synastry.person_b_chart.ascendant else None,
            )

        synastry_response = SynastryResponse(
            person_a_chart=person_a_chart,
            person_b_chart=person_b_chart,
            planet_aspects=[_synastry_aspect_to_response(a) for a in synastry.planet_aspects],
            conjunctions=[_synastry_aspect_to_response(a) for a in synastry.conjunctions],
            oppositions=[_synastry_aspect_to_response(a) for a in synastry.oppositions],
            trines=[_synastry_aspect_to_response(a) for a in synastry.trines],
            squares=[_synastry_aspect_to_response(a) for a in synastry.squares],
            sextiles=[_synastry_aspect_to_response(a) for a in synastry.sextiles],
        )

        return CompatibilityResponse(
            western_synastry=synastry_response,
            vedic_compatibility=vedic_response,
            dimensions=CompatibilityDimensionsResponse(
                emotional=dimensions.emotional,
                communication=dimensions.communication,
                values=dimensions.values,
                attraction=dimensions.attraction,
                conflict=dimensions.conflict,
                stability=dimensions.stability,
                growth=dimensions.growth,
                overall=dimensions.overall,
            ),
            interpretation=InterpretationResponse(
                summary=interpretation.summary,
                strengths=interpretation.strengths,
                challenges=interpretation.challenges,
                communication=interpretation.communication,
                emotional_dynamic=interpretation.emotional_dynamic,
                values=interpretation.values,
                growth_dynamic=interpretation.growth_dynamic,
                important_aspects=interpretation.important_aspects,
            ),
        )

    except Exception as e:
        logger.error(f"Interpretation calculation failed: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Interpretation calculation failed: {str(e)}"
        )


@router.post("/report", summary="Generate detailed compatibility report")
def generate_report(
    request: InterpretationRequest,
    current_user: models.SynoUser = Depends(get_current_active_user),
):
    person_a = _birth_data_request_to_domain(request.person_a)
    person_b = _birth_data_request_to_domain(request.person_b)

    try:
        provider = SwissEphProvider()
        from .services.report_service import ReportService
        ai_interpreter = _get_ai_interpreter()
        report_service = ReportService(provider, interpreter=ai_interpreter)

        shared_hobbies = []
        shared_values = []
        shared_intentions = []

        report = report_service.generate_report(
            person_a,
            person_b,
            shared_hobbies=shared_hobbies,
            shared_values=shared_values,
            shared_intentions=shared_intentions,
            user_a_name=request.person_a.location_name or "",
            user_b_name=request.person_b.location_name or "",
        )

        return report_service.report_to_dict(report)

    except Exception as e:
        logger.error(f"Report generation failed: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Report generation failed: {str(e)}"
        )
