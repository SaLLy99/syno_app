"""
Server-side matching engine for SYNO.
Applies preference filters and computes compatibility scores.

When full birth data is available (date, time, timezone, coordinates),
the astrology module can provide real chart-based compatibility scores.
The hash-based fallback is used for quick scoring during discovery.
"""
import logging
import math
from datetime import date, datetime, time as dtime
from typing import List, Optional, Tuple
from sqlalchemy.orm import Session, joinedload

from . import models

logger = logging.getLogger(__name__)


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
    Server-side synastry score based on birth data.

    When full birth data is available (time + location coordinates),
    uses real astrology calculations via the astrology module.
    Falls back to a deterministic hash-based approach for quick scoring
    when birth time or location data is incomplete.
    """
    if not profile_a.birth_date or not profile_b.birth_date:
        return 50.0

    astrology_score = _try_astrology_synastry(profile_a, profile_b)
    if astrology_score is not None:
        return astrology_score

    day_a = profile_a.birth_date.day
    month_a = profile_a.birth_date.month
    year_a = profile_a.birth_date.year
    day_b = profile_b.birth_date.day
    month_b = profile_b.birth_date.month
    year_b = profile_b.birth_date.year

    hash_val = (day_a * 31 + month_a * 12 + year_a * 7 + day_b * 31 + month_b * 12 + year_b * 7) % 100
    base_score = 25 + (hash_val * 0.7)
    return min(max(base_score, 25.0), 95.0)


def _try_astrology_synastry(
    profile_a: models.Profile,
    profile_b: models.Profile,
) -> Optional[float]:
    """
    Attempt real astrology synastry calculation.
    Returns None if full birth data is not available.
    """
    try:
        if not profile_a.birth_time or not profile_b.birth_time:
            return None

        location_a = profile_a.location
        location_b = profile_b.location
        if not location_a or not location_b:
            return None

        from .astrology.domain.models import BirthData
        from .astrology.providers.western import SwissEphProvider
        from .astrology.services.compatibility_service import CompatibilityService

        def _parse_birth_time(time_str: str) -> dtime:
            parts = time_str.split(":")
            return dtime(int(parts[0]), int(parts[1]))

        birth_a = BirthData(
            birth_date=profile_a.birth_date,
            birth_time=_parse_birth_time(profile_a.birth_time),
            timezone="+00:00",
            latitude=getattr(location_a, 'latitude', None) or 41.7151,
            longitude=getattr(location_a, 'longitude', None) or 44.8271,
            location_name=location_a.name,
        )
        birth_b = BirthData(
            birth_date=profile_b.birth_date,
            birth_time=_parse_birth_time(profile_b.birth_time),
            timezone="+00:00",
            latitude=getattr(location_b, 'latitude', None) or 41.7151,
            longitude=getattr(location_b, 'longitude', None) or 44.8271,
            location_name=location_b.name,
        )

        provider = SwissEphProvider()
        compat_service = CompatibilityService(provider)
        dimensions = compat_service.calculate_compatibility(birth_a, birth_b)

        return dimensions.overall

    except Exception as e:
        logger.debug(f"Astrology synastry unavailable, using fallback: {e}")
        return None


def calculate_profile_similarity(profile_a: models.Profile, profile_b: models.Profile) -> float:
    """Calculate similarity based on profile attributes."""
    score = 50.0

    hobbies_a = {h.id for h in profile_a.hobbies} if profile_a.hobbies else set()
    hobbies_b = {h.id for h in profile_b.hobbies} if profile_b.hobbies else set()
    if hobbies_a and hobbies_b:
        overlap = len(hobbies_a & hobbies_b)
        total = len(hobbies_a | hobbies_b)
        score += (overlap / total) * 20 if total > 0 else 0

    values_a = {cv.id for cv in profile_a.core_values} if profile_a.core_values else set()
    values_b = {cv.id for cv in profile_b.core_values} if profile_b.core_values else set()
    if values_a and values_b:
        overlap = len(values_a & values_b)
        total = len(values_a | values_b)
        score += (overlap / total) * 20 if total > 0 else 0

    intentions_a = {i.id for i in profile_a.intentions} if profile_a.intentions else set()
    intentions_b = {i.id for i in profile_b.intentions} if profile_b.intentions else set()
    if intentions_a and intentions_b:
        overlap = len(intentions_a & intentions_b)
        total = len(intentions_a | intentions_b)
        score += (overlap / total) * 10 if total > 0 else 0

    return min(score, 100.0)


def compute_compatibility_score(
    profile_a: models.Profile,
    profile_b: models.Profile,
) -> Tuple[float, float, str]:
    """
    Compute overall compatibility between two profiles.
    Returns (final_score, weighted_score, cosmic_insight).
    """
    synastry_score = calculate_synastry_score(profile_a, profile_b)
    profile_similarity = calculate_profile_similarity(profile_a, profile_b)

    final_score = (synastry_score * 0.6) + (profile_similarity * 0.4)
    weighted_score = synastry_score

    insight = _generate_cosmic_insight(final_score)

    return final_score, weighted_score, insight


def _generate_cosmic_insight(score: float) -> str:
    if score >= 85:
        return "A rare cosmic alignment - your charts resonate on a deep level."
    elif score >= 70:
        return "The stars suggest strong potential - your energies complement each other."
    elif score >= 55:
        return "An interesting cosmic connection - there's room for growth and discovery."
    else:
        return "Opposite energies can create powerful growth - embrace the journey."


def generate_top_reasons(profile_a: models.Profile, profile_b: models.Profile, final_score: float) -> List[str]:
    """Generate human-readable reasons for the match."""
    reasons = []

    hobbies_a = {h.name for h in profile_a.hobbies} if profile_a.hobbies else set()
    hobbies_b = {h.name for h in profile_b.hobbies} if profile_b.hobbies else set()
    shared_hobbies = hobbies_a & hobbies_b
    if shared_hobbies:
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
        reasons.append(f"Looking for: {', '.join(list(shared_intentions)[:2])}")

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
    limit: int = 100,
) -> List[dict]:
    """
    Server-side smart discovery: filters, scores, and sorts potential matches.
    Returns a list of profile dicts with compatibility scores.
    """
    current_profile = db.query(models.Profile).options(
        joinedload(models.Profile.hobbies),
        joinedload(models.Profile.core_values),
        joinedload(models.Profile.intentions),
    ).filter(models.Profile.user_id == current_user.id).first()

    if not current_profile:
        return []

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
        models.Match.user_id == current_user.id
    ).all()
    swiped_user_ids = {r[0] for r in swiped}

    received_like_ids = set()
    received = db.query(models.Match.user_id).filter(
        models.Match.matched_user_id == current_user.id,
        models.Match.status == "accepted"
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

    results = []
    for profile in profiles:
        prefs_to_use = preferences

        if prefs_to_use and not meets_filters(profile, prefs_to_use, current_profile, blocked_ids, swiped_user_ids | received_like_ids):
            continue

        if not prefs_to_use:
            if profile.user_id in blocked_ids or profile.user_id in swiped_user_ids or profile.user_id in received_like_ids:
                continue

        final_score, weighted_score, cosmic_insight = compute_compatibility_score(current_profile, profile)
        top_reasons = generate_top_reasons(current_profile, profile, final_score)

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
            "compatibility_score": round(final_score),
            "weighted_score": round(weighted_score),
            "top_reasons": top_reasons,
            "cosmic_insight": cosmic_insight,
            "liked_by_user": profile.user_id in received_like_ids,
        }
        results.append(result)

    results.sort(key=lambda x: (-x["compatibility_score"], x["user_id"]))

    return results[:limit]
