--!strict
--!optimize 2

--[[
RETURN MAH FACE BAK!!! said robloxians
Ok! said the script itself

A updated fork of RBX-ReturnMyFace by J4KEWasNotHere
]]

local module = {HeadStorage = {}}

-- Configure

local PREFER_USER = true
-- If false, and the character is possesed by a player,
-- it'll use the character's information instead of the user's information.
-- (MAY NOT ALWAYS WORK AS INTENDED)

local NO_DYNAMIC_HEADS = false
-- If true, and the dynamic head is not found in the bin/database,
-- returnClassicFace will silently bail out instead of using fallback data.

-- Services
local PlayerService = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Types
type FaceAssetId = {
	id: number,
	prefix: string
}

type HeadStorageEntry = {
	classic: BasePart,
	dynamic: BasePart,
}

-- Objects
local Storage = script:FindFirstChild("storage", true) or Instance.new("Folder")
Storage.Name = "storage"
Storage.Parent = script

local HeadTemplate = script:WaitForChild("Head")

-- Modules
local Bin = require("@self/bin")
local Shaper = require("@self/shaper")

-- Constants
local FALLBACK_DATA: FaceAssetId = {
	id = 144080495,
	prefix = "rbxassetid://"
}

local HEAD_ACCESSORY_TYPES = {
	Enum.AccessoryType.Hat,
	Enum.AccessoryType.Hair,
	Enum.AccessoryType.Face,
	Enum.AccessoryType.Eyebrow,
	Enum.AccessoryType.Eyelash,
}

local HEAD_SCALE = Vector3.new(1.25, 1.25, 1.25)
local V3_ONE = Vector3.one

-- Utility

local function isFallback(id: number): boolean
	return id == FALLBACK_DATA.id
end

local function tryGetSource(dynamicHeadId: number): FaceAssetId?
	local id, src = Bin.get(dynamicHeadId)
	if isFallback(id) and dynamicHeadId ~= FALLBACK_DATA.id then
		return nil
	end
	return src
end

local function searchForDynamicHeadId(userId: number): (number, { [string]: any }, string?)
	local appearanceData = PlayerService:GetCharacterAppearanceInfoAsync(userId)
	if not appearanceData then return 0, {}, nil end
	
	for _, assetData in appearanceData.assets do
		if assetData.assetType.id == 79 or assetData.assetType.name == "DynamicHead" then
			local headShape = assetData.meta and assetData.meta.headShape
			return assetData.id, assetData, headShape
		end
	end
	
	return 0, {}, nil
end

local function getClassicFaceIdFromDynamicHeadId(dynamicHeadId: number): (number, FaceAssetId)
	local id: number, source: FaceAssetId = Bin.get(dynamicHeadId)
	return id, source
end

-- Builder

local function remove(object: Instance): ()
	if typeof(object) == "Instance" then object:Destroy() end
end

local function getHeadScale(character: Model): number
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return 1 end
	if humanoid.RigType == Enum.HumanoidRigType.R6 then return 1 end -- scaling doesnt work with r6.
	
	local headscale = humanoid:FindFirstChild("HeadScale")
	if headscale and headscale:IsA("NumberValue") then return headscale.Value end
	
	return humanoid:GetAppliedDescription().HeadScale
end

local function getHeadShape(character: Model): string
	local head = character:FindFirstChild("Head")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local humanoidDescription = humanoid and humanoid:FindFirstChildOfClass("HumanoidDescription")
	local shape = nil
	
	if not shape and humanoidDescription then
		for _, itemDescription in humanoidDescription:GetChildren() do
			if not itemDescription:IsA("BodyPartDescription") then continue end
			if itemDescription.BodyPart ~= Enum.BodyPart.Head then continue end
			return itemDescription.HeadShape
		end
	end
	
	return shape or "Default"
end

local function refreshAccessories(character: Model, scale: number?, accessoryOffset: Vector3?): ()
	local offset = accessoryOffset or Vector3.zero
	local accessories = {}
	for _, accessory in character:GetChildren() do
		if not accessory:IsA("Accessory") then continue end
		table.insert(accessories, accessory)
		accessory.Parent = nil

		if table.find(HEAD_ACCESSORY_TYPES, accessory.AccessoryType) then
			local handle = accessory:FindFirstChild("Handle")
			if not handle or not handle:IsA("BasePart") then continue end

			if scale then
				local originalSize = handle:FindFirstChild("OriginalSize")
				if not originalSize then
					originalSize = Instance.new("Vector3Value")
					originalSize.Name = "OriginalSize"
					originalSize.Value = handle.Size
					originalSize.Parent = handle
				end
				handle.Size = (originalSize :: Vector3Value).Value * scale
			end

			for _, attachment in handle:GetChildren() do
				if not attachment:IsA("Attachment") then continue end
				local originalPos = attachment:FindFirstChild("OriginalPosition")
				if not originalPos then
					originalPos = Instance.new("Vector3Value")
					originalPos.Name = "OriginalPosition"
					originalPos.Value = attachment.Position
					originalPos.Parent = attachment
				end
				attachment.Position = (originalPos :: Vector3Value).Value * (scale or 1) + offset
			end
		end
	end

	RunService.Heartbeat:Wait()

	for _, accessory in accessories do
		accessory.Parent = character
	end
