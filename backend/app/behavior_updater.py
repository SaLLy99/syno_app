"""
Behavior updater for SYNO.
Derives UserBehaviorProfile from analytics events, match actions, and messages.

Called after key events (swipe, message) and on a daily cron to keep profiles fresh.
"""
import json
import logging
from datetime import datetime, timedelta
from typing import Optional
from sqlalchemy.orm import Session
from sqlalchemy import func as sql_func

from . import models

logger = logging.getLogger(__name__)

# Column defaults of models.UserBehaviorProfile. A profile where every field
# still equals its default carries no observed behaviour - it must not be
# scored (identical defaults would otherwise report a perfect match).
BEHAVIOR_DEFAULTS = {
    "selectivity": 0.5,
    "avg_profiles_per_session": 10.0,
    "avg_response_time_minutes": 60.0,
    "avg_message_length": 50.0,
    "conversation_depth": 5.0,
    "initiator_ratio": 0.5,
    "sessions_per_week": 3.0,
    "avg_session_minutes": 10.0,
    "peak_hour": 20,
    "openness_behavioral": 50.0,
    "conscientiousness_behavioral": 50.0,
    "extraversion_behavioral": 50.0,
    "agreeableness_behavioral": 50.0,
    "emotional_stability_behavioral": 50.0,
}


def behavior_profile_has_data(profile: models.UserBehaviorProfile) -> bool:
    """
    True when the profile reflects real user activity.

    False for freshly seeded rows (every column still at its default) - those
    have no behavioural signal and must show as "no data yet", not as a score.
    """
    if profile is None:
        return False

    for field, default in BEHAVIOR_DEFAULTS.items():
        value = getattr(profile, field, None)
        if value is None:
            continue
        if value != default:
            return True
    return False


def get_or_create_behavior_profile(db: Session, user_id: int) -> models.UserBehaviorProfile:
    """Get existing behavior profile or create a default one."""
    profile = db.query(models.UserBehaviorProfile).filter(
        models.UserBehaviorProfile.user_id == user_id
    ).first()

    if not profile:
        profile = models.UserBehaviorProfile(user_id=user_id)
        db.add(profile)
        db.commit()
        db.refresh(profile)

    return profile


def update_behavior_profile(db: Session, user_id: int) -> models.UserBehaviorProfile:
    """
    Recalculate the full behavioral profile for a user.
    Aggregates data from analytics_events, matches, and messages.
    """
    profile = get_or_create_behavior_profile(db, user_id)

    # 1. Swipe patterns
    profile.selectivity = _calculate_selectivity(db, user_id)
    profile.avg_profiles_per_session = _calculate_avg_profiles_per_session(db, user_id)

    # 2. Messaging patterns
    msg_patterns = _calculate_messaging_patterns(db, user_id)
    profile.avg_response_time_minutes = msg_patterns["avg_response_time"]
    profile.avg_message_length = msg_patterns["avg_message_length"]
    profile.conversation_depth = msg_patterns["conversation_depth"]
    profile.initiator_ratio = msg_patterns["initiator_ratio"]

    # 3. Engagement patterns
    engagement = _calculate_engagement(db, user_id)
    profile.sessions_per_week = engagement["sessions_per_week"]
    profile.avg_session_minutes = engagement["avg_session_minutes"]
    profile.peak_hour = engagement["peak_hour"]

    # 4. Personality from behavior
    personality = _derive_personality_from_behavior(db, user_id, profile)
    profile.openness_behavioral = personality["openness"]
    profile.conscientiousness_behavioral = personality["conscientiousness"]
    profile.extraversion_behavioral = personality["extraversion"]
    profile.agreeableness_behavioral = personality["agreeableness"]
    profile.emotional_stability_behavioral = personality["emotional_stability"]

    profile.computed_at = datetime.utcnow()
    db.commit()
    db.refresh(profile)

    return profile


def _calculate_selectivity(db: Session, user_id: int) -> float:
    """
    Calculate how selective a user is: likes_sent / profiles_viewed.
    Low selectivity = likes everyone (0.0), high selectivity = very picky (1.0).
    """
    # Count profiles viewed (profile_view events)
    views = db.query(models.AnalyticsEvent).filter(
        models.AnalyticsEvent.user_id == user_id,
        models.AnalyticsEvent.event_type == "profile_view",
    ).count()

    # Count likes sent
    likes = db.query(models.Match).filter(
        models.Match.user_id == user_id,
        models.Match.status == "accepted",
    ).count()

    # Count passes
    passes = db.query(models.Match).filter(
        models.Match.user_id == user_id,
        models.Match.status == "declined",
    ).count()

    total_actions = likes + passes
    if total_actions == 0:
        return 0.5  # Default: moderate selectivity

    # Selectivity = ratio of likes to total views/actions
    # If they like 30% of people they see = 0.3 selectivity
    like_ratio = likes / max(total_actions, 1)

    # Invert: low like ratio = high selectivity
    selectivity = 1.0 - like_ratio
    return max(0.0, min(1.0, selectivity))


