# Changelog

## v0.9.9 (25 November 2026)

- The lure icon briefly glows when an observed active lure expires. Login, hidden controls and rod swaps do not trigger expiry reminders.
- Added an optional saved Lure expiry sound setting, off by default, that plays once per expiry.
- The selected lure's bag count turns amber at 1-3 remaining and red at zero. Applying a lure still requires a click.

Settings

- Right-click the minimap icon and enable Lure expiry sound for one short reminder when your active lure expires. It is off by default. The icon still glows with this setting off.
- Louder fishing splash is a separate setting for the game's bite splash. Its saved Fishing volume slider runs from 0% to 100%, defaulting to 100%. While fishing, Master and Effects use that volume and music and ambience are muted. Previous sound settings return when fishing ends or is interrupted, combat begins, the addon switches off, or you log out or reload. Manual sound changes made during fishing are preserved, and other sound effects remain audible.

## v0.9.8 (21 November 2026)

- Added 337 known fishing-pool and fishable-wreckage locations across 17 Azeroth zones. Use Show fishing pools in settings. Pins appear while a rod is equipped. Locations may be empty, and Zephras Isle has no included pins.
- Added optional Louder fishing splash with a saved Fishing volume slider from 0% to 100%, defaulting to 100%. Master and Effects use the selected volume while music and ambience are muted. Previous sound settings return after fishing, interruption, combat, switching the addon off, logout or reload. Manual sound changes made during a cast are preserved. The bite splash comes from the game.
- Catch stats now start hidden after login or /reload. Enable Show catch stats at startup to open them automatically. Catch tracking continues while the window is hidden.

Client compatibility

- Added support for Retail, Forever, Classic Era, TBC Anniversary, Mists Classic and Wrath Titan Reforged.
- The settings UI was checked in-game on Forever. Other clients passed simulated API checks and still need in-game testing.
- On Retail and Classic, use the Cast / Reel In keybinding or right-click the bobber to catch. The on-screen button casts.
- Cooking uses 25 Forever recipes or a 22-recipe Classic seafood guide on other clients. Later-client recipe sources may be marked unverified.
- Pool pins cover Forever and pre-Cataclysm Azeroth. Other clients use their normal Cooking campfire.
