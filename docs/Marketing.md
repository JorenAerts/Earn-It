# Gloop launch marketing plan

**Audience:** students 16–25. **Budget:** €0, organic only. **Face:** Gloop, no founder on camera.
**Markets:** Belgium + Netherlands first (Dutch), then English.
**Assets:**
- Banner screenshots: `iOS/fastlane/screenshots/`
- Gloop stickers: `docs/marketing/gloop/` (`iOS/scripts/marketing/render_gloop.sh`)
- Screen recordings: `docs/marketing/videos/` (`iOS/scripts/marketing/record.sh`)

---

## 0. Launch checklist (App Store)
Full list in `LAUNCH_TODO.md` › "App Store launch". The ones that matter for marketing:
- [ ] Version 1.0.0 approved with **"Manually release this version"**, so you pick launch day.
- [ ] Optional: **pre-order** in App Store Connect (Pricing and Availability › Pre-Orders). The bio link then works before launch.
- [ ] App Store link in `Shared/Config/Auth.json` → `shareURL`. This turns on the share rows, the invite links and the streak card link.
- [ ] **Campaign links**, one per channel (App Store Connect › App Analytics › Campaigns): `https://apps.apple.com/app/apple-store/id<APP_ID>?pt=<PROVIDER_TOKEN>&ct=<campaign>&mt=8`

| Campaign token (`ct=`) | Where |
|---|---|
| `tiktok_bio` | TikTok bio link |
| `ig_bio` | Instagram bio / Linktree |
| `ig_story` | Instagram Story link stickers |
| `yt_shorts` | YouTube Shorts description |
| `threads_x` | Threads + X bio |
| `reddit` | Reddit posts |
| `producthunt` | Product Hunt |
| `press` | Press release |
| `student_press` | Student newspapers |
| `friends` | WhatsApp / Discord (friends and kot groups) |

---

## 1. Goals for the first 30 days
| Metric | Target | Where |
|---|---|---|
| Downloads | 1,000 | App Store Connect › Analytics |
| Rating | ≥ 4.5★ from ≥ 30 ratings | App Store Connect › Ratings |
| Trial → paid | ≥ 8 % | App Store Connect › Subscriptions |
| D7 retention | ≥ 25 % | App Store Connect › Retention |
| A post with ≥ 100k views | Yes | TikTok / Instagram insights |
| Buddies clubs | ≥ 50 | Supabase › `clubs` table |
| Onboarding completion | ≥ 70 % | TelemetryDeck › onboarding funnel |

---

## 2. Positioning and voice
- **One line:** *Gloop is the alarm you can't snooze: only a mission stops it, and your slime melts every time you try.*
- **Dutch:** *Gloop is de wekker die je niet kunt snoozen: alleen een missie zet hem uit, en je slijmpje smelt elke keer dat je het probeert.*
- **Gloop's character:** cute, dramatic, passive-aggressive, a little bit toxic, always on your side. Think of the Duolingo owl, but a slime that **melts** when you snooze.
  - Gloop talks in the first person ("I melt when you snooze").
  - Gloop has an ego (his evolution from Droplet to King Gloop) and opinions (the hot takes).
  - Gloop is never mean to a person, only to the snooze button and to excuses.
- **The enemy is the snooze button.** That's where the controversy comes from. People, groups and other apps are never the target.
- **Student truths to use:**
  - 8:30 lectures
  - 5 alarms
  - the roommate who never wakes up
  - "blok" (exam study period)
  - "kot" life
  - the TD (student party) the night before
  - the exam you almost slept through

**Bio texts:**
- EN: `I melt when you snooze. 🫠 Only a mission stops me. ⏰ #1 enemy of the snooze button.`
- NL: `Ik smelt als je snoozet. 🫠 Alleen een missie stopt mij. ⏰ Aartsvijand van de snoozeknop.`

**Hashtags (mix 3–5 per post):**
- NL: `#gloop #snooze #studentenleven #blok #kot #8u30 #ochtendroutine #wekker #studeren #fyp`
- EN: `#gloop #snooze #morningroutine #studentlife #college #wakeup #productivity #alarm #fyp #relatable`

---

