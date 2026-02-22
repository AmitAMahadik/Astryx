# Astryx setup

## Secrets (required for local run)

Copy `Secrets.xcconfig.example` to `Secrets.xcconfig` and set `MCP_BASE_URL` to your MCP server URL.

```bash
cp Secrets.xcconfig.example Secrets.xcconfig
# Edit Secrets.xcconfig and set MCP_BASE_URL = https://your-mcp-server...
```

Do not commit `Secrets.xcconfig`; it is listed in `.gitignore`. For CI/App Store builds, set `MCP_BASE_URL` in your CI environment or via a CI-only secret file.
