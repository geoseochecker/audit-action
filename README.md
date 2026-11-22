# geoseo checker audit

Fail a pull request or a deploy when your site's SEO, speed or AI-search readiness score drops.

This action reads the latest audit of your site from [geoseochecker.com](https://geoseochecker.com): the overall score, SEO, speed, AI readiness (how well ChatGPT, Perplexity or Gemini can read and quote your site), and the number of serious issues and warnings. No key and no account are needed for the headline numbers. The full report with every issue and its fix is one click away; the link is in the job summary.

## Use it

```yaml
name: Site quality
on:
  schedule: [{ cron: "0 7 * * *" }]
  workflow_dispatch:
jobs:
  geoseo:
    runs-on: ubuntu-latest
    steps:
      - uses: geoseochecker/audit-action@v1
        with:
          domain: example.com
          min-score: 80          # fail below this overall score
          max-serious: 0         # fail on any serious issue
          max-age-days: 14       # fail when the audit is older than two weeks
```

Run the job after a deploy, on a schedule, or both. The numbers appear in the job summary and as outputs for later steps.

## Inputs

| Input | Default | What it does |
|---|---|---|
| `domain` | (required) | The site to check, e.g. `example.com` |
| `min-score` | `0` | Fail when the overall score (0-100) is below this |
| `max-serious` | empty | Fail when the site has more serious issues than this |
| `max-age-days` | `0` | Fail when the latest audit is older than this many days (`0` = off) |
| `require-audit` | `false` | Fail when the site has not been audited yet (otherwise only a notice) |

## Outputs

`found`, `score`, `seo-score`, `speed-score`, `ai-readiness`, `serious-issues`, `warnings`, `audited-at`, `report-url`.

```yaml
      - id: geoseo
        uses: geoseochecker/audit-action@v1
        with: { domain: example.com }
      - run: echo "Score is ${{ steps.geoseo.outputs.score }}"
```

## Keeping the audit fresh

The action reads the latest stored audit; it does not start a new one. A site that has never been audited gets a link to run a free audit. On paid plans geoseo checker re-audits your site by itself and alerts you when something drops, so the numbers here stay current.

## Ask your AI assistant instead

geoseo checker also has an MCP server, so Claude, ChatGPT or Cursor can answer the same questions in chat: [geoseochecker.com/mcp](https://geoseochecker.com/mcp).

## License

MIT
