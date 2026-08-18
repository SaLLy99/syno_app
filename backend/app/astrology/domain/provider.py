from abc import ABC, abstractmethod
from typing import Optional

from ..domain.models import (
    BirthData,
    WesternChart,
    VedicChart,
    SynastryResult,
    VedicCompatibilityResult,
)


class AstrologyProvider(ABC):
    """Abstract base class for astrology providers.

    All astrology calculations must go through this interface.
    Provider-specific code must NOT leak into Syno business logic.
    """

    @abstractmethod
    def get_western_chart(self, birth_data: BirthData) -> WesternChart:
        """Calculate a Western (tropical) natal chart."""
        ...

    @abstractmethod
    def get_vedic_chart(
        self,
        birth_data: BirthData,
        ayanamsa: str = "Lahiri",
    ) -> VedicChart:
        """Calculate a Vedic (sidereal) natal chart."""
        ...

    @abstractmethod
    def get_synastry(
        self,
        person_a: BirthData,
        person_b: BirthData,
    ) -> SynastryResult:
        """Calculate Western synastry between two people."""
        ...

    @abstractmethod
    def get_vedic_compatibility(
        self,
        person_a: BirthData,
        person_b: BirthData,
        ayanamsa: str = "Lahiri",
    ) -> VedicCompatibilityResult:
        """Calculate Vedic (Kuta) compatibility between two people."""
        ...
