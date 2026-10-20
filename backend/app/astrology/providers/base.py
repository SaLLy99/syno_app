import logging
from typing import Optional

from ..domain.provider import AstrologyProvider

logger = logging.getLogger(__name__)


def create_astrology_provider(
    provider_type: str = "swisseph",
    api_key: Optional[str] = None,
) -> AstrologyProvider:
    """Factory function to create astrology providers.

    Args:
        provider_type: "swisseph" for Western astrology
        api_key: Not used (kept for API compatibility)

    Returns:
        An AstrologyProvider instance
    """
    if provider_type == "swisseph":
        from .western import SwissEphProvider
        return SwissEphProvider()
    else:
        raise ValueError(f"Unknown provider type: {provider_type}")
