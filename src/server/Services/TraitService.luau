-- Event traits strike slimes already in your pens: during a Lava Storm a meteor can hit
-- a slime and give it the Meteor trait, Candy Party rains Sugar on them, and so on.
-- This makes every event worth being online for.

local Config = require(game.ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local Roller = require(script.Parent.Roller)
local Net = require(script.Parent.Net)

local TraitService = {}

local function traitForEvent(event: string): string?
	for name, t in Config.Traits do
		if t.event == event then
			return name
		end
	end
	return nil
end

local function has(list: { string }?, name: string): boolean
	return list ~= nil and table.find(list, name) ~= nil
end

local function strike()
	local event = Roller.ActiveEvent()
	local trait = event and traitForEvent(event)
	if not trait then
		return
	end
	local def = Config.Traits[trait]
	for _, plot in PlotService.AllPlots() do
		local owner = plot.owner
		local data = owner and DataService.Get(owner)
		if not owner or not data then
			continue
		end
		local hit = {}
		for i, s in data.slimes do
			if not has(s.traits, trait) and #(s.traits or {}) < Config.MaxTraits and math.random() < Config.TraitStrikeChance then
				s.traits = s.traits or {}
				table.insert(s.traits, trait)
				table.insert(hit, i)
			end
		end
		if #hit > 0 then
			for _, i in hit do
				local pad = plot.model.Pens:FindFirstChild("Pen" .. i)
				if pad then
					Net.FxAll("strike", { pos = pad.Position, color = def.color, icon = def.icon })
				end
			end
			task.delay(0.9, PlotService.Render, owner)
			Net.Notify(owner, def.icon .. " " .. #hit .. " of your slimes got the " .. trait .. " trait (x" .. def.mult .. ")!", "epic")
		end
	end
end

function TraitService.Start()
	task.spawn(function()
		while true do
			task.wait(Config.TraitStrikeEverySeconds)
			strike()
		end
	end)
end

return TraitService
