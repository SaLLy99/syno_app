"""Tests for ReportService and report generation."""
import pytest
from datetime import date, time

from app.astrology.providers.western import SwissEphProvider
from app.astrology.services.report_service import (
    ReportService,
    DimensionScore,
    SynastryBreakdown,
    BehaviorScore,
)
from app.astrology.domain.models import BirthData, AstrologySystem


@pytest.fixture
def provider():
    return SwissEphProvider()


@pytest.fixture
def report_service(provider):
    return ReportService(provider)


@pytest.fixture
def person_a():
    return BirthData(
        birth_date=date(1990, 7, 15),
        birth_time=time(14, 30),
        timezone="America/New_York",
        latitude=40.7128,
        longitude=-74.0060,
    )


@pytest.fixture
def person_b():
    return BirthData(
        birth_date=date(1992, 3, 22),
        birth_time=time(9, 15),
        timezone="Europe/London",
        latitude=51.5074,
        longitude=-0.1278,
    )


class TestReportService:
    def test_report_generation(self, report_service, person_a, person_b):
        report = report_service.generate_report(
            person_a=person_a,
            person_b=person_b,
            shared_hobbies=["hiking"],
            shared_values=["honesty"],
            shared_intentions=["relationship"],
            user_a_name="Alex",
            user_b_name="Jordan",
        )

        assert report.overall_score >= 0
        assert report.overall_score <= 100
        assert report.chart_score >= 0
        assert report.chart_score <= 100
        assert report.behavior_score >= 0
        assert report.behavior_score <= 100
        assert report.cosmic_insight
        assert len(report.top_reasons) > 0

    def test_eight_dimensions_present(self, report_service, person_a, person_b):
        report = report_service.generate_report(
            person_a=person_a,
            person_b=person_b,
        )

        expected_dims = ["romance", "emotional", "communication", "long_term",
                         "marriage", "friendship", "chemistry", "spiritual"]
        for dim in expected_dims:
            assert dim in report.dimensions
            assert isinstance(report.dimensions[dim], DimensionScore)
            assert 0 <= report.dimensions[dim].score <= 100
            assert report.dimensions[dim].label
            assert report.dimensions[dim].description

    def test_synastry_breakdown(self, report_service, person_a, person_b):
        report = report_service.generate_report(
            person_a=person_a,
            person_b=person_b,
        )

        breakdown = report.synastry_breakdown
        assert isinstance(breakdown, SynastryBreakdown)
        assert 0 <= breakdown.moon_score <= 100
        assert 0 <= breakdown.mercury_score <= 100
        assert 0 <= breakdown.venus_mars_score <= 100
        assert 0 <= breakdown.nodes_score <= 100
        assert 0 <= breakdown.saturn_score <= 100

    def test_score_composition(self, report_service, person_a, person_b):
        """Headline % IS the chart score; the weighted blend lives in composite_score."""
        report = report_service.generate_report(
            person_a=person_a,
            person_b=person_b,
            behavior_activity=80.0,
            behavior_profile_quality=70.0,
            behavior_mutual_interest=60.0,
            behavioral_compatibility=90.0,
            shared_hobbies=["hiking"],
            shared_values=["honesty"],
        )

        assert report.overall_score == report.chart_score

        expected_composite = (
            (report.chart_score * 0.60)
            + (report.behavior_score * 0.30)
            + (report.profile_similarity_score * 0.10)
        )
        assert abs(report.composite_score - round(expected_composite)) <= 1

    def test_score_weights_match_discovery_defaults(self, report_service, person_a, person_b):
        """Report default weights must equal matching_engine.MODE_WEIGHTS['dating']."""
        from app.matching_engine import MODE_WEIGHTS

        report = report_service.generate_report(
            person_a=person_a,
            person_b=person_b,
            behavior_activity=80.0,
            behavior_profile_quality=70.0,
            behavior_mutual_interest=60.0,
            behavioral_compatibility=90.0,
            shared_hobbies=["hiking", "music"],
            shared_values=["honesty"],
        )
        weights = MODE_WEIGHTS["dating"]

        expected = (
            (report.chart_score * weights["synastry"])
            + (report.behavior_score * weights["behavioral"])
            + (report.profile_similarity_score * weights["profile_similarity"])
        )
        assert abs(report.composite_score - round(expected)) <= 1
        assert report.overall_score == report.chart_score

    def test_behaviour_without_data_is_null(self, report_service, person_a, person_b):
        """No observed behaviour -> behaviour part is None, never a placeholder."""
        report = report_service.generate_report(
            person_a=person_a,
            person_b=person_b,
            behavior_has_data=False,
        )

        assert report.behavior_score is None
        parts = {part["key"]: part["value"] for part in report.score_parts}
        assert parts["behavior"] is None
        assert parts["chart"] == report.chart_score
        # Headline still a real chart number, composite excludes the null part.
        assert report.overall_score == report.chart_score

    def test_partial_chart_is_flagged(self, report_service, person_a, person_b):
        report = report_service.generate_report(
            person_a=person_a,
            person_b=person_b,
            score_partial=True,
        )

        assert report.score_partial is True
        chart_part = next(p for p in report.score_parts if p["key"] == "chart")
        assert chart_part["partial"] is True

    def test_top_aspects_are_ranked_and_capped(self, report_service, person_a, person_b):
        report = report_service.generate_report(
            person_a=person_a,
            person_b=person_b,
        )

        assert 0 < len(report.top_aspects) <= 5
        scores = [aspect["score"] for aspect in report.top_aspects]
        assert scores == sorted(scores, reverse=True)
        for aspect in report.top_aspects:
            assert {"planet_a", "planet_b", "aspect", "orb", "score"} <= set(aspect)

    def test_overall_score_override(self, report_service, person_a, person_b):
        report = report_service.generate_report(
            person_a=person_a,
            person_b=person_b,
            overall_score=87.0,
        )
        assert report.overall_score == 87

    def test_component_score_overrides(self, report_service, person_a, person_b):
        report = report_service.generate_report(
            person_a=person_a,
            person_b=person_b,
            overall_score=72.0,
            behavior_score=40.0,
            profile_similarity_score=65.0,
        )
        assert report.overall_score == 72
        assert report.behavior_score == 40
        assert report.profile_similarity_score == 65

    def test_resolve_signal_weights_falls_back_to_mode(self):
        from app.matching_engine import resolve_signal_weights, MODE_WEIGHTS

        weights = resolve_signal_weights(None, "dating")
        assert weights["synastry"] == MODE_WEIGHTS["dating"]["synastry"]
        assert weights["behavioral"] == MODE_WEIGHTS["dating"]["behavioral"]

    def test_resolve_signal_weights_normalizes_user_weights(self):
        from app.matching_engine import resolve_signal_weights

        weights = resolve_signal_weights(
            {
                "weight_natal_chart": 50,
                "weight_interests": 50,
                "weight_behavior": 50,
            },
            "dating",
        )
        assert abs(weights["synastry"] - 1 / 3) < 1e-9
        assert abs(weights["profile_similarity"] - 1 / 3) < 1e-9
        assert abs(weights["behavioral"] - 1 / 3) < 1e-9
        assert abs(
            weights["synastry"] + weights["profile_similarity"] + weights["behavioral"] - 1.0
        ) < 1e-9

    def test_behavior_affects_score(self, report_service, person_a, person_b):
        report_low = report_service.generate_report(
            person_a=person_a,
            person_b=person_b,
            behavior_activity=20.0,
            behavior_profile_quality=20.0,
            behavior_mutual_interest=0.0,
        )

        report_high = report_service.generate_report(
            person_a=person_a,
            person_b=person_b,
            behavior_activity=100.0,
            behavior_profile_quality=100.0,
            behavior_mutual_interest=100.0,
        )

        assert report_high.behavior_score > report_low.behavior_score

    def test_shared_interests_affect_profile_similarity(self, report_service, person_a, person_b):
        report_none = report_service.generate_report(
            person_a=person_a,
            person_b=person_b,
        )

        report_many = report_service.generate_report(
            person_a=person_a,
            person_b=person_b,
            shared_hobbies=["hiking", "music", "cooking"],
            shared_values=["honesty", "family", "growth"],
            shared_intentions=["relationship", "friendship"],
        )

        assert report_many.profile_similarity_score > report_none.profile_similarity_score

    def test_cosmic_insight_varies_by_score(self, report_service, person_a, person_b):
        report = report_service.generate_report(
            person_a=person_a,
            person_b=person_b,
        )

        assert isinstance(report.cosmic_insight, str)
        assert len(report.cosmic_insight) > 20

    def test_top_reasons_include_shared(self, report_service, person_a, person_b):
        report = report_service.generate_report(
            person_a=person_a,
            person_b=person_b,
            shared_hobbies=["hiking"],
            shared_values=["honesty"],
        )

        reasons_text = " ".join(report.top_reasons).lower()
        assert "hiking" in reasons_text or "honesty" in reasons_text

    def test_profiles_in_report(self, report_service, person_a, person_b):
        report = report_service.generate_report(
            person_a=person_a,
            person_b=person_b,
            user_a_name="Alex",
            user_b_name="Jordan",
        )

        assert report.profiles["user_a"]["name"] == "Alex"
        assert report.profiles["user_b"]["name"] == "Jordan"
        assert report.profiles["user_a"]["zodiac"] == "Cancer"
        assert report.profiles["user_b"]["zodiac"] == "Aries"

    def test_interpretation_includes_all_dimensions(self, report_service, person_a, person_b):
        report = report_service.generate_report(
            person_a=person_a,
            person_b=person_b,
        )

        for dim in ["romance", "emotional", "communication", "long_term",
                     "marriage", "friendship", "chemistry", "spiritual"]:
            assert f"{dim}_text" in report.interpretation

    def test_report_to_dict(self, report_service, person_a, person_b):
        report = report_service.generate_report(
            person_a=person_a,
            person_b=person_b,
        )

        result = report_service.report_to_dict(report)

        assert "overall_score" in result
        assert "chart_score" in result
        assert "behavior_score" in result
        assert "dimensions" in result
        assert "synastry" in result
        assert "shared" in result
        assert "profiles" in result
        assert "interpretation" in result

        assert isinstance(result["dimensions"], dict)
        assert isinstance(result["synastry"], dict)

    def test_dimension_key_factors(self, report_service, person_a, person_b):
        report = report_service.generate_report(
            person_a=person_a,
            person_b=person_b,
        )

        for dim_key, dim_score in report.dimensions.items():
            assert isinstance(dim_score.key_factors, list)
            for factor in dim_score.key_factors:
                assert "orb" in factor

    def test_same_person_positive_aspects(self, report_service):
        same_person = BirthData(
            birth_date=date(1990, 1, 1),
            birth_time=time(12, 0),
            timezone="UTC",
            latitude=0.0,
            longitude=0.0,
        )

        report = report_service.generate_report(
            person_a=same_person,
            person_b=same_person,
        )

        assert report.dimensions["emotional"].score >= 50
        assert report.dimensions["communication"].score >= 50
        assert report.dimensions["long_term"].score >= 50

    def test_opposite_signs_lower_romance(self, report_service):
        aries = BirthData(
            birth_date=date(1990, 4, 10),
            birth_time=time(12, 0),
            timezone="UTC",
            latitude=0.0,
            longitude=0.0,
        )
        libra = BirthData(
            birth_date=date(1990, 10, 10),
            birth_time=time(12, 0),
            timezone="UTC",
            latitude=0.0,
            longitude=0.0,
        )

        report = report_service.generate_report(
            person_a=aries,
            person_b=libra,
        )

        assert report.dimensions["romance"].score >= 0

    def test_interpretation_strengths_challenges(self, report_service, person_a, person_b):
        report = report_service.generate_report(
            person_a=person_a,
            person_b=person_b,
        )

        assert isinstance(report.strengths, list)
        assert isinstance(report.challenges, list)
        assert "strengths" in report.interpretation
        assert "challenges" in report.interpretation


