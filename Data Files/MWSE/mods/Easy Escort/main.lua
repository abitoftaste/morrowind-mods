
--[[
	Mod Initialization: Easy Escort
	Author: NullCascade

	Ensures that your followers get warped to you if they get too far away. Compatible with any
	follower from any mod, without any special script attached to that NPC.

]]--

local config = mwse.loadConfig("Easy Escort")
if (config == nil) then
	config = {
		pollRate = 5,
		followDistance = 2000,
		blackList = {},
	}
else
	-- Clear out old capitalization.
	if (config.blackList) then
		config.blacklist = config.blackList
		config.blackList = nil
	end
end

-- Determines if an id is in the blacklist.
local function isInBlacklist(id)
	return (table.find(config.blacklist, id) ~= nil)
end

-- Determines if an actor is in the blacklist.
local function isActorInBlackList(actor)
	local reference = actor.reference

	-- Get the ID. If we're looking at an instance, check against the base object instead.
	local id = reference.id
	if (reference.object.isInstance) then
		id = reference.object.baseObject.id
	end

	-- Is it not in our blacklist?
	return isInBlacklist(id)
end

-- Determines if an actor is a valid companion.
local function validCompanionCheck(actor)
	-- The player shouldn't count as his own companion.
	if (actor == tes3.mobilePlayer) then
		return false
	end

	-- Respect the blacklist.
	if (isActorInBlackList(actor)) then
		return false
	end

	-- Make sure we don't teleport dead actors.
	local animState = actor.actionData.animationAttackState
	if (actor.health.current <= 0 or animState == tes3.animationState.dying or animState == tes3.animationState.dead) then
		return false
	end

	return true
end

-- Repositions any followers that don't share a cell with the player.
local function forceFollowFriendlyActors(e)
	local currentCell = tes3.getPlayerCell()

	local positionParams = {
		cell = currentCell.id,
		x = tes3.mobilePlayer.position.x,
		y = tes3.mobilePlayer.position.y,
		z = tes3.mobilePlayer.position.z
	}

	for actor in tes3.iterate(tes3.mobilePlayer.friendlyActors) do
		if (validCompanionCheck(actor)) then
			local reference = actor.reference
			if (reference.cell ~= currentCell or reference.position:distance(tes3.mobilePlayer.position) > config.followDistance) then
				positionParams.reference = reference
				mwscript.positionCell(positionParams)
			end
		end
	end
end

-- Use timers based on the poll rate.
local function onLoaded(e)
	timer.delayOneFrame(function()
		timer.start(config.pollRate, forceFollowFriendlyActors, 0)
		event.register("cellChanged", forceFollowFriendlyActors)
	end)
end
event.register("loaded", onLoaded)

-- 
-- Initialize interop library to support modifying the blacklist.
-- 

local interop = require("Easy Escort.interop")

function interop.addToBlacklist(id)
	table.insert(config.blacklist, id)
end

function interop.removeFromBlacklist(id)
	table.removevalue(config.blacklist, id)
end

interop.blacklistContains = isInBlacklist

interop.validCompanionCheck = validCompanionCheck

-- 
-- Set up Mod Config Menu support.
-- 

local modConfig = require("Easy Escort.mcm")
modConfig.config = config
local function registerModConfig()
	mwse.registerModConfig("Easy Escort", modConfig)
end
event.register("modConfigReady", registerModConfig)

-- Finally let the log know we're loaded.
mwse.log("[Easy Escort] Initialized with configuration:\n%s", json.encode(config, { indent = true }))
