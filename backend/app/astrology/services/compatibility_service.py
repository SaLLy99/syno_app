import logging
from typing import Optional

from ..domain.models import (
    BirthData,
    WesternChart,
    VedicChart,
    SynastryResult,
    VedicCompatibilityResult,
    CompatibilityDimensions,
    AspectType,
)
from ..domain.provider import AstrologyProvider

logger = logging.getLogger(__name__)

DEFAULT_WEIGHTS = {
    "emotional": {"moon_trine": 15, "moon_conj": 12, "venus_trine": 10, "venus_conj": 8},
    "communication": {"mercury_trine": 15, "mercury_conj": 12, "mercury_sextile": 8},
    "values": {"jupiter_trine": 12, "saturn_trine": 10, "venus_trine": 8},
    "attraction": {"venus_conj": 15, "mars_conj": 12, "venus_mars_sextile": 10},
    "conflict": {"mars_square": -12, "mars_opposition": -10, "saturn_square": -8},
    "stability": {"saturn_trine": 15, "saturn_sextile": 10, "jupiter_trine": 8},
    "growth": {"saturn_opposition": 10, "jupiter_square": 8, "uranus_trine": 7},
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
        ayanamsa: str = "Lahiri",
    ) -> CompatibilityDimensions:
        synastry = self.provider.get_synastry(person_a, person_b)

        vedic_compatibility = None
        try:
            vedic_compatibility = self.provider.get_vedic_compatibility(
                person_a, person_b, ayanamsa
            )
        except NotImplementedError:
            logger.info("Vedic compatibility not available, using Western only")
        except Exception as e:
            logger.warning(f"Vedic compatibility failed: {e}")

        dimensions = self._calculate_from_synastry(synastry)

        if vedic_compatibility and vedic_compatibility.kuta_score is not None:
            self._apply_vedic_adjustments(dimensions, vedic_compatibility)

        return dimensions

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
                scores[key] = 1.0 - (aspect.orb / 10.0)
                scores[key] = max(0.0, min(1.0, scores[key]))

            key_rev = self._aspect_to_key(aspect.planet_b, aspect.planet_a, aspect.aspect)
            if key_rev:
                scores[key_rev] = scores.get(key, 0)

        return scores

    def _aspect_to_key(self, planet_a, planet_b, aspect: AspectType) -> Optional[str]:
        planet_order = sorted([planet_a.value, planet_b.value])
        aspect_name = aspect.value.replace("_", "")
        return f"{planet_order[0]}_{planet_order[1]}_{aspect_name}"

    def _get_dimension_aspects(self, dimension: str) -> dict:
        return DEFAULT_WEIGHTS.get(dimension, {})

    def _apply_vedic_adjustments(
        self,
        dimensions: CompatibilityDimensions,
        vedic: VedicCompatibilityResult,
    ):
        if vedic.kuta_score is None:
            return

        kuta_factor = vedic.kuta_score / 36.0
        adjustment = (kuta_factor - 0.5) * 10

        dimensions.emotional = max(0, min(100, dimensions.emotional + adjustment))
        dimensions.values = max(0, min(100, dimensions.values + adjustment))
        dimensions.overall = round(
            sum([
                dimensions.emotional,
                dimensions.communication,
                dimensions.values,
                dimensions.attraction,
                dimensions.conflict,
                dimensions.stability,
                dimensions.growth,
            ]) / 7, 1
        )
