-- KiciaEval loader tag=c7b9ff
local base = "https://raw.githubusercontent.com/KScroom/universal-duels/master/kicia_eval_c7b9ff/"
local n = 9
local chunks = table.create and table.create(n) or {}
for i = 1, n do
	local body = game:HttpGet(base .. "p" .. i .. ".txt")
	if type(body) ~= "string" or #body == 0 then
		error("[KiciaEval] failed to download part " .. i, 0)
	end
	chunks[i] = body
end
local src = table.concat(chunks)
local fn, err = (loadstring or load)(src)
if not fn then
	error("[KiciaEval] loadstring failed: " .. tostring(err), 0)
end
fn()
