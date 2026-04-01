---
applyTo: "nanobot/agent/{loop,runner,hook,context,memory,skills,subagent}.py"
description: "USE WHEN modifying the core agent loop, runner, hooks, context builder, memory, skills, or subagent system. Covers the main execution flow and lifecycle."
---

# Agent Core

## Execution Flow

1. `AgentLoop.run()` — consumes `InboundMessage` from `MessageBus`
2. Priority commands dispatched before session lock (`/stop`, `/restart`)
3. `_dispatch()` — per-session serial, cross-session concurrent (semaphore gate)
4. `_process_message()` — builds context (history + memory + skills + system prompt)
5. `_run_agent_loop()` → `AgentRunner.run(AgentRunSpec)`
6. Runner iterates: LLM call → tool execution → append results → loop until done

## Key Rules

- `AgentRunner` is **stateless** — all state lives in `AgentRunSpec` and `AgentRunResult`
- Never add state to `AgentRunner`; pass it through `AgentRunSpec`
- Hook methods are all `async`, all optional (base class is no-op)
- `CompositeHook` isolates per-hook errors (except `finalize_content` which is a pipeline)
- Concurrency: `NANOBOT_MAX_CONCURRENT_REQUESTS` env var controls cross-session parallelism
- Tools are registered in `_register_default_tools()` — keep this the single registration point for built-in tools
- MCP servers connect lazily via `_connect_mcp()` on first message

## Hook Interface

```python
class AgentHook:
    def wants_streaming(self) -> bool: ...
    async def before_iteration(self, ctx: AgentHookContext) -> None: ...
    async def on_stream(self, ctx: AgentHookContext, delta: str) -> None: ...
    async def on_stream_end(self, ctx: AgentHookContext, resuming: bool) -> None: ...
    async def before_execute_tools(self, ctx: AgentHookContext) -> None: ...
    async def after_iteration(self, ctx: AgentHookContext) -> None: ...
    def finalize_content(self, ctx: AgentHookContext, content: str) -> str | None: ...
```

## Conventions

- Use `@dataclass(slots=True)` for new data carriers
- All I/O operations must be `async`
- Log with `loguru.logger` using `{}` placeholders
- Guard heavy imports with `TYPE_CHECKING`
