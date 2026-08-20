-- Seed all major cities into locations table
-- First check what countries exist and get their IDs

-- Insert missing countries first
INSERT INTO locations (name, type, translation_key, latitude, longitude)
SELECT name, 'country', 
       'profile.locations.' || LOWER(REPLACE(name, ' ', '_')),
       latitude, longitude
FROM (VALUES
  ('USA', 39.8283, -98.5795),
  ('UK', 55.3781, -3.4360),
  ('France', 46.2276, 2.2137),
  ('Japan', 36.2048, 138.2529),
  ('Australia', -25.2744, 133.7751),
  ('Germany', 51.1657, 10.4515),
  ('Canada', 56.1304, -106.3468),
  ('Georgia', 42.3154, 43.3569),
  ('Turkey', 38.9637, 35.2433),
  ('Italy', 41.8719, 12.5674),
  ('Spain', 40.4637, -3.7492),
  ('Brazil', -14.2350, -51.9253),
  ('India', 20.5937, 78.9629),
  ('South Korea', 35.9078, 127.7669),
  ('Israel', 31.0461, 34.8516),
  ('Russia', 61.5240, 105.3188),
  ('China', 35.8617, 104.1954),
  ('Thailand', 15.8700, 100.9925),
  ('Netherlands', 52.1326, 5.2913),
  ('Sweden', 60.1282, 18.6435),
  ('Norway', 60.4720, 8.4689),
  ('Denmark', 56.2639, 9.5018),
  ('Finland', 61.9241, 25.7482),
  ('Poland', 51.9194, 19.1451),
  ('Czech Republic', 49.8175, 15.4730),
  ('Austria', 47.5162, 14.5501),
  ('Belgium', 50.5039, 4.4699),
  ('Portugal', 39.3999, -8.2245),
  ('Greece', 39.0742, 21.8243),
  ('Ireland', 53.1424, -7.6921),
  ('New Zealand', -40.9006, 174.8860),
  ('Mexico', 23.6345, -102.5528),
  ('Argentina', -38.4161, -63.6167),
  ('South Africa', -30.5595, 22.9375),
  ('Egypt', 26.8206, 30.8025),
  ('Nigeria', 9.0820, 8.6753),
  ('Kenya', -0.0236, 37.9062),
  ('Morocco', 31.7917, -7.0926),
  ('Armenia', 40.0691, 45.0382),
  ('Azerbaijan', 40.1431, 47.5769),
  ('Ukraine', 48.3794, 31.1656),
  ('Romania', 45.9432, 24.9668),
  ('Bulgaria', 42.7339, 25.4858),
  ('Serbia', 44.0165, 21.0059),
  ('Croatia', 45.1000, 15.2000),
  ('Hungary', 47.1625, 19.5033),
  ('Estonia', 58.5953, 25.0136),
  ('Latvia', 56.8796, 24.6032),
  ('Lithuania', 55.1694, 23.8813),
  ('Singapore', 1.3521, 103.8198),
  ('Philippines', 12.8797, 121.7740),
  ('Indonesia', -0.7893, 113.9213),
  ('Malaysia', 4.2105, 101.9758),
  ('Vietnam', 14.0583, 108.2772),
  ('Colombia', 4.5709, -74.2973),
  ('Chile', -35.6751, -71.5430),
  ('Peru', -9.1900, -75.0152),
  ('Costa Rica', 9.7489, -83.7534),
  ('Cuba', 21.5218, -77.7812),
  ('Dominican Republic', 18.7357, -70.1627),
  ('Jamaica', 18.1096, -77.2975),
  ('Puerto Rico', 18.2208, -66.5901),
  ('Qatar', 25.3548, 51.1839),
  ('UAE', 23.4241, 53.8478),
  ('Saudi Arabia', 23.8859, 45.0792),
  ('Lebanon', 33.8547, 35.8623),
  ('Jordan', 30.5852, 36.2384),
  ('Iran', 32.4279, 53.6880),
  ('Pakistan', 30.3753, 69.3451),
  ('Bangladesh', 23.6850, 90.3563),
  ('Sri Lanka', 7.8731, 80.7718),
  ('Nepal', 28.3949, 84.1240),
  ('Cambodia', 12.5657, 104.9910),
  ('Mongolia', 46.8625, 103.8467),
  ('Kazakhstan', 48.0196, 66.9237),
  ('Uzbekistan', 41.3775, 64.5853),
  ('Belarus', 53.7098, 27.9534),
  ('Moldova', 47.4116, 28.3699),
  ('North Macedonia', 41.5122, 21.7453),
  ('Iceland', 64.9631, -19.0208),
  ('Luxembourg', 49.8153, 6.1296),
  ('Cyprus', 35.1264, 33.4299),
  ('Hong Kong', 22.3193, 114.1694),
  ('Taiwan', 23.6978, 120.9605)
) AS v(name, latitude, longitude)
WHERE NOT EXISTS (SELECT 1 FROM locations WHERE name = v.name AND type = 'country');

-- Now insert cities for each country
-- USA
INSERT INTO locations (name, type, parent_id, translation_key, latitude, longitude)
SELECT v.name, 'city', l.id, 
       'profile.locations.' || LOWER(REPLACE(REPLACE(REPLACE(v.name, ' ', '_'), '.', ''), '/', '_')),
       v.lat, v.lon
