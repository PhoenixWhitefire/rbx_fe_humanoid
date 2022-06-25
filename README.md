ServerHumanoid is a project aimed to mitigate character exploits in Roblox.

# What are character exploits?
Stuff like high walkspeed, noclip, teleport, stuff that involves the player's character. It doesn't need to be physics either, exploiters can delete any non-basepart in the character, stuff like their Humanoid or server-scripts.

# How does this work?
The server handles the player's _real_ character, and client sees a "puppet". The client uses the puppet to record the player's inputs, and sends the inputs to the server, which them moves the _real_ character, preventing any sort of chicanery.

# Credits
AlreadyPro - Load Character Lite's code is used to load player characters from Roblox avatar

Credit is appreciated, but _not_ required.
