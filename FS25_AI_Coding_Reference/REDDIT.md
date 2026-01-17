# Reddit Post Draft for r/farmingsimulator

## Timing Consideration

> **Is it premature to post this?**
>
> The UsedPlus mod is still in development and not yet publicly released. You could:
>
> 1. **Post now** - The coding reference stands on its own. It's useful regardless of whether your mod is released. Many people share learning resources before/without releasing the project that spawned them.
>
> 2. **Wait until UsedPlus releases** - Then you can say "validated in a released mod" and potentially do a combined announcement. More credibility, but delays sharing useful info.
>
> 3. **Post now, update later** - Share the reference now, then do a separate UsedPlus release post when ready. Two opportunities for community engagement.
>
> **Recommendation:** Option 1 or 3. The reference is valuable now. Waiting doesn't make it more valuable, just delays others benefiting from it.

---

## Suggested Title Options

1. `[Modding Resource] FS25 AI Coding Reference - 70+ patterns for mod development`
2. `I analyzed 164+ FS25 mods and documented the patterns that actually work`
3. `Free FS25 modding reference: dialogs, events, multiplayer sync, and 17 pitfalls to avoid`

---

## Post Body

Hey fellow farmers! 🚜

I've been deep in FS25 mod development and along the way I've documented everything I learned into a free resource called the **[FS25 AI Coding Reference](https://github.com/XelaNull/FS25_UsedPlus/tree/master/FS25_AI_Coding_Reference)**.

### What is it?

A collection of **working patterns** for FS25 mod development. Not theory - actual code extracted from analyzing 164+ community mods and tested in my own 83-file mod project.

| What's Included | Count |
|-----------------|-------|
| Documentation Files | 27 |
| Lines of Documentation | 9,334 |
| Validated Patterns | 70+ |
| Documented Pitfalls | 17 |
| Source Mods Analyzed | 164+ |

### Topics Covered

- **GUI Dialogs** - MessageDialog pattern, XML structure, the coordinate system that trips everyone up (Y=0 is at the BOTTOM, not top!)
- **Network Events** - Multiplayer sync done right
- **Managers** - Singleton pattern with save/load integration
- **Extensions** - How to hook into game classes without breaking things
- **Shop UI** - Adding custom buttons to the vehicle shop
- **Vehicles** - Specializations, configurations, attachers
- **Pitfalls** - 17 things that DON'T work (like `os.time()`, `goto`, Slider widgets...)

### The FS25 Modding Trifecta

I discovered two other amazing community resources, and together the three cover different needs:

| Resource | What It Answers |
|----------|-----------------|
| **[FS25 Community LUADOC](https://github.com/umbraprior/FS25-Community-LUADOC)** | "What parameters does this function take?" (11,102 functions documented!) |
| **[FS25-lua-scripting](https://github.com/Dukefarming/FS25-lua-scripting)** | "How does Giants implement this internally?" (267 raw Lua files) |
| **[FS25 AI Coding Reference](https://github.com/XelaNull/FS25_UsedPlus/tree/master/FS25_AI_Coding_Reference)** | "How do I actually build X?" (patterns & pitfalls) |

### Why "AI Coding Reference"?

I built this with Claude AI assistance, and it's specifically structured to be useful when using AI coding assistants. Clear patterns, explicit examples, and documented pitfalls help AI tools give you better answers.

### Sample: Top 5 Things That Don't Work

| Don't Use | Use Instead | Why |
|-----------|-------------|-----|
| `os.time()` | `g_currentMission.time` | Sandboxed Lua environment |
| `goto` / `::label::` | `if not then` pattern | FS25 uses Lua 5.1 |
| `Slider` widgets | `MultiTextOption` | Unreliable events |
| `DialogElement` base | `MessageDialog` | Rendering issues |
| `g_gui:showYesNoDialog()` | `YesNoDialog.show()` | Method doesn't exist |

### It's Free & Open

The whole thing is MIT-style free. Use it, share it, improve it. If you find something wrong or want to add a pattern, PRs welcome.

**Link:** https://github.com/XelaNull/FS25_UsedPlus/tree/master/FS25_AI_Coding_Reference

---

Happy modding! Let me know if you have questions or if there's a pattern you'd like documented.

---

## Post Flair

Use: `Modding` or `Resource` (check subreddit options)

---

## Tips for Posting

1. **Best time to post:** Weekday evenings or weekend mornings (US/EU time)
2. **Engage with comments:** Answer questions, take feedback graciously
3. **Don't over-promote:** This is a resource post, not an ad for UsedPlus
4. **Follow up:** If people ask for specific patterns, consider adding them and updating

---

## Alternative Shorter Version

If the full post feels too long:

---

**Title:** `Free FS25 Modding Reference - 70+ patterns, 17 pitfalls, 9000+ lines of docs`

**Body:**

Built this while learning FS25 modding - a free reference covering dialogs, events, multiplayer sync, shop UI, and more.

**What's in it:**
- 27 doc files / 9,334 lines
- 70+ validated patterns from analyzing 164+ mods
- 17 documented pitfalls (things that DON'T work)
- Topics: GUI, events, managers, extensions, vehicles, save/load

**Quick example - things that don't work:**
- `os.time()` → use `g_currentMission.time`
- `goto` statements → FS25 is Lua 5.1, no goto
- `Slider` widgets → unreliable, use MultiTextOption

**Link:** https://github.com/XelaNull/FS25_UsedPlus/tree/master/FS25_AI_Coding_Reference

Also check out these complementary resources:
- [FS25 Community LUADOC](https://github.com/umbraprior/FS25-Community-LUADOC) - API reference (11,102 functions)
- [FS25-lua-scripting](https://github.com/Dukefarming/FS25-lua-scripting) - Raw game source files

Happy modding!

---

## Notes

- The r/farmingsimulator subreddit is generally welcoming to modding resources
- Avoid posting the same thing to multiple farming sim subreddits simultaneously (looks spammy)
- Consider cross-posting to r/farmingsimulator25 if it exists and is active
- If there's a dedicated FS modding Discord, that might be worth sharing too
