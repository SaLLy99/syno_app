import logging
from typing import Dict

from ..domain.models import (
    BirthData,
    SynastryResult,
    AstrologySystem,
)
from ..domain.provider import AstrologyProvider
from ..cache.keys import generate_synastry_cache_key

logger = logging.getLogger(__name__)


class SynastryService:
    """Service for synastry calculations with caching."""

    def __init__(self, provider: AstrologyProvider):
        self.provider = provider
        self._cache: Dict[str, SynastryResult] = {}

    def calculate_synastry(
        self,
        person_a: BirthData,
        person_b: BirthData,
        use_cache: bool = True,
    ) -> SynastryResult:
        cache_key = generate_synastry_cache_key(
            person_a, person_b, AstrologySystem.WESTERN_TROPICAL
        )

        if use_cache and cache_key in self._cache:
            logger.debug(f"Cache hit for synastry: {cache_key[:12]}...")
            return self._cache[cache_key]

        result = self.provider.get_synastry(person_a, person_b)

        if use_cache:
            self._cache[cache_key] = result

        return result

    def clear_cache(self):
        self._cache.clear()
