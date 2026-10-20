from abc import ABC, abstractmethod

from ..domain.models import (
    BirthData,
    WesternChart,
    SynastryResult,
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
    def get_synastry(
        self,
        person_a: BirthData,
        person_b: BirthData,
    ) -> SynastryResult:
        """Calculate Western synastry between two people."""
        ...
