import logging
from typing import Optional

from ..domain.models import (
    BirthData,
    WesternChart,
    SynastryResult,
    CompatibilityDimensions,
    AspectType,
)
from ..domain.provider import AstrologyProvider

logger = logging.getLogger(__name__)

DEFAULT_WEIGHTS = {
    "emotional": {
        ("Moon", "Moon", "conjunction"): 12, ("Moon", "Moon", "trine"): 15,
        ("Moon", "Moon", "sextile"): 8, ("Moon", "Moon", "opposition"): 5,
        ("Moon", "Sun", "conjunction"): 10, ("Moon", "Sun", "trine"): 12,
        ("Moon", "Sun", "sextile"): 7, ("Moon", "Sun", "opposition"): 4,
        ("Moon", "Venus", "conjunction"): 10, ("Moon", "Venus", "trine"): 12,
        ("Moon", "Venus", "sextile"): 7, ("Moon", "Venus", "opposition"): 4,
        ("Moon", "Mars", "conjunction"): 8, ("Moon", "Mars", "trine"): 9,
        ("Moon", "Mars", "sextile"): 6, ("Moon", "Mars", "square"): -4,
        ("Moon", "Jupiter", "conjunction"): 8, ("Moon", "Jupiter", "trine"): 10,
        ("Moon", "Jupiter", "sextile"): 6, ("Moon", "Saturn", "conjunction"): 5,
        ("Moon", "Saturn", "trine"): 7, ("Moon", "Saturn", "square"): -5,
        ("Moon", "Saturn", "opposition"): -4, ("Moon", "Neptune", "conjunction"): 7,
        ("Moon", "Neptune", "trine"): 9, ("Moon", "Neptune", "sextile"): 5,
        ("Moon", "Pluto", "conjunction"): 6, ("Moon", "Pluto", "trine"): 8,
        ("Moon", "Pluto", "square"): -3, ("Sun", "Sun", "conjunction"): 8,
        ("Sun", "Sun", "trine"): 8, ("Sun", "Sun", "sextile"): 5,
    },
    "communication": {
        ("Mercury", "Mercury", "conjunction"): 12, ("Mercury", "Mercury", "trine"): 15,
        ("Mercury", "Mercury", "sextile"): 8, ("Mercury", "Mercury", "opposition"): 4,
        ("Mercury", "Mercury", "square"): -4, ("Mercury", "Moon", "conjunction"): 10,
        ("Mercury", "Moon", "trine"): 12, ("Mercury", "Moon", "sextile"): 7,
        ("Mercury", "Moon", "opposition"): 3, ("Mercury", "Sun", "conjunction"): 8,
        ("Mercury", "Sun", "trine"): 10, ("Mercury", "Sun", "sextile"): 6,
        ("Mercury", "Venus", "conjunction"): 9, ("Mercury", "Venus", "trine"): 11,
        ("Mercury", "Venus", "sextile"): 7, ("Mercury", "Mars", "conjunction"): 6,
        ("Mercury", "Mars", "trine"): 7, ("Mercury", "Mars", "sextile"): 5,
        ("Mercury", "Mars", "square"): -3, ("Mercury", "Jupiter", "conjunction"): 7,
        ("Mercury", "Jupiter", "trine"): 9, ("Mercury", "Jupiter", "sextile"): 6,
        ("Mercury", "Saturn", "conjunction"): 4, ("Mercury", "Saturn", "trine"): 6,
        ("Mercury", "Saturn", "square"): -4, ("Mercury", "Uranus", "conjunction"): 6,
        ("Mercury", "Uranus", "trine"): 8, ("Mercury", "Uranus", "sextile"): 5,
        ("Mercury", "Neptune", "conjunction"): 5, ("Mercury", "Neptune", "trine"): 7,
        ("Mercury", "Pluto", "conjunction"): 5, ("Mercury", "Pluto", "trine"): 7,
    },
    "values": {
        ("Jupiter", "Jupiter", "conjunction"): 12, ("Jupiter", "Jupiter", "trine"): 12,
        ("Jupiter", "Jupiter", "sextile"): 8, ("Jupiter", "Jupiter", "square"): -4,
        ("Jupiter", "Jupiter", "opposition"): 3, ("Saturn", "Saturn", "conjunction"): 10,
        ("Saturn", "Saturn", "trine"): 10, ("Saturn", "Saturn", "sextile"): 7,
        ("Saturn", "Saturn", "square"): -5, ("Saturn", "Saturn", "opposition"): -4,
        ("Venus", "Venus", "conjunction"): 8, ("Venus", "Venus", "trine"): 10,
        ("Venus", "Venus", "sextile"): 6, ("Venus", "Venus", "opposition"): 3,
        ("Sun", "Sun", "conjunction"): 8, ("Sun", "Sun", "trine"): 8,
        ("Sun", "Sun", "sextile"): 5, ("Sun", "Jupiter", "conjunction"): 7,
        ("Sun", "Jupiter", "trine"): 9, ("Sun", "Jupiter", "sextile"): 6,
        ("Sun", "Saturn", "conjunction"): 4, ("Sun", "Saturn", "trine"): 6,
        ("Sun", "Saturn", "square"): -5, ("Venus", "Jupiter", "conjunction"): 7,
        ("Venus", "Jupiter", "trine"): 9, ("Venus", "Jupiter", "sextile"): 6,
        ("Venus", "Saturn", "conjunction"): 4, ("Venus", "Saturn", "trine"): 6,
        ("Venus", "Saturn", "square"): -4, ("Jupiter", "Saturn", "conjunction"): 3,
        ("Jupiter", "Saturn", "trine"): 10, ("Jupiter", "Saturn", "square"): -5,
        ("Jupiter", "Saturn", "opposition"): -3,
    },
    "attraction": {
        ("Venus", "Venus", "conjunction"): 15, ("Venus", "Venus", "trine"): 14,
        ("Venus", "Venus", "sextile"): 9, ("Venus", "Venus", "opposition"): 4,
        ("Venus", "Venus", "square"): -4, ("Mars", "Mars", "conjunction"): 12,
        ("Mars", "Mars", "trine"): 10, ("Mars", "Mars", "sextile"): 7,
        ("Mars", "Mars", "opposition"): 5, ("Mars", "Mars", "square"): -6,
        ("Venus", "Mars", "conjunction"): 14, ("Venus", "Mars", "trine"): 12,
        ("Venus", "Mars", "sextile"): 10, ("Venus", "Mars", "opposition"): 5,
        ("Venus", "Mars", "square"): -4, ("Sun", "Venus", "conjunction"): 10,
        ("Sun", "Venus", "trine"): 12, ("Sun", "Venus", "sextile"): 8,
        ("Sun", "Venus", "opposition"): 3, ("Sun", "Mars", "conjunction"): 9,
        ("Sun", "Mars", "trine"): 10, ("Sun", "Mars", "sextile"): 7,
        ("Sun", "Mars", "opposition"): 4, ("Moon", "Venus", "conjunction"): 10,
        ("Moon", "Venus", "trine"): 12, ("Moon", "Venus", "sextile"): 7,
        ("Moon", "Mars", "conjunction"): 8, ("Moon", "Mars", "trine"): 9,
        ("Moon", "Mars", "sextile"): 6, ("Mars", "Jupiter", "conjunction"): 6,
        ("Mars", "Jupiter", "trine"): 7, ("Mars", "Jupiter", "sextile"): 5,
        ("Mars", "Saturn", "conjunction"): -3, ("Mars", "Saturn", "square"): -8,
        ("Mars", "Saturn", "opposition"): -6, ("Mars", "Pluto", "conjunction"): 6,
        ("Mars", "Pluto", "trine"): 7, ("Venus", "Pluto", "conjunction"): 8,
        ("Venus", "Pluto", "trine"): 9, ("Venus", "Pluto", "square"): -3,
    },
    "conflict": {
        ("Mars", "Mars", "square"): -12, ("Mars", "Mars", "opposition"): -10,
        ("Mars", "Mars", "conjunction"): 3, ("Saturn", "Saturn", "square"): -8,
        ("Saturn", "Saturn", "opposition"): -7, ("Mars", "Saturn", "square"): -10,
        ("Mars", "Saturn", "opposition"): -8, ("Mars", "Saturn", "conjunction"): -3,
        ("Mars", "Uranus", "square"): -9, ("Mars", "Uranus", "opposition"): -7,
        ("Mars", "Uranus", "conjunction"): 2, ("Mars", "Neptune", "square"): -5,
        ("Mars", "Neptune", "opposition"): -4, ("Mars", "Pluto", "square"): -7,
        ("Mars", "Pluto", "opposition"): -6, ("Saturn", "Uranus", "square"): -6,
        ("Saturn", "Uranus", "opposition"): -5, ("Saturn", "Pluto", "square"): -5,
        ("Uranus", "Neptune", "square"): -3, ("Uranus", "Pluto", "square"): -4,
        ("Sun", "Mars", "square"): -4, ("Sun", "Saturn", "square"): -5,
        ("Sun", "Uranus", "square"): -4, ("Moon", "Mars", "square"): -4,
        ("Moon", "Saturn", "square"): -5, ("Moon", "Pluto", "square"): -3,
        ("Venus", "Mars", "square"): -4, ("Venus", "Saturn", "square"): -4,
        ("Venus", "Pluto", "square"): -3, ("Mercury", "Mars", "square"): -3,
        ("Mercury", "Saturn", "square"): -4, ("Mercury", "Uranus", "square"): -3,
    },
    "stability": {
        ("Saturn", "Saturn", "conjunction"): 15, ("Saturn", "Saturn", "trine"): 15,
        ("Saturn", "Saturn", "sextile"): 10, ("Saturn", "Saturn", "square"): -5,
        ("Saturn", "Saturn", "opposition"): -4, ("Sun", "Sun", "conjunction"): 10,
        ("Sun", "Sun", "trine"): 8, ("Sun", "Sun", "sextile"): 5,
        ("Jupiter", "Jupiter", "conjunction"): 8, ("Jupiter", "Jupiter", "trine"): 8,
        ("Jupiter", "Jupiter", "sextile"): 5, ("Sun", "Saturn", "conjunction"): 6,
        ("Sun", "Saturn", "trine"): 8, ("Sun", "Saturn", "sextile"): 5,
        ("Sun", "Saturn", "square"): -5, ("Moon", "Saturn", "conjunction"): 5,
        ("Moon", "Saturn", "trine"): 7, ("Moon", "Saturn", "sextile"): 4,
        ("Moon", "Saturn", "square"): -5, ("Venus", "Saturn", "conjunction"): 5,
        ("Venus", "Saturn", "trine"): 7, ("Venus", "Saturn", "sextile"): 4,
        ("Venus", "Saturn", "square"): -4, ("Mercury", "Saturn", "conjunction"): 4,
        ("Mercury", "Saturn", "trine"): 6, ("Mercury", "Saturn", "sextile"): 4,
        ("Mercury", "Saturn", "square"): -4, ("Jupiter", "Saturn", "trine"): 8,
        ("Jupiter", "Saturn", "conjunction"): 3, ("Jupiter", "Saturn", "square"): -5,
        ("Jupiter", "Saturn", "opposition"): -3,
    },
    "growth": {
        ("Saturn", "Saturn", "opposition"): 10, ("Saturn", "Saturn", "square"): 5,
        ("Jupiter", "Jupiter", "square"): 8, ("Jupiter", "Jupiter", "opposition"): 6,
        ("Uranus", "Uranus", "trine"): 7, ("Uranus", "Uranus", "conjunction"): 6,
        ("Uranus", "Uranus", "sextile"): 5, ("Saturn", "Uranus", "trine"): 8,
        ("Saturn", "Uranus", "conjunction"): 5, ("Saturn", "Uranus", "square"): -6,
        ("Jupiter", "Saturn", "trine"): 10, ("Jupiter", "Saturn", "conjunction"): 3,
        ("Jupiter", "Saturn", "square"): -5, ("Neptune", "Neptune", "trine"): 6,
        ("Neptune", "Neptune", "conjunction"): 5, ("Neptune", "Neptune", "sextile"): 4,
        ("Pluto", "Pluto", "trine"): 6, ("Pluto", "Pluto", "conjunction"): 5,
        ("Pluto", "Pluto", "sextile"): 4, ("Saturn", "Neptune", "trine"): 7,
        ("Saturn", "Neptune", "conjunction"): 4, ("Saturn", "Neptune", "square"): -4,
        ("Saturn", "Pluto", "trine"): 7, ("Saturn", "Pluto", "conjunction"): 4,
        ("Saturn", "Pluto", "square"): -5, ("Jupiter", "Uranus", "trine"): 8,
        ("Jupiter", "Uranus", "conjunction"): 6, ("Jupiter", "Neptune", "trine"): 8,
        ("Jupiter", "Neptune", "conjunction"): 6, ("Jupiter", "Pluto", "trine"): 7,
        ("Jupiter", "Pluto", "conjunction"): 5, ("Uranus", "Neptune", "trine"): 5,
        ("Uranus", "Pluto", "trine"): 6, ("Neptune", "Pluto", "trine"): 5,
        ("Neptune", "Pluto", "conjunction"): 4, ("Sun", "Uranus", "trine"): 5,
        ("Sun", "Uranus", "conjunction"): 4, ("Sun", "Neptune", "trine"): 5,
        ("Sun", "Neptune", "conjunction"): 4, ("Sun", "Pluto", "trine"): 5,
        ("Sun", "Pluto", "conjunction"): 4, ("Moon", "Uranus", "trine"): 5,
        ("Moon", "Uranus", "conjunction"): 4, ("Moon", "Neptune", "trine"): 6,
        ("Moon", "Neptune", "conjunction"): 5, ("Moon", "Pluto", "trine"): 5,
        ("Moon", "Pluto", "conjunction"): 4, ("Venus", "Uranus", "trine"): 5,
        ("Venus", "Uranus", "conjunction"): 4, ("Venus", "Neptune", "trine"): 6,
        ("Venus", "Neptune", "conjunction"): 5, ("Venus", "Pluto", "trine"): 6,
        ("Venus", "Pluto", "conjunction"): 5, ("Mercury", "Uranus", "trine"): 5,
        ("Mercury", "Uranus", "conjunction"): 4, ("Mercury", "Neptune", "trine"): 5,
        ("Mercury", "Neptune", "conjunction"): 4, ("Mercury", "Pluto", "trine"): 5,
        ("Mercury", "Pluto", "conjunction"): 4,
    },
}