## 3. Setup (week −2)
- [ ] Claim **@gloopalarm** on TikTok, Instagram, YouTube, Threads and X. Fallback: @gloop.app / @gloopwakeup.
- [ ] Profile picture: the app icon (`iOS/App/Assets.xcassets/AppIcon.appiconset`). Banner image: shot 1 of the screenshots.
- [ ] Bio + campaign link per platform (table in §0).
- [ ] TikTok: switch to a **Business account** (free analytics; commercial sounds library).
- [ ] Instagram: **Professional account** (insights, Story link stickers).
- [ ] Install **CapCut** (free: editing, auto-captions, trending sounds) and use **Canva free** (carousels, 1080×1350).
- [ ] Content kit:
  - `cd iOS && scripts/marketing/render_gloop.sh` makes 25 transparent Gloop stickers (moods, melting stages 1–4, all evolution accessories, friend colours).
  - `scripts/screenshots/make.sh` (once) then `scripts/marketing/record.sh …` makes vertical Simulator recordings:
    - `record.sh missions 8 -storeShot missionGrid`
    - `record.sh rering 12 -missionRunner math` (tap wrong answers on camera)
    - `record.sh success 6 -storeShot success`
    - `record.sh slimes 10 -slimeGallery`
    - `record.sh buddies 8 -buddiesSample -buddiesClub`
    - `record.sh lockscreen 5 -storeShot lockscreen`
  - Add `-language nl` for Dutch versions.
- [ ] Ask **15–30 friends + TestFlight testers** to be ready on launch day: download, rate, start a Buddies club, and post their streak card on day 7.

---

## 4. Content pillars
| Pillar | Share | Formats |
|---|---|---|
| **A. Gloop drama** | 30 % | POV skits from Gloop's view, melting compilations, Gloop "reacting" to your snooze, Gloop reading comments |
| **B. Hot takes** | 25 % | Text-on-screen opinion + Gloop sticker + question; carousels; Story polls |
| **C. Satisfying missions** | 20 % | Screen recordings: scan your mug, sky photo, made bed, colour hunt, memory; ASMR sounds |
| **D. Student life** | 15 % | Memes about lectures, blok, kot, roommates, exams, TDs |
| **E. Challenges + community** | 10 % | #GloopChallenge, Buddies leaderboards, streak card reposts, duets and stitches |

**Format rules (TikTok / Reels / Shorts):**
- The hook is in the **first second**, as text on screen + a big Gloop.
- 7–15 seconds; loopable when possible.
- Captions always on (CapCut auto-captions): many people watch muted.
- End with a question or a "comment X" prompt. Comments matter more than likes.
- Use a trending sound at low volume, or Gloop's own alarm sounds (they're original, so no copyright issue).
- Post at **7:00–8:00** (on-topic: people are snoozing right now) or **20:00–22:00** (peak scrolling).

---

## 5. The controversy playbook
**How it works:** a polarising opinion about a **habit** makes people disagree in the comments, and comments drive reach.
- Gloop takes a strong side.
- Reply to the best disagreeing comment with a **video reply**.
- Pin one comment from each side.

**Guardrails (non-negotiable):**
- No fake reviews, no fake accounts, no staged outrage, no buying followers.
- Never mock a real person, a group (nationality, gender, job…) or a competitor by name.
- No health claims beyond common sense. Say *"many people feel groggier after snoozing"*, never *"science proves snoozing damages your brain"*.
- Respect each platform's rules. On Reddit, only where self-promotion is allowed, and say you made the app.
- If something gets too heated (insults, real conflict), Gloop steps back with a joke and doesn't feed it.

### The 12 hot takes
Each one works as a TikTok/Reel (Gloop sticker + text), as a carousel (slide 1 = the take, slides 2–4 = arguments, last = "and you?") and as a Story poll.

