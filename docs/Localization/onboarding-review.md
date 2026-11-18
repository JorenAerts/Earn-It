# Onboarding copy review — November 2026

Review of every text in the iOS onboarding (20 steps, ~350 strings incl. mission names, sounds,
permissions and the onboarding paywall) in English and the 7 shipped languages. All translations
are still AI-made (`needs_review`): this pass fixes what was clearly wrong, it does not replace a
native speaker. Rules used from now on: `glossary.md` (now covers all 7 languages + style rules).

## What was wrong

### Bugs in code (text never translated)
| Where | Problem | Fix |
|---|---|---|
| `OnboardingPersonalization.coachReaction` (name step) | `"\(name)! Love it…"` was a plain String: English in every language | `L10n.tr` |
| same, fallback name | `"friend"` hardcoded English in Gloop's lines when no name was given | `L10n.tr("friend")`, translated (vriend, Freund, ami…) |
| `QuoteCarousel.coachQuotes` (building step) | 4 Gloop quotes never translated, with hard-coded English quote marks | `L10n.tr`, no quote marks (the card already shows Gloop) |
| `GetUpTime.title` | "10–30 minutes" / "30–60 minutes" hardcoded English | `L10n.tr` |
| `WeekdayPicker` accessibility | `", alarm"` glued to the day name in English | one key `"%@, alarm on"` |
| Android (same bugs) | `"friend"` in `:core`, `"10–30 min"` in `OnboardingTexts.kt`, quotes with marks | `FALLBACK_NAME` → `R.string.name_fallback`, new `getup_10_30/30_60`, quotes from the iOS catalog |

### English source (unclear or wrong)
| Before | After | Why |
|---|---|---|
| One alarm and a short mission **gets** your brain… | …**get** your brain… | grammar |
| Over an hour. Okay, short re-rings for you, %@. | Over an hour? Okay, I'll ring again sooner for you, %@. | "re-rings" is internal jargon |
| You're up. Glad you set it. | You're up. The day is yours. | unclear what "it" is |
| You're up, and ahead. | You're up and ahead of the day. | incomplete |
| A normal alarm needs four alarms five minutes apart. Gloop needs one alarm with a mission. | A normal alarm takes four alarms, five minutes apart. Gloop takes one alarm and a mission. | "an alarm needs alarms" read oddly |
| Streaks, evolutions and buddies keep you going | …keep you motivated | idiom that got calqued in every language |
| Your first name or a nickname. Used in your coach's lines and your profile. | …Gloop uses it to talk to you and on your profile. | "coach's lines" is internal wording |
| Set up your math | Set up your math problems | incomplete |
| Print or pick any code and stick it somewhere out of bed, like the bathroom. | Print a code or use one you already have, and stick it far from your bed, like in the bathroom. | "pick any code" / "out of bed" unclear |

### Per language — main patterns
- **pt-PT** was partly broken by a search-and-replace from pt-BR: "Já tnuma conta?", "Ajuda nós",
  "Onde você ouviu falar dnós?", "Nós escreve a mensagem para você", "no casa de banho",
  "outro divisão", "à a sua escolha", "a app fechado" (also outside onboarding: camera error,
  telemetry text, paywall — fixed too). Many Brazilian words/forms left ("você", "Pular", "Malhar",
  "Confira seu e-mail", "faz ela subir", "por que", "tu"-form mixed in). Now consistent third person.
- **Gender**: the usual masculine default for the reader is kept on purpose ("réveillé",
  "despierto", "Je suis prêt", "un amico"…). A first pass made these neutral; that was reverted
  (see the last table).
- **Calques**: nl "houden je gaande", de "Schlummerkreislauf", "Schüttler", "Das sind etwa 3 Stunden
  jede Woche zurück", it "Ciclo del posticipa", "Altro" for *More* (= "other"), es "No vas a dormir a
  pesar de mí", fr "Tu ne dormiras pas malgré moi".
