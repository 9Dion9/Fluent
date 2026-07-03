# GROWTH.md — Distribution, ASO & monetization strategy
 
> Companion to CLAUDE.md. CLAUDE.md defines what we build; this file defines how it wins.
> Claude Code: this file is mostly strategy, but §1, §5 and §6 create real engineering requirements — they are cross-referenced from CLAUDE.md. When a growth decision requires code, the code requirement lives in CLAUDE.md; the reasoning lives here.
 
---
 
## 1. Positioning (drives product decisions)
 
- **We are not competing with Duolingo.** The strategy is: be **#1 for long-tail searches in 30–40 small storefronts** nobody is fighting over. Rankings-per-locale are the compounding asset.
- **v1 target languages: German + English.**
  - German learners = high-intent niche: visa/Ausbildung/nursing applicants, Goethe/TELC A1–B2 candidates. They pay, and incumbents don't serve exam prep.
  - English learners = massive volume in low-competition storefronts (Turkey, Vietnam, Indonesia, Brazil, MENA).
- **Lead marketing with German** (forgiving audience, weak competition); English rides the same infrastructure.
- Product implication (in CLAUDE.md): the gender-color signature applies to German (and future gendered languages) only; English word cards use a neutral `ink` chip showing POS instead — the component takes gender as optional.
## 2. ASO playbook (the 40-locale engine)
 
**Mechanics:** App availability is worldwide by default. Ranking per storefront comes from that storefront's metadata. App Store Connect supports ~39 localizations; each has its own title (30 chars), subtitle (30), keyword field (100), description, and screenshots.
 
**Rules (from proven indie playbook):**
1. Localize the **listing** into every supported locale at launch — translation cost only, no code.
2. Every locale's title & subtitle carry **long-tail, local-language keywords** with popularity ≥ 20 ("almanca öğren a1", "học tiếng Đức", "تعلم الألمانية للسفر", "deutsch lernen b1 prüfung"). Brand terms US/DE only.
3. **Two-tool rule:** no keyword enters a title until its popularity AND difficulty agree across two independent sources (AppFigures + Astro/AppTweak free tiers). One tool lies; two agreeing is a signal.
4. Keyword field: no spaces after commas, no plurals duplicating singulars, no words already in title/subtitle.
5. Re-crawl rankings monthly per locale; iterate the 5 worst locales each cycle. Keep a `docs/aso/` folder: one file per locale with current title/subtitle/keywords + ranking history. This folder IS the sellable asset.
**Priority storefronts, wave 1 (German-learner supply + English-learner volume):** TR, VN, ID, BR, MX, PH, IN, EG/SA (ar), UA, PL, RS/HR, TN/MA (fr+ar), DE (for English learning + Amt wedge).
 
**In-app native-language rollout (code, staged):** listings in 40 locales at launch; in-app `native_lang` UI added one locale at a time, ordered by storefront conversion data. String Catalog makes each addition a translation task, not an engineering task. Wave 1 in-app: EN, TR, ES, PT-BR, VI, AR, UK.
 
## 3. Organic loops
 
- **The camera "caught a word" moment is the marketing asset.** 2-second demo, natively viral. Seed 3–5 micro-creators (TikTok/Reels) per priority market showing it; no paid UA.
- **Shareable placement-result card** (screenshot-designed, see DESIGN.md §9.5) — the only share surface in v1.
- German migrant communities (Facebook groups, r/German, Ausbildung Telegram/WhatsApp groups) — the Amt-letter feature (§6) is the word-of-mouth trigger there.
## 4. Monetization (v2 — seams in v1)
 
- **Model: yearly-anchored subscription + lifetime. Never weekly** (churn-farming, review poison).
- Paywall order: **Yearly (anchor, ≈60% off monthly-equivalent) / Monthly / Lifetime.** Lifetime is strategic, not defensive: DE/TR/MENA are subscription-averse and our marginal cost ≈ $0.
- **Regional pricing mandatory** — Apple per-storefront price points; TR pays ~⅕ US and is still pure margin.
- **Free tier keeps the habit loop:** daily 10, all reviews/games, streak, 10 chat turns/day, 3 camera snaps/day. **Pro:** unlimited tutor + voice + camera, all scenarios, exam tracks, offline packs. Streak repair is NEVER paywalled.
- **Implementation (v2):** StoreKit 2 direct — `SubscriptionStoreView` in-app; App Store **Server Notifications V2** → Worker endpoint verifies JWS → writes `entitlements` row keyed to `user_id` → rate-limit tiers read entitlement. No RevenueCat, no third party, $0.
- **v1 seam (in CLAUDE.md):** `EntitlementProvider` interface with `FreeForAllProvider` as sole implementation; Worker rate limits already read from a tier config so v2 is a new provider + a table, zero call-site changes.
## 5. Wedge features (uniqueness nobody has)
 
1. **Amt-letter scanner (v2, German market).** Camera → on-device VisionKit OCR → tutor explains the official letter in the user's native language → extracts 5 key words into the deck. Solves a real fear for every migrant in Germany; ~90% reuses the existing camera + chat pipeline. *v1 seam:* camera pipeline keeps a `DocumentScanRoute` stub behind the same `/v1/vision/identify` contract.
2. **Goethe/TELC exam tracks (v2).** CEFR-tagged vocab (already in schema) + scenario roleplay of the actual oral exam formats ("Bildbeschreibung", "gemeinsam etwas planen") + tutor-as-examiner persona mode. Searchers typing "goethe b1 prüfung" convert. *v1 seam:* `scenarios.min_level` + `exam_track` nullable column reserved in the next migration when built — no v1 code.
3. Existing signatures to protect: gender-color system, camera→SRS loop, tutor personas.
## 6. Metrics that decide everything
 
Weekly report (`batch/report.py`) must answer:
- Onboarding funnel completion per step (target: >70% welcome→first chat turn).
- D1/D7/D30 retention (D30 >8% = viable; >15% = pour fuel).
- Per-storefront: impressions → product-page conversion → installs (App Store Connect API pull, add to report in v2).
- Chat turns/user/day and camera snaps/user/week — the two engagement predictors.
## 7. Honest odds (recorded so we stay sober)
 
| Outcome | Odds |
|---|---|
| v1 ships and works well | ~75% |
| 10k+ MAU in year 1 (with §2 executed) | ~15–25% |
| Top-3 long-tail rankings in 15+ storefronts | ~30% |
| €2–5k MRR by month 18–24 | ~15% |
| Global category #1 | ~0 — not the goal; 40 small ponds is the goal |