| # | EN | NL | Comment prompt |
|---|---|---|---|
| 1 | The snooze button should be illegal. | De snoozeknop zou verboden moeten worden. | Agree, or are you part of the problem? |
| 2 | If you need 5 alarms, you don't have a sleep problem. You have an alarm problem. | Heb je 5 wekkers nodig? Dan heb je geen slaapprobleem, maar een wekkerprobleem. | How many alarms do YOU have? |
| 3 | Snoozing isn't "5 more minutes of rest". It's starting your day by losing to your phone. | Snoozen is geen "nog 5 minuutjes rust". Het is je dag beginnen met verliezen van je gsm. | Be honest: how many times today? |
| 4 | Morning people aren't born. They're made. (By a slime that melts.) | Ochtendmensen worden niet geboren. Ze worden gemaakt. (Door een slijmpje dat smelt.) | Morning person or night owl? |
| 5 | Hot take: 8:30 lectures should be banned. Hotter take: you'd snooze through a 10:00 one too. | Hot take: lessen om 8u30 moeten verboden worden. Nog hetere take: om 10u zou je ook snoozen. | Which one hurt more? |
| 6 | Your alarm is too nice to you. That's the problem. | Je wekker is te lief voor jou. Dat is het probleem. | Should alarms be meaner? |
| 7 | Making your bed is the most underrated habit. I won't stop ringing until you do. | Je bed opmaken is de meest onderschatte gewoonte. Ik stop pas als je het doet. | Do you make your bed? 👀 |
| 8 | 🚩 they snooze 7 times · 🟢 they have a 30-day streak | 🚩 snoozet 7 keer · 🟢 heeft een reeks van 30 dagen | Drop your morning red flag |
| 9 | Unpopular opinion: an alarm should be a little bit toxic. | Unpopular opinion: een wekker mag een beetje toxic zijn. | Gentle, tough love or savage? |
| 10 | "I'm just not a morning person" is an excuse, not a personality. | "Ik ben gewoon geen ochtendmens" is een excuus, geen persoonlijkheid. | Stitch this if you disagree |
| 11 | Snoozing is a personality trait now. | Snoozen is precies een persoonlijkheid geworden. | Poll: guilty / not me |
| 12 | Rank the worst alarm sounds. Wrong answers only. | Rangschik de ergste wekkergeluiden. Alleen foute antwoorden. | Wrong answers only 👇 |

