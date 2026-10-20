"""
Server-side matching engine for SYNO.
Applies preference filters and computes compatibility scores.

Score composition combines:
- Synastry (astrology chart compatibility)
- Profile similarity (hobbies, values, intentions)
- Behavioral compatibility (observed user behavior patterns)
- Activity score (recency of engagement)
- Mutual interest (has the other user liked you)

When full birth data is available (date, time, timezone, coordinates),
the astrology module can provide real chart-based compatibility scores.
The hash-based fallback is used for quick scoring during discovery.
"""
import logging
import math
from datetime import date, datetime, time as dtime
from typing import List, Optional, Tuple
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import func as sql_func

from . import models

logger = logging.getLogger(__name__)

# Mode-specific scoring weights
# Dating: natal chart is primary (60%), behavior adds learning signal
# BFF: natal chart still leads (60%), interests matter more for friendships
MODE_WEIGHTS = {
    "dating": {
        "synastry": 0.60,
        "profile_similarity": 0.10,
        "behavioral": 0.30,
        "activity": 0.0,
        "mutual_interest": 0.0,
        "hobbies_weight": 0.15,
        "values_weight": 0.20,
        "intentions_weight": 0.15,
    },
    "bff": {
        "synastry": 0.60,
        "profile_similarity": 0.30,
        "behavioral": 0.10,
        "activity": 0.0,
        "mutual_interest": 0.0,
        "hobbies_weight": 0.35,
        "values_weight": 0.25,
        "intentions_weight": 0.10,
    },
}


def calculate_age(birth_date: date) -> int:
    today = date.today()
    return today.year - birth_date.year - ((today.month, today.day) < (birth_date.month, birth_date.day))


