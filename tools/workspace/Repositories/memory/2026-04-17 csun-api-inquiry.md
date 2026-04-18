# 2026-04-17 — CSUN OpenAI API Inquiry

## What was worked on

Researched whether CSUN provides OpenAI API access (platform.openai.com) to students — distinct
from the ChatGPT Edu (web) access already available through the CSU/OpenAI partnership.
Created a project tracker and drafted + sent the first contact email.

## Key insights

- CSUN has ChatGPT Edu (GPT-4o via web/app) for all students via CSU system deal — this does
  NOT include API keys for programmatic/developer access.
- OpenAI Codex CLI is a TUI agentic coding tool (similar to Claude Code), requires an
  `OPENAI_API_KEY` from platform.openai.com — separate billing product.
- t3.chat and similar web wrappers cannot substitute for a local coding agent (no filesystem
  access, no shell execution).

## Decisions

- Created `project-memory/csun-openai-api-inquiry.md` as the tracker for this multi-step inquiry.
- Added pointer to it in `MEMORY.md` under "Active inquiries".
- Email sent to `helpcenter@csun.edu` today (Thursday 2026-04-17, mid-day).
- Email included the Dr. Abrego independent study angle (EGT on graphs) to strengthen the case.

## Next steps

- Wait for IT Help Center response (expect 1–3 business days).
- If no response by Wednesday 2026-04-22, follow up.
- If IT can't help, escalate to Academic Technology, then CS department / a professor.
- See tracker for full contact sequence and fallback plan.

## Open questions

- Does CSUN's CSU/OpenAI agreement include any API access, or is it strictly ChatGPT Edu?
- Would the independent study with Dr. Abrego qualify for departmental API budget?

---

## Addendum — Codex CLI auth findings (same session)

Attempted to sign in to Codex CLI while waiting for IT response.

- **CSUN ChatGPT Edu SSO fails in CLI**: Error "No eligible ChatGPT account found. Authenticate
  with SSO to access your available account." — CSUN uses SAML SSO which the CLI OAuth flow
  does not support. Edu/Enterprise accounts are web-only.
- **Personal free account also initially failed**: Error "Your account is not eligible to sign in
  to Codex Local at this time." — root cause was account had never visited chatgpt.com/codex.
  Fix: open chatgpt.com/codex in browser first to activate the feature, then CLI auth works.
- **Outcome**: Codex CLI is now working via personal free ChatGPT account (aaronjan98@gmail.com).
  Free tier has rate limits but is functional for trying it out.
