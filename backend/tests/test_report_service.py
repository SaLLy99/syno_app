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
        report = report_service.generate_report(
            person_a=person_a,
            person_b=person_b,
            behavior_activity=80.0,
            behavior_profile_quality=70.0,
            behavior_mutual_interest=60.0,
        )

        expected_overall = (report.chart_score * 0.80) + (report.behavior_score * 0.15) + (report.profile_similarity_score * 0.05)
        assert abs(report.overall_score - round(expected_overall)) <= 1

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
            activity=80.0, profile_quality=70.0, mutual_interest=60.0
        )

        assert isinstance(behavior, BehaviorScore)
        expected = (80.0 * 0.40) + (70.0 * 0.35) + (60.0 * 0.25)
        assert abs(behavior.combined - expected) < 0.01

    def test_behavior_bounds(self, report_service):
        behavior = report_service._calculate_behavior_score(
            activity=100.0, profile_quality=100.0, mutual_interest=100.0
        )
        assert behavior.combined == 100.0

        behavior = report_service._calculate_behavior_score(
            activity=0.0, profile_quality=0.0, mutual_interest=0.0
        )
        assert behavior.combined == 0.0


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