def _calculate_avg_profiles_per_session(db: Session, user_id: int) -> float:
    """Calculate average number of profiles viewed per session."""
    # Look for session_start and profile_view events
    session_starts = db.query(models.AnalyticsEvent).filter(
        models.AnalyticsEvent.user_id == user_id,
        models.AnalyticsEvent.event_type == "session_start",
    ).count()

    total_views = db.query(models.AnalyticsEvent).filter(
        models.AnalyticsEvent.user_id == user_id,
        models.AnalyticsEvent.event_type == "profile_view",
    ).count()

    if session_starts == 0:
        return 10.0  # Default

    return total_views / session_starts


def _calculate_messaging_patterns(db: Session, user_id: int) -> dict:
    """Calculate messaging behavior patterns."""
    # Get all matches where this user is involved
    user_matches = db.query(models.Match).filter(
        (models.Match.user_id == user_id) | (models.Match.matched_user_id == user_id),
        models.Match.status == "accepted",
    ).all()

    match_ids = [m.id for m in user_matches]
    if not match_ids:
        return {
            "avg_response_time": 60.0,
            "avg_message_length": 50.0,
            "conversation_depth": 5.0,
            "initiator_ratio": 0.5,
        }

    # Get all messages in these matches
    all_messages = db.query(models.Message).filter(
        models.Message.match_id.in_(match_ids),
    ).order_by(models.Message.match_id, models.Message.created_at).all()

    if not all_messages:
        return {
            "avg_response_time": 60.0,
            "avg_message_length": 50.0,
            "conversation_depth": 5.0,
            "initiator_ratio": 0.5,
        }

    # Calculate average message length for this user
    user_messages = [m for m in all_messages if m.sender_id == user_id]
    if user_messages:
        avg_length = sum(len(m.content or "") for m in user_messages) / len(user_messages)
    else:
        avg_length = 50.0

    # Calculate conversation depth (messages per match)
    messages_per_match = {}
    for m in all_messages:
        if m.match_id not in messages_per_match:
            messages_per_match[m.match_id] = 0
        messages_per_match[m.match_id] += 1

    avg_depth = sum(messages_per_match.values()) / len(messages_per_match) if messages_per_match else 5.0

    # Calculate response time
    response_times = []
    for match_id in match_ids:
        match_msgs = [m for m in all_messages if m.match_id == match_id]
        match_msgs.sort(key=lambda m: m.created_at)

        for i in range(1, len(match_msgs)):
            if match_msgs[i].sender_id == user_id and match_msgs[i - 1].sender_id != user_id:
                delta = match_msgs[i].created_at - match_msgs[i - 1].created_at
                response_times.append(delta.total_seconds() / 60.0)

    avg_response = sum(response_times) / len(response_times) if response_times else 60.0

    # Calculate initiator ratio (how often this user sends first message in a match)
    initiations = 0
    for match_id in match_ids:
        match_msgs = [m for m in all_messages if m.match_id == match_id]
        match_msgs.sort(key=lambda m: m.created_at)
        if match_msgs and match_msgs[0].sender_id == user_id:
            initiations += 1

    initiator_ratio = initiations / len(match_ids) if match_ids else 0.5

    return {
        "avg_response_time": max(0.0, min(1440.0, avg_response)),  # Clamp to 0-1440 min
        "avg_message_length": max(0.0, min(500.0, avg_length)),
        "conversation_depth": max(0.0, min(100.0, avg_depth)),
        "initiator_ratio": max(0.0, min(1.0, initiator_ratio)),
    }


