--!strict
--!optimize 2

local V3Zero = Vector3.zero
local V3One = Vector3.one
local V3YAxis = Vector3.yAxis

local shaper = {
	src = {
		["Default"] = {
			MeshId = "",
			Offset = V3Zero, 
			MeshType = Enum.MeshType.Head,
			Scale = V3One * 1.25
		},
		
		["ManHead"] = {
			MeshId = "rbxassetid://8635368147",
			Offset = V3Zero, 
			MeshType = Enum.MeshType.FileMesh,
			Scale = V3One * 1
		},
		
		["WomanHead"] = {
			MeshId = "rbxassetid://8635368421",
			Offset = V3Zero, 
			MeshType = Enum.MeshType.FileMesh,
			Scale = V3One * 0.95
		},
		
		["NeoClassicMaleV2"] = {
			MeshId = "rbxassetid://4812934511",
			Offset = V3Zero, 
			MeshType = Enum.MeshType.FileMesh,
			Scale = V3One * 0.9,
			
			AccessoryOffset = Vector3.new(0, -0.25, 0.05)
		},
		
		["NeoClassicFemaleV2"] = {
			MeshId = "rbxassetid://4812958584",
			Offset = V3Zero, 
			MeshType = Enum.MeshType.FileMesh,
			Scale = V3One * 0.9,
			
			AccessoryOffset = Vector3.new(0, -0.25, 0.05)
		},
		
		["ClassicMaleV2"] = {
			MeshId = "rbxassetid://9588879695",
			Offset = V3Zero, 
			MeshType = Enum.MeshType.FileMesh,
			Scale = V3One * 0.9,
			
			AccessoryOffset = Vector3.new(0, -0.25, 0.05)
		},
		
		["ClassicFemaleV2"] = {
			MeshId = "rbxassetid://4812919237",
			Offset = V3Zero, 
			MeshType = Enum.MeshType.FileMesh,
			Scale = V3One * 0.9,
			
			AccessoryOffset = Vector3.new(0, -0.25, 0.05)
		},
		
		["Trim"] = {
			MeshId = "rbxassetid://5560742658",
			Offset = V3Zero, 
			MeshType = Enum.MeshType.FileMesh,
			Scale = V3One * 1,
			
			AccessoryOffset = Vector3.new(0, -0.25, 0)
		},
		
		["Roundy"] = {
			MeshId = "rbxassetid://10382778666",
			Offset = V3YAxis * 0.05, 
			MeshType = Enum.MeshType.FileMesh,
			Scale = V3One * 1
		},

		["Blockhead"] = {
			MeshId = "rbxassetid://5560742512",
			Offset = V3Zero, 
			MeshType = Enum.MeshType.FileMesh,
			Scale = V3One * 1
		},
		
		-- Fix Issue #1 by oryaelia in Original Repository
		["Narrow"] = {
			MeshId = "rbxassetid://746775419",
			Offset = Vector3.new(0,-0.1,0),
			MeshType = Enum.MeshType.FileMesh,
			Scale = V3One * 4.8,
		}
	}
}

function shaper.set(specialMesh: SpecialMesh, shape: string, faceId: string?): Vector3
	if typeof(specialMesh) ~= "Instance" or not specialMesh:IsA("SpecialMesh") then return V3Zero end
	if not shape or not shaper.src[shape] then shape = "Default" end
	local data = shaper.src[shape]
	
	specialMesh.MeshId = data.MeshId
	specialMesh.Offset = data.Offset
	specialMesh.MeshType = data.MeshType
	specialMesh.Scale = data.Scale

	local originalTexture = specialMesh:GetAttribute("texture_id")
	if not originalTexture then
		specialMesh:SetAttribute("texture_id", specialMesh.TextureId)
	end

	if not faceId then
		local head = specialMesh.Parent
		if head and head:IsA("BasePart") then
			local face = head:FindFirstChild("face") or head:FindFirstChild("Face")
			if face and face:IsA("Decal") then
				faceId = face.Texture
			end
		end
	end

	specialMesh.TextureId = shape == "Default" and (originalTexture or "") or (faceId or "")

	return data.AccessoryOffset or V3Zero
end

return shaper
