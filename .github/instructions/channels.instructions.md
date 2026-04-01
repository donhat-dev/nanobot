---
applyTo: "nanobot/channels/**"
description: "USE WHEN creating or modifying chat channel integrations. Covers BaseChannel subclassing, channel discovery, and the channel plugin system."
---

# Channel Development

## Creating a Channel

See [docs/CHANNEL_PLUGIN_GUIDE.md](../../docs/CHANNEL_PLUGIN_GUIDE.md) for the full step-by-step guide.

## Key Points

- Subclass `BaseChannel(ABC)` from `channels/base.py`
- Required: `name`, `display_name`, `start()`, `stop()`, `send(msg: OutboundMessage)`
- Optional: `send_delta()` for streaming, `login()` for interactive auth, `transcribe_audio()`
- Built-in channels live in `nanobot/channels/` as individual modules
- External channels register via `entry_points(group="nanobot.channels")`
- Discovery: `discover_channel_names()` scans `nanobot.channels` package; `discover_plugins()` scans entry points
- Built-in channels take priority over external plugins with the same name
- Config: channel-specific settings under `channels.{name}` in config.json; `"enabled": true` to activate
- Access control: `allowFrom` whitelist per channel; empty = deny all

## Conventions

- Channel modules are self-contained single files (one module = one channel)
- Use `loguru.logger` for all logging
- Handle reconnection and retry logic within the channel
- Global retry: `sendMaxRetries` in channel config (exponential backoff, cap at 4s)
