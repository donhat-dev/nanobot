---
applyTo: "tests/**"
description: "USE WHEN writing or modifying tests. Covers test structure, pytest conventions, and async testing patterns."
---

# Testing

## Commands

```bash
pytest                  # All tests
pytest tests/unit/      # Unit tests only
pytest -x               # Stop on first failure
pytest -k "test_name"   # Run specific test
```

## Conventions

- Framework: `pytest` with `pytest-asyncio` (auto mode — no `@pytest.mark.asyncio` needed)
- Async tests: just use `async def test_...()` — the plugin handles it
- Fixtures: prefer `conftest.py` at appropriate directory level
- Mocking: use `unittest.mock` / `pytest-mock`; mock at the boundary, not internals
- Test files mirror source structure: `tests/unit/agent/test_loop.py` ↔ `nanobot/agent/loop.py`
- Coverage: `pytest-cov` available, run with `pytest --cov=nanobot`

## Style

- Test names: `test_{what}_{scenario}` (e.g., `test_tool_registry_register_duplicate`)
- Keep tests small and focused — one assertion per behavior
- Use factories/fixtures over complex setup in test bodies
