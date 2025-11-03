# FramedScreenshots Demo Workspace

This miniature workspace demonstrates how to adopt `framed-screenshots-tool` in a multi-platform app (iPhone, iPad, and macOS). It intentionally ships without the generated `Tools/FramedScreenshots` package so you can install the tooling exactly as in a fresh project.

## Quick start

```bash
mise run install-tool      # installs the workspace-local package + demo catalog
mise run screenshots       # renders demo PNGs for all platforms
```

To bring in custom/coloured device frames, drop `.png` or `.zip` bundles into `FrameItExtras/` before running `mise run screenshots`. The generated tooling automatically merges those assets into the FrameIt cache.

Optional:

```bash
mise run generate          # calls tuist generate to materialise the Xcode workspace
mise run test              # runs DemoApp unit tests after generation
```

> **Tip:** `mise` will automatically ensure the tool is installed and the demo catalog injected before rendering.

## What gets generated

- `Tools/FramedScreenshots` – workspace-local Swift package with `framed-screenshots` CLI + preview-ready library
- `Screenshots/<locale>/` – rendered marketing assets for iPhone, iPad, and macOS
- `UITestScreenshots/` – placeholder drop location if you later hook in UI test capture

## Resetting

Regenerate the workspace by deleting `Tools/FramedScreenshots` and rerunning `mise run install-tool`. The installer is idempotent and will update generated markers in-place.
