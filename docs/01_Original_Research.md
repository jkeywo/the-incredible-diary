# Original research — Interactive Story Structures

Exported 28 September 2026 from the supplied saved conversation. The original request and complete research response follow without summarisation. HTML has been converted to Markdown, retaining accessible source links and tables. Interface controls and research-status badges are omitted. Historical references to the hotel and whole-voyage finale are preserved, not updated to the current design.

---

## User — original request

We played the Sexy Brutale video game and was disappointed that in the end you didn't have to use everything you discovered to save everyone in a single run. I'd like to design that game - pixel art, weird hotel, a branching paths of intersecting AI behaviour base of story blocks that trigger on preconditions when the conditions are correct, and a protagonist who can affect events in a time loop.
first do some deep research into appropriate games and interactive story structures.

---

## Assistant — original research

The payoff you wanted is more specific than a time-loop mystery: **learn how several individually solvable situations interact, then use that understanding to make everyone survive the same run.**

That distinction matters. Discovering every branch, saving each character once, and constructing a day in which all those rescues coexist are three different challenges. Your proposed game is principally about the third.

The research points towards a combination of **authored conditional scenes, reproducible character behaviour, and a final problem of coordinating actions**. The closest references are **Elsinore** for reactive narrative, **Eternal Threads** for interdependent rescues, **Deathloop** for the learn-then-execute structure, and **Overboard!** for a compact social world that remembers what the player does.

*The discussion below covers mechanics and narrative structures, without revealing ending twists or specific puzzle solutions.*

# 1. The most useful game references

## Elsinore: the closest match for the underlying narrative system

