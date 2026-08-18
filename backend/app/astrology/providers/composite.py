import logging
from typing import Optional

from ..domain.models import (
    BirthData,
    WesternChart,
    VedicChart,
    SynastryResult,
    VedicCompatibilityResult,
)
from ..domain.provider import AstrologyProvider
from .western import SwissEphProvider
from .vedastro import VedAstroProvider

logger = logging.getLogger(__name__)


class CompositeProvider(AstrologyProvider):
    """Combined provider that delegates Western to SwissEph and Vedic to VedAstro."""

    def __init__(self, api_key: Optional[str] = None):
        self.western = SwissEphProvider()
        self.vedic = VedAstroProvider(api_key=api_key or "FreeAPIUser")

    def get_western_chart(self, birth_data: BirthData) -> WesternChart:
        return self.western.get_western_chart(birth_data)

    def get_vedic_chart(
        self,
        birth_data: BirthData,
        ayanamsa: str = "Lahiri",
    ) -> VedicChart:
        return self.vedic.get_vedic_chart(birth_data, ayanamsa)

    def get_synastry(
        self,
        person_a: BirthData,
        person_b: BirthData,
    ) -> SynastryResult:
        return self.western.get_synastry(person_a, person_b)

    def get_vedic_compatibility(
        self,
        person_a: BirthData,
        person_b: BirthData,
        ayanamsa: str = "Lahiri",
    ) -> VedicCompatibilityResult:
        return self.vedic.get_vedic_compatibility(person_a, person_b, ayanamsa)
