# D3bot

Everything redone from scratch:
This version will be built from ground up to reduce computational resources, enable more complex bot behavior and improve path generation from navmeshes.

## Compatibility

This will for the most part be incompatible with the previous version of D3bot.
There will be importers/converters for the old navmeshes at some later point in time. But for now the navmeshes have to be redone.

## ToDo-List

- [X] Bot base (Structure for every bot)
- [X] Locomotion controller base (Hand over control to control callback, if there is one)
- [X] Bot brain base
- [X] Triangle based navmesh
- [X] Saving/Loading of navmeshes
- [X] Syncing of the navmesh between client and server
- [X] Console commands
- [X] Console variables
- [ ] ULX commands
- [X] Add go like error handling
- [X] Navmeshing SWEP
- [X] Navmeshing UI
- [ ] Navmeshing menu for saving and loading
- [ ] Show SWEP buttons and their actions on screen
- [X] Figuring out what navmesh element you point your mouse at
- [X] Localization of entities
- [ ] Filter (Blacklist) by locomotion type for entity localization (Players could abuse climbable walls and get "invisible")
- [X] Navmesh "air connections"
- [ ] Give triangles an optional volume (along the normal, as it's really easy to calculate)
- [ ] Simplify and unify logging and text output to player (console and chat)
- [X] Path-Finding
- [ ] Path-generation and simplification with locomotion controllers
- [ ] Controller callback for locomotion controllers (Button pressing logic)
- [ ] Behavior/Action controllers (Let bot do specific actions, they run locomotion controllers)
- [ ] Bot brain controllers that tell the bot what actions to run
- [ ] Supervisor that creates intermediate goals/tasks for bots and does some more thorough planning (Like where to place a nest)
- [ ] Debug "edit" modes for the SWEP (Select bots, give them a target, debug generated paths)
- [ ] [Localization optimization](documentation/lookup-acceleration/README.md), alternatively just quad tree based and use a max. distance
- [ ] Use polygons instead of triangles. This will speed up pathfinding, but path generation needs to take special care of edges that are "obtuse"
- [ ] Navmesh groups (to apply parameters to several navmesh elements). But polygons should solve that problem good enough
- [ ] Internationalization
- [ ] Improve navmesh and path drawing style (Customizable colors, less eye strain inducing shapes and default colors)