FROM (VALUES
  ('New York', 40.7128, -74.0060), ('Los Angeles', 34.0522, -118.2437),
  ('Chicago', 41.8781, -87.6298), ('Houston', 29.7604, -95.3698),
  ('Phoenix', 33.4484, -112.0740), ('San Francisco', 37.7749, -122.4194),
  ('Seattle', 47.6062, -122.3321), ('Boston', 42.3601, -71.0589),
  ('Miami', 25.7617, -80.1918), ('Atlanta', 33.7490, -84.3880),
  ('Denver', 39.7392, -104.9903), ('Austin', 30.2672, -97.7431),
  ('Dallas', 32.7767, -96.7970), ('Nashville', 36.1627, -86.7816),
  ('Portland', 45.5152, -122.6784), ('Las Vegas', 36.1699, -115.1398),
  ('San Diego', 32.7157, -117.1611), ('Philadelphia', 39.9526, -75.1652),
  ('Washington DC', 38.9072, -77.0369), ('Detroit', 42.3314, -83.0458)
) AS v(name, lat, lon)
CROSS JOIN (SELECT id FROM locations WHERE name = 'USA' AND type = 'country' LIMIT 1) l
WHERE NOT EXISTS (SELECT 1 FROM locations WHERE name = v.name AND type = 'city');

-- UK
INSERT INTO locations (name, type, parent_id, translation_key, latitude, longitude)
SELECT v.name, 'city', l.id, 'profile.locations.' || LOWER(REPLACE(v.name, ' ', '_')), v.lat, v.lon
FROM (VALUES
  ('London', 51.5074, -0.1278), ('Manchester', 53.4808, -2.2426),
  ('Birmingham', 52.4862, -1.8904), ('Edinburgh', 55.9533, -3.1883),
  ('Glasgow', 55.8642, -4.2518), ('Liverpool', 53.4084, -2.9916),
  ('Bristol', 51.4545, -2.5879), ('Leeds', 53.8008, -1.5491)
) AS v(name, lat, lon)
CROSS JOIN (SELECT id FROM locations WHERE name = 'UK' AND type = 'country' LIMIT 1) l
WHERE NOT EXISTS (SELECT 1 FROM locations WHERE name = v.name AND type = 'city');

-- France
INSERT INTO locations (name, type, parent_id, translation_key, latitude, longitude)
SELECT v.name, 'city', l.id, 'profile.locations.' || LOWER(REPLACE(v.name, ' ', '_')), v.lat, v.lon
FROM (VALUES
  ('Paris', 48.8566, 2.3522), ('Marseille', 43.2965, 5.3698),
  ('Lyon', 45.7640, 4.8357), ('Toulouse', 43.6047, 1.4442),
  ('Nice', 43.7102, 7.2620), ('Strasbourg', 48.5734, 7.7521),
  ('Bordeaux', 44.8378, -0.5792), ('Nantes', 47.2184, -1.5536)
) AS v(name, lat, lon)
CROSS JOIN (SELECT id FROM locations WHERE name = 'France' AND type = 'country' LIMIT 1) l
WHERE NOT EXISTS (SELECT 1 FROM locations WHERE name = v.name AND type = 'city');

-- Japan
INSERT INTO locations (name, type, parent_id, translation_key, latitude, longitude)
SELECT v.name, 'city', l.id, 'profile.locations.' || LOWER(REPLACE(v.name, ' ', '_')), v.lat, v.lon
FROM (VALUES
  ('Tokyo', 35.6762, 139.6503), ('Osaka', 34.6937, 135.5023),
  ('Kyoto', 35.0116, 135.7681), ('Yokohama', 35.4437, 139.6380),
  ('Nagoya', 35.1815, 136.9066), ('Sapporo', 43.0618, 141.3545),
  ('Fukuoka', 33.5904, 130.4017), ('Kobe', 34.6901, 135.1956)
) AS v(name, lat, lon)
CROSS JOIN (SELECT id FROM locations WHERE name = 'Japan' AND type = 'country' LIMIT 1) l
WHERE NOT EXISTS (SELECT 1 FROM locations WHERE name = v.name AND type = 'city');

-- Germany
INSERT INTO locations (name, type, parent_id, translation_key, latitude, longitude)
SELECT v.name, 'city', l.id, 'profile.locations.' || LOWER(REPLACE(v.name, ' ', '_')), v.lat, v.lon
FROM (VALUES
  ('Berlin', 52.5200, 13.4050), ('Munich', 48.1351, 11.5820),
  ('Hamburg', 53.5511, 9.9937), ('Frankfurt', 50.1109, 8.6821),
  ('Cologne', 50.9375, 6.9603), ('Stuttgart', 48.7758, 9.1829)
) AS v(name, lat, lon)
CROSS JOIN (SELECT id FROM locations WHERE name = 'Germany' AND type = 'country' LIMIT 1) l
WHERE NOT EXISTS (SELECT 1 FROM locations WHERE name = v.name AND type = 'city');

-- Canada
INSERT INTO locations (name, type, parent_id, translation_key, latitude, longitude)
SELECT v.name, 'city', l.id, 'profile.locations.' || LOWER(REPLACE(v.name, ' ', '_')), v.lat, v.lon
FROM (VALUES
  ('Toronto', 43.6532, -79.3832), ('Vancouver', 49.2827, -123.1207),
  ('Montreal', 45.5017, -73.5673), ('Calgary', 51.0447, -114.0719),
  ('Ottawa', 45.4215, -75.6972), ('Edmonton', 53.5461, -113.4938)
) AS v(name, lat, lon)
CROSS JOIN (SELECT id FROM locations WHERE name = 'Canada' AND type = 'country' LIMIT 1) l
WHERE NOT EXISTS (SELECT 1 FROM locations WHERE name = v.name AND type = 'city');

