---
applyTo: "nanobot/agent/tools/**"
description: "USE WHEN editing or creating tools in the agent/tools/ directory. Covers Tool(ABC) subclassing, registration patterns, parameter schemas, and error handling conventions."
---

# Tool Development

## Creating a Tool

Subclass `Tool(ABC)` from `agent/tools/base.py`:

```python
from nanobot.agent.tools.base import Tool

class MyTool(Tool):
    @property
    def name(self) -> str:
        return "my_tool"

    @property
    def description(self) -> str:
        return "Short description for the LLM to understand when to use this tool."

    @property
    def parameters(self) -> dict:
        return {
            "type": "object",
            "properties": {
                "param_name": {"type": "string", "description": "What this param does"},
            },
            "required": ["param_name"],
        }

    async def execute(self, **kwargs) -> str:
        # Return a string — never raise exceptions to the LLM
        try:
            result = await do_something(kwargs["param_name"])
            return str(result)
        except Exception as e:
            return f"Error: {e}"
```

## Conventions

- `parameters` must be a valid JSON Schema object
- `execute()` is always `async` and returns `str` or content blocks
- On failure, return `"Error: ..."` string — the LLM will read it and adapt
- Use `_HINT` suffix pattern for error messages that guide the LLM: `return f"Error: file not found.\n_HINT: check the path exists first"`
- Register tools via `ToolRegistry.register(tool_instance)` — never implicitly
- Tool names use `snake_case`
- `cast_params()` and `validate_params()` are handled by the base class automatically

## Reference Implementations

- `filesystem.py` — ReadFileTool, WriteFileTool, EditFileTool, ListDirTool
- `shell.py` — ExecTool (shell execution with security controls)
- `web.py` — WebSearchTool, WebFetchTool
- `mcp.py` — MCPToolWrapper (wrapping external MCP tools)
- `spawn.py` — SpawnTool (subagent background tasks)
