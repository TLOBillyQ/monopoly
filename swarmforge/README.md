# SwarmForge Configuration

This project uses a four-pack SwarmForge workflow with Claude-backed agents.

## Layout

- `swarmforge.conf` — four roles: specifier, coder, refactorer, architect.
- `constitution.prompt` — loads articles and tool prompts.
- `constitution/articles/project.prompt` — project shape and local topology.
- `constitution/articles/engineering.prompt` — Lua 5.4 / busted specific engineering rules (full override of shared article).
- `constitution/tools/` — Lua quality tool prompts (mutate4lua, dry4lua, crap4lua, arch_view, acceptance4lua).
- `roles/*.prompt` — per-role instructions.
- `scripts/` — operational scripts, installed from `unclebob/swarm-forge/main` by `./swarm` on first run.

## Starting the swarm

```bash
./swarm
```

Shared scripts and constitution articles are downloaded from `unclebob/swarm-forge/main` if `swarmforge/scripts/` is missing.

## Local extensions

- Agent backend: `claude` (default); also supports `codex`, `copilot`, `grok`, `kimi`.
- Terminal backend: `otty.sh` in addition to upstream adapters.

## Agent backends

Supported agent backends:

- `claude` (default)
- `codex`
- `copilot`
- `grok`
- `kimi`

To use Kimi for a role, set the agent field in `swarmforge.conf`:

```text
window coder kimi coder
```

Kimi starts in interactive mode; the role prompt is injected as the first message after the TUI is ready.

## CLI agent override

You can temporarily override the agent for all roles without editing `swarmforge.conf`:

```bash
./swarm kimi              # use Kimi for all roles in the current directory
./swarm claude            # use Claude for all roles in the current directory
./swarm kimi /path/to/prj # use Kimi for all roles in the specified project
```

The override applies only to the current launch and does not modify `swarmforge.conf`.
