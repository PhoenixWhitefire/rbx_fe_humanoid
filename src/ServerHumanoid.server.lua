--PWF

--Credit to AlreadyPro for Roblox avatar loading code ("ALREADYPRO_LoadCharacter", script.LoadCharacterModule)

--Date format: DD/MM/YYYY

--Created: 20/06/2022
--Last updated: 25/06/2022

--ServerHumanoid: A system for combatting character exploits by using a server-controlled version of the player's character

--Runtime generated instances (Instance.new) are prefixed with "SERVERHUMANOID_" to help differentiate them from normal game instances

--SETTINGS

local R15 = true --Change to 'false' to use R6

--MAIN CODE
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Remotes = ReplicatedStorage.Remotes

--All server-controlled humanoids
local ServerHumanoids = workspace.ServerHumanoids

--Custom character
local PlayerCharacterTemplate = ReplicatedStorage:FindFirstChild("PLAYER_AVATAR_OVERRIDE")
local IsGameUsingRobloxAvatar = if PlayerCharacterTemplate then false else true

local ALREADYPRO_LoadCharacter = require(script.LoadCharacterModule)

if not IsGameUsingRobloxAvatar and not PlayerCharacterTemplate:FindFirstChildWhichIsA("Humanoid") then
	error("ServerHumanoid requires character template (ReplicatedStorage.PLAYER_AVATAR_OVERRIDE) to have a Humanoid!")
end

--If packets are sent too often, but the tick sent with them (GetServerTimeNow) is not TickDelta far apart, the player may be exploiting
local PlayerRequestsInfo = {}

local Tickrate = ReplicatedStorage.Tickrate.Value

if Tickrate > 60 then
	warn("Tickrate cannot be greater than 60 due to FPS limits")
	
	Tickrate = 60
end

local TickDelta = 1 / Tickrate

local ServerCharacterScripts = {}

--Used for telling the client what localscripts it should put into it's local character, stuff like animating scripts etc
--since we want animations to be responsive on the client
local ClientScriptsFolder = Instance.new("Folder")
ClientScriptsFolder.Name = "SERVERHUMANOID_ClientCharacterScripts"

for _, Script:BaseScript in pairs(ServerStorage.CharacterScripts:GetChildren()) do
	if Script.Disabled then
		continue
	else
		if Script:IsA("LocalScript") then
			Script:Clone().Parent = ClientScriptsFolder --No real point in making a variable
		else
			table.insert(ServerCharacterScripts, Script)
		end
	end
end

ClientScriptsFolder.Parent = ReplicatedStorage

--Client is asking the server to respawn the character
Remotes.RequestSpawnCharacter.OnServerEvent:Connect(function(Player)
	--Workaround for an issue where Local Server player's names would shift from lowercase to uppercase after a bit,
	--leading to the server naming characters "PLAYER1" (for example) and then trying to access them as "Player1"
	local PlayerName = string.lower(Player.Name)
	
	if ServerHumanoids:FindFirstChild(PlayerName) then
		ServerHumanoids[PlayerName]:Destroy() --Get rid of old character first
	end
	
	local NewCharacter : Model?
	
	if IsGameUsingRobloxAvatar then
		NewCharacter = ALREADYPRO_LoadCharacter(PlayerName, ServerHumanoids, R15) --Load player character from their Roblox avatar
		
		NewCharacter.Name = PlayerName
		
		for _, Object in pairs(NewCharacter:GetDescendants()) do
			if Object:IsA("BasePart") then
				Object.Anchored = false --Make sure nothing is anchored
			end
		end
	else
		NewCharacter = PlayerCharacterTemplate:Clone() --Use custom character
		NewCharacter.Name = PlayerName
		
		NewCharacter.Parent = ServerHumanoids
	end
	
	--Initialize a key in PlayerRequestsInfo for anti- remote-spam
	PlayerRequestsInfo[PlayerName] = {
		LastRequestSent = 0,
		LastTickSent = 0,
		Infractions = 0
	}
	
	local CharacterData = script.TemplateData:Clone()
	CharacterData.Name = PlayerName
	CharacterData.Parent = ReplicatedStorage.Characters
	
	NewCharacter:WaitForChild("Humanoid") --Wait for humanoid to load so CharacterScripts can immediately use it by Character.Humanoid
	
	for _, CharacterScript in pairs(ServerCharacterScripts) do
		CharacterScript:Clone().Parent = NewCharacter
	end
end)

