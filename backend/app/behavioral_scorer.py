"""
Behavioral compatibility scorer for SYNO.
Calculates compatibility based on observed user behavior patterns.

Key insight: Some traits work better SIMILAR (values, communication style),
others work better COMPLEMENTARY (initiator/responder, activity levels).
"""
import logging
from typing import Optional

from . import models

logger = logging.getLogger(__name__)


def calculate_behavioral_compatibility(
    behavior_a: models.UserBehaviorProfile,
    behavior_b: models.UserBehaviorProfile,
    mode: str = "dating",
) -> float:
    """
    Calculate behavioral compatibility between two users.

    Scoring breakdown (total ~100 points, clamped to 30-95):
    - Communication style similarity: up to 20 pts
    - Conversation depth compatibility: up to 15 pts
    - Activity level match: up to 15 pts
    - Personality trait similarity: up to 25 pts
    - Initiator/responder complementarity: up to 12 pts
    - Response time compatibility: up to 8 pts
    - Selectivity signal: up to 10 pts
    """
    score = 50.0  # Start at neutral

    # --- SIMILARITY-BASED (similar is better) ---

    # 1. Communication style match (message length similarity)
    score += _score_communication_style(behavior_a, behavior_b)

    # 2. Conversation depth compatibility
    score += _score_conversation_depth(behavior_a, behavior_b)

    # 3. Activity level match
    score += _score_activity_level(behavior_a, behavior_b, mode)

    # 4. Personality trait similarity (Big Five from behavior)
    score += _score_personality_traits(behavior_a, behavior_b)

    # --- COMPLEMENTARITY-BASED (different can be better) ---

    # 5. Initiator/responder balance
    score += _score_initiator_balance(behavior_a, behavior_b)

    # 6. Response time compatibility
    score += _score_response_time(behavior_a, behavior_b)

    # --- SIGNAL-BASED ---

    # 7. Selectivity signal (both picky = higher quality matches)
    score += _score_selectivity_signal(behavior_a, behavior_b)

    # --- MODE ADJUSTMENTS ---
    if mode == "bff":
        # Friendship: weight conversation depth and activity level higher
        depth_bonus = _score_conversation_depth(behavior_a, behavior_b) * 0.3
        activity_bonus = _score_activity_level(behavior_a, behavior_b, mode) * 0.2
        score += depth_bonus + activity_bonus

    return max(30.0, min(95.0, score))


def _score_communication_style(
    a: models.UserBehaviorProfile,
    b: models.UserBehaviorProfile,
) -> float:
    """
    Score based on message length similarity.
    Similar message lengths = better communication match.
    Range: -8 to +12
    """
    diff = abs(a.avg_message_length - b.avg_message_length)

    if diff < 20:
        return 12.0  # Very similar style
    elif diff < 50:
        return 8.0   # Somewhat similar
    elif diff < 100:
        return 3.0   # Different but workable
    else:
        return -2.0  # Very different styles


def _score_conversation_depth(
    a: models.UserBehaviorProfile,
    b: models.UserBehaviorProfile,
) -> float:
    """
    Score based on how deep conversations each user tends to have.
    Both liking deep conversations = high score.
    Range: -5 to +12
    """
    avg_depth = (a.conversation_depth + b.conversation_depth) / 2.0
    diff = abs(a.conversation_depth - b.conversation_depth)

    score = 0.0

    # Bonus for both having deep conversations
    if avg_depth > 15:
        score += 12.0
    elif avg_depth > 8:
        score += 8.0
    elif avg_depth > 4:
        score += 4.0

    # Penalty for very different depths
    if diff > 15:
        score -= 5.0
    elif diff > 8:
        score -= 2.0

    return max(-5.0, min(12.0, score))


def _score_activity_level(
    a: models.UserBehaviorProfile,
    b: models.UserBehaviorProfile,
    mode: str,
) -> float:
    """
    Score based on activity level match.
    For dating: both active is important.
    For friendship: similar activity levels matter.
    Range: -8 to +12
    """
    diff = abs(a.sessions_per_week - b.sessions_per_week)
    avg_activity = (a.sessions_per_week + b.sessions_per_week) / 2.0

    score = 0.0

    # Both active = good
    if avg_activity > 5 and diff < 3:
        score += 12.0
    elif avg_activity > 2 and diff < 4:
        score += 8.0
    elif avg_activity > 1 and diff < 5:
        score += 4.0

    # One very active, one very inactive = friction
    if diff > 10:
        score -= 8.0
    elif diff > 6:
        score -= 4.0
    elif diff > 3:
        score -= 1.0

    return max(-8.0, min(12.0, score))


def _score_personality_traits(
    a: models.UserBehaviorProfile,
    b: models.UserBehaviorProfile,
) -> float:
    """
    Score based on Big Five personality trait similarity.
    Some traits work better similar, others complementary.

    Traits weighted by importance:
    - agreeableness: 2.5x (most important for compatibility)
    - emotional_stability: 2.0x
    - openness: 1.5x
    - conscientiousness: 1.0x
    - extraversion: 1.5x (complementary can work)
    """
    score = 0.0

    trait_weights = {
        "agreeableness": 2.5,
        "emotional_stability": 2.0,
        "openness": 1.5,
        "conscientiousness": 1.0,
        "extraversion": 1.5,
    }

    trait_pairs = [
        ("agreeableness", "agreeableness_behavioral"),
        ("emotional_stability", "emotional_stability_behavioral"),
        ("openness", "openness_behavioral"),
        ("conscientiousness", "conscientiousness_behavioral"),
        ("extraversion", "extraversion_behavioral"),
    ]

    for trait_name, attr in trait_pairs:
        val_a = getattr(a, attr, 50.0)
        val_b = getattr(b, attr, 50.0)
        diff = abs(val_a - val_b)
        weight = trait_weights[trait_name]

        if trait_name == "extraversion":
            # Extraversion: complementary can work (20-40 diff = neutral)
            if diff < 15:
                score += 2.0 * weight  # Similar = good
            elif diff < 30:
                score += 0.5 * weight  # Somewhat different = neutral/slight bonus
            elif diff < 50:
                score -= 0.5 * weight  # Very different = slight penalty
            else:
                score -= 1.0 * weight  # Extreme difference = penalty
        else:
            # Other traits: similar is better
            if diff < 15:
                score += 2.5 * weight
            elif diff < 30:
                score += 1.0 * weight
            elif diff < 50:
                score += 0.0
            else:
                score -= 0.5 * weight

    return max(-8.0, min(25.0, score))


