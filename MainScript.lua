-- Mainscript for a turret in my Roblox Game
--The turret will turn and aim towards players not on the turret's team, then it will fire bullets towards the enemy player's position
local joint = script.Parent.Torso.MovableJoint -- Important Values/Objects
local myHuman = script.Parent.Humanoid
local myRoot = script.Parent.HumanoidRootPart
local myTeam = script.Parent.TeamColor
local NPCFuncs = require(game.ServerScriptService.NPCModule) -- A module I created for NPCs, Includes distance check, check line of sight, and raycasting




local range = 500 -- Adjustable stats
local damage = 10
local rate = 20
local bulletSpeed = 300

local shootDB = false -- Cooldown: true = can't be fired.



joint.C0 = CFrame.new() -- set the initial orientation of the neck. CFrame(Coordinate Frame) is a position+orientation value. The neck is rotated to aim
script.Parent.Head.BrickColor = myTeam.Value



local clone = script.Parent:Clone() --Clone for Respawn Backup


myRoot.Beam.Color = ColorSequence.new({  -- Beam shows the target of the turret
	ColorSequenceKeypoint.new(0,script.Parent.TeamColor.Value.Color);
	ColorSequenceKeypoint.new(1,script.Parent.TeamColor.Value.Color)
})

local function findTarget() -- Searches for a target

	local target = nil
	local potentialTargets = {}
	for i, v in pairs(workspace:GetDescendants()) do -- go through all items in the workspace(visible part of the game)
		local targetHuman = v:FindFirstChild("Humanoid")
		local targetRoot = v:FindFirstChild("HumanoidRootPart")
		if targetHuman and targetRoot and NPCFuncs.CheckDist(myRoot,targetRoot) <= range  and NPCFuncs.CheckDist(myRoot,targetRoot) > 10 and NPCFuncs.CheckSight(script.Parent.Muzzle,targetRoot) and targetHuman.Health > 0 then -- Matches all requirments for target
			if v:FindFirstChild("TeamColor") then
				if v.TeamColor.Value ~= myTeam.Value then -- On different teams
					table.insert(potentialTargets,{targetRoot;NPCFuncs.CheckDist(myRoot,targetRoot)})
				end
			end
		end
	end
	table.sort(potentialTargets,function(a,b)-- Sort from shortest distance to longest. Always targets closer targets.
		return a[2] < b[2]
	end)
	if potentialTargets[1] then
		target = potentialTargets[1][1]
	end
	return target
end

