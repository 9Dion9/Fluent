# DESIGN.md — Fluent design system & UX spec

> Authoritative for all iOS UI. Claude Code: read this before writing any SwiftUI view.
> Implement §3–§6 as a `Theme` namespace + component library in M2, then never hardcode a color, font, or radius again.

---

## 1. Design principles

1. **Light and lovely.** Airy, warm, calm. Lots of breathing room. The app should feel like morning light, not a casino. If a screen feels busy, remove something.
2. **One thing per screen.** Especially onboarding and review: one question, one card, one big obvious action.
3. **Celebrate small wins, never punish.** Corrections are gifts ("here's the natural way"), never red ink. Missed streaks get empathy, not guilt.
4. **The tutor is a character, not a feature.** Personality shows up in copy, empty states, notifications, and loading moments — everywhere, consistently.
5. **Fast hands.** Every frequent action (answer a card, tap a chip, snap a word) is one thumb-reach tap with instant haptic feedback.
6. **Quality floor, always:** Dynamic Type, VoiceOver labels, dark mode, Reduce Motion respected, 44pt minimum tap targets. Non-negotiable on every screen.

**Signature element (the one thing people remember):** the **gender-color system** (§4) — every German/Spanish noun wears its article's color everywhere in the app. It's beautiful, it's a genuine mnemonic aid, and no competitor owns it.

---

## 2. Brand direction

- **Feel:** warm paper, soft ink, one confident accent. Closer to a lovely stationery shop than to a game.
- **Mascot/voice:** the tutor avatar (§9.8) carries the personality; no separate mascot in v1. The 🦜 stays as a notification flourish only.
- **Illustration style:** simple filled SF Symbols + soft blob shapes in `surfaceAlt`. No stock illustration packs.
- **Naming (decide before M2, it leaks into copy):** candidates — *Parla*, *Wortwarm*, *Lumo*, *Perch*. Pick one, register the bundle ID, move on.

---

## 3. Color tokens

Implement as `Theme.Colors` with light/dark values via asset catalog.

| Token | Light | Dark | Use |
|---|---|---|---|
| `bg` | `#FAF7F2` warm paper | `#171512` | app background |
| `surface` | `#FFFFFF` | `#211E1A` | cards, bubbles |
| `surfaceAlt` | `#F1EBE2` | `#2A2620` | secondary fills, blobs |
| `ink` | `#2B2622` | `#F2EDE6` | primary text |
| `inkSoft` | `#7A716A` | `#A89F96` | secondary text |
| `accent` | `#E8674A` warm coral | `#F07B5E` | primary buttons, active states, streak flame |
| `leaf` | `#4C8C6A` | `#6FAE8C` | success, "natural way" recasts |
| `sky` | `#4E7FB8` | `#7AA3D4` | links, info |
| `honey` | `#E3A93C` | `#EAB95C` | streak/celebration secondary |

Rules: `accent` appears **once per screen** as the primary action. Never use pure red for corrections — corrections use `leaf` (they show the *right* way). Shadows: `ink` at 6% opacity, y=2, blur=12 — barely there.

---

## 4. Gender colors (signature)

| Article | Color | Token |
|---|---|---|
| der / el | `#4E7FB8` cool blue | `genderM` |
| die / la | `#C95D63` warm rose | `genderF` |
| das | `#4C8C6A` green | `genderN` |

Applied consistently: the article chip on word cards, the tint of the word's card border, camera result cards, quiz options, and the word list. A learner should absorb genders by color memory without being told. Include a color-blind-safe alternate (article always spelled out in the chip — color is reinforcement, never the only signal).

---

## 5. Typography & shape

- **Display:** SF Pro **Rounded**, Bold — screen titles, the big word on word cards, streak numbers. Rounded is the warmth carrier.
- **Body:** SF Pro Text, regular/medium. **Target-language text is always ≥ 1 step larger** than surrounding native-language text — the learning content is the hero.
- Type scale (Dynamic Type-relative): `display` 34, `title` 24, `body` 17, `caption` 13.
- **Shape:** radius 20 for cards, 14 for buttons, chips fully rounded. Spacing grid: 4/8/12/16/24/32.

