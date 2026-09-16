local Loader = {}

-- Change this to your actual GitHub username and repo name
local BASE_URL = "https://raw.githubusercontent.com/soldiv86-rgb/DivineSouls/main/"

-- Map Roblox game IDs to the folder name inside /games
local GAME_MAP = {
	["10035204815"] = "RideAPet", 
	["10742439589"] = "Campfire",
	["10735530810"] = "EggUpgradeTree",
	-- replace with the real GameId of the game this maps to
	-- ["1111111"] = "game2",
}

function Loader:Run()
	local gameId = tostring(game.GameId)
	local folder = GAME_MAP[gameId]

	if not folder then
		warn("[DivineSouls]This game is not supported yet. GameId: " .. gameId)
		return
	end

	local url = BASE_URL .. "games/" .. folder .. "/main.lua"

	local success, result = pcall(function()
		return game:HttpGet(url)
	end)

	if not success then
		warn("[DivineSouls] Failed to fetch game module: " .. tostring(result))
		return
	end

	local success2, err = pcall(function()
	local chunk, compileErr = loadstring(result)
	if not chunk then
		error("Failed to compile game module: " .. tostring(compileErr))
	end
	chunk()
end)

	if not success2 then
		warn("[DivineSouls] Error running game module: " .. tostring(err))
	end
end

return Loader
