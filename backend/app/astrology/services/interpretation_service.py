import logging
from typing import Optional, List

from ..domain.models import (
    BirthData,
    WesternChart,
    SynastryResult,
    CompatibilityDimensions,
    InterpretationResult,
    AspectType,
    PlanetName,
    PlanetToPlanetAspect,
    HouseOverlay,
)

logger = logging.getLogger(__name__)

ASPECT_LABELS = {
    AspectType.CONJUNCTION: "conjunction",
    AspectType.TRINE: "trine",
    AspectType.SEXTILE: "sextile",
    AspectType.SQUARE: "square",
    AspectType.OPPOSITION: "opposition",
}

ASPECT_STRENGTH = {
    AspectType.CONJUNCTION: "intense",
    AspectType.TRINE: "harmonious",
    AspectType.SEXTILE: "supportive",
    AspectType.SQUARE: "challenging",
    AspectType.OPPOSITION: "polarizing",
}

PLANET_ROMANCE = {PlanetName.VENUS, PlanetName.MARS, PlanetName.SUN, PlanetName.MOON}
PLANET_EMOTIONAL = {PlanetName.MOON, PlanetName.NEPTUNE, PlanetName.PLUTO}
PLANET_COMMUNICATION = {PlanetName.MERCURY, PlanetName.URANUS}
PLANET_STRUCTURE = {PlanetName.SATURN, PlanetName.JUPITER}


