from datetime import timedelta
from functools import lru_cache
import json
from twilio.rest import Client
import os
import functools
import secrets
import logging
import re
import smtplib
from email.mime.text import MIMEText
from typing import List, Optional
from pydantic import BaseModel, EmailStr, Field
from datetime import date, datetime
from passlib.context import CryptContext
from fastapi import FastAPI, Depends, Form, HTTPException, Response, status, File, UploadFile, BackgroundTasks
from sqlalchemy.orm import Session, joinedload, load_only
from sqlalchemy import text

from . import models, schemas, crud
from .database import engine, Base, get_db
from .auth import create_access_token, get_current_active_user
from .config import settings

# Create database tables
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="SYNO Backend",
    description="API for the SYNO application.",
    version="1.0.0",
)

from fastapi import WebSocket, WebSocketDisconnect, Query
from .astrology.router import router as astrology_router
from .websocket_manager import websocket_endpoint, manager
from jose import JWTError, jwt
from .config import settings as app_settings

app.include_router(astrology_router)

@app.websocket("/ws/{user_id}")
async def websocket_handler(websocket: WebSocket, user_id: int, token: str = Query(...)):
    try:
        payload = jwt.decode(token, app_settings.secret_key, algorithms=[app_settings.algorithm])
        email: str = payload.get("sub")
        if not email:
            await websocket.close(code=4001, reason="Invalid token")
            return
        from . import crud as _crud
        from .database import SessionLocal
        db = SessionLocal()
        try:
            db_user = _crud.get_user_by_email(db, email=email)
            if not db_user or db_user.id != user_id:
                await websocket.close(code=4003, reason="Unauthorized")
                return
        finally:
            db.close()
    except JWTError:
        await websocket.close(code=4001, reason="Invalid token")
        return
    await websocket_endpoint(websocket, user_id)