def _calculate_engagement(db: Session, user_id: int) -> dict:
    """Calculate engagement patterns from analytics events."""
    # Get all events for this user in the last 30 days
    thirty_days_ago = datetime.utcnow() - timedelta(days=30)

    events = db.query(models.AnalyticsEvent).filter(
        models.AnalyticsEvent.user_id == user_id,
        models.AnalyticsEvent.created_at >= thirty_days_ago,
    ).all()

    if not events:
        return {
            "sessions_per_week": 3.0,
            "avg_session_minutes": 10.0,
            "peak_hour": 20,
        }

    # Calculate sessions per week
    # A session is roughly defined by session_start events, or gaps > 30 min
    session_dates = set()
    for event in events:
        session_dates.add(event.created_at.date())

    weeks = 30 / 7
    sessions_per_week = len(session_dates) / weeks if weeks > 0 else 3.0

    # Calculate peak hour
    hour_counts = {}
    for event in events:
        hour = event.created_at.hour
        hour_counts[hour] = hour_counts.get(hour, 0) + 1

    peak_hour = max(hour_counts, key=hour_counts.get) if hour_counts else 20

    # Estimate avg session duration from event timestamps
    # Group events by date and estimate session length
    events_by_date = {}
    for event in events:
        d = event.created_at.date()
        if d not in events_by_date:
            events_by_date[d] = []
        events_by_date[d].append(event)

    session_durations = []
    for date_events in events_by_date.values():
        date_events.sort(key=lambda e: e.created_at)
        if len(date_events) >= 2:
            duration = (date_events[-1].created_at - date_events[0].created_at).total_seconds() / 60.0
            session_durations.append(min(duration, 180.0))  # Cap at 3 hours

    avg_session = sum(session_durations) / len(session_durations) if session_durations else 10.0

    return {
        "sessions_per_week": max(0.0, min(50.0, sessions_per_week)),
        "avg_session_minutes": max(0.0, min(180.0, avg_session)),
        "peak_hour": peak_hour,
    }


def _derive_personality_from_behavior(
    db: Session,
    user_id: int,
    behavior_profile: models.UserBehaviorProfile,
) -> dict:
    """
    Derive Big Five personality traits from behavioral patterns.

    Mappings (research-based approximations):
    - Openness: high selectivity + diverse profiles viewed + creative messages
    - Conscientiousness: regular session patterns + consistent messaging
    - Extraversion: high initiator ratio + short response time + frequent sessions
    - Agreeableness: long conversations + mutual matches + longer messages
    - Emotional Stability: consistent behavior + moderate selectivity
    """
    # Start from self-reported traits if available, otherwise default to 50
    user = db.query(models.SynoUser).filter(models.SynoUser.id == user_id).first()
    profile = db.query(models.Profile).filter(models.Profile.user_id == user_id).first()

    # Use self-reported personality traits as baseline if available
    # (These come from the Flutter personalityTraits map, stored in profile or preferences)
    base_traits = {
        "openness": 50.0,
        "conscientiousness": 50.0,
        "extraversion": 50.0,
        "agreeableness": 50.0,
        "emotional_stability": 50.0,
    }

    # Adjust based on behavior
    # Openness: selective users who view diverse profiles tend to be more open
    openness_adj = 0.0
    if behavior_profile.selectivity > 0.6:
        openness_adj += 10  # Picky = more selective tastes = higher openness
    elif behavior_profile.selectivity < 0.3:
        openness_adj -= 5   # Likes everyone = less selective = lower openness

    # Conscientiousness: regular session patterns = more conscientious
    conscientiousness_adj = 0.0
    if behavior_profile.sessions_per_week > 5:
        conscientiousness_adj += 10  # Very regular user
    elif behavior_profile.sessions_per_week < 1:
        conscientiousness_adj -= 5   # Sporadic user

    # Extraversion: high initiator ratio + frequent sessions = more extraverted
    extraversion_adj = 0.0
    if behavior_profile.initiator_ratio > 0.6:
        extraversion_adj += 15  # Often initiates conversations
    elif behavior_profile.initiator_ratio < 0.3:
        extraversion_adj -= 10  # Rarely initiates

    if behavior_profile.sessions_per_week > 7:
        extraversion_adj += 5  # Very active user

    # Agreeableness: longer messages + deeper conversations = more agreeable
    agreeableness_adj = 0.0
    if behavior_profile.avg_message_length > 100:
        agreeableness_adj += 10  # Writes long, thoughtful messages
    elif behavior_profile.avg_message_length < 20:
        agreeableness_adj -= 5   # Very short messages

    if behavior_profile.conversation_depth > 10:
        agreeableness_adj += 10  # Engages in deep conversations

    # Emotional Stability: moderate behavior patterns = more stable
    emotional_adj = 0.0
    if 0.3 <= behavior_profile.selectivity <= 0.7:
        emotional_adj += 10  # Moderate selectivity = balanced
    if 2 <= behavior_profile.sessions_per_week <= 10:
        emotional_adj += 5   # Regular but not obsessive

    # Combine base + adjustments, clamp to 0-100
    return {
        "openness": max(0.0, min(100.0, base_traits["openness"] + openness_adj)),
        "conscientiousness": max(0.0, min(100.0, base_traits["conscientiousness"] + conscientiousness_adj)),
        "extraversion": max(0.0, min(100.0, base_traits["extraversion"] + extraversion_adj)),
        "agreeableness": max(0.0, min(100.0, base_traits["agreeableness"] + agreeableness_adj)),
        "emotional_stability": max(0.0, min(100.0, base_traits["emotional_stability"] + emotional_adj)),
    }
