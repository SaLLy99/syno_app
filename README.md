# SYNO — Astrology-Enhanced AI Dating App

SYNO is a minimalist cosmic dating application that bridges ancient astrological wisdom with modern AI behavioral analysis. It calculates compatibility through natal chart synastry and interaction patterns to help users find their "Cosmic Match."

## 🌌 Overview

SYNO follows a **Clean Architecture** pattern, ensuring a separation of concerns between the business logic, data management, and the user interface.

### Key Features
- **Synastry Engine:** Real-time calculation of compatibility across Moon (emotions), Mercury (communication), Venus/Mars (romance), Nodes (karma), and Saturn (stability).
- **Behavioral AI:** Analyzes personality questionnaires to refine matching beyond planetary alignments.
- **Dynamic Theming:** Custom "Deep Space," "Starlight," and "Nebula" themes that persist across devices.
- **Bilingual Support:** Full support for English, Russian, and Georgian via `easy_localization`.

---

## 🚀 Tech Stack

### Frontend (Flutter)
- **State Management:** Riverpod (Functional Providers & StateNotifiers)
- **Navigation:** GoRouter with Auth Guards
- **Networking:** Dio with Interceptors for token handling
- **Localization:** Easy Localization

### Backend (Python/FastAPI)
- **Framework:** FastAPI
- **ORM:** SQLAlchemy with PostgreSQL (or SQLite for local dev)
- **Authentication:** OAuth2 with JWT (JSON Web Tokens)
- **Data Validation:** Pydantic models

---

## 🛠️ Getting Started

### Prerequisites
- Flutter SDK (Stable)
- Python 3.9+
- Node.js (if using specific astrological CLI tools)

### Backend Setup
1. Navigate to the backend directory:
   ```bash
   cd backend
   ```
2. Create and activate a virtual environment:
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```
3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
4. Run the server:
   ```bash
   uvicorn app.main:app --reload
   ```

### Frontend Setup
1. Navigate to the flutter directory:
   ```bash
   cd flutter
   ```
2. Install Flutter packages:
   ```bash
   flutter pub get
   ```
3. Create a `.env` file in `assets/env/` based on `.env.example`:
   ```env
   BACKEND_URL=http://localhost:8000
   ```
4. Run the app:
   ```bash
   flutter run
   ```

## 📝 License
Copyright © 2024 SYNO Startup. All rights reserved.