@app.get("/api/online-status")
def get_online_status(
    user_ids: Optional[List[int]] = None,
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    online = manager.get_online_users()
    if user_ids:
        return {"online_users": [uid for uid in user_ids if uid in online]}
    return {"online_users": list(online)}


@app.get("/api/analytics/dashboard", summary="Get analytics dashboard data")
def get_analytics_dashboard(
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    profile = crud.get_profile_by_user_id(db, user_id=current_user.id)
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")

    total_likes_given = db.query(models.Match).filter(
        models.Match.user_id == current_user.id
    ).count()

    total_likes_received = db.query(models.Match).filter(
        models.Match.matched_user_id == current_user.id,
        models.Match.status == "accepted"
    ).count()

    mutual_matches = db.query(models.Match).filter(
        models.Match.user_id == current_user.id,
        models.Match.status == "accepted"
    ).count()

    reverse_matches = db.query(models.Match).filter(
        models.Match.matched_user_id == current_user.id,
        models.Match.status == "accepted"
    ).count()
    mutual_count = min(mutual_matches, reverse_matches)

    match_rate = 0.0
    if total_likes_given > 0:
        match_rate = (mutual_count / total_likes_given) * 100

    response_rate = 0.0
    if total_likes_received > 0:
        reverse_given = db.query(models.Match).filter(
            models.Match.user_id == current_user.id,
            models.Match.matched_user_id.in_(
                db.query(models.Match.user_id).filter(
                    models.Match.matched_user_id == current_user.id,
                    models.Match.status == "accepted"
                )
            )
        ).count()
        response_rate = (reverse_given / total_likes_received) * 100

    total_messages = db.query(models.Message).join(
        models.Match
    ).filter(
        (models.Match.user_id == current_user.id) | (models.Match.matched_user_id == current_user.id)
    ).count()

    unread_messages = db.query(models.Message).join(
        models.Match
    ).filter(
        (models.Match.user_id == current_user.id) | (models.Match.matched_user_id == current_user.id),
        models.Message.sender_id != current_user.id,
        models.Message.is_read == False
    ).count()

    tips = _generate_profile_tips(profile, total_likes_given, total_likes_received, mutual_count)

    return {
        "stats": {
            "likes_given": total_likes_given,
            "likes_received": total_likes_received,
            "mutual_matches": mutual_count,
            "match_rate": round(match_rate, 1),
            "response_rate": round(response_rate, 1),
            "total_messages": total_messages,
            "unread_messages": unread_messages,
        },
        "by_mode": {
            "dating": {
                "likes_given": db.query(models.Match).filter(models.Match.user_id == current_user.id, models.Match.mode == "dating").count(),
                "likes_received": db.query(models.Match).filter(models.Match.matched_user_id == current_user.id, models.Match.status == "accepted", models.Match.mode == "dating").count(),
                "matches": db.query(models.Match).filter(models.Match.user_id == current_user.id, models.Match.status == "accepted", models.Match.mode == "dating").count(),
            },
            "bff": {
                "likes_given": db.query(models.Match).filter(models.Match.user_id == current_user.id, models.Match.mode == "bff").count(),
                "likes_received": db.query(models.Match).filter(models.Match.matched_user_id == current_user.id, models.Match.status == "accepted", models.Match.mode == "bff").count(),
                "matches": db.query(models.Match).filter(models.Match.user_id == current_user.id, models.Match.status == "accepted", models.Match.mode == "bff").count(),
            },
        },
        "profile_strength": _calculate_profile_strength(profile),
        "tips": tips,
    }


def _calculate_profile_strength(profile: models.Profile) -> dict:
    score = 0
    items = []

    if profile.photos:
        photo_score = min(len(profile.photos) * 15, 30)
        score += photo_score
        if len(profile.photos) >= 3:
            items.append({"label": "Multiple photos", "score": 15, "max": 15, "status": "good"})
        else:
            items.append({"label": "Add more photos", "score": photo_score, "max": 15, "status": "needs_work"})
    else:
        items.append({"label": "Add photos", "score": 0, "max": 15, "status": "critical"})

    if profile.bio and len(profile.bio) > 20:
        score += 20
        items.append({"label": "Bio completed", "score": 20, "max": 20, "status": "good"})
    elif profile.bio:
        score += 10
        items.append({"label": "Expand your bio", "score": 10, "max": 20, "status": "needs_work"})
    else:
        items.append({"label": "Add a bio", "score": 0, "max": 20, "status": "critical"})

    if profile.hobbies:
        hobby_score = min(len(profile.hobbies) * 5, 15)
        score += hobby_score
        items.append({"label": "Interests listed", "score": hobby_score, "max": 15, "status": "good"})
    else:
        items.append({"label": "Add interests", "score": 0, "max": 15, "status": "critical"})

    if profile.core_values:
        score += 15
        items.append({"label": "Core values set", "score": 15, "max": 15, "status": "good"})
    else:
        items.append({"label": "Set core values", "score": 0, "max": 15, "status": "critical"})

    if profile.intentions:
        score += 10
        items.append({"label": "Intentions clear", "score": 10, "max": 10, "status": "good"})
    else:
        items.append({"label": "Set intentions", "score": 0, "max": 10, "status": "critical"})

    if profile.birth_date:
        score += 5
    if profile.birth_time:
        score += 5
    if profile.height:
        score += 5

    return {"score": min(score, 100), "items": items}


def _generate_profile_tips(profile, likes_given, likes_received, mutual_matches):
    tips = []

    if not profile.photos or len(profile.photos) < 3:
        tips.append({
            "icon": "photo_camera",
            "title": "Add more photos",
            "description": "Profiles with 3+ photos get 5x more likes",
            "priority": "high"
        })

    if not profile.bio or len(profile.bio) < 30:
        tips.append({
            "icon": "edit_note",
            "title": "Write a compelling bio",
            "description": "Tell people what makes you unique",
            "priority": "high"
        })

    if not profile.hobbies or len(profile.hobbies) < 3:
        tips.append({
            "icon": "interests",
            "title": "Add more interests",
            "description": "Shared interests help find compatible matches",
            "priority": "medium"
        })

    if likes_received > 0 and mutual_matches == 0:
        tips.append({
            "icon": "favorite",
            "title": "Be more active",
            "description": "You have likes waiting! Try liking back more often",
            "priority": "high"
        })

    if likes_given > 10 and mutual_matches == 0:
        tips.append({
            "icon": "tune",
            "title": "Adjust your preferences",
            "description": "Your filters might be too narrow. Try expanding your criteria",
            "priority": "medium"
        })

    if profile.birth_time is None:
        tips.append({
            "icon": "schedule",
            "title": "Add birth time",
            "description": "Accurate birth time improves astrological compatibility scores",
            "priority": "low"
        })

    if not tips:
        tips.append({
            "icon": "celebration",
            "title": "Your profile is great!",
            "description": "Keep being active and engaging with matches",
            "priority": "low"
        })

    return tips


@app.post("/api/analytics/event", summary="Track an analytics event")
def track_event(
    event_type: str,
    event_metadata: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    event = models.AnalyticsEvent(
        user_id=current_user.id,
        event_type=event_type,
        event_metadata=event_metadata,
    )
    db.add(event)
    db.commit()

    # Update behavior profile on key events
    key_events = {"profile_view", "profile_like", "profile_pass", "message_sent", "session_start"}
    if event_type in key_events:
        try:
            from .behavior_updater import update_behavior_profile
            update_behavior_profile(db, current_user.id)
        except Exception as e:
            logging.debug(f"Behavior profile update failed: {e}")

    return {"status": "ok"}

# Run startup migrations to fix schema issues on existing databases
@app.on_event("startup")
def run_startup_migrations():
    """Fix settings FK and populate translation_key values on existing databases."""
    from .database import SessionLocal
    db = SessionLocal()
    try:
        # Fix settings table FK constraint (syno_users -> profiles)
        db.execute(text("""
            DO $$ BEGIN
                IF EXISTS (
                    SELECT 1 FROM pg_constraint 
                    WHERE conname = 'fk_user_settings' 
                    AND conrelid = 'settings'::regclass
                ) THEN
                    ALTER TABLE settings DROP CONSTRAINT fk_user_settings;
                END IF;
            END $$;
        """))
        db.execute(text("""
            DELETE FROM settings WHERE user_id NOT IN (SELECT id FROM profiles);
        """))
        db.execute(text("""
            DO $$ BEGIN
                IF NOT EXISTS (
                    SELECT 1 FROM pg_constraint 
                    WHERE conname = 'fk_user_settings_profiles' 
                    AND conrelid = 'settings'::regclass
                ) THEN
                    ALTER TABLE settings ADD CONSTRAINT fk_user_settings_profiles 
                        FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;
                END IF;
            END $$;
        """))
        # Ensure translation_key columns exist
        for table in ['locations', 'educations', 'professions', 'hobbies', 'orientations', 'sexes']:
            db.execute(text(f"ALTER TABLE {table} ADD COLUMN IF NOT EXISTS translation_key VARCHAR(150);"))
        # Populate translation keys
        db.execute(text("""
            UPDATE educations SET translation_key = CASE name
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
            END WHERE translation_key IS NULL;
        """))
        db.execute(text("""
            UPDATE professions SET translation_key = CASE name
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
                WHEN 'Human Resources Manager' THEN 'profile.professions.hr_manager'
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
            END WHERE translation_key IS NULL;
        """))
        db.execute(text("""
            UPDATE hobbies SET translation_key = CASE name
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
            END WHERE translation_key IS NULL;
        """))
        db.execute(text("""
            UPDATE orientations SET translation_key = CASE name
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
            END WHERE translation_key IS NULL;
        """))
        db.execute(text("""
            UPDATE sexes SET translation_key = CASE name
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
            END WHERE translation_key IS NULL;
        """))
        db.execute(text("""
            UPDATE locations SET translation_key = CASE name
                WHEN 'USA' THEN 'profile.locations.usa'
                WHEN 'UK' THEN 'profile.locations.uk'
                WHEN 'France' THEN 'profile.locations.france'
                WHEN 'Japan' THEN 'profile.locations.japan'
                WHEN 'Australia' THEN 'profile.locations.australia'
                WHEN 'Germany' THEN 'profile.locations.germany'
                WHEN 'Canada' THEN 'profile.locations.canada'
            END WHERE type = 'country' AND translation_key IS NULL;
        """))
        db.execute(text("""
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
        """))
        # Create match_cache table if it doesn't exist
        db.execute(text("""
            CREATE TABLE IF NOT EXISTS match_cache (
                id SERIAL PRIMARY KEY,
                user_a_id INTEGER REFERENCES syno_users(id) ON DELETE CASCADE,
                user_b_id INTEGER REFERENCES syno_users(id) ON DELETE CASCADE,
                synastry_data TEXT NOT NULL,
                final_score INTEGER NOT NULL,
                weighted_score INTEGER,
                top_reasons TEXT,
                cosmic_insight TEXT,
                computed_at TIMESTAMP DEFAULT NOW(),
                UNIQUE(user_a_id, user_b_id)
            );
        """))
        # Create recommendations table if it doesn't exist
        db.execute(text("""
            CREATE TABLE IF NOT EXISTS recommendations (
                id SERIAL PRIMARY KEY,
                user_id INTEGER REFERENCES syno_users(id) ON DELETE CASCADE,
                recommended_user_id INTEGER REFERENCES syno_users(id) ON DELETE CASCADE,
                score INTEGER NOT NULL,
                reasons TEXT,
                cosmic_insight TEXT,
                recommendation_date DATE NOT NULL,
                mode VARCHAR(10) DEFAULT 'dating',
                created_at TIMESTAMP DEFAULT NOW()
            );
        """))
        # Create analytics_events table if it doesn't exist
        db.execute(text("""
            CREATE TABLE IF NOT EXISTS analytics_events (
                id SERIAL PRIMARY KEY,
                user_id INTEGER REFERENCES syno_users(id) ON DELETE CASCADE,
                event_type VARCHAR(50) NOT NULL,
                metadata TEXT,
                mode VARCHAR(10),
                created_at TIMESTAMP DEFAULT NOW()
            );
        """))
        # Add missing media columns to messages table
        db.execute(text("ALTER TABLE messages ADD COLUMN IF NOT EXISTS image_url VARCHAR(500);"))
        db.execute(text("ALTER TABLE messages ADD COLUMN IF NOT EXISTS video_url VARCHAR(500);"))
        db.execute(text("ALTER TABLE messages ADD COLUMN IF NOT EXISTS gif_url VARCHAR(500);"))
        db.execute(text("ALTER TABLE messages ADD COLUMN IF NOT EXISTS message_type VARCHAR(20) DEFAULT 'text';"))
        db.execute(text("ALTER TABLE messages ADD COLUMN IF NOT EXISTS is_edited BOOLEAN DEFAULT FALSE;"))
        db.execute(text("ALTER TABLE syno_users ADD COLUMN IF NOT EXISTS last_active_at TIMESTAMP DEFAULT NOW();"))
        db.execute(text("ALTER TABLE syno_users ADD COLUMN IF NOT EXISTS is_deactivated BOOLEAN DEFAULT FALSE;"))
        db.execute(text("ALTER TABLE syno_users ADD COLUMN IF NOT EXISTS deactivated_at TIMESTAMP;"))
        # Hard-delete deactivated accounts older than 30 days
        try:
            from . import crud as _crud
            _count = _crud.cleanup_expired_deactivated_accounts(db, days=30)
            if _count > 0:
                logging.info(f"Startup cleanup: permanently deleted {_count} deactivated accounts older than 30 days.")
        except Exception as e:
            logging.warning(f"Startup cleanup of expired deactivated accounts skipped: {e}")
        # Add lat/lon columns to locations table
        db.execute(text("ALTER TABLE locations ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION;"))
        db.execute(text("ALTER TABLE locations ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;"))
        db.execute(text("ALTER TABLE locations ADD COLUMN IF NOT EXISTS timezone VARCHAR(50);"))
        # --- Dual Mode (Dating + BFF) migrations ---
        db.execute(text("ALTER TABLE profiles ADD COLUMN IF NOT EXISTS active_mode VARCHAR(10) DEFAULT 'dating';"))
        db.execute(text("ALTER TABLE matches ADD COLUMN IF NOT EXISTS mode VARCHAR(10) DEFAULT 'dating';"))
        db.execute(text("ALTER TABLE recommendations ADD COLUMN IF NOT EXISTS mode VARCHAR(10) DEFAULT 'dating';"))
        db.execute(text("ALTER TABLE match_cache ADD COLUMN IF NOT EXISTS mode VARCHAR(10) DEFAULT 'dating';"))
        db.execute(text("ALTER TABLE analytics_events ADD COLUMN IF NOT EXISTS mode VARCHAR(10);"))
        db.execute(text("""
            CREATE TABLE IF NOT EXISTS user_app_modes (
                id SERIAL PRIMARY KEY,
                profile_id INTEGER REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
                mode VARCHAR(10) NOT NULL,
                min_age INT DEFAULT 18,
                max_age INT DEFAULT 50,
                max_distance INT DEFAULT 100,
                genders VARCHAR(50)[] DEFAULT '{}',
                orientations VARCHAR(50)[] DEFAULT '{}',
                weight_romance INT DEFAULT 50,
                weight_emotional INT DEFAULT 50,
                weight_communication INT DEFAULT 50,
                weight_long_term INT DEFAULT 50,
                weight_marriage INT DEFAULT 50,
                weight_friendship INT DEFAULT 50,
                weight_chemistry INT DEFAULT 50,
                weight_spiritual INT DEFAULT 50,
                photos_only BOOLEAN DEFAULT FALSE,
                complete_profiles_only BOOLEAN DEFAULT FALSE,
                hide_swiped BOOLEAN DEFAULT TRUE,
                hide_inactive BOOLEAN DEFAULT FALSE,
                created_at TIMESTAMP DEFAULT NOW(),
                updated_at TIMESTAMP DEFAULT NOW(),
                UNIQUE(profile_id, mode)
            );
        """))
        # --- Matching Signal Weight columns ---
        db.execute(text("ALTER TABLE user_preferences ADD COLUMN IF NOT EXISTS weight_natal_chart INT DEFAULT 60;"))
        db.execute(text("ALTER TABLE user_preferences ADD COLUMN IF NOT EXISTS weight_interests INT DEFAULT 10;"))
        db.execute(text("ALTER TABLE user_preferences ADD COLUMN IF NOT EXISTS weight_behavior INT DEFAULT 30;"))
        db.execute(text("ALTER TABLE user_app_modes ADD COLUMN IF NOT EXISTS weight_natal_chart INT DEFAULT 60;"))
        db.execute(text("ALTER TABLE user_app_modes ADD COLUMN IF NOT EXISTS weight_interests INT DEFAULT 10;"))
        db.execute(text("ALTER TABLE user_app_modes ADD COLUMN IF NOT EXISTS weight_behavior INT DEFAULT 30;"))
        # --- User Behavior Profiles table ---
        db.execute(text("""
            CREATE TABLE IF NOT EXISTS user_behavior_profiles (
                id SERIAL PRIMARY KEY,
                user_id INTEGER REFERENCES syno_users(id) ON DELETE CASCADE UNIQUE NOT NULL,
                selectivity DOUBLE PRECISION DEFAULT 0.5,
                avg_profiles_per_session DOUBLE PRECISION DEFAULT 10.0,
                avg_response_time_minutes DOUBLE PRECISION DEFAULT 60.0,
                avg_message_length DOUBLE PRECISION DEFAULT 50.0,
                conversation_depth DOUBLE PRECISION DEFAULT 5.0,
                initiator_ratio DOUBLE PRECISION DEFAULT 0.5,
                sessions_per_week DOUBLE PRECISION DEFAULT 3.0,
                avg_session_minutes DOUBLE PRECISION DEFAULT 10.0,
                peak_hour INT DEFAULT 20,
                openness_behavioral DOUBLE PRECISION DEFAULT 50.0,
                conscientiousness_behavioral DOUBLE PRECISION DEFAULT 50.0,
                extraversion_behavioral DOUBLE PRECISION DEFAULT 50.0,
                agreeableness_behavioral DOUBLE PRECISION DEFAULT 50.0,
                emotional_stability_behavioral DOUBLE PRECISION DEFAULT 50.0,
                computed_at TIMESTAMP DEFAULT NOW(),
                updated_at TIMESTAMP DEFAULT NOW()
            );
        """))
        db.commit()
        # Auto-seed locations from REST Countries API if empty
        try:
            existing_count = db.execute(text("SELECT COUNT(*) FROM locations")).scalar()
            if existing_count == 0:
                import httpx
                REST_COUNTRIES_URL = "https://restcountries.com/v3.1/all?fields=name,capital,latlng,cca2"
                response = httpx.get(REST_COUNTRIES_URL, timeout=30.0)
                response.raise_for_status()
                data = response.json()
                added_countries = 0
                added_cities = 0
                for item in data:
                    name = item.get("name", {}).get("common", "")
                    capital_list = item.get("capital", [])
                    capital = capital_list[0] if capital_list else None
                    latlng = item.get("latlng", [])
                    cca2 = item.get("cca2", "")
                    if not name or not latlng:
                        continue
                    lat = latlng[0] if len(latlng) > 0 else None
                    lon = latlng[1] if len(latlng) > 1 else None
                    exists = db.execute(text("SELECT 1 FROM locations WHERE name = :name AND type = 'country'"), {"name": name}).fetchone()
                    if not exists:
                        db.execute(text("INSERT INTO locations (name, type, latitude, longitude, translation_key) VALUES (:name, 'country', :lat, :lon, :tk)"), {"name": name, "lat": lat, "lon": lon, "tk": f"profile.locations.{name.lower().replace(' ', '_')}"})
                        db.flush()
                        added_countries += 1
                        if capital:
                            db.execute(text("INSERT INTO locations (name, type, latitude, longitude, translation_key, parent_id) VALUES (:name, 'city', :lat, :lon, :tk, (SELECT id FROM locations WHERE name = :pname AND type = 'country' LIMIT 1))"), {"name": capital, "lat": lat, "lon": lon, "tk": f"profile.locations.{capital.lower().replace(' ', '_')}", "pname": name})
                            added_cities += 1
                db.commit()
                logging.info(f"Location seeding completed: {added_countries} countries, {added_cities} cities")
            else:
                from app.location_service import backfill_location_coords
                result = backfill_location_coords(db)
                logging.info(f"Location backfill: {result}")
        except Exception as e:
            logging.warning(f"Location seeding/backfill skipped: {e}")
        logging.info("Startup migrations completed successfully.")
    except Exception as e:
        db.rollback()
        logging.warning(f"Startup migration skipped: {e}")
    finally:
        db.close()

# Password hashing context
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

logger = logging.getLogger("syno.auth")

# Define TRANSLATIONS_DIR relative to the current file
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
TRANSLATIONS_DIR = os.path.join(BASE_DIR, "translations")

# Ensure the directory exists so the app doesn't crash, and log the path for debugging
if not os.path.exists(TRANSLATIONS_DIR):
    os.makedirs(TRANSLATIONS_DIR, exist_ok=True)
    logger.info(f"Created translations directory at: {TRANSLATIONS_DIR}")
else:
    logger.info(f"Translations directory identified at: {TRANSLATIONS_DIR}")

@lru_cache(maxsize=128)
def _load_translations(lang: str) -> dict:
    """Loads translation data for a given language from a JSON file."""
    filepath = os.path.join(TRANSLATIONS_DIR, f"{lang}.json")
    if not os.path.exists(filepath):
        logger.warning(f"Translation file not found: {filepath}")
        return {}
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            return json.load(f)
    except Exception as e:
        logger.error(f"Error loading translation file {filepath}: {e}")
        return {}

def send_otp_email(to_email: str, subject: str, html_content: str) -> bool:
    """Sends an OTP email to the specified recipient."""
    try:
        msg = MIMEText(html_content, "html")
        msg["Subject"] = subject
        msg["From"] = settings.smtp_user
        msg["To"] = to_email

        if settings.smtp_port == 465:
            with smtplib.SMTP_SSL(settings.smtp_server, settings.smtp_port) as server:
                server.login(settings.smtp_user, settings.smtp_password)
                server.send_message(msg)
        else:
            with smtplib.SMTP(settings.smtp_server, settings.smtp_port) as server:
                server.starttls()  # Secure the connection
                server.login(settings.smtp_user, settings.smtp_password)
                server.send_message(msg)

        logger.info(f"Email sent successfully to {to_email}")
        return True
    except Exception as e:
        logger.error(f"Failed to send email: {e}")
        return False

def send_sms_otp(phone_number: str, message: str) -> bool:
    try:
        # These values must be in your .env / settings.py
        if not settings.twilio_sid or not settings.twilio_auth_token or settings.twilio_sid == "your_sid_here":
            logger.warning(f"[DEV MODE] Twilio not configured. SMS OTP for {phone_number}: {message}")
            return False
            
        client = Client(settings.twilio_sid, settings.twilio_auth_token)
        
        client.messages.create(
            body=message,
            from_=settings.twilio_phone, # Your purchased Twilio number
            to=phone_number
        )
        
        logger.info(f"Actual SMS sent to {phone_number}")
        return True
    except Exception as e:
        logger.error(f"Failed to send SMS: {e}")
        return False

def validate_phone_number(phone: str):
    """Validates European and Georgian phone numbers."""
    # Basic sanitization
    clean_phone = re.sub(r'[^\d+]', '', phone)
    
    # European Country Codes and typical lengths (min, max)
    # +995 (GE), +49 (DE), +33 (FR), +44 (GB), etc.
    country_codes = {
        "995": (9, 9),   # Georgia
        "49": (10, 11),  # Germany
        "33": (9, 9),    # France
        "44": (10, 10),  # UK
    }
    
    for code, (min_l, max_l) in country_codes.items():
        pattern = rf"^\+?{code}\d{{{min_l},{max_l}}}$"
        if re.match(pattern, clean_phone):
            # Remove + for uniform storage if preferred, 
            # but usually keeping + is better for internationalization
            return True, clean_phone
            
    return False, None

# Define a schema for the complete registration form data

# ----------------- AUTH -----------------

def tr(key: str, lang: str = "en", **kwargs) -> str:
    """
    Helper to translate keys using the JSON files, supporting dot notation
    and string formatting. Falls back to English if the translation is missing.
    """
    # 1. Try requested language
    val = _get_value_from_json(key, lang)

    # 2. Fallback to English if not found
    if not val and lang != "en":
        val = _get_value_from_json(key, "en")

    if not val:
        return key

    if isinstance(val, str):
        try: return val.format(**kwargs).strip()
        except (KeyError, ValueError, IndexError): return val
    return str(val)

def _get_value_from_json(key: str, lang: str) -> Optional[str]:
    """Internal helper to traverse the JSON dictionary."""
    translations = _load_translations(lang)
    val = translations
    for part in key.split('.'):
        if isinstance(val, dict):
            val = val.get(part)
        else:
            return None
    return val if isinstance(val, str) else None

@app.post("/api/auth/login", response_model=schemas.Token)
def login_for_access_token(user_credentials: schemas.UserLogin, db: Session = Depends(get_db)):
    user = crud.get_user_by_email(db, email=user_credentials.email)
    if not user or not crud.verify_password(user_credentials.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    if user.is_deactivated:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="account.deactivated"
        )
    access_token_expires = timedelta(minutes=settings.access_token_expire_minutes)
    access_token = create_access_token(
        data={"sub": user.email}, expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer"}


@app.post("/api/auth/register", response_model=schemas.Token, status_code=status.HTTP_201_CREATED)
def register_user(user: schemas.UserCreate, db: Session = Depends(get_db)):
    db_user = crud.get_user_by_email(db, email=user.email)
    if db_user:
        raise HTTPException(status_code=400, detail="Email already registered")
    
    new_user = crud.create_user(db=db, user=user)

    access_token_expires = timedelta(minutes=settings.access_token_expire_minutes)
    access_token = create_access_token(
        data={"sub": new_user.email}, expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer"}


@app.post("/api/auth/check-email", status_code=status.HTTP_200_OK)
def check_email_availability(user_data: schemas.UserBase, db: Session = Depends(get_db)):
    user = crud.get_user_by_email(db, email=user_data.email)
    if user:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Email already registered"
        )
    return {"message": "Email is available"}

@app.post("/api/auth/request-otp", status_code=status.HTTP_200_OK)
async def request_otp(otp_data: schemas.OTPRequest, background_tasks: BackgroundTasks, db: Session = Depends(get_db)):
    """
    REST API endpoint to receive email submission, generate 6-digit secure OTP,
    store in PostgreSQL, and send localized email.
    """
    # Branch to phone logic if phone number is provided instead of email
    if otp_data.phone_number and not otp_data.email:
        return await request_otp_phone(
            schemas.SMSOTPRequest(phone_number=otp_data.phone_number, lang=otp_data.lang), 
            background_tasks, 
            db
        )

    # Periodic cleanup trigger (could also be a cron job)
    if secrets.randbelow(10) == 0: # 10% chance to run cleanup on request to keep table slim
        crud.cleanup_otps(db)

    if not otp_data.email:
        raise HTTPException(status_code=400, detail="Email or Phone Number is required")

    email = otp_data.email.lower()
    # 0. Basic Rate Limiting: Prevent more than 1 request per minute per email
    last_otp = db.query(models.OTP).filter(
        models.OTP.email == email,
        models.OTP.created_at > datetime.utcnow() - timedelta(minutes=1)
    ).first()
    
    if last_otp:
        logger.warning(f"Rate limit hit for {email}")
        raise HTTPException(status_code=429, detail="otp.rate_limit_error")

    lang = otp_data.lang if otp_data.lang in ["en", "ru", "ka"] else "en"
    logger.info(f"OTP request received for email: {email} (lang: {lang})")

    try:
        # 1. Generate Secure 6-digit OTP inside the try block
        otp_code = "".join([str(secrets.randbelow(10)) for _ in range(6)])
        # 2. Prepare localized email content and HTML template
        subject = tr("otp.otp_subject", lang)
        message_text = tr("otp.otp_message", lang, code=otp_code, minutes=10)
        
        html_template = f"""
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>{subject}</title>
        </head>
        <body style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f4f4f9; padding: 20px;">
            <div style="max-width: 500px; margin: auto; background: #ffffff; padding: 40px; border-radius: 12px; box-shadow: 0 4px 15px rgba(0,0,0,0.1);">
                <h1 style="color: #6200ee; text-align: center; margin-bottom: 30px;">SYNO</h1>
                <div style="font-size: 18px; line-height: 1.6; color: #333; text-align: center;">
                    {message_text}
                </div>
                <div style="margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee; font-size: 12px; color: #888; text-align: center;">
                    &copy; {datetime.now().year} SYNO. All rights reserved.
                </div>
            </div>
        </body>
        </html>
        """

        # 3. Store the OTP in the database. crud handles hashing internally.
        crud.create_otp(db, email=email, code=otp_code)

        # 4. Send the HTML email in the background
        background_tasks.add_task(send_otp_email, email, subject, html_template)

        if getattr(settings, "debug", False):
            logger.info(f"DEBUG: OTP for {email} is {otp_code}")

    except Exception as e:
        logger.error(f"OTP Email Error: {e}")
        if isinstance(e, HTTPException):
            raise e
        raise HTTPException(status_code=500, detail="An error occurred while processing your request")
    
    return {"message": "OTP requested successfully"}

@app.post("/api/auth/request-otp-phone", status_code=status.HTTP_200_OK)
async def request_otp_phone(otp_data: schemas.SMSOTPRequest, background_tasks: BackgroundTasks, db: Session = Depends(get_db)):
    """Sends a 6-digit OTP via SMS to the provided phone number."""
    is_valid, formatted_phone = validate_phone_number(otp_data.phone_number)
    if not is_valid:
        raise HTTPException(status_code=400, detail="otp.invalid_phone_format")

    # Rate limiting: 1 request per minute
    last_otp = db.query(models.OTP).filter(
        models.OTP.phone_number == formatted_phone,
        models.OTP.created_at > datetime.utcnow() - timedelta(minutes=1)
    ).first()
    
    if last_otp:
        raise HTTPException(status_code=429, detail="otp.rate_limit_error")

    lang = otp_data.lang if otp_data.lang in ["en", "ru", "ka"] else "en"
    otp_code = "".join([str(secrets.randbelow(10)) for _ in range(6)])
    
    # Format as XXX-XXX for the SMS
    display_code = f"{otp_code[:3]}-{otp_code[3:]}"
    logger.info(f"Generated SMS OTP for {formatted_phone}: {otp_code}")

    sms_message = tr("otp.sms_message", lang, code=display_code)
    
    crud.create_otp_phone(db, phone=formatted_phone, code=otp_code)
    background_tasks.add_task(send_sms_otp, formatted_phone, sms_message)
    
    return {"message": "otp.success"}

@app.post("/api/auth/verify-otp-phone", response_model=schemas.OTPVerifyResponse)
async def verify_otp_phone(otp_data: schemas.SMSOTPVerify, db: Session = Depends(get_db)):
    """Verifies phone OTP and links it to user/profile."""
    is_valid, formatted_phone = validate_phone_number(otp_data.phone_number)
    if not is_valid:
        raise HTTPException(status_code=400, detail="otp.invalid_phone_format")
    
    success, msg_key = crud.verify_otp_phone_logic(db, formatted_phone, otp_data.code)
    if not success:
        raise HTTPException(status_code=400, detail=msg_key)

    # Check if a profile already uses this phone
    existing_profile = db.query(models.Profile).filter(models.Profile.phone_number == formatted_phone).first()
    
    if existing_profile and existing_profile.user_id:
        # If profile exists, find the associated user to issue a token
        db_user = db.query(models.SynoUser).filter(models.SynoUser.id == existing_profile.user_id).first()
        
        if db_user:
            if db_user.is_deactivated:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="account.deactivated"
                )
            access_token_expires = timedelta(minutes=settings.access_token_expire_minutes)
            access_token = create_access_token(
                data={"sub": db_user.email}, expires_delta=access_token_expires
            )
            return {
                "message": "otp.verified_success",
                "is_registered": True,
                "access_token": access_token,
                "token_type": "bearer"
            }

    # New Phone User: Create a placeholder user account to allow token issuance
    temp_email = f"phone_{formatted_phone.replace('+', '')}@syno.app".lower()
    db_user = crud.get_user_by_email(db, temp_email)
    if db_user and db_user.is_deactivated:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="account.deactivated"
        )
    if not db_user:
        db_user = crud.create_user(
            db, 
            schemas.UserCreate(email=temp_email, password=secrets.token_urlsafe(16))
        )

    access_token_expires = timedelta(minutes=settings.access_token_expire_minutes)
    access_token = create_access_token(
        data={"sub": db_user.email}, expires_delta=access_token_expires
    )
    return {
        "message": "otp.verified_success",
        "is_registered": False,
        "access_token": access_token,
        "token_type": "bearer"
    }

@app.post("/api/auth/verify-otp", response_model=schemas.OTPVerifyResponse)
async def verify_otp(otp_data: schemas.OTPVerify, db: Session = Depends(get_db)):
    # Branch to phone verification if phone number is provided
    if otp_data.phone_number and not otp_data.email:
        return await verify_otp_phone(
            schemas.SMSOTPVerify(phone_number=otp_data.phone_number, code=otp_data.code), 
            db
        )

    if not otp_data.email:
        raise HTTPException(status_code=400, detail="Email or Phone Number is required")

    email = otp_data.email.lower()
    logger.info(f"OTP verification attempt for: {email}")

    # 1. Verification Logic via CRUD
    is_valid, msg_key = crud.verify_otp_logic(db, email, otp_data.code)
    
    if not is_valid:
        logger.warning(f"OTP failed for {email}: {msg_key}")
        raise HTTPException(status_code=400, detail=msg_key)

    # 2. Check if user is registered
    db_user = crud.get_user_by_email(db, email.lower())
    db_profile = crud.get_profile_by_user_id(db, db_user.id) if db_user else None

    if db_user and db_user.is_deactivated:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="account.deactivated"
        )
    
    if db_user and db_profile:
        # Existing User with Profile - Issue login token
        access_token_expires = timedelta(minutes=settings.access_token_expire_minutes)
        access_token = create_access_token(
            data={"sub": db_user.email}, expires_delta=access_token_expires
        )
        return {
            "message": "otp.verified_success",
            "is_registered": True,
            "access_token": access_token,
            "token_type": "bearer"
        }
    elif db_user:
        # User exists but no profile - Issue token so they can create a profile in Step 2
        access_token_expires = timedelta(minutes=settings.access_token_expire_minutes)
        access_token = create_access_token(
            data={"sub": db_user.email}, expires_delta=access_token_expires
        )
        return {
            "message": "otp.verified_success",
            "is_registered": False,
            "access_token": access_token,
            "token_type": "bearer"
        }
    else:
        # New User - Create user record and return token for Step 2
        new_user = crud.create_user(
            db, 
            schemas.UserCreate(email=email, password=secrets.token_urlsafe(16))
        )
        access_token_expires = timedelta(minutes=settings.access_token_expire_minutes)
        access_token = create_access_token(
            data={"sub": new_user.email}, expires_delta=access_token_expires
        )
        return {
            "message": "otp.verified_success",
            "is_registered": False,
            "access_token": access_token,
            "token_type": "bearer"
        }


@app.get("/api/sexes/", response_model=List[schemas.Sex])
def read_sexes(db: Session = Depends(get_db)):
    return crud.get_sexes(db)


@app.get("/api/orientations/", response_model=List[schemas.Orientation])
def read_orientations(db: Session = Depends(get_db)):
    return crud.get_orientations(db)


@app.get("/api/hobbies/", response_model=List[schemas.Hobby])
def read_hobbies(q: Optional[str] = None, db: Session = Depends(get_db)):
    return crud.get_hobbies(db, query=q)

@app.get("/api/educations/", response_model=List[schemas.Education])
def read_educations(q: Optional[str] = None, db: Session = Depends(get_db)):
    return crud.get_educations(db, query=q)

@app.get("/api/professions/", response_model=List[schemas.Profession])
def read_professions(q: Optional[str] = None, db: Session = Depends(get_db)):
    return crud.get_professions(db, query=q)

@app.get("/api/core-values/", response_model=List[schemas.CoreValue])
def read_core_values(db: Session = Depends(get_db)):
    return crud.get_core_values(db)

@app.get("/api/intentions/", response_model=List[schemas.Intention])
def read_intentions(db: Session = Depends(get_db)):
    return crud.get_intentions(db)

@app.get("/api/location/search", response_model=List[schemas.Location])
async def search_locations(q: Optional[str] = None, db: Session = Depends(get_db)):
    results = crud.search_locations(db, query=q)

    from app.location_service import resolve_location_from_nominatim
    for loc in results:
        if loc.latitude is None or loc.longitude is None:
            resolved = await resolve_location_from_nominatim(loc.name)
            if resolved:
                loc.latitude = resolved["latitude"]
                loc.longitude = resolved["longitude"]
                if not loc.timezone:
                    loc.timezone = resolved.get("timezone", "+00:00")
    db.commit()

    return results


@app.post("/api/locations/seed", summary="Seed locations from REST Countries API (run once)")
async def seed_locations(db: Session = Depends(get_db)):
    from app.location_service import seed_locations_from_api
    result = await seed_locations_from_api(db)
    return result


@app.post("/api/locations/backfill", summary="Backfill missing lat/lon/timezone for existing locations")
def backfill_locations(db: Session = Depends(get_db)):
    from app.location_service import backfill_location_coords
    result = backfill_location_coords(db)
    return result


@app.get("/api/locations/resolve", summary="Resolve location name to coordinates via Nominatim")
async def resolve_location(q: str, timezone: Optional[str] = None):
    try:
        from app.location_service import resolve_location_from_nominatim
        result = await resolve_location_from_nominatim(q)
        if not result:
            raise HTTPException(status_code=404, detail=f"Could not resolve location: {q}")
        if timezone:
            result["timezone"] = timezone
        return result
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Resolve failed: {str(e)}")


@app.get("/api/locations/search-async", summary="Search locations with API fallback")
async def search_locations_async(q: Optional[str] = None, db: Session = Depends(get_db)):
    from app.location_service import search_locations_api
    return await search_locations_api(query=q, db=db)


# ----------------- USER PROFILE -----------------

@app.patch("/api/users/me", response_model=schemas.Profile, summary="Create or partially update user profile with photos")
async def create_or_update_user_profile_patch(
    profile_in: schemas.ProfileUpdateForm = Depends(schemas.ProfileUpdateForm.as_form_patch),
    primary_photo: Optional[UploadFile] = File(None),
    uploaded_photos: List[UploadFile] = File([]),
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    """
    Handles both creation and partial updates for a user's profile.
    """
    # profile_in is already parsed and validated by ProfileUpdateForm.as_form_patch
    update_data = profile_in.dict(exclude_unset=True)

    db_profile = crud.get_profile_by_user_id(db, user_id=current_user.id)
    

    if db_profile:
        # This is an update (PATCH)
        
        # Filter out theme-related fields to ensure independence. 
        # Profile updates should not modify theme settings.
        theme_keys = {'theme_id', 'background_color', 'accent_color', 'layout', 'theme_preferences'}
        filtered_data = {k: v for k, v in update_data.items() if k not in theme_keys}
        profile_update_schema = schemas.ProfileUpdate(**filtered_data)
        
        await crud.update_profile(db=db, db_profile=db_profile, profile_in=profile_update_schema)

        # 2. Handle Primary Photo Update (if provided)
        if primary_photo and primary_photo.filename:
            await crud.update_primary_photo(db, db_profile, primary_photo)

        # 3. Handle Additional Photos Append (if provided)
        valid_additional_photos = [p for p in uploaded_photos if p and p.filename]
        if valid_additional_photos:
            await crud.add_additional_photos(db, db_profile, valid_additional_photos)

        # Fetch the complete profile with all relationships loaded (intentions, professions, etc.)
        # We need to reload using the CRUD getter that has 'joinedload' options to populate nested objects for the response
        db_profile = crud.get_profile_by_user_id(db, user_id=current_user.id)

        # Construct the response manually to ensure theme_preferences are included.
        # This prevents the frontend from losing theme state after a profile update.
        profile_dict = schemas.Profile.model_validate(db_profile).model_dump()
        user_theme_settings = db.query(models.Settings).filter(models.Settings.user_id == db_profile.id).first()
        if user_theme_settings:
            profile_dict['theme_preferences'] = {
                'theme_id': user_theme_settings.theme_id,
                'background_color': user_theme_settings.background_color,
                'accent_color': user_theme_settings.accent_color,
                'layout': user_theme_settings.layout
            }
        return profile_dict
    else:
        # This is a creation (POST-like behavior on a PATCH)
        # Combine photos into a single list for creation logic
        all_photos: List[UploadFile] = []
        if primary_photo and primary_photo.filename:
            all_photos.append(primary_photo)
        all_photos.extend([p for p in uploaded_photos if p and p.filename])

        if not all_photos:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="A primary photo is required to create a profile.")
        
        # For creation, use the parsed data.
        create_data = schemas.ProfileUpdate(**update_data) # Use the parsed data

        
        # Ensure 'name' is present and not None
        if not create_data.name: raise HTTPException(status_code=400, detail="Name cannot be empty.")
        await crud.create_profile(db=db, profile_in=create_data, user_id=current_user.id, photos=all_photos)

        # Fetch the complete profile with all relationships loaded
        new_profile = crud.get_profile_by_user_id(db, user_id=current_user.id)
        
        # Attach default theme preferences for new profiles if needed
        profile_dict = schemas.Profile.model_validate(new_profile).model_dump()
        profile_dict['theme_preferences'] = {
            'theme_id': 'deep_space', # Default
            'background_color': '#000000',
            'accent_color': '#FFFFFF',
            'layout': 'default'
        }
        return profile_dict


@app.get("/api/users/me", response_model=schemas.Profile)
def read_users_me(
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    profile = crud.get_profile_by_user_id(db, user_id=current_user.id)
    if profile is None:
        raise HTTPException(status_code=404, detail="Profile not found for the current user.")
    # The response model `schemas.Profile` should be configured to serialize
    # the relationships (intentions, core_values) from the `profile` ORM object.
    # Pydantic's `model_validate` with `from_attributes=True` on the schema handles this.
    profile_dict = schemas.Profile.model_validate(profile).model_dump()
    user_theme_settings = db.query(models.Settings).filter(models.Settings.user_id == profile.id).first()
    if user_theme_settings:
        profile_dict['theme_preferences'] = {
            'theme_id': user_theme_settings.theme_id,
            'background_color': user_theme_settings.background_color,
            'accent_color': user_theme_settings.accent_color,
            'layout': user_theme_settings.layout
        }
    prefs = db.query(models.UserPreferences).filter(
        models.UserPreferences.profile_id == profile.id
    ).first()
    if prefs:
        profile_dict['preferences'] = {
            'min_age': prefs.min_age,
            'max_age': prefs.max_age,
            'max_distance': prefs.max_distance,
            'genders': prefs.genders or [],
        }
    else:
        profile_dict['preferences'] = {
            'min_age': 18,
            'max_age': 50,
            'max_distance': 100,
            'genders': [],
        }
    return profile_dict

@app.get("/api/photos/{photo_id}", summary="Get a user's photo")
def get_photo(
    photo_id: int,
    db: Session = Depends(get_db),
):
    """Retrieves and serves a photo by ID. Public endpoint for viewing profile photos."""
    photo = db.query(models.UserPhoto).filter(models.UserPhoto.id == photo_id).first()
    if not photo:
        raise HTTPException(status_code=404, detail="Photo not found.")
    return Response(content=photo.photo_data, media_type="image/jpeg")

@app.delete("/api/photos/{photo_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Delete a user's photo")
def delete_a_photo(
    photo_id: int,
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    """Deletes a specific photo by its ID."""
    success = crud.delete_photo(db, photo_id=photo_id, user_id=current_user.id)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Photo not found or you don't have permission to delete it."
        )
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@app.delete("/api/users/me", status_code=status.HTTP_204_NO_CONTENT, summary="Deactivate your account (soft-delete)")
def deactivate_current_user(
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    success = crud.deactivate_user(db, user_id=current_user.id)
    if not success:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found.")
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@app.post("/api/auth/request-reactivation", status_code=status.HTTP_200_OK)
async def request_reactivation(
    reactivation_data: schemas.AccountReactivationRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db)
):
    """
    Request a reactivation OTP for a deactivated account.
    Accepts email or phone_number. Always returns 200 to prevent enumeration.
    """
    # Resolve identifier: email or phone → email on SynoUser
    resolved_email = None
    is_phone = False

    if reactivation_data.phone_number:
        is_phone = True
        is_valid, formatted_phone = validate_phone_number(reactivation_data.phone_number)
        logger.info(f"[Reactivation] Phone input: '{reactivation_data.phone_number}', valid: {is_valid}, formatted: {formatted_phone}")
        if is_valid:
            resolved_email = f"phone_{formatted_phone.replace('+', '')}@syno.app".lower()
        else:
            # Fallback: use raw digits as formatted_phone for consistent user lookup
            clean_phone = re.sub(r'[^\d]', '', reactivation_data.phone_number)
            formatted_phone = clean_phone
            if clean_phone:
                resolved_email = f"phone_{clean_phone}@syno.app".lower()
                logger.info(f"[Reactivation] Fallback resolved_email: {resolved_email}")
    elif reactivation_data.email:
        resolved_email = reactivation_data.email.lower()
    else:
        # Always return success to prevent enumeration
        return {"message": "If an account with that identifier exists and is deactivated, a recovery code has been sent."}

    logger.info(f"[Reactivation] resolved_email: {resolved_email}")
    if resolved_email:
        user = crud.get_user_by_email(db, email=resolved_email)
        logger.info(f"[Reactivation] user found: {user is not None}, is_deactivated: {user.is_deactivated if user else 'N/A'}")
        if user and user.is_deactivated:
            try:
                otp_code = "".join([str(secrets.randbelow(10)) for _ in range(6)])
                logger.info(f"[Reactivation] Creating OTP code: {otp_code}, is_phone: {is_phone}")
                if is_phone:
                    crud.create_otp_phone(db, phone=formatted_phone, code=otp_code, expires_in_minutes=15)
                    sms_message = tr("otp.sms_message", code=otp_code)
                    background_tasks.add_task(send_sms_otp, reactivation_data.phone_number, sms_message)
                else:
                    crud.create_otp(db, email=resolved_email, code=otp_code, expires_in_minutes=15)
                    subject = "SYNO - Account Recovery"
                    html_content = f"""
                    <html>
                    <body style="font-family: sans-serif; padding: 20px;">
                        <h2 style="color: #6200ee;">SYNO Account Recovery</h2>
                        <p>Your recovery code is: <strong style="font-size: 24px; letter-spacing: 4px;">{otp_code}</strong></p>
                        <p>This code expires in 15 minutes.</p>
                        <p>If you did not request this, please ignore this email.</p>
                    </body>
                    </html>
                    """
                    background_tasks.add_task(send_otp_email, resolved_email, subject, html_content)
            except Exception as e:
                logger.error(f"[Reactivation] OTP creation error: {e}")

    # Always return success to prevent enumeration
    return {"message": "If an account with that identifier exists and is deactivated, a recovery code has been sent."}


@app.post("/api/auth/verify-reactivation", response_model=schemas.AccountReactivationResponse)
async def verify_reactivation(
    reactivation_data: schemas.AccountReactivationVerify,
    db: Session = Depends(get_db)
):
    """
    Verify the reactivation OTP and reactivate the account.
    Accepts email or phone_number. Returns a new access token on success.
    """
    # Resolve identifier
    resolved_email = None
    is_phone = False

    if reactivation_data.phone_number:
        is_phone = True
        is_valid, formatted_phone = validate_phone_number(reactivation_data.phone_number)
        if is_valid:
            resolved_email = f"phone_{formatted_phone.replace('+', '')}@syno.app".lower()
        else:
            # Fallback: use raw digits as formatted_phone (matches request-reactivation fallback)
            clean_phone = re.sub(r'[^\d]', '', reactivation_data.phone_number)
            formatted_phone = clean_phone
            if clean_phone:
                resolved_email = f"phone_{clean_phone}@syno.app".lower()
            else:
                raise HTTPException(status_code=400, detail="otp.invalid_phone_format")
    elif reactivation_data.email:
        resolved_email = reactivation_data.email.lower()
    else:
        raise HTTPException(status_code=400, detail="auth.email_or_phone_required")

    user = crud.get_user_by_email(db, email=resolved_email)

    if not user:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="auth.invalid_code")

    if not user.is_deactivated:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="auth.account_not_deactivated")

    # Verify OTP based on method
    if is_phone:
        is_valid, msg_key = crud.verify_otp_phone_logic(db, formatted_phone, reactivation_data.code)
    else:
        is_valid, msg_key = crud.verify_otp_logic(db, resolved_email, reactivation_data.code)

    if not is_valid:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=msg_key)

    # Reactivate the account
    crud.reactivate_user(db, user_id=user.id)

    # Issue a new access token
    access_token_expires = timedelta(minutes=settings.access_token_expire_minutes)
    access_token = create_access_token(
        data={"sub": user.email}, expires_delta=access_token_expires
    )
    return {
        "message": "Account reactivated successfully",
        "access_token": access_token,
        "token_type": "bearer"
    }


