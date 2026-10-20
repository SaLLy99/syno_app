import logging
from typing import Optional, Dict
from datetime import date, time

from ..domain.models import (
    BirthData,
    WesternChart,
    AstrologySystem,
)
from ..domain.provider import AstrologyProvider
from ..cache.keys import generate_chart_cache_key

logger = logging.getLogger(__name__)


class ChartService:
    """Service for natal chart calculations with caching."""

    def __init__(self, provider: AstrologyProvider):
        self.provider = provider
        self._cache: Dict[str, object] = {}

    def get_western_chart(
        self,
        birth_data: BirthData,
        use_cache: bool = True,
    ) -> WesternChart:
        cache_key = generate_chart_cache_key(
            birth_data, AstrologySystem.WESTERN_TROPICAL
        )

        if use_cache and cache_key in self._cache:
            logger.debug(f"Cache hit for western chart: {cache_key[:12]}...")
            return self._cache[cache_key]

        chart = self.provider.get_western_chart(birth_data)

        if use_cache:
            self._cache[cache_key] = chart

        return chart

    def clear_cache(self):
        self._cache.clear()
