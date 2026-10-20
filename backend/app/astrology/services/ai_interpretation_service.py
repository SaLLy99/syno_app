import hashlib
import json
import logging
import time
from typing import Optional, Dict

from google import genai

from ..domain.models import (
    WesternChart,
    SynastryResult,
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

    def __init__(
        self,
        api_key: str,
        model: str = "gemini-3.1-flash-lite",
        fallback_models: Optional[list] = None,
    ):
        self.client = genai.Client(api_key=api_key)
        self.model = model
        self.fallback_models = list(
            fallback_models or ["gemini-3.6-flash", "gemini-3.5-flash"]
        )
        self._cache: Dict[str, InterpretationResult] = {}
        self._chart_cache: Dict[str, dict] = {}

    def _make_cache_key(self, *args) -> str:
        key_str = json.dumps(args, sort_keys=True, default=str)
        return hashlib.sha256(key_str.encode()).hexdigest()

    def interpret_synastry(
        self,
        synastry: SynastryResult,
        dimensions: Optional[CompatibilityDimensions] = None,
        person_a_name: str = "",
        person_b_name: str = "",
    ) -> Optional[InterpretationResult]:
        """AI-generated synastry interpretation. Returns None on failure."""
        try:
            name_a = (person_a_name or "").strip()
            name_b = (person_b_name or "").strip()
            cache_key = self._make_cache_key(
                self._serialize_synastry(synastry),
                self._serialize_dimensions(dimensions),
                name_a,
                name_b,
            )

            if cache_key in self._cache:
                logger.debug(f"AI interpretation cache hit: {cache_key[:12]}...")
                return self._cache[cache_key]

            prompt = self._build_synastry_prompt(
                synastry, dimensions, person_a_name=name_a, person_b_name=name_b
            )
            response = self._call_ai(prompt)
            result = self._parse_synastry_response(response)

            self._cache[cache_key] = result
            logger.info(f"AI synastry interpretation generated for cache key: {cache_key[:12]}...")
            return result

        except Exception as e:
            logger.error(f"AI interpretation failed (model={self.model}), falling back to rules: {type(e).__name__}: {e}", exc_info=True)
            return None

    def generate_cosmic_insight(
        self,
        synastry: SynastryResult,
        dimensions: Optional[CompatibilityDimensions] = None,
        overall_score: float = 50.0,
        person_a_name: str = "",
        person_b_name: str = "",
    ) -> Optional[str]:
        """AI-generated cosmic insight. Returns None on failure."""
        try:
            name_a = (person_a_name or "").strip()
            name_b = (person_b_name or "").strip()
            cache_key = self._make_cache_key(
                "cosmic_insight",
                self._serialize_synastry(synastry),
                overall_score,
                name_a,
                name_b,
            )

            chart_a = synastry.person_a_chart
            chart_b = synastry.person_b_chart
            person_a_summary = self._chart_summary(chart_a) if chart_a else "N/A"
            person_b_summary = self._chart_summary(chart_b) if chart_b else "N/A"

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

            prompt = f"""You are a warm, mystical astrologer writing a short cosmic insight for a romantic match.
The overall compatibility score is {overall_score:.0f}/100.

## {name_a or "Partner One"}
{person_a_summary}

## {name_b or "Partner Two"}
{person_b_summary}
{dim_text}

Write a 2-3 sentence cosmic insight that:
- Feels personal and warm, not generic
- References their actual zodiac signs or key planetary positions
- Uses their real names ({name_a or "partner one"} and {name_b or "partner two"}) instead of "Person A"/"Person B"
- Highlights the most interesting thing about their connection
- Ends with something hopeful or intriguing

Return ONLY the text, no JSON, no markdown fences."""

            response = self._call_ai(prompt)
            result = response.strip().strip('"').strip("'")
            logger.info(f"AI cosmic insight generated")
            return result

        except Exception as e:
            logger.error(f"AI cosmic insight failed: {e}")
            return None

    def generate_top_reasons(
        self,
        synastry: SynastryResult,
        dimensions: Optional[CompatibilityDimensions] = None,
        shared_hobbies: Optional[list] = None,
        shared_values: Optional[list] = None,
        person_a_name: str = "",
        person_b_name: str = "",
    ) -> Optional[list]:
        """AI-generated top reasons. Returns None on failure."""
        try:
            name_a = (person_a_name or "").strip()
            name_b = (person_b_name or "").strip()
            chart_a = synastry.person_a_chart
            chart_b = synastry.person_b_chart
            person_a_summary = self._chart_summary(chart_a) if chart_a else "N/A"
            person_b_summary = self._chart_summary(chart_b) if chart_b else "N/A"

            shared_text = ""
            if shared_hobbies:
                shared_text += f"\nShared interests: {', '.join(shared_hobbies)}"
            if shared_values:
                shared_text += f"\nShared values: {', '.join(shared_values)}"

            dim_text = ""
            if dimensions:
                dim_text = (
                    f"\nCompatibility Dimensions:\n"
                    f"- Emotional: {dimensions.emotional}/100\n"
                    f"- Communication: {dimensions.communication}/100\n"
                    f"- Values: {dimensions.values}/100\n"
                    f"- Attraction: {dimensions.attraction}/100\n"
                    f"- Overall: {dimensions.overall}/100\n"
                )

            prompt = f"""You are a warm astrologer writing short "why we matched" reasons for a dating app.
Generate 3-5 concise reasons (each under 15 words) why these two people are a great match.
Never use "Person A" or "Person B" - use their names: {name_a or "Partner One"} and {name_b or "Partner Two"}.

## {name_a or "Partner One"}
{person_a_summary}

## {name_b or "Partner Two"}
{person_b_summary}
{dim_text}
{shared_text}

Return a JSON array of strings, e.g. ["reason 1", "reason 2", "reason 3"]
Return ONLY the JSON array, no markdown fences."""

            response = self._call_ai(prompt)
            clean = response.strip()
            if clean.startswith("```"):
                clean = clean.split("\n", 1)[1]
                if clean.endswith("```"):
                    clean = clean[:-3]
                clean = clean.strip()
            reasons = self._loads_json(clean)
            if isinstance(reasons, list):
                logger.info(f"AI top reasons generated: {len(reasons)} reasons")
                return [str(r) for r in reasons[:5]]
            return None

        except Exception as e:
            logger.error(f"AI top reasons failed: {e}")
            return None

    def interpret_natal_chart(
        self,
        chart: WesternChart,
    ) -> Optional[dict]:
        """AI-generated natal chart interpretation. Returns None on failure."""
        try:
            cache_key = self._make_cache_key(
                self._serialize_chart(chart),
            )

            if cache_key in self._chart_cache:
                logger.debug(f"AI chart cache hit: {cache_key[:12]}...")
                return self._chart_cache[cache_key]

            prompt = self._build_chart_prompt(chart)
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
        dimensions: Optional[CompatibilityDimensions],
        person_a_name: str = "",
        person_b_name: str = "",
    ) -> str:
        chart_a = synastry.person_a_chart
        chart_b = synastry.person_b_chart

        name_a = (person_a_name or "").strip() or "Partner One"
        name_b = (person_b_name or "").strip() or "Partner Two"

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

        return f"""You are a world-class astrologer and relationship coach writing a comprehensive, deeply personal synastry reading for a romantic couple. Your tone is warm, insightful, specific, and actionable - like a trusted coach who also reads charts. Reference actual planet placements, signs, and aspects by name. Write like you're giving a private reading to a close friend - intimate, genuine, and transformative.

CRITICAL NAMING RULES:
- The two people are {name_a} and {name_b}.
- NEVER write "Person A", "Person B", "Person One", "Person Two", "the first person", or "the second person" anywhere.
- Always use their real names, or clear pronouns/references ("you"/"your partner") when addressing the reader.
- The chart under "{name_a}" is {name_a}'s; the chart under "{name_b}" is {name_b}'s.

## {name_a}'s Chart
{person_a_summary}

## {name_b}'s Chart
{person_b_summary}

## Synastry Aspects
{aspects_text}
{dim_text}

Generate a JSON response with these fields:

{{
  "summary": "3-4 sentence opening reading. Paint a vivid picture of what their connection FEELS like - imagine {name_a} and {name_b} in a room together, the energy between them. Reference their Sun/Moon/Rising signs by name. Make it feel magical and specific to them.",

  "personality_a": "2-3 sentences about {name_a}'s core personality based on their Sun, Moon, Rising, and key aspects. Describe how they show up in the world and in relationships. Always use the name {name_a}.",

  "personality_b": "2-3 sentences about {name_b}'s core personality based on their Sun, Moon, Rising, and key aspects. Describe how they show up in the world and in relationships. Always use the name {name_b}.",

  "strengths": [
    "4-6 specific strengths. For each, mention exact planets, signs, and aspects. Example: '{name_a}'s Venus in Taurus trines {name_b}'s Moon in Cancer - a rare nurturing romantic bond where affection flows naturally'",
    "Be specific about WHY each aspect creates strength"
  ],

  "challenges": [
    "3-5 constructive challenges. Frame each as growth opportunity. Example: '{name_a}'s Mars in Aries squares {name_b}'s Saturn in Capricorn - passion meets caution. The key is patience and honoring each other's pace'"
  ],

  "communication": "3-4 sentences about their communication style. Reference Mercury signs and aspects. Describe HOW {name_a} and {name_b} actually talk to each other - do they finish each other's sentences? Do they need to learn each other's language? What's their texting vibe?",

  "emotional_dynamic": "3-4 sentences about their emotional connection. Reference Moon signs and aspects. Describe the FEELING of {name_a} and {name_b} being emotionally vulnerable together. How do they handle each other's tears? Their emotional rhythms?",

  "values": "3-4 sentences about shared values and worldview. Reference Jupiter/Saturn aspects. What do {name_a} and {name_b} both care about? What's their shared vision for life?",

  "growth_dynamic": "3-4 sentences about growth potential. Reference outer planet aspects (Uranus, Neptune, Pluto). How does this relationship help {name_a} and {name_b} evolve as individuals? What lessons are they here to teach each other?",

  "love_language": "2-3 sentences about their love language compatibility. Based on Venus placements, Moon aspects, and romantic indicators. How do {name_a} and {name_b} naturally give and receive love?",

  "trust_loyalty": "2-3 sentences about trust and loyalty dynamics. Reference Saturn aspects, Pluto indicators, and stability factors. How do {name_a} and {name_b} build and maintain trust?",

  "intimacy_text": "2-3 sentences about their intimate/physical connection. Reference Venus-Mars aspects and chemistry indicators. What's the chemistry like between {name_a} and {name_b}?",

  "conflict_style": "2-3 sentences about how {name_a} and {name_b} handle disagreements. Reference Mars aspects, Saturn dynamics, and challenging placements. What triggers conflict and how do they resolve it?",

  "overall_verdict": "2-3 sentence closing verdict. Summarize what makes the connection between {name_a} and {name_b} special. What is the OVERALL story of their relationship? End with something memorable and uplifting.",

  "coach_tips": [
    "4-6 actionable, specific coaching tips for {name_a} and {name_b} as a couple.",
    "Each tip must be one sentence, under 25 words, start with a verb, and reference at least one real placement or dimension from the data.",
    "Cover: communication habits, conflict repair, keeping attraction alive, and one shared-growth practice.",
    "Example: 'Schedule a weekly check-in where {name_a} shares one feeling before {name_b} problem-solves - Moon square Moon needs verbal reassurance.'"
  ]
}}

Return ONLY valid JSON, no markdown fences."""

    def _build_chart_prompt(self, chart: WesternChart) -> str:
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
        models = list(dict.fromkeys([self.model, *self.fallback_models]))
        last_error: Optional[Exception] = None
        for model in models:
            for attempt in range(2):
                try:
                    response = self.client.models.generate_content(
                        model=model,
                        contents=prompt,
                        config={
                            "temperature": 0.7,
                            "max_output_tokens": 8192,
                        },
                    )
                    text = (response.text or "").strip()
                    if not text:
                        raise ValueError("Empty AI response")
                    if model != self.model:
                        logger.info(f"AI succeeded with fallback model {model}")
                    return text
                except Exception as e:
                    last_error = e
                    if not self._is_retryable_ai_error(e):
                        raise
                    if attempt >= 1 or self._is_quota_error(e):
                        break
                    wait = 2.0
                    logger.warning(
                        f"AI call failed on {model} (attempt 1/2), "
                        f"retrying in {wait}s: {e}"
                    )
                    time.sleep(wait)
        raise last_error if last_error else RuntimeError("AI call failed")

    def _is_quota_error(self, error: Exception) -> bool:
        msg = str(error)
        markers = ("429", "RESOURCE_EXHAUSTED", "quota", "rate limit")
        return any(m.lower() in msg.lower() for m in markers)

    def _is_retryable_ai_error(self, error: Exception) -> bool:
        msg = str(error)
        markers = (
            "503",
            "429",
            "500",
            "502",
            "504",
            "UNAVAILABLE",
            "RESOURCE_EXHAUSTED",
            "overloaded",
            "high demand",
            "deadline",
            "timeout",
            "Empty AI response",
        )
        return any(m.lower() in msg.lower() for m in markers)

    def _strip_code_fences(self, text: str) -> str:
        clean = text.strip()
        if clean.startswith("```"):
            clean = clean.split("\n", 1)[1] if "\n" in clean else clean
            if clean.endswith("```"):
                clean = clean[:-3]
            clean = clean.strip()
        return clean

    def _repair_truncated_json(self, text: str) -> Optional[str]:
        start = text.find("{")
        if start < 0:
            start = text.find("[")
        if start < 0:
            return None
        fragment = text[start:]

        in_string = False
        escape = False
        for ch in fragment:
            if escape:
                escape = False
                continue
            if ch == "\\":
                escape = True
                continue
            if ch == '"':
                in_string = not in_string

        repaired = fragment.rstrip()
        if in_string:
            if repaired.endswith("\\"):
                repaired = repaired[:-1]
            repaired += '"'
        if repaired.endswith((",", ":")):
            if repaired.endswith(":"):
                repaired += " null"
            else:
                repaired = repaired[:-1]
        elif repaired and repaired[-1] in "{[":
            repaired += "}"

        in_string = False
        escape = False
        stack: list[str] = []
        for ch in repaired:
            if escape:
                escape = False
                continue
            if ch == "\\":
                escape = True
                continue
            if ch == '"':
                in_string = not in_string
                continue
            if in_string:
                continue
            if ch in "{[":
                stack.append(ch)
            elif ch in "}]":
                if stack:
                    stack.pop()
        for open_ch in reversed(stack):
            repaired += "}" if open_ch == "{" else "]"
        return repaired

    def _loads_json(self, text: str):
        clean = self._strip_code_fences(text)
        try:
            return json.loads(clean)
        except json.JSONDecodeError:
            repaired = self._repair_truncated_json(clean)
            if repaired is None:
                raise
            logger.warning(
                f"AI JSON truncated/unparseable, repaired fragment ({len(repaired)} chars)"
            )
            return json.loads(repaired)

    def _parse_synastry_response(self, response: str) -> InterpretationResult:
        try:
            data = self._loads_json(response)

            return InterpretationResult(
                summary=data.get("summary", ""),
                strengths=data.get("strengths", []),
                challenges=data.get("challenges", []),
                communication=data.get("communication", ""),
                emotional_dynamic=data.get("emotional_dynamic", ""),
                values=data.get("values", ""),
                growth_dynamic=data.get("growth_dynamic", ""),
                important_aspects=[],
                personality_a=data.get("personality_a", ""),
                personality_b=data.get("personality_b", ""),
                love_language=data.get("love_language", ""),
                trust_loyalty=data.get("trust_loyalty", ""),
                intimacy_text=data.get("intimacy_text", ""),
                conflict_style=data.get("conflict_style", ""),
                overall_verdict=data.get("overall_verdict", ""),
                coach_tips=[str(t) for t in (data.get("coach_tips") or [])][:8],
            )
        except (json.JSONDecodeError, KeyError) as e:
            logger.error(f"Failed to parse AI response: {e}")
            raise ValueError(f"Invalid AI response format: {e}")

    def _parse_chart_response(self, response: str) -> dict:
        try:
            data = self._loads_json(response)

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
