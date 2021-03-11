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
- [X] Path-generation and simplification with locomotion controllers
- [ ] Fix limitation planes by using adjacent walls and edges that are walled.
- [X] Controller callback for locomotion controllers (Button pressing logic)
- [ ] Walk locomotion handler: Let bots get around obstacles (If there is something in front, let the try to jump or move sideways based on the obstacles position in the current path element)
- [X] Walk locomotion handler: Handle destination position updates while the bot is walking along the path
- [ ] Let bots handle doors (Ideally, if possible, query if door is open. If it is, and bot walks against it, figure out door direction and walk around it)
- [ ] Add ladder locomotion handler (For general climbable surfaces and HL2 ladders)
- [ ] Add pouncing locomotion handler
- [X] Add helper to let any (coroutine based) blocking function to run asynchronously
- [ ] SWEP edit mode for navmesh entity parameters
- [ ] Behavior/Action controllers (Let bot do specific actions, they run locomotion controllers)
- [ ] Bot brain controllers that tell the bot what actions to run
- [ ] Supervisor that creates intermediate goals/tasks for bots and does some more thorough planning (Like where to place a nest)
- [X] Debug "edit" modes for the SWEP (Select bots, give them a target, debug generated paths)
- [ ] [Localization optimization](documentation/lookup-acceleration/README.md), alternatively just quad tree based and use a max. distance
- [X] Use polygons instead of triangles. This will speed up pathfinding, but path generation needs to take special care of edges that are "obtuse"
- [ ] Extend navmesh edit tools to work with polygons
- [ ] Navmesh groups (to apply parameters to several navmesh elements). But polygons should solve that problem good enough
- [ ] Internationalization
- [ ] Improve navmesh and path drawing style (Customizable colors, less eye strain inducing shapes and default colors)
- [ ] Navmesh entity selection optimization
- [ ] Ignore navmesh elements (For drawing and selection) that are not visible (Coroutine will filter and select navmesh elements in the background) (Option to enable/disable in UI)
- [ ] Navmesh drawing radius with UI slider
