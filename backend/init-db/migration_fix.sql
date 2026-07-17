-- ===============================================
-- Migration: Fix settings FK and populate translation keys
-- Run this against an EXISTING database to fix issues
-- ===============================================

-- 1. Fix settings table FK constraint (syno_users -> profiles)
-- First, drop the old FK if it exists
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'fk_user_settings' 
        AND conrelid = 'settings'::regclass
    ) THEN
        ALTER TABLE settings DROP CONSTRAINT fk_user_settings;
    END IF;
END $$;

-- Add the correct FK to profiles(id)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'fk_user_settings_profiles' 
        AND conrelid = 'settings'::regclass
    ) THEN
        ALTER TABLE settings ADD CONSTRAINT fk_user_settings_profiles 
            FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;
    END IF;
END $$;

-- 2. Ensure translation_key columns exist on all lookup tables
ALTER TABLE locations ADD COLUMN IF NOT EXISTS translation_key VARCHAR(150);
ALTER TABLE educations ADD COLUMN IF NOT EXISTS translation_key VARCHAR(150);
ALTER TABLE professions ADD COLUMN IF NOT EXISTS translation_key VARCHAR(150);
ALTER TABLE hobbies ADD COLUMN IF NOT EXISTS translation_key VARCHAR(150);
ALTER TABLE orientations ADD COLUMN IF NOT EXISTS translation_key VARCHAR(150);
ALTER TABLE sexes ADD COLUMN IF NOT EXISTS translation_key VARCHAR(150);

-- 3. Populate translation keys (only where NULL)

-- Educations
UPDATE educations SET translation_key = CASE name
    WHEN 'High School' THEN 'profile.educations.high_school'
    WHEN 'Associate' THEN 'profile.educations.associate'
    WHEN 'Bachelor' THEN 'profile.educations.bachelor'
    WHEN 'Master' THEN 'profile.educations.master'
    WHEN 'PhD' THEN 'profile.educations.phd'
    WHEN 'Trade School' THEN 'profile.educations.trade_school'
END WHERE translation_key IS NULL;

-- Professions
UPDATE professions SET translation_key = CASE name
    WHEN 'Engineer' THEN 'profile.professions.engineer'
    WHEN 'Doctor' THEN 'profile.professions.doctor'
    WHEN 'Artist' THEN 'profile.professions.artist'
    WHEN 'Teacher' THEN 'profile.professions.teacher'
    WHEN 'Developer' THEN 'profile.professions.developer'
    WHEN 'Manager' THEN 'profile.professions.manager'
    WHEN 'Student' THEN 'profile.professions.student'
END WHERE translation_key IS NULL;

-- Hobbies
UPDATE hobbies SET translation_key = CASE name
    WHEN 'Yoga' THEN 'profile.hobbies.yoga'
    WHEN 'Meditation' THEN 'profile.hobbies.meditation'
    WHEN 'Astrology' THEN 'profile.hobbies.astrology'
    WHEN 'Hiking' THEN 'profile.hobbies.hiking'
    WHEN 'Reading' THEN 'profile.hobbies.reading'
    WHEN 'Music' THEN 'profile.hobbies.music'
END WHERE translation_key IS NULL;

-- Orientations
UPDATE orientations SET translation_key = CASE name
    WHEN 'Straight' THEN 'profile.orientations.straight'
    WHEN 'Gay' THEN 'profile.orientations.gay'
    WHEN 'Bisexual' THEN 'profile.orientations.bisexual'
    WHEN 'Pansexual' THEN 'profile.orientations.pansexual'
    WHEN 'Asexual' THEN 'profile.orientations.asexual'
    WHEN 'Other' THEN 'profile.orientations.other'
END WHERE translation_key IS NULL;

-- Sexes
UPDATE sexes SET translation_key = CASE name
    WHEN 'Male' THEN 'profile.sexes.male'
    WHEN 'Female' THEN 'profile.sexes.female'
    WHEN 'Non-binary' THEN 'profile.sexes.non_binary'
    WHEN 'Other' THEN 'profile.sexes.other'
END WHERE translation_key IS NULL;

-- Countries
UPDATE locations SET translation_key = CASE name
    WHEN 'USA' THEN 'profile.locations.usa'
    WHEN 'UK' THEN 'profile.locations.uk'
    WHEN 'France' THEN 'profile.locations.france'
    WHEN 'Japan' THEN 'profile.locations.japan'
    WHEN 'Australia' THEN 'profile.locations.australia'
    WHEN 'Germany' THEN 'profile.locations.germany'
    WHEN 'Canada' THEN 'profile.locations.canada'
END WHERE type = 'country' AND translation_key IS NULL;

-- Cities
UPDATE locations SET translation_key = CASE name
    WHEN 'New York' THEN 'profile.locations.new_york'
    WHEN 'Los Angeles' THEN 'profile.locations.los_angeles'
    WHEN 'London' THEN 'profile.locations.london'
    WHEN 'Paris' THEN 'profile.locations.paris'
    WHEN 'Tokyo' THEN 'profile.locations.tokyo'
    WHEN 'Sydney' THEN 'profile.locations.sydney'
    WHEN 'Berlin' THEN 'profile.locations.berlin'
    WHEN 'Toronto' THEN 'profile.locations.toronto'
END WHERE type = 'city' AND translation_key IS NULL;
