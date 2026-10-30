-- Sprint: hold Shift (or tap the button) to run faster.
-- Runs from StarterPlayerScripts, so it starts once per player and the
-- button survives deaths/respawns instead of vanishing.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

-- Settings ---------------------------------------------------------------
local WALK_SPEED = 16
local SPRINT_SPEED = 26

local USE_STAMINA = true
local MAX_STAMINA = 100
local DRAIN_PER_SECOND = 20
local REGEN_PER_SECOND = 15
local REGEN_DELAY = 1 -- seconds after sprinting before stamina refills
local RECOVER_AT = 0.25 -- when empty, can't sprint again until 25% refilled

local SPRINT_KEYS = { Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift }

local COLORS = {
	background = Color3.fromRGB(16, 18, 26),
	backgroundActive = Color3.fromRGB(10, 40, 52),
	stroke = Color3.fromRGB(58, 64, 82),
	text = Color3.fromRGB(205, 210, 224),
	dim = Color3.fromRGB(120, 128, 150),
	accent = Color3.fromRGB(0, 220, 255),
	empty = Color3.fromRGB(255, 85, 95),
	track = Color3.fromRGB(40, 44, 58),
}
---------------------------------------------------------------------------

local player = Players.LocalPlayer
local isTouchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local function make(className, props, children)
	local instance = Instance.new(className)
	for key, value in pairs(props) do
		instance[key] = value
	end
	for _, child in ipairs(children or {}) do
		child.Parent = instance
	end
	return instance
end

-- UI ---------------------------------------------------------------------
local stroke = make("UIStroke", {
	Color = COLORS.stroke,
	Thickness = 1.5,
	ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
})

local keycapStroke = make("UIStroke", {
	Color = COLORS.stroke,
	Thickness = 1,
	ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
})

local keycapLabel = make("TextLabel", {
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	Font = Enum.Font.GothamBold,
	Text = "SHIFT",
	TextSize = 11,
	TextColor3 = COLORS.dim,
})

local keycap = make("Frame", {
	Name = "Keycap",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 12, 0.5, -3),
	Size = UDim2.fromOffset(50, 26),
	BackgroundColor3 = COLORS.track,
	Visible = not isTouchOnly,
}, {
	make("UICorner", { CornerRadius = UDim.new(0, 6) }),
	keycapStroke,
	keycapLabel,
})

local label = make("TextLabel", {
	Name = "Label",
	BackgroundTransparency = 1,
	Position = isTouchOnly and UDim2.fromOffset(0, -3) or UDim2.fromOffset(74, -3),
	Size = isTouchOnly and UDim2.fromScale(1, 1) or UDim2.new(1, -86, 1, 0),
	Font = Enum.Font.GothamBlack,
	Text = "SPRINT",
	TextSize = 16,
	TextColor3 = COLORS.text,
	TextXAlignment = isTouchOnly and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left,
})

local fill = make("Frame", {
	Name = "Fill",
	BackgroundColor3 = COLORS.accent,
	BorderSizePixel = 0,
	Size = UDim2.fromScale(1, 1),
}, {
	make("UICorner", { CornerRadius = UDim.new(1, 0) }),
})

local bar = make("Frame", {
	Name = "StaminaBar",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -7),
	Size = UDim2.new(1, -24, 0, 3),
	BackgroundColor3 = COLORS.track,
	BorderSizePixel = 0,
	Visible = USE_STAMINA,
}, {
	make("UICorner", { CornerRadius = UDim.new(1, 0) }),
	fill,
})

local button = make("TextButton", {
	Name = "SprintButton",
	AutoButtonColor = false,
	Text = "",
	AnchorPoint = isTouchOnly and Vector2.new(1, 0.5) or Vector2.new(0, 1),
	Position = isTouchOnly and UDim2.new(1, -24, 0.55, 0) or UDim2.new(0, 24, 1, -24),
	Size = isTouchOnly and UDim2.fromOffset(120, 52) or UDim2.fromOffset(172, 52),
	BackgroundColor3 = COLORS.background,
	BackgroundTransparency = 0.1,
}, {
	make("UICorner", { CornerRadius = UDim.new(0, 14) }),
	stroke,
	keycap,
	label,
	bar,
})

