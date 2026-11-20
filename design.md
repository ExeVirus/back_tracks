I need help implementing my luanti game.

First, I need some basic nodes, via core.register_node() for the textures I have (5), I also need those to become my base nodes for standard mapgens, specifically flat mapgen should just be pure sand.png nodes everywhere.

Second, I need to have the ability to dig those nodes and place them - like normal minetest or really any game in luanti.

Third, I need a chat command `/toggle` that switches between normal player walk/fly/dig to attached to an invisible entity. This entity will be not invisible later (3d model). It will be a monster truck looking thing with a turrent on top - that turret will turn and follow my look direction and so could become my player model. 

Controls for that monster truck:

Controls:
- W: Forward
- S: Backward
- A/D Turn Left/Right
- Spacebar: Nitro
- Mouse: Aim
- Left Mouse button: Bullets
- Right Mouse button: Bomb/Missile

So I'll need a HUD that shows a speedometer, and a HUD that shows a number of Nitro's remaining (for now, just use text like 0/60 and N N N for 3 nitros remaining)

For bullets, generate a texture via white and colorize it to red or similar, and use a bullet entity to represent it. Should fly out at high speed along my look reticule and disappear say after 100 node distance.

For bomb, leave unimplemented for now.

For Nitro - let me go faster than the max speed, so instead of 0-60, might jump to 90 for a few seconds before falling back down to max 60. 

Physics imlpementatino is where I need your help - probably implemented via a globalstep that checks the singleplayer inputs and then runs a Tick of hte physics simulation.

I want to use 4 points as the wheels, have inertia, have a camera that is 3rd person from that monster truck (invisible for now or maybe just a stone node model). 

These wheels don't drive rigid physics over the blocks, instead just does a smoothing algo and dynamic pressure based on distnace from nearest centroids of filled nodes. Air doesn't count. Can only gain speed based on how many and how hard the wheels are pressed - if they're all in the air, then I can't accelerate or turn. Would like some spring physics, and should be able to gain speed going downhill faster than uphill. 

ideally my wheel-base is like 4x4 nodes in size, and where my four wheels are is just based on my orientation.

Please implement all of that in runtime.lua and nodes.lua