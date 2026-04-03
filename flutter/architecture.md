# SYNO – Astrology-Enhanced AI Dating App Architecture

## Overview
SYNO is a minimalist cosmic dating app that combines Synastry (natal chart compatibility) with Behavioral AI to create a hybrid matching system. The app features a clean, modern UI with gradient purples/pinks/blues and follows Clean Architecture principles with Riverpod for state management.

## Brand Identity
- **Taglines**: "Your Cosmic Match" / "Meet Who You Are Meant To"
- **Design**: Minimalist cosmic aesthetic with gradient purples/pinks/blues
- **Font**: Rounded modern font (Outfit)
- **Reference**: Similar UX to Karma dating app

## Architecture Layers

### 1. Presentation Layer (`lib/presentation/`)
- **Screens**:
  - `onboarding/` - Birth data capture, preferences, personality questionnaire
  - `discover/` - Swipeable/scrollable cards with mini-score preview
  - `match_details/` - Full match card with score breakdown
  - `synastry_report/` - Detailed astrological compatibility report
  - `chat/` - Messaging with match card header
  - `profile/` - User profile management
  
- **Widgets**: Reusable components (CosmicGradientCard, MatchScoreWidget, etc.)

### 2. Domain Layer (`lib/domain/`)
- **Entities**: Core business models (User, Match, SynastryData, etc.)
- **Repositories**: Abstract interfaces for data operations
- **Use Cases**: Business logic encapsulation

### 3. Data Layer (`lib/data/`)
- **DTOs**: Data transfer objects for API/storage mapping
- **Repositories**: Concrete implementations
- **Services**: 
  - `SynastryCalculator` - Natal chart aspect calculations
  - `BehavioralAIService` - Questionnaire & interaction analysis
  - `WeightingEngine` - Configurable score blending
  - `ExplanationGenerator` - Human-readable match reasons

## Core Features

### Matching Engine
1. **Synastry Calculator**:
   - Moon (emotional compatibility)
   - Mercury (communication style)
   - Venus/Mars (attraction & romance)
   - Nodes (karmic connection)
   - Saturn (long-term stability)
   - Outputs: individual scores (0-100) for each aspect

2. **Behavioral AI Service**:
   - Personality questionnaire analysis
   - Interaction pattern clustering
   - Preference matching
   - Outputs: behavioral compatibility score (0-100)

3. **Weighting Engine**:
   - Configurable weights for synastry vs behavioral
   - Default: 60% synastry, 40% behavioral
   - Final score: 0-100

4. **Explanation Generator**:
   - Top 5 compatibility reasons
   - Synastry highlights
   - "Cosmic Insight" tagline
   - Red flags / challenges (optional premium)

### Data Models

**User**
```dart
- id, name, birthDate, birthTime, birthLocation
- photos, bio, preferences
- personalityTraits (questionnaire results)
- createdAt, updatedAt
```

**Match**
```dart
- id, userId, matchedUserId
- finalScore (0-100)
- synastryScore, behavioralScore
- topReasons (List<String>)
- cosmicInsight (String)
- synastryData (SynastryData)
- status (pending/accepted/declined)
- createdAt
```

**SynastryData**
```dart
- moonScore, mercuryScore, venusMarsScore
- nodesScore, saturnScore
- detailedAspects (List<Aspect>)
- interpretation (String)
```

**ChatMessage**
```dart
- id, matchId, senderId, content
- timestamp, isRead
```

## Services Architecture

### MatchingEngine (Abstract)
```dart
abstract class MatchingEngine {
  Future<Match> calculateMatch(User user1, User user2);
  Future<List<Match>> findPotentialMatches(User user);
}
```

### Implementation Services
- `SynastryCalculatorService` - Implements astrological calculations (mock with realistic data)
- `BehavioralAIService` - Implements personality & preference matching (mock)
- `WeightingEngineService` - Blends scores based on configuration
- `ExplanationGeneratorService` - Generates human-readable insights

### Repository Pattern
- `UserRepository` - User CRUD operations
- `MatchRepository` - Match data management
- `ChatRepository` - Message operations
- All backed by local storage (SharedPreferences + local JSON)

## MVP Screens

1. **Onboarding Flow**
   - Welcome splash with cosmic animation
   - Birth data input (date, time, location)
   - Preference selection (age, distance, gender)
   - Personality questionnaire (15-20 questions)
   - Photo upload

2. **Discover Screen**
   - Swipeable cards with gradient backgrounds
   - Mini-score badge (0-100)
   - Quick cosmic insight preview
   - Photo gallery, name, age, distance

3. **Match Details Screen**
   - Large profile image with gradient overlay
   - Final compatibility score (prominent)
   - Top 5 reasons for match
   - Synastry highlights
   - "Cosmic Insight" quote
   - CTA buttons (Message, View Full Report)

4. **Full Synastry Report Screen**
   - Detailed breakdown by planet/aspect
   - Visual score bars for each category
   - Interpretations for each aspect
   - Overall compatibility summary
   - Challenges & growth areas

5. **Chat Screen**
   - Match card at top (mini version)
   - Standard message interface
   - Cosmic-themed message bubbles

6. **Profile Screen**
   - User photos & bio
   - Birth chart visualization (simplified)
   - Edit preferences & questionnaire

## Mock Data Strategy
- 5-10 demo users with realistic profiles
- Pre-calculated synastry scores based on birth data patterns
- Varied personality traits for behavioral matching
- Sample messages for chat demo
- All stored in local services with JSON serialization

## Technical Stack
- **State Management**: Riverpod (Provider pattern)
- **Navigation**: go_router
- **Storage**: shared_preferences + local JSON
- **UI**: Custom widgets (no Material Design), cosmic gradients
- **Fonts**: Outfit (rounded modern), via google_fonts
- **Architecture**: Clean Architecture (domain/data/presentation)

## Integration Points (For Future)
- `SynastryCalculator`: Replace with real astrology API (e.g., AstroAPI)
- `BehavioralAI`: Integrate ML model or OpenAI embeddings
- `Storage`: Migrate to Firebase/Supabase for backend
- `Payments`: Add premium features (full reports, advanced filters)

## Deliverables
1. Complete Flutter project with clean architecture
2. All MVP screens implemented with cosmic UI
3. Mock services with realistic demo data
4. Repository pattern with local storage
5. Documentation for integration points
6. Compilation-ready, error-free codebase