local scale = make("UIScale", { Parent = button })

make("ScreenGui", {
	Name = "SprintGui",
	ResetOnSpawn = false, -- the old button most likely vanished because of this
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 10,
	Parent = player:WaitForChild("PlayerGui"),
}, { button })

-- Visuals ----------------------------------------------------------------
local FAST = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function tween(instance, props)
	TweenService:Create(instance, FAST, props):Play()
end

local shownActive = nil
local function showActive(active)
	if active == shownActive then
		return
	end
	shownActive = active
	tween(button, { BackgroundColor3 = active and COLORS.backgroundActive or COLORS.background })
	tween(stroke, { Color = active and COLORS.accent or COLORS.stroke })
	tween(label, { TextColor3 = active and COLORS.accent or COLORS.text })
	tween(keycap, { BackgroundColor3 = active and COLORS.accent or COLORS.track })
	tween(keycapStroke, { Color = active and COLORS.accent or COLORS.stroke })
	tween(keycapLabel, { TextColor3 = active and COLORS.background or COLORS.dim })
end

button.MouseEnter:Connect(function()
	tween(scale, { Scale = 1.04 })
end)
button.MouseLeave:Connect(function()
	tween(scale, { Scale = 1 })
end)
button.MouseButton1Down:Connect(function()
	tween(scale, { Scale = 0.96 })
end)
button.MouseButton1Up:Connect(function()
	tween(scale, { Scale = 1 })
end)

-- Input ------------------------------------------------------------------
local keyHeld = false
local toggled = false -- clicking/tapping the button toggles sprint on and off

local function isSprintKey(keyCode)
	return table.find(SPRINT_KEYS, keyCode) ~= nil
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return -- e.g. typing in chat
	end
	if isSprintKey(input.KeyCode) then
		keyHeld = true
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if isSprintKey(input.KeyCode) then
		keyHeld = false
	end
end)

button.Activated:Connect(function()
	toggled = not toggled
end)

-- Sprint loop ------------------------------------------------------------
local stamina = MAX_STAMINA
local exhausted = false
local lastSprintTime = 0
local appliedHumanoid = nil
local appliedSprinting = nil

local function getHumanoid()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return humanoid
	end
	return nil
end

player.CharacterAdded:Connect(function()
	toggled = false
	stamina = MAX_STAMINA
	exhausted = false
end)

RunService.Heartbeat:Connect(function(dt)
	local humanoid = getHumanoid()
	local wantsSprint = keyHeld or toggled
	local moving = humanoid ~= nil and humanoid.MoveDirection.Magnitude > 0.1

	if exhausted and stamina >= MAX_STAMINA * RECOVER_AT then
		exhausted = false
	end

	local sprinting = wantsSprint and moving and not exhausted

	if USE_STAMINA then
		if sprinting then
			stamina = math.max(0, stamina - DRAIN_PER_SECOND * dt)
			lastSprintTime = os.clock()
			if stamina <= 0 then
				exhausted = true
				sprinting = false
			end
		elseif os.clock() - lastSprintTime >= REGEN_DELAY then
			stamina = math.min(MAX_STAMINA, stamina + REGEN_PER_SECOND * dt)
		end
		fill.Size = UDim2.fromScale(stamina / MAX_STAMINA, 1)
		fill.BackgroundColor3 = exhausted and COLORS.empty or COLORS.accent
	end

	-- Only touch WalkSpeed when the state changes, so other scripts
	-- (slows, boosts) aren't overwritten every frame.
	if humanoid and (humanoid ~= appliedHumanoid or sprinting ~= appliedSprinting) then
		humanoid.WalkSpeed = sprinting and SPRINT_SPEED or WALK_SPEED
		appliedHumanoid = humanoid
		appliedSprinting = sprinting
	end

	showActive(sprinting or (toggled and not exhausted))
end)
