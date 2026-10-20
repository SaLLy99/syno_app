"""
Report service for SYNO.
Generates detailed compatibility reports using real astrology calculations.
Maps raw chart data to user-facing dimensions with interpretation text.

Scoring model (chart % + transparent parts):
  - `overall_score` (the headline %) IS the natal chart score - a real number
    computed from the inter-chart aspects, nothing else.
  - `score_parts` exposes every signal separately (chart / behaviour /
    interests) so the UI can show them side by side; a part with no real data
    is `null`, never a placeholder.
  - `composite_score` is the legacy weighted blend, kept for reference only.
"""
import logging
from typing import Optional, List, Dict, Any
from dataclasses import dataclass, field

from ..domain.models import (
    BirthData,
    WesternChart,
    SynastryResult,
    CompatibilityDimensions,
    AspectType,
    PlanetName,
    PlanetToPlanetAspect,
    HouseOverlay,
)
from ..domain.provider import AstrologyProvider
from ..services.compatibility_service import CompatibilityService
from ..services.interpretation_service import ChartInterpreter
from ..services.aspect_ranking import compute_top_aspects

logger = logging.getLogger(__name__)


@dataclass
class DimensionScore:
    score: float
    label: str
    description: str
    key_factors: List[str]


@dataclass
class SynastryBreakdown:
    moon_score: float
    mercury_score: float
    venus_mars_score: float
    nodes_score: float
    saturn_score: float


@dataclass
class BehaviorScore:
    activity: float
    profile_quality: float
    mutual_interest: float
    behavioral_compatibility: float
    combined: float


@dataclass
class CompatibilityReport:
    overall_score: float
    chart_score: float
    behavior_score: Optional[float]
    profile_similarity_score: Optional[float]
    cosmic_insight: str
    top_reasons: List[str]

    dimensions: Dict[str, DimensionScore]
    synastry_breakdown: SynastryBreakdown
    shared: Dict[str, List[str]]
    profiles: Dict[str, Dict[str, Any]]

    interpretation: Dict[str, str]
    strengths: List[str]
    challenges: List[str]

    # Transparent breakdown + what is driving the headline number.
    score_parts: List[Dict[str, Any]] = field(default_factory=list)
    top_aspects: List[Dict[str, Any]] = field(default_factory=list)
    score_partial: bool = False
    composite_score: Optional[float] = None


# Aspect scoring weights per planet pair type
ROMANCE_WEIGHTS = {
    ("Venus", "Mars"): {"conjunction": 18, "trine": 14, "sextile": 10, "square": -8, "opposition": -5},
    ("Venus", "Sun"): {"conjunction": 15, "trine": 12, "sextile": 8, "square": -6, "opposition": -4},
    ("Venus", "Moon"): {"conjunction": 14, "trine": 11, "sextile": 7, "square": -5, "opposition": -3},
    ("Mars", "Sun"): {"conjunction": 12, "trine": 10, "sextile": 6, "square": -7, "opposition": -4},
    ("Mars", "Moon"): {"conjunction": 10, "trine": 8, "sextile": 5, "square": -6, "opposition": -3},
}

EMOTIONAL_WEIGHTS = {
    ("Moon", "Moon"): {"conjunction": 18, "trine": 14, "sextile": 10, "square": -8, "opposition": -5},
    ("Moon", "Sun"): {"conjunction": 15, "trine": 12, "sextile": 8, "square": -6, "opposition": -4},
    ("Moon", "Venus"): {"conjunction": 14, "trine": 11, "sextile": 7, "square": -5, "opposition": -3},
    ("Moon", "Neptune"): {"conjunction": 10, "trine": 8, "sextile": 5, "square": -4, "opposition": -3},
    ("Moon", "Pluto"): {"conjunction": 12, "trine": 9, "sextile": 6, "square": -5, "opposition": -4},
}

COMMUNICATION_WEIGHTS = {
    ("Mercury", "Mercury"): {"conjunction": 16, "trine": 12, "sextile": 8, "square": -6, "opposition": -4},
    ("Mercury", "Sun"): {"conjunction": 14, "trine": 11, "sextile": 7, "square": -5, "opposition": -3},
    ("Mercury", "Moon"): {"conjunction": 12, "trine": 10, "sextile": 6, "square": -5, "opposition": -3},
    ("Mercury", "Jupiter"): {"conjunction": 10, "trine": 8, "sextile": 5, "square": -4, "opposition": -2},
    ("Mercury", "Venus"): {"conjunction": 11, "trine": 9, "sextile": 6, "square": -4, "opposition": -2},
}

