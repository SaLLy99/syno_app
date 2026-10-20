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
    SynastryResponse,
    CompatibilityResponse,
    InterpretationResponse,
    CompatibilityDimensionsResponse,
    PlanetPositionResponse,
    AspectResponse,
    HouseCuspResponse,
    PlanetToPlanetAspectResponse,
    HouseOverlayResponse,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/astrology", tags=["astrology"])

_ai_service: Optional[AIInterpretationService] = None


def _fallback_models() -> list[str]:
    raw = settings.gemini_fallback_models or ""
    return [m.strip() for m in raw.split(",") if m.strip()]


def _get_ai_interpreter() -> ChartInterpreter:
    """Create a ChartInterpreter with optional Gemini AI backend."""
    global _ai_service
    if settings.ai_interpretation_enabled and settings.gemini_api_key and settings.gemini_api_key != "your_gemini_api_key_here":
        if _ai_service is None:
            _ai_service = AIInterpretationService(
                api_key=settings.gemini_api_key,
                model=settings.gemini_model,
                fallback_models=_fallback_models(),
            )
        return ChartInterpreter(ai_service=_ai_service)
    return ChartInterpreter()


def _get_ai_service() -> Optional[AIInterpretationService]:
    """Get the AI interpretation service instance if configured."""
    global _ai_service
    if settings.ai_interpretation_enabled and settings.gemini_api_key and settings.gemini_api_key != "your_gemini_api_key_here":
        if _ai_service is None:
            _ai_service = AIInterpretationService(
                api_key=settings.gemini_api_key,
                model=settings.gemini_model,
                fallback_models=_fallback_models(),
            )
        return _ai_service
    return None


def _birth_data_request_to_domain(req: BirthDataRequest) -> BirthData:
    return BirthData(
        birth_date=req.birth_date,
        birth_time=req.birth_time,
        timezone=req.timezone,
        latitude=req.latitude,
        longitude=req.longitude,
        location_name=req.location_name,
    )


def _resolve_names(request) -> tuple[str, str]:
    """Resolve person display names from request, falling back to location names."""
    name_a = (getattr(request, "person_a_name", None) or "").strip()
    name_b = (getattr(request, "person_b_name", None) or "").strip()
    if not name_a:
        name_a = (request.person_a.location_name or "").strip()
    if not name_b:
        name_b = (request.person_b.location_name or "").strip()
    return name_a, name_b


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

    if birth_data.latitude is None or birth_data.longitude is None:
        raise HTTPException(
            status_code=400,
            detail="Birth location coordinates (latitude/longitude) are required for chart calculation"
        )

    try:
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
    name_a, name_b = _resolve_names(request)

    if person_a.latitude is None or person_a.longitude is None:
        raise HTTPException(status_code=400, detail=f"{name_a or 'First person'} birth location coordinates are required")
    if person_b.latitude is None or person_b.longitude is None:
        raise HTTPException(status_code=400, detail=f"{name_b or 'Second person'} birth location coordinates are required")

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
    name_a, name_b = _resolve_names(request)

    if person_a.latitude is None or person_a.longitude is None:
        raise HTTPException(status_code=400, detail=f"{name_a or 'First person'} birth location coordinates are required")
    if person_b.latitude is None or person_b.longitude is None:
        raise HTTPException(status_code=400, detail=f"{name_b or 'Second person'} birth location coordinates are required")

    try:
        western_provider = SwissEphProvider()

        synastry_service = SynastryService(western_provider)
        compatibility_service = CompatibilityService(western_provider)
        ai_svc = _get_ai_service()
        interpreter = _get_ai_interpreter()

        logger.info("Step 1: Calculating raw synastry data via Swiss Ephemeris...")
        synastry = synastry_service.calculate_synastry(person_a, person_b)
        dimensions = compatibility_service.calculate_compatibility(person_a, person_b)
        logger.info(f"Step 1 DONE: {len(synastry.planet_aspects)} aspects, overall={dimensions.overall}")
        logger.info(f"Step 1 DIMENSIONS: emotional={dimensions.emotional}, communication={dimensions.communication}, values={dimensions.values}, attraction={dimensions.attraction}, conflict={dimensions.conflict}, stability={dimensions.stability}, growth={dimensions.growth}, overall={dimensions.overall}")

        logger.info("Step 2: Generating AI interpretations from raw data...")
        interpretation = interpreter.interpret_synastry(
            synastry,
            dimensions=dimensions,
            person_a_name=name_a,
            person_b_name=name_b,
        )
        ai_used = ai_svc is not None and getattr(interpreter, "last_used_ai", False)
        logger.info(f"Step 2 DONE: ai_used={ai_used} (ai_service_configured={ai_svc is not None})")
        logger.info(f"Step 2 INTERPRETATION: summary={len(interpretation.summary)}chars, strengths={len(interpretation.strengths)}, challenges={len(interpretation.challenges)}, comm={len(interpretation.communication)}chars, emotional={len(interpretation.emotional_dynamic)}chars")
        logger.info(f"Step 2 STRENGTHS: {interpretation.strengths}")
        logger.info(f"Step 2 CHALLENGES: {interpretation.challenges}")

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

        logger.info(f"RESPONSE: {len(synastry.planet_aspects)} planet aspects, {len(synastry.conjunctions)} conjunctions, {len(synastry.trines)} trines, {len(synastry.squares)} squares, {len(synastry.sextiles)} sextiles")
        logger.info(f"RESPONSE ASPECTS: {'; '.join([f'{a.planet_a.value}-{a.planet_b.value} {a.aspect.value} orb={a.orb:.1f}' for a in synastry.planet_aspects[:5]])}")

        return CompatibilityResponse(
            western_synastry=synastry_response,
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
                ai_used=ai_used,
                personality_a=interpretation.personality_a,
                personality_b=interpretation.personality_b,
                love_language=interpretation.love_language,
                trust_loyalty=interpretation.trust_loyalty,
                intimacy_text=interpretation.intimacy_text,
                conflict_style=interpretation.conflict_style,
                overall_verdict=interpretation.overall_verdict,
                coach_tips=interpretation.coach_tips or [],
            ),
            ai_used=ai_used,
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
    name_a, name_b = _resolve_names(request)

    if person_a.latitude is None or person_a.longitude is None:
        raise HTTPException(status_code=400, detail=f"{name_a or 'First person'} birth location coordinates are required")
    if person_b.latitude is None or person_b.longitude is None:
        raise HTTPException(status_code=400, detail=f"{name_b or 'Second person'} birth location coordinates are required")

    try:
        provider = SwissEphProvider()
        from .services.report_service import ReportService
        ai_interpreter = _get_ai_interpreter()
        ai_svc = _get_ai_service()
        report_service = ReportService(provider, interpreter=ai_interpreter, ai_service=ai_svc)

        logger.info("Report: Step 1 - Calculating raw astrology data...")
        shared_hobbies = []
        shared_values = []
        shared_intentions = []

        report = report_service.generate_report(
            person_a,
            person_b,
            shared_hobbies=shared_hobbies,
            shared_values=shared_values,
            shared_intentions=shared_intentions,
            user_a_name=name_a,
            user_b_name=name_b,
        )
        logger.info(f"Report: Step 2 - AI interpretations generated, ai_used={ai_svc is not None}")

        result = report_service.report_to_dict(report)
        result['ai_used'] = ai_svc is not None and getattr(ai_interpreter, "last_used_ai", False)
        return result

    except Exception as e:
        logger.error(f"Report generation failed: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Report generation failed: {str(e)}"
        )