**Comment reply bank (Gloop's voice):**
- "Snoozing is self-care" → *"Self-care is waking up without 7 alarms. I'll wait. (I'm melting.)"*
- "I'd just delete the app" → *"You'd delete ME? After everything? 🫠 …ok but your streak though."*
- "8:30 lectures are a human rights violation" → *"Agreed. Still not letting you snooze."*
- "My alarm is my mom" → *"Respect to your mom. I'm cheaper and I don't sigh."*
- NL: "Ik snooze gewoon niet" → *"Zegt iedereen. Tot de 3e wekker. 🫠"*

---

## 6. Channels
### TikTok (main channel)
- Launch week: 2 posts a day. After that: 1 a day.
- Reply to 10+ comments a day, at least 1 video reply a day.
- Duet/stitch "I overslept" and "my alarm routine" videos with Gloop reacting.
- Check TikTok **Creative Center › Trends** weekly for sounds and hashtags.

### Instagram
- **Reels:** the same videos as TikTok, 2–4 hours later, without the TikTok watermark (export from CapCut).
- **Carousels (3 a week):**
  - the hot takes
  - "The 10 missions, ranked by how fast they wake you"
  - "Gloop's evolution: Droplet → King Gloop"
  - "5 signs you're a serial snoozer"
- **Stories (daily):**
  - morning poll at 7:15 "Did you snooze today? 😇 / 🫠"
  - quiz sticker "How many snoozes until you're late?"
  - repost user streak cards
- **Highlights:** Missions · Challenge · FAQ · Reviews (real ones only).

### YouTube Shorts
- Repost every TikTok, plus a link in the description (`ct=yt_shorts`).

### Threads / X
- Gloop's text voice, 1–2 a day:
  - one-liners ("7:01. You've snoozed once. I've aged 10 years.")
  - polls
  - "Gloop's roast of the day"
- Join morning and productivity conversations with a joke, never spam.

### Communities (BE/NL first)
- **Friends' WhatsApp / Discord / kot groups:** a personal message with the link (`ct=friends`) and an invite to a Buddies club.
- **Student associations and faculty kringen:** offer a "club challenge": the most mornings in a week wins a free Lifetime (via offer codes).
- **Reddit:**
  - r/belgium and r/thenetherlands: only in relevant threads.
  - r/getdisciplined, r/productivity, r/college: in self-promo threads, or a story post such as *"I kept oversleeping, so I built an alarm where a slime melts if I snooze"*, where the rules allow it. Always say you made it.
- **Facebook student groups** (sell/swap or "kot" groups): only where the rules allow promotion.

### Press (free)
- **Tech:** iCulture.nl, Bright.nl, Apparata, iPhoned, Tweakers (meuktracker / user submission), Smartphones.be.
- **Students:** Veto (KU Leuven), Schamper (UGent), De Moeial (VUB), Dwars (UAntwerpen), Universonen (Uhasselt), Ad Valvas (VU), Mare (Leiden).
- **Local:** Het Belang van Limburg ("Peer student/maker builds an alarm that won't let you snooze").
- **English (month 2):** Product Hunt, Indie Hackers, AppAdvice and AppSmile submission forms.

### Launch platforms
- **BetaList** (week −2, free queue).
- **Product Hunt:**
  - "coming soon" page in week −1, launch at 00:01 Pacific on launch day.
  - Tagline: *"The alarm you can't snooze: a slime melts if you try"*.
  - First comment (see §10).
- **Indie Hackers:** a build story post in launch week.

---

## 7. Timeline
### Week −2: setup and teasers (app in review or on pre-order)
- [ ] Setup checklist (§3).
- [ ] Batch-produce 10 videos.
- [ ] Teasers that don't show the app:
  - *"Something is coming for your snooze button."*
  - *"Gloop is learning to melt."* (melting sticker sequence)
  - Countdown sticker in Stories.
- [ ] BetaList submission.
- [ ] Friends and testers briefed (§3).

### Week −1: warm-up
- [ ] Product Hunt "coming soon" page.
- [ ] Press release ready (§10), with the banner and Gloop stickers zipped as a press kit.
- [ ] Hot takes #1, #2 and #5: one a day on TikTok + Reels.
- [ ] Pre-order link in every bio (if used).

### Launch week
| Day | Main post | Also |
|---|---|---|
| **Mon (launch)** | *"Gloop is live. The snooze button is dead."* Video + carousel of the 4 banner shots | Release in App Store Connect at 7:00 · Product Hunt · press release · friends' wave · Stories countdown "0" |
| Tue | Hot take #1 *"The snooze button should be illegal"* | Video replies to the best comments |
| Wed | Script 4: *Scan your mug ASMR* | Reddit story post (where allowed) |
| Thu | Script 1: *POV: you snooze and I'm the alarm* | **Start #GloopChallenge** (§8) |
| Fri | Script 7: *8u30 les na een TD* (NL) | Mail the student newspapers |
| Sat | Carousel: *The 10 missions, ranked* | Story poll + quiz |
| Sun | Script 11: *Gloop reads your comments* | Metrics check (§11), plan next week |

### Weeks 2–4
- 1 video a day (pillar mix §4), 3 carousels a week, Stories every day.
- Week 2: **#GloopChallenge** in full swing; repost participants' streak cards daily.
- Week 3: **Buddies push**: *"Make a club with your kot. Last one up buys coffee."* Club challenge with student associations.
- Week 4: double down on the 3 best formats (by views + comments), drop the 3 worst. Start English-first content.

### Month 2 onwards
- English at full speed. Product Hunt, if it wasn't used for the BE/NL launch.
- Seasonal hooks (also in `docs/AppStore.md`):
  - January exams: *"Gloop gets you to your 8:30 exam."*
  - February: *"Valentine's: find someone who wakes up on the first ring."*
  - Clock change: *"Clocks change this weekend. I don't."*
  - Back to school (September).
- Micro-creators (1k–20k followers, student and productivity niches): free Lifetime via **offer codes** in exchange for an honest video. No payment, and they must disclose it (#ad / "kreeg de app gratis").

---

## 8. #GloopChallenge (7 days, no snooze)
- **Rules:** 7 mornings in a row without snoozing. On day 7, post your **streak card** (Success screen › Share) with #GloopChallenge and tag @gloopalarm.
- **Reward:** the best 10 posts get reposted and a free Lifetime offer code.
- **Group version:** a Buddies club with friends; the club with the most first-ring mornings wins.
- **Launch post:** *"7 days. 0 snoozes. If you snooze, I melt. If you make it, you get a streak card and eternal respect. #GloopChallenge"*
- NL: *"7 dagen. 0 keer snoozen. Snooze je, dan smelt ik. Hou je het vol, dan krijg je een reekskaart en eeuwig respect. #GloopChallenge"*

---

## 9. First 14 scripts
Format: **hook** (first second on screen) · scenes · on-screen text · caption EN / NL.
Assets: stickers from `docs/marketing/gloop/`, recordings from `record.sh`.

1. **POV: you snooze and I'm the alarm**
   - Hook: "POV: you hit snooze 🫠"
   - Scenes: lock screen (`record.sh lockscreen`) → stickers `melt-1` → `melt-2` → `melt-3` → `melt-4-puddle`, one per "snooze" sound beat → final: the mission screen.
   - Text: "Snooze 1… 2… 3… 💀"
   - EN: *"Every snooze, I melt a little. How many times did you do this to me today?"*
   - NL: *"Elke keer dat je snoozet, smelt ik een beetje. Hoe vaak deed je me dit vandaag aan?"*
2. **Things only a mission can stop**
   - Hook: "My alarm only stops if I…"
   - Scenes: fast cuts of the 9 missions (`record.sh missions`, + sky / bed / colour hunt recordings).
   - EN: *"Which one would actually get you out of bed?"* · NL: *"Welke krijgt jou écht uit bed?"*
3. **Hot take: snooze should be illegal**
   - Hook: big text + `angry` sticker.
   - Scenes: 3 arguments on screen (5 s each), ending on `proud`.
   - EN: *"Agree, or are you part of the problem? 👀"* · NL: *"Akkoord, of ben jij het probleem? 👀"*
4. **Scan your mug ASMR**
   - Hook: "7:00. The alarm won't stop until I find my mug."
   - Scenes: real-phone screen recording (iPhone › Control Centre › Screen Recording) of the item mission, kitchen sounds, progress bar, confetti.
   - EN: *"The most satisfying way to stop an alarm."* · NL: *"De meest bevredigende manier om een wekker te stoppen."*
5. **Red flag / green flag: morning edition**
   - Hook: "Morning red flags 🚩"
   - Scenes: 🚩 "7 alarms" / 🚩 "snoozes the snooze" / 🟢 "30-day streak" (streak card) / 🟢 "makes the bed" (bed mission).
   - EN: *"Drop your morning red flag 👇"* · NL: *"Geef je ochtend-red flag 👇"*
6. **Gloop's evolution in 30 days**
   - Hook: "Day 1 vs day 30 of not snoozing"
   - Scenes: `stage-*` stickers in order, a beat drop on King Gloop (`stage-crown`).
   - EN: *"What stage would you be at right now?"* · NL: *"Welke fase zou jij nu zijn?"*
7. **8u30 les na een TD** (NL-first)
   - Hook: "Ik om 7u na een TD:"
   - Scenes: `melt-4-puddle` → alarm → `shocked` → math mission recording → `proud` at the lecture hall.
   - NL: *"Wie herkent dit? Tag je kotgenoot 👇"* · EN: *"8:30 lecture after a party. Tag the friend who needs this."*
8. **How many alarms do you have?**
   - Hook: "I'll go first: 1. I'm enough."
   - Scenes: a list growing (6:00, 6:05, 6:10 … 7:30) gets crossed out → the single Gloop alarm.
   - EN: *"Your number. Be honest."* · NL: *"Jouw aantal. Eerlijk zijn."*
9. **Rate my roommate's wake-up**
   - Hook: "Our kot has a wake-up leaderboard"
   - Scenes: `record.sh buddies` → zoom on "Bram: 3 rings" → `suspicious` sticker: "Bram. We need to talk."
   - EN: *"Who's the Bram in your group?"* · NL: *"Wie is de Bram van jullie kot?"*
10. **Making my bed because a slime told me to**
    - Hook: "My alarm won't stop until my bed is made"
    - Scenes: bed mission on a real phone, a time-lapse of making the bed, confetti.
    - EN: *"Underrated habit or overkill?"* · NL: *"Onderschatte gewoonte of overdreven?"*
11. **Gloop reads your comments**
    - Hook: "Reading your comments about snoozing 💀"
    - Scenes: screenshot real comments (blur usernames) → Gloop sticker + reply from the reply bank (§5).
    - EN: *"Keep them coming."* · NL: *"Meer van dat."*
12. **Is snoozing a personality now?**
    - Hook: the question in big text + `suspicious` sticker.
    - Scenes: a stitch-bait ending: "Stitch this with your snooze count."
    - EN: *"Guilty or not me?"* · NL: *"Schuldig of niet ik?"*
13. **Day 1 vs day 30 streak card reveal**
    - Hook: "I didn't snooze for 30 days. This is what I got."
    - Scenes: a streak card from a tester (with permission), stickers, the evolution.
    - EN: *"Would you last 7?"* · NL: *"Hou jij 7 dagen vol?"*
14. **The alarm sounds ranked**
    - Hook: "Ranking alarm sounds by how much they ruin my day"
    - Scenes: play 5 of Gloop's own sounds with a tier list (Canva) and a Gloop reaction per sound.
    - EN: *"Wrong answers only: what's the worst alarm sound?"* · NL: *"Alleen foute antwoorden: wat is het ergste wekkergeluid?"*

---

## 10. Ready-made texts
### Press release (NL)
> **Studentikoze wekker-app Gloop laat je niet meer snoozen**
>
> Peer, [datum]. Met Gloop lanceert JA-Solutions een wekker-app voor iedereen die elke ochtend drie keer op snooze drukt. Gloop gaat pas uit als je een korte missie doet: een rekensom, je telefoon schudden, je koffiemok scannen of zelfs je bed opmaken. Wie toch snoozet, ziet zijn wekmaatje Gloop, een slijmpje, langzaam smelten.
>
> [Quote: pas aan naar je eigen verhaal, bv.] "Gewone wekkers zijn te lief", zegt maker [naam]. "Gloop is een beetje toxic, en dat werkt."
>
> Met Buddies maak je een club met je kot of vrienden en zie je wie er al op is. Gloop is gratis te downloaden in de App Store (één wekker en de rekenmissie); Gloop Pro ontgrendelt alle missies, geluiden en onbeperkte wekkers.
>
> Download: [App Store-link met ct=press] · Perskit: [link naar zip met screenshots en Gloop-stickers] · Contact: [support-e-mail]

### Press release (EN)
> **Gloop: the alarm app that won't let you snooze, and a slime that melts if you try**
>
> Gloop is a new iPhone alarm that only stops after a quick mission: solve a problem, shake your phone, scan your coffee mug or even make your bed. Snooze anyway, and Gloop, your wake-up buddy, slowly melts. With Buddies, friends and roommates see who's up and compete on a weekly leaderboard. Free on the App Store; Gloop Pro unlocks all 10 missions, every sound and unlimited alarms.
>
> Download: [App Store link, ct=press] · Press kit: [zip] · Contact: [support email]

### Product Hunt
- **Name:** Gloop
- **Tagline (60):** The alarm you can't snooze: a slime melts if you try
- **First comment** (adapt the first sentence to your own story): *"Hi PH 👋 I kept sleeping through my alarms, so I built an alarm I can't negotiate with. Gloop only stops after a mission (math, shake, scan your mug, a photo of the sky, make your bed…), and every snooze makes Gloop, a little slime, melt a bit more. Get up on the first ring and he evolves, all the way to King Gloop. There's also Buddies: a club with friends where you see who's up. Free with one alarm. I'd love to hear which mission you'd pick, and your best snooze excuse 😅"*

### Reddit story post (where allowed; keep it true)
> **I kept oversleeping, so I built an alarm where a slime melts every time I snooze**
>
> [Adapt to your own story; only write what's true.] I had 6 alarms and still overslept. So I made an iPhone alarm that only stops after a small mission (scan my coffee mug, take a photo of the sky, make my bed…). The mascot, Gloop, melts every time I snooze, and weirdly the guilt works. It's free with one alarm. I'm the developer, happy to hear what would make it better, or what your worst snooze habit is.

### Story / DM to friends (NL)
> Hé! Mijn app Gloop staat vanaf vandaag in de App Store 🎉 Een wekker die je niet kunt snoozen. Download hem, maak een Buddies-club met je kot, en laat een rating achter als je hem goed vindt 🙏 [link ct=friends]

---

## 11. Measuring (every Sunday, 30 minutes)
| Sheet column | Source |
|---|---|
| Downloads per campaign (`ct`) | App Store Connect › Analytics › Sources › Campaigns |
| Product page views → downloads (conversion) | App Store Connect › Analytics |
| Trials started, trial → paid | App Store Connect › Subscriptions |
| Ratings + reviews (reply to every one) | App Store Connect › Ratings and Reviews |
| Onboarding drop-off step | TelemetryDeck › onboarding funnel (`docs/Telemetry.md`) |
| Paywall source → purchase | TelemetryDeck |
| Top 3 posts (views, comments, shares, saves) | TikTok / Instagram insights |
| New Buddies clubs | Supabase › `clubs` |

**Decision rules:**
- A format gets **2× the average comments** → make 3 more variations next week.
- A format gets **< 50 % of the average views twice** → drop it.
- Product page conversion **< 25 %** → test another first screenshot or subtitle (Product Page Optimization).
- Onboarding drop-off **> 30 % on one step** → fix that step before pushing more traffic.

---

## 12. Weekly routine (about 4–5 hours)
| When | Task |
|---|---|
| Sunday (30 min) | Metrics (§11), pick next week's 7 ideas from the pillar mix |
| Monday evening (2–3 h) | Batch-produce 7–10 videos + 3 carousels; schedule posts (TikTok + Meta Business Suite are free) |
| Daily (10–15 min) | Reply to comments as Gloop, 1 video reply, Story poll, repost user content |
| Monthly | Refresh promo text + What's New, seasonal hook, review this plan |
