import pytest
import json
from sqlalchemy import text
from fastapi.testclient import TestClient
from app import schemas

pytestmark = pytest.mark.integration

# ---------------------------
# Fixture to seed the database
# ---------------------------
@pytest.fixture
def seed_db(db_session):
    """
    Seed the database with required static data for integration tests.
    """
    db_session.execute(text("INSERT INTO sexes (id, name) VALUES (1, 'Male')"))
    db_session.execute(text("INSERT INTO sexes (id, name) VALUES (2, 'Female')"))

    db_session.execute(text("INSERT INTO orientations (id, name) VALUES (1, 'Straight')"))
    db_session.execute(text("INSERT INTO orientations (id, name) VALUES (2, 'Gay')"))
    db_session.execute(text("INSERT INTO orientations (id, name) VALUES (3, 'Bisexual')"))

    db_session.execute(text("INSERT INTO hobbies (id, name) VALUES (1, 'Reading')"))
    db_session.execute(text("INSERT INTO hobbies (id, name) VALUES (2, 'Traveling')"))
    db_session.execute(text("INSERT INTO hobbies (id, name) VALUES (3, 'Cooking')"))

    # Seed Professions and Educations
    db_session.execute(text("INSERT INTO professions (id, name) VALUES (1, 'Engineer')"))
    db_session.execute(text("INSERT INTO educations (id, name) VALUES (1, 'MSc')"))

    db_session.commit()
    yield
    db_session.execute(text("DELETE FROM hobbies"))
    db_session.execute(text("DELETE FROM orientations"))
    db_session.execute(text("DELETE FROM sexes"))
    db_session.execute(text("DELETE FROM professions"))
    db_session.execute(text("DELETE FROM educations"))
    db_session.commit()


def test_full_user_lifecycle(client: TestClient, seed_db):
    """
    Test full user lifecycle: register -> login -> create profile -> block -> deactivate.
    """
    # --- Register User 1 ---
    reg_res1 = client.post("/api/auth/register", json={"email": "user1@example.com", "password": "password123"})
    assert reg_res1.status_code in [200, 201]

    login_res1 = client.post("/api/auth/login", json={"email": "user1@example.com", "password": "password123"})
    assert login_res1.status_code == 200
    token1 = login_res1.json()["access_token"]
    headers1 = {"Authorization": f"Bearer {token1}"}

    # --- Register User 2 ---
    reg_res2 = client.post("/api/auth/register", json={"email": "user2@example.com", "password": "password456"})
    assert reg_res2.status_code in [200, 201]

    login_res2 = client.post("/api/auth/login", json={"email": "user2@example.com", "password": "password456"})
    assert login_res2.status_code == 200
    token2 = login_res2.json()["access_token"]
    headers2 = {"Authorization": f"Bearer {token2}"}

    # --- User 1 creates a profile ---
    # Note: The API expects multipart/form-data for profile creation/update
    profile_data1 = {
        "name": "User One",
        "birth_date": "1990-01-01",
        "birth_time": "",
        "location_id": 1,
        "sex_id": 1,
        "orientation_id": 1,
        "intention": "gdfgdfg",
        "core_values": json.dumps(["fgdfg"]),
        "bio": "A short bio about User One.",
        "hobby_ids": json.dumps([1, 2]),
        "last_name": "Smith",
        "profession_ids": json.dumps([1]),
        "education_ids": json.dumps([1]),
        "interests": json.dumps(["Coding", "Reading"]),
        "height": 180,
        "additional_photos": json.dumps(["http://example.com/1.jpg"])
    }

    # We need to send a file for the primary photo to create a profile
    files = {
        "primary_photo": ("test.jpg", b"fake image data", "image/jpeg")
    }

    profile_res1 = client.patch("/api/users/me", data=profile_data1, files=files, headers=headers1)
    print("User 1 profile creation status:", profile_res1.status_code)
    try:
        print("User 1 profile creation response:", profile_res1.json())
    except Exception:
        print("User 1 profile creation response content:", profile_res1.text)
    assert profile_res1.status_code == 200
    user1_id = profile_res1.json().get("user_id") or profile_res1.json().get("id")
    assert user1_id is not None, "User 1 ID not found after profile creation"

    # --- User 2 creates a profile ---
    profile_data2 = {
        "name": "User Two",
        "last_name": "Doe",
        "birth_date": "1992-02-02",
        "birth_time": "",
        "location_id":1,
        "sex_id": 2,
        "orientation_id": 1,
        "intention": "testing",
        "core_values": json.dumps(["value2"]),
        "bio": "string",
        "hobby_ids": json.dumps([2, 3])
    }

    files2 = {"primary_photo": ("test2.jpg", b"fake image data", "image/jpeg")}
    profile_res2 = client.patch("/api/users/me", data=profile_data2, files=files2, headers=headers2)
    print("User 2 profile creation status:", profile_res2.status_code)
    try:
        print("User 2 profile creation response:", profile_res2.json())
    except Exception:
        print("User 2 profile creation response content:", profile_res2.text)
    assert profile_res2.status_code == 200
    user2_id = profile_res2.json().get("user_id") or profile_res2.json().get("id")
    assert user2_id is not None, "User 2 ID not found after profile creation"

    # --- Verify User 1 profile ---
    profile1 = profile_res1.json()
    assert profile1["name"] == "User One"
    assert profile1["sex"]["name"] == "Male"
    assert profile1["last_name"] == "Smith"
    assert profile1["height"] == 180
    assert profile1["profession"][0]["name"] == "Engineer"
    assert profile1["education"][0]["name"] == "MSc"

    # --- User 1 tries to block themselves (should fail) ---
    block_self_res = client.post(f"/api/users/{user1_id}/block", headers=headers1)
    assert block_self_res.status_code == 404

    # --- User 1 blocks User 2 ---
    block_res = client.post(f"/api/users/{user2_id}/block", headers=headers1)
    assert block_res.status_code == 204

    # --- User 1 unblocks User 2 ---
    unblock_res = client.delete(f"/api/users/{user2_id}/unblock", headers=headers1)
    assert unblock_res.status_code == 204

    # --- User 1 deactivates their account (soft-delete) ---
    delete_res = client.delete("/api/users/me", headers=headers1)
    assert delete_res.status_code == 204

    # --- Verify User 1 can no longer access protected endpoints (deactivated = 403) ---
    profile_res_after_delete = client.get("/api/users/me", headers=headers1)
    assert profile_res_after_delete.status_code == 403

    # --- Verify User 1 cannot login with password (deactivated = 403) ---
    login_after_deactivate = client.post("/api/auth/login", json={"email": "user1@example.com", "password": "password123"})
    assert login_after_deactivate.status_code == 403

    # --- User 1 requests reactivation ---
    reactivation_res = client.post("/api/auth/request-reactivation", json={"email": "user1@example.com"})
    assert reactivation_res.status_code == 200

    # --- Verify User 1 still cannot login before reactivation ---
    login_before_reactivate = client.post("/api/auth/login", json={"email": "user1@example.com", "password": "password123"})
    assert login_before_reactivate.status_code == 403
