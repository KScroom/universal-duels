--[[
  SM2 UI — Obsidian backend with Rayfield Gen2-compatible API.
  Loads vendored Obsidian (RogueLib) from this repo — no sirius.menu / Rayfield assets.
  Usage:
    local UI = loadstring(game:HttpGet("https://raw.githubusercontent.com/KScroom/universal-duels/master/SM2UI_ObsidianCompat_packed.lua"))()
    -- UI:CreateWindow / CreateTab / CreateToggle / ... (Rayfield Gen2 shaped)
]]

local function http_get(url)
	local req = (syn and syn.request) or (http and http.request) or http_request or request
	if req then
		local ok, res = pcall(req, {
			Url = url,
			Method = "GET",
			Headers = { ["Cache-Control"] = "no-cache" },
		})
		if ok and type(res) == "table" then
			local body = res.Body or res.body
			if type(body) == "string" and #body > 100 then
				return body
			end
		end
	end
	return game:HttpGet(url)
end

local LIB_URL = "https://raw.githubusercontent.com/KScroom/universal-duels/master/RogueLib_packed.lua?v=obs4"
local Library
do
	local src = http_get(LIB_URL)
	assert(type(src) == "string" and #src > 1000, "[SM2UI] failed to download Obsidian library")
	local chunk = loadstring(src)
	assert(chunk, "[SM2UI] Obsidian library compile failed")
	Library = chunk()
	assert(type(Library) == "table" and Library.CreateWindow, "[SM2UI] Obsidian library invalid")
end

-- Soften Obsidian default accent away from purple bias if theme not set
pcall(function()
	if Library.Scheme then
		Library.Scheme.AccentColor = Color3.fromRGB(220, 220, 230)
	end
end)

local Compat = {}
Compat.__index = Compat
Compat._windows = {}
Compat._library = Library

local function flag_or(opts, fallback)
	local f = opts and (opts.flag or opts.Flag)
	if type(f) == "string" and #f > 0 then
		return f
	end
	return fallback
end

local function unique_flag(base)
	base = tostring(base or "elem"):gsub("%W", "_")
	local n = (Compat._flag_i or 0) + 1
	Compat._flag_i = n
	return base .. "_" .. tostring(n)
end

local function key_name_from_value(v)
	if typeof(v) == "EnumItem" and v.EnumType == Enum.KeyCode then
		return v.Name
	end
	if type(v) == "string" and Enum.KeyCode[v] then
		return v
	end
	if type(v) == "table" then
		if type(v.Name) == "string" and Enum.KeyCode[v.Name] then
			return v.Name
		end
		if type(v[1]) == "string" and Enum.KeyCode[v[1]] then
			return v[1]
		end
	end
	return "E"
end

local function enum_from_key_value(v)
	local name = key_name_from_value(v)
	return Enum.KeyCode[name] or Enum.KeyCode.E
end

function Compat:Destroy()
	for _, w in ipairs(self._windows) do
		pcall(function()
			if w and w._raw and false then
			end
		end)
	end
	table.clear(self._windows)
	pcall(function()
		if Library.Unload then
			Library:Unload()
		end
	end)
end

function Compat:Notify(opts)
	opts = opts or {}
	local title = opts.Title or opts.title or opts.name or "SM2"
	local content = opts.Content or opts.content or opts.Description or opts.description or opts.Text or opts.text or ""
	local dur = opts.Duration or opts.duration or 3
	pcall(function()
		Library:Notify(tostring(title) .. ": " .. tostring(content), dur)
	end)
end

local TabProxy = {}
TabProxy.__index = TabProxy

function TabProxy:_group()
	if not self._gb then
		self._gb = self._tab:AddLeftGroupbox(self._name or "Main")
		self._side = "left"
	elseif not self._gb2 then
		-- keep dumping into left; Obsidian layout stays readable
	end
	return self._gb
end

function TabProxy:CreateToggle(opts)
	opts = opts or {}
	local flag = unique_flag(flag_or(opts, opts.name or "Toggle"))
	local g = self:_group()
	local t = g:AddToggle(flag, {
		Text = tostring(opts.name or opts.Name or flag),
		Default = opts.value == true or opts.Value == true,
		Tooltip = opts.description or opts.Description,
		Callback = function(v)
			if opts.callback then
				pcall(opts.callback, v)
			end
			if opts.Callback then
				pcall(opts.Callback, v)
			end
		end,
	})
	return t
end

function TabProxy:CreateSlider(opts)
	opts = opts or {}
	local flag = unique_flag(flag_or(opts, opts.name or "Slider"))
	local range = opts.range or opts.Range or { 0, 100 }
	local min = tonumber(range[1]) or 0
	local max = tonumber(range[2]) or 100
	local g = self:_group()
	return g:AddSlider(flag, {
		Text = tostring(opts.name or opts.Name or flag),
		Default = tonumber(opts.value or opts.Value) or min,
		Min = min,
		Max = max,
		Rounding = tonumber(opts.increment or opts.Increment or 1) or 1,
		Tooltip = opts.description or opts.Description,
		Callback = function(v)
			if opts.callback then
				pcall(opts.callback, v)
			end
			if opts.Callback then
				pcall(opts.Callback, v)
			end
		end,
	})
end

function TabProxy:CreateDropdown(opts)
	opts = opts or {}
	local flag = unique_flag(flag_or(opts, opts.name or "Dropdown"))
	local values = opts.options or opts.Options or opts.Values or {}
	local default = opts.value or opts.Value or values[1]
	local defaultIndex = 1
	for i, v in ipairs(values) do
		if v == default then
			defaultIndex = i
			break
		end
	end
	local g = self:_group()
	return g:AddDropdown(flag, {
		Text = tostring(opts.name or opts.Name or flag),
		Values = values,
		Default = defaultIndex,
		Tooltip = opts.description or opts.Description,
		Callback = function(v)
			if opts.callback then
				pcall(opts.callback, v)
			end
			if opts.Callback then
				pcall(opts.Callback, v)
			end
		end,
	})
end

function TabProxy:CreateKeybind(opts)
	opts = opts or {}
	local flag = unique_flag(flag_or(opts, opts.name or "Keybind"))
	local keyName = key_name_from_value(opts.value or opts.Value or Enum.KeyCode.E)
	local g = self:_group()
	local label = g:AddLabel(tostring(opts.name or opts.Name or "Keybind"))
	return label:AddKeyPicker(flag, {
		Default = keyName,
		Text = tostring(opts.name or opts.Name or "Keybind"),
		Mode = "Hold",
		Tooltip = opts.description or opts.Description,
		Callback = function(v)
			local key = enum_from_key_value(v)
			if opts.onChanged then
				pcall(opts.onChanged, key)
			end
			if opts.OnChanged then
				pcall(opts.OnChanged, key)
			end
			if opts.callback then
				pcall(opts.callback, key)
			end
			if opts.Callback then
				pcall(opts.Callback, key)
			end
		end,
		ChangedCallback = function(v)
			local key = enum_from_key_value(v)
			if opts.onChanged then
				pcall(opts.onChanged, key)
			end
			if opts.OnChanged then
				pcall(opts.OnChanged, key)
			end
		end,
	})
end

function TabProxy:CreateButton(opts)
	opts = opts or {}
	local g = self:_group()
	return g:AddButton({
		Text = tostring(opts.name or opts.Name or "Button"),
		Func = function()
			if opts.callback then
				pcall(opts.callback)
			end
			if opts.Callback then
				pcall(opts.Callback)
			end
		end,
		Tooltip = opts.description or opts.Description,
	})
end

function TabProxy:CreateLabel(opts)
	opts = opts or {}
	local g = self:_group()
	local text = opts.name or opts.Name or opts.text or opts.Text or ""
	return g:AddLabel(tostring(text))
end

function TabProxy:CreateParagraph(opts)
	return self:CreateLabel(opts)
end

function TabProxy:CreateDivider()
	local g = self:_group()
	if g.AddDivider then
		return g:AddDivider()
	end
	return g:AddLabel("────────")
end

local WindowProxy = {}
WindowProxy.__index = WindowProxy

function WindowProxy:CreateTab(opts)
	opts = opts or {}
	local name = opts.name or opts.Name or "Tab"
	local tab = self._window:AddTab(tostring(name))
	local proxy = setmetatable({
		_tab = tab,
		_name = tostring(name),
		_gb = nil,
	}, TabProxy)
	return proxy
end

function Compat:CreateWindow(opts)
	opts = opts or {}
	local title = opts.name or opts.Name or opts.Title or "SM2"
	local footer = opts.subtitle or opts.Subtitle or opts.Footer or ""

	local window = Library:CreateWindow({
		Title = tostring(title),
		Footer = tostring(footer),
		ToggleKeybind = Enum.KeyCode.RightShift,
		Center = true,
		AutoShow = true,
		NotifySide = "Right",
		ShowCustomCursor = false,
	})

	-- Show immediately
	pcall(function()
		if Library.Toggle and not Library.Toggled then
			Library:Toggle()
		end
	end)

	local proxy = setmetatable({ _window = window }, WindowProxy)
	table.insert(self._windows, proxy)
	return proxy
end

-- Alias common Rayfield top-level helpers
function Compat:LoadConfiguration() end
function Compat:SaveConfiguration() end

print("[SM2UI] Obsidian compat ready (no Rayfield / sirius)")
return setmetatable({}, Compat)
