# Changelog

## Unreleased
- `/ft keep` and `/ft restore` now also keep the tooltip position in your Edit Mode layout (Luxthos UI updates reset it to his default). `/ft restore` writes it back into the layout; close Edit Mode first. Tested in the Forever client.
- `/ft keep` and `/ft restore`: store the EllesmereUI settings you changed compared with Luxthos UI's profile and put them back after a Luxthos UI update. The merge logic is unit-tested outside the game; not yet run in the game client.
- `/ft keep` and `/ft restore` now also cover Cooldown Manager Bar Glows, which EllesmereUI stores per spec outside the profile. `/ft keep list barglows` shows them. Unit-tested outside the game; not yet run against a real Luxthos UI update.
- `/ft keep` no longer stores settings that only differ because EllesmereUI filled in its own default and Luxthos UI's profile leaves that setting out. This removes most of the noise from the kept list.
- `/ft keep` and `/ft restore` now also cover Cooldown Manager Tracking Bars (the bars, their positions and anchor links), stored per spec like Bar Glows. `/ft keep list trackingbars` shows them; one bar is about 100 settings.
- `/ft keep` only stores settings of EllesmereUI modules that are switched on, and names the modules it left out.
- `/ft keep` stops with a message when Luxthos UI's pack changed since the last keep and that keep was not restored yet, so an update cannot silently replace the stored settings. `/ft keep force` stores anyway.
- First public repository: save one character's UI setup (CVars, chat windows, enabled addons, Edit Mode layout choice, same-class action bars) and apply it to your other characters.
- Removed the objective tracker position fix and `/ft tracker`: Luxthos UI now places the tracker correctly, so the addon no longer moves it.
- `/ft bug` window with copyable diagnostics; bug reports go to the issue tracker.
