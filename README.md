# Forever Template

A World of Warcraft addon for **WoW Forever** and **Retail**. Set up one character, then every new character starts with the same interface.

Bug reports and ideas: [Issues](https://github.com/gameforce/ForeverTemplate/issues). In game, `/ft bug` shows the details to paste.

## What it does
`/ft save` on the character you set up records, for the account:
- CVars (nameplates, interface options), chat windows and channels
- which addons are enabled
- the Edit Mode layout you use
- action bars, per class (only the same class gets them)

A character that has not applied the template does so about four seconds after login. It never copies per-character addon progress (quests, guides, chat history), and nothing is sent anywhere.

## Commands
`/ft` shows status. `/ft save`, `/ft apply`, `/ft bars`, `/ft ignore [AddonFolder]` (addons it never switches on or off), `/ft errors`, `/ft bug`, `/ft auto on|off`, `/ft reset`.

## Install (for now)
Copy this folder to `World of Warcraft/<client>/Interface/AddOns/ForeverTemplate`. A CurseForge release will follow.

## Status
Early. Tested on the WoW Forever beta client; Retail is untested. See the issue tracker for known problems.

## Branches
`staging` is where changes land and are tested. `production` is what gets released.

Not affiliated with or endorsed by Blizzard Entertainment. Copyright Gameforce Gaming; no license is granted until one is added to this repository.

Site: `site/` holds the [gameforce.ca](http://gameforce.ca) landing page (static HTML served by nginx).
