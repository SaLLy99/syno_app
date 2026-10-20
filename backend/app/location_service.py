import json
import logging
from typing import List, Optional
import httpx
from sqlalchemy.orm import Session, joinedload

from app import models

logger = logging.getLogger(__name__)

NOMINATIM_URL = "https://nominatim.openstreetmap.org/search"
REST_COUNTRIES_URL = "https://restcountries.com/v3.1/all?fields=name,capital,latlng,cca2"

MAJOR_CITIES = {
    "USA": [
        ("New York", 40.7128, -74.0060, "-05:00"), ("Los Angeles", 34.0522, -118.2437, "-08:00"),
        ("Chicago", 41.8781, -87.6298, "-06:00"), ("Houston", 29.7604, -95.3698, "-06:00"),
        ("Phoenix", 33.4484, -112.0740, "-07:00"), ("San Francisco", 37.7749, -122.4194, "-08:00"),
        ("Seattle", 47.6062, -122.3321, "-08:00"), ("Boston", 42.3601, -71.0589, "-05:00"),
        ("Miami", 25.7617, -80.1918, "-05:00"), ("Atlanta", 33.7490, -84.3880, "-05:00"),
        ("Denver", 39.7392, -104.9903, "-07:00"), ("Austin", 30.2672, -97.7431, "-06:00"),
        ("Dallas", 32.7767, -96.7970, "-06:00"), ("Nashville", 36.1627, -86.7816, "-06:00"),
        ("Portland", 45.5152, -122.6784, "-08:00"), ("Las Vegas", 36.1699, -115.1398, "-08:00"),
        ("San Diego", 32.7157, -117.1611, "-08:00"), ("Philadelphia", 39.9526, -75.1652, "-05:00"),
        ("Washington DC", 38.9072, -77.0369, "-05:00"), ("Detroit", 42.3314, -83.0458, "-05:00"),
    ],
    "UK": [
        ("London", 51.5074, -0.1278, "+00:00"), ("Manchester", 53.4808, -2.2426, "+00:00"),
        ("Birmingham", 52.4862, -1.8904, "+00:00"), ("Edinburgh", 55.9533, -3.1883, "+00:00"),
        ("Glasgow", 55.8642, -4.2518, "+00:00"), ("Liverpool", 53.4084, -2.9916, "+00:00"),
        ("Bristol", 51.4545, -2.5879, "+00:00"), ("Leeds", 53.8008, -1.5491, "+00:00"),
    ],
    "France": [
        ("Paris", 48.8566, 2.3522, "+01:00"), ("Marseille", 43.2965, 5.3698, "+01:00"),
        ("Lyon", 45.7640, 4.8357, "+01:00"), ("Toulouse", 43.6047, 1.4442, "+01:00"),
        ("Nice", 43.7102, 7.2620, "+01:00"), ("Strasbourg", 48.5734, 7.7521, "+01:00"),
        ("Bordeaux", 44.8378, -0.5792, "+01:00"), ("Nantes", 47.2184, -1.5536, "+01:00"),
    ],
    "Japan": [
        ("Tokyo", 35.6762, 139.6503, "+09:00"), ("Osaka", 34.6937, 135.5023, "+09:00"),
        ("Kyoto", 35.0116, 135.7681, "+09:00"), ("Yokohama", 35.4437, 139.6380, "+09:00"),
        ("Nagoya", 35.1815, 136.9066, "+09:00"), ("Sapporo", 43.0618, 141.3545, "+09:00"),
        ("Fukuoka", 33.5904, 130.4017, "+09:00"), ("Kobe", 34.6901, 135.1956, "+09:00"),
    ],
    "Germany": [
        ("Berlin", 52.5200, 13.4050, "+01:00"), ("Munich", 48.1351, 11.5820, "+01:00"),
        ("Hamburg", 53.5511, 9.9937, "+01:00"), ("Frankfurt", 50.1109, 8.6821, "+01:00"),
        ("Cologne", 50.9375, 6.9603, "+01:00"), ("Stuttgart", 48.7758, 9.1829, "+01:00"),
        ("Düsseldorf", 51.2277, 6.7735, "+01:00"), ("Dortmund", 51.5136, 7.4653, "+01:00"),
    ],
    "Canada": [
        ("Toronto", 43.6532, -79.3832, "-05:00"), ("Vancouver", 49.2827, -123.1207, "-08:00"),
        ("Montreal", 45.5017, -73.5673, "-05:00"), ("Calgary", 51.0447, -114.0719, "-07:00"),
        ("Ottawa", 45.4215, -75.6972, "-05:00"), ("Edmonton", 53.5461, -113.4938, "-07:00"),
        ("Quebec City", 46.8139, -71.2080, "-05:00"), ("Winnipeg", 49.8951, -97.1384, "-06:00"),
    ],
    "Australia": [
        ("Sydney", -33.8688, 151.2093, "+10:00"), ("Melbourne", -37.8136, 144.9631, "+10:00"),
        ("Brisbane", -27.4698, 153.0251, "+10:00"), ("Perth", -31.9505, 115.8605, "+08:00"),
        ("Adelaide", -34.9285, 138.6007, "+09:30"), ("Gold Coast", -28.0167, 153.4000, "+10:00"),
        ("Canberra", -35.2809, 149.1300, "+10:00"), ("Newcastle", -32.9283, 151.7817, "+10:00"),
    ],
    "Georgia": [
        ("Tbilisi", 41.7151, 44.8271, "+04:00"), ("Batumi", 41.6168, 41.6367, "+04:00"),
        ("Kutaisi", 42.2679, 42.7180, "+04:00"), ("Rustavi", 41.5381, 44.9704, "+04:00"),
        ("Gori", 41.9814, 44.1124, "+04:00"), ("Zugdidi", 42.5063, 41.8664, "+04:00"),
    ],
    "Turkey": [
        ("Istanbul", 41.0082, 28.9784, "+03:00"), ("Ankara", 39.9334, 32.8597, "+03:00"),
        ("Izmir", 38.4189, 27.1287, "+03:00"), ("Antalya", 36.8969, 30.7133, "+03:00"),
        ("Bursa", 40.1885, 29.0610, "+03:00"), ("Adana", 37.0000, 35.3213, "+03:00"),
        ("Gaziantep", 37.0662, 37.3833, "+03:00"), ("Konya", 37.8746, 32.4932, "+03:00"),
    ],
    "Italy": [
        ("Rome", 41.9028, 12.4964, "+01:00"), ("Milan", 45.4642, 9.1900, "+01:00"),
        ("Naples", 40.8518, 14.2681, "+01:00"), ("Turin", 45.0703, 7.6869, "+01:00"),
        ("Palermo", 38.1157, 13.3615, "+01:00"), ("Genoa", 44.4056, 8.9463, "+01:00"),
        ("Florence", 43.7696, 11.2558, "+01:00"), ("Bologna", 44.4949, 11.3426, "+01:00"),
    ],
    "Spain": [
        ("Barcelona", 41.3874, 2.1686, "+01:00"), ("Madrid", 40.4168, -3.7038, "+01:00"),
        ("Valencia", 39.4699, -0.3763, "+01:00"), ("Seville", 37.3891, -5.9845, "+01:00"),
        ("Bilbao", 43.2630, -2.9350, "+01:00"), ("Málaga", 36.7213, -4.4214, "+01:00"),
        ("Zaragoza", 41.6488, -0.8891, "+01:00"), ("Las Palmas", 28.1235, -15.4363, "+00:00"),
    ],
    "Brazil": [
        ("São Paulo", -23.5505, -46.6333, "-03:00"), ("Rio de Janeiro", -22.9068, -43.1729, "-03:00"),
        ("Brasília", -15.7975, -47.8919, "-03:00"), ("Salvador", -12.9714, -38.5124, "-03:00"),
        ("Fortaleza", -3.7172, -38.5433, "-03:00"), ("Belo Horizonte", -19.9167, -43.9345, "-03:00"),
        ("Manaus", -3.1190, -60.0217, "-04:00"), ("Curitiba", -25.4284, -49.2733, "-03:00"),
    ],
    "India": [
        ("Mumbai", 19.0760, 72.8777, "+05:30"), ("Delhi", 28.7041, 77.1025, "+05:30"),
        ("Bangalore", 12.9716, 77.5946, "+05:30"), ("Chennai", 13.0827, 80.2707, "+05:30"),
        ("Kolkata", 22.5726, 88.3639, "+05:30"), ("Hyderabad", 17.3850, 78.4867, "+05:30"),
        ("Pune", 18.5204, 73.8567, "+05:30"), ("Ahmedabad", 23.0225, 72.5714, "+05:30"),
    ],
    "South Korea": [
        ("Seoul", 37.5665, 126.9780, "+09:00"), ("Busan", 35.1796, 129.0756, "+09:00"),
        ("Incheon", 37.4563, 126.7052, "+09:00"), ("Daegu", 35.8714, 128.6014, "+09:00"),
        ("Daejeon", 36.3504, 127.3845, "+09:00"), ("Gwangju", 35.1595, 126.8526, "+09:00"),
    ],
    "Israel": [
        ("Tel Aviv", 32.0853, 34.7818, "+02:00"), ("Jerusalem", 31.7683, 35.2137, "+02:00"),
        ("Haifa", 32.7940, 34.9896, "+02:00"), ("Beer Sheva", 31.2530, 34.7915, "+02:00"),
    ],
    "Russia": [
        ("Moscow", 55.7558, 37.6173, "+03:00"), ("Saint Petersburg", 59.9343, 30.3351, "+03:00"),
        ("Novosibirsk", 55.0084, 82.9357, "+07:00"), ("Yekaterinburg", 56.8389, 60.6057, "+05:00"),
        ("Kazan", 55.8304, 49.0661, "+03:00"), ("Nizhny Novgorod", 56.2965, 43.9361, "+03:00"),
    ],
    "China": [
        ("Beijing", 39.9042, 116.4074, "+08:00"), ("Shanghai", 31.2304, 121.4737, "+08:00"),
        ("Guangzhou", 23.1291, 113.2644, "+08:00"), ("Shenzhen", 22.5431, 114.0579, "+08:00"),
        ("Chengdu", 30.5728, 104.0668, "+08:00"), ("Hangzhou", 30.2741, 120.1551, "+08:00"),
        ("Wuhan", 30.5928, 114.3055, "+08:00"), ("Xi'an", 34.3416, 108.9398, "+08:00"),
    ],
    "Thailand": [
        ("Bangkok", 13.7563, 100.5018, "+07:00"), ("Chiang Mai", 18.7883, 98.9853, "+07:00"),
        ("Phuket", 7.8804, 98.3923, "+07:00"), ("Pattaya", 12.9236, 100.8825, "+07:00"),
        ("Nonthaburi", 13.8621, 100.5143, "+07:00"), ("Hat Yai", 7.0000, 100.4747, "+07:00"),
    ],
    "Netherlands": [
        ("Amsterdam", 52.3676, 4.9041, "+01:00"), ("Rotterdam", 51.9244, 4.4777, "+01:00"),
        ("The Hague", 52.0705, 4.3007, "+01:00"), ("Utrecht", 52.0907, 5.1214, "+01:00"),
        ("Eindhoven", 51.4416, 5.4697, "+01:00"), ("Groningen", 53.2194, 6.5665, "+01:00"),
    ],
    "Sweden": [
        ("Stockholm", 59.3293, 18.0686, "+01:00"), ("Gothenburg", 57.7089, 11.9746, "+01:00"),
        ("Malmö", 55.6050, 13.0038, "+01:00"), ("Uppsala", 59.8586, 17.6389, "+01:00"),
        ("Linköping", 58.4108, 15.6214, "+01:00"), ("Örebro", 59.2753, 15.2134, "+01:00"),
    ],
    "Norway": [
        ("Oslo", 59.9139, 10.7522, "+01:00"), ("Bergen", 60.3913, 5.3221, "+01:00"),
        ("Trondheim", 63.4305, 10.3951, "+01:00"), ("Stavanger", 58.9700, 5.7331, "+01:00"),
        ("Drammen", 59.7439, 10.2045, "+01:00"), ("Fredrikstad", 59.2181, 10.9283, "+01:00"),
    ],
    "Denmark": [
        ("Copenhagen", 55.6761, 12.5683, "+01:00"), ("Aarhus", 56.1629, 10.2039, "+01:00"),
        ("Odense", 55.4038, 10.4024, "+01:00"), ("Aalborg", 57.0488, 9.9217, "+01:00"),
    ],
    "Finland": [
        ("Helsinki", 60.1699, 24.9384, "+02:00"), ("Espoo", 60.2055, 24.6559, "+02:00"),
        ("Tampere", 61.4978, 23.7610, "+02:00"), ("Turku", 60.4518, 22.2666, "+02:00"),
        ("Oulu", 65.0121, 25.4651, "+02:00"), ("Jyväskylä", 62.2426, 25.7473, "+02:00"),
    ],
    "Poland": [
        ("Warsaw", 52.2297, 21.0122, "+01:00"), ("Kraków", 50.0647, 19.9450, "+01:00"),
        ("Łódź", 51.7592, 19.4560, "+01:00"), ("Wrocław", 51.1079, 17.0385, "+01:00"),
        ("Poznań", 52.4064, 16.9252, "+01:00"), ("Gdańsk", 54.3520, 18.6466, "+01:00"),
    ],
    "Czech Republic": [
        ("Prague", 50.0755, 14.4378, "+01:00"), ("Brno", 49.1951, 16.6068, "+01:00"),
        ("Ostrava", 49.8209, 18.2625, "+01:00"), ("Plzeň", 49.7384, 13.3736, "+01:00"),
    ],
    "Austria": [
        ("Vienna", 48.2082, 16.3738, "+01:00"), ("Graz", 47.0707, 15.4395, "+01:00"),
        ("Linz", 48.3069, 14.2858, "+01:00"), ("Salzburg", 47.8095, 13.0550, "+01:00"),
        ("Innsbruck", 47.2692, 11.4041, "+01:00"),
    ],
    "Belgium": [
        ("Brussels", 50.8503, 4.3517, "+01:00"), ("Antwerp", 51.2194, 4.4025, "+01:00"),
        ("Ghent", 51.0543, 3.7174, "+01:00"), ("Liège", 50.6326, 5.5797, "+01:00"),
    ],
    "Portugal": [
        ("Lisbon", 38.7223, -9.1393, "+00:00"), ("Porto", 41.1579, -8.6291, "+00:00"),
        ("Faro", 37.0194, -7.9304, "+00:00"), ("Coimbra", 40.2033, -8.4103, "+00:00"),
    ],
    "Greece": [
        ("Athens", 37.9838, 23.7275, "+02:00"), ("Thessaloniki", 40.6401, 22.9444, "+02:00"),
        ("Patras", 38.2466, 21.7346, "+02:00"), ("Heraklion", 35.3387, 25.1442, "+02:00"),
    ],
    "Ireland": [
        ("Dublin", 53.3498, -6.2603, "+00:00"), ("Cork", 51.8969, -8.4863, "+00:00"),
        ("Galway", 53.2707, -9.0568, "+00:00"), ("Limerick", 52.6638, -8.6267, "+00:00"),
    ],
    "New Zealand": [
        ("Auckland", -36.8485, 174.7633, "+12:00"), ("Wellington", -41.2865, 174.7762, "+12:00"),
        ("Christchurch", -43.5321, 172.6362, "+12:00"), ("Hamilton", -37.7870, 175.2793, "+12:00"),
    ],
    "Mexico": [
        ("Mexico City", 19.4326, -99.1332, "-06:00"), ("Guadalajara", 20.6597, -103.3496, "-06:00"),
        ("Monterrey", 25.6866, -100.3161, "-06:00"), ("Cancún", 21.1619, -86.8515, "-05:00"),
        ("Puebla", 19.0414, -98.2063, "-06:00"), ("Tijuana", 32.5149, -117.0382, "-08:00"),
    ],
    "Argentina": [
        ("Buenos Aires", -34.6037, -58.3816, "-03:00"), ("Córdoba", -31.4201, -64.1888, "-03:00"),
        ("Rosario", -32.9468, -60.6393, "-03:00"), ("Mendoza", -32.8895, -68.8458, "-03:00"),
    ],
    "South Africa": [
        ("Cape Town", -33.9249, 18.4241, "+02:00"), ("Johannesburg", -26.2041, 28.0473, "+02:00"),
        ("Durban", -29.8587, 31.0218, "+02:00"), ("Pretoria", -25.7479, 28.2293, "+02:00"),
        ("Port Elizabeth", -33.9608, 25.6022, "+02:00"),
    ],
    "Egypt": [
        ("Cairo", 30.0444, 31.2357, "+02:00"), ("Alexandria", 31.2001, 29.9187, "+02:00"),
        ("Giza", 30.0131, 31.2089, "+02:00"), ("Luxor", 25.6872, 32.6396, "+02:00"),
    ],
    "Nigeria": [
        ("Lagos", 6.5244, 3.3792, "+01:00"), ("Abuja", 9.0579, 7.4951, "+01:00"),
        ("Kano", 12.0022, 8.5920, "+01:00"), ("Ibadan", 7.3775, 3.9470, "+01:00"),
    ],
    "Kenya": [
        ("Nairobi", -1.2921, 36.8219, "+03:00"), ("Mombasa", -4.0435, 39.6682, "+03:00"),
        ("Kisumu", -0.1022, 34.7617, "+03:00"), ("Nakuru", -0.3031, 36.0800, "+03:00"),
    ],
    "Morocco": [
        ("Casablanca", 33.5731, -7.5898, "+01:00"), ("Rabat", 34.0209, -6.8416, "+01:00"),
        ("Marrakech", 31.6295, -7.9811, "+01:00"), ("Fez", 34.0331, -5.0003, "+01:00"),
    ],
    "Armenia": [
        ("Yerevan", 40.1792, 44.4991, "+04:00"), ("Gyumri", 40.7929, 43.8465, "+04:00"),
        ("Vanadzor", 40.8128, 44.4883, "+04:00"), ("Vagharshapat", 40.1631, 44.2966, "+04:00"),
    ],
    "Azerbaijan": [
        ("Baku", 40.4093, 49.8671, "+04:00"), ("Ganja", 40.6828, 46.3606, "+04:00"),
        ("Sumqayit", 40.5855, 49.6317, "+04:00"), ("Mingachevir", 40.7700, 47.0489, "+04:00"),
    ],
    "Ukraine": [
        ("Kyiv", 50.4501, 30.5234, "+02:00"), ("Kharkiv", 49.9935, 36.2304, "+02:00"),
        ("Odesa", 46.4825, 30.7233, "+02:00"), ("Dnipro", 48.4647, 35.0462, "+02:00"),
        ("Lviv", 49.8397, 24.0297, "+02:00"), ("Zaporizhzhia", 47.8388, 35.1396, "+02:00"),
    ],
    "Romania": [
        ("Bucharest", 44.4268, 26.1025, "+02:00"), ("Cluj-Napoca", 46.7712, 23.6236, "+02:00"),
        ("Timișoara", 45.7489, 21.2087, "+02:00"), ("Iași", 47.1585, 27.6014, "+02:00"),
        ("Constanța", 44.1598, 28.6348, "+02:00"),
    ],
    "Bulgaria": [
        ("Sofia", 42.6977, 23.3219, "+02:00"), ("Plovdiv", 42.1354, 24.7453, "+02:00"),
        ("Varna", 43.2141, 27.9147, "+02:00"), ("Burgas", 42.5048, 27.4626, "+02:00"),
    ],
    "Serbia": [
        ("Belgrade", 44.7866, 20.4489, "+01:00"), ("Novi Sad", 45.2671, 19.8335, "+01:00"),
        ("Niš", 43.3209, 21.8958, "+01:00"), ("Kragujevac", 44.0128, 20.9283, "+01:00"),
    ],
    "Croatia": [
        ("Zagreb", 45.8150, 15.9819, "+01:00"), ("Split", 43.5081, 16.4402, "+01:00"),
        ("Rijeka", 45.3271, 14.4422, "+01:00"), ("Osijek", 45.5550, 18.6950, "+01:00"),
    ],
    "Hungary": [
        ("Budapest", 47.4979, 19.0402, "+01:00"), ("Debrecen", 47.5316, 21.6273, "+01:00"),
        ("Szeged", 46.2530, 20.1414, "+01:00"), ("Miskolc", 48.1035, 20.7784, "+01:00"),
    ],
    "Estonia": [
        ("Tallinn", 59.4370, 24.7536, "+02:00"), ("Tartu", 58.3780, 26.7290, "+02:00"),
    ],
    "Latvia": [
        ("Riga", 56.9496, 24.1052, "+02:00"), ("Daugavpils", 55.8714, 26.5161, "+02:00"),
        ("Liepāja", 56.5047, 21.0109, "+02:00"),
    ],
    "Lithuania": [
        ("Vilnius", 54.6872, 25.2797, "+02:00"), ("Kaunas", 54.8985, 23.9036, "+02:00"),
        ("Klaipėda", 55.7033, 21.1443, "+02:00"),
    ],
    "Singapore": [
        ("Singapore", 1.3521, 103.8198, "+08:00"),
    ],
    "Philippines": [
        ("Manila", 14.5995, 120.9842, "+08:00"), ("Quezon City", 14.6760, 121.0437, "+08:00"),
        ("Cebu City", 10.3157, 123.8854, "+08:00"), ("Davao City", 7.1907, 125.4553, "+08:00"),
    ],
    "Indonesia": [
        ("Jakarta", -6.2088, 106.8456, "+07:00"), ("Surabaya", -7.2575, 112.7521, "+07:00"),
        ("Bandung", -6.9175, 107.6191, "+07:00"), ("Medan", 3.5952, 98.6722, "+07:00"),
        ("Bali (Denpasar)", -8.6500, 115.2167, "+08:00"),
    ],
    "Malaysia": [
        ("Kuala Lumpur", 3.1390, 101.6869, "+08:00"), ("George Town", 5.4141, 100.3288, "+08:00"),
        ("Johor Bahru", 1.4927, 103.7414, "+08:00"), ("Kota Kinabalu", 5.9804, 116.0735, "+08:00"),
    ],
    "Vietnam": [
        ("Ho Chi Minh City", 10.8231, 106.6297, "+07:00"), ("Hanoi", 21.0278, 105.8342, "+07:00"),
        ("Da Nang", 16.0544, 108.2022, "+07:00"), ("Hai Phong", 20.8449, 106.6881, "+07:00"),
    ],
    "Colombia": [
        ("Bogotá", 4.7110, -74.0721, "-05:00"), ("Medellín", 6.2476, -75.5658, "-05:00"),
        ("Cali", 3.4516, -76.5320, "-05:00"), ("Barranquilla", 10.9685, -74.7813, "-05:00"),
    ],
    "Chile": [
        ("Santiago", -33.4489, -70.6693, "-04:00"), ("Valparaíso", -33.0472, -71.6127, "-04:00"),
        ("Concepción", -36.8270, -73.0498, "-04:00"), ("Antofagasta", -23.6509, -70.3975, "-04:00"),
    ],
    "Peru": [
        ("Lima", -12.0464, -77.0428, "-05:00"), ("Arequipa", -16.4090, -71.5375, "-05:00"),
        ("Cusco", -13.5320, -71.9675, "-05:00"), ("Trujillo", -8.1091, -79.0215, "-05:00"),
    ],
    "Costa Rica": [
        ("San José", 9.9281, -84.0907, "-06:00"), ("Limón", 9.9907, -83.0359, "-06:00"),
        ("Alajuela", 10.0136, -84.2150, "-06:00"),
    ],
    "Cuba": [
        ("Havana", 23.1136, -82.3666, "-05:00"), ("Santiago de Cuba", 20.0174, -75.8268, "-05:00"),
        ("Camagüey", 21.3808, -77.9169, "-05:00"),
    ],
    "Dominican Republic": [
        ("Santo Domingo", 18.4861, -69.9312, "-04:00"), ("Santiago", 19.4517, -70.6970, "-04:00"),
        ("Punta Cana", 18.5601, -68.3725, "-04:00"),
    ],
    "Jamaica": [
        ("Kingston", 18.0179, -76.8099, "-05:00"), ("Montego Bay", 18.4762, -77.8939, "-05:00"),
    ],
    "Puerto Rico": [
        ("San Juan", 18.4655, -66.1057, "-04:00"), ("Bayamón", 18.3985, -66.1557, "-04:00"),
    ],
    "Qatar": [
        ("Doha", 25.2854, 51.5310, "+03:00"), ("Al Wakrah", 25.1716, 51.6000, "+03:00"),
    ],
    "UAE": [
        ("Dubai", 25.2048, 55.2708, "+04:00"), ("Abu Dhabi", 24.4539, 54.3773, "+04:00"),
        ("Sharjah", 25.3573, 55.3908, "+04:00"),
    ],
    "Saudi Arabia": [
        ("Riyadh", 24.7136, 46.6753, "+03:00"), ("Jeddah", 21.4858, 39.1925, "+03:00"),
        ("Mecca", 21.3891, 39.8579, "+03:00"), ("Medina", 24.4709, 39.6122, "+03:00"),
    ],
    "Lebanon": [
        ("Beirut", 33.8938, 35.5018, "+02:00"), ("Tripoli", 34.4333, 35.8333, "+02:00"),
        ("Sidon", 33.5600, 35.3714, "+02:00"),
    ],
    "Jordan": [
        ("Amman", 31.9454, 35.9284, "+02:00"), ("Zarqa", 32.0833, 36.0833, "+02:00"),
        ("Irbid", 32.5556, 35.8500, "+02:00"),
    ],
    "Iran": [
        ("Tehran", 35.6892, 51.3890, "+03:30"), ("Isfahan", 32.6546, 51.6680, "+03:30"),
        ("Mashhad", 36.2972, 59.6067, "+03:30"), ("Shiraz", 29.5918, 52.5836, "+03:30"),
    ],
    "Pakistan": [
        ("Karachi", 24.8607, 67.0011, "+05:00"), ("Lahore", 31.5204, 74.3587, "+05:00"),
        ("Islamabad", 33.6844, 73.0479, "+05:00"), ("Faisalabad", 31.4504, 73.1350, "+05:00"),
    ],
    "Bangladesh": [
        ("Dhaka", 23.8103, 90.4125, "+06:00"), ("Chittagong", 22.3569, 91.7832, "+06:00"),
        ("Khulna", 22.8456, 89.5403, "+06:00"),
    ],
    "Sri Lanka": [
        ("Colombo", 6.9271, 79.8612, "+05:30"), ("Kandy", 7.2906, 80.6337, "+05:30"),
        ("Galle", 6.0355, 80.2210, "+05:30"),
    ],
    "Nepal": [
        ("Kathmandu", 27.7172, 85.3240, "+05:45"), ("Pokhara", 28.2096, 83.9856, "+05:45"),
    ],
    "Cambodia": [
        ("Phnom Penh", 11.5564, 104.9282, "+07:00"), ("Siem Reap", 13.3671, 103.8448, "+07:00"),
    ],
    "Mongolia": [
        ("Ulaanbaatar", 47.8864, 106.9057, "+08:00"), ("Erdenet", 49.0833, 104.1500, "+08:00"),
    ],
    "Kazakhstan": [
        ("Astana", 51.1694, 71.4491, "+06:00"), ("Almaty", 43.2220, 76.8512, "+06:00"),
        ("Shymkent", 42.3155, 69.5968, "+06:00"),
    ],
    "Uzbekistan": [
        ("Tashkent", 41.2995, 69.2401, "+05:00"), ("Samarkand", 39.6542, 66.9597, "+05:00"),
        ("Bukhara", 39.7747, 64.4286, "+05:00"),
    ],
    "Belarus": [
        ("Minsk", 53.9006, 27.5590, "+03:00"), ("Gomel", 52.4345, 30.9754, "+03:00"),
        ("Mogilev", 53.9168, 30.3449, "+03:00"),
    ],
    "Moldova": [
        ("Chișinău", 47.0105, 28.8638, "+02:00"), ("Tiraspol", 46.8619, 29.6169, "+02:00"),
    ],
    "North Macedonia": [
        ("Skopje", 41.9973, 21.4280, "+01:00"), ("Bitola", 41.0297, 21.3292, "+01:00"),
    ],
    "Iceland": [
        ("Reykjavik", 64.1466, -21.9426, "+00:00"),
    ],
    "Luxembourg": [
        ("Luxembourg City", 49.6117, 6.1319, "+01:00"),
    ],
    "Cyprus": [
        ("Nicosia", 35.1856, 33.3823, "+02:00"), ("Limassol", 34.7071, 33.0226, "+02:00"),
    ],
    "Hong Kong": [
        ("Hong Kong", 22.3193, 114.1694, "+08:00"),
    ],
    "Taiwan": [
        ("Taipei", 25.0330, 121.5654, "+08:00"), ("Kaohsiung", 22.6273, 120.3014, "+08:00"),
        ("Taichung", 24.1477, 120.6736, "+08:00"),
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


def backfill_location_coords(db: Session) -> dict:
    """Backfill latitude, longitude, and timezone for existing locations that are missing them."""
    cities_without_coords = db.query(models.Location).filter(
        models.Location.type == "city",
        (models.Location.latitude == None) | (models.Location.longitude == None),
    ).all()

    updated = 0
    for loc in cities_without_coords:
        for country_name, cities in MAJOR_CITIES.items():
            for city_name, lat, lon, tz in cities:
                if loc.name.lower() == city_name.lower():
                    loc.latitude = lat
                    loc.longitude = lon
                    if not loc.timezone:
                        loc.timezone = tz
                    updated += 1
                    break
            if loc.latitude is not None:
                break

    countries_without_coords = db.query(models.Location).filter(
        models.Location.type == "country",
        (models.Location.latitude == None) | (models.Location.longitude == None),
    ).all()

    for loc in countries_without_coords:
        for country_name, cities in MAJOR_CITIES.items():
            if loc.name.lower() == country_name.lower():
                if cities:
                    loc.latitude = cities[0][1]
                    loc.longitude = cities[0][2]
                    updated += 1
                break

    db.commit()
    return {"status": "backfilled", "updated": updated, "remaining_without_coords": db.query(models.Location).filter(
        (models.Location.latitude == None) | (models.Location.longitude == None)
    ).count()}


async def resolve_location_from_nominatim(name: str) -> Optional[dict]:
    """Resolve a location name to lat/lon using Nominatim OpenStreetMap."""
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.get(
                NOMINATIM_URL,
                params={"q": name, "format": "json", "limit": 1},
                headers={"User-Agent": "syno_app/1.0"},
            )
            if resp.status_code != 200:
                logger.warning(f"Nominatim returned {resp.status_code} for '{name}'")
                return None

            data = resp.json()
            if not data:
                logger.warning(f"Nominatim found no results for '{name}'")
                return None

            result = data[0]
            lat = float(result["lat"])
            lon = float(result["lon"])

            return {
                "latitude": lat,
                "longitude": lon,
                "timezone": "+00:00",
                "display_name": result.get("display_name", name),
            }

    except Exception as e:
        logger.error(f"Nominatim resolve failed for '{name}': {e}")
        return None


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
            for city_data in major_cities:
                city_name = city_data[0]
                city_lat = city_data[1]
                city_lon = city_data[2]
                city_tz = city_data[3] if len(city_data) > 3 else None
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
                        timezone=city_tz,
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
                    "timezone": loc.timezone,
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