-- Australia
INSERT INTO locations (name, type, parent_id, translation_key, latitude, longitude)
SELECT v.name, 'city', l.id, 'profile.locations.' || LOWER(REPLACE(v.name, ' ', '_')), v.lat, v.lon
FROM (VALUES
  ('Sydney', -33.8688, 151.2093), ('Melbourne', -37.8136, 144.9631),
  ('Brisbane', -27.4698, 153.0251), ('Perth', -31.9505, 115.8605),
  ('Adelaide', -34.9285, 138.6007), ('Gold Coast', -28.0167, 153.4000)
) AS v(name, lat, lon)
CROSS JOIN (SELECT id FROM locations WHERE name = 'Australia' AND type = 'country' LIMIT 1) l
WHERE NOT EXISTS (SELECT 1 FROM locations WHERE name = v.name AND type = 'city');

-- Georgia
INSERT INTO locations (name, type, parent_id, translation_key, latitude, longitude)
SELECT v.name, 'city', l.id, 'profile.locations.' || LOWER(REPLACE(v.name, ' ', '_')), v.lat, v.lon
FROM (VALUES
  ('Tbilisi', 41.7151, 44.8271), ('Batumi', 41.6168, 41.6367),
  ('Kutaisi', 42.2679, 42.7180), ('Rustavi', 41.5381, 44.9704),
  ('Gori', 41.9814, 44.1124), ('Zugdidi', 42.5063, 41.8664)
) AS v(name, lat, lon)
CROSS JOIN (SELECT id FROM locations WHERE name = 'Georgia' AND type = 'country' LIMIT 1) l
WHERE NOT EXISTS (SELECT 1 FROM locations WHERE name = v.name AND type = 'city');

-- Turkey
INSERT INTO locations (name, type, parent_id, translation_key, latitude, longitude)
SELECT v.name, 'city', l.id, 'profile.locations.' || LOWER(REPLACE(v.name, ' ', '_')), v.lat, v.lon
FROM (VALUES
  ('Istanbul', 41.0082, 28.9784), ('Ankara', 39.9334, 32.8597),
  ('Izmir', 38.4189, 27.1287), ('Antalya', 36.8969, 30.7133)
) AS v(name, lat, lon)
CROSS JOIN (SELECT id FROM locations WHERE name = 'Turkey' AND type = 'country' LIMIT 1) l
WHERE NOT EXISTS (SELECT 1 FROM locations WHERE name = v.name AND type = 'city');

-- Italy
INSERT INTO locations (name, type, parent_id, translation_key, latitude, longitude)
SELECT v.name, 'city', l.id, 'profile.locations.' || LOWER(REPLACE(v.name, ' ', '_')), v.lat, v.lon
FROM (VALUES
  ('Rome', 41.9028, 12.4964), ('Milan', 45.4642, 9.1900),
  ('Naples', 40.8518, 14.2681), ('Florence', 43.7696, 11.2558),
  ('Turin', 45.0703, 7.6869), ('Bologna', 44.4949, 11.3426)
) AS v(name, lat, lon)
CROSS JOIN (SELECT id FROM locations WHERE name = 'Italy' AND type = 'country' LIMIT 1) l
WHERE NOT EXISTS (SELECT 1 FROM locations WHERE name = v.name AND type = 'city');

-- Spain
INSERT INTO locations (name, type, parent_id, translation_key, latitude, longitude)
SELECT v.name, 'city', l.id, 'profile.locations.' || LOWER(REPLACE(v.name, ' ', '_')), v.lat, v.lon
FROM (VALUES
  ('Barcelona', 41.3874, 2.1686), ('Madrid', 40.4168, -3.7038),
  ('Valencia', 39.4699, -0.3763), ('Seville', 37.3891, -5.9845)
) AS v(name, lat, lon)
CROSS JOIN (SELECT id FROM locations WHERE name = 'Spain' AND type = 'country' LIMIT 1) l
WHERE NOT EXISTS (SELECT 1 FROM locations WHERE name = v.name AND type = 'city');

-- Brazil
INSERT INTO locations (name, type, parent_id, translation_key, latitude, longitude)
SELECT v.name, 'city', l.id, 'profile.locations.' || LOWER(REPLACE(v.name, ' ', '_')), v.lat, v.lon
FROM (VALUES
  ('São Paulo', -23.5505, -46.6333), ('Rio de Janeiro', -22.9068, -43.1729),
  ('Brasília', -15.7975, -47.8919), ('Salvador', -12.9714, -38.5124)
) AS v(name, lat, lon)
CROSS JOIN (SELECT id FROM locations WHERE name = 'Brazil' AND type = 'country' LIMIT 1) l
WHERE NOT EXISTS (SELECT 1 FROM locations WHERE name = v.name AND type = 'city');

-- India
INSERT INTO locations (name, type, parent_id, translation_key, latitude, longitude)
SELECT v.name, 'city', l.id, 'profile.locations.' || LOWER(REPLACE(v.name, ' ', '_')), v.lat, v.lon
FROM (VALUES
  ('Mumbai', 19.0760, 72.8777), ('Delhi', 28.7041, 77.1025),
  ('Bangalore', 12.9716, 77.5946), ('Chennai', 13.0827, 80.2707),
  ('Kolkata', 22.5726, 88.3639), ('Hyderabad', 17.3850, 78.4867)
) AS v(name, lat, lon)
CROSS JOIN (SELECT id FROM locations WHERE name = 'India' AND type = 'country' LIMIT 1) l
WHERE NOT EXISTS (SELECT 1 FROM locations WHERE name = v.name AND type = 'city');

