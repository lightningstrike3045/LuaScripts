local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local HTTPService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")

local g = workspace.Gravity

local Weapon = script:FindFirstAncestorOfClass("Tool")
if not Weapon then error("Place the system in a Weapon!")end
local RaycastModule = require(script.Parent.RaycastModule)
local WeaponSystem = Weapon.WeaponSystem
local Modules = WeaponSystem.Modules
local Config = Weapon.Configuration
local ObjectConfig = Weapon.Objects
if not Config or not ObjectConfig then
	error("Configuration or Objects missing in tool!")
end

local ReloadAnimation = ObjectConfig.ReloadAnimation.Value
local HoldingAnimation = ObjectConfig.HoldingAnimation.Value
local Bullet = ObjectConfig.Bullet.Value
local MuzzleFlash = ObjectConfig.MuzzleFlash.Value
local FireSound = ObjectConfig.FireSound.Value
local HitEffects = ObjectConfig.HitEffects.Value

local BulletCapacity = Config.Capacity.Value
local Explodes = Config.Explodes.Value
local BR = Config.Explodes.BlastRadius.Value
local BP = Config.Explodes.BlastPressure.Value
local IsShown = Config.Explodes.ExplosionShown.Value
local DespawnTime = Config.BulletDespawnTime.Value
local IsAuto = Config.IsAutomatic.Value
local HitParticleCount = Config.HitParticleCount.Value
local MuzzleParticleCount = Config.MuzzleParticleCount.Value
local ReloadTime = Config.ReloadTime.Value
local ADS_Enabled = Config.AimDownSightsEnabled.Value
local GravityEffectMultiplier = Config.GravityEffectMultiplier.Value
local Damage = Config.Damage.Value
local Speed = Config.BulletSpeed.Value

local DmgShowModule = require(game.ServerStorage.ModuleScripts.Show_Dmg_Module)
if not Bullet then
	error("There is no bullet specified!")
end



local CanHit = Instance.new("BoolValue",Bullet)
CanHit.Value = true
CanHit.Name = 'CanHit'
-------------------------------------------------------------
local FireDB = false
local AutoOn = false
local BulletAmount = BulletCapacity
local CurrentDamageTag = ''
-------------------------------------------------------------
local function getUser()
	local Character = script:FindFirstAncestorOfClass("Model")
	if not Character then error("Weapon not in Character!") end
	local plr = Players:GetPlayerFromCharacter(Character)
	if not plr then error("Model not associated with player!") end
	return plr, Character
	
end
local function getUserFromHit(Part)
	if Part.Parent:FindFirstChildOfClass("Humanoid") then
		local char = Part.Parent
		local Plr = Players:GetPlayerFromCharacter(char)
		if Plr then
			return Plr
		end
	end
	return nil
end

local ReloadTrack = nil
local module = {}
module.isReloading = false
function module.Reload()
	
	if not module.isReloading then
		module.cancelReload()
		local plr,char = getUser()
		local Humanoid = char:FindFirstChildOfClass("Humanoid")
		if not Humanoid then return end
		local Animator = Humanoid:FindFirstChildOfClass("Animator")
		if not Animator then return end
		module.isReloading = true
		local ReloadTrack = Animator:LoadAnimation(ReloadAnimation)
		ReloadTrack:Play()
		delay(ReloadTime,function()
			if module.isReloading then
				module.isReloading = false
				WeaponSystem.Variables.Bullets.Value = BulletCapacity
			end
		end)
		
	end
end

function module.cancelReload()
	module.isReloading = false
	if ReloadTrack then
		ReloadTrack:Stop()
	end
end


