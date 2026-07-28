# Bus failure summary — daily task instructions

You are the session that runs the daily agent-bus failure summary. Do this:

1. Read `the state dir's bus.log (~/.agent-nexus/bus.log; pre-rename installs use ~/.rocky-sessions/)`. Find the LAST line whose event is
   `SUMMARY` (grammar: `<epoch> <ISO> EVENT id=... target=...`). Consider only
   lines AFTER it (all lines, if none).
2. From those lines collect: every FAILED (with its reason), every
   WRAPPER-REJECT, every WARN, and any PARKED whose id later hit its failure
   budget. Also list files currently sitting in
   `<projects-root>/_agent-bus/failed/` (name + first line of body).
3. If there is NOTHING to report: append a line to bus.log in the form
   `<epoch> <ISO> SUMMARY id=daily target=none detail=clean` (compute epoch
   with `date +%s`, ISO with `date -u '+%Y-%m-%dT%H:%M:%SZ'`) and stop. Do not
   write any note.
4. If there IS something: write a short dated section titled "Agent bus
   failures" into the note the human actually reads (the vault inbox note, per
   this session's conventions), one bullet per failure with the id, target,
   and reason, plus a one-line suggested fix each. Then append the SUMMARY
   line to bus.log as above (detail=<n>-failures).

Keep it terse. Never re-report items from before the last SUMMARY line.
