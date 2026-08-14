# Writing conventions

House style for issues, status reports, and internal engineering documents. Each rule has a reason;
where the reason does not apply, neither does the rule.

---

## No em-dashes

Use commas, parentheses, or restructure the sentence.

## No first or third person framing in issue and status prose

Write the state of the world, not your relationship to it.

| Instead of | Write |
|---|---|
| "I want to fix the failing drives" | "The storage node has drives that are failing or have already failed." |
| "We should set up monitoring" | "There is no centralised visibility into the infrastructure." |
| "I think the recordsize is wrong" | "Recordsize is set to 128K on a dataset holding 8K database pages." |

Two reasons. State-describing prose stays accurate when the author changes team, where "I want"
becomes an orphaned preference nobody can evaluate. And it separates the observation from the person
who made it, so the observation can be argued with on its merits.

### The exception

First person is right where the sentence genuinely is a personal ask: a blocker you are raising, or a
decision you need from someone. Depersonalising those turns a request into a statement, and
statements do not get answered.

- Correct in a status report's Blockers section: "I need access to the backup host before I can
  verify the restore."
- Wrong in an issue description: "I need someone to look at the backup host."

## No priority language in prose

Priority is a field. An issue whose description argues for its own urgency competes with the field
that records it, and the two drift apart the moment either is updated.

Remove "this is critical", "high priority", "urgent" from the body. Set the field instead. If the
urgency needs justifying, state the consequence and let the reader draw the conclusion: "an inactive
replication slot retains WAL indefinitely and will fill the primary's disk" carries more weight than
"this is a P1".

## Prose for narrative, bullets for lists

A bulleted list of full sentences is prose that has been chopped up, and it reads worse than the
paragraph it came from. It also hides the connections between items -- the reason B follows from A
disappears when both become bullets.

Use bullets for genuinely list-shaped content: hosts, options, action items, check results.

## Describe what done looks like

An issue that describes only a problem cannot be finished, only abandoned. Say what the expected
outcome is, even when it is obvious to you today.

## Name people only where they are a real dependency

"Work with the storage vendor" or a named colleague who holds the access you need is useful context.
A name attached to a problem is not, and it makes the item harder to reassign.

Follow the local convention for how colleagues are referred to. Team tone varies -- some teams write
informally in trackers and some do not. Match what is already there rather than importing a style.

## Omit what the reader already has

Project IDs, tracker links the reader already receives, full issue text they can open, and background
they wrote themselves. Every line of it competes with the lines that carry new information.

## Be specific about blockers

A blocker that names no person, date, or dependency is usually a sign the writer has not yet worked
out what is blocking them.

| Vague | Specific |
|---|---|
| "Waiting on hardware" | "Drive replacements were ordered on the 3rd and have not arrived, so the resilver cannot be scheduled." |
| "Blocked on access" | "I need read access to the backup host to verify the restore; requested from the platform team on Tuesday." |

## A note on tone

These rules are about clarity and durability, not formality. Contractions are fine. Short sentences
are fine. Plain words beat impressive ones.

The test for any sentence: **would a colleague who was not in the conversation know what to do after
reading it?**
