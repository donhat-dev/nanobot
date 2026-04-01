# Nanobot — Workspace Instructions

Ultra-lightweight personal AI assistant (~98% Python). Async-first, minimal abstractions, explicit module boundaries.

## Product Direction

Evolving into a **mini agent OS for chat automation**: easy to add custom tools, custom chat behaviors, reload/swap plugins, and experiment with self-improving tool loops — while keeping the core small and readable.

## Architecture

```
nanobot/
├── agent/           # Core agent logic
│   ├── loop.py      # AgentLoop: message intake → context build → LLM ↔ tool loop
│   ├── runner.py    # AgentRunner: stateless LLM↔tool iteration engine
│   ├── context.py   # System prompt & context assembly
│   ├── hook.py      # AgentHook lifecycle (before_iteration, on_stream, before_execute_tools, etc.)
│   ├── memory.py    # Persistent conversation memory
│   ├── skills.py    # SKILL.md loader (workspace skills/ → builtin nanobot/skills/)
│   ├── subagent.py  # SubagentManager: background task spawning via SpawnTool
│   └── tools/       # Built-in tools + registry + MCP wrapper
│       ├── base.py      # Tool(ABC) — base class for ALL tools
│       ├── registry.py  # ToolRegistry — register/unregister/execute
│       └── mcp.py       # MCPToolWrapper — wraps MCP server tools as native Tools
├── channels/        # Chat platform integrations (Telegram, Discord, Slack, etc.)
│   ├── base.py      # BaseChannel(ABC) — abstract channel interface
│   ├── registry.py  # Channel discovery: built-in + entry_points("nanobot.channels")
│   └── manager.py   # Channel lifecycle management
├── command/         # Chat command routing
│   ├── router.py    # CommandRouter: priority → exact → prefix → interceptors
│   └── builtin.py   # /stop, /restart, /status, /new, /help
├── bus/             # MessageBus for inbound/outbound routing
├── config/          # Pydantic config schema (camelCase JSON ↔ snake_case Python)
├── providers/       # LLM provider adapters (OpenRouter, Anthropic, OpenAI, Gemini, etc.)
├── session/         # Conversation session management
├── skills/          # Bundled skill definitions (github, weather, tmux, etc.)
├── cron/            # Scheduled task execution
├── heartbeat/       # Proactive periodic wake-up
├── api/             # OpenAI-compatible HTTP API (/v1/chat/completions)
└── cli/             # Typer CLI commands
```

**Data flow:** Channel → MessageBus → AgentLoop → ContextBuilder → AgentRunner (LLM ↔ ToolRegistry) → MessageBus → Channel

## Extension Points

| What | How | Reference |
|------|-----|-----------|
| Custom tool | Subclass `Tool(ABC)` from `agent/tools/base.py`, register via `ToolRegistry.register()` | See `agent/tools/filesystem.py` for examples |
| Lifecycle hook | Subclass `AgentHook` from `agent/hook.py`, pass to `AgentLoop(hooks=[...])` | See [docs/PYTHON_SDK.md](docs/PYTHON_SDK.md) |
| Custom skill | Add `skills/{name}/SKILL.md` to workspace (overrides builtin) | See `nanobot/skills/` for format |
| Custom channel | Subclass `BaseChannel`, register via `entry_points(group="nanobot.channels")` | See [docs/CHANNEL_PLUGIN_GUIDE.md](docs/CHANNEL_PLUGIN_GUIDE.md) |
| Custom command | Use `CommandRouter.exact()`, `.prefix()`, or `.intercept()` | See `command/builtin.py` |
| MCP servers | Config-driven in `tools.mcpServers` — auto-wrapped as native tools | README MCP section |

## Build & Test

```bash
pip install -e ".[dev]"     # Install with dev dependencies
pytest                       # Run tests
pytest tests/unit/           # Unit tests only
ruff check nanobot/          # Lint
ruff format nanobot/         # Format
```

## Code Conventions

- **Async everywhere**: all I/O is `async def`; use `asyncio` primitives
- **Logging**: `loguru.logger` with `{}` format placeholders (never `%s`)
- **Type hints**: always present; use `X | None` union syntax (Python 3.10+)
- **Imports**: `from __future__ import annotations` in most files; heavy imports guarded by `TYPE_CHECKING`
- **Data classes**: `@dataclass(slots=True)` for performance; Pydantic `BaseModel` for config only
- **Config**: camelCase in JSON files, snake_case in Python (via `alias_generator=to_camel`)
- **Error handling in tools**: return `"Error: ..."` strings to the LLM, don't raise exceptions
- **Naming**: `snake_case` throughout; private methods prefixed with `_`
- **Line length**: 100 chars max (ruff E501 ignored but general target)
- **Linter rules**: ruff with rule sets E, F, I, N, W

## Key Design Principles

1. **Keep it small**: nanobot's value is being ultra-lightweight. Every addition must justify its weight.
2. **Explicit over magic**: no decorators for tool registration, no metaclass scanning, no implicit discovery (except channels via entry_points).
3. **Composable, not frameworky**: prefer thin interfaces with reference implementations over full frameworks.
4. **Backward compatible**: new features should not break existing `config.json`, tool definitions, or channel integrations.
5. **Module boundaries matter**: each directory is a clean module boundary. Don't reach across boundaries without going through the public API.

## Implementation Priorities (Current Milestone)

When adding new code, follow these priorities:

1. **Plugin abstraction for tools** — register custom tools without editing core logic, folder-based discovery, hot-reload compatible module boundaries
2. **Chat automation layer** — command/handler patterns for delegation to tools, subagents, tool output chaining, job/task flows
3. **Self-evolve hooks** — lightweight feedback loop (task input → tool output → evaluator feedback → revised config), deterministic and debuggable
4. **Hot reload path** — design plugin loading for future file-change reload; don't overengineer now

## Conventions That Differ From Common Practice

- Tools return plain strings or content blocks — **not** structured result objects
- The agent loop uses **per-session locking** (serial within session, concurrent across sessions)
- Skills use **YAML frontmatter in Markdown** (`SKILL.md`) with optional `nanobot.requires` metadata
- Channel plugins use **Python entry_points**, not config-based class paths
- Config uses **camelCase JSON** but Python code uses **snake_case** (auto-aliased via Pydantic)

## Existing Documentation

Do not duplicate content from these files — link to them instead:

- [CONTRIBUTING.md](CONTRIBUTING.md) — branching strategy, dev setup, code style philosophy
- [docs/CHANNEL_PLUGIN_GUIDE.md](docs/CHANNEL_PLUGIN_GUIDE.md) — step-by-step channel plugin creation
- [docs/PYTHON_SDK.md](docs/PYTHON_SDK.md) — programmatic usage, hooks API, session isolation
- [README.md](README.md) — features, install, config, CLI reference, providers, MCP, security
- [SECURITY.md](SECURITY.md) — security policy and reporting
