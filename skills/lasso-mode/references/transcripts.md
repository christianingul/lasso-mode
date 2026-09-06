# Reading session transcripts

Claude Code writes one JSONL file per session to `~/.claude/projects/<slug>/<session-id>.jsonl`. Every line is one chat message.

`<slug>` is the current working directory with the leading slash dropped and every `/` turned into `-`. So `/Users/you/proj` becomes `Users-you-proj`.

List candidates newest-first by real modification time, never by the UUID in the name:

```bash
ls -t ~/.claude/projects/<slug>/*.jsonl 2>/dev/null | head -10
```

To identify a specific session, read the first line of each candidate and check that its message text contains the conversation's opening user prompt.

## Scope: this project only

**Read only this project's slug directory.** Never glob across `~/.claude/projects/*/`. That crosses project boundaries and reads private chats from unrelated work. If the user asks for another project's transcripts, they have to name it.

Grep for the topic before reading, then read only the matching sessions and only their relevant regions. Transcripts are large, and this is grunt work worth handing to a subagent (the [Guard the Context Window](../../principle-guard-the-context-window/SKILL.md) principle skill). Skip the current session plus obvious noise: subagent, eval, and test sessions.

Anything mined from a transcript is history, not current truth. Check it against live state with `git` and `gh` before acting on it.