class ChartInterpreter:
    """Service for generating structured interpretations from astrology data.

    Supports AI-powered interpretations (via OpenAI) with automatic fallback
    to rule-based templates if AI is unavailable or fails.
    """

    def __init__(self, ai_service=None):
        self.ai_service = ai_service
        self.last_used_ai = False

    def interpret_natal_chart(self, chart: WesternChart) -> dict:
        if self.ai_service:
            logger.info("Attempting AI-powered natal chart interpretation...")
            ai_result = self.ai_service.interpret_natal_chart(chart)
            if ai_result:
                logger.info("AI natal chart interpretation SUCCESS")
                return ai_result
            logger.warning("AI natal chart interpretation returned None — falling back to rules")

        logger.info("Using rule-based natal chart interpretation")
        return self._rule_based_natal_chart(chart)

    def _rule_based_natal_chart(self, chart: WesternChart) -> dict:
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
        dimensions: Optional[CompatibilityDimensions] = None,
        person_a_name: str = "",
        person_b_name: str = "",
    ) -> InterpretationResult:
        self.last_used_ai = False
        if self.ai_service:
            logger.info("Attempting AI-powered synastry interpretation...")
            ai_result = self.ai_service.interpret_synastry(
                synastry,
                dimensions=dimensions,
                person_a_name=person_a_name,
                person_b_name=person_b_name,
            )
            if ai_result:
                logger.info("AI interpretation SUCCESS — using AI-generated text")
                self.last_used_ai = True
                if not ai_result.coach_tips:
                    ai_result.coach_tips = self._build_coach_tips(
                        synastry, dimensions, person_a_name, person_b_name
                    )
                return ai_result
            logger.warning("AI interpretation returned None — falling back to rule-based")

        logger.info("Using rule-based synastry interpretation")
        return self._rule_based_synastry(synastry, dimensions, person_a_name, person_b_name)

    def _rule_based_synastry(
        self,
        synastry: SynastryResult,
        dimensions: Optional[CompatibilityDimensions] = None,
        person_a_name: str = "",
        person_b_name: str = "",
    ) -> InterpretationResult:
        all_aspects = (
            synastry.conjunctions + synastry.oppositions +
            synastry.trines + synastry.squares + synastry.sextiles
        )

        strengths = self._build_strengths(synastry.conjunctions, synastry.trines, synastry.sextiles)
        challenges = self._build_challenges(synastry.squares, synastry.oppositions)

        communication = self._build_communication(all_aspects)
        emotional = self._build_emotional(all_aspects)
        values = self._build_values(all_aspects, dimensions)
        growth = self._build_growth(all_aspects)

        name_a = (person_a_name or "").strip()
        name_b = (person_b_name or "").strip()

        personality_a = self._build_personality_a(synastry, name_a, name_b)
        personality_b = self._build_personality_b(synastry, name_a, name_b)
        love_language = self._build_love_language(all_aspects)
        trust_loyalty = self._build_trust_loyalty(all_aspects)
        intimacy = self._build_intimacy(all_aspects)
        conflict_style = self._build_conflict_style(all_aspects)
        verdict = self._build_verdict(synastry, dimensions, name_a, name_b)
        coach_tips = self._build_coach_tips(synastry, dimensions, name_a, name_b)

        important = [
            {
                "planets": f"{a.planet_a.value}-{a.planet_b.value}",
                "aspect": a.aspect.value,
                "orb": round(a.orb, 1),
                "sign_a": a.sign_a.value,
                "sign_b": a.sign_b.value,
            }
            for a in synastry.planet_aspects[:10]
        ]

        return InterpretationResult(
            summary=self._build_summary(synastry, dimensions),
            strengths=strengths,
            challenges=challenges,
            communication=communication,
            emotional_dynamic=emotional,
            values=values,
            growth_dynamic=growth,
            important_aspects=important,
            personality_a=personality_a,
            personality_b=personality_b,
            love_language=love_language,
            trust_loyalty=trust_loyalty,
            intimacy_text=intimacy,
            conflict_style=conflict_style,
            overall_verdict=verdict,
            coach_tips=coach_tips,
        )

    def _build_coach_tips(
        self,
        synastry: SynastryResult,
        dimensions: Optional[CompatibilityDimensions],
        name_a: str = "",
        name_b: str = "",
    ) -> List[str]:
        """Rule-based actionable coaching tips from aspects and dimensions."""
        you = "You"
        them = "your partner"
        if name_a and name_b:
            you, them = name_a, name_b

        all_aspects = (
            synastry.conjunctions + synastry.oppositions +
            synastry.trines + synastry.squares + synastry.sextiles
        )
        tips: List[str] = []

        mercury_square = any(
            PlanetName.MERCURY in (a.planet_a, a.planet_b) and a.aspect == AspectType.SQUARE
            for a in all_aspects
        )
        moon_tension = any(
            PlanetName.MOON in (a.planet_a, a.planet_b) and a.aspect in (AspectType.SQUARE, AspectType.OPPOSITION)
            for a in all_aspects
        )
        venus_mars = any(
            {a.planet_a, a.planet_b} == {PlanetName.VENUS, PlanetName.MARS}
            and a.aspect in (AspectType.SQUARE, AspectType.OPPOSITION)
            for a in all_aspects
        )
        saturn_contact = any(
            PlanetName.SATURN in (a.planet_a, a.planet_b)
            for a in all_aspects
        )
        outer_square = any(
            a.planet_a in (PlanetName.URANUS, PlanetName.NEPTUNE, PlanetName.PLUTO)
            or a.planet_b in (PlanetName.URANUS, PlanetName.NEPTUNE, PlanetName.PLUTO)
            for a in all_aspects
        ) and any(a.aspect in (AspectType.SQUARE, AspectType.OPPOSITION) for a in all_aspects)

        if mercury_square:
            tips.append(
                f"Pause before replying when a conversation heats up - "
                f"Mercury tension means {you} and {them} think at different speeds."
            )
        else:
            tips.append(
                f"Keep a shared note or voice memo for ideas - "
                f"easy Mercury flow is a strength worth protecting."
            )

        if moon_tension:
            tips.append(
                f"Check in about mood before problem-solving: "
                f"ask {them} 'do you need comfort or solutions?' first."
            )
        else:
            tips.append(
                f"Name one thing you appreciate about each other daily - "
                f"emotional ease here compounds fast."
            )

        if venus_mars:
            tips.append(
                f"Schedule regular date nights with novelty - "
                f"friction in attraction works best when it has a playful outlet."
            )
        else:
            tips.append(
                f"Keep initiating small physical affection - "
                f"romantic chemistry flows naturally for you two."
            )

        if saturn_contact:
            tips.append(
                f"Agree on one shared commitment each month - "
                f"Saturn contact rewards steady, kept promises."
            )

        if outer_square:
            tips.append(
                f"Give each other room for a solo interest or project - "
                f"outer-planet tension eases with healthy independence."
            )

        if dimensions:
            if dimensions.communication < 55:
                tips.append(
                    f"Communication scores {dimensions.communication:.0f}/100 - "
                    f"try a weekly 20-minute no-phone conversation."
                )
            if dimensions.conflict < 55:
                tips.append(
                    f"Conflict handling scores {dimensions.conflict:.0f}/100 - "
                    f"agree on a 20-minute cooling-off rule before returning to a disagreement."
                )
            if dimensions.emotional < 55:
                tips.append(
                    f"Emotional connection scores {dimensions.emotional:.0f}/100 - "
                    f"share one vulnerable feeling each week to build the habit."
                )
            if dimensions.stability >= 70:
                tips.append(
                    f"Stability is a bright spot ({dimensions.stability:.0f}/100) - "
                    f"use it as the base when you work on weaker areas."
                )

        return tips[:6]

    def _build_summary(
        self,
        synastry: SynastryResult,
        dimensions: Optional[CompatibilityDimensions],
    ) -> str:
        parts = []

        a_chart = synastry.person_a_chart
        b_chart = synastry.person_b_chart
        a_sun = self._get_sun_sign(a_chart)
        b_sun = self._get_sun_sign(b_chart)
        a_moon = self._get_moon_sign(a_chart)
        b_moon = self._get_moon_sign(b_chart)

        if a_sun and b_sun:
            parts.append(
                f"You are {a_sun} Sun with {a_moon or '?'} Moon, "
                f"they are {b_sun} Sun with {b_moon or '?'} Moon."
            )

        total = len(synastry.planet_aspects)
        conj_count = len(synastry.conjunctions)
        trine_count = len(synastry.trines)
        square_count = len(synastry.squares)
        opp_count = len(synastry.oppositions)

        parts.append(
            f"Your charts share {total} inter-chart aspects: "
            f"{conj_count} conjunctions, {trine_count} trines, "
            f"{square_count} squares, {opp_count} oppositions."
        )

        if dimensions:
            parts.append(f"Overall compatibility: {dimensions.overall}/100.")

        return " ".join(parts)

    def _build_strengths(
        self,
        conjunctions: List[PlanetToPlanetAspect],
        trines: List[PlanetToPlanetAspect],
        sextiles: List[PlanetToPlanetAspect],
    ) -> List[str]:
        items = []

        for c in conjunctions:
            label = ASPECT_STRENGTH.get(c.aspect, "")
            items.append(
                f"{c.planet_a.value} {c.aspect.value} {c.planet_b.value} "
                f"(orb {c.orb:.1f}°) in {c.sign_a.value}/{c.sign_b.value} - "
                f"{label} natural connection"
            )

        for t in trines:
            items.append(
                f"{t.planet_a.value} {t.aspect.value} {t.planet_b.value} "
                f"(orb {t.orb:.1f}°) in {t.sign_a.value}/{t.sign_b.value} - "
                f"harmonic flow between energies"
            )

        for s in sextiles:
            items.append(
                f"{s.planet_a.value} {s.aspect.value} {s.planet_b.value} "
                f"(orb {s.orb:.1f}°) in {s.sign_a.value}/{s.sign_b.value} - "
                f"opportunity for growth"
            )

        return items[:10]

    def _build_challenges(
        self,
        squares: List[PlanetToPlanetAspect],
        oppositions: List[PlanetToPlanetAspect],
    ) -> List[str]:
        items = []

        for sq in squares:
            items.append(
                f"{sq.planet_a.value} {sq.aspect.value} {sq.planet_b.value} "
                f"(orb {sq.orb:.1f}°) in {sq.sign_a.value}/{sq.sign_b.value} - "
                f"tension requiring conscious work"
            )

        for opp in oppositions:
            items.append(
                f"{opp.planet_a.value} {opp.aspect.value} {opp.planet_b.value} "
                f"(orb {opp.orb:.1f}°) in {opp.sign_a.value}/{opp.sign_b.value} - "
                f"polarity that can create growth through awareness"
            )

        return items[:10]

    def _build_communication(self, all_aspects: List[PlanetToPlanetAspect]) -> str:
        mercury_aspects = [
            a for a in all_aspects
            if PlanetName.MERCURY in (a.planet_a, a.planet_b)
        ]

        if not mercury_aspects:
            return (
                "No strong Mercury aspects between your charts. "
                "Communication styles are neutral - you'll need to explore "
                "how you each prefer to exchange ideas."
            )

        parts = []
        for a in mercury_aspects:
            other = a.planet_b if a.planet_a == PlanetName.MERCURY else a.planet_a
            interp = self._mercury_interp(a.aspect)
            parts.append(
                f"Mercury {a.aspect.value} {other.value} (orb {a.orb:.1f}°) "
                f"in {a.sign_a.value}/{a.sign_b.value}: {interp}"
            )

        return " ".join(parts)

    def _mercury_interp(self, aspect: AspectType) -> str:
        return {
            AspectType.CONJUNCTION: "Your thinking styles merge naturally - you finish each other's sentences.",
            AspectType.TRINE: "Ideas flow effortlessly between you - you understand each other's mental wavelength.",
            AspectType.SEXTILE: "You stimulate each other's thinking and can learn from different perspectives.",
            AspectType.SQUARE: "Communication requires patience - your thinking styles clash but can push you to articulate better.",
            AspectType.OPPOSITION: "You think in complementary ways - what one lacks, the other provides.",
        }.get(aspect, "")

    def _build_emotional(self, all_aspects: List[PlanetToPlanetAspect]) -> str:
        moon_aspects = [
            a for a in all_aspects
            if PlanetName.MOON in (a.planet_a, a.planet_b)
        ]

        if not moon_aspects:
            return (
                "No strong Moon aspects between your charts. "
                "Emotional attunement will develop through shared experiences "
                "rather than instinctive connection."
            )

        parts = []
        for a in moon_aspects:
            other = a.planet_b if a.planet_a == PlanetName.MOON else a.planet_a
            interp = self._moon_interp(a.aspect)
            parts.append(
                f"Moon {a.aspect.value} {other.value} (orb {a.orb:.1f}°) "
                f"in {a.sign_a.value}/{a.sign_b.value}: {interp}"
            )

        return " ".join(parts)

    def _moon_interp(self, aspect: AspectType) -> str:
        return {
            AspectType.CONJUNCTION: "Deep emotional mirror - you instinctively feel what the other feels.",
            AspectType.TRINE: "Emotional ease - you comfort and nurture each other naturally.",
            AspectType.SEXTILE: "Gentle emotional support - you bring out each other's tender side.",
            AspectType.SQUARE: "Emotional friction - your feelings can clash but this drives deeper understanding.",
            AspectType.OPPOSITION: "Emotional polarity - you mirror each other's inner needs, promoting growth.",
        }.get(aspect, "")

    def _build_values(
        self,
        all_aspects: List[PlanetToPlanetAspect],
        dimensions: Optional[CompatibilityDimensions],
    ) -> str:
        jupiter_aspects = [
            a for a in all_aspects
            if PlanetName.JUPITER in (a.planet_a, a.planet_b)
        ]
        saturn_aspects = [
            a for a in all_aspects
            if PlanetName.SATURN in (a.planet_a, a.planet_b)
        ]

        parts = []
        for a in jupiter_aspects:
            other = a.planet_b if a.planet_a == PlanetName.JUPITER else a.planet_a
            parts.append(
                f"Jupiter {a.aspect.value} {other.value} (orb {a.orb:.1f}°) "
                f"in {a.sign_a.value}/{a.sign_b.value} - "
                + self._jupiter_interp(a.aspect)
            )

        for a in saturn_aspects:
            other = a.planet_b if a.planet_a == PlanetName.SATURN else a.planet_a
            parts.append(
                f"Saturn {a.aspect.value} {other.value} (orb {a.orb:.1f}°) "
                f"in {a.sign_a.value}/{a.sign_b.value} - "
                + self._saturn_interp(a.aspect)
            )

        if not parts:
            parts.append(
                "Jupiter and Saturn have minimal contact between your charts. "
                "Values alignment will come from shared life experiences rather than "
                "innate philosophical resonance."
            )

        if dimensions:
            v = dimensions.values
            if v >= 75:
                parts.append(f"Your values compatibility scores {v}/100 - you share a similar worldview.")
            elif v >= 55:
                parts.append(f"Your values compatibility scores {v}/100 - mostly aligned with room for growth.")
            else:
                parts.append(f"Your values compatibility scores {v}/100 - different perspectives that can enrich each other.")

        return " ".join(parts)

    def _jupiter_interp(self, aspect: AspectType) -> str:
        return {
            AspectType.CONJUNCTION: "Shared optimism and philosophical alignment.",
            AspectType.TRINE: "Natural expansion of each other's beliefs and worldview.",
            AspectType.SEXTILE: "Opportunities to broaden horizons together.",
            AspectType.SQUARE: "Different philosophies that challenge you to refine your beliefs.",
            AspectType.OPPOSITION: "Opposing viewpoints that can balance each other's extremes.",
        }.get(aspect, "")

    def _saturn_interp(self, aspect: AspectType) -> str:
        return {
            AspectType.CONJUNCTION: "Shared sense of duty and long-term commitment.",
            AspectType.TRINE: "Mutual respect for structure and responsibility.",
            AspectType.SEXTILE: "Supportive discipline that helps you build together.",
            AspectType.SQUARE: "Areas where you challenge each other's boundaries and responsibilities.",
            AspectType.OPPOSITION: "Tension between caution and freedom that requires compromise.",
        }.get(aspect, "")

    def _build_growth(
        self,
        all_aspects: List[PlanetToPlanetAspect],
    ) -> str:
        outer_aspects = [
            a for a in all_aspects
            if a.planet_a in (PlanetName.URANUS, PlanetName.NEPTUNE, PlanetName.PLUTO)
            or a.planet_b in (PlanetName.URANUS, PlanetName.NEPTUNE, PlanetName.PLUTO)
        ]

        if not outer_aspects:
            return (
                "Your charts have minimal outer planet contact. "
                "Growth potential lies in everyday experiences and the "
                "gradual deepening of your connection."
            )

        parts = []
        for a in outer_aspects[:5]:
            other_planet = a.planet_b if a.planet_a in (PlanetName.URANUS, PlanetName.NEPTUNE, PlanetName.PLUTO) else a.planet_a
            outer = a.planet_a if a.planet_a in (PlanetName.URANUS, PlanetName.NEPTUNE, PlanetName.PLUTO) else a.planet_b
            interp = self._outer_interp(outer, a.aspect)
            parts.append(
                f"{outer.value} {a.aspect.value} {other_planet.value} (orb {a.orb:.1f}°) "
                f"in {a.sign_a.value}/{a.sign_b.value}: {interp}"
            )

        return " ".join(parts)

    def _outer_interp(self, planet: PlanetName, aspect: AspectType) -> str:
        bases = {
            PlanetName.URANUS: {
                AspectType.CONJUNCTION: "Sudden insights and electric excitement in the relationship.",
                AspectType.TRINE: "Innovation and freedom expressed harmoniously between you.",
                AspectType.SEXTILE: "Gentle awakenings that push you toward growth.",
                AspectType.SQUARE: "Restlessness and need for change that tests the bond.",
                AspectType.OPPOSITION: "Balancing stability with unpredictability.",
            },
            PlanetName.NEPTUNE: {
                AspectType.CONJUNCTION: "Spiritual depth and shared dreams, but watch for illusion.",
                AspectType.TRINE: "Romantic idealism and intuitive understanding.",
                AspectType.SEXTILE: "Gentle spiritual connection and creative inspiration.",
                AspectType.SQUARE: "Idealism meeting reality - learning to see each other clearly.",
                AspectType.OPPOSITION: "Dreams versus practicality in the relationship.",
            },
            PlanetName.PLUTO: {
                AspectType.CONJUNCTION: "Intense transformative power - this bond changes you both.",
                AspectType.TRINE: "Deep psychological understanding and healing energy.",
                AspectType.SEXTILE: "Opportunities for profound personal growth through the relationship.",
                AspectType.SQUARE: "Power dynamics and control issues that demand transformation.",
                AspectType.OPPOSITION: "Mirror of each other's shadow selves, promoting deep work.",
            },
        }
        return bases.get(planet, {}).get(aspect, "")

    def _build_personality_a(
        self,
        synastry: SynastryResult,
        name_a: str = "",
        name_b: str = "",
    ) -> str:
        a_chart = synastry.person_a_chart
        if not a_chart:
            return "Personality details unavailable without chart data."

        who = (name_a or "").strip()
        other = (name_b or "").strip() or "your partner"

        sun_sign = self._get_sun_sign(a_chart)
        moon_sign = self._get_moon_sign(a_chart)
        asc_sign = None
        for p in a_chart.planets:
            if p.planet == PlanetName.ASCENDANT:
                asc_sign = p.sign.value

        parts = []
        if sun_sign and moon_sign:
            if who:
                parts.append(
                    f"{who} is {sun_sign} Sun / {moon_sign} Moon"
                    + (f" with {asc_sign} rising" if asc_sign else "")
                    + "."
                )
            else:
                parts.append(
                    f"You are {sun_sign} Sun / {moon_sign} Moon"
                    + (f" with {asc_sign} rising" if asc_sign else "")
                    + "."
                )

        sun_aspects = [
            a for a in synastry.planet_aspects
            if a.planet_a == PlanetName.SUN or a.planet_b == PlanetName.SUN
        ]
        if sun_aspects:
            connections = []
            for a in sun_aspects[:4]:
                planet = a.planet_a if a.planet_a == PlanetName.SUN else a.planet_b
                other_planet = a.planet_b if planet == a.planet_a else a.planet_a
                connections.append(
                    f"Sun {a.aspect.value} {other_planet.value} (orb {a.orb:.1f}°)"
                )
            subject = f"{who}'s" if who else "Your"
            parts.append(
                f"Their Sun connects via {', '.join(connections)}, "
                f"showing how {subject} core identity interacts with {other}."
            )

        return " ".join(parts) if parts else "Personality analysis requires more chart data."

    def _build_personality_b(
        self,
        synastry: SynastryResult,
        name_a: str = "",
        name_b: str = "",
    ) -> str:
        b_chart = synastry.person_b_chart
        if not b_chart:
            return "Personality details unavailable without chart data."

        who = (name_b or "").strip()
        other = (name_a or "").strip() or "you"

        sun_sign = self._get_sun_sign(b_chart)
        moon_sign = self._get_moon_sign(b_chart)
        asc_sign = None
        for p in b_chart.planets:
            if p.planet == PlanetName.ASCENDANT:
                asc_sign = p.sign.value

        parts = []
        if sun_sign and moon_sign:
            if who:
                parts.append(
                    f"{who} is {sun_sign} Sun / {moon_sign} Moon"
                    + (f" with {asc_sign} rising" if asc_sign else "")
                    + "."
                )
            else:
                parts.append(
                    f"They are {sun_sign} Sun / {moon_sign} Moon"
                    + (f" with {asc_sign} rising" if asc_sign else "")
                    + "."
                )

        venus_aspects = [
            a for a in synastry.planet_aspects
            if a.planet_a == PlanetName.VENUS or a.planet_b == PlanetName.VENUS
        ]
        if venus_aspects:
            connections = []
            for a in venus_aspects[:4]:
                other_planet = a.planet_b if a.planet_a == PlanetName.VENUS else a.planet_a
                connections.append(
                    f"Venus {a.aspect.value} {other_planet.value} (orb {a.orb:.1f}°)"
                )
            subject = f"{who}'s" if who else "Their"
            parts.append(
                f"Their Venus connects via {', '.join(connections)}, "
                f"revealing how {subject} love and affection shows up with {other}."
            )

        return " ".join(parts) if parts else "Personality analysis requires more chart data."

    def _build_love_language(self, all_aspects: List[PlanetToPlanetAspect]) -> str:
        venus_aspects = [a for a in all_aspects if PlanetName.VENUS in (a.planet_a, a.planet_b)]
        moon_aspects = [a for a in all_aspects if PlanetName.MOON in (a.planet_a, a.planet_b)]

        parts = []
        for a in venus_aspects:
            other = a.planet_b if a.planet_a == PlanetName.VENUS else a.planet_a
            interp = {
                AspectType.CONJUNCTION: "affection is expressed naturally and intuitively.",
                AspectType.TRINE: "romantic gestures flow easily between you.",
                AspectType.SEXTILE: "you discover each other's love language through small gestures.",
                AspectType.SQUARE: "you express love differently - learning each other's style takes effort.",
                AspectType.OPPOSITION: "you mirror each other's romantic needs in complementary ways.",
            }.get(a.aspect, "")
            if interp:
                parts.append(
                    f"Venus {a.aspect.value} {other.value} (orb {a.orb:.1f}°) "
                    f"in {a.sign_a.value}/{a.sign_b.value}: {interp}"
                )

        for a in moon_aspects:
            other = a.planet_b if a.planet_a == PlanetName.MOON else a.planet_b
            if a.aspect == AspectType.CONJUNCTION:
                parts.append(
                    f"Moon conjunction (orb {a.orb:.1f}°): you instinctively know "
                    f"how to comfort and nurture each other."
                )

        if not parts:
            parts.append(
                "Your love language expression is shaped by the interplay of Venus "
                "and Moon energies between your charts."
            )

        return " ".join(parts)

    def _build_trust_loyalty(self, all_aspects: List[PlanetToPlanetAspect]) -> str:
        saturn_aspects = [a for a in all_aspects if PlanetName.SATURN in (a.planet_a, a.planet_b)]
        sun_aspects = [a for a in all_aspects if PlanetName.SUN in (a.planet_a, a.planet_b)]

        parts = []
        for a in saturn_aspects:
            other = a.planet_b if a.planet_a == PlanetName.SATURN else a.planet_a
            interp = {
                AspectType.CONJUNCTION: "deep commitment and shared sense of duty.",
                AspectType.TRINE: "mutual respect that builds lasting trust.",
                AspectType.SEXTILE: "supportive discipline that strengthens loyalty.",
                AspectType.SQUARE: "trust tested through responsibility - ultimately deepened.",
                AspectType.OPPOSITION: "balancing freedom with commitment requires honest dialogue.",
            }.get(a.aspect, "")
            if interp:
                parts.append(
                    f"Saturn {a.aspect.value} {other.value} (orb {a.orb:.1f}°): {interp}"
                )

        for a in sun_aspects:
            other = a.planet_b if a.planet_a == PlanetName.SUN else a.planet_b
            if a.aspect == AspectType.CONJUNCTION:
                parts.append(
                    f"Sun conjunction (orb {a.orb:.1f}°): your core identities align, "
                    f"fostering mutual trust."
                )

        if not parts:
            parts.append(
                "Trust develops through shared experiences rather than innate planetary resonance."
            )

        return " ".join(parts)

    def _build_intimacy(self, all_aspects: List[PlanetToPlanetAspect]) -> str:
        venus_mars = [
            a for a in all_aspects
            if {a.planet_a, a.planet_b} == {PlanetName.VENUS, PlanetName.MARS}
        ]
        pluto_aspects = [
            a for a in all_aspects
            if PlanetName.PLUTO in (a.planet_a, a.planet_b)
        ]

        parts = []
        for a in venus_mars:
            other = a.planet_b if a.planet_a == PlanetName.VENUS else a.planet_a
            interp = {
                AspectType.CONJUNCTION: "intense romantic and physical magnetism - you draw each other in irresistibly.",
                AspectType.TRINE: "passionate connection that feels natural and effortless.",
                AspectType.SEXTILE: "playful attraction that builds through shared experiences.",
                AspectType.SQUARE: "intense but sometimes challenging attraction - the spark requires balance.",
                AspectType.OPPOSITION: "powerful pull of opposites - you complete each other's desires.",
            }.get(a.aspect, "")
            if interp:
                parts.append(
                    f"Venus {a.aspect.value} {other.value} (orb {a.orb:.1f}°) "
                    f"in {a.sign_a.value}/{a.sign_b.value}: {interp}"
                )

        for a in pluto_aspects[:2]:
            other = a.planet_b if a.planet_a == PlanetName.PLUTO else a.planet_a
            if a.aspect in (AspectType.TRINE, AspectType.CONJUNCTION, AspectType.SEXTILE):
                parts.append(
                    f"Pluto {a.aspect.value} {other.value} (orb {a.orb:.1f}°): "
                    f"deep psychological and transformative intimacy."
                )

        if not parts:
            parts.append(
                "Your intimate connection is shaped by the interplay of Venus, Mars, "
                "and Pluto energies between your charts."
            )

        return " ".join(parts)

    def _build_conflict_style(self, all_aspects: List[PlanetToPlanetAspect]) -> str:
        mars_aspects = [a for a in all_aspects if PlanetName.MARS in (a.planet_a, a.planet_b)]
        saturn_aspects = [a for a in all_aspects if PlanetName.SATURN in (a.planet_a, a.planet_b)]

        parts = []
        for a in mars_aspects:
            other = a.planet_b if a.planet_a == PlanetName.MARS else a.planet_a
            interp = {
                AspectType.CONJUNCTION: "shared assertiveness - you can be direct but may escalate.",
                AspectType.TRINE: "healthy expression of anger - conflicts resolve naturally.",
                AspectType.SEXTILE: "constructive channeling of competitive energy.",
                AspectType.SQUARE: "passionate disagreements that can escalate quickly - learn to pause.",
                AspectType.OPPOSITION: "opposing styles of assertion that can balance each other.",
            }.get(a.aspect, "")
            if interp:
                parts.append(
                    f"Mars {a.aspect.value} {other.value} (orb {a.orb:.1f}°) "
                    f"in {a.sign_a.value}/{a.sign_b.value}: {interp}"
                )

        for a in saturn_aspects:
            other = a.planet_b if a.planet_a == PlanetName.SATURN else a.planet_a
            if a.aspect == AspectType.SQUARE:
                parts.append(
                    f"Saturn square {other.value} (orb {a.orb:.1f}°): "
                    f"feelings of restriction during conflicts - patience is essential."
                )

        if not parts:
            parts.append(
                "Your conflict style is influenced by Mars and Saturn dynamics, "
                "shaping how you navigate disagreements."
            )

        return " ".join(parts)

    def _build_verdict(
        self,
        synastry: SynastryResult,
        dimensions: Optional[CompatibilityDimensions],
        name_a: str = "",
        name_b: str = "",
    ) -> str:
        parts = []

        a_chart = synastry.person_a_chart
        b_chart = synastry.person_b_chart
        a_sun = self._get_sun_sign(a_chart)
        b_sun = self._get_sun_sign(b_chart)

        if a_sun and b_sun:
            a_label = f"{name_a} ({a_sun})" if name_a else a_sun
            b_label = f"{name_b} ({b_sun})" if name_b else b_sun
            parts.append(f"Between {a_label} and {b_label} energy:")

        total = len(synastry.planet_aspects)
        conj = len(synastry.conjunctions)
        trine = len(synastry.trines)
        square = len(synastry.squares)

        if conj > 3:
            parts.append(
                f"Strong natural resonance with {conj} conjunctions binding your charts."
            )
        if trine > 3:
            parts.append(
                f"Harmonic ease through {trine} trines that make connection feel natural."
            )
        if square > 3:
            parts.append(
                f"Dynamic tension from {square} squares that drives transformation."
            )

        if dimensions:
            if dimensions.overall >= 75:
                parts.append(
                    f"Overall {dimensions.overall}/100: a particularly promising cosmic match "
                    f"with strong potential across multiple dimensions."
                )
            elif dimensions.overall >= 55:
                parts.append(
                    f"Overall {dimensions.overall}/100: solid compatibility with room to "
                    f"deepen your connection over time."
                )
            else:
                parts.append(
                    f"Overall {dimensions.overall}/100: challenging but potentially transformative "
                    f"if both commit to understanding each other."
                )

        return " ".join(parts) if parts else "Your cosmic connection has unique qualities worth exploring."

    def _get_sun_sign(self, chart: Optional[WesternChart]) -> Optional[str]:
        if not chart:
            return None
        for planet in chart.planets:
            if planet.planet == PlanetName.SUN:
                return planet.sign.value
        return None

    def _get_moon_sign(self, chart: Optional[WesternChart]) -> Optional[str]:
        if not chart:
            return None
        for planet in chart.planets:
            if planet.planet == PlanetName.MOON:
                return planet.sign.value
        return None
