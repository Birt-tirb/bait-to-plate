Bait to Plate 0.9.9
Release for current official WoW clients:
Forever 1.60.1, Retail 12.1.5, Classic Era 1.15.9, TBC Anniversary 2.5.6,
Mists of Pandaria Classic 5.5.4, and Wrath Titan Reforged 3.80.2.
The settings UI was checked in-game on Forever. Other client ports passed
simulated API checks and still need in-game testing.

Install

1. Extract the BankFishing folder from the ZIP into Interface\AddOns
   inside the WoW client folder you play.
2. Enable Bait to Plate in the AddOns list for that client.
3. Type /baittoplate or open Options > AddOns > Bait to Plate.
   The on-screen button enables WoW's Interact Key when used. Turn on
   Auto Loot if you want the game to collect the catch for you.
4. Learn Fishing and face fishable water. Assign Bait to Plate:
   Cast / Reel In in Keybindings > AddOns. Press it to cast, wait for
   the splash, then press it again to catch.
   In Forever, the on-screen button also casts and reels in. On other
   clients it casts, and you use the keybinding or right-click the bobber
   to catch.

Classic and Forever controls appear when a fishing pole is equipped.
Retail controls appear once Fishing is learned, with fishing equipment
read from the profession tool slot.
Right-drag the button to move it. Type /baittoplate button to hide
or show it for the current session. If you prefer a key, assign
Bait to Plate: Cast / Reel In under Options > Keybindings > AddOns.
The existing /bankfishing and /reelandrecord commands still work.

Blue fish on the minimap mark 337 known fishing-pool and fishable-wreckage
locations across 17 Azeroth zones. They appear while a fishing pole is
equipped and Bait to Plate is on. These pins cover Forever and
pre-Cataclysm Azeroth. The saved pool overlay is disabled on Retail and
post-Cataclysm Classic clients, where these old map coordinates differ.
Right-click the minimap icon and use
Show fishing pools to change the saved preference. This starts enabled.
Locations can be empty when you visit. Forever's new zones are not covered
by the included locations. Pool data and artwork credits are included in
PoolData-LICENSE.txt.

Louder fishing splash
Right-click the minimap icon and enable Louder fishing splash in settings.
Choose Fishing volume from 0% to 100% with the slider (default 100%).
During your Fishing channel, Master and Effects use that volume while
music and ambience are muted. Your previous sound settings return when
fishing ends, combat begins, the addon switches off, you reload, or you
log out. The selected fishing volume is saved between sessions.
Other sound effects are audible too. Changes you make to sound settings
during fishing are preserved.
The game provides the splash at the bite. A separate custom bite sound
cannot be triggered reliably through the normal addon API.

The lure icon beside Cast Fishing shows the selected lure's bag count
and the remaining time on your equipped pole. Right-click to choose
a lure, then left-click to apply it. Let an active lure expire before
applying another. Forever includes Camper's Lure and Secret Bait.
Other clients use the six supported standard pole lures.

The lure icon briefly glows when an active lure expires. Enable Lure
expiry sound in settings for one reminder sound per expiry (off by
default). The selected lure's bag count turns amber at three or fewer
and red at zero. A lure still needs a click to apply.

The campfire icon shows how many of the selected camp item are in
your bags. Right-click to choose a campfire kit, Fish Bowl, Fishing
Rack, or Fishing Hut. Left-click to place it. Fishing features
require a nearby campfire. These camp items are specific to Forever.
On other clients, left-click the campfire icon to build a normal Cooking
campfire.

The catch window starts hidden at login and /reload. In settings, enable
Show catch stats at startup if you want it to open automatically. Use
Toggle Catch Stats or /baittoplate stats to open it whenever you want.
Catch tracking continues while the window is hidden.

The catch window has Session, All-Time and Cooking tabs. The first
two show totals, item artwork for first and latest catches, and a
ranked chart of your five most common catches. Session resets on
login or /reload. All-Time
is saved across characters on this WoW account and starts at version
0.5.0. Drag the window to move it. Click X or type /bankfishing stats
to hide it while keeping the counter running.

Cooking checks your skill, bags and known recipes for 25 Forever seafood
dishes. Other clients use a 22-recipe Classic seafood guide, with
requirements adapted for their client. Retail uses Classic Cooking skill.
Expansion cooking recipes are outside this guide. Some later-client recipe
vendors remain unverified and are labelled in the tooltips. Ready recipes
and recipes using fish you already
have appear first. Each recipe row shows one status. Hover for separate
requirements and ingredient sections with In bags / Needed counts.
Tooltips also show where to learn the recipe.
Use Open Cooking once on each
character to verify learned recipes when WoW has not reported them.
Recipe checks are informational. Craft at the appropriate station
using WoW's Cooking window.

Left-click the fishing icon on the minimap to turn Bait to Plate off
or on. Right-click the icon to open settings.
While off, the fishing button, stats window and pool markers are hidden, and the
addon's keybinding and catch tracking are paused.
Right-drag the minimap icon to move it around the minimap. Both window
positions, the icon position, and the minimap on/off setting are saved.

If the button casts but does not reel in

The game must select an in-range bobber for the button to reel in.
Face the bobber and try again after the splash. You can always
right-click the bobber directly, including if the client restricts
access to its built-in Interact button.

Bait to Plate uses WoW's protected spell button and native Interact
action. Each cast and reel requires its own click or key press.
It temporarily increases WoW's Interact range setting while the line
is out so the client can select bobbers farther from shore.

Blizzard Interact Key documentation
https://news.blizzard.com/en-us/article/23876525/accessibility-updates-in-dragonflight

Blizzard add-on policy
https://eu.forums.blizzard.com/en/wow/t/wow-user-interface-add-on-development-policy/1642

Forever Cooking and campfire basics
https://worldofwarcraft.blizzard.com/en-us/news/24301516/gather-around-the-campfire-in-world-of-warcraft-forever

Forever cooking recipes and vendors
https://www.zockify.com/forever/professions/cooking/recipes/