---

## 6. Motion & haptics

- Springs only (`.spring(response: 0.35, dampingFraction: 0.8)`), no linear/ease curves. Everything under 400ms.
- **Haptic map:** chip tap = `.light`; correct answer = `.success` notification; wrong answer = `.soft` (never `.error` buzz); streak/level-up = `.success` + confetti; send message = `.medium`.
- **Confetti** (small, tasteful, `accent`+`honey`+`leaf` particles, 1.2s): placement result, daily set complete, streak milestone, first camera word. Nowhere else — scarcity keeps it special.
- Tutor **typing indicator:** three soft dots breathing in the tutor bubble, appears < 100ms after send.
- Respect Reduce Motion: replace springs/confetti with crossfades.

---

## 7. Core components (build once in M2)

- `PrimaryButton` (accent, full-width, 54pt), `GhostButton`
- `SelectableCard` / `SelectableChip` (multi-select interests; springy select with checkmark morph)
- `WordCard` — big rounded word, gender-colored article chip, IPA, example with tap-to-play audio button, translation reveal
- `ChatBubble` (user right/`surfaceAlt`, tutor left/`surface` with avatar), `CorrectionCard` (leaf-tinted: original struck softly → arrow → natural way + one-line why), `SuggestionChips`
- `ProgressRing` (daily goal, honey→accent gradient), `StreakFlame` (count + flame, grayscale when today not yet earned)
- `PlacementProgressDots`, `AudioWaveformButton` (record state), `ToastBanner`
- `EmptyState` (blob + one line of tutor-voice copy + one action)

---

## 8. Key screens

**Home ("Today")** — top: greeting in target language + streak flame + progress ring. Middle: today's 3 actions as cards — *Daily words (4/10)*, *Chat with {tutor}*, *Review due (12)*. Bottom: camera FAB-style card "What's around you? 📷". One scroll, no tabs-inside-tabs. Tab bar: Today · Chat · Words · Camera.

**Chat** — clean thread; corrections render as a `CorrectionCard` *under* the tutor bubble, collapsed to one line, tap to expand. Suggested-reply chips above the input. Mic button toggles walkie-talkie mode (hold to record, waveform, release to send; transcript appears immediately, reply audio auto-plays with speaker toggle). Scenario picker as a horizontal shelf ("☕ Order a coffee", "🏨 Check in", "🎉 At a party").

**Review session** — one card centered, four rating buttons (Again/Hard/Good/Easy) colored ink→leaf, big and thumb-reachable. Progress bar on top. Session end: summary card (words strengthened, ring progress) + confetti if goal hit.

**Camera ("caught a word" moment)** — live viewfinder, soft reticle. On identify: the word card **springs up from the object's position** with the gender-colored article, audio auto-plays once, "Added to your words ✓" toast. This 2-second moment is the app's demo magic — polish it obsessively.

**Degraded states** — gateway down: tutor avatar asleep, "„{Tutor} ist kurz eingenickt" / "{Tutor} is taking a quick nap — meanwhile, 12 words are ready for review →" (always redirect to something that works offline).

---

## 9. Onboarding — the sticky version (M2, screen by screen)

Goals: time-to-first-magic < 90 seconds; investment before permission asks; the user *teaches the app about themselves* (personalization = commitment); the first tutor interaction cannot fail.

Progress dots across the top from screen 2 on. Every screen: one question, big options, primary button pinned bottom. All copy through String Catalog.