--Client is telling the server the character is not moving in the correct direction, not jumping, or not looking the right way
Remotes.UpdateMove.OnServerEvent:Connect(function(Player, MoveDirection, Jump, LookDirection, Tick)
	local PlayerName = string.lower(Player.Name)
	
	ReplicatedStorage.Characters[PlayerName].CommandID.Value += 1
	
	local Character = ServerHumanoids:FindFirstChild(PlayerName)
	
	if not Character then
		--Possibly log this, player could be exploiting
		--Don't kick them though, it could be an issue with latency
		
		warn(Player.Name, "requested UpdateMove, but has no character!")
		
		return
	end
	
	--Do some basic type checks
	if typeof(MoveDirection) ~= "Vector3" or typeof(Jump) ~= "boolean" or typeof(LookDirection) ~= "number" or typeof(Tick) ~= "number" then
		--Player is DEFINITELY exploiting
		
		Player:Kick("Exploiting")
		
		warn(Player.Name, "requested UpdateMove, but MoveDirection (second parameter) is not a Vector3!")
		
		PlayerRequestsInfo[PlayerName] = nil
		
		return
	end
	
	local PlayerInfo = PlayerRequestsInfo[PlayerName]
	
	if not PlayerInfo then
		return
	end
	
	--The server should have the latest game tick, not the client!
	if Tick > workspace:GetServerTimeNow() then
		Player:Kick("Exploiting")
		
		warn(Player.Name, "requested UpdateMove, but Tick sent is ahead of server!")
		
		PlayerRequestsInfo[PlayerName] = nil
		
		PlayerInfo = nil
		
		return
	else
		local DifferenceSigned = Tick - PlayerInfo.LastTickSent
		
		--Tick is apparently from before the last tick
		if DifferenceSigned < 0 then
			if PlayerInfo.LastTickSent == 0 then --Basically the same as 'if Tick < 0'
				--The only way the player can get kicked in this scenario is if they sent a NEGATIVE Tick value, which is impossible to get normally
				
				Player:Kick("Exploiting")
				
				warn(Player.Name, "sent a negative Tick parameter with UpdateMove")
			else
				Player:Kick("Packets out-of-order")
				
				warn(Player.Name, "has fired UpdateMove with Tick parameter LOWER than previous Tick")
			end
		end
		
		--How long has it been since the last tick was sent
		local Difference = math.abs(DifferenceSigned) --math.abs makes sure it's always positive
		
		if Difference < TickDelta  then
			PlayerRequestsInfo[PlayerName].Infractions += 1
			
			if PlayerRequestsInfo[PlayerName].Infractions > 10 then
				Player:Kick("Exploiting")
				
				warn(Player.Name, "was spamming remotes! Tick difference was", Difference, "but should be at minimum", TickDelta * 0.5 .. "!")
				
				PlayerRequestsInfo[PlayerName] = nil
				
				PlayerInfo = nil
				
				return
			end
		end
	end
	
	PlayerInfo.LastTickSent = Tick
	
	if MoveDirection.X ~= MoveDirection.X
		or MoveDirection.Y ~= MoveDirection.Y
		or MoveDirection.Z ~= MoveDirection.Z
	then
		--MoveDirection vector has some NaNs, do not proceed

		warn("NaN move vector for", Player.Name)

		return
	end
	
	--It doesn't matter if MoveDirection is out of the -1 to 1 range, the speed won't increase
	Character.Humanoid:Move(MoveDirection)
	
	Character.Humanoid.Jump = Jump
	
	--Make character look correct direction
	Character.PrimaryPart.CFrame = CFrame.new(Character.PrimaryPart.Position) * CFrame.Angles(0, math.rad(LookDirection), 0)
end)

--Update character info in ReplicatedStorage
RunService.Heartbeat:Connect(function()
	for _, CharacterData in pairs(ReplicatedStorage.Characters:GetChildren()) do
		local Character = workspace.ServerHumanoids:FindFirstChild(CharacterData.Name)
		
		if not Character then
			continue
		end
		
		local JumpVector = Vector3.new(
			0,
			if Character.Humanoid.Jump then 1 else 0,
			0
		)
		
		--The client checks all of these values to see whether the server is up-to-date on player inputs, and, if not, then
		--call UpdateMove
		CharacterData.MoveDirection.Value = Character.Humanoid.MoveDirection + JumpVector
		CharacterData.Velocity.Value = Character.PrimaryPart.AssemblyLinearVelocity
		CharacterData.CharacterCFrame.Value = Character.PrimaryPart.CFrame
		CharacterData.YLook.Value = Character.PrimaryPart.Orientation.Y
	end
end)