function module.onHit(hit,pos)
	if RunService:IsServer() then
		if Explodes then
			local explosion = Instance.new("Explosion")
			explosion.Position = pos
			explosion.BlastRadius = BR
			explosion.BlastPressure = BP
			explosion.Parent = workspace
			explosion.Visible = IsShown
			explosion.DestroyJointRadiusPercent=0
			explosion.ExplosionType = Enum.ExplosionType.NoCraters
			
			local hitPart = Instance.new("Part",workspace)
			hitPart.Transparency = 1
			hitPart.Shape = Enum.PartType.Ball
			hitPart.Size = Vector3.new(2*BR,2*BR,2*BR)
			hitPart.CanCollide = false
			hitPart.Position = pos
			hitPart.Anchored = true
			local hitParts = workspace:GetPartsInPart(hitPart)
			local position = hitPart.Position
			hitPart:Destroy()

			
			local Conn 
			Conn = explosion.Hit:Connect(function(part,dist)
				local plr = getUserFromHit(part)
				if plr and plr.TeamColor ~= getUser().TeamColor then
					if not CollectionService:HasTag(plr,CurrentDamageTag) then
						CollectionService:AddTag(plr,CurrentDamageTag)
						plr.Character.Humanoid:TakeDamage(Damage * (1 - dist/BR))
						DmgShowModule.makeDmgShowGUI(pos,Damage*(1-dist/BR))
						
					end
				end
				if not plr and part.Parent:FindFirstChild("Humanoid") then
					if not CollectionService:HasTag(part.Parent,CurrentDamageTag) then
						CollectionService:AddTag(part.Parent,CurrentDamageTag)
						print(Damage * 1-dist/BR)
						part.Parent.Humanoid:TakeDamage(Damage * (1-dist/BR))
						DmgShowModule.makeDmgShowGUI(pos,Damage*(1-dist/BR))
					end
				end
				if CollectionService:HasTag(part,"RamParts") then
					if not CollectionService:HasTag(part.Parent,CurrentDamageTag) then
						local Center = part.Parent:FindFirstChild("Center")
						if Center then
							if Center:FindFirstChild("Health") then
								Center.Health.Value -= Damage*(1-dist/BR)
								DmgShowModule.makeDmgShowGUI(part.Position,Damage*(1-dist/BR))
							end
						end
					end
				end
			end)
			
			local Tag = CurrentDamageTag
			delay(1,function()
				for i, plr in pairs(Players:GetPlayers()) do
					if CollectionService:HasTag(plr,Tag) then
						CollectionService:RemoveTag(plr,Tag)
						Conn:Disconnect()
					end
				end
			end)
		else
			local plr = true --getUserFromHit(hit)
			if plr then
				local human = plr.Character:FindFirstChildOfClass("Humanoid")
				if human then
					human:TakeDamage(Damage)
					
				end
			end
		end
		if HitEffects then
			local ClonedEffects = HitEffects:clone()
			ClonedEffects.Parent = workspace
			ClonedEffects.Position = pos
			for i, child in pairs(ClonedEffects:GetChildren()) do
				if child:IsA("Sound") then
					child:Play()
					
				end
				if child:IsA("ParticleEmitter") then
					child:Emit(HitParticleCount)
				end
			end
			Debris:AddItem(ClonedEffects,2)
		end
	end

end

function module.HitDetection(currentBullet,Target)
	if RunService:IsServer() then
		local function makePart(pos)
			local Part = Instance.new("Part")
			Part.Parent = workspace
			Part.Size = Vector3.new(0.3,0.3,0.3)
			Part.Material = Enum.Material.Neon
			Part.Anchored = true
			Part.Position = pos
			Part.CanCollide = false
			Part.CanTouch = false
			Part.CanQuery = false
		end
		CurrentDamageTag = HTTPService:GenerateGUID(false)
		local CurrentPosition = currentBullet.Position
		local Velocity = (Target - CurrentPosition).Unit * Speed
		local FrameConnection
		FrameConnection = RunService.Stepped:Connect(function(total,Delta)
			local NewPosition = CurrentPosition + Velocity * Delta
			Velocity -= Vector3.new(0,g * GravityEffectMultiplier * Delta)
			local Result = RaycastModule.raycast(CurrentPosition,NewPosition-CurrentPosition,{currentBullet,Weapon})
			if Result and Result.Instance then
				print("Hit")
				module.onHit(Result.Instance,Result.Position)
				FrameConnection:Disconnect()
			end
			CurrentPosition = NewPosition
		end)
	end
end


return module
