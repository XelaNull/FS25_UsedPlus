# Reddit Post Draft for r/farmingsimulator

## Timing Consideration

> **Is it premature to post this?**
>
> The UsedPlus mod is still in development and not yet publicly released. You could:
>
> 1. **Post now** - The coding reference stands on its own as a learning resource.
> 2. **Wait until UsedPlus releases** - More credibility, but delays sharing.
> 3. **Post now, update later** - Two opportunities for community engagement.
>
> **Recommendation:** The reference is useful now. Waiting doesn't add value.

---

## Suggested Title Options

1. `Put together some FS25 modding notes while learning - maybe useful to others?`
2. `Documented some FS25 modding patterns & pitfalls - sharing in case it helps`
3. `Small FS25 modding reference I made - dialogs, events, common mistakes`

---

## Post Body

Hey all,

I've been working on my first FS25 mod and kept running into the same issues - GUI coordinates being backwards from what I expected, functions that don't exist, patterns that silently fail. So I started writing things down.

Ended up with a small collection of notes I'm calling the **[FS25 AI Coding Reference](https://github.com/XelaNull/FS25_UsedPlus/tree/master/FS25_AI_Coding_Reference)**. Figured I'd share it in case it saves someone else some headaches.

### What's in it

Mostly stuff I wish I'd known when starting out:

- **GUI dialogs** - How the coordinate system actually works (Y=0 is at the bottom, not top - that one got me)
- **Network events** - Getting multiplayer sync right
- **Common pitfalls** - 17 things that don't work (like `os.time()` not existing, no `goto` in Lua 5.1, etc.)
- **Patterns** - Managers, extensions, save/load, shop UI stuff

I also found a couple other community resources while researching that are worth knowing about:

- **[FS25 Community LUADOC](https://github.com/umbraprior/FS25-Community-LUADOC)** - Huge API reference with 11,000+ functions documented
- **[FS25-lua-scripting](https://github.com/Dukefarming/FS25-lua-scripting)** - Raw Lua files from the game

Between those two and my notes, most questions I've had are covered somewhere.

### Quick example - stuff that doesn't work

| Don't use | Use instead | Why |
|-----------|-------------|-----|
| `os.time()` | `g_currentMission.time` | Sandboxed environment |
| `goto` | `if/else` | Lua 5.1 only |
| `Slider` widgets | `MultiTextOption` | Events don't fire reliably |

Anyway, it's all free. Hope it's useful to someone.

**Link:** https://github.com/XelaNull/FS25_UsedPlus/tree/master/FS25_AI_Coding_Reference

---

## Post Flair

Use: `Modding` or `Resource` (check subreddit options)

---

## Alternative Even Shorter Version

---

**Title:** `Some FS25 modding notes I put together - pitfalls, patterns, etc.`

**Body:**

Working on my first FS25 mod and kept notes on stuff that tripped me up. Figured I'd share in case it helps anyone.

Covers things like:
- GUI coordinate system (Y=0 is at bottom, not top)
- Network events for multiplayer
- 17 things that don't work (`os.time()`, `goto`, Slider widgets, etc.)
- Dialog patterns, managers, save/load

Also found these helpful:
- [FS25 Community LUADOC](https://github.com/umbraprior/FS25-Community-LUADOC) - API docs
- [FS25-lua-scripting](https://github.com/Dukefarming/FS25-lua-scripting) - Raw game source

Link: https://github.com/XelaNull/FS25_UsedPlus/tree/master/FS25_AI_Coding_Reference

---

## Notes

- Keep it casual - you're sharing notes, not launching a product
- Engage with comments genuinely
- If people point out errors, thank them and fix it
