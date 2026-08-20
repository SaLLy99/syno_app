-- ===============================================
-- Syno Backend Init Script
-- Creates tables and inserts test data if missing
-- Updated to include cities, countries, hobbies, orientations, and sexes
-- ===============================================

-- 0️⃣ Setup helper functions first
CREATE OR REPLACE FUNCTION cleanup_expired_otps()
RETURNS void AS $$
BEGIN
    DELETE FROM otps
    WHERE expires_at < NOW()
       OR used_flag = TRUE;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION trigger_cleanup_otps_handler()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM cleanup_expired_otps();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 1️⃣ Create locations table
CREATE TABLE IF NOT EXISTS locations (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    type VARCHAR(10) NOT NULL, -- 'country' or 'city'
    parent_id INT REFERENCES locations(id) ON DELETE CASCADE,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    UNIQUE(name, parent_id)
);

-- 2️⃣ Create educations table
CREATE TABLE IF NOT EXISTS educations (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL
);

-- 2️⃣.5 Create professions table
CREATE TABLE IF NOT EXISTS professions (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL
);

-- 3️⃣ Create hobbies table
CREATE TABLE IF NOT EXISTS hobbies (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL
);

-- 4️⃣ Create orientations table
CREATE TABLE IF NOT EXISTS orientations (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL
);


-- 5️⃣ Create sexes table
CREATE TABLE IF NOT EXISTS sexes (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL
);

-- 5️⃣.5 Create core_values table
CREATE TABLE IF NOT EXISTS core_values (
    id SERIAL PRIMARY KEY,
    key VARCHAR(50) UNIQUE NOT NULL,
    translation_key VARCHAR(100) NOT NULL
);

-- 5️⃣.6 Create intentions table
CREATE TABLE IF NOT EXISTS intentions (
    id SERIAL PRIMARY KEY,
    key VARCHAR(50) UNIQUE NOT NULL,
    translation_key VARCHAR(100) NOT NULL
);

