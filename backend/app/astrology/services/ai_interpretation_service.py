import hashlib
import json
import logging
from typing import Optional, Dict

from google import genai

from ..domain.models import (
    WesternChart,
    SynastryResult,
    VedicCompatibilityResult,
    CompatibilityDimensions,
    InterpretationResult,
    PlanetName,
    AspectType,
)

logger = logging.getLogger(__name__)


class AIInterpretationService:
    """AI-powered astrology interpretation using Google Gemini (free tier).

    Free tier: 60 requests/min, 1M tokens/day.
    Generates unique, rich interpretations for each chart/synastry.
    Caches results by SHA-256 hash of input data so the same profile always
    gets the same interpretation and never re-calls the API.
    """

    def __init__(self, api_key: str, model: str = "gemini-2.0-flash"):
        self.client = genai.Client(api_key=api_key)
        self.model = model
        self._cache: Dict[str, InterpretationResult] = {}
        self._chart_cache: Dict[str, dict] = {}

    def _make_cache_key(self, *args) -> str:
        key_str = json.dumps(args, sort_keys=True, default=str)
        return hashlib.sha256(key_str.encode()).hexdigest()

    def interpret_synastry(
        self,
        synastry: SynastryResult,
        vedic_compatibility: Optional[VedicCompatibilityResult] = None,
        dimensions: Optional[CompatibilityDimensions] = None,
    ) -> Optional[InterpretationResult]:
        """AI-generated synastry interpretation. Returns None on failure."""
        try:
            cache_key = self._make_cache_key(
                self._serialize_synastry(synastry),
                self._serialize_vedic(vedic_compatibility),
                self._serialize_dimensions(dimensions),
            )

            if cache_key in self._cache:
                logger.debug(f"AI interpretation cache hit: {cache_key[:12]}...")
                return self._cache[cache_key]

            prompt = self._build_synastry_prompt(synastry, vedic_compatibility, dimensions)
            response = self._call_ai(prompt)
            result = self._parse_synastry_response(response)

            self._cache[cache_key] = result
            return result

        except Exception as e:
            logger.error(f"AI interpretation failed: {e}")
            return None

    def interpret_natal_chart(
        self,
        chart: WesternChart,
        vedic_chart=None,
    ) -> Optional[dict]:
        """AI-generated natal chart interpretation. Returns None on failure."""
        try:
            cache_key = self._make_cache_key(
                self._serialize_chart(chart),
                self._serialize_vedic_chart(vedic_chart),
            )

            if cache_key in self._chart_cache:
                logger.debug(f"AI chart cache hit: {cache_key[:12]}...")
                return self._chart_cache[cache_key]

            prompt = self._build_chart_prompt(chart, vedic_chart)
            response = self._call_ai(prompt)
            result = self._parse_chart_response(response)

            self._chart_cache[cache_key] = result
            return result

        except Exception as e:
            logger.error(f"AI chart interpretation failed: {e}")
            return None

    def _build_synastry_prompt(
        self,
        synastry: SynastryResult,
        vedic_compatibility: Optional[VedicCompatibilityResult],
        dimensions: Optional[CompatibilityDimensions],
    ) -> str:
        chart_a = synastry.person_a_chart
        chart_b = synastry.person_b_chart

        person_a_summary = self._chart_summary(chart_a) if chart_a else "N/A"
        person_b_summary = self._chart_summary(chart_b) if chart_b else "N/A"

        aspects_text = self._format_synastry_aspects(synastry)

        dim_text = ""
        if dimensions:
            dim_text = (
                f"\nCompatibility Dimensions:\n"
                f"- Emotional: {dimensions.emotional}/100\n"
                f"- Communication: {dimensions.communication}/100\n"
                f"- Values: {dimensions.values}/100\n"
                f"- Attraction: {dimensions.attraction}/100\n"
                f"- Conflict: {dimensions.conflict}/100\n"
                f"- Stability: {dimensions.stability}/100\n"
                f"- Growth: {dimensions.growth}/100\n"
                f"- Overall: {dimensions.overall}/100\n"
            )

        vedic_text = ""
        if vedic_compatibility and vedic_compatibility.kuta_score:
            vedic_text = f"\nVedic Kuta Score: {vedic_compatibility.kuta_score}/36\n"

        return f"""You are a warm, insightful astrologer interpreting a romantic synastry chart. 
Be specific, personal, and avoid generic statements. Reference actual planet placements.

## Person A Chart
{person_a_summary}

## Person B Chart
{person_b_summary}

## Synastry Aspects
{aspects_text}
{dim_text}{vedic_text}

Generate a JSON response with these fields:
{{
  "summary": "2-3 sentence overall reading referencing their actual Sun/Moon/Rising signs",
  "strengths": ["3-5 specific strength points referencing actual aspects"],
  "challenges": ["3-5 specific challenge areas referencing actual aspects"],
  "communication": "1-2 sentences about their communication style based on Mercury aspects",
  "emotional_dynamic": "1-2 sentences about emotional connection based on Moon aspects",
  "values": "1-2 sentences about shared values based on Jupiter/Saturn aspects",
  "growth_dynamic": "1-2 sentences about growth potential based on outer planet aspects"
}}

Return ONLY valid JSON, no markdown fences."""

    def _build_chart_prompt(self, chart: WesternChart, vedic_chart=None) -> str:
        summary = self._chart_summary(chart)

        aspects_text = ""
        for a in chart.aspects:
            aspects_text += f"  {a.planet_a.value} {a.aspect.value} {a.planet_b.value} (orb {a.orb:.1f}°)\n"

        return f"""You are a warm, insightful astrologer interpreting a natal chart.
Be specific and personal. Reference actual planet placements and signs.

## Natal Chart
{summary}

## Aspects
{aspects_text}

Generate a JSON response with these fields:
{{
  "summary": "2-3 sentence personality overview referencing Sun, Moon, and Rising",
  "sun_sign": "The zodiac sign of the Sun (e.g. 'Leo')",
  "moon_sign": "The zodiac sign of the Moon (e.g. 'Scorpio')",
  "ascendant": "The Rising sign (e.g. 'Libra')",
  "strengths": ["3-4 strengths derived from harmonious aspects"],
  "challenges": ["3-4 growth areas derived from challenging aspects"],
  "personality": "2-3 sentences about their core personality from Sun/Moon/Rising"
}}

Return ONLY valid JSON, no markdown fences."""

    def _call_ai(self, prompt: str) -> str:
        response = self.client.models.generate_content(
            model=self.model,
            contents=prompt,
            config={
                "temperature": 0.7,
                "max_output_tokens": 1500,
            },
        )
        return response.text.strip()

    def _parse_synastry_response(self, response: str) -> InterpretationResult:
        try:
            clean = response.strip()
            if clean.startswith("```"):
                clean = clean.split("\n", 1)[1]
                if clean.endswith("```"):
                    clean = clean[:-3]
                clean = clean.strip()

            data = json.loads(clean)

            return InterpretationResult(
                summary=data.get("summary", ""),
                strengths=data.get("strengths", []),
                challenges=data.get("challenges", []),
                communication=data.get("communication", ""),
                emotional_dynamic=data.get("emotional_dynamic", ""),
                values=data.get("values", ""),
                growth_dynamic=data.get("growth_dynamic", ""),
                important_aspects=[],
            )
        except (json.JSONDecodeError, KeyError) as e:
            logger.error(f"Failed to parse AI response: {e}")
            raise ValueError(f"Invalid AI response format: {e}")

    def _parse_chart_response(self, response: str) -> dict:
        try:
            clean = response.strip()
            if clean.startswith("```"):
                clean = clean.split("\n", 1)[1]
                if clean.endswith("```"):
                    clean = clean[:-3]
                clean = clean.strip()

            data = json.loads(clean)

            return {
                "summary": data.get("summary", ""),
                "sun_sign": data.get("sun_sign", ""),
                "moon_sign": data.get("moon_sign", ""),
                "ascendant": data.get("ascendant", ""),
                "strengths": data.get("strengths", []),
                "challenges": data.get("challenges", []),
                "personality": data.get("personality", ""),
            }
        except (json.JSONDecodeError, KeyError) as e:
            logger.error(f"Failed to parse AI chart response: {e}")
            raise ValueError(f"Invalid AI response format: {e}")

    def _chart_summary(self, chart: Optional[WesternChart]) -> str:
        if not chart:
            return "No chart data available"

        lines = []
        for planet in chart.planets:
            retro = " (R)" if planet.retrograde else ""
            lines.append(
                f"  {planet.planet.value}: {planet.sign.value} {planet.degree:.1f}°"
                f"{f' in House {planet.house}' if planet.house else ''}{retro}"
            )
        return "\n".join(lines)

    def _format_synastry_aspects(self, synastry: SynastryResult) -> str:
        lines = []
        for a in synastry.conjunctions:
            lines.append(f"  {a.planet_a.value} conjunct {a.planet_b.value} in {a.sign_a.value}/{a.sign_b.value} (orb {a.orb:.1f}°)")
        for a in synastry.trines:
            lines.append(f"  {a.planet_a.value} trine {a.planet_b.value} (orb {a.orb:.1f}°)")
        for a in synastry.squares:
            lines.append(f"  {a.planet_a.value} square {a.planet_b.value} (orb {a.orb:.1f}°)")
        for a in synastry.sextiles:
            lines.append(f"  {a.planet_a.value} sextile {a.planet_b.value} (orb {a.orb:.1f}°)")
        for a in synastry.oppositions:
            lines.append(f"  {a.planet_a.value} opposite {a.planet_b.value} (orb {a.orb:.1f}°)")
        return "\n".join(lines) if lines else "No significant aspects found"

    def _serialize_synastry(self, synastry: SynastryResult) -> dict:
        return {
            "aspects": [
                {
                    "planet_a": a.planet_a.value,
                    "planet_b": a.planet_b.value,
                    "aspect": a.aspect.value,
                    "orb": round(a.orb, 2),
                    "sign_a": a.sign_a.value,
                    "sign_b": a.sign_b.value,
                }
                for a in synastry.planet_aspects
            ],
            "person_a_chart": self._serialize_chart(synastry.person_a_chart),
            "person_b_chart": self._serialize_chart(synastry.person_b_chart),
        }

    def _serialize_chart(self, chart: Optional[WesternChart]) -> dict:
        if not chart:
            return {}
        return {
            "planets": [
                {
                    "planet": p.planet.value,
                    "sign": p.sign.value,
                    "degree": round(p.degree, 2),
                    "house": p.house,
                    "retrograde": p.retrograde,
                }
                for p in chart.planets
            ]
        }

    def _serialize_vedic(self, vedic: Optional[VedicCompatibilityResult]) -> dict:
        if not vedic:
            return {}
        return {"kuta_score": vedic.kuta_score}

    def _serialize_vedic_chart(self, vedic) -> dict:
        if not vedic:
            return {}
        return {
            "planets": [
                {"planet": p.planet.value, "sign": p.sign.value}
                for p in vedic.planets
            ]
        }

    def _serialize_dimensions(self, dims: Optional[CompatibilityDimensions]) -> dict:
        if not dims:
            return {}
        return {
            "emotional": dims.emotional,
            "communication": dims.communication,
            "values": dims.values,
            "attraction": dims.attraction,
            "conflict": dims.conflict,
            "stability": dims.stability,
            "growth": dims.growth,
            "overall": dims.overall,
        }