local function aim(targetPart)
	local unit = (targetPart.CFrame.Position - script.Parent.Muzzle.CFrame.Position).Unit--Get the unit vector of the direction the turret is supposed to point
	local RotationOffset = (script.Parent.PrimaryPart.CFrame-script.Parent.PrimaryPart.CFrame.p):inverse()--Constant rotational offset to be negated
	for i = 0.1,1,0.1 do
		wait()
		joint.C0 = joint.C0:Lerp(CFrame.new(Vector3.new(0,0,0),unit) * RotationOffset * CFrame.Angles(0,-1*math.rad(90),0),i)-- additional 90 degrees needed due to face misalignment(right face in front face's position) while rigging. Lerp used for smooth effect
	end

end
local function shoot()
	if not shootDB then -- not on cooldown
		script.Parent.Head.Shoot:Play()--sound
		shootDB = true -- turn on cooldown
		script.Parent.FirePosition.Attachment.ParticleEmitter:Emit(1)--muzzle flash
		delay(1/rate,function()--waits (1/rate) seconds, runs in another thread
			shootDB = false --turn off cooldown
		end)
		local bullet = script.Parent.Bullet:Clone()--make new bullet
		bullet.Transparency = 0--bullet properties 
		bullet.CanCollide = false
		bullet.Anchored = true
		bullet.CFrame = script.Parent.FirePosition.CFrame
		bullet.Parent = workspace
		bullet.Trail.Enabled = true
		
		delay(10,function()
			if bullet then
				bullet:Destroy()
			end
		end)
		local touchConn --Touched event connection, assigning variable for disconnection later to save resources
		local connection --Stepped connection
		
		local function hit(instance)
			if instance.Parent:FindFirstChild("Humanoid") then
				if instance.Parent:FindFirstChild("TeamColor") then
					if instance.Parent.TeamColor.Value ~= myTeam.Value then --Damages enemy players and other NPCs
						instance.Parent.Humanoid:TakeDamage(damage)
					end
				else
					instance.Parent.Humanoid:TakeDamage(damage)
				end
			end
			local sound = script.Parent.Head.Hit:Clone()
			sound.Parent = bullet
			sound:Play()
			bullet.Transparency = 1
			connection:Disconnect()--Cleanup
			touchConn:Disconnect()
			delay(0.5,function()
				bullet:Destroy()
			end)
		end
		touchConn = bullet.Touched:Connect(function(part)-- Connecting the hit event to the hit function
			if not part:IsDescendantOf(script.Parent) then --checking if it hit the turret itself
				hit(part)
			end
		end)
		connection = game:GetService("RunService").Stepped:Connect(function(running,elapsed)-- Connecting the Stepped(Fires each frame) event to a new function
			local result = NPCFuncs.Raycast(bullet.Position,bullet.CFrame.LookVector * bulletSpeed * elapsed,{script.Parent;bullet})--Raycast to see if there is something between previous position and current position
			if result then
				local instance = result.Instance
				if instance and not instance:IsDescendantOf(script.Parent) then
					if instance.Parent:FindFirstChild("Humanoid") then
						if instance.Parent:FindFirstChild("TeamColor") then
							hit(instance)
						end
					end
					bullet.Transparency = 1
					connection:Disconnect()
					delay(0.5,function()
						bullet:Destroy()
					end)
				end
			end
			bullet.Position = bullet.Position + bullet.CFrame.LookVector * bulletSpeed * elapsed--Manually move forwards. Smoother than physics-affected parts
		end)
	end
	
end

local barrelTweenInfo = TweenInfo.new( -- Tween creates smooth animated changes in properties.
	1,
	Enum.EasingStyle.Sine,
	Enum.EasingDirection.InOut,
	0,
	false,
	0
)

local tweenService = game:GetService("TweenService")
local startTween = tweenService:Create(script.Parent.Head.HingeConstraint,barrelTweenInfo,{AngularVelocity = 20})--Faster barrel spin
local endTween = tweenService:Create(script.Parent.Head.HingeConstraint,barrelTweenInfo,{AngularVelocity = 0})
local engineStart = tweenService:Create(script.Parent.Head.Engine,barrelTweenInfo,{PlaybackSpeed = 5})--Higher speed = higher pitch
local engineEnd = tweenService:Create(script.Parent.Head.Engine,barrelTweenInfo,{PlaybackSpeed = 1})
myHuman.Died:Connect(function()
	local e = Instance.new("Explosion",workspace)
	e.DestroyJointRadiusPercent = 0
	e.Position = myRoot.Position
	myRoot.Explosion:Play()
	--When died, explodes
	for i = 0.01,1,0.01 do
		wait(0.1)
		joint.C0 = joint.C0:Lerp(CFrame.Angles(math.rad(-25),0,0),i)
	end
	--turns barrel to a specific point
	script.Parent.Support.Anchored = false
	endTween:Play()
	--slows down barrel rotation
	wait(5)
	clone.Parent = workspace
	script.Parent:Destroy()
end)
local function main()--main function
	local target = findTarget()--get target
	if target then
		myRoot.Beam.Attachment1 = target:FindFirstChildOfClass("Attachment") or Instance.new("Attachment",target)
		startTween:Play()
		engineStart:Play()
		aim(target)--aim
		
	else
		myRoot.Beam.Attachment1 = nil
		endTween:Play()
		engineEnd:Play()
	end
end
spawn(function()
	while wait() do
		if findTarget() and myHuman.Health > 0 then
			script.Parent.FirePosition.Attachment.Smoke.Enabled = true
			shoot()-- keep shooting if there is a target
		else
			script.Parent.FirePosition.Attachment.Smoke.Enabled = false
		end	
	end

end)
while wait() do
	if myHuman.Health > 0 then
		main()--keep running main function
	else
		myRoot.Beam:Destroy()
		endTween:Play()
		engineEnd:Play()
		--death cleanup
		break
	end
end
