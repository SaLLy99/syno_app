"""
Recommendation engine for SYNO.
Generates daily top picks based on compatibility, activity, and profile quality.
"""
import json
from datetime import date, datetime, timedelta
from typing import List, Optional
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import func as sql_func

from . import models
from .matching_engine import (
    compute_compatibility_score,
    generate_top_reasons,
    calculate_age,
)


def calculate_profile_quality_score(profile: models.Profile) -> float:
    """Score how complete and attractive a profile is (0-100)."""
    score = 0.0

    if profile.photos:
        score += min(len(profile.photos) * 10, 30)

    if profile.bio and len(profile.bio) > 20:
        score += 20
    elif profile.bio:
        score += 10

    if profile.hobbies:
        score += min(len(profile.hobbies) * 5, 15)

    if profile.core_values:
        score += min(len(profile.core_values) * 5, 15)

    if profile.intentions:
        score += 10

    if profile.height:
        score += 5

    if profile.birth_date:
        score += 5

    return min(score, 100.0)


def calculate_activity_score(
    db: Session,
    user_id: int,
) -> float:
    """Score user activity (0-100). More recent activity = higher score."""
    recent_match = db.query(models.Match).filter(
        models.Match.user_id == user_id
    ).order_by(models.Match.created_at.desc()).first()

    if not recent_match:
        return 20.0

    days_since = (datetime.utcnow() - recent_match.created_at).days

    if days_since <= 1:
        return 100.0
    elif days_since <= 3:
        return 80.0
    elif days_since <= 7:
        return 60.0
    elif days_since <= 14:
        return 40.0
    else:
        return 20.0


def calculate_mutual_interest_score(
    db: Session,
    current_user_id: int,
    candidate_user_id: int,
) -> float:
    """Score based on whether the candidate has shown interest in the current user."""
    incoming = db.query(models.Match).filter(
        models.Match.user_id == candidate_user_id,
        models.Match.matched_user_id == current_user_id,
        models.Match.status == "accepted",
    ).first()

    if incoming:
        return 80.0

    return 0.0


def calculate_intention_alignment(
    profile_a: models.Profile,
    profile_b: models.Profile,
) -> float:
    """Score based on how aligned intentions are."""
    if not profile_a.intentions or not profile_b.intentions:
        return 50.0

    keys_a = {i.key for i in profile_a.intentions}
    keys_b = {i.key for i in profile_b.intentions}

    if not keys_a or not keys_b:
        return 50.0

    overlap = len(keys_a & keys_b)
    total = len(keys_a | keys_b)

    if total == 0:
        return 50.0

    return (overlap / total) * 100.0


def generate_daily_recommendations(
    db: Session,
    current_user: models.SynoUser,
    max_recommendations: int = 10,
) -> List[dict]:
    """
    Generate daily top pick recommendations.
    Combines compatibility, profile quality, activity, and mutual interest.
    """
    today = date.today()

    existing_today = db.query(models.Recommendation).filter(
        models.Recommendation.user_id == current_user.id,
        models.Recommendation.recommendation_date == today,
    ).all()

    if existing_today:
        return _format_existing_recommendations(db, existing_today)

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

    swiped_ids = set()
    swiped = db.query(models.Match.matched_user_id).filter(
        models.Match.user_id == current_user.id
    ).all()
    swiped_ids = {r[0] for r in swiped}

    preferences = db.query(models.UserPreferences).filter(
        models.UserPreferences.profile_id == current_profile.id
    ).first()

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
    ).all()

    candidates = []
    for profile in profiles:
        if profile.user_id in blocked_ids or profile.user_id in swiped_ids:
            continue

        if preferences:
            if preferences.photos_only and not profile.photos:
                continue
            if preferences.complete_profiles_only and (not profile.photos or not profile.bio):
                continue
            if profile.birth_date:
                age = calculate_age(profile.birth_date)
                if age < preferences.min_age or age > preferences.max_age:
                    continue
            if preferences.genders and profile.sex:
                if profile.sex.name not in preferences.genders:
                    continue
            if preferences.orientations and profile.orientation:
                if profile.orientation.name not in preferences.orientations:
                    continue
            if preferences.min_height and profile.height:
                if profile.height < preferences.min_height:
                    continue
            if preferences.max_height and profile.height:
                if profile.height > preferences.max_height:
                    continue

        compatibility_score, _, cosmic_insight = compute_compatibility_score(current_profile, profile)
        top_reasons = generate_top_reasons(current_profile, profile, compatibility_score)

        profile_quality = calculate_profile_quality_score(profile)
        activity_score = calculate_activity_score(db, profile.user_id)
        mutual_interest = calculate_mutual_interest_score(db, current_user.id, profile.user_id)
        intention_alignment = calculate_intention_alignment(current_profile, profile)

        final_score = (
            compatibility_score * 0.40 +
            profile_quality * 0.20 +
            activity_score * 0.15 +
            mutual_interest * 0.15 +
            intention_alignment * 0.10
        )

        candidates.append({
            "profile": profile,
            "score": round(final_score),
            "reasons": top_reasons,
            "cosmic_insight": cosmic_insight,
        })

    candidates.sort(key=lambda x: x["score"], reverse=True)
    top_picks = candidates[:max_recommendations]

    recommendations = []
    for pick in top_picks:
        profile = pick["profile"]
        rec = models.Recommendation(
            user_id=current_user.id,
            recommended_user_id=profile.user_id,
            score=pick["score"],
            reasons=json.dumps(pick["reasons"]),
            cosmic_insight=pick["cosmic_insight"],
            recommendation_date=today,
        )
        db.add(rec)
        recommendations.append(rec)

    db.commit()

    return _format_existing_recommendations(db, recommendations)


def _format_existing_recommendations(
    db: Session,
    recommendations: List[models.Recommendation],
) -> List[dict]:
    """Format recommendation objects with profile data."""
    if not recommendations:
        return []

    user_ids = [rec.recommended_user_id for rec in recommendations]
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
    ).filter(models.Profile.user_id.in_(user_ids)).all()
    profile_map = {p.user_id: p for p in profiles}

    results = []
    for rec in recommendations:
        profile = profile_map.get(rec.recommended_user_id)
        if not profile:
            continue

        primary_photo = next(
            (p for p in profile.photos if p.is_primary),
            (profile.photos[0] if profile.photos else None)
        )

        reasons = []
        try:
            reasons = json.loads(rec.reasons) if rec.reasons else []
        except (json.JSONDecodeError, TypeError):
            reasons = []

        results.append({
            "id": rec.id,
            "recommended_user_id": rec.recommended_user_id,
            "score": rec.score,
            "reasons": reasons,
            "cosmic_insight": rec.cosmic_insight or "",
            "recommendation_date": rec.recommendation_date.isoformat(),
            "profile": {
                "id": profile.user_id,
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
            }
        })

    return results
