# FS25 AI Coding Reference, 70 patterns, 9k+ lines

Hey all,

I've been working on my first FS25 mod using Claude Code (Opus 4.5) as my coding partner. We kept running into the same issues - GUI coordinates being backwards from what we expected, functions that don't exist, patterns that silently fail. So we started writing things down.

Ended up with a collection of notes called the **[FS25 AI Coding Reference](https://github.com/XelaNull/FS25_UsedPlus/tree/master/FS25_AI_Coding_Reference)**. It was created by AI, for AI - structured specifically so AI coding assistants can reference it when helping with FS25 mods. But due to its structured nature, it turns out to be pretty useful for us humans too. :)

Figured I'd share it in case it saves someone else some headaches or gives them an easier path to creating their own FS25 mod.

## What's in it

Mostly stuff I wish I'd known when starting out:

- **GUI dialogs** - How the coordinate system actually works (Y=0 is at the bottom, not top - that one got me)
- **Network events** - Getting multiplayer sync right
- **Common pitfalls** - 17 things that don't work (like `os.time()` not existing, no `goto` in Lua 5.1, etc.)
- **Patterns** - Managers, extensions, save/load, shop UI stuff

I also found a couple other community resources while researching that are worth knowing about:

- **[FS25 Community LUADOC](https://github.com/umbraprior/FS25-Community-LUADOC)** - Huge API reference with 11,000+ functions documented
- **[FS25-lua-scripting](https://github.com/Dukefarming/FS25-lua-scripting)** - Raw Lua files from the game

Between those two and my notes, most questions I've had are covered somewhere.

## Quick example - stuff that doesn't work

| Don't use | Use instead | Why |
|-----------|-------------|-----|
| `os.time()` | `g_currentMission.time` | Sandboxed environment |
| `goto` | `if/else` | Lua 5.1 only |
| `Slider` widgets | `MultiTextOption` | Events don't fire reliably |

Anyway, it's all free. Hope it's useful to someone.

**Link:** https://github.com/XelaNull/FS25_UsedPlus/tree/master/FS25_AI_Coding_Reference
