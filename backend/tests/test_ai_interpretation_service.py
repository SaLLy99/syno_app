import json

import pytest

from app.astrology.domain.models import InterpretationResult, SynastryResult
from app.astrology.services.ai_interpretation_service import AIInterpretationService


@pytest.fixture
def service(monkeypatch):
    monkeypatch.setenv("GOOGLE_API_KEY", "")
    monkeypatch.delenv("GOOGLE_API_KEY", raising=False)
    svc = AIInterpretationService.__new__(AIInterpretationService)
    svc.model = "gemini-3.6-flash"
    svc.fallback_models = ["gemini-3.5-flash"]
    svc._cache = {}
    svc._chart_cache = {}
    return svc


def test_loads_json_full(service):
    assert service._loads_json('{"a": 1}') == {"a": 1}


def test_loads_json_code_fence(service):
    assert service._loads_json('```json\n{"a": 1}\n```') == {"a": 1}


def test_loads_json_truncated_string(service):
    data = service._loads_json('{\n  "summary": "Unterminated')
    assert data["summary"] == "Unterminated"


def test_loads_json_truncated_mid_object(service):
    data = service._loads_json('{"summary": "ok", "strengths": ["a", "b')
    assert data["summary"] == "ok"
    assert data["strengths"] == ["a", "b"]


def test_loads_json_truncated_after_key(service):
    data = service._loads_json('{"summary":')
    assert data == {"summary": None}


def test_retryable_markers(service):
    assert service._is_retryable_ai_error(Exception("503 Service Unavailable"))
    assert service._is_retryable_ai_error(Exception("UNAVAILABLE: high demand"))
    assert service._is_retryable_ai_error(ValueError("Empty AI response"))
    assert not service._is_retryable_ai_error(Exception("400 invalid argument"))


def test_call_ai_retries_then_succeeds(monkeypatch):
    monkeypatch.delenv("GOOGLE_API_KEY", raising=False)
    svc = AIInterpretationService.__new__(AIInterpretationService)
    svc.model = "gemini-3.6-flash"
    svc.fallback_models = ["gemini-3.5-flash"]
    calls = {"n": 0}

    class FakeModels:
        def generate_content(self, **kwargs):
            calls["n"] += 1
            if calls["n"] < 2:
                raise Exception("503 high demand")
            class R:
                text = '{"ok": true}'
            return R()

    class FakeClient:
        models = FakeModels()

    svc.client = FakeClient()
    monkeypatch.setattr(
        "app.astrology.services.ai_interpretation_service.time.sleep",
        lambda *_: None,
    )
    assert svc._call_ai("hi") == '{"ok": true}'
    assert calls["n"] == 2


def test_call_ai_falls_back_to_secondary_model(monkeypatch):
    monkeypatch.delenv("GOOGLE_API_KEY", raising=False)
    svc = AIInterpretationService.__new__(AIInterpretationService)
    svc.model = "gemini-3.6-flash"
    svc.fallback_models = ["gemini-3.5-flash"]
    seen_models = []

    class FakeModels:
        def generate_content(self, **kwargs):
            seen_models.append(kwargs["model"])
            if kwargs["model"] == "gemini-3.6-flash":
                raise Exception("503 high demand")
            class R:
                text = '{"ok": true}'
            return R()

    class FakeClient:
        models = FakeModels()

    svc.client = FakeClient()
    monkeypatch.setattr(
        "app.astrology.services.ai_interpretation_service.time.sleep",
        lambda *_: None,
    )
    assert svc._call_ai("hi") == '{"ok": true}'
    assert seen_models == [
        "gemini-3.6-flash",
        "gemini-3.6-flash",
        "gemini-3.5-flash",
    ]