1. **Welcome.** Warm paper bg, app name in Rounded, one line: "Learn a language by actually talking." Detected native language confirmed inline ("I'll speak English with you — change?"). Single button: *Let's go*.
2. **Target language.** Two big flag-free cards (German 🥨, English ☕ — objects, not flags): "German — spoken by 130M people" / "English — the world's handshake". Tap = select + advance (no extra confirm tap).
3. **"How much German do you know?"** Four cards: *Nothing yet* / *A few words* / *I can get by* / *Quite a bit*. Sets the placement starting rung. Copy under: "No wrong answer — we'll fine-tune in a moment."
4. **Adaptive placement (the cool factor).** "Quick check — 5 little questions, 30 seconds." Staircase from the quiz bank: correct → harder, miss → easier; instant feedback per answer (leaf check / soft "we'll get there"). *Nothing yet* users skip to a 2-question tap-the-word warmup instead so they still get a win.
5. **Placement result — first celebration.** Confetti. "You're starting at **Elementary** — you already know more than you think." One insight line ("You nailed word order — we'll grow your vocabulary."). This is the screen people screenshot.
6. **Interests.** "What do you want to talk about?" Multi-select chips (Travel ✈️, Food 🥐, Work 💼, Daily life ☕, Culture 🎭, Sport ⚽, Relationships 💛, Music 🎧). Min 2, springy selection. Copy: "Your chats and words will be about these."
7. **Daily goal + reminder.** Ring visual with 5/10/15 words options (10 pre-selected: "most people keep this one"). Then reminder time picker. **Notification pre-prompt on this screen:** "Want a nudge at 19:00? One friendly reminder a day, never spam." → only if they tap *Remind me* does the system dialog appear (a declined pre-prompt is recoverable; a declined system dialog is not). Skip is visible and shame-free.
8. **Meet your tutor.** Three persona cards with avatars + a sample line in each voice: **Sunny** ("Ooh, this'll be fun!"), **Dry** ("I promise this hurts less than the gym."), **Professor** ("Every word has a story — let's find yours."). Then name field, pre-filled with a suggestion per language (Emma / Mateo…), editable. Button: *Meet {name}*.
9. **First message — the guaranteed win.** Lands directly in chat. Tutor sends a warm two-line hello in native + one target-language word ("Hallo! 👋 That's the first of many.") + **one suggested-reply chip already glowing** ("Hallo, {tutor}!"). One tap = the user has "spoken" the language within 90 seconds of opening the app. Tutor replies with genuine delight + today's ring appears with 1/10 filled — the loop is now visible.

**Instrumentation:** fire `onboarding_step` per screen — the drop-off funnel is the #1 chart in the weekly report.

---

## 10. Notification copy (rotate, tutor-voiced, per persona)

Never the same message twice in a row. Examples (Sunny):
- "10 new words are waiting 🦜 They're getting impatient."
- "Your streak is at {n} 🔥 Two minutes keeps it alive."
- "Quick one: how do you say 'coffee' in German? …come check."
- "{word} misses you. So do I. — {tutor}"
- "30 seconds of German now = smug feeling all evening."
Dry and Professor get their own sets. Streak-save day gets its own gentle variant. Cap: 1/day, at the chosen time, plus an optional streak-rescue at 21:00 local only if today is unearned and a streak ≥ 3 is at risk.

---

## 11. Voice & microcopy rules

- The tutor's persona is the app's voice everywhere: errors, empty states, permission asks.
- Permission strings (Info.plist), human versions: mic — "So you can send voice messages to {tutor} and be understood."; speech — "Turns your voice into text, right on your iPhone."; camera — "Point at anything to learn its name."
- Errors say what happened + what to do, in-voice, never apologize twice: "Couldn't reach {tutor} — your words and reviews still work offline."
- Buttons say what they do: *Start review*, *Send*, *Add to my words* — never *OK/Submit*.
- Sentence case everywhere. Emoji: at most one per string, none in Professor persona.

## 12. Accessibility & i18n checklist (every screen, every PR)

- [ ] Dynamic Type up to XXL without truncation of learning content
- [ ] VoiceOver: word cards read "der Tisch, masculine, the table" with audio action
- [ ] Color never the sole signal (gender chips spell the article; correct/wrong have icons)
- [ ] Reduce Motion path
- [ ] 44pt targets; rating buttons reachable one-handed on a 4.7" screen
- [ ] All strings in `Localizable.xcstrings`; no concatenated sentences (word order breaks in other languages); dates/plurals via formatters
