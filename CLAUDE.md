@AGENTS.md

Claude-specific notes:

- Read `../ewe-companion/AGENTS.md` too: the rules and the map are there,
  and most features change both repos.
- Check every visible change in the island harness
  (`../ewe-companion/tests/island.sh`, with `ISLAND_WORK` in your
  scratchpad) and read each screenshot before you report on it. Hover and
  click bugs need `tests/island.sh hover`; curve bugs need `--scale 1.8`.
- Never restart `ewe.service` unless the owner asked to try a change: it
  restarts their whole shell.
- Commit or push only when asked; branch off `main` first. End commit
  messages with the Co-Authored-By line the session gives you.