-- South Korea
INSERT INTO locations (name, type, parent_id, translation_key, latitude, longitude)
SELECT v.name, 'city', l.id, 'profile.locations.' || LOWER(REPLACE(v.name, ' ', '_')), v.lat, v.lon
FROM (VALUES
  ('Seoul', 37.5665, 126.9780), ('Busan', 35.1796, 129.0756),
  ('Incheon', 37.4563, 126.7052), ('Daegu', 35.8714, 128.6014)
) AS v(name, lat, lon)
CROSS JOIN (SELECT id FROM locations WHERE name = 'South Korea' AND type = 'country' LIMIT 1) l
WHERE NOT EXISTS (SELECT 1 FROM locations WHERE name = v.name AND type = 'city');

-- Israel
INSERT INTO locations (name, type, parent_id, translation_key, latitude, longitude)
SELECT v.name, 'city', l.id, 'profile.locations.' || LOWER(REPLACE(v.name, ' ', '_')), v.lat, v.lon
FROM (VALUES
  ('Tel Aviv', 32.0853, 34.7818), ('Jerusalem', 31.7683, 35.2137),
  ('Haifa', 32.7940, 34.9896)
) AS v(name, lat, lon)
CROSS JOIN (SELECT id FROM locations WHERE name = 'Israel' AND type = 'country' LIMIT 1) l
WHERE NOT EXISTS (SELECT 1 FROM locations WHERE name = v.name AND type = 'city');

-- Russia
INSERT INTO locations (name, type, parent_id, translation_key, latitude, longitude)
SELECT v.name, 'city', l.id, 'profile.locations.' || LOWER(REPLACE(v.name, ' ', '_')), v.lat, v.lon
FROM (VALUES
  ('Moscow', 55.7558, 37.6173), ('Saint Petersburg', 59.9343, 30.3351),
  ('Novosibirsk', 55.0084, 82.9357), ('Kazan', 55.8304, 49.0661)
) AS v(name, lat, lon)
CROSS JOIN (SELECT id FROM locations WHERE name = 'Russia' AND type = 'country' LIMIT 1) l
WHERE NOT EXISTS (SELECT 1 FROM locations WHERE name = v.name AND type = 'city');

-- China
INSERT INTO locations (name, type, parent_id, translation_key, latitude, longitude)
SELECT v.name, 'city', l.id, 'profile.locations.' || LOWER(REPLACE(v.name, ' ', '_')), v.lat, v.lon
FROM (VALUES
  ('Beijing', 39.9042, 116.4074), ('Shanghai', 31.2304, 121.4737),
  ('Guangzhou', 23.1291, 113.2644), ('Shenzhen', 22.5431, 114.0579),
  ('Chengdu', 30.5728, 104.0668), ('Hangzhou', 30.2741, 120.1551)
) AS v(name, lat, lon)
CROSS JOIN (SELECT id FROM locations WHERE name = 'China' AND type = 'country' LIMIT 1) l
WHERE NOT EXISTS (SELECT 1 FROM locations WHERE name = v.name AND type = 'city');

-- Thailand
INSERT INTO locations (name, type, parent_id, translation_key, latitude, longitude)
SELECT v.name, 'city', l.id, 'profile.locations.' || LOWER(REPLACE(v.name, ' ', '_')), v.lat, v.lon
FROM (VALUES
  ('Bangkok', 13.7563, 100.5018), ('Chiang Mai', 18.7883, 98.9853),
  ('Phuket', 7.8804, 98.3923), ('Pattaya', 12.9236, 100.8825)
) AS v(name, lat, lon)
CROSS JOIN (SELECT id FROM locations WHERE name = 'Thailand' AND type = 'country' LIMIT 1) l
WHERE NOT EXISTS (SELECT 1 FROM locations WHERE name = v.name AND type = 'city');

-- Netherlands
INSERT INTO locations (name, type, parent_id, translation_key, latitude, longitude)
SELECT v.name, 'city', l.id, 'profile.locations.' || LOWER(REPLACE(v.name, ' ', '_')), v.lat, v.lon
FROM (VALUES
  ('Amsterdam', 52.3676, 4.9041), ('Rotterdam', 51.9244, 4.4777),
  ('The Hague', 52.0705, 4.3007), ('Utrecht', 52.0907, 5.1214)
) AS v(name, lat, lon)
CROSS JOIN (SELECT id FROM locations WHERE name = 'Netherlands' AND type = 'country' LIMIT 1) l
WHERE NOT EXISTS (SELECT 1 FROM locations WHERE name = v.name AND type = 'city');

-- Sweden
INSERT INTO locations (name, type, parent_id, translation_key, latitude, longitude)
SELECT v.name, 'city', l.id, 'profile.locations.' || LOWER(REPLACE(v.name, ' ', '_')), v.lat, v.lon
FROM (VALUES
  ('Stockholm', 59.3293, 18.0686), ('Gothenburg', 57.7089, 11.9746),
  ('Malmö', 55.6050, 13.0038)
) AS v(name, lat, lon)
CROSS JOIN (SELECT id FROM locations WHERE name = 'Sweden' AND type = 'country' LIMIT 1) l
WHERE NOT EXISTS (SELECT 1 FROM locations WHERE name = v.name AND type = 'city');

