--SETTINGS

local CLOSE_BY = 5
local A_BIT_FAR = 20

--MAIN CODE
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Player = Players.LocalPlayer
local PlayerName = string.lower(Player.Name)

local Characters = workspace.ServerHumanoids
local Remotes = ReplicatedStorage.Remotes

--Since the client must get rid of the server character model locally, store character data in a folder in ReplicatedStorage
local CharacterDatas = ReplicatedStorage.Characters
local ServerCharacterData

local LocalCharacter

local Tickrate = ReplicatedStorage.Tickrate.Value

if Tickrate > 60 then
	warn("Limiting update rate to 60") --Roblox limits client FPS to 60, can't go above this
	
	Tickrate = 60
end

local TickDelta = 1 / Tickrate --How long to wait between each :FireServer call
local LocalCmdID = 0

local LocalCharacterScripts = ReplicatedStorage:WaitForChild("SERVERHUMANOID_ClientCharacterScripts")

local function CreateCharacter()
	LocalCharacter = nil
	
	Remotes.RequestSpawnCharacter:FireServer()
	
	local Character = Characters:WaitForChild(PlayerName) --Wait for character to spawn
	
	LocalCharacter = Character:Clone() --Clone character - player avatar or custom character
	
	Player.Character = LocalCharacter --Let the player control the LOCAL character's humanoid

	--Get rid of the server character model locally so it doesn't show up on the player's screen, replication issues
	--mean we can't let Player.Character be the server character
	Character:Destroy()
	
	ServerCharacterData = CharacterDatas[PlayerName]
	
	LocalCharacter.Parent = workspace
	
	LocalCharacter:WaitForChild("Humanoid") --Make sure the Humanoid exists before continuing

	for _, CharacterScript in pairs(LocalCharacterScripts:GetChildren()) do
		CharacterScript:Clone().Parent = LocalCharacter
	end
end

while true do
	if not Player.Character then --Spawn character if character does not exist, i.e., player just joined or just died
		CreateCharacter()
	end
	
	local JumpVector = Vector3.new(
		0,
		if LocalCharacter.Humanoid.Jump then 1 else 0,
		0
	)
	
	local ServerMove = ServerCharacterData.MoveDirection.Value
	--ServerMove includes whether the character is jumping with Y = 1,
	--so ClientMove must as well
	local ClientMove = LocalCharacter.Humanoid.MoveDirection + JumpVector
	
	--Check if the server is moving the character in the correct direction + if they are jumping + if the character is rotated correctly
	if ServerMove ~= ClientMove or ServerCharacterData.YLook.Value ~= LocalCharacter.PrimaryPart.Orientation.Y then
		--Increment command number for synchronization purposes
		LocalCmdID += 1
		
		Remotes.UpdateMove:FireServer(
			LocalCharacter.Humanoid.MoveDirection,
			LocalCharacter.Humanoid.Jump,
			LocalCharacter.PrimaryPart.Orientation.Y,
			workspace:GetServerTimeNow()
		)
	end
	
	--Wait until it's time for the next tick
	task.wait(TickDelta)
	
	--Check if the server is at the same point in time as the client
	if ServerCharacterData.CommandID.Value == LocalCmdID and LocalCharacter then
		--Smoothly move local character to correct position
		LocalCharacter.PrimaryPart.CFrame = LocalCharacter.PrimaryPart.CFrame:Lerp(ServerCharacterData.CharacterCFrame.Value, 0.1)
		
		if (LocalCharacter.PrimaryPart.Position - ServerCharacterData.CharacterCFrame.Value.Position).Magnitude > CLOSE_BY then
			--Teleport them if they get too far from the server character instead
			LocalCharacter.PrimaryPart.CFrame = ServerCharacterData.CharacterCFrame.Value
		end
	end
	
	if (LocalCharacter.PrimaryPart.Position - ServerCharacterData.CharacterCFrame.Value.Position).Magnitude > A_BIT_FAR then
		--They are TOO FAR from the character, but since they've been actively moving, they haven't been teleported back
		--Teleport them back regardless in this case
		LocalCharacter.PrimaryPart.CFrame = ServerCharacterData.CharacterCFrame.Value
	end
end