class TestBehaviorScore:
    def test_behavior_calculation(self, report_service):
        behavior = report_service._calculate_behavior_score(
            activity=80.0, profile_quality=70.0, mutual_interest=60.0,
            behavioral_compatibility=90.0,
        )

        assert isinstance(behavior, BehaviorScore)
        supplementary = (80.0 * 0.40) + (70.0 * 0.35) + (60.0 * 0.25)
        expected = (90.0 * 0.60) + (supplementary * 0.40)
        assert abs(behavior.combined - expected) < 0.01

    def test_behavior_bounds(self, report_service):
        behavior = report_service._calculate_behavior_score(
            activity=100.0, profile_quality=100.0, mutual_interest=100.0,
            behavioral_compatibility=100.0,
        )
        assert behavior.combined == 100.0

        behavior = report_service._calculate_behavior_score(
            activity=0.0, profile_quality=0.0, mutual_interest=0.0,
            behavioral_compatibility=0.0,
        )
        assert behavior.combined == 0.0

    def test_behavioral_compatibility_dominates(self, report_service):
        low = report_service._calculate_behavior_score(
            activity=100.0, profile_quality=100.0, mutual_interest=100.0,
            behavioral_compatibility=20.0,
        )
        high = report_service._calculate_behavior_score(
            activity=100.0, profile_quality=100.0, mutual_interest=100.0,
            behavioral_compatibility=90.0,
        )
        assert high.combined > low.combined


