-- Script Hub Entry Point
-- This is the only script users need to run.

local BASE_URL = "https://raw.githubusercontent.com/soldiv86-rgb/DivineSouls/main/"

local function fetch(path)
	local success, result = pcall(function()
		return game:HttpGet(BASE_URL .. path)
	end)

	if not success then
		warn("[DivineSouls] Failed to fetch: " .. path)
		return nil
	end

	return result
end

-- Load the loader module
local loaderSource = fetch("core/loader.lua")
if not loaderSource then
	warn("[DivineSouls] Could not load core loader. Aborting.")
	return
end

local success, Loader = pcall(function()
	return loadstring(loaderSource)()
end)

if not success then
	warn("[DivineSouls] Loader failed to execute: " .. tostring(Loader))
	return
end

-- Run it
Loader:Run()