class CompatibilityService:
    """Service for calculating compatibility dimensions from astrology data.

    Syno MUST own its scoring logic. This service consumes normalized
    astrology data and calculates dimension scores.
    """

    def __init__(self, provider: AstrologyProvider):
        self.provider = provider

    def calculate_compatibility(
        self,
        person_a: BirthData,
        person_b: BirthData,
    ) -> CompatibilityDimensions:
        synastry = self.provider.get_synastry(person_a, person_b)
        return self._calculate_from_synastry(synastry)

    def _calculate_from_synastry(self, synastry: SynastryResult) -> CompatibilityDimensions:
        scores = {
            "emotional": 50.0,
            "communication": 50.0,
            "values": 50.0,
            "attraction": 50.0,
            "conflict": 50.0,
            "stability": 50.0,
            "growth": 50.0,
        }

        aspect_scores = self._score_aspects(synastry)

        for dimension in scores:
            dimension_aspects = self._get_dimension_aspects(dimension)
            for aspect_key, base_weight in dimension_aspects.items():
                if aspect_key in aspect_scores:
                    scores[dimension] += base_weight * aspect_scores[aspect_key]

        for dimension in scores:
            scores[dimension] = max(0.0, min(100.0, scores[dimension]))

        overall = sum(scores.values()) / len(scores)

        return CompatibilityDimensions(
            emotional=round(scores["emotional"], 1),
            communication=round(scores["communication"], 1),
            values=round(scores["values"], 1),
            attraction=round(scores["attraction"], 1),
            conflict=round(scores["conflict"], 1),
            stability=round(scores["stability"], 1),
            growth=round(scores["growth"], 1),
            overall=round(overall, 1),
        )

    def _score_aspects(self, synastry: SynastryResult) -> dict:
        scores = {}
        all_aspects = synastry.conjunctions + synastry.oppositions + \
                      synastry.trines + synastry.squares + synastry.sextiles

        for aspect in all_aspects:
            key = self._aspect_to_key(aspect.planet_a, aspect.planet_b, aspect.aspect)
            if key:
                orb_score = 1.0 - (aspect.orb / 10.0)
                orb_score = max(0.0, min(1.0, orb_score))
                scores[key] = max(scores.get(key, 0), orb_score)

            key_rev = self._aspect_to_key(aspect.planet_b, aspect.planet_a, aspect.aspect)
            if key_rev:
                scores[key_rev] = max(scores.get(key_rev, 0), scores.get(key, 0))

        return scores

    def _aspect_to_key(self, planet_a, planet_b, aspect: AspectType) -> Optional[str]:
        return (planet_a.value, planet_b.value, aspect.value)

    def _get_dimension_aspects(self, dimension: str) -> dict:
        return DEFAULT_WEIGHTS.get(dimension, {})
