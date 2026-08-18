import logging
from typing import List, Optional
import httpx
from sqlalchemy.orm import Session, joinedload

from app import models

logger = logging.getLogger(__name__)

REST_COUNTRIES_URL = "https://restcountries.com/v3.1/all?fields=name,capital,latlng,cca2"


async def fetch_countries_from_api() -> List[dict]:
    """Fetch all countries with capitals and coordinates from REST Countries API."""
    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.get(REST_COUNTRIES_URL)
            response.raise_for_status()
            data = response.json()

            results = []
            for country in data:
                name = country.get("name", {}).get("common", "")
                capital_list = country.get("capital", [])
                capital = capital_list[0] if capital_list else None
                latlng = country.get("latlng", [])
                cca2 = country.get("cca2", "")

                if not name or not latlng:
                    continue

                lat = latlng[0] if len(latlng) > 0 else None
                lon = latlng[1] if len(latlng) > 1 else None

                results.append({
                    "country": name,
                    "country_code": cca2,
                    "capital": capital,
                    "latitude": lat,
                    "longitude": lon,
                })

            logger.info(f"Fetched {len(results)} countries from REST Countries API")
            return results

    except Exception as e:
        logger.error(f"Failed to fetch from REST Countries API: {e}")
        return []


async def seed_locations_from_api(db: Session) -> dict:
    """Seed the locations table with countries and their capitals from REST Countries API."""
    existing_count = db.query(models.Location).count()
    if existing_count > 0:
        return {"status": "already_seeded", "count": existing_count}

    countries = await fetch_countries_from_api()
    if not countries:
        return {"status": "api_failed", "count": 0}

    added_countries = 0
    added_cities = 0

    for item in countries:
        country_name = item["country"]
        capital = item["capital"]
        lat = item["latitude"]
        lon = item["longitude"]

        existing = db.query(models.Location).filter(
            models.Location.name == country_name,
            models.Location.type == "country"
        ).first()

        if not existing:
            country_location = models.Location(
                name=country_name,
                type="country",
                latitude=lat,
                longitude=lon,
                translation_key=f"profile.locations.{country_name.lower().replace(' ', '_')}",
            )
            db.add(country_location)
            db.flush()
            added_countries += 1

            if capital:
                city_location = models.Location(
                    name=capital,
                    type="city",
                    parent_id=country_location.id,
                    latitude=lat,
                    longitude=lon,
                    translation_key=f"profile.locations.{capital.lower().replace(' ', '_')}",
                )
                db.add(city_location)
                added_cities += 1

    db.commit()

    return {
        "status": "seeded",
        "countries": added_countries,
        "cities": added_cities,
        "total": added_countries + added_cities,
    }


async def search_locations_api(query: Optional[str] = None, db: Session = None) -> List[dict]:
    """Search locations. If DB has data, use it. Otherwise fetch from API."""
    if db:
        existing = db.query(models.Location).filter(
            models.Location.type == "city"
        ).count()

        if existing > 0:
            locations = db.query(models.Location).options(
                joinedload(models.Location.parent)
            ).filter(
                models.Location.type.ilike("city"),
                models.Location.parent_id.isnot(None),
            )
            if query:
                locations = locations.filter(
                    models.Location.name.ilike(f"%{query}%")
                )
            results = locations.limit(20).all()
            return [
                {
                    "id": loc.id,
                    "name": loc.name,
                    "type": loc.type,
                    "latitude": loc.latitude,
                    "longitude": loc.longitude,
                    "parent": {"id": loc.parent.id, "name": loc.parent.name} if loc.parent else None,
                }
                for loc in results
            ]

    countries = await fetch_countries_from_api()
    if query:
        query_lower = query.lower()
        countries = [
            c for c in countries
            if query_lower in c["country"].lower()
            or (c["capital"] and query_lower in c["capital"].lower())
        ]

    results = []
    for item in countries[:20]:
        results.append({
            "name": item["capital"] or item["country"],
            "type": "city",
            "latitude": item["latitude"],
            "longitude": item["longitude"],
            "parent": {"name": item["country"]},
        })

    return results
