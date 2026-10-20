"""
Rank the inter-chart aspects that drive a compatibility score.

Shared by the matching engine (discover cards) and the compatibility report so
both screens show the exact same "what's driving this score" list.
"""
from typing import List

# How much each aspect type contributes (standard synastry weights).
ASPECT_WEIGHTS = {
    "conjunction": 1.00,
    "opposition": 0.85,
    "square": 0.85,
    "trine": 0.75,
    "sextile": 0.55,
}

# How much each planet matters in a relationship reading.
PLANET_IMPORTANCE = {
    "sun": 1.0, "moon": 1.0, "venus": 0.9, "mars": 0.9, "mercury": 0.7,
    "jupiter": 0.6, "saturn": 0.6, "uranus": 0.4, "neptune": 0.4, "pluto": 0.4,
}


def compute_top_aspects(aspects: List[dict], limit: int = 5) -> List[dict]:
    """
    Score = planet importance x aspect weight x orb tightness.

    A 1.2 degree Venus-Mars conjunction outranks the same aspect at 7 degrees,
    which is what users see as "what's driving this score".
    """
    ranked: List[dict] = []
    for aspect in aspects:
        planet_a = str(aspect.get("planet_a", "")).lower()
        planet_b = str(aspect.get("planet_b", "")).lower()
        aspect_type = str(aspect.get("aspect", "")).lower()
        try:
            orb = float(aspect.get("orb") or 0.0)
        except (TypeError, ValueError):
            orb = 0.0

        planet_weight = max(
            PLANET_IMPORTANCE.get(planet_a, 0.3),
            PLANET_IMPORTANCE.get(planet_b, 0.3),
        )
        aspect_weight = ASPECT_WEIGHTS.get(aspect_type, 0.5)
        tightness = max(0.0, 1.0 - (min(orb, 8.0) / 8.0))
        score = round(100.0 * planet_weight * aspect_weight * (0.35 + 0.65 * tightness))

        ranked.append({**aspect, "score": score})

    ranked.sort(key=lambda item: (-item["score"], item.get("orb", 0.0)))
    return ranked[:limit]
