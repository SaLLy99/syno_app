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
        provider_type: "swisseph" for Western, "vedastro" for Vedic, "combined" for both
        api_key: VedAstro API key (required for vedastro provider)

    Returns:
        An AstrologyProvider instance
    """
    if provider_type == "vedastro":
        from .vedastro import VedAstroProvider
        return VedAstroProvider(api_key=api_key or "FreeAPIUser")
    elif provider_type == "swisseph":
        from .western import SwissEphProvider
        return SwissEphProvider()
    elif provider_type == "combined":
        from .composite import CompositeProvider
        return CompositeProvider(api_key=api_key)
    else:
        raise ValueError(f"Unknown provider type: {provider_type}")