def haversine_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculate distance in km between two lat/lon points."""
    R = 6371
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = (math.sin(dlat / 2) ** 2 +
         math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) *
         math.sin(dlon / 2) ** 2)
    return R * 2 * math.asin(math.sqrt(a))


def calculate_synastry_score(profile_a: models.Profile, profile_b: models.Profile) -> float:
    """
    Chart compatibility score (0-100) used for ranking.

    Delegates to compute_chart_score(): real astrology whenever both profiles
    have a birth date + place. Returns 50.0 (neutral) only when there is not
    enough birth data to say anything - never a made-up number.
    """
    score, _partial = compute_chart_score(profile_a, profile_b)
    if score is None:
        logger.info("[SynastryCalc] Not enough birth data -> neutral 50 (not displayed)")
        return 50.0
    return score


def compute_chart_score(
    profile_a: models.Profile,
    profile_b: models.Profile,
) -> Tuple[Optional[float], bool]:
    """
    Real natal-chart compatibility between two profiles.

    Returns (score, partial):
      - score: 0-100, or None when a birth date/place is missing (no fake value).
      - partial: True when a birth time was missing and we used 12:00 local,
        so houses and the Ascendant are approximate.
    """
    if not profile_a.birth_date or not profile_b.birth_date:
        return None, False
    return _try_astrology_synastry(profile_a, profile_b)


def _build_birth_data(profile: models.Profile, allow_missing_time: bool = False):
    """
    Build BirthData from a profile.

    Returns (birth_data, partial):
      - birth_data is None when the profile has no usable birth date/place.
      - partial is True when the birth time was missing and 12:00 local was
        assumed (planet signs stay correct, houses/Ascendant become approximate).
    """
    from .astrology.domain.models import BirthData

    if not profile.birth_date or not profile.location:
        return None, False

    location = profile.location
    lat = getattr(location, 'latitude', None)
    lon = getattr(location, 'longitude', None)
    if lat is None or lon is None:
        return None, False

    partial = False
    if profile.birth_time:
        parts = profile.birth_time.split(":")
        birth_time = dtime(int(parts[0]), int(parts[1]))
    elif allow_missing_time:
        birth_time = dtime(12, 0)
        partial = True
    else:
        return None, False

    tz = getattr(location, 'timezone', None) or "+00:00"

    return BirthData(
        birth_date=profile.birth_date,
        birth_time=birth_time,
        timezone=tz,
        latitude=lat,
        longitude=lon,
        location_name=location.name,
    ), partial


def _try_astrology_synastry(
    profile_a: models.Profile,
    profile_b: models.Profile,
) -> Tuple[Optional[float], bool]:
    """
    Attempt real astrology synastry calculation.

    Returns (score, partial). (None, False) when birth data is unusable or the
    astrology engine is unavailable.
    """
    try:
        birth_a, partial_a = _build_birth_data(profile_a, allow_missing_time=True)
        birth_b, partial_b = _build_birth_data(profile_b, allow_missing_time=True)
        if birth_a is None or birth_b is None:
            return None, False

        from .astrology.providers.western import SwissEphProvider
        from .astrology.services.compatibility_service import CompatibilityService

        logger.info("[SynastryCalc] Computing astrology compatibility")
        provider = SwissEphProvider()
        compat_service = CompatibilityService(provider)
        dimensions = compat_service.calculate_compatibility(birth_a, birth_b)

        return dimensions.overall, (partial_a or partial_b)

    except Exception as e:
        logger.debug(f"Astrology synastry unavailable: {e}")
        return None, False


def _try_astrology_synastry_full(
    profile_a: models.Profile,
    profile_b: models.Profile,
    person_a_name: str = "",
    person_b_name: str = "",
) -> Optional[dict]:
    """
    Attempt real astrology synastry calculation with full data.
    Returns dict with score, dimensions, synastry aspects, and interpretation.
    Returns None if full birth data is not available.
    """
    try:
        birth_a, partial_a = _build_birth_data(profile_a, allow_missing_time=True)
        birth_b, partial_b = _build_birth_data(profile_b, allow_missing_time=True)
        if birth_a is None or birth_b is None:
            return None

        name_a = (person_a_name or "").strip() or (getattr(profile_a, "name", "") or "")
        name_b = (person_b_name or "").strip() or (getattr(profile_b, "name", "") or "")

        from .astrology.providers.western import SwissEphProvider
        from .astrology.services.compatibility_service import CompatibilityService
        from .astrology.services.synastry_service import SynastryService
        from .astrology.services.interpretation_service import ChartInterpreter

        provider = SwissEphProvider()
        synastry_service = SynastryService(provider)
        compat_service = CompatibilityService(provider)
        interpreter = ChartInterpreter()

        synastry = synastry_service.calculate_synastry(birth_a, birth_b)
        dimensions = compat_service.calculate_compatibility(birth_a, birth_b)
        interpretation = interpreter.interpret_synastry(
            synastry,
            dimensions=dimensions,
            person_a_name=name_a,
            person_b_name=name_b,
        )

        synastry_aspects = []
        for a in synastry.planet_aspects:
            synastry_aspects.append({
                "planet_a": a.planet_a.value,
                "planet_b": a.planet_b.value,
                "aspect": a.aspect.value,
                "orb": round(a.orb, 1),
                "sign_a": a.sign_a.value,
                "sign_b": a.sign_b.value,
                "house_a": a.house_a,
                "house_b": a.house_b,
            })

        interpretation_dict = {
            "summary": interpretation.summary,
            "communication": interpretation.communication,
            "emotional_dynamic": interpretation.emotional_dynamic,
            "values": interpretation.values,
            "growth_dynamic": interpretation.growth_dynamic,
            "strengths": interpretation.strengths,
            "challenges": interpretation.challenges,
            "important_aspects": interpretation.important_aspects,
            "personality_a": interpretation.personality_a,
            "personality_b": interpretation.personality_b,
            "love_language": interpretation.love_language,
            "trust_loyalty": interpretation.trust_loyalty,
            "intimacy_text": interpretation.intimacy_text,
            "conflict_style": interpretation.conflict_style,
            "overall_verdict": interpretation.overall_verdict,
            "coach_tips": list(interpretation.coach_tips or []),
            "ai_used": False,
        }

        return {
            "score": dimensions.overall,
            "ai_used": False,
            "partial": bool(partial_a or partial_b),
            "top_aspects": compute_top_aspects(synastry_aspects, limit=5),
            "dimensions": {
                "emotional": dimensions.emotional,
                "communication": dimensions.communication,
                "values": dimensions.values,
                "attraction": dimensions.attraction,
                "conflict": dimensions.conflict,
                "stability": dimensions.stability,
                "growth": dimensions.growth,
                "overall": dimensions.overall,
            },
            "synastry": {
                "planet_aspects": synastry_aspects,
            },
            "interpretation": interpretation_dict,
        }

    except Exception as e:
        logger.debug(f"Astrology synastry full unavailable: {e}")
        return None


def compute_top_aspects(aspects: List[dict], limit: int = 5) -> List[dict]:
    """Rank inter-chart aspects (see astrology.services.aspect_ranking)."""
    from .astrology.services.aspect_ranking import compute_top_aspects as _rank
    return _rank(aspects, limit=limit)


def calculate_profile_similarity(
    profile_a: models.Profile,
    profile_b: models.Profile,
    hobbies_weight: float = 0.20,
    values_weight: float = 0.20,
    intentions_weight: float = 0.10,
) -> float:
    """Calculate similarity based on profile attributes with configurable weights."""
    score = 50.0

    hobbies_a = {h.id for h in profile_a.hobbies} if profile_a.hobbies else set()
    hobbies_b = {h.id for h in profile_b.hobbies} if profile_b.hobbies else set()
    if hobbies_a and hobbies_b:
        overlap = len(hobbies_a & hobbies_b)
        total = len(hobbies_a | hobbies_b)
        score += (overlap / total) * (hobbies_weight * 100) if total > 0 else 0

    values_a = {cv.id for cv in profile_a.core_values} if profile_a.core_values else set()
    values_b = {cv.id for cv in profile_b.core_values} if profile_b.core_values else set()
    if values_a and values_b:
        overlap = len(values_a & values_b)
        total = len(values_a | values_b)
        score += (overlap / total) * (values_weight * 100) if total > 0 else 0

    intentions_a = {i.id for i in profile_a.intentions} if profile_a.intentions else set()
    intentions_b = {i.id for i in profile_b.intentions} if profile_b.intentions else set()
    if intentions_a and intentions_b:
        overlap = len(intentions_a & intentions_b)
        total = len(intentions_a | intentions_b)
        score += (overlap / total) * (intentions_weight * 100) if total > 0 else 0

    return min(score, 100.0)


def profile_similarity_has_data(
    profile_a: models.Profile,
    profile_b: models.Profile,
) -> bool:
    """
    True when at least one comparable dimension (hobbies, core values,
    intentions) exists on BOTH profiles. When nothing is comparable the
    profile part must be reported as "no data yet", never as a neutral 50.
    """
    for relation in ("hobbies", "core_values", "intentions"):
        try:
            ids_a = {item.id for item in (getattr(profile_a, relation) or [])}
            ids_b = {item.id for item in (getattr(profile_b, relation) or [])}
        except Exception:
            # Could not read the relationship - keep the number rather than
            # hiding real data behind an error.
            return True
        if ids_a and ids_b:
            return True
    return False


def compute_compatibility_score(
    profile_a: models.Profile,
    profile_b: models.Profile,
    mode: str = "dating",
) -> Tuple[float, float, str]:
    """
    Compute overall compatibility between two profiles.
    Returns (final_score, weighted_score, cosmic_insight).

    Uses synastry + profile similarity only (no behavioral data).
    For full scoring with behavior, use compute_full_compatibility_score().
    """
    weights = MODE_WEIGHTS.get(mode, MODE_WEIGHTS["dating"])
    synastry_score = calculate_synastry_score(profile_a, profile_b)
    profile_similarity = calculate_profile_similarity(
        profile_a, profile_b,
        hobbies_weight=weights["hobbies_weight"],
        values_weight=weights["values_weight"],
        intentions_weight=weights["intentions_weight"],
    )

    final_score = (synastry_score * weights["synastry"]) + (profile_similarity * weights["profile_similarity"])
    weighted_score = synastry_score

    insight = _generate_cosmic_insight(final_score, mode)

    return final_score, weighted_score, insight


def resolve_signal_weights(
    user_weights: Optional[dict] = None,
    mode: str = "dating",
) -> dict:
    """
    Resolve synastry / profile_similarity / behavioral weights for a scoring run.

    Priority:
    1. User-configurable weights (weight_natal_chart, weight_interests,
       weight_behavior) normalized to sum to 1.0.
    2. MODE_WEIGHTS defaults for the given mode.

    Shared by compute_full_compatibility_score() and the compatibility report
    endpoint so both produce the same number.
    """
    if user_weights and all(k in user_weights for k in ('weight_natal_chart', 'weight_interests', 'weight_behavior')):
        natal_raw = max(0, min(100, user_weights['weight_natal_chart']))
        interests_raw = max(0, min(100, user_weights['weight_interests']))
        behavior_raw = max(0, min(100, user_weights['weight_behavior']))

        total = natal_raw + interests_raw + behavior_raw
        if total > 0:
            return {
                "synastry": natal_raw / total,
                "profile_similarity": interests_raw / total,
                "behavioral": behavior_raw / total,
                "activity": 0.0,       # Activity and mutual interest are boosters, not user-configurable
                "mutual_interest": 0.0,
                "hobbies_weight": 0.15,
                "values_weight": 0.20,
                "intentions_weight": 0.15,
            }
    return MODE_WEIGHTS.get(mode, MODE_WEIGHTS["dating"])


def compute_full_compatibility_score(
    db: Session,
    current_user_id: int,
    profile_a: models.Profile,
    profile_b: models.Profile,
    mode: str = "dating",
    user_weights: Optional[dict] = None,
    chart: Optional[Tuple[Optional[float], bool]] = None,
) -> Tuple[Optional[float], Optional[float], Optional[float], float, float, float, str, List[str]]:
    """
    Compute full compatibility score combining all factors:
    synastry, profile similarity, behavioral compatibility, activity, mutual interest.

    Args:
        user_weights: Optional dict with keys 'weight_natal_chart', 'weight_interests',
                      'weight_behavior' (0-100 each). Normalized to sum to 1.0.
                      If None, uses MODE_WEIGHTS defaults.
        chart: Optional pre-computed (chart_score, partial) to avoid recomputing
               astrology when the caller already has it.

    Returns:
        (final_score, synastry_score, behavioral_score, activity_score,
         mutual_interest_score, weighted_score, cosmic_insight, top_reasons)

        synastry_score / behavioral_score are None when there is no real data
        behind them - callers must not display a made-up number.
    """
    weights = resolve_signal_weights(user_weights, mode)

    # 1. Chart (synastry) score
    if chart is not None:
        chart_score, chart_partial = chart
    else:
        chart_score, chart_partial = compute_chart_score(profile_a, profile_b)

    # 2. Profile similarity (None = nothing comparable on both profiles yet)
    profile_similarity: Optional[float] = None
    if profile_similarity_has_data(profile_a, profile_b):
        profile_similarity = calculate_profile_similarity(
            profile_a, profile_b,
            hobbies_weight=weights["hobbies_weight"],
            values_weight=weights["values_weight"],
            intentions_weight=weights["intentions_weight"],
        )

    # 3. Behavioral compatibility (None = no observed behaviour yet)
    behavioral_score = _calculate_behavioral_score(db, current_user_id, profile_b.user_id, mode)

    # 4. Activity score
    activity_score = _calculate_activity_score(db, profile_b.user_id)

    # 5. Mutual interest score
    mutual_interest = _calculate_mutual_interest_score(db, current_user_id, profile_b.user_id)

    # Ranking score: weighted average over the signals that actually exist,
    # so a missing behavioural profile never drags the number down (or fakes it).
    signals: List[Tuple[float, float]] = [
        (chart_score if chart_score is not None else 50.0, weights["synastry"]),
    ]
    if profile_similarity is not None:
        signals.append((profile_similarity, weights["profile_similarity"]))
    if behavioral_score is not None:
        signals.append((behavioral_score, weights["behavioral"]))

    weight_total = sum(weight for _, weight in signals) or 1.0
    base_score = sum(score * weight for score, weight in signals) / weight_total

    # Activity and mutual interest add a small boost (up to 10 points each).
    # Ranking only - they are NOT part of the displayed compatibility %.
    activity_boost = (activity_score / 100.0) * 10.0
    mutual_boost = (mutual_interest / 100.0) * 10.0

    final_score = max(0.0, min(100.0, base_score + activity_boost + mutual_boost))
    weighted_score = base_score

    # Generate reasons combining profile and behavioral insights
    top_reasons = generate_top_reasons(profile_a, profile_b, final_score, mode=mode)

    # Add behavioral reasons if available
    behavioral_reasons = _generate_behavioral_reasons(db, current_user_id, profile_b.user_id, mode)
    top_reasons = behavioral_reasons + top_reasons
    top_reasons = top_reasons[:5]

    insight = _generate_cosmic_insight(final_score, mode)

    return (
        final_score, chart_score, behavioral_score,
        activity_score, mutual_interest, weighted_score,
        insight, top_reasons,
    )


def build_score_parts(
    chart_score: Optional[float],
    chart_partial: bool,
    behavioral_score: Optional[float],
    profile_similarity: Optional[float],
) -> List[dict]:
    """
    Transparent score breakdown for the UI: one row per signal, with a null
    value when there is no data yet (never a placeholder number).
    """
    return [
        {
            "key": "chart",
            "label": "Natal chart",
            "value": round(chart_score) if chart_score is not None else None,
            "partial": bool(chart_partial),
        },
        {
            "key": "behavior",
            "label": "Behaviour",
            "value": round(behavioral_score) if behavioral_score is not None else None,
            "partial": False,
        },
        {
            "key": "profile",
            "label": "Interests & values",
            "value": round(profile_similarity) if profile_similarity is not None else None,
            "partial": False,
        },
    ]



def _calculate_behavioral_score(
    db: Session,
    user_a_id: int,
    user_b_id: int,
    mode: str = "dating",
) -> Optional[float]:
    """
    Behavioral compatibility score, or None when neither user has real
    behavioural data yet (default profiles are not a signal).
    """
    try:
        from .behavior_updater import get_or_create_behavior_profile, behavior_profile_has_data
        from .behavioral_scorer import calculate_behavioral_compatibility

        behavior_a = get_or_create_behavior_profile(db, user_a_id)
        behavior_b = get_or_create_behavior_profile(db, user_b_id)

        if not behavior_profile_has_data(behavior_a) or not behavior_profile_has_data(behavior_b):
            return None

        return calculate_behavioral_compatibility(behavior_a, behavior_b, mode=mode)
    except Exception as e:
        logger.debug(f"Behavioral scoring unavailable: {e}")
        return None


def _calculate_activity_score(db: Session, user_id: int) -> float:
    """
    Score user activity based on recency of engagement.
    More recent activity = higher score (0-100).
    """
    recent_match = db.query(models.Match).filter(
        models.Match.user_id == user_id
    ).order_by(models.Match.created_at.desc()).first()

    recent_message = db.query(models.Message).join(models.Match).filter(
        models.Match.user_id == user_id
    ).order_by(models.Message.created_at.desc()).first()

    # Use the most recent activity
    last_activity = None
    if recent_match and recent_message:
        last_activity = max(recent_match.created_at, recent_message.created_at)
    elif recent_match:
        last_activity = recent_match.created_at
    elif recent_message:
        last_activity = recent_message.created_at

    if not last_activity:
        return 20.0  # No activity

    days_since = (datetime.utcnow() - last_activity).days

    if days_since <= 1:
        return 100.0
    elif days_since <= 3:
        return 85.0
    elif days_since <= 7:
        return 70.0
    elif days_since <= 14:
        return 50.0
    elif days_since <= 30:
        return 30.0
    else:
        return 15.0


def _calculate_mutual_interest_score(
    db: Session,
    current_user_id: int,
    candidate_user_id: int,
) -> float:
    """
    Score based on whether the candidate has shown interest in the current user.
    80 if they've already liked you, 0 otherwise.
    """
    incoming = db.query(models.Match).filter(
        models.Match.user_id == candidate_user_id,
        models.Match.matched_user_id == current_user_id,
        models.Match.status == "accepted",
    ).first()

    if incoming:
        return 80.0

    return 0.0


def _generate_behavioral_reasons(
    db: Session,
    user_a_id: int,
    user_b_id: int,
    mode: str = "dating",
) -> List[str]:
    """Generate behavioral reasons if behavior profiles exist."""
    try:
        from .behavior_updater import get_or_create_behavior_profile
        from .behavioral_scorer import generate_behavioral_reasons

        behavior_a = get_or_create_behavior_profile(db, user_a_id)
        behavior_b = get_or_create_behavior_profile(db, user_b_id)

        score = _calculate_behavioral_score(db, user_a_id, user_b_id, mode)
        if score is None:
            return []
        return generate_behavioral_reasons(behavior_a, behavior_b, score, mode)
    except Exception:
        return []


def _generate_cosmic_insight(score: float, mode: str = "dating") -> str:
    if mode == "bff":
        if score >= 85:
            return "A rare connection - you share an incredible amount in common!"
        elif score >= 70:
            return "Great potential for friendship - your interests align beautifully."
        elif score >= 55:
            return "An interesting connection - there's plenty to explore together."
        else:
            return "Different personalities can create the best friendships - give it a chance!"
    else:
        if score >= 85:
            return "A rare cosmic alignment - your charts resonate on a deep level."
        elif score >= 70:
            return "The stars suggest strong potential - your energies complement each other."
        elif score >= 55:
            return "An interesting cosmic connection - there's room for growth and discovery."
        else:
            return "Opposite energies can create powerful growth - embrace the journey."


def generate_top_reasons(profile_a: models.Profile, profile_b: models.Profile, final_score: float, mode: str = "dating") -> List[str]:
    """Generate human-readable reasons for the match, mode-aware."""
    reasons = []

    hobbies_a = {h.name for h in profile_a.hobbies} if profile_a.hobbies else set()
    hobbies_b = {h.name for h in profile_b.hobbies} if profile_b.hobbies else set()
    shared_hobbies = hobbies_a & hobbies_b
    if shared_hobbies:
        if mode == "bff":
            reasons.insert(0, f"You both enjoy: {', '.join(list(shared_hobbies)[:3])}")
        else:
            reasons.append(f"Shared interests: {', '.join(list(shared_hobbies)[:3])}")

    values_a = {cv.key for cv in profile_a.core_values} if profile_a.core_values else set()
    values_b = {cv.key for cv in profile_b.core_values} if profile_b.core_values else set()
    shared_values = values_a & values_b
    if shared_values:
        reasons.append(f"Common values: {', '.join(list(shared_values)[:3])}")

    intentions_a = {i.key for i in profile_a.intentions} if profile_a.intentions else set()
    intentions_b = {i.key for i in profile_b.intentions} if profile_b.intentions else set()
    shared_intentions = intentions_a & intentions_b
    if shared_intentions:
        if mode == "bff":
            reasons.append(f"Both looking for: {', '.join(list(shared_intentions)[:2])}")
        else:
            reasons.append(f"Looking for: {', '.join(list(shared_intentions)[:2])}")

    if mode == "bff":
        if final_score >= 75:
            reasons.append("Excellent potential for a great friendship")
        elif final_score >= 60:
            reasons.append("Good foundation for friendship")
    else:
        if final_score >= 75:
            reasons.append("Strong overall compatibility score")
        elif final_score >= 60:
            reasons.append("Good potential for connection")

    return reasons[:5]


def meets_filters(
    profile: models.Profile,
    preferences: models.UserPreferences,
    current_user_profile: models.Profile,
    blocked_ids: set,
    swiped_user_ids: set,
) -> bool:
    """Check if a profile passes all preference filters."""
    if profile.user_id in blocked_ids:
        return False

    if profile.user_id in swiped_user_ids:
        return False

    if preferences.photos_only:
        if not profile.photos:
            return False

    if preferences.complete_profiles_only:
        if not profile.photos or not profile.bio:
            return False

    if profile.birth_date:
        age = calculate_age(profile.birth_date)
        if age < preferences.min_age or age > preferences.max_age:
            return False

    if preferences.genders and profile.sex:
        if profile.sex.name not in preferences.genders:
            return False

    if preferences.orientations and profile.orientation:
        if profile.orientation.name not in preferences.orientations:
            return False

    if preferences.min_height and profile.height:
        if profile.height < preferences.min_height:
            return False

    if preferences.max_height and profile.height:
        if profile.height > preferences.max_height:
            return False

    return True


def get_smart_discover_list(
    db: Session,
    current_user: models.SynoUser,
    preferences: Optional[models.UserPreferences] = None,
    mode: str = "dating",
    limit: int = 100,
) -> List[dict]:
    """
    Server-side smart discovery: filters, scores, and sorts potential matches.
    Returns a list of profile dicts with compatibility scores.
    Mode-aware: uses mode-specific preferences and scoring weights.
    """
    current_profile = db.query(models.Profile).options(
        joinedload(models.Profile.hobbies),
        joinedload(models.Profile.core_values),
        joinedload(models.Profile.intentions),
    ).filter(models.Profile.user_id == current_user.id).first()

    if not current_profile:
        return []

    # Load mode-specific preferences if available
    mode_prefs = db.query(models.UserAppMode).filter(
        models.UserAppMode.profile_id == current_profile.id,
        models.UserAppMode.mode == mode,
    ).first()

    blocked_ids = set()
    blocked_by_me = db.query(models.user_blocks.c.blocked_id).filter(
        models.user_blocks.c.blocker_id == current_user.id
    ).all()
    blocked_me = db.query(models.user_blocks.c.blocker_id).filter(
        models.user_blocks.c.blocked_id == current_user.id
    ).all()
    blocked_ids = {r[0] for r in blocked_by_me} | {r[0] for r in blocked_me}

    swiped_user_ids = set()
    swiped = db.query(models.Match.matched_user_id).filter(
        models.Match.user_id == current_user.id,
        models.Match.mode == mode,
    ).all()
    swiped_user_ids = {r[0] for r in swiped}

    received_like_ids = set()
    received = db.query(models.Match.user_id).filter(
        models.Match.matched_user_id == current_user.id,
        models.Match.status == "accepted",
        models.Match.mode == mode,
    ).all()
    received_like_ids = {r[0] for r in received}

    profiles = db.query(models.Profile).options(
        joinedload(models.Profile.location),
        joinedload(models.Profile.sex),
        joinedload(models.Profile.orientation),
        joinedload(models.Profile.photos),
        joinedload(models.Profile.hobbies),
        joinedload(models.Profile.intentions),
        joinedload(models.Profile.core_values),
        joinedload(models.Profile.professions),
        joinedload(models.Profile.educations),
    ).filter(
        models.Profile.user_id != current_user.id,
    ).limit(limit + 50).all()

    if not profiles:
        return []

    # Merge mode-specific prefs with global prefs for filtering
    effective_prefs = preferences
    if mode_prefs and preferences:
        # Create a copy-like object using mode_prefs overrides
        class MergedPrefs:
            pass
        merged = MergedPrefs()
        for attr in ['min_age', 'max_age', 'max_distance', 'genders', 'orientations',
                      'photos_only', 'complete_profiles_only', 'hide_swiped', 'hide_inactive']:
            mode_val = getattr(mode_prefs, attr, None)
            global_val = getattr(preferences, attr, None)
            setattr(merged, attr, mode_val if mode_val is not None else global_val)
        effective_prefs = merged
    elif mode_prefs:
        class MergedPrefs:
            pass
        merged = MergedPrefs()
        for attr in ['min_age', 'max_age', 'max_distance', 'genders', 'orientations',
                      'photos_only', 'complete_profiles_only', 'hide_swiped', 'hide_inactive']:
            setattr(merged, attr, getattr(mode_prefs, attr, None))
        # Set defaults for attrs that meets_filters expects
        if not hasattr(merged, 'min_height'): merged.min_height = None
        if not hasattr(merged, 'max_height'): merged.max_height = None
        effective_prefs = merged

    results = []
    for profile in profiles:
        if effective_prefs and not meets_filters(profile, effective_prefs, current_profile, blocked_ids, swiped_user_ids | received_like_ids):
            continue

        if not effective_prefs:
            if profile.user_id in blocked_ids or profile.user_id in swiped_user_ids or profile.user_id in received_like_ids:
                continue

        # Extract user-configurable matching signal weights
        user_weights = None
        if preferences:
            user_weights = {
                'weight_natal_chart': getattr(preferences, 'weight_natal_chart', 60),
                'weight_interests': getattr(preferences, 'weight_interests', 10),
                'weight_behavior': getattr(preferences, 'weight_behavior', 30),
            }
        elif mode_prefs:
            user_weights = {
                'weight_natal_chart': getattr(mode_prefs, 'weight_natal_chart', 60),
                'weight_interests': getattr(mode_prefs, 'weight_interests', 30),
                'weight_behavior': getattr(mode_prefs, 'weight_behavior', 10),
            }
        signal_weights = resolve_signal_weights(user_weights, mode)

        # Full astrology reading (chart score, aspects, interpretation).
        # Computed once and reused as the headline score + ranking input.
        synastry_data = _try_astrology_synastry_full(current_profile, profile)
        if synastry_data is not None:
            chart_score = synastry_data.get("score")
            chart_partial = bool(synastry_data.get("partial", False))
        else:
            chart_score, chart_partial = compute_chart_score(current_profile, profile)

        (
            final_score, _synastry_score, behavioral_score,
            activity_score, mutual_interest, weighted_score,
            cosmic_insight, top_reasons,
        ) = compute_full_compatibility_score(
            db, current_user.id, current_profile, profile, mode=mode,
            user_weights=user_weights,
            chart=(chart_score, chart_partial),
        )

        profile_sim: Optional[float] = None
        if profile_similarity_has_data(current_profile, profile):
            profile_sim = calculate_profile_similarity(
                current_profile, profile,
                hobbies_weight=signal_weights["hobbies_weight"],
                values_weight=signal_weights["values_weight"],
                intentions_weight=signal_weights["intentions_weight"],
            )

        score_parts = build_score_parts(
            chart_score, chart_partial, behavioral_score, profile_sim,
        )

        result = {
            "id": profile.id,
            "user_id": profile.user_id,
            "name": profile.name,
            "last_name": profile.last_name,
            "birth_date": profile.birth_date.isoformat() if profile.birth_date else None,
            "birth_time": profile.birth_time,
            "bio": profile.bio,
            "height": profile.height,
            "location": {"id": profile.location.id, "name": profile.location.name, "type": profile.location.type, "translation_key": profile.location.translation_key or '', "latitude": profile.location.latitude, "longitude": profile.location.longitude} if profile.location else None,
            "sex": {"id": profile.sex.id, "name": profile.sex.name, "translation_key": profile.sex.translation_key or ''} if profile.sex else None,
            "orientation": {"id": profile.orientation.id, "name": profile.orientation.name, "translation_key": profile.orientation.translation_key or ''} if profile.orientation else None,
            "photos": [{"id": ph.id, "is_primary": ph.is_primary, "upload_order": ph.upload_order, "url": f"/api/photos/{ph.id}"} for ph in profile.photos],
            "hobbies": [{"id": h.id, "name": h.name, "translation_key": h.translation_key or ''} for h in profile.hobbies],
            "intentions": [{"id": i.id, "key": i.key, "translation_key": i.translation_key} for i in profile.intentions],
            "core_values": [{"id": cv.id, "key": cv.key, "translation_key": cv.translation_key or ''} for cv in profile.core_values],
            "professions": [{"id": pr.id, "name": pr.name, "translation_key": pr.translation_key or ''} for pr in profile.professions],
            "educations": [{"id": e.id, "name": e.name, "translation_key": e.translation_key or ''} for e in profile.educations],
            # Headline % = the natal chart score (what the badge shows).
            # Falls back to the composite only when there is no chart at all.
            "compatibility_score": round(chart_score if chart_score is not None else final_score),
            "chart_score": round(chart_score) if chart_score is not None else None,
            "chart_partial": chart_partial,
            "profile_similarity_score": round(profile_sim) if profile_sim is not None else None,
            "synastry_score": round(chart_score) if chart_score is not None else None,
            "behavioral_score": round(behavioral_score) if behavioral_score is not None else None,
            # Weighted blend of the signals that actually exist (no boosts).
            "composite_score": round(weighted_score),
            "weighted_score": round(weighted_score),
            "score_parts": score_parts,
            "top_reasons": top_reasons,
            "cosmic_insight": cosmic_insight,
            "liked_by_user": profile.user_id in received_like_ids,
            "mode": mode,
            "synastry_data": synastry_data,
        }
        results.append(result)

    results.sort(
        key=lambda x: (-(x["chart_score"] if x["chart_score"] is not None else x["compatibility_score"]), x["user_id"])
    )

    return results[:limit]