-- Norway
INSERT INTO locations (name, type, parent_id, translation_key, latitude, longitude)
SELECT v.name, 'city', l.id, 'profile.locations.' || LOWER(REPLACE(v.name, ' ', '_')), v.lat, v.lon
FROM (VALUES
  ('Oslo', 59.9139, 10.7522), ('Bergen', 60.3913, 5.3221),
  ('Trondheim', 63.4305, 10.3951), ('Stavanger', 58.9700, 5.7331)
) AS v(name, lat, lon)
CROSS JOIN (SELECT id FROM locations WHERE name = 'Norway' AND type = 'country' LIMIT 1) l
WHERE NOT EXISTS (SELECT 1 FROM locations WHERE name = v.name AND type = 'city');

-- Denmark
INSERT INTO locations (name, type, parent_id, translation_key, latitude, longitude)
SELECT v.name, 'city', l.id, 'profile.locations.' || LOWER(REPLACE(v.name, ' ', '_')), v.lat, v.lon
FROM (VALUES
  ('Copenhagen', 55.6761, 12.5683), ('Aarhus', 56.1629, 10.2039),
  ('Odense', 55.4038, 10.4024)
) AS v(name, lat, lon)
CROSS JOIN (SELECT id FROM locations WHERE name = 'Denmark' AND type = 'country' LIMIT 1) l
WHERE NOT EXISTS (SELECT 1 FROM locations WHERE name = v.name AND type = 'city');

-- Finland
INSERT INTO locations (name, type, parent_id, translation_key, latitude, longitude)
SELECT v.name, 'city', l.id, 'profile.locations.' || LOWER(REPLACE(v.name, ' ', '_')), v.lat, v.lon
FROM (VALUES
  ('Helsinki', 60.1699, 24.9384), ('Espoo', 60.2055, 24.6559),
  ('Tampere', 61.4978, 23.7610)
) AS v(name, lat, lon)
CROSS JOIN (SELECT id FROM locations WHERE name = 'Finland' AND type = 'country' LIMIT 1) l
WHERE NOT EXISTS (SELECT 1 FROM locations WHERE name = v.name AND type = 'city');

-- Poland
INSERT INTO locations (name, type, parent_id, translation_key, latitude, longitude)
SELECT v.name, 'city', l.id, 'profile.locations.' || LOWER(REPLACE(v.name, ' ', '_')), v.lat, v.lon
FROM (VALUES
  ('Warsaw', 52.2297, 21.0122), ('Kraków', 50.0647, 19.9450),
  ('Wrocław', 51.1079, 17.0385), ('Poznań', 52.4064, 16.9252)
) AS v(name, lat, lon)
CROSS JOIN (SELECT id FROM locations WHERE name = 'Poland' AND type = 'country' LIMIT 1) l
WHERE NOT EXISTS (SELECT 1 FROM locations WHERE name = v.name AND type = 'city');

-- Czech Republic
INSERT INTO locations (name, type, parent_id, translation_key, latitude, longitude)
SELECT v.name, 'city', l.id, 'profile.locations.' || LOWER(REPLACE(v.name, ' ', '_')), v.lat, v.lon
FROM (VALUES
  ('Prague', 50.0755, 14.4378), ('Brno', 49.1951, 16.6068)
) AS v(name, lat, lon)
CROSS JOIN (SELECT id FROM locations WHERE name = 'Czech Republic' AND type = 'country' LIMIT 1) l
WHERE NOT EXISTS (SELECT 1 FROM locations WHERE name = v.name AND type = 'city');

-- Austria
INSERT INTO locations (name, type, parent_id, translation_key, latitude, longitude)
SELECT v.name, 'city', l.id, 'profile.locations.' || LOWER(REPLACE(v.name, ' ', '_')), v.lat, v.lon
FROM (VALUES
  ('Vienna', 48.2082, 16.3738), ('Graz', 47.0707, 15.4395),
  ('Salzburg', 47.8095, 13.0550)
) AS v(name, lat, lon)
CROSS JOIN (SELECT id FROM locations WHERE name = 'Austria' AND type = 'country' LIMIT 1) l
WHERE NOT EXISTS (SELECT 1 FROM locations WHERE name = v.name AND type = 'city');

-- Belgium
INSERT INTO locations (name, type, parent_id, translation_key, latitude, longitude)
SELECT v.name, 'city', l.id, 'profile.locations.' || LOWER(REPLACE(v.name, ' ', '_')), v.lat, v.lon
FROM (VALUES
  ('Brussels', 50.8503, 4.3517), ('Antwerp', 51.2194, 4.4025),
  ('Ghent', 51.0543, 3.7174)
) AS v(name, lat, lon)
CROSS JOIN (SELECT id FROM locations WHERE name = 'Belgium' AND type = 'country' LIMIT 1) l
WHERE NOT EXISTS (SELECT 1 FROM locations WHERE name = v.name AND type = 'city');

-- Portugal
INSERT INTO locations (name, type, parent_id, translation_key, latitude, longitude)
SELECT v.name, 'city', l.id, 'profile.locations.' || LOWER(REPLACE(v.name, ' ', '_')), v.lat, v.lon
FROM (VALUES
  ('Lisbon', 38.7223, -9.1393), ('Porto', 41.1579, -8.6291)
) AS v(name, lat, lon)
CROSS JOIN (SELECT id FROM locations WHERE name = 'Portugal' AND type = 'country' LIMIT 1) l
WHERE NOT EXISTS (SELECT 1 FROM locations WHERE name = v.name AND type = 'city');