SELECT cleanup_expired_otps();
-- 5️⃣.7 Create otps table for email verification
CREATE TABLE IF NOT EXISTS otps (
    id SERIAL PRIMARY KEY,
    email VARCHAR(100) NOT NULL,
    otp_hash VARCHAR(255) NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    used_flag BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_otps_email ON otps(email);

-- 6️⃣ Users table: authentication and account basics
CREATE TABLE IF NOT EXISTS syno_users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 7️⃣ Profiles table: extended profile info
CREATE TABLE IF NOT EXISTS profiles (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES syno_users(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    birth_date DATE NOT NULL,
    birth_time VARCHAR(5),
    location_id INT REFERENCES locations(id) ON DELETE SET NULL,
    sex_id INT NOT NULL REFERENCES sexes(id) ON DELETE RESTRICT,
    orientation_id INT NOT NULL REFERENCES orientations(id) ON DELETE RESTRICT,
    height int,
    additional_photos TEXT[],
    bio TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 8️⃣ Profile Hobbies table: many-to-many relationship between profiles and hobbies
CREATE TABLE IF NOT EXISTS profile_hobbies (
    profile_id INT NOT NULL,
    hobby_id INT NOT NULL,
    PRIMARY KEY (profile_id, hobby_id),
    FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE,
    FOREIGN KEY (hobby_id) REFERENCES hobbies(id) ON DELETE CASCADE
);

-- 8️⃣.5 Profile Educations table
CREATE TABLE IF NOT EXISTS profile_educations (
    profile_id INT NOT NULL,
    education_id INT NOT NULL,
    PRIMARY KEY (profile_id, education_id),
    FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE,
    FOREIGN KEY (education_id) REFERENCES educations(id) ON DELETE CASCADE
);

-- 8️⃣.6 Profile Professions table
CREATE TABLE IF NOT EXISTS profile_professions (
    profile_id INT NOT NULL,
    profession_id INT NOT NULL,
    PRIMARY KEY (profile_id, profession_id),
    FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE,
    FOREIGN KEY (profession_id) REFERENCES professions(id) ON DELETE CASCADE
);

-- 8️⃣.7 Profile Core Values table
CREATE TABLE IF NOT EXISTS profile_core_values (
    profile_id INT NOT NULL,
    core_value_id INT NOT NULL,
    PRIMARY KEY (profile_id, core_value_id),
    FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE,
    FOREIGN KEY (core_value_id) REFERENCES core_values(id) ON DELETE CASCADE
);

-- 8️⃣.8 Profile Intentions table
CREATE TABLE IF NOT EXISTS profile_intentions (
    profile_id INT NOT NULL,
    intention_id INT NOT NULL,
    PRIMARY KEY (profile_id, intention_id),
    FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE,
    FOREIGN KEY (intention_id) REFERENCES intentions(id) ON DELETE CASCADE
);

-- New table for user photos
CREATE TABLE IF NOT EXISTS user_photos (
    id SERIAL PRIMARY KEY,
    profile_id INT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    photo_data BYTEA NOT NULL,
    is_primary BOOLEAN DEFAULT FALSE,
    upload_order INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 9️⃣ Locations are populated dynamically via the /api/locations/seed endpoint
-- (fetches from REST Countries API with real coordinates on first run)

-- 1️⃣0️⃣.5 Insert sample data into educations
INSERT INTO educations (name) VALUES
    ('High School'),
    ('GED'),
    ('Some College'),
    ('Associate Degree'),
    ('Associate of Arts (AA)'),
    ('Associate of Science (AS)'),
    ('Bachelor''s Degree'),
    ('Bachelor of Arts (BA)'),
    ('Bachelor of Science (BS)'),
    ('Master''s Degree'),
    ('Master of Arts (MA)'),
    ('Master of Science (MS)'),
    ('Master of Business Administration (MBA)'),
    ('Doctorate (PhD)'),
    ('Juris Doctor (JD)'),
    ('Doctor of Medicine (MD)'),
    ('Doctor of Osteopathy (DO)'),
    ('Trade/Vocational School'),
    ('Professional Degree (MD, JD, etc.)'),
    ('Post-Doctoral'),
    ('Certificate Program'),
    ('Online Course/Certification'),
    ('Some University'),
    ('Currently in High School'),
    ('Currently in College/University'),
    ('Apprenticeship'),
    ('Diploma'),
    ('Art School'),
    ('Music School/Conservatory'),
    ('Film School'),
    ('Coding Bootcamp'),
    ('Seminary'),
    ('Other')
ON CONFLICT (name) DO NOTHING;

-- 1️⃣0️⃣.6 Insert sample data into professions
INSERT INTO professions (name) VALUES
    ('Software Developer'),
    ('Data Scientist'),
    ('Doctor'),
    ('Nurse'),
    ('Teacher'),
    ('Professor'),
    ('Lawyer'),
    ('Accountant'),
    ('Architect'),
    ('Graphic Designer'),
    ('Marketing Manager'),
    ('Sales Representative'),
    ('Business Analyst'),
    ('Project Manager'),
    ('Financial Advisor'),
    ('Psychologist'),
    ('Therapist'),
    ('Dentist'),
    ('Pharmacist'),
    ('Veterinarian'),
    ('Journalist'),
    ('Writer'),
    ('Photographer'),
    ('Chef'),
    ('Musician'),
    ('Actor'),
    ('Entrepreneur'),
    ('Real Estate Agent'),
    ('Police Officer'),
    ('Firefighter'),
    ('Pilot'),
    ('Civil Engineer'),
    ('Mechanical Engineer'),
    ('Electrical Engineer'),
    ('Web Designer'),
    ('UX/UI Designer'),
    ('Content Creator'),
    ('Social Media Manager'),
    ('Human Resources Manager'),
    ('Consultant'),
    ('Researcher'),
    ('Scientist'),
    ('Librarian'),
    ('Plumber'),
    ('Electrician'),
    ('Carpenter'),
    ('Barista'),
    ('Retail Worker'),
    ('Student'),
    ('Intern'),
    ('Freelancer'),
    ('Retired'),
    ('Surgeon'),
    ('Paramedic'),
    ('Physical Therapist'),
    ('Occupational Therapist'),
    ('Speech Therapist'),
    ('Social Worker'),
    ('Counselor'),
    ('Dietitian'),
    ('Nutritionist'),
    ('Radiologist'),
    ('Anesthesiologist'),
    ('Cardiologist'),
    ('Dermatologist'),
    ('Neurologist'),
    ('Pediatrician'),
    ('Psychiatrist'),
    ('Optometrist'),
    ('Chiropractor'),
    ('Environmental Scientist'),
    ('Marine Biologist'),
    ('Archaeologist'),
    ('Geologist'),
    ('Meteorologist'),
    ('Statistician'),
    ('Actuary'),
    ('Economist'),
    ('Linguist'),
    ('Translator'),
    ('Interpreter'),
    ('Flight Attendant'),
    ('Air Traffic Controller'),
    ('Marine Engineer'),
    ('Structural Engineer'),
    ('Environmental Engineer'),
    ('Software Engineer'),
    ('Hardware Engineer'),
    ('Network Engineer'),
    ('Cybersecurity Analyst'),
    ('Database Administrator'),
    ('Cloud Architect'),
    ('DevOps Engineer'),
    ('Technical Writer'),
    ('Paralegal'),
    ('Compliance Officer'),
    ('Risk Manager'),
    ('Investment Banker'),
    ('Portfolio Manager'),
    ('Financial Analyst'),
    ('Credit Analyst'),
    ('Loan Officer'),
    ('Retail Manager'),
    ('Restaurant Manager'),
    ('Hotel Manager'),
    ('Event Planner'),
    ('Wedding Planner'),
    ('Travel Agent'),
    ('Tour Guide'),
    ('Administrative Assistant'),
    ('Executive Assistant'),
    ('Operations Manager'),
    ('Supply Chain Manager'),
    ('Logistics Manager'),
    ('Quality Control Inspector'),
    ('Health Inspector'),
    ('Detective'),
    ('Forensic Scientist'),
    ('Intelligence Analyst'),
    ('Security Consultant'),
    ('Private Investigator'),
    ('Judge'),
    ('Mediator'),
    ('Lobbyist'),
    ('Political Consultant'),
    ('Speechwriter'),
    ('Press Secretary'),
    ('Communications Director'),
    ('Brand Manager'),
    ('Product Manager'),
    ('Data Analyst'),
    ('Market Research Analyst'),
    ('Machine Learning Engineer'),
    ('AI Researcher'),
    ('Robotics Engineer'),
    ('Automation Engineer'),
    ('Telecommunications Engineer'),
    ('Audio Engineer'),
    ('Video Engineer'),
    ('Lighting Designer'),
    ('Set Designer'),
    ('Costume Designer'),
    ('Makeup Artist'),
    ('Hair Stylist'),
    ('Massage Therapist'),
    ('Acupuncturist'),
    ('Midwife'),
    ('Genetic Counselor'),
    ('Art Therapist'),
    ('Music Therapist'),
    ('Recreation Therapist'),
    ('Nonprofit Director'),
    ('Grant Writer'),
    ('Academic Advisor'),
    ('Career Counselor'),
    ('Athletic Director'),
    ('Coach'),
    ('Personal Trainer'),
    ('Yoga Instructor'),
    ('Swimming Instructor'),
    ('Ski Instructor'),
    ('Surf Instructor'),
    ('Park Ranger'),
    ('Conservation Officer'),
    ('Zookeeper'),
    ('Animal Trainer'),
    ('Pet Groomer'),
    ('Veterinary Technician'),
    ('Pharmaceutical Sales Rep'),
    ('Account Executive'),
    ('Business Development Manager'),
    ('Creative Director'),
    ('Art Director'),
    ('Motion Designer'),
    ('3D Artist'),
    ('Videographer'),
    ('Editor'),
    ('Composer'),
    ('Choreographer'),
    ('Director'),
    ('Producer'),
    ('Screenwriter'),
    ('Playwright'),
    ('Novelist'),
    ('Poet'),
    ('Reporter'),
    ('Anchor'),
    ('Host'),
    ('Critic'),
    ('Publisher'),
    ('Publicist'),
    ('Stage Manager'),
    ('Concert Promoter'),
    ('Booking Agent'),
    ('Tour Manager'),
    ('Other')
ON CONFLICT (name) DO NOTHING;

-- 1️⃣1️⃣ Insert sample data into hobbies
INSERT INTO hobbies (name) VALUES
    ('Yoga'),
    ('Meditation'),
    ('Astrology'),
    ('Hiking'),
    ('Reading'),
    ('Music'),
    ('Traveling'),
    ('Photography'),
    ('Cooking'),
    ('Baking'),
    ('Gaming'),
    ('Painting'),
    ('Drawing'),
    ('Writing'),
    ('Dancing'),
    ('Running'),
    ('Jogging'),
    ('Swimming'),
    ('Cycling'),
    ('Tennis'),
    ('Basketball'),
    ('Football'),
    ('Volleyball'),
    ('Skiing'),
    ('Snowboarding'),
    ('Surfing'),
    ('Rock Climbing'),
    ('Camping'),
    ('Gardening'),
    ('DIY Projects'),
    ('Crafts'),
    ('Knitting'),
    ('Sewing'),
    ('Watching Movies'),
    ('Watching TV Shows'),
    ('Podcasts'),
    ('Volunteering'),
    ('Walking'),
    ('Board Games'),
    ('Collecting'),
    ('Bird Watching'),
    ('Fishing'),
    ('Martial Arts'),
    ('Pilates'),
    ('CrossFit'),
    ('Weightlifting'),
    ('Skateboarding'),
    ('Roller Skating'),
    ('Bowling'),
    ('Karaoke'),
    ('Book Club'),
    ('Coding'),
    ('Woodworking'),
    ('Pottery'),
    ('Glassblowing'),
    ('Drama/Theater'),
    ('Fashion'),
    ('Interior Design'),
    ('Tea'),
    ('Coffee'),
    ('Wine Tasting'),
    ('Food Exploration'),
    ('Nature'),
    ('Animals'),
    ('Dogs'),
    ('Cats'),
    ('Horseback Riding'),
    ('Scuba Diving'),
    ('Snorkeling'),
    ('Kayaking'),
    ('Rowing'),
    ('Meditation Retreats'),
    ('Spiritual Practices'),
    ('Tarot'),
    ('Astronomy'),
    ('Space'),
    ('Science'),
    ('History'),
    ('Philosophy'),
    ('Psychology'),
    ('Self-Improvement'),
    ('Minimalism'),
    ('Sustainability'),
    ('Fitness'),
    ('Health'),
    ('Wellness'),
    ('Nutrition'),
    ('Craft Beer'),
    ('Mixology'),
    ('Sushi Making'),
    ('Blogging'),
    ('Vlogging'),
    ('Podcasting'),
    ('Crypto'),
    ('Investing'),
    ('Real Estate'),
    ('Startups'),
    ('Networking'),
    ('Public Speaking'),
    ('Teaching'),
    ('Mentoring'),
    ('Parenting'),
    ('Home Improvement'),
    ('Car Enthusiast'),
    ('Motorcycles'),
    ('Aviation'),
    ('Sailing'),
    ('Paddleboarding'),
    ('Ice Skating'),
    ('Snowshoeing'),
    ('Geocaching'),
    ('Puzzles'),
    ('Escape Rooms'),
    ('Laser Tag'),
    ('Paintball'),
    ('Go-Karting'),
    ('Bungee Jumping'),
    ('Skydiving'),
    ('Paragliding'),
    ('Ziplining'),
    ('Axe Throwing'),
    ('Archery'),
    ('Fencing'),
    ('Table Tennis'),
    ('Badminton'),
    ('Squash'),
    ('Rugby'),
    ('Cricket'),
    ('Golf'),
    ('Boxing'),
    ('Wrestling'),
    ('Judo'),
    ('Karate'),
    ('Taekwondo'),
    ('Tai Chi'),
    ('Qigong'),
    ('Reiki'),
    ('Crystal Healing'),
    ('Aromatherapy'),
    ('Sound Healing'),
    ('Chanting'),
    ('Breathwork'),
    ('Cold Plunge'),
    ('Sauna'),
    ('Spa'),
    ('Journaling'),
    ('Gratitude Practice'),
    ('Dream Journaling'),
    ('Lucid Dreaming'),
    ('Anime'),
    ('K-Pop'),
    ('Cosplay'),
    ('LARPing'),
    ('Tabletop RPGs'),
    ('Dungeons & Dragons'),
    ('Magic Tricks'),
    ('Juggling'),
    ('Parkour'),
    ('Pickleball'),
    ('Chess'),
    ('Poker'),
    ('Billiards'),
    ('Darts'),
    ('Pinball'),
    ('Retro Gaming'),
    ('Streaming'),
    ('Filmmaking'),
    ('Animation'),
    ('DJing'),
    ('Songwriting'),
    ('Poetry'),
    ('Calligraphy'),
    ('Origami'),
    ('Scrapbooking'),
    ('Nail Art'),
    ('Makeup'),
    ('Skincare'),
    ('Candle Making'),
    ('Soap Making'),
    ('3D Printing'),
    ('Robotics'),
    ('Ham Radio'),
    ('Speedcubing'),
    ('Lockpicking'),
    ('Fire Spinning'),
    ('Hula Hooping'),
    ('Slacklining'),
    ('Belly Dancing'),
    ('Folk Dancing'),
    ('Ballroom Dancing'),
    ('Salsa Dancing'),
    ('Tango'),
    ('Swing Dancing'),
    ('Breakdancing'),
    ('Ballet'),
    ('Home Brewing'),
    ('Cheese Making'),
    ('Chocolate Making'),
    ('BBQ & Grilling'),
    ('Smoking Meat'),
    ('Vegan Cooking'),
    ('Houseplants'),
    ('Bonsai'),
    ('Terrariums'),
    ('Urban Farming'),
    ('Hydroponics'),
    ('Van Life'),
    ('RV Life'),
    ('Digital Nomad'),
    ('Language Learning'),
    ('Ceramics'),
    ('Sculpture'),
    ('Miniature Painting'),
    ('Model Building'),
    ('Dioramas'),
    ('Puppetry'),
    ('Stand-up Comedy'),
    ('Improv'),
    ('Podcast Hosting'),
    ('Debate'),
    ('Board Game Design'),
    ('Game Development'),
    ('App Development'),
    ('Drone Racing'),
    ('RC Cars'),
    ('Model Rockets'),
    ('Astrophotography'),
    ('Wildlife Photography'),
    ('Backpacking'),
    ('Solo Travel'),
    ('Thrift Shopping'),
    ('Antiques'),
    ('Vinyl Collecting'),
    ('Sneaker Collecting'),
    ('Card Games'),
    ('Go'),
    ('Mahjong'),
    ('Beekeeping'),
    ('Foraging'),
    ('Mushroom Hunting'),
    ('Urban Exploration'),
    ('Leatherworking'),
    ('Jewelry Making'),
    ('Embroidery'),
    ('Crochet'),
    ('Macramé'),
    ('Tie-Dye'),
    ('Screen Printing'),
    ('Printmaking'),
    ('Mural Painting'),
    ('Street Art'),
    ('Digital Art'),
    ('Pixel Art'),
    ('NFT Art'),
    ('AI Art'),
    ('Cooking Classes'),
    ('Food Trucks'),
    ('Restaurant Hopping'),
    ('Coffee Roasting'),
    ('Tea Blending'),
    ('Wine Making'),
    ('Kombucha Making'),
    ('Fermenting'),
    ('Meal Prep'),
    ('Grilling'),
    ('Smoking')
ON CONFLICT (name) DO NOTHING;

-- 1️⃣2️⃣ Insert sample data into orientations
INSERT INTO orientations (name) VALUES
    ('Straight'),
    ('Gay'),
    ('Lesbian'),
    ('Bisexual'),
    ('Pansexual'),
    ('Asexual'),
    ('Demisexual'),
    ('Queer'),
    ('Questioning'),
    ('Polysexual'),
    ('Omnisexual'),
    ('Graysexual'),
    ('Grayromantic'),
    ('Polyamorous'),
    ('Heteroflexible'),
    ('Homoflexible'),
    ('Androsexual'),
    ('Gynesexual'),
    ('Skoliosexual'),
    ('Aroace'),
    ('Aceflux'),
    ('Aromantic'),
    ('Demiromantic'),
    ('Abrosexual'),
    ('Reciprosexual'),
    ('Cupiosexual'),
    ('Fraysexual'),
    ('Lithromantic'),
    ('Quoiromantic'),
    ('Sapphic'),
    ('Achillean'),
    ('Uranic'),
    ('Ceterosexual'),
    ('Other');

-- 1️⃣3️⃣ Insert sample data into sexes
INSERT INTO sexes (name) VALUES
    ('Male'),
    ('Female'),
    ('Non-binary'),
    ('Transgender Male'),
    ('Transgender Female'),
    ('Transsexual'),
    ('Transfeminine'),
    ('Transmasculine'),
    ('Third Gender'),
    ('Androgyne'),
    ('Neutrois'),
    ('Demiboy'),
    ('Demigirl'),
    ('Genderqueer'),
    ('Genderfluid'),
    ('Agender'),
    ('Bigender'),
    ('Pangender'),
    ('Maverique'),
    ('Xenogender'),
    ('Two-Spirit'),
    ('Intersex'),
    ('Gender Non-conforming'),
    ('Questioning'),
    ('Other');

-- 1️⃣3️⃣.5 Insert sample data into core_values
INSERT INTO core_values (key, translation_key) VALUES
    ('spirituality', 'profile.core_values.spirituality'),
    ('kindness', 'profile.core_values.kindness'),
    ('creativity', 'profile.core_values.creativity'),
    ('authenticity', 'profile.core_values.authenticity'),
    ('growth', 'profile.core_values.growth'),
    ('adventure', 'profile.core_values.adventure'),
    ('commitment', 'profile.core_values.commitment'),
    ('honesty', 'profile.core_values.honesty'),
    ('loyalty', 'profile.core_values.loyalty'),
    ('family', 'profile.core_values.family'),
    ('freedom', 'profile.core_values.freedom'),
    ('justice', 'profile.core_values.justice'),
    ('compassion', 'profile.core_values.compassion'),
    ('wisdom', 'profile.core_values.wisdom'),
    ('humor', 'profile.core_values.humor'),
    ('health', 'profile.core_values.health'),
    ('sustainability', 'profile.core_values.sustainability'),
    ('innovation', 'profile.core_values.innovation'),
    ('tradition', 'profile.core_values.tradition'),
    ('community', 'profile.core_values.community')
ON CONFLICT (key) DO NOTHING;

-- 1️⃣3️⃣.6 Insert sample data into intentions
INSERT INTO intentions (key, translation_key) VALUES
    ('soulmate', 'register.options.intentions.soulmate'),
    ('casual_relationship', 'register.options.intentions.casual_relationship'),
    ('exploring', 'register.options.intentions.exploring'),
    ('friendship', 'register.options.intentions.friendship'),
    ('long_term_relationship', 'register.options.intentions.long_term_relationship'),
    ('marriage', 'register.options.intentions.marriage'),
    ('short_term_dating', 'register.options.intentions.short_term_dating'),
    ('activity_partner', 'register.options.intentions.activity_partner')
ON CONFLICT (key) DO NOTHING;

-- 1️⃣4️⃣ Optional test user (only inserts if missing) password user
INSERT INTO syno_users (email, password_hash) 
VALUES ('test@example.com', '$2a$12$hNpHdvZXLQuRPxKVz/7NFuBKotAgxeFij6GLNsMbzxdWAflKEDxfG')
ON CONFLICT (email) DO NOTHING;

-- 1️⃣5️⃣ Optional test profile (only inserts if missing)
INSERT INTO profiles (user_id, name, last_name, birth_date, birth_time, location_id, sex_id, orientation_id, bio)
SELECT DISTINCT
 u.id,
    'Test User',
    'Test User2',
    '1976-06-26'::date,
    '22:44',
    (SELECT id FROM locations WHERE name = 'New York' AND type = 'city' AND parent_id = (SELECT id FROM locations WHERE name = 'USA')),
    (SELECT id FROM sexes WHERE name = 'Male'),
    (SELECT id FROM orientations WHERE name = 'Bisexual'),
    'This is a test user profile.'
FROM syno_users u
WHERE u.email = 'test@example.com'
  AND NOT EXISTS (
    SELECT 1 FROM profiles p WHERE p.user_id = u.id
  )
ON CONFLICT DO NOTHING;

-- 1️⃣6️⃣ Optional test profile hobbies (only inserts if profile was created)
INSERT INTO profile_hobbies (profile_id, hobby_id)
SELECT
 p.id,
    h.id
FROM profiles p
JOIN hobbies h ON h.name IN ('Astrology', 'Hiking')
WHERE p.user_id = (SELECT id FROM syno_users WHERE email = 'test@example.com')
ON CONFLICT (profile_id, hobby_id) DO NOTHING;

-- 1️⃣6️⃣.5 Optional test profile intentions and core values
INSERT INTO profile_intentions (profile_id, intention_id)
SELECT
 p.id,
 i.id
FROM profiles p
JOIN intentions i ON i.key = 'soulmate'
WHERE p.user_id = (SELECT id FROM syno_users WHERE email = 'test@example.com')
ON CONFLICT DO NOTHING;

INSERT INTO profile_core_values (profile_id, core_value_id)
SELECT
 p.id,
 cv.id
FROM profiles p
JOIN core_values cv ON cv.key IN ('spirituality', 'kindness', 'adventure')
WHERE p.user_id = (SELECT id FROM syno_users WHERE email = 'test@example.com')
ON CONFLICT DO NOTHING;



-- 1. Create the settings table to store detailed theme customization
CREATE TABLE IF NOT EXISTS settings (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL UNIQUE,
    theme_id VARCHAR(50),
    background_color VARCHAR(50),
    accent_color VARCHAR(50),
    layout VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_user_settings FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE
);

-- 2. Add theme_id column to profiles table if it doesn't exist
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS theme_id VARCHAR(50);
ALTER TABLE otps ADD COLUMN attempts INTEGER DEFAULT 0;

-- ===============================================
-- 1️⃣7️⃣ Done.
-- Done. Tables ready and test user inserted safely.
-- Remember to seed cities, countries, hobbies, orientations, and sexes.
-- ===============================================

-- 5️⃣.8 Cleanup Function for OTPs
-- Create a trigger function
CREATE OR REPLACE FUNCTION cleanup_expired_otps()
RETURNS void AS $$
BEGIN
    DELETE FROM otps
    WHERE expires_at < NOW()
       OR used_flag = TRUE;
END;
$$ LANGUAGE plpgsql;

-- 3. Create a Trigger Function to call the Cleanup
CREATE OR REPLACE FUNCTION trigger_cleanup_otps_handler()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM cleanup_expired_otps();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. Set the Trigger to fire every time a new code is created
DROP TRIGGER IF EXISTS cleanup_on_insert ON otps;
CREATE TRIGGER cleanup_on_insert
AFTER INSERT ON otps
FOR EACH STATEMENT
EXECUTE FUNCTION trigger_cleanup_otps_handler();

-- 1. Update Profiles table to include unique phone numbers
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS phone_number VARCHAR(20);
ALTER TABLE profiles ADD CONSTRAINT uq_profiles_phone_number UNIQUE (phone_number);

-- 2. Update OTPs table to support SMS and rate limiting
-- Make email nullable as we now support phone-based OTP
ALTER TABLE otps ALTER COLUMN email DROP NOT NULL;

-- Add phone_number and tracking columns
ALTER TABLE otps ADD COLUMN IF NOT EXISTS phone_number VARCHAR(20);

-- Create index for phone_number lookups in OTP table
CREATE INDEX IF NOT EXISTS ix_otps_phone_number ON otps (phone_number);

-- ===============================================
-- Add translation_key support for localized profile lookup tables
-- ===============================================

-- Add columns
ALTER TABLE locations
    ADD COLUMN IF NOT EXISTS translation_key VARCHAR(150);

ALTER TABLE educations
    ADD COLUMN IF NOT EXISTS translation_key VARCHAR(150);

ALTER TABLE professions
    ADD COLUMN IF NOT EXISTS translation_key VARCHAR(150);

ALTER TABLE hobbies
    ADD COLUMN IF NOT EXISTS translation_key VARCHAR(150);

ALTER TABLE orientations
    ADD COLUMN IF NOT EXISTS translation_key VARCHAR(150);

ALTER TABLE sexes
    ADD COLUMN IF NOT EXISTS translation_key VARCHAR(150);


-- ===============================================
-- Populate translation keys
-- ===============================================

-- Educations
UPDATE educations
SET translation_key = CASE name
    WHEN 'High School' THEN 'profile.educations.high_school'
    WHEN 'GED' THEN 'profile.educations.ged'
    WHEN 'Some College' THEN 'profile.educations.some_college'
    WHEN 'Associate Degree' THEN 'profile.educations.associate'
    WHEN 'Associate of Arts (AA)' THEN 'profile.educations.associate_arts'
    WHEN 'Associate of Science (AS)' THEN 'profile.educations.associate_science'
    WHEN 'Bachelor''s Degree' THEN 'profile.educations.bachelor'
    WHEN 'Bachelor of Arts (BA)' THEN 'profile.educations.bachelor_arts'
    WHEN 'Bachelor of Science (BS)' THEN 'profile.educations.bachelor_science'
    WHEN 'Master''s Degree' THEN 'profile.educations.master'
    WHEN 'Master of Arts (MA)' THEN 'profile.educations.master_arts'
    WHEN 'Master of Science (MS)' THEN 'profile.educations.master_science'
    WHEN 'Master of Business Administration (MBA)' THEN 'profile.educations.mba'
    WHEN 'Doctorate (PhD)' THEN 'profile.educations.phd'
    WHEN 'Juris Doctor (JD)' THEN 'profile.educations.juris_doctor'
    WHEN 'Doctor of Medicine (MD)' THEN 'profile.educations.doctor_medicine'
    WHEN 'Doctor of Osteopathy (DO)' THEN 'profile.educations.doctor_osteopathy'
    WHEN 'Trade/Vocational School' THEN 'profile.educations.trade_school'
    WHEN 'Professional Degree (MD, JD, etc.)' THEN 'profile.educations.professional_degree'
    WHEN 'Post-Doctoral' THEN 'profile.educations.post_doctoral'
    WHEN 'Certificate Program' THEN 'profile.educations.certificate_program'
    WHEN 'Online Course/Certification' THEN 'profile.educations.online_course'
    WHEN 'Some University' THEN 'profile.educations.some_university'
    WHEN 'Currently in High School' THEN 'profile.educations.currently_high_school'
    WHEN 'Currently in College/University' THEN 'profile.educations.currently_college'
    WHEN 'Apprenticeship' THEN 'profile.educations.apprenticeship'
    WHEN 'Diploma' THEN 'profile.educations.diploma'
    WHEN 'Art School' THEN 'profile.educations.art_school'
    WHEN 'Music School/Conservatory' THEN 'profile.educations.music_school'
    WHEN 'Film School' THEN 'profile.educations.film_school'
    WHEN 'Coding Bootcamp' THEN 'profile.educations.coding_bootcamp'
    WHEN 'Seminary' THEN 'profile.educations.seminary'
    WHEN 'Other' THEN 'profile.educations.other'
END
WHERE translation_key IS NULL;


-- Professions
UPDATE professions
SET translation_key = CASE name
    WHEN 'Software Developer' THEN 'profile.professions.software_developer'
    WHEN 'Data Scientist' THEN 'profile.professions.data_scientist'
    WHEN 'Doctor' THEN 'profile.professions.doctor'
    WHEN 'Nurse' THEN 'profile.professions.nurse'
    WHEN 'Teacher' THEN 'profile.professions.teacher'
    WHEN 'Professor' THEN 'profile.professions.professor'
    WHEN 'Lawyer' THEN 'profile.professions.lawyer'
    WHEN 'Accountant' THEN 'profile.professions.accountant'
    WHEN 'Architect' THEN 'profile.professions.architect'
    WHEN 'Graphic Designer' THEN 'profile.professions.graphic_designer'
    WHEN 'Marketing Manager' THEN 'profile.professions.marketing_manager'
    WHEN 'Sales Representative' THEN 'profile.professions.sales_representative'
    WHEN 'Business Analyst' THEN 'profile.professions.business_analyst'
    WHEN 'Project Manager' THEN 'profile.professions.project_manager'
    WHEN 'Financial Advisor' THEN 'profile.professions.financial_advisor'
    WHEN 'Psychologist' THEN 'profile.professions.psychologist'
    WHEN 'Therapist' THEN 'profile.professions.therapist'
    WHEN 'Dentist' THEN 'profile.professions.dentist'
    WHEN 'Pharmacist' THEN 'profile.professions.pharmacist'
    WHEN 'Veterinarian' THEN 'profile.professions.veterinarian'
    WHEN 'Journalist' THEN 'profile.professions.journalist'
    WHEN 'Writer' THEN 'profile.professions.writer'
    WHEN 'Photographer' THEN 'profile.professions.photographer'
    WHEN 'Chef' THEN 'profile.professions.chef'
    WHEN 'Musician' THEN 'profile.professions.musician'
    WHEN 'Actor' THEN 'profile.professions.actor'
    WHEN 'Entrepreneur' THEN 'profile.professions.entrepreneur'
    WHEN 'Real Estate Agent' THEN 'profile.professions.real_estate_agent'
    WHEN 'Police Officer' THEN 'profile.professions.police_officer'
    WHEN 'Firefighter' THEN 'profile.professions.firefighter'
    WHEN 'Pilot' THEN 'profile.professions.pilot'
    WHEN 'Civil Engineer' THEN 'profile.professions.civil_engineer'
    WHEN 'Mechanical Engineer' THEN 'profile.professions.mechanical_engineer'
    WHEN 'Electrical Engineer' THEN 'profile.professions.electrical_engineer'
    WHEN 'Web Designer' THEN 'profile.professions.web_designer'
    WHEN 'UX/UI Designer' THEN 'profile.professions.ux_ui_designer'
    WHEN 'Content Creator' THEN 'profile.professions.content_creator'
    WHEN 'Social Media Manager' THEN 'profile.professions.social_media_manager'
    WHEN 'Human Resources Manager' THEN 'profile.professions.human_resources_manager'
    WHEN 'Consultant' THEN 'profile.professions.consultant'
    WHEN 'Researcher' THEN 'profile.professions.researcher'
    WHEN 'Scientist' THEN 'profile.professions.scientist'
    WHEN 'Librarian' THEN 'profile.professions.librarian'
    WHEN 'Plumber' THEN 'profile.professions.plumber'
    WHEN 'Electrician' THEN 'profile.professions.electrician'
    WHEN 'Carpenter' THEN 'profile.professions.carpenter'
    WHEN 'Barista' THEN 'profile.professions.barista'
    WHEN 'Retail Worker' THEN 'profile.professions.retail_worker'
    WHEN 'Student' THEN 'profile.professions.student'
    WHEN 'Intern' THEN 'profile.professions.intern'
    WHEN 'Freelancer' THEN 'profile.professions.freelancer'
    WHEN 'Retired' THEN 'profile.professions.retired'
    WHEN 'Surgeon' THEN 'profile.professions.surgeon'
    WHEN 'Paramedic' THEN 'profile.professions.paramedic'
    WHEN 'Physical Therapist' THEN 'profile.professions.physical_therapist'
    WHEN 'Occupational Therapist' THEN 'profile.professions.occupational_therapist'
    WHEN 'Speech Therapist' THEN 'profile.professions.speech_therapist'
    WHEN 'Social Worker' THEN 'profile.professions.social_worker'
    WHEN 'Counselor' THEN 'profile.professions.counselor'
    WHEN 'Dietitian' THEN 'profile.professions.dietitian'
    WHEN 'Nutritionist' THEN 'profile.professions.nutritionist'
    WHEN 'Radiologist' THEN 'profile.professions.radiologist'
    WHEN 'Anesthesiologist' THEN 'profile.professions.anesthesiologist'
    WHEN 'Cardiologist' THEN 'profile.professions.cardiologist'
    WHEN 'Dermatologist' THEN 'profile.professions.dermatologist'
    WHEN 'Neurologist' THEN 'profile.professions.neurologist'
    WHEN 'Pediatrician' THEN 'profile.professions.pediatrician'
    WHEN 'Psychiatrist' THEN 'profile.professions.psychiatrist'
    WHEN 'Optometrist' THEN 'profile.professions.optometrist'
    WHEN 'Chiropractor' THEN 'profile.professions.chiropractor'
    WHEN 'Environmental Scientist' THEN 'profile.professions.environmental_scientist'
    WHEN 'Marine Biologist' THEN 'profile.professions.marine_biologist'
    WHEN 'Archaeologist' THEN 'profile.professions.archaeologist'
    WHEN 'Geologist' THEN 'profile.professions.geologist'
    WHEN 'Meteorologist' THEN 'profile.professions.meteorologist'
    WHEN 'Statistician' THEN 'profile.professions.statistician'
    WHEN 'Actuary' THEN 'profile.professions.actuary'
    WHEN 'Economist' THEN 'profile.professions.economist'
    WHEN 'Linguist' THEN 'profile.professions.linguist'
    WHEN 'Translator' THEN 'profile.professions.translator'
    WHEN 'Interpreter' THEN 'profile.professions.interpreter'
    WHEN 'Flight Attendant' THEN 'profile.professions.flight_attendant'
    WHEN 'Air Traffic Controller' THEN 'profile.professions.air_traffic_controller'
    WHEN 'Marine Engineer' THEN 'profile.professions.marine_engineer'
    WHEN 'Structural Engineer' THEN 'profile.professions.structural_engineer'
    WHEN 'Environmental Engineer' THEN 'profile.professions.environmental_engineer'
    WHEN 'Software Engineer' THEN 'profile.professions.software_engineer'
    WHEN 'Hardware Engineer' THEN 'profile.professions.hardware_engineer'
    WHEN 'Network Engineer' THEN 'profile.professions.network_engineer'
    WHEN 'Cybersecurity Analyst' THEN 'profile.professions.cybersecurity_analyst'
    WHEN 'Database Administrator' THEN 'profile.professions.database_administrator'
    WHEN 'Cloud Architect' THEN 'profile.professions.cloud_architect'
    WHEN 'DevOps Engineer' THEN 'profile.professions.devops_engineer'
    WHEN 'Technical Writer' THEN 'profile.professions.technical_writer'
    WHEN 'Paralegal' THEN 'profile.professions.paralegal'
    WHEN 'Compliance Officer' THEN 'profile.professions.compliance_officer'
    WHEN 'Risk Manager' THEN 'profile.professions.risk_manager'
    WHEN 'Investment Banker' THEN 'profile.professions.investment_banker'
    WHEN 'Portfolio Manager' THEN 'profile.professions.portfolio_manager'
    WHEN 'Financial Analyst' THEN 'profile.professions.financial_analyst'
    WHEN 'Credit Analyst' THEN 'profile.professions.credit_analyst'
    WHEN 'Loan Officer' THEN 'profile.professions.loan_officer'
    WHEN 'Retail Manager' THEN 'profile.professions.retail_manager'
    WHEN 'Restaurant Manager' THEN 'profile.professions.restaurant_manager'
    WHEN 'Hotel Manager' THEN 'profile.professions.hotel_manager'
    WHEN 'Event Planner' THEN 'profile.professions.event_planner'
    WHEN 'Wedding Planner' THEN 'profile.professions.wedding_planner'
    WHEN 'Travel Agent' THEN 'profile.professions.travel_agent'
    WHEN 'Tour Guide' THEN 'profile.professions.tour_guide'
    WHEN 'Administrative Assistant' THEN 'profile.professions.administrative_assistant'
    WHEN 'Executive Assistant' THEN 'profile.professions.executive_assistant'
    WHEN 'Operations Manager' THEN 'profile.professions.operations_manager'
    WHEN 'Supply Chain Manager' THEN 'profile.professions.supply_chain_manager'
    WHEN 'Logistics Manager' THEN 'profile.professions.logistics_manager'
    WHEN 'Quality Control Inspector' THEN 'profile.professions.quality_control_inspector'
    WHEN 'Health Inspector' THEN 'profile.professions.health_inspector'
    WHEN 'Detective' THEN 'profile.professions.detective'
    WHEN 'Forensic Scientist' THEN 'profile.professions.forensic_scientist'
    WHEN 'Intelligence Analyst' THEN 'profile.professions.intelligence_analyst'
    WHEN 'Security Consultant' THEN 'profile.professions.security_consultant'
    WHEN 'Private Investigator' THEN 'profile.professions.private_investigator'
    WHEN 'Judge' THEN 'profile.professions.judge'
    WHEN 'Mediator' THEN 'profile.professions.mediator'
    WHEN 'Lobbyist' THEN 'profile.professions.lobbyist'
    WHEN 'Political Consultant' THEN 'profile.professions.political_consultant'
    WHEN 'Speechwriter' THEN 'profile.professions.speechwriter'
    WHEN 'Press Secretary' THEN 'profile.professions.press_secretary'
    WHEN 'Communications Director' THEN 'profile.professions.communications_director'
    WHEN 'Brand Manager' THEN 'profile.professions.brand_manager'
    WHEN 'Product Manager' THEN 'profile.professions.product_manager'
    WHEN 'Data Analyst' THEN 'profile.professions.data_analyst'
    WHEN 'Market Research Analyst' THEN 'profile.professions.market_research_analyst'
    WHEN 'Machine Learning Engineer' THEN 'profile.professions.machine_learning_engineer'
    WHEN 'AI Researcher' THEN 'profile.professions.ai_researcher'
    WHEN 'Robotics Engineer' THEN 'profile.professions.robotics_engineer'
    WHEN 'Automation Engineer' THEN 'profile.professions.automation_engineer'
    WHEN 'Telecommunications Engineer' THEN 'profile.professions.telecommunications_engineer'
    WHEN 'Audio Engineer' THEN 'profile.professions.audio_engineer'
    WHEN 'Video Engineer' THEN 'profile.professions.video_engineer'
    WHEN 'Lighting Designer' THEN 'profile.professions.lighting_designer'
    WHEN 'Set Designer' THEN 'profile.professions.set_designer'
    WHEN 'Costume Designer' THEN 'profile.professions.costume_designer'
    WHEN 'Makeup Artist' THEN 'profile.professions.makeup_artist'
    WHEN 'Hair Stylist' THEN 'profile.professions.hair_stylist'
    WHEN 'Massage Therapist' THEN 'profile.professions.massage_therapist'
    WHEN 'Acupuncturist' THEN 'profile.professions.acupuncturist'
    WHEN 'Midwife' THEN 'profile.professions.midwife'
    WHEN 'Genetic Counselor' THEN 'profile.professions.genetic_counselor'
    WHEN 'Art Therapist' THEN 'profile.professions.art_therapist'
    WHEN 'Music Therapist' THEN 'profile.professions.music_therapist'
    WHEN 'Recreation Therapist' THEN 'profile.professions.recreation_therapist'
    WHEN 'Nonprofit Director' THEN 'profile.professions.nonprofit_director'
    WHEN 'Grant Writer' THEN 'profile.professions.grant_writer'
    WHEN 'Academic Advisor' THEN 'profile.professions.academic_advisor'
    WHEN 'Career Counselor' THEN 'profile.professions.career_counselor'
    WHEN 'Athletic Director' THEN 'profile.professions.athletic_director'
    WHEN 'Coach' THEN 'profile.professions.coach'
    WHEN 'Personal Trainer' THEN 'profile.professions.personal_trainer'
    WHEN 'Yoga Instructor' THEN 'profile.professions.yoga_instructor'
    WHEN 'Swimming Instructor' THEN 'profile.professions.swimming_instructor'
    WHEN 'Ski Instructor' THEN 'profile.professions.ski_instructor'
    WHEN 'Surf Instructor' THEN 'profile.professions.surf_instructor'
    WHEN 'Park Ranger' THEN 'profile.professions.park_ranger'
    WHEN 'Conservation Officer' THEN 'profile.professions.conservation_officer'
    WHEN 'Zookeeper' THEN 'profile.professions.zookeeper'
    WHEN 'Animal Trainer' THEN 'profile.professions.animal_trainer'
    WHEN 'Pet Groomer' THEN 'profile.professions.pet_groomer'
    WHEN 'Veterinary Technician' THEN 'profile.professions.veterinary_technician'
    WHEN 'Pharmaceutical Sales Rep' THEN 'profile.professions.pharmaceutical_sales_rep'
    WHEN 'Account Executive' THEN 'profile.professions.account_executive'
    WHEN 'Business Development Manager' THEN 'profile.professions.business_development_manager'
    WHEN 'Creative Director' THEN 'profile.professions.creative_director'
    WHEN 'Art Director' THEN 'profile.professions.art_director'
    WHEN 'Motion Designer' THEN 'profile.professions.motion_designer'
    WHEN '3D Artist' THEN 'profile.professions.3d_artist'
    WHEN 'Videographer' THEN 'profile.professions.videographer'
    WHEN 'Editor' THEN 'profile.professions.editor'
    WHEN 'Composer' THEN 'profile.professions.composer'
    WHEN 'Choreographer' THEN 'profile.professions.choreographer'
    WHEN 'Director' THEN 'profile.professions.director'
    WHEN 'Producer' THEN 'profile.professions.producer'
    WHEN 'Screenwriter' THEN 'profile.professions.screenwriter'
    WHEN 'Playwright' THEN 'profile.professions.playwright'
    WHEN 'Novelist' THEN 'profile.professions.novelist'
    WHEN 'Poet' THEN 'profile.professions.poet'
    WHEN 'Reporter' THEN 'profile.professions.reporter'
    WHEN 'Anchor' THEN 'profile.professions.anchor'
    WHEN 'Host' THEN 'profile.professions.host'
    WHEN 'Critic' THEN 'profile.professions.critic'
    WHEN 'Publisher' THEN 'profile.professions.publisher'
    WHEN 'Publicist' THEN 'profile.professions.publicist'
    WHEN 'Stage Manager' THEN 'profile.professions.stage_manager'
    WHEN 'Concert Promoter' THEN 'profile.professions.concert_promoter'
    WHEN 'Booking Agent' THEN 'profile.professions.booking_agent'
    WHEN 'Tour Manager' THEN 'profile.professions.tour_manager'
    WHEN 'Other' THEN 'profile.professions.other'
END
WHERE translation_key IS NULL;


-- Hobbies
UPDATE hobbies
SET translation_key = CASE name
    WHEN 'Yoga' THEN 'profile.hobbies.yoga'
    WHEN 'Meditation' THEN 'profile.hobbies.meditation'
    WHEN 'Astrology' THEN 'profile.hobbies.astrology'
    WHEN 'Hiking' THEN 'profile.hobbies.hiking'
    WHEN 'Reading' THEN 'profile.hobbies.reading'
    WHEN 'Music' THEN 'profile.hobbies.music'
    WHEN 'Traveling' THEN 'profile.hobbies.traveling'
    WHEN 'Photography' THEN 'profile.hobbies.photography'
    WHEN 'Cooking' THEN 'profile.hobbies.cooking'
    WHEN 'Baking' THEN 'profile.hobbies.baking'
    WHEN 'Gaming' THEN 'profile.hobbies.gaming'
    WHEN 'Painting' THEN 'profile.hobbies.painting'
    WHEN 'Drawing' THEN 'profile.hobbies.drawing'
    WHEN 'Writing' THEN 'profile.hobbies.writing'
    WHEN 'Dancing' THEN 'profile.hobbies.dancing'
    WHEN 'Running' THEN 'profile.hobbies.running'
    WHEN 'Jogging' THEN 'profile.hobbies.jogging'
    WHEN 'Swimming' THEN 'profile.hobbies.swimming'
    WHEN 'Cycling' THEN 'profile.hobbies.cycling'
    WHEN 'Tennis' THEN 'profile.hobbies.tennis'
    WHEN 'Basketball' THEN 'profile.hobbies.basketball'
    WHEN 'Football' THEN 'profile.hobbies.football'
    WHEN 'Volleyball' THEN 'profile.hobbies.volleyball'
    WHEN 'Skiing' THEN 'profile.hobbies.skiing'
    WHEN 'Snowboarding' THEN 'profile.hobbies.snowboarding'
    WHEN 'Surfing' THEN 'profile.hobbies.surfing'
    WHEN 'Rock Climbing' THEN 'profile.hobbies.rock_climbing'
    WHEN 'Camping' THEN 'profile.hobbies.camping'
    WHEN 'Gardening' THEN 'profile.hobbies.gardening'
    WHEN 'DIY Projects' THEN 'profile.hobbies.diy_projects'
    WHEN 'Crafts' THEN 'profile.hobbies.crafts'
    WHEN 'Knitting' THEN 'profile.hobbies.knitting'
    WHEN 'Sewing' THEN 'profile.hobbies.sewing'
    WHEN 'Watching Movies' THEN 'profile.hobbies.watching_movies'
    WHEN 'Watching TV Shows' THEN 'profile.hobbies.watching_tv_shows'
    WHEN 'Podcasts' THEN 'profile.hobbies.podcasts'
    WHEN 'Volunteering' THEN 'profile.hobbies.volunteering'
    WHEN 'Walking' THEN 'profile.hobbies.walking'
    WHEN 'Board Games' THEN 'profile.hobbies.board_games'
    WHEN 'Collecting' THEN 'profile.hobbies.collecting'
    WHEN 'Bird Watching' THEN 'profile.hobbies.bird_watching'
    WHEN 'Fishing' THEN 'profile.hobbies.fishing'
    WHEN 'Martial Arts' THEN 'profile.hobbies.martial_arts'
    WHEN 'Pilates' THEN 'profile.hobbies.pilates'
    WHEN 'CrossFit' THEN 'profile.hobbies.crossfit'
    WHEN 'Weightlifting' THEN 'profile.hobbies.weightlifting'
    WHEN 'Skateboarding' THEN 'profile.hobbies.skateboarding'
    WHEN 'Roller Skating' THEN 'profile.hobbies.roller_skating'
    WHEN 'Bowling' THEN 'profile.hobbies.bowling'
    WHEN 'Karaoke' THEN 'profile.hobbies.karaoke'
    WHEN 'Book Club' THEN 'profile.hobbies.book_club'
    WHEN 'Coding' THEN 'profile.hobbies.coding'
    WHEN 'Woodworking' THEN 'profile.hobbies.woodworking'
    WHEN 'Pottery' THEN 'profile.hobbies.pottery'
    WHEN 'Glassblowing' THEN 'profile.hobbies.glassblowing'
    WHEN 'Drama/Theater' THEN 'profile.hobbies.drama_theater'
    WHEN 'Fashion' THEN 'profile.hobbies.fashion'
    WHEN 'Interior Design' THEN 'profile.hobbies.interior_design'
    WHEN 'Tea' THEN 'profile.hobbies.tea'
    WHEN 'Coffee' THEN 'profile.hobbies.coffee'
    WHEN 'Wine Tasting' THEN 'profile.hobbies.wine_tasting'
    WHEN 'Food Exploration' THEN 'profile.hobbies.food_exploration'
    WHEN 'Nature' THEN 'profile.hobbies.nature'
    WHEN 'Animals' THEN 'profile.hobbies.animals'
    WHEN 'Dogs' THEN 'profile.hobbies.dogs'
    WHEN 'Cats' THEN 'profile.hobbies.cats'
    WHEN 'Horseback Riding' THEN 'profile.hobbies.horseback_riding'
    WHEN 'Scuba Diving' THEN 'profile.hobbies.scuba_diving'
    WHEN 'Snorkeling' THEN 'profile.hobbies.snorkeling'
    WHEN 'Kayaking' THEN 'profile.hobbies.kayaking'
    WHEN 'Rowing' THEN 'profile.hobbies.rowing'
    WHEN 'Meditation Retreats' THEN 'profile.hobbies.meditation_retreats'
    WHEN 'Spiritual Practices' THEN 'profile.hobbies.spiritual_practices'
    WHEN 'Tarot' THEN 'profile.hobbies.tarot'
    WHEN 'Astronomy' THEN 'profile.hobbies.astronomy'
    WHEN 'Space' THEN 'profile.hobbies.space'
    WHEN 'Science' THEN 'profile.hobbies.science'
    WHEN 'History' THEN 'profile.hobbies.history'
    WHEN 'Philosophy' THEN 'profile.hobbies.philosophy'
    WHEN 'Psychology' THEN 'profile.hobbies.psychology'
    WHEN 'Self-Improvement' THEN 'profile.hobbies.self_improvement'
    WHEN 'Minimalism' THEN 'profile.hobbies.minimalism'
    WHEN 'Sustainability' THEN 'profile.hobbies.sustainability'
    WHEN 'Fitness' THEN 'profile.hobbies.fitness'
    WHEN 'Health' THEN 'profile.hobbies.health'
    WHEN 'Wellness' THEN 'profile.hobbies.wellness'
    WHEN 'Nutrition' THEN 'profile.hobbies.nutrition'
    WHEN 'Craft Beer' THEN 'profile.hobbies.craft_beer'
    WHEN 'Mixology' THEN 'profile.hobbies.mixology'
    WHEN 'Sushi Making' THEN 'profile.hobbies.sushi_making'
    WHEN 'Blogging' THEN 'profile.hobbies.blogging'
    WHEN 'Vlogging' THEN 'profile.hobbies.vlogging'
    WHEN 'Podcasting' THEN 'profile.hobbies.podcasting'
    WHEN 'Crypto' THEN 'profile.hobbies.crypto'
    WHEN 'Investing' THEN 'profile.hobbies.investing'
    WHEN 'Real Estate' THEN 'profile.hobbies.real_estate'
    WHEN 'Startups' THEN 'profile.hobbies.startups'
    WHEN 'Networking' THEN 'profile.hobbies.networking'
    WHEN 'Public Speaking' THEN 'profile.hobbies.public_speaking'
    WHEN 'Teaching' THEN 'profile.hobbies.teaching'
    WHEN 'Mentoring' THEN 'profile.hobbies.mentoring'
    WHEN 'Parenting' THEN 'profile.hobbies.parenting'
    WHEN 'Home Improvement' THEN 'profile.hobbies.home_improvement'
    WHEN 'Car Enthusiast' THEN 'profile.hobbies.car_enthusiast'
    WHEN 'Motorcycles' THEN 'profile.hobbies.motorcycles'
    WHEN 'Aviation' THEN 'profile.hobbies.aviation'
    WHEN 'Sailing' THEN 'profile.hobbies.sailing'
    WHEN 'Paddleboarding' THEN 'profile.hobbies.paddleboarding'
    WHEN 'Ice Skating' THEN 'profile.hobbies.ice_skating'
    WHEN 'Snowshoeing' THEN 'profile.hobbies.snowshoeing'
    WHEN 'Geocaching' THEN 'profile.hobbies.geocaching'
    WHEN 'Puzzles' THEN 'profile.hobbies.puzzles'
    WHEN 'Escape Rooms' THEN 'profile.hobbies.escape_rooms'
    WHEN 'Laser Tag' THEN 'profile.hobbies.laser_tag'
    WHEN 'Paintball' THEN 'profile.hobbies.paintball'
    WHEN 'Go-Karting' THEN 'profile.hobbies.go_karting'
    WHEN 'Bungee Jumping' THEN 'profile.hobbies.bungee_jumping'
    WHEN 'Skydiving' THEN 'profile.hobbies.skydiving'
    WHEN 'Paragliding' THEN 'profile.hobbies.paragliding'
    WHEN 'Ziplining' THEN 'profile.hobbies.ziplining'
    WHEN 'Axe Throwing' THEN 'profile.hobbies.axe_throwing'
    WHEN 'Archery' THEN 'profile.hobbies.archery'
    WHEN 'Fencing' THEN 'profile.hobbies.fencing'
    WHEN 'Table Tennis' THEN 'profile.hobbies.table_tennis'
    WHEN 'Badminton' THEN 'profile.hobbies.badminton'
    WHEN 'Squash' THEN 'profile.hobbies.squash'
    WHEN 'Rugby' THEN 'profile.hobbies.rugby'
    WHEN 'Cricket' THEN 'profile.hobbies.cricket'
    WHEN 'Golf' THEN 'profile.hobbies.golf'
    WHEN 'Boxing' THEN 'profile.hobbies.boxing'
    WHEN 'Wrestling' THEN 'profile.hobbies.wrestling'
    WHEN 'Judo' THEN 'profile.hobbies.judo'
    WHEN 'Karate' THEN 'profile.hobbies.karate'
    WHEN 'Taekwondo' THEN 'profile.hobbies.taekwondo'
    WHEN 'Tai Chi' THEN 'profile.hobbies.tai_chi'
    WHEN 'Qigong' THEN 'profile.hobbies.qigong'
    WHEN 'Reiki' THEN 'profile.hobbies.reiki'
    WHEN 'Crystal Healing' THEN 'profile.hobbies.crystal_healing'
    WHEN 'Aromatherapy' THEN 'profile.hobbies.aromatherapy'
    WHEN 'Sound Healing' THEN 'profile.hobbies.sound_healing'
    WHEN 'Chanting' THEN 'profile.hobbies.chanting'
    WHEN 'Breathwork' THEN 'profile.hobbies.breathwork'
    WHEN 'Cold Plunge' THEN 'profile.hobbies.cold_plunge'
    WHEN 'Sauna' THEN 'profile.hobbies.sauna'
    WHEN 'Spa' THEN 'profile.hobbies.spa'
    WHEN 'Journaling' THEN 'profile.hobbies.journaling'
    WHEN 'Gratitude Practice' THEN 'profile.hobbies.gratitude_practice'
    WHEN 'Dream Journaling' THEN 'profile.hobbies.dream_journaling'
    WHEN 'Lucid Dreaming' THEN 'profile.hobbies.lucid_dreaming'
    WHEN 'Anime' THEN 'profile.hobbies.anime'
    WHEN 'K-Pop' THEN 'profile.hobbies.k_pop'
    WHEN 'Cosplay' THEN 'profile.hobbies.cosplay'
    WHEN 'LARPing' THEN 'profile.hobbies.larping'
    WHEN 'Tabletop RPGs' THEN 'profile.hobbies.tabletop_rpgs'
    WHEN 'Dungeons & Dragons' THEN 'profile.hobbies.dungeons_and_dragons'
    WHEN 'Magic Tricks' THEN 'profile.hobbies.magic_tricks'
    WHEN 'Juggling' THEN 'profile.hobbies.juggling'
    WHEN 'Parkour' THEN 'profile.hobbies.parkour'
    WHEN 'Pickleball' THEN 'profile.hobbies.pickleball'
    WHEN 'Chess' THEN 'profile.hobbies.chess'
    WHEN 'Poker' THEN 'profile.hobbies.poker'
    WHEN 'Billiards' THEN 'profile.hobbies.billiards'
    WHEN 'Darts' THEN 'profile.hobbies.darts'
    WHEN 'Pinball' THEN 'profile.hobbies.pinball'
    WHEN 'Retro Gaming' THEN 'profile.hobbies.retro_gaming'
    WHEN 'Streaming' THEN 'profile.hobbies.streaming'
    WHEN 'Filmmaking' THEN 'profile.hobbies.filmmaking'
    WHEN 'Animation' THEN 'profile.hobbies.animation'
    WHEN 'DJing' THEN 'profile.hobbies.djing'
    WHEN 'Songwriting' THEN 'profile.hobbies.songwriting'
    WHEN 'Poetry' THEN 'profile.hobbies.poetry'
    WHEN 'Calligraphy' THEN 'profile.hobbies.calligraphy'
    WHEN 'Origami' THEN 'profile.hobbies.origami'
    WHEN 'Scrapbooking' THEN 'profile.hobbies.scrapbooking'
    WHEN 'Nail Art' THEN 'profile.hobbies.nail_art'
    WHEN 'Makeup' THEN 'profile.hobbies.makeup'
    WHEN 'Skincare' THEN 'profile.hobbies.skincare'
    WHEN 'Candle Making' THEN 'profile.hobbies.candle_making'
    WHEN 'Soap Making' THEN 'profile.hobbies.soap_making'
    WHEN '3D Printing' THEN 'profile.hobbies.3d_printing'
    WHEN 'Robotics' THEN 'profile.hobbies.robotics'
    WHEN 'Ham Radio' THEN 'profile.hobbies.ham_radio'
    WHEN 'Speedcubing' THEN 'profile.hobbies.speedcubing'
    WHEN 'Lockpicking' THEN 'profile.hobbies.lockpicking'
    WHEN 'Fire Spinning' THEN 'profile.hobbies.fire_spinning'
    WHEN 'Hula Hooping' THEN 'profile.hobbies.hula_hooping'
    WHEN 'Slacklining' THEN 'profile.hobbies.slacklining'
    WHEN 'Belly Dancing' THEN 'profile.hobbies.belly_dancing'
    WHEN 'Folk Dancing' THEN 'profile.hobbies.folk_dancing'
    WHEN 'Ballroom Dancing' THEN 'profile.hobbies.ballroom_dancing'
    WHEN 'Salsa Dancing' THEN 'profile.hobbies.salsa_dancing'
    WHEN 'Tango' THEN 'profile.hobbies.tango'
    WHEN 'Swing Dancing' THEN 'profile.hobbies.swing_dancing'
    WHEN 'Breakdancing' THEN 'profile.hobbies.breakdancing'
    WHEN 'Ballet' THEN 'profile.hobbies.ballet'
    WHEN 'Home Brewing' THEN 'profile.hobbies.home_brewing'
    WHEN 'Cheese Making' THEN 'profile.hobbies.cheese_making'
    WHEN 'Chocolate Making' THEN 'profile.hobbies.chocolate_making'
    WHEN 'BBQ & Grilling' THEN 'profile.hobbies.bbq_and_grilling'
    WHEN 'Smoking Meat' THEN 'profile.hobbies.smoking_meat'
    WHEN 'Vegan Cooking' THEN 'profile.hobbies.vegan_cooking'
    WHEN 'Houseplants' THEN 'profile.hobbies.houseplants'
    WHEN 'Bonsai' THEN 'profile.hobbies.bonsai'
    WHEN 'Terrariums' THEN 'profile.hobbies.terrariums'
    WHEN 'Urban Farming' THEN 'profile.hobbies.urban_farming'
    WHEN 'Hydroponics' THEN 'profile.hobbies.hydroponics'
    WHEN 'Van Life' THEN 'profile.hobbies.van_life'
    WHEN 'RV Life' THEN 'profile.hobbies.rv_life'
    WHEN 'Digital Nomad' THEN 'profile.hobbies.digital_nomad'
    WHEN 'Language Learning' THEN 'profile.hobbies.language_learning'
    WHEN 'Ceramics' THEN 'profile.hobbies.ceramics'
    WHEN 'Sculpture' THEN 'profile.hobbies.sculpture'
    WHEN 'Miniature Painting' THEN 'profile.hobbies.miniature_painting'
    WHEN 'Model Building' THEN 'profile.hobbies.model_building'
    WHEN 'Dioramas' THEN 'profile.hobbies.dioramas'
    WHEN 'Puppetry' THEN 'profile.hobbies.puppetry'
    WHEN 'Stand-up Comedy' THEN 'profile.hobbies.stand_up_comedy'
    WHEN 'Improv' THEN 'profile.hobbies.improv'
    WHEN 'Podcast Hosting' THEN 'profile.hobbies.podcast_hosting'
    WHEN 'Debate' THEN 'profile.hobbies.debate'
    WHEN 'Board Game Design' THEN 'profile.hobbies.board_game_design'
    WHEN 'Game Development' THEN 'profile.hobbies.game_development'
    WHEN 'App Development' THEN 'profile.hobbies.app_development'
    WHEN 'Drone Racing' THEN 'profile.hobbies.drone_racing'
    WHEN 'RC Cars' THEN 'profile.hobbies.rc_cars'
    WHEN 'Model Rockets' THEN 'profile.hobbies.model_rockets'
    WHEN 'Astrophotography' THEN 'profile.hobbies.astrophotography'
    WHEN 'Wildlife Photography' THEN 'profile.hobbies.wildlife_photography'
    WHEN 'Backpacking' THEN 'profile.hobbies.backpacking'
    WHEN 'Solo Travel' THEN 'profile.hobbies.solo_travel'
    WHEN 'Thrift Shopping' THEN 'profile.hobbies.thrift_shopping'
    WHEN 'Antiques' THEN 'profile.hobbies.antiques'
    WHEN 'Vinyl Collecting' THEN 'profile.hobbies.vinyl_collecting'
    WHEN 'Sneaker Collecting' THEN 'profile.hobbies.sneaker_collecting'
    WHEN 'Card Games' THEN 'profile.hobbies.card_games'
    WHEN 'Go' THEN 'profile.hobbies.go'
    WHEN 'Mahjong' THEN 'profile.hobbies.mahjong'
    WHEN 'Beekeeping' THEN 'profile.hobbies.beekeeping'
    WHEN 'Foraging' THEN 'profile.hobbies.foraging'
    WHEN 'Mushroom Hunting' THEN 'profile.hobbies.mushroom_hunting'
    WHEN 'Urban Exploration' THEN 'profile.hobbies.urban_exploration'
    WHEN 'Leatherworking' THEN 'profile.hobbies.leatherworking'
    WHEN 'Jewelry Making' THEN 'profile.hobbies.jewelry_making'
    WHEN 'Embroidery' THEN 'profile.hobbies.embroidery'
    WHEN 'Crochet' THEN 'profile.hobbies.crochet'
    WHEN 'Macramé' THEN 'profile.hobbies.macrame'
    WHEN 'Tie-Dye' THEN 'profile.hobbies.tie_dye'
    WHEN 'Screen Printing' THEN 'profile.hobbies.screen_printing'
    WHEN 'Printmaking' THEN 'profile.hobbies.printmaking'
    WHEN 'Mural Painting' THEN 'profile.hobbies.mural_painting'
    WHEN 'Street Art' THEN 'profile.hobbies.street_art'
    WHEN 'Digital Art' THEN 'profile.hobbies.digital_art'
    WHEN 'Pixel Art' THEN 'profile.hobbies.pixel_art'
    WHEN 'NFT Art' THEN 'profile.hobbies.nft_art'
    WHEN 'AI Art' THEN 'profile.hobbies.ai_art'
    WHEN 'Cooking Classes' THEN 'profile.hobbies.cooking_classes'
    WHEN 'Food Trucks' THEN 'profile.hobbies.food_trucks'
    WHEN 'Restaurant Hopping' THEN 'profile.hobbies.restaurant_hopping'
    WHEN 'Coffee Roasting' THEN 'profile.hobbies.coffee_roasting'
    WHEN 'Tea Blending' THEN 'profile.hobbies.tea_blending'
    WHEN 'Wine Making' THEN 'profile.hobbies.wine_making'
    WHEN 'Kombucha Making' THEN 'profile.hobbies.kombucha_making'
    WHEN 'Fermenting' THEN 'profile.hobbies.fermenting'
    WHEN 'Meal Prep' THEN 'profile.hobbies.meal_prep'
    WHEN 'Grilling' THEN 'profile.hobbies.grilling'
    WHEN 'Smoking' THEN 'profile.hobbies.smoking'
END
WHERE translation_key IS NULL;


-- Orientations
UPDATE orientations
SET translation_key = CASE name
    WHEN 'Straight' THEN 'profile.orientations.straight'
    WHEN 'Gay' THEN 'profile.orientations.gay'
    WHEN 'Lesbian' THEN 'profile.orientations.lesbian'
    WHEN 'Bisexual' THEN 'profile.orientations.bisexual'
    WHEN 'Pansexual' THEN 'profile.orientations.pansexual'
    WHEN 'Asexual' THEN 'profile.orientations.asexual'
    WHEN 'Demisexual' THEN 'profile.orientations.demisexual'
    WHEN 'Queer' THEN 'profile.orientations.queer'
    WHEN 'Questioning' THEN 'profile.orientations.questioning'
    WHEN 'Polysexual' THEN 'profile.orientations.polysexual'
    WHEN 'Omnisexual' THEN 'profile.orientations.omnisexual'
    WHEN 'Graysexual' THEN 'profile.orientations.graysexual'
    WHEN 'Grayromantic' THEN 'profile.orientations.grayromantic'
    WHEN 'Polyamorous' THEN 'profile.orientations.polyamorous'
    WHEN 'Heteroflexible' THEN 'profile.orientations.heteroflexible'
    WHEN 'Homoflexible' THEN 'profile.orientations.homoflexible'
    WHEN 'Androsexual' THEN 'profile.orientations.androsexual'
    WHEN 'Gynesexual' THEN 'profile.orientations.gynesexual'
    WHEN 'Skoliosexual' THEN 'profile.orientations.skoliosexual'
    WHEN 'Aroace' THEN 'profile.orientations.aroace'
    WHEN 'Aceflux' THEN 'profile.orientations.aceflux'
    WHEN 'Aromantic' THEN 'profile.orientations.aromantic'
    WHEN 'Demiromantic' THEN 'profile.orientations.demiromantic'
    WHEN 'Abrosexual' THEN 'profile.orientations.abrosexual'
    WHEN 'Reciprosexual' THEN 'profile.orientations.reciprosexual'
    WHEN 'Cupiosexual' THEN 'profile.orientations.cupiosexual'
    WHEN 'Fraysexual' THEN 'profile.orientations.fraysexual'
    WHEN 'Lithromantic' THEN 'profile.orientations.lithromantic'
    WHEN 'Quoiromantic' THEN 'profile.orientations.quoiromantic'
    WHEN 'Sapphic' THEN 'profile.orientations.sapphic'
    WHEN 'Achillean' THEN 'profile.orientations.achillean'
    WHEN 'Uranic' THEN 'profile.orientations.uranic'
    WHEN 'Ceterosexual' THEN 'profile.orientations.ceterosexual'
    WHEN 'Other' THEN 'profile.orientations.other'
END
WHERE translation_key IS NULL;


-- Sexes
UPDATE sexes
SET translation_key = CASE name
    WHEN 'Male' THEN 'profile.sexes.male'
    WHEN 'Female' THEN 'profile.sexes.female'
    WHEN 'Non-binary' THEN 'profile.sexes.non_binary'
    WHEN 'Transgender Male' THEN 'profile.sexes.transgender_male'
    WHEN 'Transgender Female' THEN 'profile.sexes.transgender_female'
    WHEN 'Transsexual' THEN 'profile.sexes.transsexual'
    WHEN 'Transfeminine' THEN 'profile.sexes.transfeminine'
    WHEN 'Transmasculine' THEN 'profile.sexes.transmasculine'
    WHEN 'Third Gender' THEN 'profile.sexes.third_gender'
    WHEN 'Androgyne' THEN 'profile.sexes.androgyne'
    WHEN 'Neutrois' THEN 'profile.sexes.neutrois'
    WHEN 'Demiboy' THEN 'profile.sexes.demiboy'
    WHEN 'Demigirl' THEN 'profile.sexes.demigirl'
    WHEN 'Genderqueer' THEN 'profile.sexes.genderqueer'
    WHEN 'Genderfluid' THEN 'profile.sexes.genderfluid'
    WHEN 'Agender' THEN 'profile.sexes.agender'
    WHEN 'Bigender' THEN 'profile.sexes.bigender'
    WHEN 'Pangender' THEN 'profile.sexes.pangender'
    WHEN 'Maverique' THEN 'profile.sexes.maverique'
    WHEN 'Xenogender' THEN 'profile.sexes.xenogender'
    WHEN 'Two-Spirit' THEN 'profile.sexes.two_spirit'
    WHEN 'Intersex' THEN 'profile.sexes.intersex'
    WHEN 'Gender Non-conforming' THEN 'profile.sexes.gender_non_conforming'
    WHEN 'Questioning' THEN 'profile.sexes.questioning'
    WHEN 'Other' THEN 'profile.sexes.other'
END
WHERE translation_key IS NULL;


-- Countries
UPDATE locations
SET translation_key = CASE name
    WHEN 'USA' THEN 'profile.locations.usa'
    WHEN 'UK' THEN 'profile.locations.uk'
    WHEN 'France' THEN 'profile.locations.france'
    WHEN 'Japan' THEN 'profile.locations.japan'
    WHEN 'Australia' THEN 'profile.locations.australia'
    WHEN 'Germany' THEN 'profile.locations.germany'
    WHEN 'Canada' THEN 'profile.locations.canada'
    WHEN 'Georgia' THEN 'profile.locations.georgia'
    WHEN 'Turkey' THEN 'profile.locations.turkey'
    WHEN 'Italy' THEN 'profile.locations.italy'
    WHEN 'Spain' THEN 'profile.locations.spain'
    WHEN 'Brazil' THEN 'profile.locations.brazil'
    WHEN 'India' THEN 'profile.locations.india'
    WHEN 'South Korea' THEN 'profile.locations.south_korea'
    WHEN 'Israel' THEN 'profile.locations.israel'
    WHEN 'Switzerland' THEN 'profile.locations.switzerland'
    WHEN 'Netherlands' THEN 'profile.locations.netherlands'
    WHEN 'Sweden' THEN 'profile.locations.sweden'
    WHEN 'Norway' THEN 'profile.locations.norway'
    WHEN 'Denmark' THEN 'profile.locations.denmark'
    WHEN 'Finland' THEN 'profile.locations.finland'
    WHEN 'Poland' THEN 'profile.locations.poland'
    WHEN 'Czech Republic' THEN 'profile.locations.czech_republic'
    WHEN 'Austria' THEN 'profile.locations.austria'
    WHEN 'Belgium' THEN 'profile.locations.belgium'
    WHEN 'Portugal' THEN 'profile.locations.portugal'
    WHEN 'Greece' THEN 'profile.locations.greece'
    WHEN 'Ireland' THEN 'profile.locations.ireland'
    WHEN 'New Zealand' THEN 'profile.locations.new_zealand'
    WHEN 'Mexico' THEN 'profile.locations.mexico'
    WHEN 'Thailand' THEN 'profile.locations.thailand'
    WHEN 'China' THEN 'profile.locations.china'
    WHEN 'Argentina' THEN 'profile.locations.argentina'
    WHEN 'South Africa' THEN 'profile.locations.south_africa'
    WHEN 'Nigeria' THEN 'profile.locations.nigeria'
    WHEN 'Egypt' THEN 'profile.locations.egypt'
    WHEN 'Kenya' THEN 'profile.locations.kenya'
    WHEN 'Morocco' THEN 'profile.locations.morocco'
    WHEN 'Armenia' THEN 'profile.locations.armenia'
    WHEN 'Azerbaijan' THEN 'profile.locations.azerbaijan'
    WHEN 'Ukraine' THEN 'profile.locations.ukraine'
    WHEN 'Romania' THEN 'profile.locations.romania'
    WHEN 'Bulgaria' THEN 'profile.locations.bulgaria'
    WHEN 'Serbia' THEN 'profile.locations.serbia'
    WHEN 'Croatia' THEN 'profile.locations.croatia'
    WHEN 'Hungary' THEN 'profile.locations.hungary'
    WHEN 'Estonia' THEN 'profile.locations.estonia'
    WHEN 'Latvia' THEN 'profile.locations.latvia'
    WHEN 'Lithuania' THEN 'profile.locations.lithuania'
    WHEN 'Cyprus' THEN 'profile.locations.cyprus'
    WHEN 'Malta' THEN 'profile.locations.malta'
    WHEN 'Luxembourg' THEN 'profile.locations.luxembourg'
    WHEN 'Iceland' THEN 'profile.locations.iceland'
    WHEN 'Singapore' THEN 'profile.locations.singapore'
    WHEN 'Hong Kong' THEN 'profile.locations.hong_kong'
    WHEN 'Taiwan' THEN 'profile.locations.taiwan'
    WHEN 'Philippines' THEN 'profile.locations.philippines'
    WHEN 'Indonesia' THEN 'profile.locations.indonesia'
    WHEN 'Malaysia' THEN 'profile.locations.malaysia'
    WHEN 'Vietnam' THEN 'profile.locations.vietnam'
    WHEN 'Colombia' THEN 'profile.locations.colombia'
    WHEN 'Chile' THEN 'profile.locations.chile'
    WHEN 'Peru' THEN 'profile.locations.peru'
    WHEN 'Ecuador' THEN 'profile.locations.ecuador'
    WHEN 'Uruguay' THEN 'profile.locations.uruguay'
    WHEN 'Costa Rica' THEN 'profile.locations.costa_rica'
    WHEN 'Panama' THEN 'profile.locations.panama'
    WHEN 'Cuba' THEN 'profile.locations.cuba'
    WHEN 'Dominican Republic' THEN 'profile.locations.dominican_republic'
    WHEN 'Jamaica' THEN 'profile.locations.jamaica'
    WHEN 'Puerto Rico' THEN 'profile.locations.puerto_rico'
    WHEN 'Trinidad and Tobago' THEN 'profile.locations.trinidad_and_tobago'
    WHEN 'Qatar' THEN 'profile.locations.qatar'
    WHEN 'UAE' THEN 'profile.locations.uae'
    WHEN 'Saudi Arabia' THEN 'profile.locations.saudi_arabia'
    WHEN 'Lebanon' THEN 'profile.locations.lebanon'
    WHEN 'Jordan' THEN 'profile.locations.jordan'
    WHEN 'Iraq' THEN 'profile.locations.iraq'
    WHEN 'Iran' THEN 'profile.locations.iran'
    WHEN 'Pakistan' THEN 'profile.locations.pakistan'
    WHEN 'Bangladesh' THEN 'profile.locations.bangladesh'
    WHEN 'Sri Lanka' THEN 'profile.locations.sri_lanka'
    WHEN 'Nepal' THEN 'profile.locations.nepal'
    WHEN 'Cambodia' THEN 'profile.locations.cambodia'
    WHEN 'Myanmar' THEN 'profile.locations.myanmar'
    WHEN 'Mongolia' THEN 'profile.locations.mongolia'
    WHEN 'Kazakhstan' THEN 'profile.locations.kazakhstan'
    WHEN 'Uzbekistan' THEN 'profile.locations.uzbekistan'
    WHEN 'Russia' THEN 'profile.locations.russia'
    WHEN 'Belarus' THEN 'profile.locations.belarus'
    WHEN 'Moldova' THEN 'profile.locations.moldova'
    WHEN 'North Macedonia' THEN 'profile.locations.north_macedonia'
    WHEN 'Albania' THEN 'profile.locations.albania'
    WHEN 'Montenegro' THEN 'profile.locations.montenegro'
    WHEN 'Bosnia and Herzegovina' THEN 'profile.locations.bosnia_and_herzegovina'
    WHEN 'Slovenia' THEN 'profile.locations.slovenia'
    WHEN 'Slovakia' THEN 'profile.locations.slovakia'
END
WHERE type = 'country'
  AND translation_key IS NULL;


-- Cities
UPDATE locations
SET translation_key = CASE name
    WHEN 'New York' THEN 'profile.locations.new_york'
    WHEN 'Los Angeles' THEN 'profile.locations.los_angeles'
    WHEN 'London' THEN 'profile.locations.london'
    WHEN 'Paris' THEN 'profile.locations.paris'
    WHEN 'Tokyo' THEN 'profile.locations.tokyo'
    WHEN 'Sydney' THEN 'profile.locations.sydney'
    WHEN 'Berlin' THEN 'profile.locations.berlin'
    WHEN 'Toronto' THEN 'profile.locations.toronto'
    WHEN 'Tbilisi' THEN 'profile.locations.tbilisi'
    WHEN 'Batumi' THEN 'profile.locations.batumi'
    WHEN 'Istanbul' THEN 'profile.locations.istanbul'
    WHEN 'Ankara' THEN 'profile.locations.ankara'
    WHEN 'Rome' THEN 'profile.locations.rome'
    WHEN 'Milan' THEN 'profile.locations.milan'
    WHEN 'Barcelona' THEN 'profile.locations.barcelona'
    WHEN 'Madrid' THEN 'profile.locations.madrid'
    WHEN 'Amsterdam' THEN 'profile.locations.amsterdam'
    WHEN 'Vienna' THEN 'profile.locations.vienna'
    WHEN 'Prague' THEN 'profile.locations.prague'
    WHEN 'Budapest' THEN 'profile.locations.budapest'
    WHEN 'Warsaw' THEN 'profile.locations.warsaw'
    WHEN 'Krakow' THEN 'profile.locations.krakow'
    WHEN 'Munich' THEN 'profile.locations.munich'
    WHEN 'Hamburg' THEN 'profile.locations.hamburg'
    WHEN 'Marseille' THEN 'profile.locations.marseille'
    WHEN 'Lyon' THEN 'profile.locations.lyon'
    WHEN 'Brussels' THEN 'profile.locations.brussels'
    WHEN 'Zurich' THEN 'profile.locations.zurich'
    WHEN 'Geneva' THEN 'profile.locations.geneva'
    WHEN 'Stockholm' THEN 'profile.locations.stockholm'
    WHEN 'Copenhagen' THEN 'profile.locations.copenhagen'
    WHEN 'Oslo' THEN 'profile.locations.oslo'
    WHEN 'Helsinki' THEN 'profile.locations.helsinki'
    WHEN 'Dublin' THEN 'profile.locations.dublin'
    WHEN 'Edinburgh' THEN 'profile.locations.edinburgh'
    WHEN 'Lisbon' THEN 'profile.locations.lisbon'
    WHEN 'Porto' THEN 'profile.locations.porto'
    WHEN 'Athens' THEN 'profile.locations.athens'
    WHEN 'Thessaloniki' THEN 'profile.locations.thessaloniki'
    WHEN 'Dubai' THEN 'profile.locations.dubai'
    WHEN 'Abu Dhabi' THEN 'profile.locations.abu_dhabi'
    WHEN 'Doha' THEN 'profile.locations.doha'
    WHEN 'Singapore' THEN 'profile.locations.singapore'
    WHEN 'Hong Kong' THEN 'profile.locations.hong_kong'
    WHEN 'Seoul' THEN 'profile.locations.seoul'
    WHEN 'Bangkok' THEN 'profile.locations.bangkok'
    WHEN 'Bali' THEN 'profile.locations.bali'
    WHEN 'Mumbai' THEN 'profile.locations.mumbai'
    WHEN 'Delhi' THEN 'profile.locations.delhi'
    WHEN 'Bangalore' THEN 'profile.locations.bangalore'
    WHEN 'Beijing' THEN 'profile.locations.beijing'
    WHEN 'Shanghai' THEN 'profile.locations.shanghai'
    WHEN 'Taipei' THEN 'profile.locations.taipei'
    WHEN 'Melbourne' THEN 'profile.locations.melbourne'
    WHEN 'Brisbane' THEN 'profile.locations.brisbane'
    WHEN 'Perth' THEN 'profile.locations.perth'
    WHEN 'San Francisco' THEN 'profile.locations.san_francisco'
    WHEN 'Miami' THEN 'profile.locations.miami'
    WHEN 'Chicago' THEN 'profile.locations.chicago'
    WHEN 'Las Vegas' THEN 'profile.locations.las_vegas'
    WHEN 'Seattle' THEN 'profile.locations.seattle'
    WHEN 'Boston' THEN 'profile.locations.boston'
    WHEN 'Austin' THEN 'profile.locations.austin'
    WHEN 'Denver' THEN 'profile.locations.denver'
    WHEN 'Portland' THEN 'profile.locations.portland'
    WHEN 'Nashville' THEN 'profile.locations.nashville'
    WHEN 'Washington DC' THEN 'profile.locations.washington_dc'
    WHEN 'Atlanta' THEN 'profile.locations.atlanta'
    WHEN 'Dallas' THEN 'profile.locations.dallas'
    WHEN 'Houston' THEN 'profile.locations.houston'
    WHEN 'Phoenix' THEN 'profile.locations.phoenix'
    WHEN 'San Diego' THEN 'profile.locations.san_diego'
    WHEN 'Philadelphia' THEN 'profile.locations.philadelphia'
    WHEN 'Vancouver' THEN 'profile.locations.vancouver'
    WHEN 'Montreal' THEN 'profile.locations.montreal'
    WHEN 'Calgary' THEN 'profile.locations.calgary'
    WHEN 'Ottawa' THEN 'profile.locations.ottawa'
    WHEN 'Mexico City' THEN 'profile.locations.mexico_city'
    WHEN 'Cancun' THEN 'profile.locations.cancun'
    WHEN 'Buenos Aires' THEN 'profile.locations.buenos_aires'
    WHEN 'Santiago' THEN 'profile.locations.santiago'
    WHEN 'Lima' THEN 'profile.locations.lima'
    WHEN 'Bogota' THEN 'profile.locations.bogota'
    WHEN 'Sao Paulo' THEN 'profile.locations.sao_paulo'
    WHEN 'Rio de Janeiro' THEN 'profile.locations.rio_de_janeiro'
    WHEN 'Cape Town' THEN 'profile.locations.cape_town'
    WHEN 'Johannesburg' THEN 'profile.locations.johannesburg'
    WHEN 'Nairobi' THEN 'profile.locations.nairobi'
    WHEN 'Cairo' THEN 'profile.locations.cairo'
    WHEN 'Marrakech' THEN 'profile.locations.marrakech'
    WHEN 'Tel Aviv' THEN 'profile.locations.tel_aviv'
    WHEN 'Jerusalem' THEN 'profile.locations.jerusalem'
    WHEN 'Beirut' THEN 'profile.locations.beirut'
    WHEN 'Yerevan' THEN 'profile.locations.yerevan'
    WHEN 'Baku' THEN 'profile.locations.baku'
    WHEN 'Kutaisi' THEN 'profile.locations.kutaisi'
    WHEN 'Sukhumi' THEN 'profile.locations.sukhumi'
    WHEN 'Kyiv' THEN 'profile.locations.kyiv'
    WHEN 'Lviv' THEN 'profile.locations.lviv'
    WHEN 'Bucharest' THEN 'profile.locations.bucharest'
    WHEN 'Cluj-Napoca' THEN 'profile.locations.cluj_napoca'
    WHEN 'Sofia' THEN 'profile.locations.sofia'
    WHEN 'Belgrade' THEN 'profile.locations.belgrade'
    WHEN 'Zagreb' THEN 'profile.locations.zagreb'
    WHEN 'Split' THEN 'profile.locations.split'
    WHEN 'Ljubljana' THEN 'profile.locations.ljubljana'
    WHEN 'Bratislava' THEN 'profile.locations.bratislava'
    WHEN 'Tallinn' THEN 'profile.locations.tallinn'
    WHEN 'Riga' THEN 'profile.locations.riga'
    WHEN 'Vilnius' THEN 'profile.locations.vilnius'
    WHEN 'Nicosia' THEN 'profile.locations.nicosia'
    WHEN 'Valletta' THEN 'profile.locations.valletta'
    WHEN 'Luxembourg City' THEN 'profile.locations.luxembourg_city'
    WHEN 'Reykjavik' THEN 'profile.locations.reykjavik'
    WHEN 'Tbilisi' THEN 'profile.locations.tbilisi'
END
WHERE type = 'city'
  AND translation_key IS NULL;

