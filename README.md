ServerHumanoid is a project aimed to mitigate character exploits in Roblox.

# What are character exploits?
Stuff like high walkspeed, noclip, teleport, stuff that involves the player's character. It doesn't need to be physics either, exploiters can delete any non-basepart in the character, stuff like their Humanoid or server-scripts.

# How does this work?
The server handles the player's _real_ character, and client sees a "puppet". The client uses the puppet to record the player's inputs, and sends the inputs to the server, which them moves the _real_ character, preventing any sort of chicanery.

# Setup
* Drag-and-drop the .rbxm file into a baseplate or some other open Studio place file
* Ungroup the model (Ctrl + U can be used)
* Move the children models into their places shown by their name
* Ungroup all of the children models
* Done!

# The code
* Any code I didn't write _will not_ be included directly in the repository as .lua files, but some of them _have_ been modified, such as Roblox's default animation scripts.
* The code is documented with comments.
* Some code has been politely _borrowed_ from a certain plugin who's creator refuses to respond to my DMs.

# Credits
AlreadyPro - Load Character Lite's code is used to load player characters from Roblox avatar

Credit is appreciated, but _not_ required.