LONG_TERM_WEIGHTS = {
    ("Saturn", "Sun"): {"conjunction": 10, "trine": 14, "sextile": 10, "square": -10, "opposition": -8},
    ("Saturn", "Moon"): {"conjunction": 8, "trine": 12, "sextile": 8, "square": -9, "opposition": -7},
    ("Saturn", "Venus"): {"conjunction": 9, "trine": 13, "sextile": 9, "square": -8, "opposition": -6},
    ("Saturn", "Saturn"): {"conjunction": 12, "trine": 10, "sextile": 7, "square": -5, "opposition": -4},
    ("Jupiter", "Saturn"): {"conjunction": 8, "trine": 10, "sextile": 6, "square": -4, "opposition": -3},
}

MARRIAGE_WEIGHTS = {
    ("Saturn", "Sun"): {"conjunction": 12, "trine": 15, "sextile": 10, "square": -10, "opposition": -8},
    ("Saturn", "Moon"): {"conjunction": 10, "trine": 13, "sextile": 9, "square": -9, "opposition": -7},
    ("Saturn", "Venus"): {"conjunction": 11, "trine": 14, "sextile": 10, "square": -8, "opposition": -6},
    ("Jupiter", "Sun"): {"conjunction": 10, "trine": 12, "sextile": 8, "square": -4, "opposition": -3},
    ("Venus", "Venus"): {"conjunction": 14, "trine": 11, "sextile": 7, "square": -5, "opposition": -3},
}

FRIENDSHIP_WEIGHTS = {
    ("Mercury", "Mercury"): {"conjunction": 14, "trine": 12, "sextile": 8, "square": -5, "opposition": -3},
    ("Mercury", "Sun"): {"conjunction": 12, "trine": 10, "sextile": 7, "square": -4, "opposition": -2},
    ("Moon", "Moon"): {"conjunction": 12, "trine": 10, "sextile": 7, "square": -5, "opposition": -3},
    ("Jupiter", "Mercury"): {"conjunction": 10, "trine": 8, "sextile": 5, "square": -3, "opposition": -2},
    ("Sun", "Sun"): {"conjunction": 10, "trine": 8, "sextile": 5, "square": -4, "opposition": -3},
}

CHEMISTRY_WEIGHTS = {
    ("Venus", "Mars"): {"conjunction": 18, "trine": 14, "sextile": 10, "square": -6, "opposition": -4},
    ("Mars", "Pluto"): {"conjunction": 14, "trine": 10, "sextile": 7, "square": -5, "opposition": -4},
    ("Venus", "Pluto"): {"conjunction": 15, "trine": 11, "sextile": 8, "square": -5, "opposition": -4},
    ("Moon", "Mars"): {"conjunction": 12, "trine": 9, "sextile": 6, "square": -5, "opposition": -3},
    ("Sun", "Mars"): {"conjunction": 11, "trine": 8, "sextile": 5, "square": -4, "opposition": -3},
}

SPIRITUAL_WEIGHTS = {
    ("Neptune", "Sun"): {"conjunction": 12, "trine": 14, "sextile": 9, "square": -6, "opposition": -4},
    ("Neptune", "Moon"): {"conjunction": 14, "trine": 12, "sextile": 8, "square": -5, "opposition": -3},
    ("Neptune", "Neptune"): {"conjunction": 10, "trine": 8, "sextile": 5, "square": -3, "opposition": -2},
    ("Pluto", "Sun"): {"conjunction": 10, "trine": 11, "sextile": 7, "square": -5, "opposition": -4},
    ("Pluto", "Moon"): {"conjunction": 12, "trine": 10, "sextile": 6, "square": -4, "opposition": -3},
}

