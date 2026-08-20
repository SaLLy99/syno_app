import logging
from typing import List, Optional
import httpx
from sqlalchemy.orm import Session, joinedload

from app import models

logger = logging.getLogger(__name__)

REST_COUNTRIES_URL = "https://restcountries.com/v3.1/all?fields=name,capital,latlng,cca2"

MAJOR_CITIES = {
    "USA": [
        ("New York", 40.7128, -74.0060), ("Los Angeles", 34.0522, -118.2437),
        ("Chicago", 41.8781, -87.6298), ("Houston", 29.7604, -95.3698),
        ("Phoenix", 33.4484, -112.0740), ("San Francisco", 37.7749, -122.4194),
        ("Seattle", 47.6062, -122.3321), ("Boston", 42.3601, -71.0589),
        ("Miami", 25.7617, -80.1918), ("Atlanta", 33.7490, -84.3880),
        ("Denver", 39.7392, -104.9903), ("Austin", 30.2672, -97.7431),
        ("Dallas", 32.7767, -96.7970), ("Nashville", 36.1627, -86.7816),
        ("Portland", 45.5152, -122.6784), ("Las Vegas", 36.1699, -115.1398),
        ("San Diego", 32.7157, -117.1611), ("Philadelphia", 39.9526, -75.1652),
        ("Washington DC", 38.9072, -77.0369), ("Detroit", 42.3314, -83.0458),
    ],
    "UK": [
        ("London", 51.5074, -0.1278), ("Manchester", 53.4808, -2.2426),
        ("Birmingham", 52.4862, -1.8904), ("Edinburgh", 55.9533, -3.1883),
        ("Glasgow", 55.8642, -4.2518), ("Liverpool", 53.4084, -2.9916),
        ("Bristol", 51.4545, -2.5879), ("Leeds", 53.8008, -1.5491),
    ],
    "France": [
        ("Paris", 48.8566, 2.3522), ("Marseille", 43.2965, 5.3698),
        ("Lyon", 45.7640, 4.8357), ("Toulouse", 43.6047, 1.4442),
        ("Nice", 43.7102, 7.2620), ("Strasbourg", 48.5734, 7.7521),
        ("Bordeaux", 44.8378, -0.5792), ("Nantes", 47.2184, -1.5536),
    ],
    "Japan": [
        ("Tokyo", 35.6762, 139.6503), ("Osaka", 34.6937, 135.5023),
        ("Kyoto", 35.0116, 135.7681), ("Yokohama", 35.4437, 139.6380),
        ("Nagoya", 35.1815, 136.9066), ("Sapporo", 43.0618, 141.3545),
        ("Fukuoka", 33.5904, 130.4017), ("Kobe", 34.6901, 135.1956),
    ],
    "Germany": [
        ("Berlin", 52.5200, 13.4050), ("Munich", 48.1351, 11.5820),
        ("Hamburg", 53.5511, 9.9937), ("Frankfurt", 50.1109, 8.6821),
        ("Cologne", 50.9375, 6.9603), ("Stuttgart", 48.7758, 9.1829),
        ("Düsseldorf", 51.2277, 6.7735), ("Dortmund", 51.5136, 7.4653),
    ],
    "Canada": [
        ("Toronto", 43.6532, -79.3832), ("Vancouver", 49.2827, -123.1207),
        ("Montreal", 45.5017, -73.5673), ("Calgary", 51.0447, -114.0719),
        ("Ottawa", 45.4215, -75.6972), ("Edmonton", 53.5461, -113.4938),
        ("Quebec City", 46.8139, -71.2080), ("Winnipeg", 49.8951, -97.1384),
    ],
    "Australia": [
        ("Sydney", -33.8688, 151.2093), ("Melbourne", -37.8136, 144.9631),
        ("Brisbane", -27.4698, 153.0251), ("Perth", -31.9505, 115.8605),
        ("Adelaide", -34.9285, 138.6007), ("Gold Coast", -28.0167, 153.4000),
        ("Canberra", -35.2809, 149.1300), ("Newcastle", -32.9283, 151.7817),
    ],
    "Georgia": [
        ("Tbilisi", 41.7151, 44.8271), ("Batumi", 41.6168, 41.6367),
        ("Kutaisi", 42.2679, 42.7180), ("Rustavi", 41.5381, 44.9704),
        ("Gori", 41.9814, 44.1124), ("Zugdidi", 42.5063, 41.8664),
    ],
    "Turkey": [
        ("Istanbul", 41.0082, 28.9784), ("Ankara", 39.9334, 32.8597),
        ("Izmir", 38.4189, 27.1287), ("Antalya", 36.8969, 30.7133),
        ("Bursa", 40.1885, 29.0610), ("Adana", 37.0000, 35.3213),
        ("Gaziantep", 37.0662, 37.3833), ("Konya", 37.8746, 32.4932),
    ],
    "Italy": [
        ("Rome", 41.9028, 12.4964), ("Milan", 45.4642, 9.1900),
        ("Naples", 40.8518, 14.2681), ("Turin", 45.0703, 7.6869),
        ("Palermo", 38.1157, 13.3615), ("Genoa", 44.4056, 8.9463),
        ("Florence", 43.7696, 11.2558), ("Bologna", 44.4949, 11.3426),
    ],
    "Spain": [
        ("Barcelona", 41.3874, 2.1686), ("Madrid", 40.4168, -3.7038),
        ("Valencia", 39.4699, -0.3763), ("Seville", 37.3891, -5.9845),
        ("Bilbao", 43.2630, -2.9350), ("Málaga", 36.7213, -4.4214),
        ("Zaragoza", 41.6488, -0.8891), ("Las Palmas", 28.1235, -15.4363),
    ],
    "Brazil": [
        ("São Paulo", -23.5505, -46.6333), ("Rio de Janeiro", -22.9068, -43.1729),
        ("Brasília", -15.7975, -47.8919), ("Salvador", -12.9714, -38.5124),
        ("Fortaleza", -3.7172, -38.5433), ("Belo Horizonte", -19.9167, -43.9345),
        ("Manaus", -3.1190, -60.0217), ("Curitiba", -25.4284, -49.2733),
    ],
    "India": [
        ("Mumbai", 19.0760, 72.8777), ("Delhi", 28.7041, 77.1025),
        ("Bangalore", 12.9716, 77.5946), ("Chennai", 13.0827, 80.2707),
        ("Kolkata", 22.5726, 88.3639), ("Hyderabad", 17.3850, 78.4867),
        ("Pune", 18.5204, 73.8567), ("Ahmedabad", 23.0225, 72.5714),
    ],
    "South Korea": [
        ("Seoul", 37.5665, 126.9780), ("Busan", 35.1796, 129.0756),
        ("Incheon", 37.4563, 126.7052), ("Daegu", 35.8714, 128.6014),
        ("Daejeon", 36.3504, 127.3845), ("Gwangju", 35.1595, 126.8526),
    ],
    "Israel": [
        ("Tel Aviv", 32.0853, 34.7818), ("Jerusalem", 31.7683, 35.2137),
        ("Haifa", 32.7940, 34.9896), ("Beer Sheva", 31.2530, 34.7915),
    ],
    "Russia": [
        ("Moscow", 55.7558, 37.6173), ("Saint Petersburg", 59.9343, 30.3351),
        ("Novosibirsk", 55.0084, 82.9357), ("Yekaterinburg", 56.8389, 60.6057),
        ("Kazan", 55.8304, 49.0661), ("Nizhny Novgorod", 56.2965, 43.9361),
    ],
    "China": [
        ("Beijing", 39.9042, 116.4074), ("Shanghai", 31.2304, 121.4737),
        ("Guangzhou", 23.1291, 113.2644), ("Shenzhen", 22.5431, 114.0579),
        ("Chengdu", 30.5728, 104.0668), ("Hangzhou", 30.2741, 120.1551),
        ("Wuhan", 30.5928, 114.3055), ("Xi'an", 34.3416, 108.9398),
    ],
    "Thailand": [
        ("Bangkok", 13.7563, 100.5018), ("Chiang Mai", 18.7883, 98.9853),
        ("Phuket", 7.8804, 98.3923), ("Pattaya", 12.9236, 100.8825),
        ("Nonthaburi", 13.8621, 100.5143), ("Hat Yai", 7.0000, 100.4747),
    ],
    "Netherlands": [
        ("Amsterdam", 52.3676, 4.9041), ("Rotterdam", 51.9244, 4.4777),
        ("The Hague", 52.0705, 4.3007), ("Utrecht", 52.0907, 5.1214),
        ("Eindhoven", 51.4416, 5.4697), ("Groningen", 53.2194, 6.5665),
    ],
    "Sweden": [
        ("Stockholm", 59.3293, 18.0686), ("Gothenburg", 57.7089, 11.9746),
        ("Malmö", 55.6050, 13.0038), ("Uppsala", 59.8586, 17.6389),
        ("Linköping", 58.4108, 15.6214), ("Örebro", 59.2753, 15.2134),
    ],
    "Norway": [
        ("Oslo", 59.9139, 10.7522), ("Bergen", 60.3913, 5.3221),
        ("Trondheim", 63.4305, 10.3951), ("Stavanger", 58.9700, 5.7331),
        ("Drammen", 59.7439, 10.2045), ("Fredrikstad", 59.2181, 10.9283),
    ],
    "Denmark": [
        ("Copenhagen", 55.6761, 12.5683), ("Aarhus", 56.1629, 10.2039),
        ("Odense", 55.4038, 10.4024), ("Aalborg", 57.0488, 9.9217),
    ],
    "Finland": [
        ("Helsinki", 60.1699, 24.9384), ("Espoo", 60.2055, 24.6559),
        ("Tampere", 61.4978, 23.7610), ("Turku", 60.4518, 22.2666),
        ("Oulu", 65.0121, 25.4651), ("Jyväskylä", 62.2426, 25.7473),
    ],
    "Poland": [
        ("Warsaw", 52.2297, 21.0122), ("Kraków", 50.0647, 19.9450),
        ("Łódź", 51.7592, 19.4560), ("Wrocław", 51.1079, 17.0385),
        ("Poznań", 52.4064, 16.9252), ("Gdańsk", 54.3520, 18.6466),
    ],
    "Czech Republic": [
        ("Prague", 50.0755, 14.4378), ("Brno", 49.1951, 16.6068),
        ("Ostrava", 49.8209, 18.2625), ("Plzeň", 49.7384, 13.3736),
    ],
    "Austria": [
        ("Vienna", 48.2082, 16.3738), ("Graz", 47.0707, 15.4395),
        ("Linz", 48.3069, 14.2858), ("Salzburg", 47.8095, 13.0550),
        ("Innsbruck", 47.2692, 11.4041),
    ],
    "Belgium": [
        ("Brussels", 50.8503, 4.3517), ("Antwerp", 51.2194, 4.4025),
        ("Ghent", 51.0543, 3.7174), ("Liège", 50.6326, 5.5797),
    ],
    "Portugal": [
        ("Lisbon", 38.7223, -9.1393), ("Porto", 41.1579, -8.6291),
        ("Faro", 37.0194, -7.9304), ("Coimbra", 40.2033, -8.4103),
    ],
    "Greece": [
        ("Athens", 37.9838, 23.7275), ("Thessaloniki", 40.6401, 22.9444),
        ("Patras", 38.2466, 21.7346), ("Heraklion", 35.3387, 25.1442),
    ],
    "Ireland": [
        ("Dublin", 53.3498, -6.2603), ("Cork", 51.8969, -8.4863),
        ("Galway", 53.2707, -9.0568), ("Limerick", 52.6638, -8.6267),
    ],
    "New Zealand": [
        ("Auckland", -36.8485, 174.7633), ("Wellington", -41.2865, 174.7762),
        ("Christchurch", -43.5321, 172.6362), ("Hamilton", -37.7870, 175.2793),
    ],
    "Mexico": [
        ("Mexico City", 19.4326, -99.1332), ("Guadalajara", 20.6597, -103.3496),
        ("Monterrey", 25.6866, -100.3161), ("Cancún", 21.1619, -86.8515),
        ("Puebla", 19.0414, -98.2063), ("Tijuana", 32.5149, -117.0382),
    ],
    "Argentina": [
        ("Buenos Aires", -34.6037, -58.3816), ("Córdoba", -31.4201, -64.1888),
        ("Rosario", -32.9468, -60.6393), ("Mendoza", -32.8895, -68.8458),
    ],
    "South Africa": [
        ("Cape Town", -33.9249, 18.4241), ("Johannesburg", -26.2041, 28.0473),
        ("Durban", -29.8587, 31.0218), ("Pretoria", -25.7479, 28.2293),
        ("Port Elizabeth", -33.9608, 25.6022),
    ],
    "Egypt": [
        ("Cairo", 30.0444, 31.2357), ("Alexandria", 31.2001, 29.9187),
        ("Giza", 30.0131, 31.2089), ("Luxor", 25.6872, 32.6396),
    ],
    "Nigeria": [
        ("Lagos", 6.5244, 3.3792), ("Abuja", 9.0579, 7.4951),
        ("Kano", 12.0022, 8.5920), ("Ibadan", 7.3775, 3.9470),
    ],
    "Kenya": [
        ("Nairobi", -1.2921, 36.8219), ("Mombasa", -4.0435, 39.6682),
        ("Kisumu", -0.1022, 34.7617), ("Nakuru", -0.3031, 36.0800),
    ],
    "Morocco": [
        ("Casablanca", 33.5731, -7.5898), ("Rabat", 34.0209, -6.8416),
        ("Marrakech", 31.6295, -7.9811), ("Fez", 34.0331, -5.0003),
    ],
    "Armenia": [
        ("Yerevan", 40.1792, 44.4991), ("Gyumri", 40.7929, 43.8465),
        ("Vanadzor", 40.8128, 44.4883), ("Vagharshapat", 40.1631, 44.2966),
    ],
    "Azerbaijan": [
        ("Baku", 40.4093, 49.8671), ("Ganja", 40.6828, 46.3606),
        ("Sumqayit", 40.5855, 49.6317), ("Mingachevir", 40.7700, 47.0489),
    ],
    "Ukraine": [
        ("Kyiv", 50.4501, 30.5234), ("Kharkiv", 49.9935, 36.2304),
        ("Odesa", 46.4825, 30.7233), ("Dnipro", 48.4647, 35.0462),
        ("Lviv", 49.8397, 24.0297), ("Zaporizhzhia", 47.8388, 35.1396),
    ],
    "Romania": [
        ("Bucharest", 44.4268, 26.1025), ("Cluj-Napoca", 46.7712, 23.6236),
        ("Timișoara", 45.7489, 21.2087), ("Iași", 47.1585, 27.6014),
        ("Constanța", 44.1598, 28.6348),
    ],
    "Bulgaria": [
        ("Sofia", 42.6977, 23.3219), ("Plovdiv", 42.1354, 24.7453),
        ("Varna", 43.2141, 27.9147), ("Burgas", 42.5048, 27.4626),
    ],
    "Serbia": [
        ("Belgrade", 44.7866, 20.4489), ("Novi Sad", 45.2671, 19.8335),
        ("Niš", 43.3209, 21.8958), ("Kragujevac", 44.0128, 20.9283),
    ],
    "Croatia": [
        ("Zagreb", 45.8150, 15.9819), ("Split", 43.5081, 16.4402),
        ("Rijeka", 45.3271, 14.4422), ("Osijek", 45.5550, 18.6950),
    ],
    "Hungary": [
        ("Budapest", 47.4979, 19.0402), ("Debrecen", 47.5316, 21.6273),
        ("Szeged", 46.2530, 20.1414), ("Miskolc", 48.1035, 20.7784),
    ],
    "Estonia": [
        ("Tallinn", 59.4370, 24.7536), ("Tartu", 58.3780, 26.7290),
    ],
    "Latvia": [
        ("Riga", 56.9496, 24.1052), ("Daugavpils", 55.8714, 26.5161),
        ("Liepāja", 56.5047, 21.0109),
    ],
    "Lithuania": [
        ("Vilnius", 54.6872, 25.2797), ("Kaunas", 54.8985, 23.9036),
        ("Klaipėda", 55.7033, 21.1443),
    ],
    "Singapore": [
        ("Singapore", 1.3521, 103.8198),
    ],
    "Philippines": [
        ("Manila", 14.5995, 120.9842), ("Quezon City", 14.6760, 121.0437),
        ("Cebu City", 10.3157, 123.8854), ("Davao City", 7.1907, 125.4553),
    ],
    "Indonesia": [
        ("Jakarta", -6.2088, 106.8456), ("Surabaya", -7.2575, 112.7521),
        ("Bandung", -6.9175, 107.6191), ("Medan", 3.5952, 98.6722),
        ("Bali (Denpasar)", -8.6500, 115.2167),
    ],
    "Malaysia": [
        ("Kuala Lumpur", 3.1390, 101.6869), ("George Town", 5.4141, 100.3288),
        ("Johor Bahru", 1.4927, 103.7414), ("Kota Kinabalu", 5.9804, 116.0735),
    ],
    "Vietnam": [
        ("Ho Chi Minh City", 10.8231, 106.6297), ("Hanoi", 21.0278, 105.8342),
        ("Da Nang", 16.0544, 108.2022), ("Hai Phong", 20.8449, 106.6881),
    ],
    "Colombia": [
        ("Bogotá", 4.7110, -74.0721), ("Medellín", 6.2476, -75.5658),
        ("Cali", 3.4516, -76.5320), ("Barranquilla", 10.9685, -74.7813),
    ],
    "Chile": [
        ("Santiago", -33.4489, -70.6693), ("Valparaíso", -33.0472, -71.6127),
        ("Concepción", -36.8270, -73.0498), ("Antofagasta", -23.6509, -70.3975),
    ],
    "Peru": [
        ("Lima", -12.0464, -77.0428), ("Arequipa", -16.4090, -71.5375),
        ("Cusco", -13.5320, -71.9675), ("Trujillo", -8.1091, -79.0215),
    ],
    "Costa Rica": [
        ("San José", 9.9281, -84.0907), ("Limón", 9.9907, -83.0359),
        ("Alajuela", 10.0136, -84.2150),
    ],
    "Cuba": [
        ("Havana", 23.1136, -82.3666), ("Santiago de Cuba", 20.0174, -75.8268),
        ("Camagüey", 21.3808, -77.9169),
    ],
    "Dominican Republic": [
        ("Santo Domingo", 18.4861, -69.9312), ("Santiago", 19.4517, -70.6970),
        ("Punta Cana", 18.5601, -68.3725),
    ],
    "Jamaica": [
        ("Kingston", 18.0179, -76.8099), ("Montego Bay", 18.4762, -77.8939),
    ],
    "Puerto Rico": [
        ("San Juan", 18.4655, -66.1057), ("Bayamón", 18.3985, -66.1557),
    ],
    "Qatar": [
        ("Doha", 25.2854, 51.5310), ("Al Wakrah", 25.1716, 51.6000),
    ],
    "UAE": [
        ("Dubai", 25.2048, 55.2708), ("Abu Dhabi", 24.4539, 54.3773),
        ("Sharjah", 25.3573, 55.3908),
    ],
    "Saudi Arabia": [
        ("Riyadh", 24.7136, 46.6753), ("Jeddah", 21.4858, 39.1925),
        ("Mecca", 21.3891, 39.8579), ("Medina", 24.4709, 39.6122),
    ],
    "Lebanon": [
        ("Beirut", 33.8938, 35.5018), ("Tripoli", 34.4333, 35.8333),
        ("Sidon", 33.5600, 35.3714),
    ],
    "Jordan": [
        ("Amman", 31.9454, 35.9284), ("Zarqa", 32.0833, 36.0833),
        ("Irbid", 32.5556, 35.8500),
    ],
    "Iran": [
        ("Tehran", 35.6892, 51.3890), ("Isfahan", 32.6546, 51.6680),
        ("Mashhad", 36.2972, 59.6067), ("Shiraz", 29.5918, 52.5836),
    ],
    "Pakistan": [
        ("Karachi", 24.8607, 67.0011), ("Lahore", 31.5204, 74.3587),
        ("Islamabad", 33.6844, 73.0479), ("Faisalabad", 31.4504, 73.1350),
    ],
    "Bangladesh": [
        ("Dhaka", 23.8103, 90.4125), ("Chittagong", 22.3569, 91.7832),
        ("Khulna", 22.8456, 89.5403),
    ],
    "Sri Lanka": [
        ("Colombo", 6.9271, 79.8612), ("Kandy", 7.2906, 80.6337),
        ("Galle", 6.0535, 80.2210),
    ],
    "Nepal": [
        ("Kathmandu", 27.7172, 85.3240), ("Pokhara", 28.2096, 83.9856),
    ],
    "Cambodia": [
        ("Phnom Penh", 11.5564, 104.9282), ("Siem Reap", 13.3671, 103.8448),
    ],
    "Mongolia": [
        ("Ulaanbaatar", 47.8864, 106.9057), ("Erdenet", 49.0833, 104.1500),
    ],
    "Kazakhstan": [
        ("Astana", 51.1694, 71.4491), ("Almaty", 43.2220, 76.8512),
        ("Shymkent", 42.3155, 69.5968),
    ],
    "Uzbekistan": [
        ("Tashkent", 41.2995, 69.2401), ("Samarkand", 39.6542, 66.9597),
        ("Bukhara", 39.7747, 64.4286),
    ],
    "Belarus": [
        ("Minsk", 53.9006, 27.5590), ("Gomel", 52.4345, 30.9754),
        ("Mogilev", 53.9168, 30.3449),
    ],
    "Moldova": [
        ("Chișinău", 47.0105, 28.8638), ("Tiraspol", 46.8619, 29.6169),
    ],
    "North Macedonia": [
        ("Skopje", 41.9973, 21.4280), ("Bitola", 41.0297, 21.3292),
    ],
    "Iceland": [
        ("Reykjavik", 64.1466, -21.9426),
    ],
    "Luxembourg": [
        ("Luxembourg City", 49.6117, 6.1319),
    ],
    "Cyprus": [
        ("Nicosia", 35.1856, 33.3823), ("Limassol", 34.7071, 33.0226),
    ],
    "Hong Kong": [
        ("Hong Kong", 22.3193, 114.1694),
    ],
    "Taiwan": [
        ("Taipei", 25.0330, 121.5654), ("Kaohsiung", 22.6273, 120.3014),
        ("Taichung", 24.1477, 120.6736),
    ],
}


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
    """Seed the locations table with countries, capitals, and major cities."""
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

            major_cities = MAJOR_CITIES.get(country_name, [])
            for city_name, city_lat, city_lon in major_cities:
                if city_name == capital:
                    continue
                city_existing = db.query(models.Location).filter(
                    models.Location.name == city_name,
                    models.Location.type == "city",
                    models.Location.parent_id == country_location.id,
                ).first()
                if not city_existing:
                    city_location = models.Location(
                        name=city_name,
                        type="city",
                        parent_id=country_location.id,
                        latitude=city_lat,
                        longitude=city_lon,
                        translation_key=f"profile.locations.{city_name.lower().replace(' ', '_').replace('.', '').replace('/', '_')}",
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