@app.post("/api/admin/cleanup-deactivated", summary="Permanently delete deactivated accounts past recovery window")
def cleanup_deactivated_accounts(
    days: int = 30,
    db: Session = Depends(get_db)
):
    """Admin endpoint to permanently delete accounts deactivated more than N days ago."""
    count = crud.cleanup_expired_deactivated_accounts(db, days=days)
    return {"deleted_count": count}


# ----------------- BLOCK / UNBLOCK -----------------

@app.post("/api/users/{user_id}/block", status_code=status.HTTP_204_NO_CONTENT, summary="Block another user")
def block_a_user(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    result = crud.block_user(db, blocker_id=current_user.id, blocked_id=user_id)
    if result is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User to block not found or you cannot block yourself."
        )
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@app.delete("/api/users/{user_id}/unblock", status_code=status.HTTP_204_NO_CONTENT, summary="Unblock another user")
def unblock_user(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    crud.unblock_user(db, blocker_id=current_user.id, blocked_id=user_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@app.get("/api/users/me/blocked", response_model=List[schemas.Profile], summary="Get list of blocked users")
def get_blocked_list(
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    return crud.get_blocked_users(db, blocker_id=current_user.id)


@app.get("/api/users/profile-search/{name}", response_model=schemas.Profile, summary="Search for a user profile by name")
def search_user_by_name_endpoint(
    name: str,
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    profile = crud.get_profile_by_name(db, name)
    if not profile:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return profile


@app.post("/api/users/block-by-name", status_code=status.HTTP_204_NO_CONTENT, summary="Block user by profile name")
def block_user_by_name(
    name_data: schemas.BlockByNameRequest,
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    profile = crud.get_profile_by_name(db, name_data.name)
    if not profile:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    
    result = crud.block_user(db, blocker_id=current_user.id, blocked_id=profile.user_id)
    if result is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot block yourself")
    return Response(status_code=status.HTTP_204_NO_CONTENT)


# ----------------- USER PREFERENCES -----------------

@app.get("/api/users/me/preferences", response_model=schemas.UserPreferencesResponse)
def get_user_preferences(
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    db_profile = crud.get_profile_by_user_id(db, user_id=current_user.id)
    if not db_profile:
        raise HTTPException(status_code=404, detail="Profile not found")

    prefs = db.query(models.UserPreferences).filter(
        models.UserPreferences.profile_id == db_profile.id
    ).first()

    if not prefs:
        prefs = models.UserPreferences(profile_id=db_profile.id)
        db.add(prefs)
        db.commit()
        db.refresh(prefs)

    return prefs


@app.put("/api/users/me/preferences", response_model=schemas.UserPreferencesResponse)
def update_user_preferences(
    prefs_data: schemas.UserPreferencesCreate,
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    db_profile = crud.get_profile_by_user_id(db, user_id=current_user.id)
    if not db_profile:
        raise HTTPException(status_code=404, detail="Profile not found")

    prefs = db.query(models.UserPreferences).filter(
        models.UserPreferences.profile_id == db_profile.id
    ).first()

    if not prefs:
        prefs = models.UserPreferences(profile_id=db_profile.id)
        db.add(prefs)

    update_dict = prefs_data.model_dump(exclude_unset=True)
    for key, value in update_dict.items():
        setattr(prefs, key, value)

    try:
        db.commit()
        db.refresh(prefs)
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to save preferences: {str(e)}")

    return prefs


# ----------------- DUAL MODE (Dating + BFF) -----------------

@app.post("/api/mode/switch", summary="Switch active mode (dating or bff)")
def switch_mode(
    mode_data: schemas.ModeSwitchRequest,
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    profile = crud.switch_active_mode(db, user_id=current_user.id, mode=mode_data.mode)
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")
    return {"active_mode": profile.active_mode}


@app.get("/api/mode/current", summary="Get current active mode")
def get_current_mode(
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    profile = crud.get_profile_by_user_id(db, user_id=current_user.id)
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")
    return {"active_mode": profile.active_mode or "dating"}


@app.get("/api/mode/preferences", response_model=schemas.UserAppModeResponse, summary="Get mode-specific preferences")
def get_mode_preferences(
    mode: str = "dating",
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    db_profile = crud.get_profile_by_user_id(db, user_id=current_user.id)
    if not db_profile:
        raise HTTPException(status_code=404, detail="Profile not found")
    app_mode = crud.get_or_create_app_mode(db, profile_id=db_profile.id, mode=mode)
    return app_mode


@app.put("/api/mode/preferences", response_model=schemas.UserAppModeResponse, summary="Update mode-specific preferences")
def update_mode_preferences(
    mode: str = "dating",
    prefs_data: schemas.UserAppModeUpdate = None,
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    db_profile = crud.get_profile_by_user_id(db, user_id=current_user.id)
    if not db_profile:
        raise HTTPException(status_code=404, detail="Profile not found")
    update_dict = prefs_data.model_dump(exclude_unset=True) if prefs_data else {}
    app_mode = crud.update_app_mode(db, profile_id=db_profile.id, mode=mode, data=update_dict)
    return app_mode


@app.get("/api/discover")
def get_discover(
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    db_profile = crud.get_profile_by_user_id(db, user_id=current_user.id)
    if not db_profile:
        return []

    blocked_ids_query = db.query(models.user_blocks.c.blocked_id).filter(
        models.user_blocks.c.blocker_id == current_user.id
    )
    blocked_ids = [r[0] for r in blocked_ids_query.all()]

    swiped_user_ids = set()
    swiped = db.query(models.Match.matched_user_id).filter(
        models.Match.user_id == current_user.id
    ).all()
    swiped_user_ids = {r[0] for r in swiped}

    received_like_ids = set()
    received = db.query(models.Match.user_id).filter(
        models.Match.matched_user_id == current_user.id,
        models.Match.status == "accepted"
    ).all()
    received_like_ids = {r[0] for r in received}

    exclude_ids = set(blocked_ids) | swiped_user_ids | received_like_ids

    query = db.query(models.Profile).options(
        joinedload(models.Profile.location),
        joinedload(models.Profile.sex),
        joinedload(models.Profile.orientation),
        joinedload(models.Profile.photos).load_only(models.UserPhoto.id, models.UserPhoto.is_primary, models.UserPhoto.upload_order),
        joinedload(models.Profile.hobbies),
        joinedload(models.Profile.intentions),
        joinedload(models.Profile.core_values),
        joinedload(models.Profile.professions),
        joinedload(models.Profile.educations),
    ).filter(
        models.Profile.user_id != current_user.id,
        ~models.Profile.user_id.in_(exclude_ids) if exclude_ids else True,
    )

    profiles = query.all()

    received_like_ids_display = set(crud.get_received_like_user_ids(db, user_id=current_user.id))

    profile_list = [
        {
            "id": p.id,
            "user_id": p.user_id,
            "name": p.name,
            "last_name": p.last_name,
            "birth_date": p.birth_date.isoformat() if p.birth_date else None,
            "birth_time": p.birth_time,
            "bio": p.bio,
            "height": p.height,
            "location": {"id": p.location.id, "name": p.location.name, "type": p.location.type, "translation_key": p.location.translation_key or '', "latitude": p.location.latitude, "longitude": p.location.longitude} if p.location else None,
            "sex": {"id": p.sex.id, "name": p.sex.name, "translation_key": p.sex.translation_key or ''} if p.sex else None,
            "orientation": {"id": p.orientation.id, "name": p.orientation.name, "translation_key": p.orientation.translation_key or ''} if p.orientation else None,
            "photos": [{"id": ph.id, "is_primary": ph.is_primary, "upload_order": ph.upload_order, "url": f"/api/photos/{ph.id}"} for ph in p.photos],
            "hobbies": [{"id": h.id, "name": h.name, "translation_key": h.translation_key or ''} for h in p.hobbies],
            "intentions": [{"id": i.id, "key": i.key, "translation_key": i.translation_key} for i in p.intentions],
            "core_values": [{"id": cv.id, "key": cv.key, "translation_key": cv.translation_key or ''} for cv in p.core_values],
            "professions": [{"id": pr.id, "name": pr.name, "translation_key": pr.translation_key or ''} for pr in p.professions],
            "educations": [{"id": e.id, "name": e.name, "translation_key": e.translation_key or ''} for e in p.educations],
            "liked_by_user": p.user_id in received_like_ids_display,
        }
        for p in profiles
    ]

    profile_list.sort(key=lambda x: (not x["liked_by_user"], x["user_id"]))

    return profile_list


@app.get("/api/discover/smart", response_model=List[schemas.SmartDiscoverItem], summary="Smart discovery with server-side scoring")
def get_smart_discover(
    mode: str = "dating",
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    from .matching_engine import get_smart_discover_list

    db_profile = crud.get_profile_by_user_id(db, user_id=current_user.id)
    if not db_profile:
        return []

    preferences = db.query(models.UserPreferences).filter(
        models.UserPreferences.profile_id == db_profile.id
    ).first()

    results = get_smart_discover_list(db, current_user, preferences, mode=mode)
    return results


@app.get("/api/recommendations/daily", response_model=List[schemas.RecommendationResponse], summary="Get daily top pick recommendations")
def get_daily_recommendations(
    mode: str = "dating",
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    from .recommendation_engine import generate_daily_recommendations

    db_profile = crud.get_profile_by_user_id(db, user_id=current_user.id)
    if not db_profile:
        return []

    results = generate_daily_recommendations(db, current_user, mode=mode)
    return results


@app.put("/api/users/me/settings", response_model=schemas.Profile)
def update_theme_settings(
    settings_data: schemas.ThemeSettingsUpdate,
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    # First, ensure a profile exists. The database schema requires a profile
    # before settings can be saved, which is the cause of the ForeignKeyViolation.
    db_profile = crud.get_profile_by_user_id(db, user_id=current_user.id)
    if not db_profile:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="A user profile must be created before theme settings can be saved."
        )

    # 1. Upsert (Update or Create) Settings
    user_settings = db.query(models.Settings).filter(models.Settings.user_id == db_profile.id).first()
    if not user_settings:
        user_settings = models.Settings(user_id=db_profile.id)
        db.add(user_settings)

    user_settings.theme_id = settings_data.theme_id
    user_settings.background_color = settings_data.background_color
    user_settings.accent_color = settings_data.accent_color
    user_settings.layout = settings_data.layout

    # 2. Update legacy theme_id on the Profile table. This is now guaranteed to exist.
    theme_map = {
        'deep_space': '3',   # Maps to old Purple/Dark
        'starlight': '1',    # Maps to old Light
        'nebula_dream': '2', # Maps to old System/Default
    }
    db_profile.theme_id = theme_map.get(settings_data.theme_id, settings_data.theme_id)

    try:
        db.commit()
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to save theme settings: {str(e)}"
        )
    db.refresh(db_profile)
    db.refresh(user_settings)

    profile_dict = schemas.Profile.model_validate(db_profile).model_dump()
    profile_dict['theme_preferences'] = {
        'theme_id': user_settings.theme_id,
        'background_color': user_settings.background_color,
        'accent_color': user_settings.accent_color,
        'layout': user_settings.layout
    }
    return profile_dict


# ============================================================
# MATCHES ENDPOINTS
# ============================================================

@app.post("/api/matches", response_model=schemas.MatchResponse, summary="Create or update a match (swipe)")
def create_or_update_match(
    match_data: schemas.MatchCreate,
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    if match_data.matched_user_id == current_user.id:
        raise HTTPException(status_code=400, detail="Cannot match with yourself")

    if match_data.status not in ("pending", "accepted", "declined", "hidden", "saved"):
        raise HTTPException(status_code=400, detail="Invalid match status")

    target_user = db.query(models.SynoUser).filter(models.SynoUser.id == match_data.matched_user_id).first()
    if not target_user:
        raise HTTPException(status_code=404, detail="Target user not found")

    target_profile = crud.get_profile_by_user_id(db, user_id=match_data.matched_user_id)
    if not target_profile:
        raise HTTPException(status_code=404, detail="Target user has no profile")

    match = crud.create_match(
        db,
        user_id=current_user.id,
        matched_user_id=match_data.matched_user_id,
        status=match_data.status,
        compatibility_score=match_data.compatibility_score,
        mode=match_data.mode,
    )

    # Update behavior profile after swipe action
    try:
        from .behavior_updater import update_behavior_profile
        update_behavior_profile(db, current_user.id)
    except Exception as e:
        logging.debug(f"Behavior profile update after swipe failed: {e}")

    return match


@app.get("/api/matches", response_model=List[schemas.MatchWithProfileResponse], summary="Get all matches for current user")
def get_my_matches(
    mode: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    if mode:
        matches = crud.get_matches_for_user_by_mode(db, user_id=current_user.id, mode=mode)
    else:
        matches = crud.get_matches_for_user(db, user_id=current_user.id)
    result = []
    for m in matches:
        other_id = m.matched_user_id if m.user_id == current_user.id else m.user_id
        profile = db.query(models.Profile).options(
            joinedload(models.Profile.photos).load_only(models.UserPhoto.id, models.UserPhoto.is_primary),
            joinedload(models.Profile.location),
            joinedload(models.Profile.sex),
        ).filter(models.Profile.user_id == other_id).first()
        matched_profile = None
        if profile:
            primary_photo = next((p for p in profile.photos if p.is_primary), (profile.photos[0] if profile.photos else None))
            matched_profile = {
                "id": profile.user_id,
                "user_id": profile.user_id,
                "name": profile.name,
                "last_name": profile.last_name,
                "birth_date": profile.birth_date.isoformat() if profile.birth_date else None,
                "birth_time": profile.birth_time,
                "bio": profile.bio,
                "location": {"id": profile.location.id, "name": profile.location.name, "latitude": profile.location.latitude, "longitude": profile.location.longitude} if profile.location else None,
                "sex": {"id": profile.sex.id, "name": profile.sex.name} if profile.sex else None,
                "photo_url": f"/api/photos/{primary_photo.id}" if primary_photo else None,
            }
        result.append(schemas.MatchWithProfileResponse(
            id=m.id,
            user_id=m.user_id,
            matched_user_id=m.matched_user_id,
            status=m.status,
            compatibility_score=m.compatibility_score,
            mode=m.mode or "dating",
            created_at=m.created_at,
            updated_at=m.updated_at,
            matched_profile=matched_profile,
        ))
    return result


@app.patch("/api/matches/{match_id}", response_model=schemas.MatchResponse, summary="Update match status")
def update_match_status(
    match_id: int,
    update_data: schemas.MatchUpdate,
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    if update_data.status not in ("pending", "accepted", "declined", "hidden", "saved"):
        raise HTTPException(status_code=400, detail="Invalid match status")
    match = crud.update_match_status(db, match_id=match_id, user_id=current_user.id, status=update_data.status)
    if not match:
        raise HTTPException(status_code=404, detail="Match not found")
    return match


@app.get("/api/matches/mutual/{other_user_id}", response_model=schemas.MutualMatchCheck, summary="Check if mutual match exists")
def check_mutual_match(
    other_user_id: int,
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    mutual = crud.get_mutual_match(db, user_id=current_user.id, other_user_id=other_user_id)
    return schemas.MutualMatchCheck(
        is_mutual=mutual is not None,
        match_id=mutual.id if mutual else None
    )


@app.get("/api/matches/{match_id}/compatibility", summary="Get detailed compatibility report for a match")
def get_compatibility_report(
    match_id: int,
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    match = db.query(models.Match).filter(models.Match.id == match_id).first()
    if not match:
        raise HTTPException(status_code=404, detail="Match not found")

    if match.user_id != current_user.id and match.matched_user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not part of this match")

    other_user_id = match.matched_user_id if match.user_id == current_user.id else match.user_id

    current_profile = crud.get_profile_by_user_id(db, user_id=current_user.id)
    other_profile = crud.get_profile_by_user_id(db, user_id=other_user_id)

    if not current_profile or not other_profile:
        raise HTTPException(status_code=404, detail="Profile not found")

    if not current_profile.birth_date or not other_profile.birth_date:
        raise HTTPException(status_code=400, detail="Birth date required for detailed report")

    if not current_profile.location or not other_profile.location:
        raise HTTPException(status_code=400, detail="Location required for detailed report")

    try:
        from datetime import time as dtime
        from .astrology.domain.models import BirthData
        from .astrology.providers.western import SwissEphProvider
        from .astrology.services.report_service import ReportService

        # Missing birth time is not fatal: we compute at 12:00 local and flag
        # the whole report as partial (houses/Ascendant become approximate).
        chart_partial = False

        def _parse_birth_time(profile) -> dtime:
            nonlocal chart_partial
            if profile.birth_time:
                parts = profile.birth_time.split(":")
                return dtime(int(parts[0]), int(parts[1]))
            chart_partial = True
            return dtime(12, 0)

        def _get_timezone(loc) -> str:
            tz = getattr(loc, 'timezone', None) if loc else None
            if tz:
                return tz
            return "+00:00"

        birth_a = BirthData(
            birth_date=current_profile.birth_date,
            birth_time=_parse_birth_time(current_profile),
            timezone=_get_timezone(current_profile.location),
            latitude=getattr(current_profile.location, 'latitude', None),
            longitude=getattr(current_profile.location, 'longitude', None),
            location_name=current_profile.location.name,
        )
        birth_b = BirthData(
            birth_date=other_profile.birth_date,
            birth_time=_parse_birth_time(other_profile),
            timezone=_get_timezone(other_profile.location),
            latitude=getattr(other_profile.location, 'latitude', None),
            longitude=getattr(other_profile.location, 'longitude', None),
            location_name=other_profile.location.name,
        )

        if birth_a.latitude is None or birth_a.longitude is None:
            raise HTTPException(status_code=400, detail="Your birth location coordinates are missing")
        if birth_b.latitude is None or birth_b.longitude is None:
            raise HTTPException(status_code=400, detail="Match birth location coordinates are missing")

        hobbies_a = {h.name for h in current_profile.hobbies} if current_profile.hobbies else set()
        hobbies_b = {h.name for h in other_profile.hobbies} if other_profile.hobbies else set()
        shared_hobbies = list(hobbies_a & hobbies_b)

        values_a = {cv.key for cv in current_profile.core_values} if current_profile.core_values else set()
        values_b = {cv.key for cv in other_profile.core_values} if other_profile.core_values else set()
        shared_values = list(values_a & values_b)

        intentions_a = {i.key for i in current_profile.intentions} if current_profile.intentions else set()
        intentions_b = {i.key for i in other_profile.intentions} if other_profile.intentions else set()
        shared_intentions = list(intentions_a & intentions_b)

        from .recommendation_engine import calculate_activity_score, calculate_profile_quality_score, calculate_mutual_interest_score

        activity = calculate_activity_score(db, other_user_id)
        profile_quality = calculate_profile_quality_score(other_profile)
        mutual = calculate_mutual_interest_score(db, current_user.id, other_user_id)

        # Behavioral compatibility - None when neither user has observed
        # behaviour yet (default profiles are not a signal).
        from .matching_engine import _calculate_behavioral_score

        behavioral_compat = _calculate_behavioral_score(db, current_user.id, other_user_id, mode="dating")

        # Canonical discovery score: same function + same weights as the
        # discover list and match list, so the report % can never drift.
        from .matching_engine import (
            compute_full_compatibility_score,
            resolve_signal_weights,
            calculate_profile_similarity,
            profile_similarity_has_data,
            compute_chart_score,
        )

        mode = match.mode or "dating"
        preferences = db.query(models.UserPreferences).filter(
            models.UserPreferences.profile_id == current_profile.id
        ).first()
        mode_prefs = db.query(models.UserAppMode).filter(
            models.UserAppMode.profile_id == current_profile.id,
            models.UserAppMode.mode == mode,
        ).first()

        if preferences:
            user_weights = {
                'weight_natal_chart': getattr(preferences, 'weight_natal_chart', 60),
                'weight_interests': getattr(preferences, 'weight_interests', 10),
                'weight_behavior': getattr(preferences, 'weight_behavior', 30),
            }
        elif mode_prefs:
            user_weights = {
                'weight_natal_chart': getattr(mode_prefs, 'weight_natal_chart', 60),
                'weight_interests': getattr(mode_prefs, 'weight_interests', 30),
                'weight_behavior': getattr(mode_prefs, 'weight_behavior', 10),
            }
        else:
            user_weights = None

        signal_weights = resolve_signal_weights(user_weights, mode)

        # Chart score is computed once and reused for the headline % and the
        # ranking input, so the two can never disagree.
        chart_value, chart_flag = compute_chart_score(current_profile, other_profile)
        chart_partial = chart_partial or chart_flag

        (
            canonical_score, canonical_synastry, canonical_behavioral,
            _activity, _mutual, _weighted, _insight, _reasons,
        ) = compute_full_compatibility_score(
            db, current_user.id, current_profile, other_profile,
            mode=mode, user_weights=user_weights,
            chart=(chart_value, chart_flag),
        )

        # Interests/values are only a number when both profiles actually
        # have something comparable - otherwise the part stays null.
        profile_has_data = profile_similarity_has_data(current_profile, other_profile)
        canonical_profile_sim = (
            calculate_profile_similarity(
                current_profile, other_profile,
                hobbies_weight=signal_weights["hobbies_weight"],
                values_weight=signal_weights["values_weight"],
                intentions_weight=signal_weights["intentions_weight"],
            )
            if profile_has_data
            else None
        )

        provider = SwissEphProvider()
        from .astrology.router import _get_ai_interpreter, _get_ai_service
        ai_interpreter = _get_ai_interpreter()
        ai_service = _get_ai_service()
        report_service = ReportService(
            provider, interpreter=ai_interpreter, ai_service=ai_service
        )

        report = report_service.generate_report(
            person_a=birth_a,
            person_b=birth_b,
            shared_hobbies=shared_hobbies,
            shared_values=shared_values,
            shared_intentions=shared_intentions,
            user_a_name=current_profile.name or "",
            user_b_name=other_profile.name or "",
            behavior_activity=activity,
            behavior_profile_quality=profile_quality,
            behavior_mutual_interest=mutual,
            behavioral_compatibility=behavioral_compat if behavioral_compat is not None else 50.0,
            # Headline % = the chart score. Behaviour shows as its own part.
            overall_score=canonical_synastry if canonical_synastry is not None else None,
            profile_similarity_score=canonical_profile_sim,
            behavior_score=canonical_behavioral,
            behavior_has_data=canonical_behavioral is not None,
            profile_has_data=profile_has_data,
            score_partial=chart_partial,
            composite_score=_weighted,
            chart_weight=signal_weights["synastry"],
            behavior_weight=signal_weights["behavioral"],
            profile_weight=signal_weights["profile_similarity"],
        )

        result = report_service.report_to_dict(report)
        result["ai_used"] = ai_service is not None and getattr(ai_interpreter, "last_used_ai", False)
        result["score_source"] = "natal_chart"
        return result

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Compatibility report failed: {e}")
        raise HTTPException(status_code=500, detail=f"Report generation failed: {str(e)}")


@app.delete("/api/matches/{match_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Delete a match")
def delete_match(
    match_id: int,
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    success = crud.delete_match(db, match_id=match_id, user_id=current_user.id)
    if not success:
        raise HTTPException(status_code=404, detail="Match not found")


@app.post("/api/matches/undo-last", summary="Undo the last swipe")
def undo_last_swipe(
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    last_match = db.query(models.Match).filter(
        models.Match.user_id == current_user.id
    ).order_by(models.Match.created_at.desc()).first()

    if not last_match:
        raise HTTPException(status_code=404, detail="No swipes to undo")

    db.delete(last_match)
    db.commit()
    return {"status": "undone", "undone_match_id": last_match.id}


# ============================================================
# MESSAGES ENDPOINTS
# ============================================================

@app.get("/api/messages/{match_id}", response_model=List[schemas.MessageResponse], summary="Get messages for a match")
def get_messages(
    match_id: int,
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    messages = crud.get_messages_for_match(db, match_id=match_id, user_id=current_user.id)
    return messages


@app.post("/api/messages", response_model=schemas.MessageResponse, summary="Send a message")
async def send_message(
    msg_data: schemas.MessageCreate,
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    match = db.query(models.Match).filter(models.Match.id == msg_data.match_id).first()
    if not match:
        raise HTTPException(status_code=404, detail="Match not found")

    if match.user_id != current_user.id and match.matched_user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not part of this match")

    other_user_id = match.matched_user_id if match.user_id == current_user.id else match.user_id

    blocked_ids = crud.get_blocked_user_ids(db, user_id=current_user.id)
    if other_user_id in blocked_ids:
        raise HTTPException(status_code=403, detail="Cannot message this user")

    other_blocked_ids = crud.get_blocked_user_ids(db, user_id=other_user_id)
    if current_user.id in other_blocked_ids:
        raise HTTPException(status_code=403, detail="Cannot message this user")

    reverse_match = db.query(models.Match).filter(
        models.Match.user_id == other_user_id,
        models.Match.matched_user_id == current_user.id,
    ).first()

    canonical_match_id = min(match.id, reverse_match.id) if reverse_match else match.id

    message = crud.create_message(
        db,
        match_id=canonical_match_id,
        sender_id=current_user.id,
        content=msg_data.content,
        image_url=msg_data.image_url,
        video_url=msg_data.video_url,
        gif_url=msg_data.gif_url,
        message_type=msg_data.message_type
    )
    if not message:
        raise HTTPException(status_code=400, detail="Failed to send message")

    sender_profile = crud.get_profile_by_user_id(db, user_id=current_user.id)
    sender_name = f"{sender_profile.name} {sender_profile.last_name or ''}".strip() if sender_profile else "Someone"
    await manager.notify_new_message(
        recipient_id=other_user_id,
        sender_id=current_user.id,
        sender_name=sender_name,
        content=msg_data.content
    )

    # Update behavior profile after sending message
    try:
        from .behavior_updater import update_behavior_profile
        update_behavior_profile(db, current_user.id)
    except Exception as e:
        logging.debug(f"Behavior profile update after message failed: {e}")

    return message


@app.patch("/api/messages/{match_id}/read", status_code=status.HTTP_204_NO_CONTENT, summary="Mark messages as read")
def mark_read(
    match_id: int,
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    crud.mark_messages_read(db, match_id=match_id, user_id=current_user.id)


@app.delete("/api/messages/{match_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Delete all messages for a match")
def delete_chat(
    match_id: int,
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    success = crud.delete_chat_messages(db, match_id=match_id, user_id=current_user.id)
    if not success:
        raise HTTPException(status_code=404, detail="Match not found or not authorized")


@app.delete("/api/messages/message/{message_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Delete a single message")
def delete_single_message(
    message_id: int,
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    message = crud.delete_single_message(db, message_id=message_id, user_id=current_user.id)
    if not message:
        raise HTTPException(status_code=404, detail="Message not found or not authorized")


@app.patch("/api/messages/message/{message_id}", response_model=schemas.MessageResponse, summary="Edit a message")
def edit_message(
    message_id: int,
    edit_data: schemas.MessageEdit,
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    message = crud.edit_message(db, message_id=message_id, user_id=current_user.id, new_content=edit_data.content)
    if not message:
        raise HTTPException(status_code=404, detail="Message not found or not authorized")
    return message


@app.post("/api/messages/message/{message_id}/forward", response_model=schemas.MessageResponse, summary="Forward a message to another match")
def forward_message(
    message_id: int,
    forward_data: schemas.MessageForward,
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    original = db.query(models.Message).filter(models.Message.id == message_id).first()
    if not original:
        raise HTTPException(status_code=404, detail="Message not found")

    target_match = db.query(models.Match).filter(models.Match.id == forward_data.target_match_id).first()
    if not target_match:
        raise HTTPException(status_code=404, detail="Target match not found")
    if target_match.user_id != current_user.id and target_match.matched_user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not part of this match")

    message = crud.create_message(
        db,
        match_id=forward_data.target_match_id,
        sender_id=current_user.id,
        content=original.content,
        image_url=original.image_url,
        video_url=original.video_url,
        gif_url=original.gif_url,
        message_type=original.message_type
    )
    if not message:
        raise HTTPException(status_code=400, detail="Failed to forward message")
    return message


@app.post("/api/chat/media", summary="Upload chat media (image/video)")
async def upload_chat_media(
    file: UploadFile = File(...),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    allowed_image_types = ["image/jpeg", "image/png", "image/gif", "image/webp"]
    allowed_video_types = ["video/mp4", "video/quicktime", "video/webm"]
    max_image_size = 10 * 1024 * 1024
    max_video_size = 50 * 1024 * 1024

    if file.content_type in allowed_image_types:
        media_type = "image"
        max_size = max_image_size
    elif file.content_type in allowed_video_types:
        media_type = "video"
        max_size = max_video_size
    else:
        raise HTTPException(status_code=400, detail="Unsupported file type. Use JPEG, PNG, GIF, WebP for images or MP4, MOV, WebM for videos.")

    contents = await file.read()
    if len(contents) > max_size:
        raise HTTPException(status_code=400, detail=f"File too large. Max size: {max_size // (1024 * 1024)}MB")

    upload_dir = os.path.join("uploads", "chat_media")
    os.makedirs(upload_dir, exist_ok=True)

    file_ext = file.filename.split(".")[-1] if file.filename else "bin"
    filename = f"{current_user.id}_{secrets.token_hex(16)}.{file_ext}"
    filepath = os.path.join(upload_dir, filename)

    with open(filepath, "wb") as f:
        f.write(contents)

    return {
        "url": f"/api/chat/media/{filename}",
        "media_type": media_type,
        "filename": filename
    }


@app.get("/api/chat/media/{filename}", summary="Get chat media file")
async def get_chat_media(filename: str):
    filepath = os.path.join("uploads", "chat_media", filename)
    if not os.path.exists(filepath):
        raise HTTPException(status_code=404, detail="Media not found")

    ext = filename.split(".")[-1].lower()
    content_type_map = {
        "jpg": "image/jpeg", "jpeg": "image/jpeg", "png": "image/png",
        "gif": "image/gif", "webp": "image/webp",
        "mp4": "video/mp4", "mov": "video/quicktime", "webm": "video/webm",
    }
    content_type = content_type_map.get(ext, "application/octet-stream")

    with open(filepath, "rb") as f:
        contents = f.read()
    return Response(content=contents, media_type=content_type)


@app.get("/api/chats", response_model=List[schemas.ChatListResponse], summary="Get chat list (mutual matches)")
def get_chat_list(
    mode: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    if mode:
        return crud.get_chat_list_by_mode(db, user_id=current_user.id, mode=mode)
    return crud.get_chat_list(db, user_id=current_user.id)


# ============================================================
# LIKES ENDPOINTS
# ============================================================

@app.get("/api/likes/received", response_model=List[schemas.ReceivedLikeResponse], summary="Get incoming likes (people who liked you)")
def get_received_likes(
    mode: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    if mode:
        return crud.get_received_likes_by_mode(db, user_id=current_user.id, mode=mode)
    return crud.get_received_likes(db, user_id=current_user.id)


@app.post("/api/likes/{match_id}/accept", response_model=schemas.MatchResponse, summary="Accept an incoming like")
def accept_incoming_like(
    match_id: int,
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    result = crud.accept_incoming_like(db, match_id=match_id, user_id=current_user.id)
    if not result:
        raise HTTPException(status_code=404, detail="Like not found")
    return result


@app.post("/api/likes/{match_id}/decline", status_code=status.HTTP_204_NO_CONTENT, summary="Decline an incoming like")
def decline_incoming_like(
    match_id: int,
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    success = crud.decline_incoming_like(db, match_id=match_id, user_id=current_user.id)
    if not success:
        raise HTTPException(status_code=404, detail="Like not found")


# ============================================================
# BEHAVIOR PROFILE ENDPOINTS
# ============================================================

@app.get("/api/users/me/behavior-profile", summary="Get your behavioral profile")
def get_behavior_profile(
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    """Get the current user's behavioral profile derived from their actions."""
    from .behavior_updater import get_or_create_behavior_profile

    profile = get_or_create_behavior_profile(db, current_user.id)
    return {
        "user_id": profile.user_id,
        "selectivity": profile.selectivity,
        "avg_profiles_per_session": profile.avg_profiles_per_session,
        "avg_response_time_minutes": profile.avg_response_time_minutes,
        "avg_message_length": profile.avg_message_length,
        "conversation_depth": profile.conversation_depth,
        "initiator_ratio": profile.initiator_ratio,
        "sessions_per_week": profile.sessions_per_week,
        "avg_session_minutes": profile.avg_session_minutes,
        "peak_hour": profile.peak_hour,
        "openness_behavioral": profile.openness_behavioral,
        "conscientiousness_behavioral": profile.conscientiousness_behavioral,
        "extraversion_behavioral": profile.extraversion_behavioral,
        "agreeableness_behavioral": profile.agreeableness_behavioral,
        "emotional_stability_behavioral": profile.emotional_stability_behavioral,
        "computed_at": profile.computed_at.isoformat() if profile.computed_at else None,
    }


@app.post("/api/users/me/behavior-profile/refresh", summary="Force refresh your behavioral profile")
def refresh_behavior_profile(
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    """Force recalculation of the behavioral profile from all available data."""
    from .behavior_updater import update_behavior_profile

    profile = update_behavior_profile(db, current_user.id)
    return {
        "status": "refreshed",
        "computed_at": profile.computed_at.isoformat() if profile.computed_at else None,
    }


@app.get("/api/behavioral-compatibility/{other_user_id}", summary="Get behavioral compatibility with another user")
def get_behavioral_compatibility(
    other_user_id: int,
    mode: str = "dating",
    db: Session = Depends(get_db),
    current_user: models.SynoUser = Depends(get_current_active_user)
):
    """Get behavioral compatibility score and reasons with another user."""
    from .behavior_updater import get_or_create_behavior_profile
    from .behavioral_scorer import calculate_behavioral_compatibility, generate_behavioral_reasons

    behavior_a = get_or_create_behavior_profile(db, current_user.id)
    behavior_b = get_or_create_behavior_profile(db, other_user_id)

    score = calculate_behavioral_compatibility(behavior_a, behavior_b, mode=mode)
    reasons = generate_behavioral_reasons(behavior_a, behavior_b, score, mode)

    return {
        "behavioral_score": round(score),
        "reasons": reasons,
        "mode": mode,
    }
