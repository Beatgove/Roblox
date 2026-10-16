-- Cross-service events, so services can report things (for quests) without requiring each other.

local Signals = {}

-- (player: Player, kind: string, amount: number) - see Config.QuestPool kinds.
Signals.Quest = Instance.new("BindableEvent")

function Signals.Progress(player: Player, kind: string, amount: number?)
	Signals.Quest:Fire(player, kind, amount or 1)
end

return Signals
