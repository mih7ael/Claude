-- On-foot sprint: hold Shift / L3, or toggle the Sprint button on touch screens.
-- Disabled during missions and while seated so it never competes with flight input.

local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("CoopChaos")
local Theme = require(Shared.Theme)
local UI = require(Shared.UI)

local Store = require(script.Parent.Store)

local C = Theme.Colors
local player = Players.LocalPlayer

local Sprint = {}

local WALK, RUN = 16, 28
local IDLE_FADE = 0.3 -- how faded the PC pill is while you're walking (0 = solid)

local held = false -- keyboard / gamepad hold
local toggled = false -- touch button toggle

local button: TextButton? = nil
local hint: CanvasGroup? = nil
local hintKey: Frame? = nil
local hintKeyLabel: TextLabel? = nil
local hintIcon: ImageLabel? = nil
local hintLabel: TextLabel? = nil
local hintStroke: UIStroke? = nil
local hintBar: Frame? = nil
local hintShown = false
local hintRunning = false

local function humanoid(): Humanoid?
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function allowed(): boolean
	local hum = humanoid()
	return hum ~= nil and hum.Health > 0 and not hum.Sit and not Store.get("InMission")
end

-- The hint pill reads as a state chip: faded glass while walking, solid cyan while you are actually running.
local function paintHint(running: boolean)
	if not hint then
		return
	end
	hintRunning = running
	if hintShown then
		UI.tween(hint, { GroupTransparency = if running then 0 else IDLE_FADE }, Theme.Tween.Fast)
	end
	if hintStroke then
		TweenService:Create(hintStroke, Theme.Tween.Fast, {
			Color = if running then C.Accent else C.Stroke,
			Transparency = if running then 0.05 else 0.45,
		}):Play()
	end
	UI.tween(hint, { BackgroundColor3 = if running then C.Elevated else C.Surface }, Theme.Tween.Fast)
	if hintIcon then
		UI.tween(hintIcon, { ImageColor3 = if running then C.Accent else C.TextDim }, Theme.Tween.Fast)
	end
	if hintKey then
		UI.tween(hintKey, { BackgroundColor3 = if running then C.Accent else C.Elevated }, Theme.Tween.Fast)
	end
	if hintKeyLabel then
		TweenService:Create(hintKeyLabel, Theme.Tween.Fast, {
			TextColor3 = if running then C.AccentText else C.Text,
		}):Play()
	end
	if hintLabel then
		hintLabel.Text = if running then "Sprinting" else "Sprint"
		TweenService:Create(hintLabel, Theme.Tween.Fast, {
			TextColor3 = if running then C.Accent else C.Text,
		}):Play()
	end
	if hintBar then
		UI.tween(hintBar, { Size = UDim2.new(if running then 1 else 0, 0, 0, 2) }, Theme.Tween.Normal)
	end
end

local function showHintFrame(show: boolean)
	if not hint or show == hintShown then
		return
	end
	hintShown = show
	if show then
		hint.Visible = true
		hint.GroupTransparency = 1
		hint.Position = UDim2.new(0, 16, 1, -10)
		UI.tween(hint, {
			GroupTransparency = if hintRunning then 0 else IDLE_FADE,
			Position = UDim2.new(0, 16, 1, -16),
		}, Theme.Tween.Normal)
	else
		local t = UI.tween(hint, { GroupTransparency = 1, Position = UDim2.new(0, 16, 1, -10) }, Theme.Tween.Normal)
		t.Completed:Once(function()
			if hint and not hintShown then
				hint.Visible = false
			end
		end)
	end
end

local function apply()
	local hum = humanoid()
	if not hum then
		return
	end
	local running = allowed() and (held or toggled)
	hum.WalkSpeed = if running then RUN else WALK
	paintHint(running)
	-- PC only; stays up whenever you can sprint. Hidden in menus, missions and seats/vehicles (Shift is throttle there)
	showHintFrame(not UserInputService.TouchEnabled
		and UserInputService.KeyboardEnabled
		and allowed()
		and not Store.get("MenuOpen"))
	if button then
		button.Visible = UserInputService.TouchEnabled and allowed() and not Store.get("MenuOpen")
		UI.tween(button, { BackgroundColor3 = if toggled then C.Accent else C.Background }, Theme.Tween.Fast)
		local ic = button:FindFirstChildOfClass("ImageLabel")
		if ic then
			ic.ImageColor3 = if toggled then C.AccentText else C.Text
		end
		local lbl = button:FindFirstChild("Label") :: TextLabel?
		if lbl then
			lbl.Text = if toggled then "RUNNING" else "SPRINT"
			lbl.TextColor3 = if toggled then C.AccentText else C.Text
		end
	end