- **Item name with a fixed gender** ("Finde deinen %@", "Trouve ton %@", "Trova il tuo %@ e
  inquadralo"): wrong for half the names people type. Now quoted: „%@“, « %@ », «%@».
- **French typography**: non-breaking space before ? ! : ; and inside « » in the whole fr file.
- **Dutch**: "Ga verder" → "Doorgaan", "Sla over" → "Overslaan", "Wekker gaat" → "Wekker gaat af",
  "Hoofd" → "Brein", more natural Gloop lines.

## Still for a native speaker
- Gloop's jokes and puns (puddle, bouncing, droopy) in every language.
- Outside onboarding not reviewed: coach tones (de "Harte Liebe" is a calque), pt-PT
  "Parada de segurança" (glossary says "paragem"), remaining "você" in pt-PT (~50 strings).
- Stale key `streak %lld` in every translation file (not in the code any more), unrelated to this pass.

## All changes (before → after)

## nl (81 changes)

| English | Before | After |
|---|---|---|
| Over an hour. Okay, short re-rings for you, %@. | Meer dan een uur. Oké, korte herhalingen voor jou, %@. | (key replaced, see new English) |
| You're up, and ahead. | Je bent op, en voor. | (key replaced, see new English) |
| You're up. Glad you set it. | Je bent op. Goed dat je hem hebt gezet. | (key replaced, see new English) |
| A normal alarm needs four alarms five minutes apart. Gloop needs one alarm with a mission. | Een gewone wekker heeft vier alarmen met vijf minuten ertussen nodig. Gloop heeft één wekker met een missie nodig. | (key replaced, see new English) |
| Streaks, evolutions and buddies keep you going | Reeksen, evoluties en buddies houden je gaande | (key replaced, see new English) |
| Your first name or a nickname. Used in your coach's lines and your profile. | Je voornaam of een bijnaam. Gebruikt in de zinnen van je coach en in je profiel. | (key replaced, see new English) |
| Snoozing drops you back into sleep you can't finish, so every extra ring tends to leave you groggier. One alarm and a short mission gets your brain and body going at once. | Door te snoozen val je terug in slaap die je niet kunt afmaken, dus je wordt meestal suffer van elke extra keer. Eén wekker en een korte missie krijgen je hoofd en lichaam meteen op gang. | (key replaced, see new English) |
| Set up your math | Stel je sommen in | (key replaced, see new English) |
| Print or pick any code and stick it somewhere out of bed, like the bathroom. | Druk een code af of kies er een en plak hem ergens buiten je bed, bijvoorbeeld in de badkamer. | (key replaced, see new English) |
| friend | vriend | slaapkop |
| %@! Love it. We're going to be a great team. | — | %@! Mooie naam. Wij worden een topteam. |
| You're up and ahead of the day. | — | Je bent op, en de dag een stap voor. |
| You're up. The day is yours. | — | Je bent op. De dag is van jou. |
| Over an hour? Okay, I'll ring again sooner for you, %@. | — | Meer dan een uur? Oké, dan ga ik voor jou sneller opnieuw af, %@. |
| A normal alarm takes four alarms, five minutes apart. Gloop takes one alarm and a mission. | — | Met een gewone wekker zet je er vier, met vijf minuten ertussen. Met Gloop is het één wekker en een missie. |
| %@, alarm on | — | %@, wekker aan |
| Every snooze makes me a little droopier. Just saying. | — | Bij elke snooze zak ik een beetje meer in. Zeg ik maar even. |
| Feet on the floor first. Thinking comes later. | — | Eerst je voeten op de grond. Nadenken komt later. |
| Nobody ever regretted getting up on time. Especially not me. | — | Niemand heeft ooit spijt gehad van op tijd opstaan. Ik al helemaal niet. |
| One mission, then the morning is yours. And I get to bounce. | — | Eén missie en de ochtend is van jou. En ik mag stuiteren. |
| Streaks, evolutions and buddies keep you motivated | — | Reeksen, evoluties en buddies houden je gemotiveerd |
| Your first name or a nickname. Gloop uses it to talk to you and on your profile. | — | Je voornaam of een bijnaam. Gloop spreekt je ermee aan en zet hem op je profiel. |
| Snoozing drops you back into sleep you can't finish, so every extra ring tends to leave you groggier. One alarm and a short mission get your brain and body going at once. | — | Als je snoozet, val je terug in een slaap die je niet kunt afmaken. Daardoor word je van elke extra keer meestal juist suffer. Eén wekker en een korte missie krijgen je hoofd en lijf meteen op gang. |
| Set up your math problems | — | Stel je sommen in |
| Print a code or use one you already have, and stick it far from your bed, like in the bathroom. | — | Druk een code af of gebruik er een die je al hebt, en plak hem ver van je bed, bijvoorbeeld in de badkamer. |
| 10–30 minutes | — | 10–30 minuten |
| 30–60 minutes | — | 30–60 minuten |
| Continue | Ga verder | Doorgaan |
| Continue without account | Ga verder zonder account | Doorgaan zonder account |
| Continue with %@ | Ga verder met %@ | Doorgaan met %@ |
| Continue with free version | Ga verder met de gratis versie | Doorgaan met de gratis versie |
| Create your account | Maak je account | Maak een account aan |
| Create a new account | Maak een nieuw account | Maak een nieuw account aan |
| Check your inbox for a reset link. | Kijk in je inbox voor een herstellink. | Check je inbox: we hebben je een link gestuurd om je wachtwoord opnieuw in te stellen. |
| Skip | Sla over | Overslaan |
| Rings until you're up | Gaat door tot je op bent | Blijft afgaan tot je op bent |
| Alarm rings | Wekker gaat | Wekker gaat af |
| An alarm that keeps ringing until you're up | Een wekker die blijft gaan tot je op bent | Een wekker die blijft afgaan tot je echt op bent |
| What goes through your head when your alarm rings? | Wat gaat er door je hoofd als je wekker gaat? | Wat gaat er door je hoofd als je wekker afgaat? |
| Setting your %@ alarm | Je wekker van %@ instellen | Je wekker voor %@ instellen |
| Loading %@ | %@ laden | %@ klaarzetten |
| Getting your mornings ready | Je ochtenden worden klaargezet | We zetten je ochtenden klaar |
| Feeling groggy for ages | Me lang suf voelen | Nog lang suf blijven |
| Sleeping through alarms | Door wekkers heen slapen | Door mijn wekker heen slapen |
| Be on time, every time | Altijd op tijd | Altijd op tijd zijn |
| Work out before my day | Sporten voor mijn dag begint | Sporten voordat mijn dag begint |
| Get ahead on my day | Voorsprong op mijn dag | Een voorsprong op mijn dag |
| Feel awake, not a zombie | Voel je wakker, geen zombie | Me wakker voelen, geen zombie |
| Shakes | Keer schudden | Aantal keer schudden |
| More shakes, more awake. | Meer schudden, wakkerder. | Hoe meer je schudt, hoe wakkerder je wordt. |
| PRO missions come with a free trial. Tap one to try it, or keep Math on the free plan. | PRO-missies komen met een gratis proefperiode. Tik er een aan om te proberen, of hou Rekenen op het gratis abonnement. | PRO-missies kun je gratis uitproberen. Tik er een aan, of blijf bij Rekenen met het gratis abonnement. |
| Unlock by inviting a friend | Ontgrendel door een vriend uit te nodigen | Ontgrendel door iemand uit te nodigen |
| Know someone who oversleeps? Send them Gloop and get Rise & Conquer, a brass fanfare that's not in the free plan. | Ken je iemand die zich verslaapt? Stuur hem of haar Gloop en krijg Rise & Conquer, een koperfanfare die niet in de gratis versie zit. | Ken je iemand die zich vaak verslaapt? Stuur Gloop door en krijg Rise & Conquer, een koperfanfare die niet in de gratis versie zit. |
| Text one friend | Stuur een vriend een bericht | Stuur iemand een bericht |
| That's about %@ hours back every week. | Dat is ongeveer %@ uur terug, elke week. | Zo win je elke week zo'n %@ uur terug. |
| That's about %@ hour back every week. | Dat is ongeveer %@ uur terug, elke week. | Zo win je elke week zo'n %@ uur terug. |
| You're up. Go train. | Je bent op. Ga trainen. | Je bent op. Tijd om te trainen. |
| You're up. Coffee's yours. | Je bent op. De koffie is voor jou. | Je bent op. Tijd voor koffie. |
| Hi, I'm %@! I get droopy when you snooze, so let's not. | Hoi, ik ben %@! Ik word slap als je snoozet, dus laten we dat niet doen. | Hoi, ik ben %@! Als je snoozet, zak ik in elkaar. Dus liever niet. |
| Ooh, a morning person. I like you already. | Ooh, een ochtendmens. Ik vind je nu al leuk. | Ooh, een ochtendmens. Jou mag ik nu al. |
| Five minutes. Sure. That's how I end up a puddle. | Vijf minuutjes. Tuurlijk. Zo eindig ik als plasje. | Vijf minuutjes. Tuurlijk. Zo eindig ik als een plasje. |
| A backup for your backup? You only need me now. | Een reserve voor je reserve? Je hebt nu alleen mij nodig. | Een reserve voor je reservewekker? Je hebt nu alleen mij nog nodig. |
| Because the day is waiting, %@. I'll make it worth it. | Omdat de dag op je wacht, %@. Ik maak het de moeite waard. | Omdat de dag op je wacht, %@. Ik zorg dat het de moeite waard is. |
| Not bad! Let's make it zero. | Niet slecht! Laten we er nul van maken. | Niet slecht! Nu nog naar nul. |
| The snooze button is not your friend. I am. | De snoozeknop is niet je vriend. Ik wel. | De snoozeknop is je vriend niet. Ik wel. |
| You won't sleep through me. I keep coming back. | Door mij slaap je niet heen. Ik blijf terugkomen. | Mij verslaap je niet. Ik blijf terugkomen. |
| %@. I'll be there, bouncing. | %@. Ik ben er, stuiterend. | %@. Ik sta al te stuiteren. |
| This is the only thing that stops me. Pick wisely. | Dit is het enige wat me stopt. Kies verstandig. | Dit is het enige wat mij stopt. Kies goed. |
| Gloop gets you out of bed and wide awake | Gloop krijgt je uit bed en klaarwakker | Gloop haalt je uit bed en maakt je klaarwakker |
| Let's get you out of bed | Tijd om je uit bed te krijgen | Wij krijgen je uit bed |
| No more stacking alarms. One alarm that doesn't give up. | Geen stapel wekkers meer. Eén wekker die niet opgeeft. | Geen rij wekkers meer. Eén wekker die niet opgeeft. |
| Make sure your %@ alarm rings | Zorg dat je wekker van %@ afgaat | Zorg dat je wekker van %@ echt afgaat |
| Alarms ring through silent mode and Focus. Notifications bring %@'s evening reminders. | Wekkers gaan af door de stille modus en Focus heen. Meldingen brengen de avondherinneringen van %@. | Wekkers gaan ook af in de stille modus en met Focus. Via meldingen krijg je de avondherinneringen van %@. |
| So your alarm rings through silent mode and Focus. | Zodat je wekker afgaat door de stille modus en Focus heen. | Zodat je wekker ook afgaat in de stille modus en met Focus. |
| Your alarm rings through silent mode and Focus, even when the app is closed. | Je wekker gaat af door de stille modus en Focus heen, ook als de app gesloten is. | Je wekker gaat ook af in de stille modus en met Focus, zelfs als de app dicht is. |
| What's your age range? | Wat is je leeftijd? | Hoe oud ben je? |
| What would you do with that time back? | Wat zou je doen met die tijd? | Wat zou je doen met die gewonnen tijd? |
| How much time until you actually get up? | Hoeveel tijd duurt het voor je echt opstaat? | Hoe lang duurt het voordat je echt opstaat? |
| Onboarding progress | Voortgang introductie | Voortgang van de introductie |
| Wake up | Word wakker | Opstaan |
| Brain | Hoofd | Brein |

## de (63 changes)

| English | Before | After |
|---|---|---|
| Over an hour. Okay, short re-rings for you, %@. | Über eine Stunde. Okay, kurze Abstände für dich, %@. | (key replaced, see new English) |
| You're up, and ahead. | Du bist wach, und vorne. | (key replaced, see new English) |
| You're up. Glad you set it. | Du bist wach. Gut, dass du ihn gestellt hast. | (key replaced, see new English) |
| A normal alarm needs four alarms five minutes apart. Gloop needs one alarm with a mission. | Ein normaler Wecker braucht vier Alarme im Abstand von fünf Minuten. Gloop braucht einen Wecker mit einer Mission. | (key replaced, see new English) |
| Streaks, evolutions and buddies keep you going | Serien, Entwicklungen und Buddies halten dich dran | (key replaced, see new English) |
| Your first name or a nickname. Used in your coach's lines and your profile. | Dein Vorname oder ein Spitzname. Wird in den Sätzen deines Coaches und in deinem Profil verwendet. | (key replaced, see new English) |
| Snoozing drops you back into sleep you can't finish, so every extra ring tends to leave you groggier. One alarm and a short mission gets your brain and body going at once. | Beim Schlummern fällst du zurück in Schlaf, den du nicht beenden kannst, deshalb macht dich jedes weitere Klingeln eher noch benommener. Ein Wecker und eine kurze Mission bringen Kopf und Körper auf einmal in Gang. | (key replaced, see new English) |
| Set up your math | Richte deine Rechenaufgaben ein | (key replaced, see new English) |
| Print or pick any code and stick it somewhere out of bed, like the bathroom. | Druck einen Code aus oder nimm irgendeinen und kleb ihn weit weg vom Bett, zum Beispiel ins Bad. | (key replaced, see new English) |
| friend | Freund | Schlafmütze |
| %@! Love it. We're going to be a great team. | — | %@! Schöner Name. Wir zwei werden ein super Team. |
| You're up and ahead of the day. | — | Du bist wach und dem Tag einen Schritt voraus. |
| You're up. The day is yours. | — | Du bist wach. Der Tag gehört dir. |
| Over an hour? Okay, I'll ring again sooner for you, %@. | — | Über eine Stunde? Okay, dann klingle ich bei dir schneller wieder, %@. |
| A normal alarm takes four alarms, five minutes apart. Gloop takes one alarm and a mission. | — | Mit einem normalen Wecker stellst du vier Alarme im Abstand von fünf Minuten. Mit Gloop reichen ein Wecker und eine Mission. |
| %@, alarm on | — | %@, Wecker an |
| Every snooze makes me a little droopier. Just saying. | — | Mit jedem Schlummern sacke ich ein bisschen mehr zusammen. Nur so als Info. |
| Feet on the floor first. Thinking comes later. | — | Erst die Füße auf den Boden. Denken kommt später. |
| Nobody ever regretted getting up on time. Especially not me. | — | Pünktlich aufstehen hat noch niemand bereut. Ich schon gar nicht. |
| One mission, then the morning is yours. And I get to bounce. | — | Eine Mission, dann gehört der Morgen dir. Und ich darf hüpfen. |
| Streaks, evolutions and buddies keep you motivated | — | Serien, Entwicklungen und Buddies halten dich motiviert |
| Your first name or a nickname. Gloop uses it to talk to you and on your profile. | — | Dein Vorname oder ein Spitzname. Gloop spricht dich damit an und zeigt ihn in deinem Profil. |
| Snoozing drops you back into sleep you can't finish, so every extra ring tends to leave you groggier. One alarm and a short mission get your brain and body going at once. | — | Beim Schlummern fällst du in einen Schlaf zurück, den du nicht zu Ende bringen kannst. Deshalb macht dich jedes weitere Klingeln eher noch benommener. Ein Wecker und eine kurze Mission bringen Kopf und Körper auf einmal in Schwung. |
| Set up your math problems | — | Richte deine Rechenaufgaben ein |
| Print a code or use one you already have, and stick it far from your bed, like in the bathroom. | — | Druck einen Code aus oder nimm einen, den du schon hast, und kleb ihn weit weg vom Bett, zum Beispiel ins Bad. |
| 10–30 minutes | — | 10–30 Minuten |
| 30–60 minutes | — | 30–60 Minuten |
| Snooze cycle | Schlummerkreislauf | Schlummerschleife |
| GROGGY ZONE | MÜDE ZONE | DÖSZONE |
| Chart: snoozing keeps your energy in a groggy zone; getting up at the first alarm raises it steadily. | Diagramm: Beim Schlummern bleibt deine Energie in einer müden Zone; beim Aufstehen beim ersten Klingeln steigt sie stetig an. | Diagramm: Beim Schlummern bleibt deine Energie in der Döszone; wenn du beim ersten Klingeln aufstehst, steigt sie stetig an. |
| An alarm that keeps ringing until you're up | Ein Wecker, der klingelt, bis du aufstehst | Ein Wecker, der so lange klingelt, bis du wirklich aufstehst |
| Rings until you're up | Klingelt, bis du wach bist | Klingelt, bis du aufstehst |
| Ugh, why so early? | Ugh, warum so früh? | Boah, warum so früh? |
| Feeling groggy for ages | Ewig benommen sein | Ewig nicht richtig wach werden |
| Be on time, every time | Pünktlich, jedes Mal | Immer pünktlich sein |
| Work out before my day | Sport vor meinem Tag | Vor dem Tag Sport machen |
| Have quiet time for me | Ruhige Zeit für mich | Ruhige Zeit für mich haben |
| Get ahead on my day | Vorsprung für meinen Tag | Mit Vorsprung in den Tag starten |
| Feel awake, not a zombie | Wach fühlen, kein Zombie | Mich wach fühlen, nicht wie ein Zombie |
| A head start on your day | Ein Vorsprung für deinen Tag | Mit Vorsprung in den Tag |
| Awake, not a zombie | Wach, kein Zombie | Wach statt Zombie |
| Shakes | Schüttler | Wie oft schütteln |
| %lld shakes | {"one": "%lld Schüttler", "other": "%lld Schüttler"} | {"one": "%lld-mal schütteln", "other": "%lld-mal schütteln"} |
| %lld shakes · %@ | {"one": "%lld Schüttler · %@", "other": "%lld Schüttler · %@"} | {"one": "%lld-mal schütteln · %@", "other": "%lld-mal schütteln · %@"} |
| More shakes, more awake. | Mehr Schütteln, wacher. | Je mehr du schüttelst, desto wacher wirst du. |
| Know someone who oversleeps? Send them Gloop and get Rise & Conquer, a brass fanfare that's not in the free plan. | Kennst du jemanden, der verschläft? Schick ihm Gloop und hol dir Rise & Conquer, eine Blechbläser-Fanfare, die es in der Gratisversion nicht gibt. | Kennst du jemanden, der oft verschläft? Schick Gloop weiter und hol dir Rise & Conquer, eine Blechbläser-Fanfare, die es in der Gratisversion nicht gibt. |
| Unlock by inviting a friend | Freischalten durch Einladen eines Freundes | Freischalten, indem du jemanden einlädst |
| Text one friend | Einem Freund schreiben | Jemandem schreiben |
| Hi, I'm %@! I get droopy when you snooze, so let's not. | Hi, ich bin %@! Ich werde schlapp, wenn du schlummerst, also lass es lieber. | Hi, ich bin %@! Wenn du schlummerst, werde ich schlapp. Also lieber nicht. |
| Five minutes. Sure. That's how I end up a puddle. | Fünf Minuten. Klar. So ende ich als Pfütze. | Fünf Minuten. Klar. Und so ende ich als Pfütze. |
| Not bad! Let's make it zero. | Nicht schlecht! Jetzt auf null. | Nicht schlecht! Jetzt noch auf null. |
| That's a whole episode of lying around. Noted. | Eine ganze Folge lang liegen geblieben. Notiert. | Das ist eine ganze Serienfolge im Bett. Notiert. |
| An hour?! I'm melting just hearing that. | Eine Stunde?! Ich schmelze schon beim Zuhören. | Eine Stunde?! Ich schmelze schon, wenn ich das höre. |
| The snooze button is not your friend. I am. | Die Schlummertaste ist nicht dein Freund. Ich schon. | Die Schlummertaste meint es nicht gut mit dir. Ich schon. |
| %@. I'll be there, bouncing. | %@. Ich bin da und hüpfe. | %@. Ich bin da und hüpfe schon. |
| Pick everything that sounds like you. | Wähle alles, was zu dir passt. | Wähle alles, was auf dich zutrifft. |
| That's about %@ hours back every week. | Das sind etwa %@ Stunden jede Woche zurück. | So gewinnst du jede Woche etwa %@ Stunden zurück. |
| That's about %@ hour back every week. | Das sind etwa %@ Stunde jede Woche zurück. | So gewinnst du jede Woche etwa %@ Stunde zurück. |
| You're up. Coffee's yours. | Du bist wach. Der Kaffee gehört dir. | Du bist wach. Der Kaffee wartet. |
| Make sure your %@ alarm rings | Sorge dafür, dass dein Wecker um %@ klingelt | Damit dein Wecker um %@ auch wirklich klingelt |
| Find your %@ and point the camera at it. | Finde deinen %@ und richte die Kamera darauf. | Finde „%@“ und richte die Kamera darauf. |
| Wake up | Aufwachen | Aufstehen |
| Start free trial | Gratis-Test starten | Gratis testen |

## fr (52 changes)

| English | Before | After |
|---|---|---|
| Over an hour. Okay, short re-rings for you, %@. | Plus d’une heure. D’accord, nouvelles sonneries rapprochées pour toi, %@. | (key replaced, see new English) |
| You're up, and ahead. | Tu es debout, et en avance. | (key replaced, see new English) |
| You're up. Glad you set it. | Tu es debout. Bien joué de l’avoir réglé. | (key replaced, see new English) |
| A normal alarm needs four alarms five minutes apart. Gloop needs one alarm with a mission. | Un réveil classique, c’est quatre alarmes à cinq minutes d’intervalle. Avec Gloop, une seule alarme avec une mission suffit. | (key replaced, see new English) |
| Streaks, evolutions and buddies keep you going | Séries, évolutions et buddies te motivent | (key replaced, see new English) |
| Your first name or a nickname. Used in your coach's lines and your profile. | Ton prénom ou un surnom. Utilisé dans les phrases de ton coach et dans ton profil. | (key replaced, see new English) |
| Snoozing drops you back into sleep you can't finish, so every extra ring tends to leave you groggier. One alarm and a short mission gets your brain and body going at once. | Répéter l’alarme te replonge dans un sommeil que tu ne peux pas finir, alors chaque sonnerie de plus te laisse souvent plus groggy. Un seul réveil et une courte mission mettent ton cerveau et ton corps en route d’un coup. | (key replaced, see new English) |
| Set up your math | Configure tes calculs | (key replaced, see new English) |
| Print or pick any code and stick it somewhere out of bed, like the bathroom. | Imprime ou choisis un code et colle-le loin de ton lit, par exemple dans la salle de bain. | (key replaced, see new English) |
| friend | ami | marmotte |
| %@! Love it. We're going to be a great team. | — | %@ ! J’adore. On va faire une super équipe. |
| You're up and ahead of the day. | — | Tu es debout, avec une longueur d’avance sur la journée. |
| You're up. The day is yours. | — | Tu es debout. La journée est à toi. |
| Over an hour? Okay, I'll ring again sooner for you, %@. | — | Plus d’une heure ? D’accord, je resonnerai plus vite pour toi, %@. |
| A normal alarm takes four alarms, five minutes apart. Gloop takes one alarm and a mission. | — | Avec un réveil classique, il faut quatre alarmes à cinq minutes d’intervalle. Avec Gloop, une alarme et une mission suffisent. |
| %@, alarm on | — | %@, réveil activé |
| Every snooze makes me a little droopier. Just saying. | — | À chaque répétition, je m’affaisse un peu plus. Je dis ça, je dis rien. |
| Feet on the floor first. Thinking comes later. | — | D’abord les pieds par terre. On réfléchira après. |
| Nobody ever regretted getting up on time. Especially not me. | — | Personne n’a jamais regretté de s’être levé à l’heure. Surtout pas moi. |
| One mission, then the morning is yours. And I get to bounce. | — | Une mission, et la matinée est à toi. Et moi, je rebondis. |
| Streaks, evolutions and buddies keep you motivated | — | Séries, évolutions et buddies te donnent envie de continuer |
| Your first name or a nickname. Gloop uses it to talk to you and on your profile. | — | Ton prénom ou un surnom. Gloop l’utilise pour te parler et sur ton profil. |
| Snoozing drops you back into sleep you can't finish, so every extra ring tends to leave you groggier. One alarm and a short mission get your brain and body going at once. | — | Répéter l’alarme te replonge dans un sommeil que tu ne peux pas finir : chaque sonnerie de plus te rend souvent plus vaseux. Une seule alarme et une courte mission mettent ton cerveau et ton corps en route d’un coup. |
| Set up your math problems | — | Configure tes calculs |
| Print a code or use one you already have, and stick it far from your bed, like in the bathroom. | — | Imprime un code ou utilise-en un que tu as déjà, et colle-le loin de ton lit, par exemple dans la salle de bain. |
| 10–30 minutes | — | 10 à 30 minutes |
| 30–60 minutes | — | 30 à 60 minutes |
| A quick mission proves you're awake | Une petite mission prouve que tu es réveillé | Une petite mission pour prouver que tu ne dors plus |
| Gloop gets you out of bed and wide awake | Gloop te sort du lit, bien réveillé | Gloop te sort du lit et te réveille pour de bon |
| Feel awake, not a zombie | Te sentir réveillé, pas zombie | Être en forme, pas en mode zombie |
| Awake, not a zombie | Réveillé, pas zombie | En forme, pas en mode zombie |
| I'm ready | Je suis prêt | Je me lance |
| More shakes, more awake. | Plus de secousses, plus réveillé. | Plus tu secoues, plus tu te réveilles. |
| I'm using Gloop: an alarm that keeps ringing until I'm actually out of bed. Want to be my wake-up buddy? | J’utilise Gloop : un réveil qui sonne jusqu’à ce que je sois vraiment sorti du lit. Tu veux être mon pote de réveil ? | J’utilise Gloop : un réveil qui sonne jusqu’à ce que je sorte vraiment du lit. Tu veux qu’on se réveille ensemble ? |
| Unlock by inviting a friend | Débloque-le en invitant un ami | Débloque-le en invitant quelqu’un |
| Text one friend | Écrire à un ami | Écrire à quelqu’un |
| Know someone who oversleeps? Send them Gloop and get Rise & Conquer, a brass fanfare that's not in the free plan. | Tu connais quelqu’un qui ne se réveille jamais ? Envoie-lui Gloop et obtiens Rise & Conquer, une fanfare de cuivres absente de la version gratuite. | Tu connais quelqu’un qui a du mal à se lever ? Envoie-lui Gloop et reçois Rise & Conquer, une fanfare de cuivres absente de la version gratuite. |
| Glad you found me! | Contente que tu m’aies trouvé ! | Ravi que tu m’aies trouvé ! |
| Snooze cycle | Cycle de répétition | Cycle de répétitions |
| Snoozing | Répéter l’alarme | Répétitions |
| GROGGY ZONE | ZONE PÂTEUSE | ZONE VASEUSE |
| Chart: snoozing keeps your energy in a groggy zone; getting up at the first alarm raises it steadily. | Graphique : en répétant l’alarme, ton énergie reste dans une zone pâteuse ; te lever à la première sonnerie la fait monter régulièrement. | Graphique : en répétant l’alarme, ton énergie reste dans une zone vaseuse ; te lever à la première sonnerie la fait monter régulièrement. |
| Ooh, a morning person. I like you already. | Oh, quelqu’un du matin. Je t’aime déjà bien. | Oh, tu es du matin ! Je t’aime déjà bien. |
| You won't sleep through me. I keep coming back. | Tu ne dormiras pas malgré moi. Je reviens toujours. | Avec moi, impossible de continuer à dormir. Je reviens toujours. |
| That's about %@ hours back every week. | Ça fait environ %@ heures de gagnées chaque semaine. | Ça te fait environ %@ heures de gagnées chaque semaine. |
| Getting your mornings ready | Préparation de tes matins | On prépare tes matins |
| Setting your %@ alarm | Réglage de ton réveil de %@ | Réglage de ton réveil à %@ |
| Make sure your %@ alarm rings | Assure-toi que ton réveil de %@ sonne | Pour que ton réveil de %@ sonne vraiment |
| Sleeping through alarms | Ne pas entendre les réveils | Ne pas entendre mon réveil |
| Scrolling my phone | Faire défiler mon téléphone | Scroller sur mon téléphone |
| Find your %@ and point the camera at it. | Trouve ton %@ et pointe l’appareil photo dessus. | Trouve « %@ » et pointe l’appareil photo dessus. |
| Wake up | Se réveiller | Réveil |

## es (47 changes)

| English | Before | After |
|---|---|---|
| Over an hour. Okay, short re-rings for you, %@. | Más de una hora. Vale, repeticiones cortas para ti, %@. | (key replaced, see new English) |
| You're up, and ahead. | Estás en pie, y con ventaja. | (key replaced, see new English) |
| You're up. Glad you set it. | Estás en pie. Menos mal que la pusiste. | (key replaced, see new English) |
| A normal alarm needs four alarms five minutes apart. Gloop needs one alarm with a mission. | Un despertador normal necesita cuatro alarmas separadas por cinco minutos. Gloop necesita una alarma con una misión. | (key replaced, see new English) |
| Streaks, evolutions and buddies keep you going | Rachas, evoluciones y buddies te mantienen en marcha | (key replaced, see new English) |
| Your first name or a nickname. Used in your coach's lines and your profile. | Tu nombre o un apodo. Se usa en las frases de tu coach y en tu perfil. | (key replaced, see new English) |
| Snoozing drops you back into sleep you can't finish, so every extra ring tends to leave you groggier. One alarm and a short mission gets your brain and body going at once. | Posponer te devuelve a un sueño que no puedes terminar, así que cada alarma extra suele dejarte más atontado. Una sola alarma y una misión corta ponen en marcha cerebro y cuerpo a la vez. | (key replaced, see new English) |
| Set up your math | Configura tus operaciones | (key replaced, see new English) |
| Print or pick any code and stick it somewhere out of bed, like the bathroom. | Imprime o elige cualquier código y pégalo lejos de la cama, por ejemplo en el baño. | (key replaced, see new English) |
| friend | amigo | marmota |
| %@! Love it. We're going to be a great team. | — | ¡%@! Me encanta. Vamos a ser un gran equipo. |
| You're up and ahead of the day. | — | Ya estás en pie y con ventaja sobre el día. |
| You're up. The day is yours. | — | Ya estás en pie. El día es tuyo. |
| Over an hour? Okay, I'll ring again sooner for you, %@. | — | ¿Más de una hora? Vale, contigo volveré a sonar antes, %@. |
| A normal alarm takes four alarms, five minutes apart. Gloop takes one alarm and a mission. | — | Con un despertador normal pones cuatro alarmas separadas por cinco minutos. Con Gloop basta una alarma y una misión. |
| %@, alarm on | — | %@, alarma activada |
| Every snooze makes me a little droopier. Just saying. | — | Cada vez que pospones, me desinflo un poco más. Ahí lo dejo. |
| Feet on the floor first. Thinking comes later. | — | Primero los pies en el suelo. Ya pensarás luego. |
| Nobody ever regretted getting up on time. Especially not me. | — | Nadie se ha arrepentido nunca de levantarse a tiempo. Y yo menos. |
| One mission, then the morning is yours. And I get to bounce. | — | Una misión y la mañana es tuya. Y yo, a botar. |
| Streaks, evolutions and buddies keep you motivated | — | Rachas, evoluciones y buddies te mantienen con ganas |
| Your first name or a nickname. Gloop uses it to talk to you and on your profile. | — | Tu nombre o un apodo. Gloop lo usa para hablarte y en tu perfil. |
| Snoozing drops you back into sleep you can't finish, so every extra ring tends to leave you groggier. One alarm and a short mission get your brain and body going at once. | — | Al posponer vuelves a un sueño que no puedes terminar, así que con cada alarma extra te suele costar más espabilar. Una sola alarma y una misión corta ponen en marcha cerebro y cuerpo a la vez. |
| Set up your math problems | — | Configura tus operaciones |
| Print a code or use one you already have, and stick it far from your bed, like in the bathroom. | — | Imprime un código o usa uno que ya tengas, y pégalo lejos de la cama, por ejemplo en el baño. |
| 10–30 minutes | — | 10–30 minutos |
| 30–60 minutes | — | 30–60 minutos |
| A quick mission proves you're awake | Una misión rápida demuestra que estás despierto | Una misión rápida demuestra que ya te has despertado |
| Gloop gets you out of bed and wide awake | Gloop te saca de la cama bien despierto | Gloop te saca de la cama y te quita el sueño de encima |
| Feel awake, not a zombie | Sentirte despierto, no un zombi | Tener energía, no ir como un zombi |
| Awake, not a zombie | Despierto, no un zombi | Con energía, nada de zombis |
| Feeling groggy for ages | Estar atontado mucho rato | Tardar mucho en espabilar |
| I'm ready | Estoy listo | ¡Vamos allá! |
| Be honest. I can tell. | Sé sincero. Se nota. | Di la verdad. Se nota. |
| More shakes, more awake. | Más sacudidas, más despierto. | Cuanto más agites, más te despiertas. |
| Know someone who oversleeps? Send them Gloop and get Rise & Conquer, a brass fanfare that's not in the free plan. | ¿Conoces a alguien que se duerme? Envíale Gloop y consigue Rise & Conquer, una fanfarria de metales que no está en el plan gratuito. | ¿Conoces a alguien a quien le cuesta levantarse? Envíale Gloop y consigue Rise & Conquer, una fanfarria de metales que no está en el plan gratuito. |
| Unlock by inviting a friend | Desbloquéalo invitando a un amigo | Desbloquéalo invitando a alguien |
| Text one friend | Escribir a un amigo | Escribir a alguien |
| I'm using Gloop: an alarm that keeps ringing until I'm actually out of bed. Want to be my wake-up buddy? | Uso Gloop: una alarma que suena hasta que salgo de verdad de la cama. ¿Quieres ser mi compañero de despertar? | Uso Gloop: una alarma que suena hasta que salgo de verdad de la cama. ¿Te apuntas a madrugar conmigo? |
| Ooh, a morning person. I like you already. | Oh, alguien madrugador. Ya me caes bien. | ¡Uy, te gusta madrugar! Ya me caes bien. |
| You won't sleep through me. I keep coming back. | No vas a dormir a pesar de mí. Siempre vuelvo. | Conmigo no hay quien siga durmiendo. Siempre vuelvo. |
| Glad you found me! | ¡Qué bien que me encontraras! | ¡Qué bien que me hayas encontrado! |
| That's about %@ hours back every week. | Eso son unas %@ horas recuperadas cada semana. | Recuperas unas %@ horas cada semana. |
| That's about %@ hour back every week. | Eso es aproximadamente %@ hora recuperada cada semana. | Recuperas alrededor de %@ hora cada semana. |
| Not bad! Let's make it zero. | ¡No está mal! Vamos a por cero. | ¡No está mal! Ahora, a por el cero. |
| That's a whole episode of lying around. Noted. | Un episodio entero tumbado. Anotado. | Eso es un episodio entero sin salir de la cama. Anotado. |
| Find your %@ and point the camera at it. | Encuentra tu %@ y apunta la cámara hacia él. | Busca «%@» y apúntale con la cámara. |

## it (55 changes)

| English | Before | After |
|---|---|---|
| Over an hour. Okay, short re-rings for you, %@. | Più di un’ora. Ok, nuovi squilli ravvicinati per te, %@. | (key replaced, see new English) |
| You're up, and ahead. | Sei in piedi, e in vantaggio. | (key replaced, see new English) |
| You're up. Glad you set it. | Sei in piedi. Meno male che l’hai impostata. | (key replaced, see new English) |
| A normal alarm needs four alarms five minutes apart. Gloop needs one alarm with a mission. | Una sveglia normale ha bisogno di quattro allarmi a cinque minuti l’uno dall’altro. A Gloop ne basta uno con una missione. | (key replaced, see new English) |
| Streaks, evolutions and buddies keep you going | Serie, evoluzioni e buddies ti tengono in carreggiata | (key replaced, see new English) |
| Your first name or a nickname. Used in your coach's lines and your profile. | Il tuo nome o un soprannome. Usato nelle frasi del coach e nel tuo profilo. | (key replaced, see new English) |
| Snoozing drops you back into sleep you can't finish, so every extra ring tends to leave you groggier. One alarm and a short mission gets your brain and body going at once. | Posticipando ricadi in un sonno che non puoi finire, quindi ogni squillo in più tende a lasciarti più intontito. Una sveglia e una breve missione mettono in moto cervello e corpo insieme. | (key replaced, see new English) |
| Set up your math | Configura i tuoi calcoli | (key replaced, see new English) |
| Print or pick any code and stick it somewhere out of bed, like the bathroom. | Stampa o scegli un codice e attaccalo lontano dal letto, per esempio in bagno. | (key replaced, see new English) |
| friend | amico | marmotta |
| %@! Love it. We're going to be a great team. | — | %@! Che bel nome. Faremo una squadra fantastica. |
| You're up and ahead of the day. | — | Sei in piedi e un passo avanti alla giornata. |
| You're up. The day is yours. | — | Sei in piedi. La giornata è tua. |
| Over an hour? Okay, I'll ring again sooner for you, %@. | — | Più di un’ora? Ok, con te tornerò a suonare prima, %@. |
| A normal alarm takes four alarms, five minutes apart. Gloop takes one alarm and a mission. | — | Con una sveglia normale ne imposti quattro, a cinque minuti l’una dall’altra. Con Gloop bastano una sveglia e una missione. |
| %@, alarm on | — | %@, sveglia attiva |
| Every snooze makes me a little droopier. Just saying. | — | Ogni volta che rimandi, mi affloscio un po’ di più. Lo dico e basta. |
| Feet on the floor first. Thinking comes later. | — | Prima i piedi a terra. A pensare ci pensi dopo. |
| Nobody ever regretted getting up on time. Especially not me. | — | Nessuno si è mai pentito di alzarsi in orario. Io meno di tutti. |
| One mission, then the morning is yours. And I get to bounce. | — | Una missione, e la mattina è tua. E io posso rimbalzare. |
| Streaks, evolutions and buddies keep you motivated | — | Serie, evoluzioni e buddies ti danno la carica |
| Your first name or a nickname. Gloop uses it to talk to you and on your profile. | — | Il tuo nome o un soprannome. Gloop lo usa per parlarti e sul tuo profilo. |
| Snoozing drops you back into sleep you can't finish, so every extra ring tends to leave you groggier. One alarm and a short mission get your brain and body going at once. | — | Rimandando la sveglia ricadi in un sonno che non puoi finire, così ogni squillo in più tende a lasciarti la testa più annebbiata. Una sveglia e una breve missione mettono in moto cervello e corpo insieme. |
| Set up your math problems | — | Configura i tuoi calcoli |
| Print a code or use one you already have, and stick it far from your bed, like in the bathroom. | — | Stampa un codice o usane uno che hai già, e attaccalo lontano dal letto, per esempio in bagno. |
| 10–30 minutes | — | 10–30 minuti |
| 30–60 minutes | — | 30–60 minuti |
| Welcome back | Bentornato | Ciao di nuovo |
| A quick mission proves you're awake | Una missione veloce dimostra che sei sveglio | Una missione veloce per dimostrare che non dormi più |
| Gloop gets you out of bed and wide awake | Gloop ti tira giù dal letto ben sveglio | Gloop ti tira giù dal letto e ti sveglia del tutto |
| Feel awake, not a zombie | Sentirti sveglio, non uno zombie | Avere energia, non sembrare uno zombie |
| Awake, not a zombie | Sveglio, non uno zombie | Energia, altro che zombie |
| Feeling groggy for ages | Restare intontito a lungo | Metterci una vita a carburare |
| I'm ready | Sono pronto | Ci sono! |
| Be honest. I can tell. | Sii sincero. Me ne accorgo. | Dimmi la verità. Me ne accorgo. |
| Ooh, a morning person. I like you already. | Oh, una persona mattiniera. Mi stai già simpatico. | Oh, una persona mattiniera. Mi piaci già. |
| Glad you found me! | Che bello che mi hai trovato! | Che bello che tu mi abbia trovato! |
| More | Altro | Di più |
| Fewer | Meno | Di meno |
| Snooze cycle | Ciclo del posticipa | Ciclo di rinvii |
| Snoozing | Posticipare | Rinvii |
| Hitting snooze | Premere posticipa | Premere Posponi |
| Chart: snoozing keeps your energy in a groggy zone; getting up at the first alarm raises it steadily. | Grafico: posticipando, la tua energia resta in una zona di intontimento; alzarti al primo squillo la fa salire in modo costante. | Grafico: rimandando la sveglia, la tua energia resta nella zona di intontimento; alzarti al primo squillo la fa salire in modo costante. |
| The snooze button is not your friend. I am. | Il tasto posticipa non è tuo amico. Io sì. | Il tasto Posponi non è tuo amico. Io sì. |
| Hi, I'm %@! I get droopy when you snooze, so let's not. | Ciao, sono %@! Mi affloscio quando posticipi, quindi evitiamo. | Ciao, sono %@! Mi affloscio quando rimandi la sveglia, quindi meglio di no. |
| More shakes, more awake. | Più scosse, più sveglio. | Più scuoti, più ti svegli. |
| I'm using Gloop: an alarm that keeps ringing until I'm actually out of bed. Want to be my wake-up buddy? | Uso Gloop: una sveglia che suona finché non sono davvero fuori dal letto. Vuoi essere il mio compagno di sveglia? | Uso Gloop: una sveglia che suona finché non sono davvero fuori dal letto. Ti va di svegliarci insieme? |
| Know someone who oversleeps? Send them Gloop and get Rise & Conquer, a brass fanfare that's not in the free plan. | Conosci qualcuno che dorme troppo? Mandagli Gloop e ottieni Rise & Conquer, una fanfara di ottoni non inclusa nel piano gratuito. | Conosci qualcuno che fa fatica ad alzarsi? Invia Gloop e ottieni Rise & Conquer, una fanfara di ottoni non inclusa nel piano gratuito. |
| Unlock by inviting a friend | Sbloccalo invitando un amico | Sbloccalo invitando qualcuno |
| Text one friend | Scrivi a un amico | Scrivi a qualcuno |
| Keep my sound | Tieni il mio suono | Tengo il mio suono |
| That's about %@ hours back every week. | Sono circa %@ ore recuperate ogni settimana. | Recuperi circa %@ ore ogni settimana. |
| That's about %@ hour back every week. | Sono circa %@ ora recuperata ogni settimana. | Recuperi circa %@ ora ogni settimana. |
| You won't sleep through me. I keep coming back. | Con me non dormi oltre. Torno sempre. | Con me non riuscirai a riaddormentarti. Torno sempre. |
| Find your %@ and point the camera at it. | Trova il tuo %@ e inquadralo con la fotocamera. | Trova «%@» e inquadralo con la fotocamera. |

## pt-BR (46 changes)

| English | Before | After |
|---|---|---|
| Over an hour. Okay, short re-rings for you, %@. | Mais de uma hora. Tá, repetições curtas para você, %@. | (key replaced, see new English) |
| You're up, and ahead. | Você está de pé, e na frente. | (key replaced, see new English) |
| You're up. Glad you set it. | Você está de pé. Ainda bem que colocou. | (key replaced, see new English) |
| A normal alarm needs four alarms five minutes apart. Gloop needs one alarm with a mission. | Um despertador comum precisa de quatro alarmes com cinco minutos de intervalo. O Gloop precisa de um alarme com uma missão. | (key replaced, see new English) |
| Streaks, evolutions and buddies keep you going | Sequências, evoluções e buddies mantêm você firme | (key replaced, see new English) |
| Your first name or a nickname. Used in your coach's lines and your profile. | Seu primeiro nome ou um apelido. Usado nas frases do seu coach e no seu perfil. | (key replaced, see new English) |
| Snoozing drops you back into sleep you can't finish, so every extra ring tends to leave you groggier. One alarm and a short mission gets your brain and body going at once. | A soneca joga você de volta num sono que não dá para terminar, então cada toque extra costuma deixar você mais grogue. Um alarme e uma missão curta ligam cérebro e corpo de uma vez. | (key replaced, see new English) |
| Set up your math | Configure suas contas | (key replaced, see new English) |
| Print or pick any code and stick it somewhere out of bed, like the bathroom. | Imprima ou escolha qualquer código e cole longe da cama, como no banheiro. | (key replaced, see new English) |
| friend | amigo | estrela |
| %@! Love it. We're going to be a great team. | — | %@! Adorei. A gente vai formar um ótimo time. |
| You're up and ahead of the day. | — | Você está de pé e na frente do dia. |
| You're up. The day is yours. | — | Você está de pé. O dia é seu. |
| Over an hour? Okay, I'll ring again sooner for you, %@. | — | Mais de uma hora? Tá, com você eu volto a tocar mais rápido, %@. |
| A normal alarm takes four alarms, five minutes apart. Gloop takes one alarm and a mission. | — | Com um despertador comum, você precisa de quatro alarmes com cinco minutos de intervalo. Com o Gloop, basta um alarme e uma missão. |
| %@, alarm on | — | %@, alarme ativado |
| Every snooze makes me a little droopier. Just saying. | — | Cada soneca me deixa um pouco mais murcho. Só avisando. |
| Feet on the floor first. Thinking comes later. | — | Primeiro os pés no chão. Pensar fica pra depois. |
| Nobody ever regretted getting up on time. Especially not me. | — | Ninguém nunca se arrependeu de levantar na hora. Muito menos eu. |
| One mission, then the morning is yours. And I get to bounce. | — | Uma missão e a manhã é sua. E eu fico quicando. |
| Streaks, evolutions and buddies keep you motivated | — | Sequências, evoluções e buddies mantêm sua motivação |
| Your first name or a nickname. Gloop uses it to talk to you and on your profile. | — | Seu primeiro nome ou um apelido. O Gloop usa para falar com você e no seu perfil. |
| Snoozing drops you back into sleep you can't finish, so every extra ring tends to leave you groggier. One alarm and a short mission get your brain and body going at once. | — | A soneca joga você de volta num sono que não dá para terminar, então cada toque extra costuma deixar você mais grogue. Um alarme e uma missão curta ligam cérebro e corpo de uma vez. |
| Set up your math problems | — | Configure suas contas |
| Print a code or use one you already have, and stick it far from your bed, like in the bathroom. | — | Imprima um código ou use um que você já tem e cole longe da cama, por exemplo no banheiro. |
| 10–30 minutes | — | 10–30 minutos |
| 30–60 minutes | — | 30–60 minutos |
| Welcome back | Bem-vindo de volta | Que bom te ver de novo |
| A quick mission proves you're awake | Uma missão rápida prova que você está acordado | Uma missão rápida prova que você já levantou |
| Gloop gets you out of bed and wide awake | O Gloop tira você da cama bem acordado | O Gloop tira você da cama e acaba com o sono |
| Feel awake, not a zombie | Se sentir acordado, não um zumbi | Ter energia, não parecer um zumbi |
| Awake, not a zombie | Acordado, não um zumbi | Com energia, nada de zumbi |
| I'm ready | Estou pronto | Vamos lá! |
| Be honest. I can tell. | Seja sincero. Eu percebo. | Fala a verdade. Eu percebo. |
| More shakes, more awake. | Mais chacoalhadas, mais acordado. | Quanto mais você chacoalha, mais o sono vai embora. |
| I'm using Gloop: an alarm that keeps ringing until I'm actually out of bed. Want to be my wake-up buddy? | Estou usando o Gloop: um alarme que toca até eu sair mesmo da cama. Quer ser meu parceiro de despertar? | Estou usando o Gloop: um alarme que toca até eu sair mesmo da cama. Bora acordar junto comigo? |
| Unlock by inviting a friend | Desbloqueie convidando um amigo | Desbloqueie convidando alguém |
| Text one friend | Mandar mensagem para um amigo | Mandar mensagem para alguém |
| Know someone who oversleeps? Send them Gloop and get Rise & Conquer, a brass fanfare that's not in the free plan. | Conhece alguém que perde a hora? Mande o Gloop e ganhe Rise & Conquer, uma fanfarra de metais que não está no plano gratuito. | Conhece alguém que vive perdendo a hora? Mande o Gloop e ganhe Rise & Conquer, uma fanfarra de metais que não está no plano gratuito. |
| Chart: snoozing keeps your energy in a groggy zone; getting up at the first alarm raises it steadily. | Gráfico: soneca mantém sua energia numa zona de moleza; levantar no primeiro alarme faz ela subir sem parar. | Gráfico: com a soneca, sua energia fica numa zona de moleza; levantar no primeiro alarme a faz subir sem parar. |
| You won't sleep through me. I keep coming back. | Você não vai dormir apesar de mim. Eu sempre volto. | Comigo não tem como continuar dormindo. Eu sempre volto. |
| That's about %@ hours back every week. | Isso são cerca de %@ horas de volta toda semana. | Isso dá umas %@ horas a mais toda semana. |
| That's about %@ hour back every week. | Isso é cerca de %@ hora de volta toda semana. | Isso dá cerca de %@ hora a mais toda semana. |
| Work out before my day | Malhar antes do meu dia | Malhar antes de começar o dia |
| Get up on time, every time — with every mission and alarm you need. | De pé na hora, sempre — com todas as missões e alarmes que você precisa. | De pé na hora, sempre — com todas as missões e alarmes de que você precisa. |
| Find your %@ and point the camera at it. | Encontre seu %@ e aponte a câmera para ele. | Encontre “%@” e aponte a câmera para lá. |

## pt-PT (94 changes)

| English | Before | After |
|---|---|---|
| Over an hour. Okay, short re-rings for you, %@. | Mais de uma hora. Está bem, repetições curtas para você, %@. | (key replaced, see new English) |
| You're up, and ahead. | Está a pé, e na frente. | (key replaced, see new English) |
| You're up. Glad you set it. | Está a pé. Ainda bem que colocou. | (key replaced, see new English) |
| A normal alarm needs four alarms five minutes apart. Gloop needs one alarm with a mission. | Um despertador comum precisa de quatro alarmes com cinco minutos de intervalo. O Gloop precisa de um alarme com uma missão. | (key replaced, see new English) |
| Streaks, evolutions and buddies keep you going | Sequências, evoluções e buddies mantêm você firme | (key replaced, see new English) |
| Your first name or a nickname. Used in your coach's lines and your profile. | O seu primeiro nome ou um apelido. Usado nas frases do seu coach e no seu perfil. | (key replaced, see new English) |
| Snoozing drops you back into sleep you can't finish, so every extra ring tends to leave you groggier. One alarm and a short mission gets your brain and body going at once. | A snooze joga você de volta num sono que não dá para terminar, então cada toque extra costuma deixar você mais grogue. Um alarme e uma missão curta ligam cérebro e corpo de uma vez. | (key replaced, see new English) |
| Set up your math | Configure as suas contas | (key replaced, see new English) |
| Print or pick any code and stick it somewhere out of bed, like the bathroom. | Imprima ou escolha qualquer código e cole longe da cama, como no casa de banho. | (key replaced, see new English) |
| friend | amigo | estrela |
| %@! Love it. We're going to be a great team. | — | %@! Adoro. Vamos formar uma ótima equipa. |
| You're up and ahead of the day. | — | Já está a pé e um passo à frente do dia. |
| You're up. The day is yours. | — | Já está a pé. O dia é seu. |
| Over an hour? Okay, I'll ring again sooner for you, %@. | — | Mais de uma hora? Está bem, para si vou voltar a tocar mais depressa, %@. |
| A normal alarm takes four alarms, five minutes apart. Gloop takes one alarm and a mission. | — | Com um despertador normal, precisa de quatro alarmes com cinco minutos de intervalo. Com o Gloop, basta um alarme e uma missão. |
| %@, alarm on | — | %@, alarme ativado |
| Every snooze makes me a little droopier. Just saying. | — | Cada snooze deixa-me um pouco mais murcho. Fica o aviso. |
| Feet on the floor first. Thinking comes later. | — | Primeiro os pés no chão. Pensar fica para depois. |
| Nobody ever regretted getting up on time. Especially not me. | — | Nunca ninguém se arrependeu de se levantar a horas. Muito menos eu. |
| One mission, then the morning is yours. And I get to bounce. | — | Uma missão e a manhã é sua. E eu fico a saltitar. |
| Streaks, evolutions and buddies keep you motivated | — | Sequências, evoluções e buddies mantêm a motivação |
| Your first name or a nickname. Gloop uses it to talk to you and on your profile. | — | O seu primeiro nome ou uma alcunha. O Gloop usa-o para falar consigo e no seu perfil. |
| Snoozing drops you back into sleep you can't finish, so every extra ring tends to leave you groggier. One alarm and a short mission get your brain and body going at once. | — | Com o snooze, volta a cair num sono que não consegue terminar, por isso cada toque extra costuma deixar ainda mais sono. Um alarme e uma missão curta põem o cérebro e o corpo a funcionar de uma vez. |
| Set up your math problems | — | Configure as suas contas |
| Print a code or use one you already have, and stick it far from your bed, like in the bathroom. | — | Imprima um código ou use um que já tenha e cole-o longe da cama, por exemplo na casa de banho. |
| 10–30 minutes | — | 10–30 minutos |
| 30–60 minutes | — | 30–60 minutos |
| Already have an account? | Já tnuma conta? | Já tem uma conta? |
| Helps us build Gloop for people like you. | Ajuda nós a criar o Gloop para pessoas como você. | Ajuda-nos a fazer o Gloop para pessoas como si. |
| Where did you hear about us? | Onde você ouviu falar dnós? | Onde ouviu falar de nós? |
| We'll write the message for you. | Nós escreve a mensagem para você. | Nós escrevemos a mensagem por si. |
| This device has no camera that Gloop can use. | Este dispositivo não tnuma câmara que o Gloop possa usar. | Este dispositivo não tem uma câmara que o Gloop possa usar. |
| Helps us see which screens and features work and where people get stuck, so we can make Gloop better. Anonymous: a random ID that isn't linked to your account, and never your name, email, alarm names, photos or what you type. Turning it off stops it immediately and forgets the ID. | Ajuda nós a ver quais ecrãs e recursos funcionam e onde as pessoas travam, para melhorar o Gloop. Anônimo: um ID aleatório que não está ligado à a sua conta, e nunca seu nome, e-mail, nomes de alarmes, fotos ou o que você digita. Desativar interrompe na hora e esquece o ID. | Ajuda-nos a ver que ecrãs e funcionalidades funcionam e onde as pessoas ficam bloqueadas, para melhorarmos o Gloop. É anónimo: um ID aleatório que não está ligado à sua conta, e nunca o seu nome, e-mail, nomes de alarmes, fotos ou o que escreve. Ao desativar, para de imediato e o ID é esquecido. |
| Scan a code you stuck in another room. | Digitalize um código que você colou em outro divisão. | Digitalize um código que colou noutra divisão. |
| Scan an item you pick, like your toothbrush or coffee cup. | Digitalize um objeto à a sua escolha, como sua escova de dentes ou chávena de café. | Digitalize um objeto à sua escolha, como a escova de dentes ou a chávena de café. |
| Scan a code in another room, shake it awake, and more to come. | Digitalize um código em outro divisão, abane até acordar, e tem mais por vir. | Digitalize um código noutra divisão, abane até acordar, e há mais a caminho. |
| Your alarm rings through silent mode and Focus, even when the app is closed. | O seu alarme toca mesmo no modo silencioso e em Foco, até com a app fechado. | O seu alarme toca mesmo no modo silencioso e em Foco, até com a app fechada. |
| Welcome back | Bem-vindo de volta | Olá de novo |
| Optional — keeps your progress safe and unlocks buddy features later. | Opcional — protege o seu progresso e libera recursos com amigos depois. | Opcional — guarda o seu progresso e, mais tarde, desbloqueia funcionalidades com amigos. |
| Check your inbox for a reset link. | Confira seu e-mail para o link de redefinição. | Veja o seu e-mail: enviámos uma ligação para repor a palavra-passe. |
| Chart: snoozing keeps your energy in a groggy zone; getting up at the first alarm raises it steadily. | Gráfico: snooze mantém a sua energia numa zona de moleza; levantar no primeiro alarme faz ela subir sem parar. | Gráfico: com o snooze, a sua energia fica numa zona de moleza; levantar-se ao primeiro alarme fá-la subir de forma constante. |
| Rings until you're up | Toca até você levantar | Toca até se levantar |
| So your alarm rings through silent mode and Focus. | Para seu alarme tocar mesmo no modo silencioso e em Foco. | Para que o seu alarme toque mesmo no modo silencioso e em Foco. |
| Ugh, why so early? | Argh, por que tão cedo? | Argh, porquê tão cedo? |
| Work out before my day | Malhar antes do meu dia | Treinar antes de o dia começar |
| Get ahead on my day | Sair na frente no meu dia | Adiantar-me no meu dia |
| Feel awake, not a zombie | Se sentir acordado, não um zumbi | Ter energia, não parecer um zombie |
| Awake, not a zombie | Acordado, não um zumbi | Com energia, nada de zombies |
| Feeling groggy for ages | Ficar grogue por muito tempo | Demorar uma eternidade a despertar |
| Set up later (use Math for now) | Configurar depois (use Matemática por enquanto) | Configurar depois (Matemática por agora) |
| Something that's not in your bedroom: your toothbrush, coffee mug or shoes. | Algo que não está no seu quarto: a sua escova de dentes, caneca de café ou sapatilhas. | Algo que não esteja no seu quarto: a escova de dentes, a caneca de café ou os sapatos. |
| More shakes, more awake. | Mais abanões, mais acordado. | Quanto mais abanar, mais depressa o sono passa. |
| Pick your alarm sound | Escolha seu som de alarme | Escolha o seu som de alarme |
| Tap to hear it. You can add your own sounds later. | Toque para ouvir. Você pode adicionar os seus próprios sons depois. | Toque para ouvir. Pode adicionar os seus próprios sons mais tarde. |
| Keep my sound | Manter meu som | Manter o meu som |
| Text one friend | Mandar mensagem para um amigo | Enviar mensagem a alguém |
| Skip | Pular | Saltar |
| It's yours, free, forever. Want to use it as your alarm? | É o seu, grátis, para sempre. Quer usar como alarme? | É seu, grátis, para sempre. Quer usá-lo como alarme? |
| Know someone who oversleeps? Send them Gloop and get Rise & Conquer, a brass fanfare that's not in the free plan. | Conhece alguém que perde a hora? Mande o Gloop e ganhe Rise & Conquer, uma fanfarra de metais que não está no plano gratuito. | Conhece alguém que adormece sempre? Envie-lhe o Gloop e ganhe Rise & Conquer, uma fanfarra de metais que não está no plano gratuito. |
| Unlock by inviting a friend | Desbloqueie ao convidar um amigo | Desbloqueie ao convidar alguém |
| I'm using Gloop: an alarm that keeps ringing until I'm actually out of bed. Want to be my wake-up buddy? | Estou a usar o Gloop: um alarme que toca até eu sair mesmo da cama. Quer ser o meu parceiro de despertar? | Estou a usar o Gloop: um alarme que toca até eu sair mesmo da cama. Queres acordar comigo? |
| That's about %@ hours back every week. | Isso são cerca de %@ horas de volta todas as semanas. | São cerca de %@ horas recuperadas por semana. |
| That's about %@ hour back every week. | Isso é cerca de %@ hora de volta todas as semanas. | É cerca de %@ hora recuperada por semana. |
| Quiet time that's all yours | Um tempo tranquilo só o seu | Um tempo tranquilo só para si |
| You're up. Go train. | Está a pé. Vamos treinar. | Já está a pé. Vá treinar. |
| You're up. Coffee's yours. | Está a pé. O café é o seu. | Já está a pé. O café é seu. |
| What should I call you? | Como devo chamar você? | Como lhe devo chamar? |
| What should %@ call you? | Como o %@ deve chamar você? | Como lhe deve chamar o %@? |
| Five minutes. Sure. That's how I end up a puddle. | Cinco minutos. Claro. É assim que eu viro uma poça. | Cinco minutos. Claro. É assim que acabo numa poça. |
| A backup for your backup? You only need me now. | Um alarme reserva para seu alarme reserva? Agora você só precisa de mim. | Um alarme de reserva para o seu alarme de reserva? Agora só precisa de mim. |
| Because the day is waiting, %@. I'll make it worth it. | Porque o dia está à tua espera, %@. Vou fazer valer a pena. | Porque o dia está à sua espera, %@. Vou fazer valer a pena. |
| Be honest. I can tell. | Seja sincero. Eu percebo. | Diga a verdade. Eu percebo. |
| Not bad! Let's make it zero. | Nada mal! Vamos zerar. | Nada mal! Agora, vamos chegar ao zero. |
| That's a whole episode of lying around. Noted. | Um episódio inteiro de enrolação. Anotado. | Um episódio inteiro na cama. Anotado. |
| The snooze button is not your friend. I am. | O botão snooze não é o seu amigo. Eu sou. | O snooze não é seu amigo. Eu sou. |
| You won't sleep through me. I keep coming back. | Você não vai dormir apesar de mim. Eu sempre volto. | Comigo não há como continuar a dormir. Volto sempre. |
| Got it. I'll pick a mission that gets you moving. | Entendi. Vou escolher uma missão que faça você se mexer. | Entendido. Vou escolher uma missão que obrigue a mexer. |
| Pick everything that sounds like you. | Escolha tudo que tem a ver com você. | Escolha tudo o que se aplica a si. |
| Pick something you can't ignore. | Escolha algo que você não consiga ignorar. | Escolha algo que não consiga ignorar. |
| An alarm that keeps ringing until you're up | Um alarme que toca até você levantar | Um alarme que toca até se levantar |
| A quick mission proves you're awake | Uma missão rápida prova que está acordado | Uma missão rápida prova que já se levantou |
| What keeps you in bed after your alarm? | O que prende você na cama depois do alarme? | O que impede que se levante depois do alarme? |
| Gloop gets you out of bed and wide awake | O Gloop tira você da cama bem acordado | Com o Gloop, sai da cama e o sono vai-se embora |
| What time do you want to be up? | Que horas você quer estar a pé? | A que horas quer estar a pé? |
| Wake-up time | Horário de acordar | Hora de acordar |
| How much time until you actually get up? | Quanto tempo até você realmente levantar? | Quanto tempo demora a levantar-se de verdade? |
| What would you do with that time back? | O que você faria com esse tempo de volta? | O que faria com esse tempo recuperado? |
| Suggested for you · %@ | Sugerido para você · %@ | Sugerido para si · %@ |
| Get up on time, every time — with every mission and alarm you need. | A pé na hora, sempre — com todas as missões e alarmes que você precisa. | A pé a horas, sempre — com todas as missões e alarmes de que precisa. |
| Weekdays, weekends, gym days — each with its own setup. | Dias úteis, fins de semana, dias de ginásio — cada um com sua configuração. | Dias úteis, fins de semana, dias de ginásio — cada um com a sua configuração. |
| Go to your code and scan it. | Vá até o seu código e digitalize. | Vá até ao seu código e digitalize-o. |
| I'm ready | Estou pronto | Vamos a isso! |
| You're Pro | Você é Pro | Já é Pro |
| Find your %@ and point the camera at it. | Encontre o seu %@ e aponte a câmara para ele. | Encontre “%@” e aponte a câmara para lá. |

## pt-PT (second pass)

| English | Before | After |
|---|---|---|
| Snooze cycle | Ciclo da snooze | Ciclo do snooze |
| Hitting snooze | Apertar snooze | Carregar no snooze |
| Scrolling my phone | Fazer scroll no telemóvel | Andar a fazer scroll no telemóvel |
| Sleeping through alarms | Dormir com o alarme a tocar | Não ouvir o alarme |

## Gender: back to the usual masculine default

| Lang | English | Now |
|---|---|---|
| nl | friend | vriend |
| nl | Unlock by inviting a friend | Ontgrendel door een vriend uit te nodigen |
| nl | Text one friend | Stuur een vriend een bericht |
| de | friend | Freund |
| de | Unlock by inviting a friend | Freischalten, indem du einen Freund einlädst |
| de | Text one friend | Einem Freund schreiben |
| de | Know someone who oversleeps? Send them Gloop and get Rise & Conquer, a brass fanfare that's not in the free plan. | Kennst du jemanden, der oft verschläft? Schick ihm Gloop und hol dir Rise & Conquer, eine Blechbläser-Fanfare, die es in der Gratisversion nicht gibt. |
| de | The snooze button is not your friend. I am. | Die Schlummertaste ist nicht dein Freund. Ich schon. |
| fr | friend | ami |
| fr | A quick mission proves you're awake | Une petite mission prouve que tu es réveillé |
| fr | Gloop gets you out of bed and wide awake | Gloop te sort du lit, bien réveillé |
| fr | Feel awake, not a zombie | Me sentir réveillé, pas comme un zombie |
| fr | Awake, not a zombie | Réveillé, pas zombie |
| fr | I'm ready | Je suis prêt |
| fr | I'm using Gloop: an alarm that keeps ringing until I'm actually out of bed. Want to be my wake-up buddy? | J’utilise Gloop : un réveil qui sonne jusqu’à ce que je sois vraiment sorti du lit. Tu veux être mon pote de réveil ? |
| fr | Unlock by inviting a friend | Débloque-le en invitant un ami |
| fr | Text one friend | Écrire à un ami |
| fr | More shakes, more awake. | Plus de secousses, plus réveillé. |
| fr | Streaks, evolutions and buddies keep you motivated | Séries, évolutions et buddies te gardent motivé |
| es | friend | amigo |
| es | A quick mission proves you're awake | Una misión rápida demuestra que estás despierto |
| es | Gloop gets you out of bed and wide awake | Gloop te saca de la cama bien despierto |
| es | Feel awake, not a zombie | Sentirme despierto, no como un zombi |
| es | Awake, not a zombie | Despierto, no un zombi |
| es | Feeling groggy for ages | Estar atontado mucho rato |
| es | I'm ready | Estoy listo |
| es | Be honest. I can tell. | Sé sincero. Se nota. |
| es | More shakes, more awake. | Más sacudidas, más despierto. |
| es | Know someone who oversleeps? Send them Gloop and get Rise & Conquer, a brass fanfare that's not in the free plan. | ¿Conoces a alguien que siempre se queda dormido? Envíale Gloop y consigue Rise & Conquer, una fanfarria de metales que no está en el plan gratuito. |
| es | Unlock by inviting a friend | Desbloquéalo invitando a un amigo |
| es | Text one friend | Escribir a un amigo |
| es | I'm using Gloop: an alarm that keeps ringing until I'm actually out of bed. Want to be my wake-up buddy? | Uso Gloop: una alarma que suena hasta que salgo de verdad de la cama. ¿Quieres ser mi compañero de despertar? |
| es | Ooh, a morning person. I like you already. | ¡Uy, eres madrugador! Ya me caes bien. |
| es | You won't sleep through me. I keep coming back. | Conmigo no te vas a quedar dormido. Siempre vuelvo. |
| es | Snoozing drops you back into sleep you can't finish, so every extra ring tends to leave you groggier. One alarm and a short mission get your brain and body going at once. | Al posponer vuelves a un sueño que no puedes terminar, así que cada alarma extra suele dejarte más atontado. Una sola alarma y una misión corta ponen en marcha cerebro y cuerpo a la vez. |
| es | Streaks, evolutions and buddies keep you motivated | Rachas, evoluciones y buddies te mantienen motivado |
| it | friend | amico |
| it | Welcome back | Bentornato |
| it | A quick mission proves you're awake | Una missione veloce dimostra che sei sveglio |
| it | Gloop gets you out of bed and wide awake | Gloop ti tira giù dal letto ben sveglio |
| it | Feel awake, not a zombie | Sentirmi sveglio, non uno zombie |
| it | Awake, not a zombie | Sveglio, non uno zombie |
| it | Feeling groggy for ages | Restare intontito a lungo |
| it | I'm ready | Sono pronto |
| it | Be honest. I can tell. | Sii sincero. Me ne accorgo. |
| it | Ooh, a morning person. I like you already. | Oh, una persona mattiniera. Mi stai già simpatico. |
| it | I'm using Gloop: an alarm that keeps ringing until I'm actually out of bed. Want to be my wake-up buddy? | Uso Gloop: una sveglia che suona finché non sono davvero fuori dal letto. Vuoi essere il mio compagno di sveglia? |
| it | Know someone who oversleeps? Send them Gloop and get Rise & Conquer, a brass fanfare that's not in the free plan. | Conosci qualcuno che dorme sempre troppo? Mandagli Gloop e ottieni Rise & Conquer, una fanfara di ottoni non inclusa nel piano gratuito. |
| it | Unlock by inviting a friend | Sbloccalo invitando un amico |
| it | Text one friend | Scrivi a un amico |
| it | Snoozing drops you back into sleep you can't finish, so every extra ring tends to leave you groggier. One alarm and a short mission get your brain and body going at once. | Rimandando la sveglia ricadi in un sonno che non puoi finire, così ogni squillo in più tende a lasciarti più intontito. Una sveglia e una breve missione mettono in moto cervello e corpo insieme. |
| pt-BR | friend | amigo |
| pt-BR | Welcome back | Bem-vindo de volta |
| pt-BR | A quick mission proves you're awake | Uma missão rápida prova que você está acordado |
| pt-BR | Gloop gets you out of bed and wide awake | O Gloop tira você da cama bem acordado |
| pt-BR | Feel awake, not a zombie | Me sentir acordado, e não um zumbi |
| pt-BR | Awake, not a zombie | Acordado, não um zumbi |
| pt-BR | I'm ready | Estou pronto |
| pt-BR | Be honest. I can tell. | Seja sincero. Eu percebo. |
| pt-BR | More shakes, more awake. | Mais chacoalhadas, mais acordado. |
| pt-BR | I'm using Gloop: an alarm that keeps ringing until I'm actually out of bed. Want to be my wake-up buddy? | Estou usando o Gloop: um alarme que toca até eu sair mesmo da cama. Quer ser meu parceiro de despertar? |
| pt-BR | Unlock by inviting a friend | Desbloqueie convidando um amigo |
| pt-BR | Text one friend | Mandar mensagem para um amigo |
| pt-BR | Streaks, evolutions and buddies keep you motivated | Sequências, evoluções e buddies mantêm você motivado |
| pt-PT | friend | amigo |
| pt-PT | Welcome back | Bem-vindo de volta |
| pt-PT | A quick mission proves you're awake | Uma missão rápida prova que está acordado |
| pt-PT | Gloop gets you out of bed and wide awake | O Gloop tira-o da cama bem acordado |
| pt-PT | Feel awake, not a zombie | Sentir-me acordado, não um zombie |
| pt-PT | Awake, not a zombie | Acordado, não um zombie |
| pt-PT | I'm ready | Estou pronto |
| pt-PT | Be honest. I can tell. | Seja sincero. Eu percebo. |
| pt-PT | More shakes, more awake. | Mais abanões, mais acordado. |
| pt-PT | Text one friend | Enviar mensagem a um amigo |
| pt-PT | Unlock by inviting a friend | Desbloqueie ao convidar um amigo |
| pt-PT | I'm using Gloop: an alarm that keeps ringing until I'm actually out of bed. Want to be my wake-up buddy? | Estou a usar o Gloop: um alarme que toca até eu sair mesmo da cama. Queres ser o meu parceiro de despertar? |
| pt-PT | Got it. I'll pick a mission that gets you moving. | Entendido. Vou escolher uma missão que o ponha a mexer. |
| pt-PT | What keeps you in bed after your alarm? | O que o prende na cama depois do alarme? |
| pt-PT | Snoozing drops you back into sleep you can't finish, so every extra ring tends to leave you groggier. One alarm and a short mission get your brain and body going at once. | O snooze devolve-o a um sono que não consegue terminar, por isso cada toque extra costuma deixá-lo mais ensonado. Um alarme e uma missão curta põem o cérebro e o corpo a funcionar de uma vez. |
| pt-PT | Streaks, evolutions and buddies keep you motivated | Sequências, evoluções e buddies mantêm-no motivado |
