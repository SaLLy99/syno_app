import hashlib
import json

from ..domain.models import BirthData, AstrologySystem


def generate_chart_cache_key(
    birth_data: BirthData,
    system: AstrologySystem,
) -> str:
    """Generate a deterministic cache key for birth chart calculations.

    The key is based on:
    - birth date
    - birth time
    - timezone
    - latitude
    - longitude
    - astrology system
    """
    key_data = {
        "date": birth_data.birth_date.isoformat(),
        "time": birth_data.birth_time.isoformat(),
        "tz": birth_data.timezone,
        "lat": birth_data.latitude,
        "lon": birth_data.longitude,
        "system": system.value,
    }

    key_str = json.dumps(key_data, sort_keys=True)
    return hashlib.sha256(key_str.encode()).hexdigest()


def generate_synastry_cache_key(
    person_a: BirthData,
    person_b: BirthData,
    system: AstrologySystem,
) -> str:
    """Generate a deterministic cache key for synastry calculations.

    Order-independent: person_a and person_b are sorted by birth date + time.
    """
    key_data_a = {
        "date": person_a.birth_date.isoformat(),
        "time": person_a.birth_time.isoformat(),
        "tz": person_a.timezone,
        "lat": person_a.latitude,
        "lon": person_a.longitude,
    }
    key_data_b = {
        "date": person_b.birth_date.isoformat(),
        "time": person_b.birth_time.isoformat(),
        "tz": person_b.timezone,
        "lat": person_b.latitude,
        "lon": person_b.longitude,
    }

    sorted_pair = sorted([key_data_a, key_data_b], key=lambda x: json.dumps(x, sort_keys=True))

    full_key = {
        "pair": sorted_pair,
        "system": system.value,
    }

    key_str = json.dumps(full_key, sort_keys=True)
    return hashlib.sha256(key_str.encode()).hexdigest()
