# 2D Platformer Pathfinding GDScript 4.4.1
## Description
This 2D Platformer Pathfinding project provides a rudimentary algorithm to create a pathfinding behavior to a Player character and and enemy character using the built-in `A* Graph` node in Godot. It is converted and improved from the tutorial series [Godot 4.x Advanced 2D Platformer Path Finding](https://youtube.com/playlist?list=PL6Ikt4l3NbVi_9_-TqX-JUsJ9nIFeYAFE&si=1pFHbTRJXprzpWVb) written in C# by the YouTube channel [TheSolarString](https://www.youtube.com/@TheSolarString)  into **GDScript 4.4.1** using the new TileMapLayer node (instead of the deprecated TileMap node in previous versions). I highly recommend anyone interested in using this tool to watch his video series to understand the algorithm better.

Original Repository here: https://github.com/solarstrings/Godot4.x_Advanced2DPlatformerPathFinding

#### Note:
1. Some methods that return Nullable types that were used in the original tutorial in C# were converted into returning an effectively invalid result such as `Vector2i.MAX` instead of `null` 
in order to preserves the static typing of the methods and take advantage of the editor's IntelliSense. If you adopt these scripts into your game, depending on the game, this may not work as expected.
2. Assets have been shared with original author's permission.
   
## How to use

 1. In Project -> Project Settings -> Input Map, set up 2 inputs named `left_mouse_button` and `start_follow`. In the demo project, `left_mouse_button` is set up as the left mouse button, and `start_follow` is set up with the space-bar, the right mouse button and the enter key.
 2. In the Godot editor, in the `Main` scene, change the parameters in the `TileMapLayerPathfind` node to change the pathfinding behaviors.
		 **a.** `ShowDebugGraph` flag to show the debuging lines and graph points visually
		 **b.** `Jump Distance` to define maximum horizontal jump distance in the graph
		 **c.** `Jump Height`to define maximum vertical jump distance in the graph
		 **d.** `Fall Tile Horizontal Scan` to define how far away horizontally should the graph scan for a fall tile below. When character collision shape is wider than the tile size, this should be round up to the smallest integer of the ratio between the character collision shape and the tile size to ensure proper falling. For example, if the character collision shape is 20px wide and the tile size is 16px, this value should be at least 2.
 3. Run the project.
 4. Left click to move the player character. Spacebar to let the enemy start following the player.
 5. You can switch to the included 16px tile map scene to try out different tile sizes.

Note: Codes are commented, particularly in the player and skeleton scripts for further adjustment in your projects.

## Future improvement ideas

Despite the original name of this project being "Advanced Path Finding" (as in the original YouTube tutorials), I found there are things left to be desired with the pathfinding algorithm. I will provide some ideas for future improvements of this project should anyone (or myself) want to try and improve it.

### 1. Improve the `A* graph` / pathfinding algorithm

There are edge cases in the current implementation of the `A* graph` that causes the characters to move in unexpected and incorrect behaviors. The pathfinding works well enough with simple, blocky platform shapes, but in my testing I have found it could fail with more complex shapes.

### 2. Upgrade to work with moving platforms
Current implementation only works with static tiles. TheSolarString provided a suggestion on how one could upgrade the algorithm to work with moving platforms [in a comment](https://www.youtube.com/watch?v=SRrLptMY5pk&lc=Ugx8H8oWT1MB_dQ_ePd4AaABAg.A2_v-qs3eo3A2bWogDpsVy) on the last part of his tutorial series on YouTube.
### 3. Hard-coded values
In the current implementation, there are hard coded values governing how the characters will behave with the platforms when it comes to jumping. Even though it is the `TileMapLayer` that dictates how the graph will be drawn, the movement is handled in the character scripts, using their own hard-coded values. This means if the values are not corresponding to the values provided in the `TileMapLayer`, the character won't be able to move properly. For example, if the `Jump Height` value in the `TileMapLayer` is set too high but the `Jump Velocity` values in the characters' scripts are set too low, they will stuck in a tile trying to jump up a platform indefinitely. In a more mature project, these values should be controlled in only one place, and easily changed.
### 4. Strong coupling between the TileMapLayer and the characters
In the current implementation, one one graph is drawn for all characters using the `TileMapLayer`. This means that the `TileMapLayer` assumes a lot of how every character will move through the tile map and what their movement capabilities are. This is not the case in a good platforming game, so an important improvement would be that each character will draw their own graph in the map and can dictate their own movement through it. This could be achieve in 2 ways:

 1. Draw multiple `TileMapLayer` nodes with different parameters for different characters with different capabilities and have them correspond accordingly.
 2. Refactor the code so that each character will have a component that draw its own graph from a `TileMapLayer`.

## Contact

Contact and follow me on [itch.io](https://lestavol.itch.io/) for future updates and new projects or contact me on Discord as Lestavol.

[itch.io Tool link](https://lestavol.itch.io/platformer-pathfinding-godot-gdscript-441)
