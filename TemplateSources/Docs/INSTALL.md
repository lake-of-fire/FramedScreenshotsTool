# Framed Screenshots Tool

{{MARKER_START}}
To finish wiring the local tooling inside Xcode:

1. Open your workspace in Xcode.
2. Choose **File → Add Packages…**.
3. Pick **Add Local…** and select the folder at `{{RELATIVE_TOOL_PATH}}`.
4. Add the `FramedScreenshots` package to the targets that need screenshot registration access.

From the terminal you can list or render screenshots with:

```
mise run {{TASK_NAME}} -- --list
```

or

```
mise run {{TASK_NAME}} -- --out Screenshots
```

## Optional: App Store Connect uploads

To upload rendered screenshots automatically you can let the tool store your App Store Connect API credentials in the macOS keychain:

```
framed-screenshots-tool enable-app-store-connect --workspace .
```

The command prompts for:

- API Key identifier (`ASC_KEY_ID`)
- Issuer identifier (`ASC_ISSUER_ID`)
- App Store Connect App ID (`ASC_APP_ID`)
- Target platform (`ios`, `macos`, or `appletvos`)
- Optional version string to pin uploads
- The `.p8` private key file contents

Credentials are stored per-workspace and never written to disk. To clear them again run:

```
framed-screenshots-tool disable-app-store-connect --workspace .
```

When the CLI runs it first reads credentials from the keychain; environment variables (`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY`, `ASC_APP_ID`, `ASC_PLATFORM`, `ASC_APP_VERSION`) remain a fallback for CI or other automation.

To pre-cache device frames (including coloured variants) run:

```
framed-screenshots-tool cache-frameit-frames --workspace .
```

Set `FRAMED_SCREENSHOTS_FRAME_ARCHIVES`, create a `FrameItAdditionalArchives.json` file (array of URLs), or pass `--frame-archive <url-or-path>` when running the CLI to layer in extra frame bundles (for example, Cosmic Orange devices).
{{MARKER_END}}
