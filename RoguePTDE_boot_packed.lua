-- Rogue Lineage PTDE bootloader (small) — downloads main script reliably
print("[PTDE] bootloader starting…")
local HttpService = game:GetService("HttpService")
local URL = "https://raw.githubusercontent.com/KScroom/universal-duels/master/RoguePTDE_packed.lua?v=ptde2"
local req = (syn and syn.request) or (http and http.request) or http_request or request

local function download(url)
	if req then
		local ok, res = pcall(req, {
			Url = url,
			Method = "GET",
			Headers = { ["Cache-Control"] = "no-cache" },
		})
		if ok and type(res) == "table" then
			local body = res.Body or res.body
			local code = res.StatusCode or res.statusCode or 0
			print("[PTDE] request status=", code, "bytes=", body and #body or 0)
			if type(body) == "string" and #body > 10000 then
				return body
			end
		else
			warn("[PTDE] request failed:", res)
		end
	end
	print("[PTDE] falling back to HttpGet…")
	return game:HttpGet(url, true)
end

local src = download(URL)
if type(src) ~= "string" or #src < 10000 then
	error("[PTDE] download failed / empty body (" .. tostring(src and #src) .. ")", 0)
end
print("[PTDE] compiling", #src, "chars…")
local fn, err = loadstring(src)
if not fn then
	error("[PTDE] compile failed: " .. tostring(err), 0)
end
print("[PTDE] executing…")
local ok, runtimeErr = pcall(fn)
if not ok then
	warn("[PTDE] runtime error:", runtimeErr)
	error(runtimeErr, 0)
end
print("[PTDE] bootloader done")