end

function Sprint.init(gui: ScreenGui)
	ContextActionService:BindAction("CC_Sprint", function(_, state)
		if Store.get("InMission") then
			return Enum.ContextActionResult.Pass
		end
		held = state == Enum.UserInputState.Begin
		apply()
		return Enum.ContextActionResult.Pass
	end, false, table.unpack(require(Shared.Keybinds).Codes.Sprint))

	-- touch toggle: compact pill above the jump button
	local b = UI.new("TextButton", {
		Name = "SprintButton",
		Text = "",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -168),
		Size = UDim2.fromOffset(104, 44),
		BackgroundColor3 = C.Background,
		BackgroundTransparency = 0.15,
		Visible = false,
		Parent = gui,
	})
	UI.corner(Theme.Radius.Pill).Parent = b
	UI.stroke(C.Accent, 2, 0.1).Parent = b
	UI.padding(0, 12, 0, 10).Parent = b
	UI.list(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center).Parent = b
	UI.icon(Theme.Icons.Sprint, 22, C.Text, { LayoutOrder = 1 }).Parent = b
	UI.text({ Name = "Label", Text = "SPRINT", Style = "Caption", TextSize = 13, FontFace = Theme.Fonts.Bold, TextColor3 = C.Text, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), TextWrapped = false, LayoutOrder = 2, Parent = b })
	b.Activated:Connect(function()
		toggled = not toggled
		apply()
	end)
	button = b

	-- PC hint, bottom-left: keycap + status. Fades back while walking, glows cyan while running.
	local h = UI.new("CanvasGroup", {
		Name = "SprintHint",
		BackgroundColor3 = C.Surface,
		GroupTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.fromOffset(0, 44),
		AutomaticSize = Enum.AutomaticSize.X,
		Visible = false,
		Parent = gui,
	})
	UI.corner(Theme.Radius.Pill).Parent = h
	local stroke = UI.stroke(C.Stroke, 1.5, 0.45)
	stroke.Parent = h
	UI.gradient(C.Elevated, C.Background, 90).Parent = h
	UI.padding(0, 16, 0, 10).Parent = h
	UI.list(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center).Parent = h

	local key = UI.keycap("SHIFT", { LayoutOrder = 1 })
	key.Parent = h
	hintKey = key
	hintKeyLabel = key:FindFirstChild("Label") :: TextLabel?

	UI.new("Frame", {
		Name = "Divider",
		BackgroundColor3 = C.Stroke,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(1, 18),
		LayoutOrder = 2,
		Parent = h,
	})

	local ic = UI.icon(Theme.Icons.Sprint, 18, C.TextDim, { LayoutOrder = 3 })
	ic.Parent = h
	hintIcon = ic

	local lbl = UI.text({
		Name = "Label",
		Text = "Sprint",
		Style = "Body",
		TextSize = 14,
		FontFace = Theme.Fonts.Bold,
		TextColor3 = C.Text,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		TextWrapped = false,
		LayoutOrder = 4,
		Parent = h,
	})
	hintLabel = lbl

	-- cyan underline under the label that sweeps in while running
	hintBar = UI.new("Frame", {
		Name = "RunBar",
		BackgroundColor3 = C.Accent,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -9),
		Size = UDim2.new(0, 0, 0, 2),
		Parent = lbl,
	})

	hint = h
	hintStroke = stroke
	paintHint(false)

	local function watchCharacter(char: Model)
		local hum = char:WaitForChild("Humanoid") :: Humanoid
		toggled, held = false, false
		hum:GetPropertyChangedSignal("Sit"):Connect(apply)
		apply()
	end
	if player.Character then
		task.spawn(watchCharacter, player.Character)
	end
	player.CharacterAdded:Connect(watchCharacter)
	Store.watch("InMission", function()
		toggled, held = false, false
		apply()
	end)
	Store.watch("MenuOpen", apply)
end

return Sprint
