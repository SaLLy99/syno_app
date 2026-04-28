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
    name VARCHAR(20) UNIQUE NOT NULL
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

-- 9️⃣ Insert sample data into locations (countries)
INSERT INTO locations (name, type) VALUES
    ('USA', 'country'),
    ('UK', 'country'),
    ('France', 'country'),
    ('Japan', 'country'),
    ('Australia', 'country'),
    ('Germany', 'country'),
    ('Canada', 'country')
ON CONFLICT (name, parent_id) DO NOTHING;

-- 🔟 Insert sample data into locations (cities)
INSERT INTO locations (name, type, parent_id) VALUES
    ('New York', 'city', (SELECT id FROM locations WHERE name = 'USA' AND type = 'country')),
    ('Los Angeles', 'city', (SELECT id FROM locations WHERE name = 'USA' AND type = 'country')),
    ('London', 'city', (SELECT id FROM locations WHERE name = 'UK' AND type = 'country')),
    ('Paris', 'city', (SELECT id FROM locations WHERE name = 'France' AND type = 'country')),
    ('Tokyo', 'city', (SELECT id FROM locations WHERE name = 'Japan' AND type = 'country')),
    ('Sydney', 'city', (SELECT id FROM locations WHERE name = 'Australia' AND type = 'country')),
    ('Berlin', 'city', (SELECT id FROM locations WHERE name = 'Germany' AND type = 'country')),
    ('Toronto', 'city', (SELECT id FROM locations WHERE name = 'Canada' AND type = 'country'))
ON CONFLICT (name, parent_id) DO NOTHING;

-- 1️⃣0️⃣.5 Insert sample data into educations
INSERT INTO educations (name) VALUES
    ('High School'), ('Bachelor'), ('Master'), ('PhD'), ('Associate'), ('Trade School')
ON CONFLICT (name) DO NOTHING;

-- 1️⃣0️⃣.6 Insert sample data into professions
INSERT INTO professions (name) VALUES
    ('Engineer'), ('Doctor'), ('Artist'), ('Teacher'), ('Developer'), ('Manager'), ('Student')
ON CONFLICT (name) DO NOTHING;

-- 1️⃣1️⃣ Insert sample data into hobbies
INSERT INTO hobbies (name) VALUES
    ('Yoga'),
    ('Meditation'),
    ('Astrology'),
    ('Hiking'),
    ('Reading'),
    ('Music')
ON CONFLICT (name) DO NOTHING;

-- 1️⃣2️⃣ Insert sample data into orientations
INSERT INTO orientations (name) VALUES
    ('Straight'),
    ('Gay'),
    ('Bisexual'),
    ('Pansexual'),
    ('Asexual'),
    ('Other');

-- 1️⃣3️⃣ Insert sample data into sexes
INSERT INTO sexes (name) VALUES
    ('Male'),
    ('Female'),
    ('Non-binary'),
    ('Other');

-- 1️⃣3️⃣.5 Insert sample data into core_values
INSERT INTO core_values (key, translation_key) VALUES
    ('spirituality', 'profile.core_values.spirituality'),
    ('kindness', 'profile.core_values.kindness'),
    ('creativity', 'profile.core_values.creativity'),
    ('authenticity', 'profile.core_values.authenticity'),
    ('growth', 'profile.core_values.growth'),
    ('adventure', 'profile.core_values.adventure')
ON CONFLICT (key) DO NOTHING;

-- 1️⃣3️⃣.6 Insert sample data into intentions
INSERT INTO intentions (key, translation_key) VALUES
    ('soulmate', 'register.options.intentions.soulmate'),
    ('casual_relationship', 'register.options.intentions.casual_relationship'),
    ('exploring', 'register.options.intentions.exploring'),
    ('friendship', 'register.options.intentions.friendship')
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
CREATE TABLE settings (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL UNIQUE,
    theme_id VARCHAR(50),
    background_color VARCHAR(50),
    accent_color VARCHAR(50),
    layout VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    -- Adjust 'users(id)' to match your actual users table name (e.g., auth_user, users)
    CONSTRAINT fk_user_settings FOREIGN KEY (user_id) REFERENCES syno_users(id) ON DELETE CASCADE
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