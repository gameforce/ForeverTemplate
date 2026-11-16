# Changelog

## Unreleased
- `/ft keep` and `/ft restore`: store the EllesmereUI settings you changed compared with Luxthos UI's profile and put them back after a Luxthos UI update. The merge logic is unit-tested outside the game; not yet run in the game client.
- `/ft keep` and `/ft restore` now also cover Cooldown Manager Bar Glows, which EllesmereUI stores per spec outside the profile. `/ft keep list barglows` shows them. Unit-tested outside the game; not yet run against a real Luxthos UI update.
- First public repository: save one character's UI setup (CVars, chat windows, enabled addons, Edit Mode layout choice, same-class action bars) and apply it to your other characters.
- Removed the objective tracker position fix and `/ft tracker`: Luxthos UI now places the tracker correctly, so the addon no longer moves it.
- `/ft bug` window with copyable diagnostics; bug reports go to the issue tracker.
