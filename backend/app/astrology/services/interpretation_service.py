import logging
from typing import Optional

from ..domain.models import (
    BirthData,
    WesternChart,
    VedicChart,
    SynastryResult,
    VedicCompatibilityResult,
    CompatibilityDimensions,
    InterpretationResult,
    AspectType,
    PlanetName,
)

logger = logging.getLogger(__name__)


class ChartInterpreter:
    """Service for generating structured interpretations from astrology data.

    Supports AI-powered interpretations (via OpenAI) with automatic fallback
    to rule-based templates if AI is unavailable or fails.
    """

    def __init__(self, ai_service=None):
        self.ai_service = ai_service

    def interpret_natal_chart(
        self,
        chart: WesternChart,
        vedic_chart: Optional[VedicChart] = None,
    ) -> dict:
        if self.ai_service:
            ai_result = self.ai_service.interpret_natal_chart(chart, vedic_chart)
            if ai_result:
                return ai_result

        return self._rule_based_natal_chart(chart, vedic_chart)

    def _rule_based_natal_chart(
        self,
        chart: WesternChart,
        vedic_chart: Optional[VedicChart] = None,
    ) -> dict:
        sun_sign = None
        moon_sign = None
        ascendant_sign = None

        for planet in chart.planets:
            if planet.planet == PlanetName.SUN:
                sun_sign = planet.sign.value
            elif planet.planet == PlanetName.MOON:
                moon_sign = planet.sign.value
            elif planet.planet == PlanetName.ASCENDANT:
                ascendant_sign = planet.sign.value

        strengths = []
        challenges = []

        for aspect in chart.aspects:
            if aspect.aspect == AspectType.TRINE:
                strengths.append(
                    f"{aspect.planet_a.value} trine {aspect.planet_b.value} "
                    f"(orb {aspect.orb}°) - natural harmony and ease"
                )
            elif aspect.aspect == AspectType.SEXTILE:
                strengths.append(
                    f"{aspect.planet_a.value} sextile {aspect.planet_b.value} "
                    f"(orb {aspect.orb}°) - opportunities for growth"
                )
            elif aspect.aspect == AspectType.SQUARE:
                challenges.append(
                    f"{aspect.planet_a.value} square {aspect.planet_b.value} "
                    f"(orb {aspect.orb}°) - tension and dynamic energy"
                )
            elif aspect.aspect == AspectType.OPPOSITION:
                challenges.append(
                    f"{aspect.planet_a.value} opposite {aspect.planet_b.value} "
                    f"(orb {aspect.orb}°) - polarity and integration needed"
                )

        retrograde_planets = [p for p in chart.planets if p.retrograde]

        return {
            "summary": (
                f"Sun in {sun_sign or 'unknown'}, "
                f"Moon in {moon_sign or 'unknown'}, "
                f"Ascendant in {ascendant_sign or 'unknown'}"
            ),
            "sun_sign": sun_sign,
            "moon_sign": moon_sign,
            "ascendant": ascendant_sign,
            "strengths": strengths,
            "challenges": challenges,
            "retrograde_planets": [p.planet.value for p in retrograde_planets],
            "total_aspects": len(chart.aspects),
            "trines": len([a for a in chart.aspects if a.aspect == AspectType.TRINE]),
            "squares": len([a for a in chart.aspects if a.aspect == AspectType.SQUARE]),
        }

    def interpret_synastry(
        self,
        synastry: SynastryResult,
        vedic_compatibility: Optional[VedicCompatibilityResult] = None,
        dimensions: Optional[CompatibilityDimensions] = None,
    ) -> InterpretationResult:
        if self.ai_service:
            ai_result = self.ai_service.interpret_synastry(
                synastry, vedic_compatibility, dimensions
            )
            if ai_result:
                return ai_result

        return self._rule_based_synastry(synastry, vedic_compatibility, dimensions)

    def _rule_based_synastry(
        self,
        synastry: SynastryResult,
        vedic_compatibility: Optional[VedicCompatibilityResult] = None,
        dimensions: Optional[CompatibilityDimensions] = None,
    ) -> InterpretationResult:
        strengths = []
        challenges = []

        for conj in synastry.conjunctions:
            strengths.append(
                f"{conj.planet_a.value}-{conj.planet_b.value} conjunction "
                f"in {conj.sign_a.value}/{conj.sign_b.value} "
                f"- strong natural connection"
            )

        for trine in synastry.trines:
            strengths.append(
                f"{trine.planet_a.value}-{trine.planet_b.value} trine "
                f"- harmonic flow between energies"
            )

        for square in synastry.squares:
            challenges.append(
                f"{square.planet_a.value}-{square.planet_b.value} square "
                f"- areas of tension requiring work"
            )

        for opp in synastry.oppositions:
            challenges.append(
                f"{opp.planet_a.value}-{opp.planet_b.value} opposition "
                f"- polarity that can create growth"
            )

        communication_parts = []
        for aspect in synastry.planet_aspects:
            if PlanetName.MERCURY in (aspect.planet_a, aspect.planet_b):
                communication_parts.append(
                    f"{aspect.planet_a.value}-{aspect.planet_b.value} "
                    f"({aspect.aspect.value}) - "
                    + self._communication_interpretation(aspect.aspect)
                )

        emotional_parts = []
        for aspect in synastry.planet_aspects:
            if PlanetName.MOON in (aspect.planet_a, aspect.planet_b):
                emotional_parts.append(
                    f"{aspect.planet_a.value}-{aspect.planet_b.value} "
                    f"({aspect.aspect.value}) - "
                    + self._emotional_interpretation(aspect.aspect)
                )

        return InterpretationResult(
            summary=self._generate_summary(synastry, dimensions),
            strengths=strengths[:10],
            challenges=challenges[:10],
            communication=" ".join(communication_parts[:3]) if communication_parts else "No strong communication indicators",
            emotional_dynamic=" ".join(emotional_parts[:3]) if emotional_parts else "No strong emotional indicators",
            values=self._interpret_values(synastry),
            growth_dynamic=self._interpret_growth(synastry),
            important_aspects=[
                {
                    "planets": f"{a.planet_a.value}-{a.planet_b.value}",
                    "aspect": a.aspect.value,
                    "orb": a.orb,
                }
                for a in synastry.planet_aspects[:10]
            ],
        )

    def _generate_summary(
        self,
        synastry: SynastryResult,
        dimensions: Optional[CompatibilityDimensions],
    ) -> str:
        parts = []
        parts.append(f"Synastry analysis shows {len(synastry.planet_aspects)} inter-chart aspects.")

        if synastry.conjunctions:
            parts.append(f"{len(synastry.conjunctions)} conjunctions indicate strong natural connections.")
        if synastry.trines:
            parts.append(f"{len(synastry.trines)} trines suggest harmonic flow.")
        if synastry.squares:
            parts.append(f"{len(synastry.squares)} squares create dynamic tension for growth.")

        if dimensions:
            parts.append(f"Overall compatibility score: {dimensions.overall}/100.")

        return " ".join(parts)

    def _communication_interpretation(self, aspect: AspectType) -> str:
        interpretations = {
            AspectType.CONJUNCTION: "merged communication styles",
            AspectType.TRINE: "natural ease in expressing thoughts together",
            AspectType.SEXTILE: "opportunity to learn from different communication approaches",
            AspectType.SQUARE: "communication may require conscious effort and patience",
            AspectType.OPPOSITION: "different communication styles that can complement each other",
        }
        return interpretations.get(aspect, "")

    def _emotional_interpretation(self, aspect: AspectType) -> str:
        interpretations = {
            AspectType.CONJUNCTION: "deep emotional understanding and shared feelings",
            AspectType.TRINE: "natural emotional harmony and comfort",
            AspectType.SEXTILE: "emotional support and gentle understanding",
            AspectType.SQUARE: "emotional intensity that challenges both partners",
            AspectType.OPPOSITION: "emotional mirroring that promotes self-awareness",
        }
        return interpretations.get(aspect, "")

    def _interpret_values(self, synastry: SynastryResult) -> str:
        jupiter_aspects = [
            a for a in synastry.planet_aspects
            if PlanetName.JUPITER in (a.planet_a, a.planet_b)
        ]
        saturn_aspects = [
            a for a in synastry.planet_aspects
            if PlanetName.SATURN in (a.planet_a, a.planet_b)
        ]

        parts = []
        if jupiter_aspects:
            parts.append("Jupiter aspects suggest shared optimism and philosophical alignment.")
        if saturn_aspects:
            parts.append("Saturn aspects indicate shared sense of responsibility and structure.")
        if not parts:
            parts.append("Values alignment requires deeper exploration of individual charts.")

        return " ".join(parts)

    def _interpret_growth(self, synastry: SynastryResult) -> str:
        uranian_aspects = [
            a for a in synastry.planet_aspects
            if PlanetName.URANUS in (a.planet_a, a.planet_b)
        ]
        neptunian_aspects = [
            a for a in synastry.planet_aspects
            if PlanetName.NEPTUNE in (a.planet_a, a.planet_b)
        ]
        plutonian_aspects = [
            a for a in synastry.planet_aspects
            if PlanetName.PLUTO in (a.planet_a, a.planet_b)
        ]

        parts = []
        if uranian_aspects:
            parts.append("Uranus aspects bring excitement and potential for sudden change.")
        if neptunian_aspects:
            parts.append("Neptune aspects add spiritual depth and idealism.")
        if plutonian_aspects:
            parts.append("Pluto aspects indicate transformative power in the relationship.")

        if not parts:
            parts.append("Growth potential lies in the interplay of core planetary energies.")

        return " ".join(parts)