def _score_initiator_balance(
    a: models.UserBehaviorProfile,
    b: models.UserBehaviorProfile,
) -> float:
    """
    Score based on initiator/responder balance.
    One person initiating + other responding = ideal dynamic.
    Both always initiating or both never = friction.
    Range: -5 to +12
    """
    diff = abs(a.initiator_ratio - b.initiator_ratio)

    # Sweet spot: some complementarity (0.2 < diff < 0.6)
    if 0.15 < diff < 0.55:
        return 12.0  # Great balance
    elif 0.1 < diff < 0.65:
        return 8.0   # Good balance
    elif diff < 0.1:
        # Both always initiate or both never = slight friction
        avg_init = (a.initiator_ratio + b.initiator_ratio) / 2.0
        if avg_init > 0.7:
            return 2.0  # Both initiate a lot = okay but some competition
        elif avg_init < 0.3:
            return 0.0  # Both rarely initiate = conversation may stall
        return 4.0
    else:
        return -2.0  # Very imbalanced


def _score_response_time(
    a: models.UserBehaviorProfile,
    b: models.UserBehaviorProfile,
) -> float:
    """
    Score based on response time compatibility.
    Similar response times = good. Very different = friction.
    Range: -5 to +8
    """
    diff = abs(a.avg_response_time_minutes - b.avg_response_time_minutes)

    if diff < 10:
        return 8.0   # Both fast or both slow = great match
    elif diff < 30:
        return 5.0   # Somewhat similar
    elif diff < 60:
        return 2.0   # Noticeable difference
    elif diff < 120:
        return -2.0  # Significant difference
    else:
        return -5.0  # One very fast, one very slow = friction


def _score_selectivity_signal(
    a: models.UserBehaviorProfile,
    b: models.UserBehaviorProfile,
) -> float:
    """
    Score based on selectivity patterns.
    Both being selective = higher quality matching potential.
    Range: -3 to +10
    """
    both_selective = a.selectivity > 0.6 and b.selectivity > 0.6
    both_casual = a.selectivity < 0.3 and b.selectivity < 0.3
    one_very_selective = (a.selectivity > 0.8 and b.selectivity < 0.2) or \
                         (b.selectivity > 0.8 and a.selectivity < 0.2)

    if both_selective:
        return 10.0  # Both picky = likely higher quality matches
    elif both_casual:
        return 2.0   # Both casual = fine, but less selective
    elif one_very_selective:
        return -3.0  # Very different dating styles
    else:
        return 4.0   # Moderate selectivity = neutral positive


def generate_behavioral_reasons(
    behavior_a: models.UserBehaviorProfile,
    behavior_b: models.UserBehaviorProfile,
    compatibility_score: float,
    mode: str = "dating",
) -> list:
    """
    Generate human-readable reasons based on behavioral compatibility.
    """
    reasons = []

    # Communication style
    msg_diff = abs(behavior_a.avg_message_length - behavior_b.avg_message_length)
    if msg_diff < 30:
        reasons.append("You have similar communication styles")

    # Conversation depth
    avg_depth = (behavior_a.conversation_depth + behavior_b.conversation_depth) / 2.0
    if avg_depth > 10:
        reasons.append("Both enjoy deep, meaningful conversations")

    # Activity level
    avg_activity = (behavior_a.sessions_per_week + behavior_b.sessions_per_week) / 2.0
    if avg_activity > 5:
        reasons.append("Both are actively engaged on the app")

    # Initiator balance
    diff = abs(behavior_a.initiator_ratio - behavior_b.initiator_ratio)
    if 0.15 < diff < 0.55:
        reasons.append("Complementary conversation dynamics")

    # Response time
    resp_diff = abs(behavior_a.avg_response_time_minutes - behavior_b.avg_response_time_minutes)
    if resp_diff < 15:
        reasons.append("Similar response time patterns")

    # Personality traits
    openness_diff = abs(behavior_a.openness_behavioral - behavior_b.openness_behavioral)
    if openness_diff < 15:
        reasons.append("Shared curiosity and open-mindedness")

    agreeableness_diff = abs(behavior_a.agreeableness_behavioral - behavior_b.agreeableness_behavioral)
    if agreeableness_diff < 15:
        reasons.append("Compatible emotional intelligence")

    # Selectivity
    if behavior_a.selectivity > 0.6 and behavior_b.selectivity > 0.6:
        reasons.append("Both are thoughtful and selective in matching")

    # Mode-specific
    if mode == "bff":
        if avg_depth > 8:
            reasons.append("Great potential for meaningful friendship")
        if avg_activity > 3:
            reasons.append("Both active - easy to stay connected")

    return reasons[:5]