# Moon/Mercury/Venus-Mars/Nodes/Saturn breakdown weights
SYNASTRY_MOON_WEIGHTS = {
    ("Moon", "Moon"): 20, ("Moon", "Sun"): 15, ("Moon", "Venus"): 14,
    ("Moon", "Neptune"): 10, ("Moon", "Pluto"): 12, ("Moon", "Jupiter"): 8,
}
SYNASTRY_MERCURY_WEIGHTS = {
    ("Mercury", "Mercury"): 20, ("Mercury", "Sun"): 15, ("Mercury", "Moon"): 14,
    ("Mercury", "Venus"): 10, ("Mercury", "Jupiter"): 12, ("Mercury", "Saturn"): 8,
}
SYNASTRY_VENUS_MARS_WEIGHTS = {
    ("Venus", "Mars"): 20, ("Venus", "Venus"): 15, ("Mars", "Mars"): 14,
    ("Venus", "Sun"): 12, ("Mars", "Sun"): 10, ("Venus", "Pluto"): 10,
}
SYNASTRY_NODES_WEIGHTS = {
    ("Sun", "Moon"): 15, ("Sun", "Sun"): 12, ("Moon", "Moon"): 14,
    ("Saturn", "Saturn"): 10, ("Neptune", "Neptune"): 8, ("Pluto", "Pluto"): 10,
}
SYNASTRY_SATURN_WEIGHTS = {
    ("Saturn", "Saturn"): 20, ("Saturn", "Sun"): 15, ("Saturn", "Moon"): 14,
    ("Saturn", "Venus"): 12, ("Saturn", "Jupiter"): 10, ("Saturn", "Mars"): 8,
}

DIMENSION_LABELS = {
    "romance": ("Romance", "Chemistry and romantic spark between you"),
    "emotional": ("Emotional Connection", "How deeply you feel for each other"),
    "communication": ("Communication", "How well you understand and talk to each other"),
    "long_term": ("Long-Term Potential", "Whether this can stand the test of time"),
    "marriage": ("Marriage Compatibility", "Foundation for lasting commitment"),
    "friendship": ("Friendship Base", "The friendship foundation of your bond"),
    "chemistry": ("Physical Chemistry", "The magnetic pull between you"),
    "spiritual": ("Spiritual Connection", "Soul-level resonance and shared growth"),
}