-- Greece
INSERT INTO locations (name, type, parent_id, translation_key, latitude, longitude)
SELECT v.name, 'city', l.id, 'profile.locations.' || LOWER(REPLACE(v.name, ' ', '_')), v.lat, v.lon
FROM (VALUES
  ('Athens', 37.9838, 23.7275), ('Thessaloniki', 40.6401, 22.9444)
) AS v(name, lat, lon)
CROSS JOIN (SELECT id FROM locations WHERE name = 'Greece' AND type = 'country' LIMIT 1) l
WHERE NOT EXISTS (SELECT 1 FROM locations WHERE name = v.name AND type = 'city');

-- Ireland
INSERT INTO locations (name, type, parent_id, translation_key, latitude, longitude)
SELECT v.name, 'city', l.id, 'profile.locations.' || LOWER(REPLACE(v.name, ' ', '_')), v.lat, v.lon
FROM (VALUES
  ('Dublin', 53.3498, -6.2603), ('Cork', 51.8969, -8.4863),
  ('Galway', 53.2707, -9.0568)
) AS v(name, lat, lon)
CROSS JOIN (SELECT id FROM locations WHERE name = 'Ireland' AND type = 'country' LIMIT 1) l
WHERE NOT EXISTS (SELECT 1 FROM locations WHERE name = v.name AND type = 'city');

-- Mexico
INSERT INTO locations (name, type, parent_id, translation_key, latitude, longitude)
SELECT v.name, 'city', l.id, 'profile.locations.' || LOWER(REPLACE(v.name, ' ', '_')), v.lat, v.lon
FROM (VALUES
  ('Mexico City', 19.4326, -99.1332), ('Guadalajara', 20.6597, -103.3496),
  ('Monterrey', 25.6866, -100.3161), ('Cancún', 21.1619, -86.8515)
) AS v(name, lat, lon)
CROSS JOIN (SELECT id FROM locations WHERE name = 'Mexico' AND type = 'country' LIMIT 1) l
WHERE NOT EXISTS (SELECT 1 FROM locations WHERE name = v.name AND type = 'city');

-- Argentina
INSERT INTO locations (name, type, parent_id, translation_key, latitude, longitude)
SELECT v.name, 'city', l.id, 'profile.locations.' || LOWER(REPLACE(v.name, ' ', '_')), v.lat, v.lon
FROM (VALUES
  ('Buenos Aires', -34.6037, -58.3816), ('Córdoba', -31.4201, -64.1888),
  ('Rosario', -32.9468, -60.6393)
) AS v(name, lat, lon)
CROSS JOIN (SELECT id FROM locations WHERE name = 'Argentina' AND type = 'country' LIMIT 1) l
WHERE NOT EXISTS (SELECT 1 FROM locations WHERE name = v.name AND type = 'city');

-- South Africa
INSERT INTO locations (name, type, parent_id, translation_key, latitude, longitude)
SELECT v.name, 'city', l.id, 'profile.locations.' || LOWER(REPLACE(v.name, ' ', '_')), v.lat, v.lon
FROM (VALUES
  ('Cape Town', -33.9249, 18.4241), ('Johannesburg', -26.2041, 28.0473),
  ('Durban', -29.8587, 31.0218)
) AS v(name, lat, lon)
CROSS JOIN (SELECT id FROM locations WHERE name = 'South Africa' AND type = 'country' LIMIT 1) l
WHERE NOT EXISTS (SELECT 1 FROM locations WHERE name = v.name AND type = 'city');

-- Egypt
INSERT INTO locations (name, type, parent_id, translation_key, latitude, longitude)
SELECT v.name, 'city', l.id, 'profile.locations.' || LOWER(REPLACE(v.name, ' ', '_')), v.lat, v.lon
FROM (VALUES
  ('Cairo', 30.0444, 31.2357), ('Alexandria', 31.2001, 29.9187)
) AS v(name, lat, lon)
CROSS JOIN (SELECT id FROM locations WHERE name = 'Egypt' AND type = 'country' LIMIT 1) l
WHERE NOT EXISTS (SELECT 1 FROM locations WHERE name = v.name AND type = 'city');

-- Ukraine
INSERT INTO locations (name, type, parent_id, translation_key, latitude, longitude)
SELECT v.name, 'city', l.id, 'profile.locations.' || LOWER(REPLACE(v.name, ' ', '_')), v.lat, v.lon
FROM (VALUES
  ('Kyiv', 50.4501, 30.5234), ('Kharkiv', 49.9935, 36.2304),
  ('Odesa', 46.4825, 30.7233), ('Lviv', 49.8397, 24.0297)
) AS v(name, lat, lon)
CROSS JOIN (SELECT id FROM locations WHERE name = 'Ukraine' AND type = 'country' LIMIT 1) l
WHERE NOT EXISTS (SELECT 1 FROM locations WHERE name = v.name AND type = 'city');

-- Romania
INSERT INTO locations (name, type, parent_id, translation_key, latitude, longitude)
SELECT v.name, 'city', l.id, 'profile.locations.' || LOWER(REPLACE(v.name, ' ', '_')), v.lat, v.lon
FROM (VALUES
  ('Bucharest', 44.4268, 26.1025), ('Cluj-Napoca', 46.7712, 23.6236),
  ('Timișoara', 45.7489, 21.2087)
) AS v(name, lat, lon)
CROSS JOIN (SELECT id FROM locations WHERE name = 'Romania' AND type = 'country' LIMIT 1) l
WHERE NOT EXISTS (SELECT 1 FROM locations WHERE name = v.name AND type = 'city');

