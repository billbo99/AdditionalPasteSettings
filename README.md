This mod has been enhanced from the original mod .. https://mods.factorio.com/mod/additional-paste-settings

## Notes for 2.0
- Using Quality icon not the best .. waiting on https://forums.factorio.com/viewtopic.php?f=28&t=117265
- Pasting to new 2.x display plates does not work yet .. waiting on https://forums.factorio.com/viewtopic.php?f=28&t=116024&p=623916&hilit=display#p623916
- Unable to set the quality on Storage Chest filters .. waiting on https://forums.factorio.com/viewtopic.php?f=28&t=117407
- Added smart inserter .. if pulling from an assembler set filters on inserter to the product
- Removed support (for now) for
  - SE cargo landing pads
  - Display plates
  - Combinators


Adds additional paste settings in the game (Shift+Right Click entity then Shift+Left Click another).
See it in action here: https://gfycat.com/BonyBlissfulElephantbeetle

- Copy from Machine -> Paste into Inserter: Sets the inserter's condition to be less than the stack's multiplier of the item being produced by the assembling machine. If it's connected to ANY wire network, it sets the condition to the circuit condition. If not connected to a wire network, set it based on the logistics condition.
- Copy from Machine -> Paste into Logistic Chest: Allows you to choose how the requests is set. It can be: the item output Stack Size; by a multiplier of the Items Produced; or by Time Spent crafting the item. Has an option to invert logic for Buffer chests, to paste products instead of ingredients.
- Copy and paste into SAME Inserter: Clears the logistics and circuit condition.
- Copy and paste into SAME Requester/Buffer Chest: Clears the requests for that chest.
Copy from Machine -> Paste into Constant Combinator: Sets the signals of the constant combinators based on the recipe ingredients of the assembling machine.

You have the option for the pasting to be additive. That means, instead of replacing the contents of the logistic chest/inserter, it will merge and/or add the amount of items. This allows for easy setup of multiple recipes into the same requester chest, or to easily increase the request/filter amount.

The Configuration is found in Settings -> Mod Settings. Please configure it to your liking.

___
## Additional support has been added for
- Train station renaming
- ~~Display plates~~
- Loader filters
- ~~Decider/arithmetic combinators~~

Picture | Picture |
--- | ---|
![alt text](https://assets-mod.factorio.com/assets/c4504336d9acd9b823752f5feb6d9a3c61411ffe.png) | ![alt text](https://assets-mod.factorio.com/assets/27347056dba7cab3d7dc74fe9e3a88534e7f1857.png "display plates")|
![alt text](https://assets-mod.factorio.com/assets/7a2c25b74cba558c6bef2dbe40878561e41b48cf.png "loaders")|![alt text](https://assets-mod.factorio.com/assets/714ce416d740d493eb89384cb78844719b2fb3b6.png "combinators")|
