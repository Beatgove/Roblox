-- Redeem codes, kept on the server only so players can't read them out of ReplicatedStorage.
-- Players type these in the CODES menu. Each works once per player.
-- cash: flat cash. incomeSeconds: or that many seconds of income if bigger.
-- luckMinutes: minutes of 5x dispenser luck. slime: a slime id to give.
-- expires: os.time() after which the code stops working (nil = never).
return {
	RELEASE = { cash = 1000, luckMinutes = 15, msg = "Welcome! $1K and 15 minutes of 5x LUCK!" },
	SLIMETIME = { cash = 2500, incomeSeconds = 300, msg = "Cash boost!" },
	LUCKY = { luckMinutes = 30, msg = "30 minutes of 5x LUCK!" },
	FREESLIME = { slime = "Codey", msg = "You got the exclusive Codey slime!" },
	SPOOKY = { slime = "PumpkinKing", expires = os.time({ year = 2026, month = 11, day = 1, hour = 0 }), msg = "Exclusive Pumpkin King slime!" },
}