end

local function setFaceTexture(head: Instance, texture: string): ()
	local face = head:FindFirstChild("face") or head:FindFirstChild("Face")
	if face and face:IsA("Decal") then
		face.Texture = texture
	end
end

local function setHeadMesh(head: Instance, dynamic: boolean, scale: number?, shape: string?, isR6: boolean?): Vector3
	local mesh = head:FindFirstChildOfClass("SpecialMesh")
	if not mesh then return Vector3.zero end

	if dynamic then
		mesh.MeshType = Enum.MeshType.FileMesh
		mesh.Scale = V3_ONE
		mesh.Offset = Vector3.zero

		local textureId = mesh:GetAttribute("texture_id")
		if textureId then
			mesh.TextureId = textureId
			mesh:SetAttribute("texture_id", nil)
		end

		local headId = mesh:GetAttribute("head_id")
		if headId then
			mesh.MeshId = headId
			mesh:SetAttribute("head_id", nil)
		end

		return Vector3.zero
	else
		if not mesh:GetAttribute("head_id") then
			mesh:SetAttribute("head_id", mesh.MeshId)
		end
		mesh.MeshType = Enum.MeshType.Head
		mesh.Scale = HEAD_SCALE * math.max(0, scale or 1)
	end

	if not dynamic then
		local accessoryOffset = Shaper.set(mesh, shape or "Default")
		mesh.Scale = mesh.Scale * math.max(0, scale or 1)
		return accessoryOffset
	end

	return Vector3.zero
end

local function swapHead(character: Model, wantDynamic: boolean, texture: string?, scale: number, shape: string?): BasePart?
	local currHead = character:FindFirstChild("Head") :: BasePart?
	local part0 = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not part0 or not currHead then return nil end
	
	local isR6 = part0.Name == "Torso"
	
	if isR6 then
		if texture then setFaceTexture(currHead, texture) end
		local accessoryOffset = setHeadMesh(currHead, wantDynamic, scale, shape, true)
		refreshAccessories(character, scale, accessoryOffset)
		return currHead
	end
	
	local storage: HeadStorageEntry? = module.HeadStorage[character]
	
	if storage then
		local outgoing = wantDynamic and storage.classic or storage.dynamic
		local incoming = wantDynamic and storage.dynamic or storage.classic

		outgoing.Parent = Storage
		incoming.Parent = character

		if texture then setFaceTexture(incoming, texture) end
		local accessoryOffset = setHeadMesh(incoming, wantDynamic, scale, shape, isR6)
		refreshAccessories(character, scale, accessoryOffset)
		return incoming
	end
	
	local classicHead = HeadTemplate:Clone()
	classicHead.Name = "Head"
	classicHead.Color = currHead.Color
	classicHead:SetAttribute("IsDynamic", false)
	
	if scale ~= 1 then
		--classicHead.Size = Vector3.new(2, 1, 1) * scale
		for _, obj in classicHead:GetDescendants() do
			if obj:IsA("Vector3Value") then
				obj.Value *= scale
			elseif obj:IsA("Attachment") then
				obj.Position *= scale
				obj.Orientation *= scale
			end
		end
	end
	
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local requiredNeck = true
	
	if humanoid then
		requiredNeck = humanoid.RequiresNeck
		humanoid.RequiresNeck = false
	end
	
	local neck = Instance.new("Motor6D")
	neck.Name = "Neck"
	neck.Part0 = part0 :: BasePart
	neck.Part1 = classicHead
	
	neck.C0 = CFrame.new(0, (part0 :: BasePart).Size.Y / 2, 0)
	neck.C1 = CFrame.new(0, -classicHead.Size.Y / 2, 0)
	
	currHead.Parent = Storage
	neck.Parent = classicHead
	
	module.HeadStorage[character] = {
		classic = classicHead,
		dynamic = currHead,
	}
	
	local activeHead: BasePart
	if wantDynamic then
		classicHead.Parent = Storage
		currHead.Parent = character
		activeHead = currHead
	else
		classicHead.Parent = character
		activeHead = classicHead
	end
	
	if humanoid then wait() humanoid.RequiresNeck = requiredNeck end
	
	if texture then setFaceTexture(activeHead, texture) end
	local accessoryOffset = setHeadMesh(activeHead, wantDynamic, scale, shape, isR6) -- last was false, nil (<-)
	refreshAccessories(character, scale, accessoryOffset)
	
	return activeHead
