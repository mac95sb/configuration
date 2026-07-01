# Notion Hosted MCP — Condensed Reference

## Server

- Endpoint: `https://mcp.notion.com/mcp`
- Type: remote HTTP MCP, OAuth
- Supports page search, read, and edit (Markdown), plus data-source operations.

## Hermes config shape

```yaml
mcp_servers:
  notion:
    url: https://mcp.notion.com/mcp
```

## Required one-time steps

1. Create an internal integration at `https://www.notion.so/profile/integrations`.
2. Grant the integration access to target pages via:
   - Integration settings > Access tab, or
   - Page > `...` > Connect to integration.

## Usage flow

1. Add config.
2. Run `/reload-mcp` in Hermes.
3. On first use of a Notion tool, complete the browser OAuth flow.

## Sources

- Notion MCP overview: https://developers.notion.com/guides/mcp/overview
- Get started (clients): https://developers.notion.com/guides/mcp/get-started-with-mcp
- GitHub repo: https://github.com/makenotion/notion-mcp-server