-- UAE
INSERT INTO locations (name, type, parent_id, translation_key, latitude, longitude)
SELECT v.name, 'city', l.id, 'profile.locations.' || LOWER(REPLACE(v.name, ' ', '_')), v.lat, v.lon
FROM (VALUES
  ('Dubai', 25.2048, 55.2708), ('Abu Dhabi', 24.4539, 54.3773),
  ('Sharjah', 25.3573, 55.3908)
) AS v(name, lat, lon)
CROSS JOIN (SELECT id FROM locations WHERE name = 'UAE' AND type = 'country' LIMIT 1) l
WHERE NOT EXISTS (SELECT 1 FROM locations WHERE name = v.name AND type = 'city');

-- Lebanon
INSERT INTO locations (name, type, parent_id, translation_key, latitude, longitude)
SELECT v.name, 'city', l.id, 'profile.locations.' || LOWER(REPLACE(v.name, ' ', '_')), v.lat, v.lon
FROM (VALUES
  ('Beirut', 33.8938, 35.5018)
) AS v(name, lat, lon)
CROSS JOIN (SELECT id FROM locations WHERE name = 'Lebanon' AND type = 'country' LIMIT 1) l
WHERE NOT EXISTS (SELECT 1 FROM locations WHERE name = v.name AND type = 'city');

-- Singapore
INSERT INTO locations (name, type, parent_id, translation_key, latitude, longitude)
SELECT v.name, 'city', l.id, 'profile.locations.' || LOWER(REPLACE(v.name, ' ', '_')), v.lat, v.lon
FROM (VALUES
  ('Singapore', 1.3521, 103.8198)
) AS v(name, lat, lon)
CROSS JOIN (SELECT id FROM locations WHERE name = 'Singapore' AND type = 'country' LIMIT 1) l
WHERE NOT EXISTS (SELECT 1 FROM locations WHERE name = v.name AND type = 'city');

-- Philippines
INSERT INTO locations (name, type, parent_id, translation_key, latitude, longitude)
SELECT v.name, 'city', l.id, 'profile.locations.' || LOWER(REPLACE(v.name, ' ', '_')), v.lat, v.lon
FROM (VALUES
  ('Manila', 14.5995, 120.9842), ('Cebu City', 10.3157, 123.8854)
) AS v(name, lat, lon)
CROSS JOIN (SELECT id FROM locations WHERE name = 'Philippines' AND type = 'country' LIMIT 1) l
WHERE NOT EXISTS (SELECT 1 FROM locations WHERE name = v.name AND type = 'city');

-- Indonesia
INSERT INTO locations (name, type, parent_id, translation_key, latitude, longitude)
SELECT v.name, 'city', l.id, 'profile.locations.' || LOWER(REPLACE(v.name, ' ', '_')), v.lat, v.lon
FROM (VALUES
  ('Jakarta', -6.2088, 106.8456), ('Bali (Denpasar)', -8.6500, 115.2167)
) AS v(name, lat, lon)
CROSS JOIN (SELECT id FROM locations WHERE name = 'Indonesia' AND type = 'country' LIMIT 1) l
WHERE NOT EXISTS (SELECT 1 FROM locations WHERE name = v.name AND type = 'city');

-- Malaysia
INSERT INTO locations (name, type, parent_id, translation_key, latitude, longitude)
SELECT v.name, 'city', l.id, 'profile.locations.' || LOWER(REPLACE(v.name, ' ', '_')), v.lat, v.lon
FROM (VALUES
  ('Kuala Lumpur', 3.1390, 101.6869)
) AS v(name, lat, lon)
CROSS JOIN (SELECT id FROM locations WHERE name = 'Malaysia' AND type = 'country' LIMIT 1) l
WHERE NOT EXISTS (SELECT 1 FROM locations WHERE name = v.name AND type = 'city');

-- Vietnam
INSERT INTO locations (name, type, parent_id, translation_key, latitude, longitude)
SELECT v.name, 'city', l.id, 'profile.locations.' || LOWER(REPLACE(v.name, ' ', '_')), v.lat, v.lon
FROM (VALUES
  ('Ho Chi Minh City', 10.8231, 106.6297), ('Hanoi', 21.0278, 105.8342)
) AS v(name, lat, lon)
CROSS JOIN (SELECT id FROM locations WHERE name = 'Vietnam' AND type = 'country' LIMIT 1) l
WHERE NOT EXISTS (SELECT 1 FROM locations WHERE name = v.name AND type = 'city');

-- Colombia
INSERT INTO locations (name, type, parent_id, translation_key, latitude, longitude)
SELECT v.name, 'city', l.id, 'profile.locations.' || LOWER(REPLACE(v.name, ' ', '_')), v.lat, v.lon
FROM (VALUES
  ('Bogotá', 4.7110, -74.0721), ('Medellín', 6.2476, -75.5658),
  ('Cali', 3.4516, -76.5320)
) AS v(name, lat, lon)
CROSS JOIN (SELECT id FROM locations WHERE name = 'Colombia' AND type = 'country' LIMIT 1) l
WHERE NOT EXISTS (SELECT 1 FROM locations WHERE name = v.name AND type = 'city');