In **Elsinore**, Ophelia repeatedly experiences the events surrounding *Hamlet*, attempting to change what happens through her interactions with the other characters. Its official description emphasises a real-time simulation in which characters have needs, desires, schedules and plans, and events are selected in response to the player’s interventions. That is unusually close to your proposed combination of a time loop and intersecting AI behaviour. [Steam Store](https://store.steampowered.com/app/512890/Elsinore/?l=english)

More importantly, designer Connor Fallon documented a revealing development problem. The team initially organised interactions around entering scenes and choosing branches. Once the player could retain knowledge between loops and tell people things at different times, the possible combinations became difficult to author. The response was to make discovered information—“hearsay”—a reusable means of intervention. Players influence the circumstances leading into scenes rather than receiving a completely different set of choices inside every possible version of them. In that development account, most scenes became unalterable once underway. [Game Developer](https://www.gamedeveloper.com/design/interacting-with-the-world-of-elsinore)

**The useful lesson is that information can be an action, not merely a collectible.** Learning about an affair, a threat or a hidden passage matters because somebody can be told, persuaded, distracted or exposed.

For your hotel, that suggests actions such as telling the porter that a particular guest is in danger, giving a musician a reason to miss their performance, or revealing evidence that changes whom the manager trusts. Each intervention changes the conditions under which later scenes occur.

There is also a useful warning in Elsinore’s approach. Restricting intervention during scenes makes authoring more manageable, but your game may need more physical interference. That makes **which scenes are interruptible, and what interruption means**, an important design decision—not an implementation detail to postpone.

## Eternal Threads: the closest match for “make all the rescues coexist”

**Eternal Threads** is particularly relevant to the ending you wanted. Its premise is to alter decisions during the week preceding a house fire so that six people survive. Simply preventing the fire is prohibited by the fiction. The player instead changes earlier choices, with alterations adding, removing or replacing subsequent events. Changes at different points interact, and individual characters have multiple possible survival outcomes. [store.steampowered.com](https://store.steampowered.com/app/1046790/Eternal_Threads/)

This is the distinction your idea needs: **a successful local intervention is not necessarily part of a successful overall solution**.

Its main difference is the player’s relationship to time. Eternal Threads lets the player inspect and edit a timeline; it is not principally about occupying one body and physically carrying out a tightly constrained rescue plan. [store.steampowered.com](https://store.steampowered.com/app/1046790/Eternal_Threads/)

I would therefore borrow its **interacting consequences**, not its entire interaction model. Your game could ask the player to discover a compatible set of changes and then execute them through movement, conversation, objects and delegation.

A promising consequence is that an early rescue can be valid but inefficient. The player may initially save somebody through a time-consuming emergency response, then later discover an earlier intervention that prevents the emergency entirely. That creates genuine learning rather than merely accumulating more tasks.

## Deathloop: the strongest reference for the final execution promise

**Deathloop** makes the overall objective explicit: eliminate eight targets before the day resets. Learning their schedules and relationships provides the basis for changing the circumstances in which those targets can be reached. It also contains persistent weapons and abilities, so its progression is not exclusively knowledge-based. [PlayStation](https://www.playstation.com/en-us/games/deathloop/)

A report of narrative designer Pawel Kroenke’s GDC presentation describes a central intention: players should formulate a plan from acquired knowledge and then execute it. The team also treated the relationship between player knowledge and protagonist knowledge as a deliberate narrative problem, rather than allowing the protagonist to understand crucial things that the player had not learned. [Game Developer](https://www.gamedeveloper.com/marketing/using-time-loop-logic-to-shape-deathloop-s-narrative)

For your game, the inverse is compelling: instead of aligning circumstances to kill everyone, align them to keep everyone alive.

The important borrowing is **the explicit overarching objective**, not necessarily its combat, equipment progression or particular solution structure. The player should understand early that the hotel can, in principle, be saved in one run. Otherwise, a late demand to combine all the rescues risks feeling like an unexpected examination.

I would also distinguish two types of final challenge:

**Executing a known sequence** tests memory and timing. **Coordinating a understood system** tests whether the player knows which actions are essential, which can move, and which other characters can perform. Your description sounds much more like the second.

## Overboard! and Expelled!: compact social worlds with persistent consequences within a run

In **Overboard!**, the player has committed a murder and has a limited window to avoid being exposed. Other characters move and act independently, remembering what they witness and hear. Eavesdropping, lying, blackmail, theft and the handling of evidence form part of the interaction space. [Inkle Studios](https://www.inklestudios.com/overboard/)

**Expelled!** applies a related approach to a school-day accusation. Its official description again emphasises a “clockwork” narrative in which characters remember observations, and repeated play helps the player discover a better outcome. These are replayable scenarios rather than necessarily fictional supernatural loops, but their structure is directly relevant. [Inkle Studios](https://www.inklestudios.com/expelled/)

Their value is **scope discipline**. A small location and limited period can support considerable complexity when the same people, objects and accusations recur in different combinations.

For your hotel, the crucial implication is that the world cannot consist only of objective facts. It needs distinctions such as:

> The medicine has been stolen.
> The doctor knows it has been stolen.
> The doctor believes the bellhop stole it.
> The bellhop knows who actually took it.

Those are different conditions, capable of producing different behaviour. A room full of plausible misunderstandings can provide more useful narrative complexity than a much larger map.

## Outer Wilds: how knowledge becomes progression

**Outer Wilds** offers a different but essential reference. Its solar system changes over the course of a repeating period: locations become accessible or inaccessible, and understanding those changes is part of exploration. The official description centres the experience on investigating mysteries within that changing world. [Mobius Digital](https://www.mobiusdigitalgames.com/outer-wilds.html)

Narrative designer Kelsey Beachum’s GDC talk, *Sparking Curiosity-Driven Exploration Through Narrative in Outer Wilds*, specifically addresses motivating players through curiosity rather than assigned missions, and connecting nonlinear narrative to player-directed progression. [GDC Vault](https://gdcvault.com/play/1027008/Independent-Games-Summit-Sparking-Curiosity)

The transfer to your game is not simply “include a notebook.” It is to make discoveries change what the player believes they can accomplish.

Learning that the laundry lift can carry a person, that a guest always leaves their door unlocked during a particular appointment, or that a seemingly threatening character is actually trying to prevent a disaster should open possibilities without requiring an explicit ability unlock.

For the final run, this suggests a useful standard: **the player should feel more powerful because the hotel has become intelligible**, not merely because the protagonist has acquired more supernatural powers.

## The Last Express and The Invisible Hours: a world that continues outside your attention

**The Last Express** combines a contained train setting, real-time events, reactive characters and interconnected information puzzles. Its official creator archive describes multiple story strands unfolding during the journey rather than a sequence of isolated scenes waiting for the player. [Jordan Mechner](https://www.jordanmechner.com/en/library/the-last-express-site/gameplay.html)

**The Invisible Hours** presents interwoven stories in a mansion, with the player acting as an invisible observer who can follow different characters and investigate the environment. Its official framing is immersive theatre: the player chooses what to attend to within a larger unfolding production. [Steam Store](https://store.steampowered.com/app/582560/The_Invisible_Hours/)

Together, they expose an important distinction:

> **Choosing which events to witness is not the same as changing which events occur.**

Your game needs both. Observation gives the player a partial account of the hotel; intervention changes that account on subsequent loops.

The architectural implication is significant. A crucial argument cannot simply wait until the player enters its room unless that waiting has an in-world explanation. Events elsewhere must genuinely advance. The player should be able to arrive after something happened and reconstruct it from changed positions, missing objects, damaged rooms or subsequent conversations.

That makes absence informative rather than making it feel as though the player missed the only permitted cutscene.

## Innkeep: an unusually direct reference for the hotel’s everyday interactions

The **Innkeep** developer’s account of its conversation system is particularly pertinent. It describes combining ordinary innkeeping work with talking, eavesdropping and discovering information about guests. Its proposed conversation structure uses storylets and character states: a guest’s comfort, mood or drunkenness can make particular interactions possible. The developer also discusses conversations changing a guest’s mood, prompting another person to respond, and thereby creating a further conversation that the player can overhear. [Innkeep](https://innkeepgame.com/conversations-and-clues-in-innkeep/)

That is a small but important causal chain:

**Player interaction → changed character state → another character reacts → new information becomes available.**

The same account considers how dialogue should consume time without requiring the player to read under pressure, and how visible explanations for available options can support intentional play. This is a development account, rather than proof that every described feature survived unchanged into a finished release. [Innkeep](https://innkeepgame.com/conversations-and-clues-in-innkeep/)

The lesson for your game is to make hotel work part of the narrative machinery. Serving a drink, moving luggage, changing a seating arrangement or preparing a room can be a means of altering behaviour—not housekeeping chores attached to an otherwise separate mystery.

## Additional references with specific lessons

| Reference | What it contributes | Important difference |
| --- | --- | --- |
| **The Séance of Blake Manor** | A supernatural hotel mystery built around interviewing guests, recording deductions, exploring the building and being present for events at the right time. Its official description makes time expenditure central. | Useful for setting and investigation structure; not presented as a time-loop game. Its visual style is comic-book-inspired rather than your proposed pixel art. [Raw Fury](https://rawfury.com/games/the-seance-of-blake-manor/) |
| **Ghost Trick: Phantom Detective** | Object possession, manipulation and rewinding time make physical interventions central to solving supernatural mysteries. | Useful for defining a small, expressive intervention vocabulary rather than for the full ensemble simulation. [Steam Store](https://store.steampowered.com/app/1967430/Ghost_Trick_Phantom_Detective/?l=english) |
| **Tragedy Looper** | This board game makes hidden roles, information and preconditions determine whether scheduled tragedies occur. The protagonists can win by surviving a loop without triggering its loss conditions. | A human mastermind actively opposes them, and some scripts allow a separate final deduction victory. Neither should be imported automatically into a reproducible rescue simulation. [1J1JU](https://cdn.1j1ju.com/medias/4a/87/06-tragedy-looper-rulebook.pdf) |

Tragedy Looper is especially worth examining away from the computer. It isolates the question: **what must players know about causes, rather than merely about scheduled events, to prevent a tragedy?**

# 2. Interactive story structures that fit this game

## A conditional scene network, not one enormous branching tree

Emily Short’s useful definition of a **storylet** consists of authored content, conditions governing when it is available, and effects on the game state. The content need not be a paragraph: it can contain a scene, a local choice sequence or another kind of presentation. Storylets can be assembled into several larger structures, including branches, loops and reconverging paths. [Emily Short's Interactive Storytelling](https://emshort.blog/2019/11/29/storylets-you-want-them/)

This closely matches your “story blocks that trigger on preconditions,” with one crucial correction:

**A condition becoming true should usually make a block eligible, not automatically force it to happen immediately.**

Consider an original hotel example:

> **The doctor investigates a reported poisoning.**
> It becomes possible when the doctor has received a credible report, knows where to go, can reach the location, and is not committed to something more urgent.
> Beginning the response changes her current plan. Successfully treating the victim changes their condition and may consume a resource. Being interrupted produces a different outcome.

The report, journey and treatment need not be one indivisible block. Nor should “doctor dispatched” immediately mean “victim saved.”

This structure avoids writing a separate global branch for every combination of earlier events. But local branches remain useful: a conversation can still have choices, and a confrontation can still have several authored outcomes.

**Storylets are a way to organise possibilities, not a guarantee that those possibilities form a coherent game.**

## Eligibility, selection and execution are separate problems

Short distinguishes quality-based structures, which expose content according to state, from salience-based approaches, which select an appropriate response from a set of possibilities. The latter is especially useful for context-sensitive reactions: a highly specific response can replace a generic one when its conditions apply. [Emily Short's Interactive Storytelling](https://emshort.blog/2016/04/12/beyond-branching-quality-based-and-salience-based-narrative-structures/)

For your project, three questions should remain distinct:

| Question | Example |
| --- | --- |
| **Eligibility:** Could this happen now? | The porter has learned that someone is trapped. |
| **Selection:** Does it take precedence? | Rescuing the guest matters more than delivering luggage. |
| **Execution:** What actually happens? | The porter obtains a key, travels to the room and attempts entry. |

A character learning three facts at once should not start three incompatible scenes.

Research on the storylet design space also distinguishes approaches that bind content to suitable actors or objects, rather than relying entirely on fixed global flags. This supports reusable patterns such as an accusation with an accuser, accused person and witness. [Max Kreminski](https://mkremins.github.io/publications/Storylets_SketchingAMap.pdf)

For the hotel, I would use that selectively. Generic patterns can handle carrying, witnessing, interrupting and seeking help. Major emotional confrontations should retain enough specificity that the characters do not feel interchangeable.

## Agent-centred storytelling: characters participate rather than merely trigger

**Versu**, described by Richard Evans and Emily Short, provides another important model. Its autonomous characters participate in **social practices**: structured situations that offer actions to people occupying different roles. Characters choose among those actions using utility-based reasoning. Several practices can coexist—for example, eating, discussing politics and flirting during the same dinner. [Computer Science UK](https://cs.uky.edu/~sgware/reading/papers/evans2014versu.pdf)

The relevant principle is that an interaction belongs neither wholly to one character nor wholly to an omnipotent script.

An argument needs participants. A theft needs a thief, an object and an opportunity. A rescue may require a rescuer, a victim, a route and equipment. These are **coordinated situations involving several entities**.

My inference for your game is that character plans and story blocks should complement each other:

- Character behaviour determines what people are trying to do.
- Story blocks describe meaningful encounters and consequences.
- A coordinating system ensures those encounters are physically possible.

That coordinating system might reserve participants and objects during a short scene. Otherwise, the same waiter could be assigned simultaneously to serve dinner and witness an incident downstairs.

The trade-off is between interruptibility and authoring cost. Short committed actions, explicit interruptions and clear fallback behaviour seem more promising than either fully uninterruptible cutscenes or unrestricted interruption at every animation frame.

## Narrative planning: causal validity is not enough

**StoryAssembler**, presented by Garbe and colleagues, combines authored fragments with preconditions and effects, shared state, and planning towards narrative goals. Its architecture includes state-space planning and hierarchical decomposition, showing how authored material can be assembled in response to changing circumstances rather than through one fixed sequence. It is a research system for dynamic choice-driven narratives, not a ready-made hotel simulation. [Max Kreminski](https://mkremins.github.io/publications/StoryAssembler.pdf)

A complementary distinction comes from Riedl and Young’s *Narrative Planning: Balancing Plot and Character*. Their work separates a causally valid plot from one in which characters’ actions are understandable as intentional behaviour. A sequence can achieve the author’s desired outcome while still making its participants appear unmotivated. [arXiv](https://arxiv.org/abs/1401.3841)

That distinction is central here.

A planner might discover that the gardener can save the singer by taking a key, crossing the kitchen and unlocking a door. But why would the gardener do that? Has anyone told them about the danger? Do they believe it? Are they willing to help? Do they know where the key is?

For this project, I would initially investigate planning primarily as an **authoring and validation tool**. It can help identify a possible all-survive route, missing prerequisites and contradictory resource demands. Runtime characters can then follow a more bounded, legible set of intentions.

I would be wary of an online narrative planner continually rearranging events to force a dramatic result. That could undermine the player’s ability to learn reliable causes.

## Drama management needs limits

My recommendation is to distinguish **presentation management** from **outcome manipulation**.

A presentation system can avoid overlapping important dialogue, prioritise an urgent reaction, or choose a fitting line when the player arrives. It should not secretly move a disaster because the player was doing too well, or make a newly invented obstacle invalidate a correct plan.

The central promise should be:

> **The hotel responds to what happened, not to whether the author currently wants more tension.**

None of this requires an LLM generating dialogue or deciding character behaviour. The core design problem is defining state, intentions, conditions, time and consequences. Generated prose would be a separate choice, not a prerequisite for the structure you described.

# 3. What this research implies for your particular game

The following are design recommendations drawn from the comparison, rather than claims about how every reference game works.

## Make the world reproducible, without making it rigid

**Deterministic does not mean fixed.** It means that the same relevant causes produce the same effects.

A guest can behave differently because their appointment was cancelled, because they heard a warning, or because someone took their key. They should not make a different critical decision simply because a random roll changed between otherwise identical loops.

The player should eventually learn:

> “She goes to the ballroom because she expects to meet her brother.”

That is more useful than merely learning:

> “She stands in the ballroom at 8:40.”

The first can generate deductions about unobserved situations. The second mostly supports memorising a timetable.

I would keep four kinds of information separate: **physical world state, each character’s beliefs, the protagonist’s retained knowledge, and the evidence recorded for the player**. Seeing something in a previous loop does not make another character believe it in this one.

## Design backwards from a genuinely achievable final run

The success condition must concern the completed run:

> **Everyone is alive and safe through the relevant endpoint.**

It must not mean that every character has been saved at least once, or that everyone happened to be alive at some intermediate moment before a delayed consequence killed them.

This suggests designing an initial complete rescue plan relatively early, then building the mysteries through which players discover its components.

The most interesting structure is likely to be a **partial-order plan**: some things must happen before others, but not every action has one mandatory position. For example, the player may need to convince the electrician before a performance begins, while having freedom over when to obtain evidence or redirect another guest.

A useful original example:

A doctor can reach either of two emergencies, but not both before their deadlines. Early loops teach the player how to summon her to each. Later, the player discovers how to prevent the first emergency by stopping poisoned wine from being served. That frees the doctor to attend the second. Persuading a staff member to withhold the wine becomes the connection between the two subplots.

This is stronger than simply requiring the player to perform two familiar rescues faster. **The combined solution changes the approach.**

There is one important caveat: do not protect the intended complexity through arbitrary prohibitions. When a sensible global solution exists—evacuating the hotel, cancelling the event, cutting a shared power supply—the fiction and systems should either support it or clearly establish why it is insufficient.

## Interpret “use everything” as synthesis, not exhaustive collection

I would aim for **every major storyline to contribute to the final solution**, not every discovered fact.

Some discoveries can provide alternative routes, explain motives, clarify misleading evidence or deepen the characters. Requiring every diary entry and optional conversation risks turning understanding into checklist completion.

The final run should reward three forms of mastery:

**Causal mastery:** knowing what must change and why.

**Social mastery:** knowing who can help, what they believe, and what would persuade them.

**Practical mastery:** knowing how to arrange those changes within the available time.

This also provides a strong role for delegation. A character can save another character while the protagonist handles a different crisis. The player still earned that outcome by creating the right conditions.

Crucially, the delegated action should happen **within the final loop**. It should not be a permanent bypass granted because the player solved that subplot previously.

## Make the hotel’s mundane systems carry the weirdness

For this concept, the hotel is more useful as a set of shared systems than as a collection of themed puzzle rooms.

Keys, staff passages, room service, a switchboard, performances, luggage, kitchens, lifts and maintenance all create reasons for characters to cross paths. Supernatural rules can then alter those same systems.

A ghost who can only speak through an occupied room’s telephone is more integrated with the setting than a ghost who provides an unrelated riddle. A lift that visits a different floor during the séance creates a rule that can intersect with deliveries, appointments and escape routes.

The weirdness should remain learnable. Repetition gives the player opportunities to test strange rules; it should not become an excuse for exceptions whenever the plot needs them.

For pixel art, I would prioritise **observable state changes** over sheer decorative detail: readable silhouettes, recognisable carried objects, clear door states, distinctive room layouts and visible changes in activity. The player needs to notice that somebody took a bag, changed clothes or abandoned a task.

I would not assume that pixel art makes the overall project cheap. The expensive part of this concept is likely to be the number of meaningful interactions that must be authored, communicated and tested.

## Provide evidence, not an omniscient solution graph

The notebook or timeline should distinguish between what the player observed, what somebody claimed, and what the player currently predicts.

“Guest entered the lift at 8:15” is an observation. “Guest always takes the lift at 8:15” is a hypothesis. “Guest takes the lift because the stairs are locked” is a causal explanation, possibly still untested.

That distinction helps avoid an interface that silently supplies the entire solution.

Failure feedback matters equally. After a changed plan fails, the player needs some route to understanding why: a witness, a changed destination, a missing object, an overheard complaint or a visible interruption. Otherwise, intersecting behaviour becomes indistinguishable from arbitrary punishment.

The final run also needs generous execution ergonomics. Fast-forwarding, understandable travel costs and useful margins can preserve planning difficulty without demanding unnecessarily precise inputs. Advancing time should advance the same underlying world, not jump to a different approximation of it.

## Treat interaction complexity as the main production risk

Storylets reduce the need to duplicate entire branches. **They do not remove the combinations of states that require testing.**

I would therefore favour a relatively sparse interaction network: each character has a few meaningful relationships and dependencies, while a small number of shared hotel systems connect the larger picture. Not every person needs a bespoke response to every object and every revelation.

Before expanding the cast, the development tools should make it possible to answer:

> Why did this scene occur?
> Why did another scene not occur?
> What changed this character’s plan?
> Who currently owns this object or occupies this resource?
> What earlier action caused this failure?

A recorded successful run is also valuable as a regression test. If changing a conversation makes the all-survive route impossible, that should be detectable without repeatedly playing the whole game by hand.

Automated tests will not prove that the mystery is understandable or emotionally effective. Those still require playtesting. They can, however, catch the more basic failure of a carefully designed solution no longer being executable.

# 4. The direction I would take from this research

The strongest combination is:

**Elsinore’s information-driven interventions, Overboard!’s character knowledge and memory, Eternal Threads’ interacting rescues, and Deathloop’s explicit requirement to convert learning into one successful execution.** Their relevant mechanics and structures are documented in the developer and official sources discussed above. [Game Developer+3](https://www.gamedeveloper.com/design/interacting-with-the-world-of-elsinore)

Underneath that, I would investigate **authored storylets over a reproducible world, with goal-driven characters and explicit coordination for shared scenes**. I would not start with an enormous branching script, an unrestricted emergent narrative simulation, or a system that generates whatever event seems dramatic next.

The first prototype should test the interaction that none of the individual ingredients guarantees:

**Can saving one person consistently and understandably change another person’s situation—and can the player discover a better plan that saves both?**

One hotel wing, three endangered characters and a small number of interconnected incidents would be enough. It should contain individually discoverable rescues, a conflict between the obvious approaches, and at least one valid combined solution. Art polish, a large cast and a complete mythology can wait until that structure produces satisfying deductions.

The largest unresolved design choice is the protagonist’s agency: an unseen manipulator, a visible guest, and a member of staff imply very different ways to alter events. That choice should come before designing a large library of story blocks.

**The aim is not to make the player watch every branch. It is to let them understand the hotel well enough to create one day in which everyone survives.**