def test_call_ai_fails_fast_on_non_retryable(monkeypatch):
    monkeypatch.delenv("GOOGLE_API_KEY", raising=False)
    svc = AIInterpretationService.__new__(AIInterpretationService)
    svc.model = "gemini-3.6-flash"
    svc.fallback_models = ["gemini-3.5-flash"]
    calls = {"n": 0}

    class FakeModels:
        def generate_content(self, **kwargs):
            calls["n"] += 1
            raise Exception("400 API key not valid")

    class FakeClient:
        models = FakeModels()

    svc.client = FakeClient()
    with pytest.raises(Exception, match="400"):
        svc._call_ai("hi")
    assert calls["n"] == 1


def test_quota_error_fails_over_without_delay(monkeypatch):
    monkeypatch.delenv("GOOGLE_API_KEY", raising=False)
    svc = AIInterpretationService.__new__(AIInterpretationService)
    svc.model = "gemini-3.6-flash"
    svc.fallback_models = ["gemini-3.1-flash-lite"]
    seen_models = []
    sleeps = []

    class FakeModels:
        def generate_content(self, **kwargs):
            seen_models.append(kwargs["model"])
            if kwargs["model"] == "gemini-3.6-flash":
                raise Exception("429 RESOURCE_EXHAUSTED quota exceeded")
            class R:
                text = '{"ok": true}'
            return R()

    class FakeClient:
        models = FakeModels()

    svc.client = FakeClient()
    monkeypatch.setattr(
        "app.astrology.services.ai_interpretation_service.time.sleep",
        lambda s: sleeps.append(s),
    )
    assert svc._call_ai("hi") == '{"ok": true}'
    assert seen_models == ["gemini-3.6-flash", "gemini-3.1-flash-lite"]
    assert sleeps == []


def test_synastry_prompt_uses_real_names(service):
    prompt = service._build_synastry_prompt(
        SynastryResult(),
        None,
        person_a_name="Sally Tkhilaishvili",
        person_b_name="Nino Beridze",
    )

    assert "Sally Tkhilaishvili" in prompt
    assert "Nino Beridze" in prompt
    assert "coach_tips" in prompt
    assert "## Sally Tkhilaishvili's Chart" in prompt
    assert "## Nino Beridze's Chart" in prompt
    assert "## Person A Chart" not in prompt
    assert "## Person B Chart" not in prompt
    # The only allowed mentions are the explicit "never use these labels" rule
    assert prompt.count("Person A") <= 1
    assert prompt.count("Person B") <= 1


def test_synastry_prompt_without_names_never_says_person_a(service):
    prompt = service._build_synastry_prompt(SynastryResult(), None)

    assert "## Person A Chart" not in prompt
    assert "## Person B Chart" not in prompt
    assert prompt.count("Person A") <= 1
    assert prompt.count("Person B") <= 1
    assert "Partner One" in prompt


def test_parse_synastry_response_reads_coach_tips(service):
    payload = {
        "summary": "s",
        "strengths": ["a"],
        "challenges": ["b"],
        "communication": "c",
        "emotional_dynamic": "e",
        "values": "v",
        "growth_dynamic": "g",
        "personality_a": "pa",
        "personality_b": "pb",
        "love_language": "ll",
        "trust_loyalty": "tl",
        "intimacy_text": "it",
        "conflict_style": "cs",
        "overall_verdict": "ov",
        "coach_tips": [
            "Schedule a weekly check-in.",
            "Alternate who plans date night.",
            "Repair with a shared joke after conflict.",
        ],
    }

    result = service._parse_synastry_response(json.dumps(payload))

    assert isinstance(result, InterpretationResult)
    assert len(result.coach_tips) == 3
    assert result.coach_tips[0] == "Schedule a weekly check-in."


def test_parse_synastry_response_missing_coach_tips_defaults_empty(service):
    result = service._parse_synastry_response(json.dumps({"summary": "only"}))

    assert result.coach_tips == []


def test_cache_key_differs_by_names(service):
    key_a = service._make_cache_key("syn", "dims", "Sally", "Nino")
    key_b = service._make_cache_key("syn", "dims", "Sally", "Mariam")
    key_none = service._make_cache_key("syn", "dims", "", "")

    assert key_a != key_b
    assert key_a != key_none