-- Chile
INSERT INTO locations (name, type, parent_id, translation_key, latitude, longitude)
SELECT v.name, 'city', l.id, 'profile.locations.' || LOWER(REPLACE(v.name, ' ', '_')), v.lat, v.lon
FROM (VALUES
  ('Santiago', -33.4489, -70.6693), ('Valparaíso', -33.0472, -71.6127)
) AS v(name, lat, lon)
CROSS JOIN (SELECT id FROM locations WHERE name = 'Chile' AND type = 'country' LIMIT 1) l
WHERE NOT EXISTS (SELECT 1 FROM locations WHERE name = v.name AND type = 'city');

-- Peru
INSERT INTO locations (name, type, parent_id, translation_key, latitude, longitude)
SELECT v.name, 'city', l.id, 'profile.locations.' || LOWER(REPLACE(v.name, ' ', '_')), v.lat, v.lon
FROM (VALUES
  ('Lima', -12.0464, -77.0428), ('Cusco', -13.5320, -71.9675)
) AS v(name, lat, lon)
CROSS JOIN (SELECT id FROM locations WHERE name = 'Peru' AND type = 'country' LIMIT 1) l
WHERE NOT EXISTS (SELECT 1 FROM locations WHERE name = v.name AND type = 'city');

-- Hungary
INSERT INTO locations (name, type, parent_id, translation_key, latitude, longitude)
SELECT v.name, 'city', l.id, 'profile.locations.' || LOWER(REPLACE(v.name, ' ', '_')), v.lat, v.lon
FROM (VALUES
  ('Budapest', 47.4979, 19.0402)
) AS v(name, lat, lon)
CROSS JOIN (SELECT id FROM locations WHERE name = 'Hungary' AND type = 'country' LIMIT 1) l
WHERE NOT EXISTS (SELECT 1 FROM locations WHERE name = v.name AND type = 'city');

-- Croatia
INSERT INTO locations (name, type, parent_id, translation_key, latitude, longitude)
SELECT v.name, 'city', l.id, 'profile.locations.' || LOWER(REPLACE(v.name, ' ', '_')), v.lat, v.lon
FROM (VALUES
  ('Zagreb', 45.8150, 15.9819), ('Split', 43.5081, 16.4402)
) AS v(name, lat, lon)
CROSS JOIN (SELECT id FROM locations WHERE name = 'Croatia' AND type = 'country' LIMIT 1) l
WHERE NOT EXISTS (SELECT 1 FROM locations WHERE name = v.name AND type = 'city');

-- Serbia
INSERT INTO locations (name, type, parent_id, translation_key, latitude, longitude)
SELECT v.name, 'city', l.id, 'profile.locations.' || LOWER(REPLACE(v.name, ' ', '_')), v.lat, v.lon
FROM (VALUES
  ('Belgrade', 44.7866, 20.4489), ('Novi Sad', 45.2671, 19.8335)
) AS v(name, lat, lon)
CROSS JOIN (SELECT id FROM locations WHERE name = 'Serbia' AND type = 'country' LIMIT 1) l
WHERE NOT EXISTS (SELECT 1 FROM locations WHERE name = v.name AND type = 'city');

-- Bulgaria
INSERT INTO locations (name, type, parent_id, translation_key, latitude, longitude)
SELECT v.name, 'city', l.id, 'profile.locations.' || LOWER(REPLACE(v.name, ' ', '_')), v.lat, v.lon
FROM (VALUES
  ('Sofia', 42.6977, 23.3219), ('Plovdiv', 42.1354, 24.7453)
) AS v(name, lat, lon)
CROSS JOIN (SELECT id FROM locations WHERE name = 'Bulgaria' AND type = 'country' LIMIT 1) l
WHERE NOT EXISTS (SELECT 1 FROM locations WHERE name = v.name AND type = 'city');

-- Armenia
INSERT INTO locations (name, type, parent_id, translation_key, latitude, longitude)
SELECT v.name, 'city', l.id, 'profile.locations.' || LOWER(REPLACE(v.name, ' ', '_')), v.lat, v.lon
FROM (VALUES
  ('Yerevan', 40.1792, 44.4991)
) AS v(name, lat, lon)
CROSS JOIN (SELECT id FROM locations WHERE name = 'Armenia' AND type = 'country' LIMIT 1) l
WHERE NOT EXISTS (SELECT 1 FROM locations WHERE name = v.name AND type = 'city');

-- Azerbaijan
INSERT INTO locations (name, type, parent_id, translation_key, latitude, longitude)
SELECT v.name, 'city', l.id, 'profile.locations.' || LOWER(REPLACE(v.name, ' ', '_')), v.lat, v.lon
FROM (VALUES
  ('Baku', 40.4093, 49.8671)
) AS v(name, lat, lon)
CROSS JOIN (SELECT id FROM locations WHERE name = 'Azerbaijan' AND type = 'country' LIMIT 1) l
WHERE NOT EXISTS (SELECT 1 FROM locations WHERE name = v.name AND type = 'city');

-- New Zealand
INSERT INTO locations (name, type, parent_id, translation_key, latitude, longitude)
SELECT v.name, 'city', l.id, 'profile.locations.' || LOWER(REPLACE(v.name, ' ', '_')), v.lat, v.lon
FROM (VALUES
  ('Auckland', -36.8485, 174.7633), ('Wellington', -41.2865, 174.7762),
  ('Christchurch', -43.5321, 172.6362)
) AS v(name, lat, lon)
CROSS JOIN (SELECT id FROM locations WHERE name = 'New Zealand' AND type = 'country' LIMIT 1) l
WHERE NOT EXISTS (SELECT 1 FROM locations WHERE name = v.name AND type = 'city');
