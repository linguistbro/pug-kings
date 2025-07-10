## v0.6.8
# Updates
- Leaderboard frame is now resizable 
- Healer points are now more similar to DPS points (for overall healing)
- Tanks gets additional points for just being tanks (until further tank only stats are added)

# Fixes
- Fixed players not being awarded correctly for having food/flask/augment rune buffs and using potions

## v0.6.7
# Updates
- Points are awarded to players for having food/flask buffs and using tempered potions

# Fixes
- Community member list is not auto-refreshed when creating a LFG post (for assignig icons next to community members)
- Changed CHANGELOG.txt to CHANGELOG.md

## v0.6.6
# Fixes
- Added "Details! Damage Meter" as a required dependancy (PuG Kings addon will be disabled automatically without it)
- Made the addon compatible with 11.1.7
- More code refactor

## v0.6.5
# Fixes
- Points are correctly awarded to players who throw bombs off of the platform and use bombs to destroy coils (Gallywix)

## v0.6.4
# Updates
- Points are awarded to players who catch and deliver fuel in time (Vexie Mythic)
- Points are deducted from players who catch fuel but do not deliver it in time (Vexie Mythic)
- 1 point is deducted from players who got stunned by Screwed! (Sprocket)
- Points are deducted from players who get hit by boss abilities: Blazing Beam, Rocket Barrage, and Jumbo Void Beam (Sprocket)
- Points are awarded to players for getting/refreshing their High Roller! buff (Bandit)
- Points are deducted from players from getting stunned by Crushed! (Bandit)
- 2 points are awarded to players for each bomb they throw off of the arena (Gallywix)
- 2 points are awarded to players who disable a coil with a bomb (Gallywix)

## v0.6.3
# Fixes
- Items on the leaderboard frame are no longer interractable when they are not visible
- Now, the Purge Data pop-up box only appears automatically when entering raid instances

# Updates
- The PuG Kings addon is now being published as beta (discoverable on Curse Forge)

## v0.6.2
# Fixes
- Players are now correctly awarded points for interrupting "Repair" abilty (Vexie)
- Players are now correctly awarded points for dealing more than average damage to Geargrinder Bikers (Vexie)


## v0.6.1
# Fixes
- Improved the code to handle boss resets and wipes much better

# Updates
- Increased points earned from 1 to 2 for doing more than avarage damage to Territorial Bombshell (Stix)
- Increased points earned from interrupting Scrap Rockets from 1 per 2 interrupts to 1 per 1 interrupt (Stix)

## v0.6
# Fixes
- Changed all addon prints to be available only when debuggin is turned on (enabled from options menu)
- Disabled addon outside of Liberation of Undermine raid

# Features
- Added an options menu (right click minimap icon to access it)

## v0.5
# Fixes
- Fixed Territorial Bombshell Add damage points (it was counted towards Mugzee previously)
- Minimap icon size is scaled down, the position is saved between sessions
- Fixed an error related to boss resets (no encounter ID when somebody resets the boss)

# Features
- Players lose points if they hit a Territorial Bombshell with their ball mechanic during Stix (Heroic & Mythic)

## v0.4.1
# Fixes
- Fixed getting errors for missing libraries
- Updated the point calculation formula for getting damaged by spells and moved it to functions.lua
- Updated how scores are listed on the leaderboard for better visibility

# Features
- Added rudimentary points tracking for all remaining bosses (e.g. getting stunned, not dodging moving lava, etc.)
- Minimap icon to open and close the leaderboard

# Work in progress
- Leaderboard sync between addon users

## v0.3
# Fixes
- Code cleanup for better debugging.

# Features
- Added rudimentary points tracking for Vexie and Rik Reverb (e.g. getting stunned, not dodging moving lava, etc.)

## v0.2
# Fixes
- Leaderboard frame and leaderboard details frame position are now saved between sessions.
- Code cleanup for better debugging.

# Features
- Implemented Ace-Com, LibDeflate, LibStub and LibSerialize to share leaderboard data from raid/party leader to raid/party members.
- Added rudimentary points tracking for Cauldron boss: points are deduced for getting hit by abilities that you can dodge (e.g. getting stunned, not dodging moving lava, etc.)

## v0.1 
# Features
- Puts PuG Kings logo next to PuG Kings community members on the LFG list
- Gives scores to party/raid members based on their performance
- Overall DPS / Healing scores
- (Work in Progress) Liberation of Undermine performance scores