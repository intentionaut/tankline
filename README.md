# Tankline

How full is your tank? Tankline puts the answer in one line at the bottom of Claude Code: how much of your context window you have used, and how much of your 5-hour and weekly limits.

```
ctx [######----] 62%  |  5h 24% resets 2h13m  |  7d 91% resets 3d8h
```

One bash file. The only dependency is `jq`. Nothing to configure.

## Install

You need `bash` and `jq`. Check with `jq --version`. If it is missing, install it with your package manager, for example `brew install jq` or `sudo apt install jq`. Tankline is a bash script, so it will not run under plain `sh`.

1. Copy `tankline.sh` somewhere you will remember, for example `~/.claude/tankline.sh`, then run `chmod +x ~/.claude/tankline.sh`.
2. Add this to `~/.claude/settings.json`:
   ```json
   { "statusLine": { "type": "command", "command": "~/.claude/tankline.sh", "refreshInterval": 60 } }
   ```
3. Send your next message. The line shows up at the bottom.

`refreshInterval` is optional. Without it Claude Code only re-runs the script on events, like a new reply or `/compact` finishing, so the reset countdown can go stale while you are away. The script takes a few milliseconds, so a short interval costs nothing. It runs on your machine and uses no API tokens.

## Reading the gauge

- `ctx` is the share of your context window in use, from `context_window.used_percentage`. The bar is 10 characters wide by default.
- `5h` and `7d` are the shares of your 5-hour and 7-day usage windows you have used, from `rate_limits.five_hour` and `rate_limits.seven_day`, with the time left until each one resets.

Green, then yellow from 70%, then red from 90%. Each figure gets its own colour.

## Colourblind mode

Green and red are the two colours red-green colourblind eyes have trouble telling apart, which is not much use on a fuel gauge. Set `TANKLINE_COLORBLIND=1` and two things change:

- The colours become blue, then yellow from 70%, then magenta from 90%.
- Each figure gets a marker after the percentage: nothing when all is well, `!` from 70%, `!!` from 90%. The state never rests on colour alone.

```
ctx [#########-] 95%!!  |  5h 75%! resets 2h14m  |  7d 50% resets 3d9h
```

It is on for any value except empty or `0`. The thresholds are the same `TANKLINE_WARN` and `TANKLINE_CRIT` as the colours use. `n/a` gets no marker. With `NO_COLOR` set as well, the colours go and the markers stay. The bar keeps the width you set with `TANKLINE_WIDTH`. The markers add at most two characters per figure, six across the line.

I checked the palette in a simulator (DaltonLens, deuteranopia and protanopia) against the colours of seven terminal themes. Yellow stayed well clear of the other two in all of them. Blue and magenta came close in the VS Code theme, and that is what the markers are for.

## When you see n/a

Tankline says `n/a` when Claude Code has not sent the data. It will not show 0% for something it does not know.

- `ctx n/a`: no context figure yet. That happens before the first reply of a session, and again right after `/compact` until the next reply.
- `5h n/a` and `7d n/a`: Claude Code only sends `rate_limits` to Claude.ai subscribers (Pro and Max), and only after the first reply in a session. On an API key or another provider you will always see n/a here, and the context bar still works. A single window can go missing too.
- A percentage with no `resets` part: there was a figure but no reset time.
- `resets now`: the reset time has passed and Claude Code has not sent a fresh figure yet.

If `jq` is missing, it prints `tankline: jq not found` and stops cleanly.

## If nothing shows up

Run the command under "Try it without Claude Code" below in a terminal first.

- A line comes back: the script is fine, so look at the `statusLine` entry in `~/.claude/settings.json` and the path in it.
- `tankline: jq not found`: install `jq`, as above.
- `permission denied`: run `chmod +x` on the file.

To remove it, delete the `statusLine` entry from `~/.claude/settings.json` and delete the script.

## Settings

All optional. Set them as environment variables on the command in `settings.json`.

| Variable | Default | What it does |
| --- | --- | --- |
| `TANKLINE_WARN` | 70 | percentage where the colour turns yellow |
| `TANKLINE_CRIT` | 90 | percentage where the colour turns red |
| `TANKLINE_WIDTH` | 10 | width of the context bar in characters |
| `NO_COLOR` | unset | set to anything to turn colour off |
| `TANKLINE_COLORBLIND` | unset | set to anything but `0` for blue, yellow and magenta, with `!` and `!!` markers |

For example: `"command": "TANKLINE_WARN=60 ~/.claude/tankline.sh"`.

## Try it without Claude Code

```
echo '{"context_window":{"used_percentage":62}}' | bash tankline.sh
```

## Why another one

Other people have built status lines like this, and some do a lot more. I wanted the small version: one file you can read over a coffee, no package manager, no plugin, nothing to set up. If you want cost tracking, git status or several lines, one of those will suit you better. If you want two numbers and a script you can read in a couple of minutes, try this.

## Good to know

- Everything comes from the JSON Claude Code sends to the status line. The fields are documented at https://code.claude.com/docs/en/statusline and may change. If one is renamed, that part shows `n/a` until the script is updated.
- The 5-hour and weekly figures are the subscription windows Claude Code reports. I checked them against Claude desktop's usage view twice on 4 October 2026, with Claude Code 2.1.289. The reset times matched both times. The percentages did not: the weekly figure was 3 points under desktop and then 1, and the 5-hour figure was 15 points under and then 5. I have not pinned down why, so treat them as Claude Code's numbers.
- I have tested it on Linux, and on macOS 26.7 with the bash that ships with it (3.2.57) and jq 1.7.1. I have not tried a newer bash on the Mac, or iTerm2. On Windows, use Git Bash or WSL.

## Bugs and ideas

If something looks wrong, open an issue and say which Claude Code version you have. The line itself is the most useful thing to paste.

## Licence

MIT. See `LICENSE`.