end

local function hasStaticHead(character: Model): boolean
	local head = character:FindFirstChild("Head")
	if not head then return true end
	local mesh = head:FindFirstChildOfClass("SpecialMesh")
	local face = head:FindFirstChild("face") or head:FindFirstChild("Face")
	local meshIsStatic = (face and mesh and #mesh:GetChildren() < 2 and mesh.MeshType == Enum.MeshType.Head) and true or false
	return meshIsStatic
end

local function resolveSourceFromDesc(desc: HumanoidDescription?): (FaceAssetId?, boolean)
	if not desc or desc.Head == 0 then return nil, false end
	local src = tryGetSource(desc.Head)
	if not src then return nil, true end -- had a head id but not in bin
	return src, false
end

-- Public (get)

function module.getClassicFaceIdFromHumanoidDescription(humanoidDescription: HumanoidDescription): (number?, FaceAssetId)
	local dynamicHeadId = humanoidDescription.Head
	if not dynamicHeadId or dynamicHeadId == 0 then return nil, FALLBACK_DATA end
	local classicFaceId, src = getClassicFaceIdFromDynamicHeadId(dynamicHeadId)
	return classicFaceId, src
end

function module.getClassicFaceIdFromUserId(userId: number): (number?, FaceAssetId, string?)
	local dynamicHeadId, _, shape = searchForDynamicHeadId(userId)
	if dynamicHeadId == 0 then return nil, FALLBACK_DATA, nil end
	local classicFaceId, src = getClassicFaceIdFromDynamicHeadId(dynamicHeadId)
	return classicFaceId, src, shape
end

function module.getClassicFaceIdFromCharacter(character: Model): (number?, FaceAssetId)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return nil, FALLBACK_DATA end
	
	local humanoidDescription = humanoid:FindFirstChildOfClass("HumanoidDescription")
	if humanoidDescription and humanoidDescription.Head ~= 0 then
		local classicFaceId, src = getClassicFaceIdFromDynamicHeadId(humanoidDescription.Head)
		return classicFaceId, src
	end
	
	local player: Player? = PlayerService:GetPlayerFromCharacter(character)
	if player then
		local id, data = module.getClassicFaceIdFromUserId(player.UserId)
		return id, data
	end
	
	return nil, FALLBACK_DATA
end

-- Public (set)

-- Returns a character's dynamic head to its classic state.
function module.returnClassicFace(character: Model)
	if hasStaticHead(character) then return end
	
	local scale = getHeadScale(character)
	local source: FaceAssetId
	
	local player: Player? = PlayerService:GetPlayerFromCharacter(character)
	local headShape = getHeadShape(character)
	
	if player and PREFER_USER then
		local dynamicHeadId = searchForDynamicHeadId(player.UserId)
		if dynamicHeadId == 0 then
			if NO_DYNAMIC_HEADS then return end
			source = FALLBACK_DATA
		else
			local src = tryGetSource(dynamicHeadId)
			if not src then
				if not NO_DYNAMIC_HEADS then return end
				source = FALLBACK_DATA
			else
				source = src
			end
		end
	else
		-- Covers both player (not PREFER_USER) and NPC 
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local desc = humanoid and humanoid:FindFirstChildOfClass("HumanoidDescription")
		local src, notInBin = resolveSourceFromDesc(desc)
		if not src then
			if notInBin and not NO_DYNAMIC_HEADS then print("stopped") return end
			source = FALLBACK_DATA
		else
			source = src
		end
	end
	
	local texture = source.prefix .. source.id
	swapHead(character, false, texture, scale, headShape)
end

-- Returns a character's head to its dynamic state - must already exist in the character.
function module.returnDynamicHead(character: Model)
	local storage: HeadStorageEntry? = module.HeadStorage[character]
	if not storage then
		local head = character:FindFirstChild("Head")
		if not head then return end
		setHeadMesh(head, true, nil, nil)
		return
	end
	swapHead(character, true, nil, getHeadScale(character))
end

-- Cleanup
PlayerService.PlayerAdded:Connect(function(player)
	player.CharacterRemoving:Connect(function(character)
		local storage: HeadStorageEntry? = module.HeadStorage[character]
		if not storage then return end
		remove(storage.classic)
		remove(storage.dynamic)
		module.HeadStorage[character] = nil
	end)
end)

return table.freeze(module)
