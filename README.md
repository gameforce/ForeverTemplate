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
`/ft` shows status. `/ft save`, `/ft apply`, `/ft keep` and `/ft restore` (see below), `/ft bars`, `/ft ignore [AddonFolder]` (addons it never switches on or off), `/ft errors`, `/ft bug`, `/ft auto on|off`, `/ft reset`.

## Keeping your EllesmereUI changes when Luxthos UI updates
An update imports Luxthos UI's EllesmereUI profile over yours, so element positions and options you changed are lost. Before you update, type `/ft keep`: it compares your active EllesmereUI profile with the one in the Luxthos UI pack and stores every setting you changed or added. After the update, type `/ft restore` and click Reload: your settings go back on top of the new profile, and anything Luxthos changed that you did not touch keeps his new value. A login message reminds you when the pack changed since your last `/ft keep`. Run `/ft keep` again after each round of tweaks. Cooldown Manager Bar Glows are kept too, although EllesmereUI stores them per spec outside the profile. `/ft keep list` shows what is stored, and `/ft keep list barglows` narrows it. Skipped on purpose: the Cooldown Manager spell lists, per-spell settings and EllesmereUI bookkeeping keys.

## Install (for now)
Copy this folder to `World of Warcraft/<client>/Interface/AddOns/ForeverTemplate`. A CurseForge release will follow.

## Status
Early. Tested on the WoW Forever beta client; Retail is untested. See the issue tracker for known problems.

## Branches
`staging` is where changes land and are tested. `production` is what gets released.

Not affiliated with or endorsed by Blizzard Entertainment. Copyright Gameforce Gaming; no license is granted until one is added to this repository.

Site: `site/` holds the [gameforce.ca](http://gameforce.ca) landing page (static HTML served by nginx).
