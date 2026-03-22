# t3 Claude Wrapper

## Purpose

Use `tools/ops/start_t3_with_claude_proxy.sh` to launch t3 with the same Claude and CC Switch environment that works in the terminal.

This avoids the macOS GUI environment mismatch that causes `claudeAgent` to ask for login again.

## Defaults

The wrapper exports these values before starting t3:

- `HOME=$HOME`
- `PATH=$HOME/.local/bin:$PATH`
- `ANTHROPIC_BASE_URL=http://127.0.0.1:15721`
- `ANTHROPIC_API_KEY=any`

It also checks that Claude resolves to `~/.local/bin/claude`.

## Usage

Launch a `.app` bundle:

```bash
tools/ops/start_t3_with_claude_proxy.sh
```

Launch a binary directly:

```bash
tools/ops/start_t3_with_claude_proxy.sh /path/to/t3-binary
```

Pass extra args after `--`:

```bash
tools/ops/start_t3_with_claude_proxy.sh /Applications/T3 Code (Alpha).app -- --port 3000
```

## Validation

Dry run without starting t3:

```bash
T3_LAUNCHER_DRY_RUN=1 tools/ops/start_t3_with_claude_proxy.sh
```

Expected output:

- `ANTHROPIC_BASE_URL=http://127.0.0.1:15721`
- `claude=/Users/billyq/.local/bin/claude`

## Notes

- Do not launch t3 from Dock or Spotlight if you want Claude takeover to apply.
- Keep CC Switch Proxy Service and Claude Takeover enabled before starting t3.
