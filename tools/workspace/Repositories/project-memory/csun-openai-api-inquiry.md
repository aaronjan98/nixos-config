# CSUN OpenAI API Access Inquiry

## Goal

Determine whether CSUN provides OpenAI API keys (platform.openai.com) to students — distinct
from the ChatGPT Edu web access already available through the CSU/OpenAI partnership.
If yes, get a working API key to use with tools like Codex CLI or Aider.

## Background

- CSUN students have ChatGPT Edu (GPT-4o via web/app) through the CSU system deal.
- Codex CLI and other agentic tools require an `OPENAI_API_KEY` from platform.openai.com — a
  separate product from ChatGPT Edu.
- It's unclear if CSUN's agreement includes programmatic API access for developers.

---

## Contact Sequence

### Step 1 — IT Help Center (first contact)
- **Contact:** helpcenter@csun.edu / (818) 677-1400
- **Ask:** "Does CSUN provide OpenAI API keys or platform.openai.com credits for student
  developers? I'm trying to use developer tools that require an API key, not just ChatGPT Edu."
- **Sent:** 2026-04-17 (Thursday, mid-day)
- **Response:** (pending)
- **Outcome:** [ ] Yes → get key  [ ] No → escalate to Step 2  [ ] Referred elsewhere

### Step 2 — Academic Technology (if IT Help Center can't help)
- **Contact:** https://www.csun.edu/it/academic-technology/artificial-intelligence-ai
- **Ask:** Same question, add context that it's for a CS course or personal dev tools.
- **Sent:** (date)
- **Response:** (pending)
- **Outcome:** [ ] Yes  [ ] No → try Step 3

### Step 3 — CS Department / Professor
- **Contact:** A professor in CS who uses AI tools in their courses.
- **Ask:** "Does the department have an OpenAI API key or budget for student developer access?
  I'd like to use Codex CLI for a project."
- **Sent:** (date)
- **Response:** (pending)
- **Outcome:** [ ] Yes  [ ] No → go to fallback

---

## Fallback Plan (if CSUN provides nothing)

| Option | Cost | Notes |
|--------|------|-------|
| platform.openai.com personal account | ~$5-20 credit | Pay-per-token, works immediately |
| Aider + Ollama (local model) | Free | Needs decent GPU; works offline |
| Claude Code | Already have it | Currently using this |
| Cursor / Windsurf free tier | Free | IDE-based, limited requests/month |

---

## Notes / Updates

<!-- Append dated entries here as the thread progresses -->

### 2026-04-17
- Researched the question. CSUN has ChatGPT Edu (web) but no confirmed API access for devs.
- Created this tracker.
