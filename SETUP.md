# Astryx setup

## MCP server URL

Set your Swiss Ephemeris MCP server base URL in code: edit `Astryx/App/AppConfig.swift` and replace the `mcpBaseURL` value with your deployed endpoint (e.g. Azure Container Apps URL).

## Secrets (required for AI / local run)

Copy `Secrets.xcconfig.example` to `Secrets.xcconfig` and set any AI proxy keys (e.g. `AIPROXY_SERVICE_URL`, `AIPROXY_PARTIAL_KEY`) as needed.

Do not commit `Secrets.xcconfig`; it is listed in `.gitignore`.