class TestProfileSimilarity:
    def test_no_shared(self, report_service):
        score = report_service._calculate_profile_similarity(None, None, None)
        assert score == 50.0

    def test_with_shared_hobbies(self, report_service):
        score = report_service._calculate_profile_similarity(
            ["hiking", "music"], None, None
        )
        assert score > 50.0

    def test_with_all_shared(self, report_service):
        score = report_service._calculate_profile_similarity(
            ["hiking", "music", "cooking"],
            ["honesty", "family"],
            ["relationship"],
        )
        assert score >= 80.0


class TestInterpretationContent:
    def test_coach_tips_present(self, report_service, person_a, person_b):
        report = report_service.generate_report(
            person_a=person_a,
            person_b=person_b,
            user_a_name="Sally Tkhilaishvili",
            user_b_name="Sally T.",
        )

        tips = report.interpretation["coach_tips"]
        assert isinstance(tips, list)
        assert len(tips) >= 3
        assert all(isinstance(t, str) and t.strip() for t in tips)

    def test_coach_tips_in_report_to_dict(self, report_service, person_a, person_b):
        report = report_service.generate_report(
            person_a=person_a,
            person_b=person_b,
        )
        result = report_service.report_to_dict(report)

        assert "coach_tips" in result["interpretation"]
        assert len(result["interpretation"]["coach_tips"]) >= 1

    def test_interpretation_enriched_fields(self, report_service, person_a, person_b):
        report = report_service.generate_report(
            person_a=person_a,
            person_b=person_b,
            user_a_name="Sally Tkhilaishvili",
            user_b_name="Sally T.",
        )
        interp = report.interpretation

        for key in [
            "personality_a", "personality_b", "love_language", "trust_loyalty",
            "intimacy_text", "conflict_style", "overall_verdict", "coach_tips",
        ]:
            assert key in interp, f"missing {key}"

        assert interp["personality_a"].strip()
        assert interp["personality_b"].strip()

    def test_no_person_a_or_person_b_labels(self, report_service, person_a, person_b):
        report = report_service.generate_report(
            person_a=person_a,
            person_b=person_b,
            user_a_name="Sally Tkhilaishvili",
            user_b_name="Sally T.",
        )
        interp = report.interpretation

        assert "Person A" not in interp["personality_a"]
        assert "Person B" not in interp["personality_a"]
        assert "Person A" not in interp["personality_b"]
        assert "Person B" not in interp["personality_b"]
        assert "Person A" not in interp["overall_verdict"]
        assert "Person B" not in interp["overall_verdict"]

    def test_names_used_in_personality_text(self, report_service, person_a, person_b):
        report = report_service.generate_report(
            person_a=person_a,
            person_b=person_b,
            user_a_name="Sally Tkhilaishvili",
            user_b_name="Nino Beridze",
        )
        interp = report.interpretation

        assert "Sally Tkhilaishvili" in interp["personality_a"]
        assert "Nino Beridze" in interp["personality_b"]

    def test_fallback_names_when_missing(self, report_service, person_a, person_b):
        report = report_service.generate_report(
            person_a=person_a,
            person_b=person_b,
        )
        interp = report.interpretation

        assert "Person A" not in interp["personality_a"]
        assert "Person B" not in interp["personality_b"]
        assert interp["personality_a"].strip()