class ReportService:
    """Generates detailed compatibility reports from real astrology data."""

    def __init__(self, provider: AstrologyProvider, interpreter: Optional[ChartInterpreter] = None, ai_service=None):
        self.provider = provider
        self.compat_service = CompatibilityService(provider)
        self.interpreter = interpreter or ChartInterpreter()
        self.ai_service = ai_service

    def generate_report(
        self,
        person_a: BirthData,
        person_b: BirthData,
        shared_hobbies: Optional[List[str]] = None,
        shared_values: Optional[List[str]] = None,
        shared_intentions: Optional[List[str]] = None,
        user_a_name: str = "",
        user_b_name: str = "",
        behavior_activity: float = 50.0,
        behavior_profile_quality: float = 50.0,
        behavior_mutual_interest: float = 0.0,
        behavioral_compatibility: float = 50.0,
        overall_score: Optional[float] = None,
        profile_similarity_score: Optional[float] = None,
        behavior_score: Optional[float] = None,
        behavior_has_data: bool = True,
        profile_has_data: bool = True,
        score_partial: bool = False,
        composite_score: Optional[float] = None,
        chart_weight: float = 0.60,
        behavior_weight: float = 0.30,
        profile_weight: float = 0.10,
    ) -> CompatibilityReport:
        synastry = self.provider.get_synastry(person_a, person_b)
        dimensions = self.compat_service.calculate_compatibility(person_a, person_b)

        chart_score = dimensions.overall

        behavior = self._calculate_behavior_score(
            behavior_activity, behavior_profile_quality,
            behavior_mutual_interest, behavioral_compatibility,
        )
        if behavior_score is not None:
            behavior = BehaviorScore(
                activity=behavior.activity,
                profile_quality=behavior.profile_quality,
                mutual_interest=behavior.mutual_interest,
                behavioral_compatibility=behavior.behavioral_compatibility,
                combined=max(0.0, min(100.0, behavior_score)),
            )

        profile_sim = self._calculate_profile_similarity(
            shared_hobbies, shared_values, shared_intentions
        )
        if profile_similarity_score is not None:
            profile_sim = max(0.0, min(100.0, profile_similarity_score))

        # Composition weights are only used for the legacy `composite_score`;
        # the headline number below is the chart score on its own.
        weight_total = chart_weight + behavior_weight + profile_weight
        if weight_total <= 0:
            chart_weight, behavior_weight, profile_weight = 0.60, 0.30, 0.10
        else:
            chart_weight /= weight_total
            behavior_weight /= weight_total
            profile_weight /= weight_total

        # Headline % = real natal-chart score. Callers may override, but never
        # with a weighted average - the parts are shown separately instead.
        if overall_score is not None:
            overall = max(0.0, min(100.0, overall_score))
        else:
            overall = chart_score

        if behavior_has_data:
            behavior_value = round(max(0.0, min(100.0, behavior.combined)))
            behavior_combined: Optional[float] = behavior.combined
        else:
            # No observed behaviour: the part is null, not a placeholder number.
            behavior_value = None
            behavior_combined = None

        # No comparable interests/values on both profiles: the part is null,
        # not a neutral number.
        profile_value: Optional[float] = (
            round(max(0.0, min(100.0, profile_sim))) if profile_has_data else None
        )

        signals = [(chart_score, chart_weight)]
        if behavior_combined is not None:
            signals.append((behavior_combined, behavior_weight))
        if profile_value is not None:
            signals.append((profile_sim, profile_weight))
        signal_total = sum(weight for _, weight in signals) or 1.0
        computed_composite = sum(score * weight for score, weight in signals) / signal_total
        composite = computed_composite if composite_score is None else composite_score

        score_parts = [
            {
                "key": "chart",
                "label": "Natal chart",
                "value": round(chart_score),
                "partial": bool(score_partial),
            },
            {
                "key": "behavior",
                "label": "Behaviour",
                "value": behavior_value,
                "partial": False,
            },
            {
                "key": "profile",
                "label": "Interests & values",
                "value": profile_value,
                "partial": False,
            },
        ]

        aspect_rows = [
            {
                "planet_a": aspect.planet_a.value,
                "planet_b": aspect.planet_b.value,
                "aspect": aspect.aspect.value,
                "orb": round(aspect.orb, 1),
                "sign_a": aspect.sign_a.value,
                "sign_b": aspect.sign_b.value,
            }
            for aspect in synastry.planet_aspects
        ]
        top_aspects = compute_top_aspects(aspect_rows, limit=5)

        dim_scores = self._calculate_all_dimensions(synastry)

        synastry_breakdown = self._calculate_synastry_breakdown(synastry)

        cosmic_insight = self._generate_cosmic_insight_ai(
            synastry, dimensions, overall,
            person_a_name=user_a_name, person_b_name=user_b_name,
        ) or self._generate_cosmic_insight(overall, dim_scores)
        top_reasons = self._generate_top_reasons_ai(
            synastry, dimensions, shared_hobbies, shared_values,
            person_a_name=user_a_name, person_b_name=user_b_name,
        ) or self._generate_top_reasons(dim_scores, shared_hobbies, shared_values, shared_intentions)

        interpretation = self._generate_interpretation(
            synastry, dim_scores,
            person_a_name=user_a_name, person_b_name=user_b_name,
            chart_dimensions=dimensions,
        )

        return CompatibilityReport(
            overall_score=round(overall),
            chart_score=round(chart_score),
            behavior_score=behavior_value,
            profile_similarity_score=profile_value,
            cosmic_insight=cosmic_insight,
            top_reasons=top_reasons,
            dimensions=dim_scores,
            synastry_breakdown=synastry_breakdown,
            shared={
                "hobbies": shared_hobbies or [],
                "values": shared_values or [],
                "intentions": shared_intentions or [],
            },
            profiles={
                "user_a": {"name": user_a_name, "zodiac": self._get_sun_sign(synastry.person_a_chart)},
                "user_b": {"name": user_b_name, "zodiac": self._get_sun_sign(synastry.person_b_chart)},
            },
            interpretation=interpretation,
            strengths=interpretation.get("strengths", []),
            challenges=interpretation.get("challenges", []),
            score_parts=score_parts,
            top_aspects=top_aspects,
            score_partial=bool(score_partial),
            composite_score=round(composite) if composite is not None else None,
        )

    def _calculate_behavior_score(
        self, activity: float, profile_quality: float,
        mutual_interest: float, behavioral_compatibility: float = 50.0,
    ) -> BehaviorScore:
        """
        Calculate combined behavior score.
        Now includes behavioral compatibility as the primary factor.
        """
        # Primary: behavioral compatibility (60% of behavior score)
        # Secondary: activity + profile quality + mutual interest (40% of behavior score)
        supplementary = (activity * 0.40) + (profile_quality * 0.35) + (mutual_interest * 0.25)
        combined = (behavioral_compatibility * 0.60) + (supplementary * 0.40)

        return BehaviorScore(
            activity=activity,
            profile_quality=profile_quality,
            mutual_interest=mutual_interest,
            behavioral_compatibility=behavioral_compatibility,
            combined=combined,
        )

    def _calculate_profile_similarity(
        self,
        shared_hobbies: Optional[List[str]],
        shared_values: Optional[List[str]],
        shared_intentions: Optional[List[str]],
    ) -> float:
        score = 50.0
        if shared_hobbies:
            score += min(len(shared_hobbies) * 5, 20)
        if shared_values:
            score += min(len(shared_values) * 5, 20)
        if shared_intentions:
            score += min(len(shared_intentions) * 5, 10)
        return min(score, 100.0)

    def _calculate_all_dimensions(self, synastry: SynastryResult) -> Dict[str, DimensionScore]:
        return {
            "romance": self._score_dimension(synastry, ROMANCE_WEIGHTS, "romance"),
            "emotional": self._score_dimension(synastry, EMOTIONAL_WEIGHTS, "emotional"),
            "communication": self._score_dimension(synastry, COMMUNICATION_WEIGHTS, "communication"),
            "long_term": self._score_dimension(synastry, LONG_TERM_WEIGHTS, "long_term"),
            "marriage": self._score_dimension(synastry, MARRIAGE_WEIGHTS, "marriage"),
            "friendship": self._score_dimension(synastry, FRIENDSHIP_WEIGHTS, "friendship"),
            "chemistry": self._score_dimension(synastry, CHEMISTRY_WEIGHTS, "chemistry"),
            "spiritual": self._score_dimension(synastry, SPIRITUAL_WEIGHTS, "spiritual"),
        }

    def _score_dimension(
        self, synastry: SynastryResult, weights: dict, dimension: str
    ) -> DimensionScore:
        score = 50.0
        key_factors = []

        all_aspects = (
            synastry.conjunctions + synastry.oppositions +
            synastry.trines + synastry.squares + synastry.sextiles
        )

        for aspect in all_aspects:
            pair = self._normalize_pair(aspect.planet_a.value, aspect.planet_b.value)
            aspect_key = aspect.aspect.value

            if pair in weights and aspect_key in weights[pair]:
                weight = weights[pair][aspect_key]
                orb_factor = max(0.3, 1.0 - (aspect.orb / 15.0))
                contribution = weight * orb_factor
                score += contribution

                if abs(weight) >= 8:
                    direction = "+" if weight > 0 else ""
                    factor_text = (
                        f"{aspect.planet_a.value}-{aspect.planet_b.value} "
                        f"{aspect.aspect.value} (orb {aspect.orb:.1f}deg) "
                        f"{direction}{weight:.0f}"
                    )
                    key_factors.append(factor_text)

        score = max(0.0, min(100.0, score))
        label, description = DIMENSION_LABELS.get(dimension, (dimension, ""))

        return DimensionScore(
            score=round(score),
            label=label,
            description=description,
            key_factors=key_factors[:5],
        )

    def _normalize_pair(self, planet_a: str, planet_b: str) -> tuple:
        order = sorted([planet_a, planet_b])
        return (order[0], order[1])

    def _calculate_synastry_breakdown(self, synastry: SynastryResult) -> SynastryBreakdown:
        all_aspects = (
            synastry.conjunctions + synastry.oppositions +
            synastry.trines + synastry.squares + synastry.sextiles
        )

        moon_score = self._score_group(all_aspects, SYNASTRY_MOON_WEIGHTS)
        mercury_score = self._score_group(all_aspects, SYNASTRY_MERCURY_WEIGHTS)
        venus_mars_score = self._score_group(all_aspects, SYNASTRY_VENUS_MARS_WEIGHTS)
        nodes_score = self._score_group(all_aspects, SYNASTRY_NODES_WEIGHTS)
        saturn_score = self._score_group(all_aspects, SYNASTRY_SATURN_WEIGHTS)

        return SynastryBreakdown(
            moon_score=round(moon_score),
            mercury_score=round(mercury_score),
            venus_mars_score=round(venus_mars_score),
            nodes_score=round(nodes_score),
            saturn_score=round(saturn_score),
        )

    def _score_group(self, all_aspects: List[PlanetToPlanetAspect], weights: dict) -> float:
        score = 50.0
        for aspect in all_aspects:
            pair = self._normalize_pair(aspect.planet_a.value, aspect.planet_b.value)
            aspect_key = aspect.aspect.value
            if pair in weights:
                weight = weights[pair]
                if isinstance(weight, dict):
                    if aspect_key in weight:
                        orb_factor = max(0.3, 1.0 - (aspect.orb / 15.0))
                        score += weight[aspect_key] * orb_factor
                else:
                    aspect_bonus = {
                        "conjunction": 1.0, "trine": 0.8, "sextile": 0.6,
                        "square": -0.5, "opposition": -0.4,
                    }
                    bonus = aspect_bonus.get(aspect_key, 0)
                    if bonus != 0:
                        orb_factor = max(0.3, 1.0 - (aspect.orb / 15.0))
                        score += weight * bonus * orb_factor
        return max(0.0, min(100.0, score))

    def _get_sun_sign(self, chart: Optional[WesternChart]) -> Optional[str]:
        if not chart:
            return None
        for planet in chart.planets:
            if planet.planet == PlanetName.SUN:
                return planet.sign.value
        return None

    def _generate_cosmic_insight(self, score: float, dimensions: Dict[str, DimensionScore]) -> str:
        strongest = max(dimensions.values(), key=lambda d: d.score)
        weakest = min(dimensions.values(), key=lambda d: d.score)

        if score >= 85:
            return (
                f"A rare cosmic connection. Your strongest bond is {strongest.label.lower()} "
                f"({strongest.score}/100). The stars have aligned in a truly special way."
            )
        elif score >= 70:
            return (
                f"Strong potential between you. {strongest.label} stands out at {strongest.score}/100. "
                f"With attention to {weakest.label.lower()}, this bond can flourish."
            )
        elif score >= 55:
            return (
                f"An interesting cosmic connection with room for discovery. "
                f"Your {strongest.label.lower()} ({strongest.score}/100) is a solid foundation."
            )
        else:
            return (
                f"Opposite energies that can spark growth. "
                f"Your {strongest.label.lower()} ({strongest.score}/100) shows where you naturally connect."
            )

    def _generate_cosmic_insight_ai(
        self,
        synastry: SynastryResult,
        dimensions: CompatibilityDimensions,
        overall_score: float,
        person_a_name: str = "",
        person_b_name: str = "",
    ) -> Optional[str]:
        if not self.ai_service:
            return None
        try:
            return self.ai_service.generate_cosmic_insight(
                synastry, dimensions, overall_score,
                person_a_name=person_a_name, person_b_name=person_b_name,
            )
        except Exception as e:
            logger.warning(f"AI cosmic insight failed, using rule-based: {e}")
            return None

    def _generate_top_reasons_ai(
        self,
        synastry: SynastryResult,
        dimensions: CompatibilityDimensions,
        shared_hobbies: Optional[List[str]],
        shared_values: Optional[List[str]],
        person_a_name: str = "",
        person_b_name: str = "",
    ) -> Optional[List[str]]:
        if not self.ai_service:
            return None
        try:
            return self.ai_service.generate_top_reasons(
                synastry, dimensions, shared_hobbies, shared_values,
                person_a_name=person_a_name, person_b_name=person_b_name,
            )
        except Exception as e:
            logger.warning(f"AI top reasons failed, using rule-based: {e}")
            return None

    def _generate_top_reasons(
        self,
        dimensions: Dict[str, DimensionScore],
        shared_hobbies: Optional[List[str]],
        shared_values: Optional[List[str]],
        shared_intentions: Optional[List[str]],
    ) -> List[str]:
        reasons = []

        sorted_dims = sorted(dimensions.values(), key=lambda d: d.score, reverse=True)
        for dim in sorted_dims[:2]:
            if dim.score >= 65:
                reasons.append(f"Strong {dim.label.lower()} ({dim.score}/100)")

        if shared_hobbies:
            reasons.append(f"Shared interests: {', '.join(shared_hobbies[:3])}")
        if shared_values:
            reasons.append(f"Common values: {', '.join(shared_values[:3])}")
        if shared_intentions:
            reasons.append(f"Aligned goals: {', '.join(shared_intentions[:2])}")

        return reasons[:5]

    def _generate_interpretation(
        self,
        synastry: SynastryResult,
        dimensions: Dict[str, DimensionScore],
        person_a_name: str = "",
        person_b_name: str = "",
        chart_dimensions: Optional[CompatibilityDimensions] = None,
    ) -> Dict[str, str]:
        result = self.interpreter.interpret_synastry(
            synastry,
            dimensions=chart_dimensions,
            person_a_name=person_a_name,
            person_b_name=person_b_name,
        )

        coach_tips = list(result.coach_tips or [])
        if not coach_tips:
            coach_tips = self._fallback_coach_tips(dimensions, person_a_name, person_b_name)

        interpretation = {
            "summary": result.summary,
            "communication": result.communication,
            "emotional_dynamic": result.emotional_dynamic,
            "values": result.values,
            "growth_dynamic": result.growth_dynamic,
            "strengths": result.strengths,
            "challenges": result.challenges,
            "personality_a": result.personality_a,
            "personality_b": result.personality_b,
            "love_language": result.love_language,
            "trust_loyalty": result.trust_loyalty,
            "intimacy_text": result.intimacy_text,
            "conflict_style": result.conflict_style,
            "overall_verdict": result.overall_verdict,
            "coach_tips": coach_tips,
        }

        for dim_key, dim_score in dimensions.items():
            if dim_score.score >= 75:
                interpretation[f"{dim_key}_text"] = (
                    f"Your {dim_score.label.lower()} is exceptional ({dim_score.score}/100). "
                    f"{dim_score.description}."
                )
            elif dim_score.score >= 60:
                interpretation[f"{dim_key}_text"] = (
                    f"Your {dim_score.label.lower()} is strong ({dim_score.score}/100). "
                    f"{dim_score.description}."
                )
            elif dim_score.score >= 45:
                interpretation[f"{dim_key}_text"] = (
                    f"Your {dim_score.label.lower()} has potential ({dim_score.score}/100). "
                    f"{dim_score.description}."
                )
            else:
                interpretation[f"{dim_key}_text"] = (
                    f"Your {dim_score.label.lower()} needs attention ({dim_score.score}/100). "
                    f"{dim_score.description}."
                )

        return interpretation

    def _fallback_coach_tips(
        self,
        dimensions: Dict[str, DimensionScore],
        name_a: str = "",
        name_b: str = "",
    ) -> List[str]:
        """Dimension-driven coaching tips when no richer interpretation exists."""
        sorted_dims = sorted(dimensions.values(), key=lambda d: d.score)
        weakest = sorted_dims[0] if sorted_dims else None
        strongest = sorted_dims[-1] if sorted_dims else None

        tips: List[str] = []
        if weakest and weakest.score < 60:
            tips.append(
                f"Focus this month on {weakest.label.lower()} ({weakest.score}/100): "
                f"one small, repeated action beats a big gesture."
            )
        if strongest and strongest.score >= 60:
            tips.append(
                f"Lean on your {strongest.label.lower()} ({strongest.score}/100) as the "
                f"foundation when you work on harder areas."
            )
        tips.append(
            "Do a weekly 20-minute check-in: one appreciation, one irritation, one plan."
        )
        tips.append(
            "Name the repair move after a fight - a quick hug or callback joke shortens tension."
        )
        tips.append(
            "Alternate who plans the next date so novelty never depends on one person."
        )
        return tips[:6]

    def report_to_dict(self, report: CompatibilityReport) -> dict:
        return {
            "overall_score": report.overall_score,
            "chart_score": report.chart_score,
            "behavior_score": report.behavior_score,
            "profile_similarity_score": report.profile_similarity_score,
            "composite_score": report.composite_score,
            "score_partial": report.score_partial,
            "score_parts": report.score_parts,
            "top_aspects": report.top_aspects,
            "cosmic_insight": report.cosmic_insight,
            "top_reasons": report.top_reasons,
            "dimensions": {
                key: {
                    "score": dim.score,
                    "label": dim.label,
                    "description": dim.description,
                    "key_factors": dim.key_factors,
                }
                for key, dim in report.dimensions.items()
            },
            "synastry": {
                "moon": report.synastry_breakdown.moon_score,
                "mercury": report.synastry_breakdown.mercury_score,
                "venus_mars": report.synastry_breakdown.venus_mars_score,
                "nodes": report.synastry_breakdown.nodes_score,
                "saturn": report.synastry_breakdown.saturn_score,
            },
            "shared": report.shared,
            "profiles": report.profiles,
            "interpretation": report.interpretation,
            "score_breakdown": {
                "chart": report.chart_score,
                "behavior": report.behavior_score,
                "profile_similarity": report.profile_similarity_score,
            },
        }
