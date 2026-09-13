local genv = getgenv()
if genv._DGAP then
	pcall(genv._DGAP.unload)
end

local ESP_STYLES = { "Soul", "Skeleton", "Rift", "Weave" }

local Config = {
	Enabled = true,
	Preset = "Blatant",
	AutoParry = true,
	AutoDodge = true,
	SmartInterrupt = true,
	JumpAttackCounter = true,
	BreakLight = true,
	BreakHeavy = true,
	BreakJump = true,
	BreakDodge = true,
	BreakLightChance = 1,
	BreakHeavyChance = 1,
	BreakJumpChance = 1,
	BreakDodgeChance = 1,
	BreakLightAbs = 1,
	BreakHeavyAbs = 1,
	BreakJumpAbs = 1,
	BreakDodgeAbs = 1,
	ComboMode = "Fastest",
	ComboOnly = false,
	CustomCombo = false,
	ComboMap = {},
	DodgeSpeed = 1,
	DodgeRange = 1,
	DodgeCooldown = 0.15,
	ParryChance = 1,
	DodgeChance = 1,
	IntentionalBlock = false,
	IntentionalBlockChance = 0,
	HumanDelay = false,
	HumanDelayMin = 0,
	HumanDelayMax = 0,
	EspStyle = "Soul",
	EspColorA = Color3.fromRGB(70, 230, 255),
	EspColorB = Color3.fromRGB(190, 80, 255),
	EspSpeed = 1,
	EspThick = 2,
	ReachPad = 0.65,
	ParryLead = 0,
	DodgeLead = 0.22,
	HoldAfter = 0.05,
	MinRemaining = -0.02,
	Visuals = true,
	Hitbox = true,
	HitboxPhysics = "UseAnother",
	HitboxAnimSpeed = 0.7,
	HitboxFallSpeed = 0.45,
	HitboxColorA = Color3.fromRGB(70, 230, 255),
	HitboxColorB = Color3.fromRGB(190, 80, 255),
	GodMode = false,
	Speed = false,
	SpeedValue = 32,
	NoClip = false,
	NoSlowdown = false,
	NoStun = false,
	NoDelay = false,
	WeaponSkins = {},
	HitSound = true,
	HitSoundPreset = "Fatality",
	HitSoundVolume = 3.5,
	HitRing = true,
	HitRingLife = 1.85,
	HitRingR0 = 0.45,
	HitRingR1 = 5.6,
	HitRingThick = 3,
	HitRingColorA = Color3.fromRGB(70, 230, 255),
	HitRingColorB = Color3.fromRGB(190, 80, 255),
	ParrySound = true,
	ParrySoundPreset = "SuccessFX",
	ParrySoundVolume = 3.5,
	AttackHelper = true,
	PerfectDodgeCounter = true,
	AHPunishBlock = true,
	AHPunishWhiff = true,
	AHJumpChase = true,
	StaffDetect = true,
	CustomModel = true,
	CustomModelMaterial = "Glass",
	CustomModelColor = Color3.fromRGB(186, 150, 255),
	CustomModelTransparency = 0.18,
	OutlineColor = Color3.fromRGB(255, 92, 163),
	Debug = false,
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

repeat
	task.wait()
until ReplicatedStorage:GetAttribute("ControllersLoaded") and ReplicatedStorage:FindFirstChild("GameManager")

local function filterTables(keys)
	if type(filtergc) ~= "function" then
		return nil
	end
	local ok, res = pcall(filtergc, "table", { Keys = keys })
	if ok and type(res) == "table" then
		return res
	end
	return nil
end

local function stealTable(pred, keys)
	local list = filterTables(keys)
	if type(list) ~= "table" then
		return nil
	end
	if pred(list) then
		return list
	end
	for _, obj in list do
		if type(obj) == "table" and pred(obj) then
			return obj
		end
	end
	return nil
end

local CharacterController = stealTable(function(obj)
	return type(rawget(obj, "GetLocalCharacterHandler")) == "function"
		and type(rawget(obj, "GetCharacterHandler")) == "function"
		and type(rawget(obj, "GetLoadedCharacterHandlerByCharId")) == "function"
		and rawget(obj, "LocalCharacterLoaded") ~= nil
end, { "GetLocalCharacterHandler", "GetCharacterHandler", "GetLoadedCharacterHandlerByCharId", "LocalCharacterLoaded" })

local MatchController = stealTable(function(obj)
	return type(rawget(obj, "IsCharacterEnemyOfLocalPlayer")) == "function"
		and type(rawget(obj, "ActiveMatches")) == "table"
		and rawget(obj, "MatchStartedForLocalPlayer") ~= nil
end, { "IsCharacterEnemyOfLocalPlayer", "ActiveMatches", "MatchStartedForLocalPlayer" })

local PingController = stealTable(function(obj)
	if type(rawget(obj, "GetPing")) ~= "function" then
		return false
	end
	local n = 0
	for _ in obj do
		n += 1
		if n > 2 then
			return false
		end
	end
	return n == 1
end, { "GetPing" })

local SoundModule = stealTable(function(obj)
	return type(rawget(obj, "PlaySound")) == "function" and type(rawget(obj, "StopSound")) == "function"
end, { "PlaySound", "StopSound" })

if not CharacterController then
	error("[DG-AP] CharacterController not in filtergc (join a character first)")
end

local CYAN = Color3.fromRGB(70, 230, 255)
local MAGENTA = Color3.fromRGB(190, 80, 255)
local CORE = Color3.fromRGB(255, 255, 255)
local RED = Color3.fromRGB(255, 60, 60)
local SLICE = Color3.fromRGB(255, 176, 72)
local DODGE_COL = Color3.fromRGB(160, 120, 255)
local SPARK = Color3.fromRGB(255, 196, 132)
local SPARK_HOT = Color3.fromRGB(255, 248, 236)
local SPARK_EMBER = Color3.fromRGB(255, 78, 28)
local SPARK_STEEL = Color3.fromRGB(186, 196, 210)

local drawings = {}
local conns = {}
local running = true
local rng = Random.new()

local function bind(sig, fn)
	local c = sig:Connect(fn)
	conns[#conns + 1] = c
	return c
end

do
	local duelPlaces = {
		[100484168444874] = true,
		[107083982238164] = true,
		[93870717579227] = true,
	}
	local isDuel = duelPlaces[game.PlaceId] == true
	local okGm, gm = pcall(require, ReplicatedStorage.GameManager)
	if okGm and gm and gm.Globals and gm.Globals.IS_DUEL_RESERVED_SERVER == true then
		isDuel = true
	end
	local kicked = false
	local function expectedCap()
		local m = MatchController and MatchController.ActiveLocalPlayerMatch
		if m and m.Combatants then
			local n = 0
			for _ in m.Combatants do
				n += 1
			end
			if n >= 2 then
				return n
			end
		end
		local mode = ReplicatedStorage:GetAttribute("MM_Gamemode")
		if type(mode) == "string" and string.find(string.lower(mode), "2v2", 1, true) then
			return 4
		end
		return 2
	end
	local function checkStaff()
		if kicked or not Config.StaffDetect or not isDuel or not running then
			return
		end
		if #Players:GetPlayers() > expectedCap() then
			kicked = true
			pcall(function()
				LocalPlayer:Kick("Staff detected!")
			end)
			task.defer(function()
				pcall(function()
					game:Shutdown()
				end)
			end)
		end
	end
	if isDuel then
		bind(Players.PlayerAdded, function()
			task.defer(checkStaff)
		end)
		task.spawn(function()
			while running do
				checkStaff()
				task.wait(0.4)
			end
		end)
	end
end

local function newDraw(class)
	local obj = Drawing.new(class)
	drawings[#drawings + 1] = obj
	return obj
end

local function destroyDraw(obj)
	obj.Visible = false
	obj:Remove()
end

local catalog = {}
local animIndex = {}
local dodgeFwdIds = {}
local dodgeBackIds = {}
local jumpAnimIds = {}
local blockAnimIds = {}
local blockSince = {}
local blockPunishUntil = {}
local blockPunished = {}

local function animIdOf(anim)
	if typeof(anim) == "Instance" then
		return anim.AnimationId
	end
	return nil
end

local function ingestInfo(info)
	if type(info) ~= "table" then
		return
	end
	local wname = info.WeaponName
	if type(wname) ~= "string" or catalog[wname] then
		return
	end
	local pack = {
		name = wname,
		radius = tonumber(info.RootColliderRadius) or 2.5,
		dodgeDist = tonumber(info.DodgeDistance) or 1,
		attacks = {},
		cosmetics = {},
	}
	do
		local c = info.Cosmetics
		if type(c) == "table" then
			for name, mod in c do
				if type(name) == "string" and mod ~= nil and type(mod) ~= "function" then
					pack.cosmetics[#pack.cosmetics + 1] = name
				end
			end
			table.sort(pack.cosmetics)
		elseif typeof(c) == "Instance" then
			for _, ch in c:GetChildren() do
				pack.cosmetics[#pack.cosmetics + 1] = ch.Name
			end
			table.sort(pack.cosmetics)
		end
	end
	local fwdId = animIdOf(info.DodgeForwardAnimation)
	local backId = animIdOf(info.DodgeBackwardAnimation)
	if fwdId then
		dodgeFwdIds[fwdId] = true
	end
	if backId then
		dodgeBackIds[backId] = true
	end
	local blk = animIdOf(info.BlockAnimation)
	if blk then
		blockAnimIds[blk] = true
	end
	local types = info.BasicAttackTypes
	if type(types) ~= "table" then
		catalog[wname] = pack
		return
	end
	for attackName, atk in types do
		if type(atk) == "table" and type(atk.impacts) == "table" then
			local impacts = {}
			for i, imp in atk.impacts do
				local ii = imp.impactInfo
				if type(ii) == "table" then
					local results = ii.impactResults
					local canParry = type(results) == "table" and type(results.Parry) == "table"
					impacts[#impacts + 1] = {
						index = i,
						markerTime = tonumber(imp.markerTime) or 0,
						size = ii.hitboxSize or Vector3.new(6, 7, 7),
						cf = ii.hitboxCFrame or CFrame.new(0, -1.2, -2.8),
						canParry = canParry,
						saDmg = tonumber(ii.superArmorDamage) or 0,
					}
				end
			end
			if #impacts > 0 then
				table.sort(impacts, function(a, b)
					return (a.markerTime or 0) < (b.markerTime or 0)
				end)
				for i, imp in impacts do
					imp.index = i
				end
				local tm = atk.timeMarkers
				local pred, canCancel = 0, 0
				if type(tm) == "table" then
					pred = tonumber(tm.predictionEnd) or 0
					canCancel = tonumber(tm.canCancel) or 0
				end
				local entry = {
					weapon = wname,
					attack = tostring(attackName),
					speed = tonumber(atk.attackSpeedMultiplier) or 1,
					superArmor = tonumber(atk.superArmor) or 0,
					pred = pred,
					canCancel = canCancel,
					animId = animIdOf(atk.animation),
					windup = false,
					impacts = impacts,
					nextLight = type(atk.nextLightAttack) == "string" and atk.nextLightAttack or nil,
					nextHeavy = type(atk.nextHeavyAttack) == "string" and atk.nextHeavyAttack or nil,
				}
				pack.attacks[attackName] = entry
				if entry.animId then
					local list = animIndex[entry.animId]
					if not list then
						list = {}
						animIndex[entry.animId] = list
					end
					list[#list + 1] = entry
				end
			end
		end
	end
	local jump = pack.attacks.JumpAttack
	local prep = info.JumpPrepareAttackAnimation
	if jump and prep then
		local pid = animIdOf(prep)
		if pid then
			local wind = {
				weapon = jump.weapon,
				attack = "JumpAttack",
				speed = jump.speed,
				superArmor = jump.superArmor,
				pred = jump.pred or 0,
				canCancel = jump.canCancel or 0,
				animId = pid,
				windup = true,
				impacts = jump.impacts,
			}
			local list = animIndex[pid]
			if not list then
				list = {}
				animIndex[pid] = list
			end
			list[#list + 1] = wind
		end
	end
	catalog[wname] = pack
end

do
	local list = filterTables({ "WeaponName", "BasicAttackTypes", "RootColliderRadius" })
	if type(list) == "table" then
		if type(rawget(list, "WeaponName")) == "string" then
			ingestInfo(list)
		else
			for _, obj in list do
				if type(obj) == "table" then
					ingestInfo(obj)
				end
			end
		end
	end
end

do
	local def = ReplicatedStorage:FindFirstChild("Animations")
	def = def and def:FindFirstChild("Character")
	def = def and def:FindFirstChild("Default")
	if def then
		local f, b = def:FindFirstChild("DodgeForward"), def:FindFirstChild("DodgeBackward")
		if f and f:IsA("Animation") then
			dodgeFwdIds[f.AnimationId] = true
		end
		if b and b:IsA("Animation") then
			dodgeBackIds[b.AnimationId] = true
		end
		local jc, j = def:FindFirstChild("JumpCrouch"), def:FindFirstChild("Jump")
		if jc and jc:IsA("Animation") then
			jumpAnimIds[jc.AnimationId] = true
		end
		if j and j:IsA("Animation") then
			jumpAnimIds[j.AnimationId] = true
		end
	end
end

local function equippedName(model)
	local w = model and model:GetAttribute("EquippedWeapon")
	if type(w) ~= "string" then
		return nil
	end
	if catalog[w] then
		return w
	end
	w = string.gsub(w, "^%W+", "")
	if catalog[w] then
		return w
	end
	for name in catalog do
		if string.find(w, name, 1, true) then
			return name
		end
	end
	return w
end

local function lookupAttack(weaponName, animId)
	if weaponName and catalog[weaponName] then
		for _, entry in catalog[weaponName].attacks do
			if entry.animId == animId then
				return entry
			end
		end
	end
	local list = animIndex[animId]
	if list then
		return list[1]
	end
	return nil
end

local function ourRadius()
	local lh = CharacterController:GetLocalCharacterHandler()
	if not lh then
		return 2.5
	end
	local w = equippedName(lh.OriginalModel)
	if type(w) == "string" and catalog[w] then
		return catalog[w].radius
	end
	return 2.5
end

local function obbHitsSphere(boxCF, boxSize, center, radius)
	local lp = boxCF:PointToObjectSpace(center)
	local hx = boxSize.X * 0.5
	local hy = boxSize.Y * 0.5
	local hz = boxSize.Z * 0.5
	local dx = lp.X - math.clamp(lp.X, -hx, hx)
	local dy = lp.Y - math.clamp(lp.Y, -hy, hy)
	local dz = lp.Z - math.clamp(lp.Z, -hz, hz)
	return (dx * dx + dy * dy + dz * dz) <= radius * radius
end

local function w2s(v3)
	local p = workspace.CurrentCamera:WorldToViewportPoint(v3)
	if p.Z <= 0 then
		return nil
	end
	return Vector2.new(p.X, p.Y)
end

local function lerpColor(a, b, t)
	t = math.clamp(t, 0, 1)
	return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end

local function gradAlong(t, a, b)
	local spd = a == nil and (Config.EspSpeed or 1) or 1
	local u = (t * spd) % 1
	local s = 0.5 - 0.5 * math.cos(u * 6.283185307179586)
	local ca = a or Config.EspColorA or CYAN
	local cb = b or Config.EspColorB or MAGENTA
	if typeof(ca) ~= "Color3" then
		ca = CYAN
	end
	if typeof(cb) ~= "Color3" then
		cb = MAGENTA
	end
	return lerpColor(ca, cb, s)
end

local linePool = {}
local lineUsed = 0
local circlePool = {}
local circleUsed = 0
local OFF = Vector2.new(-200, -200)

local function beginFrame()
	lineUsed = 0
	circleUsed = 0
end

local function endFrame()
	for i = lineUsed + 1, #linePool do
		local o = linePool[i]
		o.From = OFF
		o.To = OFF
		o.Transparency = 0
		o.Visible = true
	end
	for i = circleUsed + 1, #circlePool do
		local o = circlePool[i]
		o.Position = OFF
		o.Radius = 0
		o.Transparency = 0
		o.Visible = true
	end
end

local function fillCircle(pos, worldR, color, alpha)
	circleUsed += 1
	local o = circlePool[circleUsed]
	if not o then
		o = newDraw("Circle")
		circlePool[circleUsed] = o
		o.Filled = true
		o.NumSides = 16
		o.Visible = true
		o.Thickness = 1
	end
	local sp = workspace.CurrentCamera:WorldToViewportPoint(pos)
	if sp.Z <= 0.08 or alpha < 0.04 then
		o.Position = OFF
		o.Radius = 0
		o.Transparency = 0
		return
	end
	o.Position = Vector2.new(sp.X, sp.Y)
	o.Radius = math.clamp(worldR / sp.Z * 420, 3.5, 34)
	o.Color = color
	o.Filled = true
	o.Transparency = math.clamp(alpha, 0, 1)
end

local function line3(a, b, color, thick, alpha)
	lineUsed += 1
	local o = linePool[lineUsed]
	if not o then
		o = newDraw("Line")
		linePool[lineUsed] = o
		o.Visible = true
	end
	local pa = w2s(a)
	local pb = w2s(b)
	if not pa or not pb then
		o.From = OFF
		o.To = OFF
		o.Transparency = 0
		return
	end
	o.From = pa
	o.To = pb
	o.Color = color
	o.Thickness = thick or 2
	o.Transparency = math.clamp(alpha or 0.92, 0, 1)
end

local BONES = {
	{ "Head", "UpperTorso" },
	{ "UpperTorso", "LowerTorso" },
	{ "UpperTorso", "LeftUpperArm" },
	{ "LeftUpperArm", "LeftLowerArm" },
	{ "LeftLowerArm", "LeftHand" },
	{ "UpperTorso", "RightUpperArm" },
	{ "RightUpperArm", "RightLowerArm" },
	{ "RightLowerArm", "RightHand" },
	{ "LowerTorso", "LeftUpperLeg" },
	{ "LeftUpperLeg", "LeftLowerLeg" },
	{ "LeftLowerLeg", "LeftFoot" },
	{ "LowerTorso", "RightUpperLeg" },
	{ "RightUpperLeg", "RightLowerLeg" },
	{ "RightLowerLeg", "RightFoot" },
}

local lightning = {
	bolts = {},
	lastSpawn = 0,
	appear = 0,
	hurt = 0,
	lastHp = nil,
	lastModel = nil,
}

local hbFX = {
	vis = 0,
	bits = {},
	cf = CFrame.new(),
	size = Vector3.new(4, 4, 4),
	color = SLICE,
	remain = 0.4,
}

local wisps = {}
for i = 1, 7 do
	wisps[i] = {
		off = rng:NextNumber(0, 6.28),
		speed = 0.55 + rng:NextNumber() * 0.45,
		twist = 1.4 + rng:NextNumber() * 1.2,
		rad = 0.55 + rng:NextNumber() * 0.5,
	}
end

local function perp(dir)
	local n = dir.Magnitude
	if n < 1e-6 then
		return Vector3.new(1, 0, 0)
	end
	dir = dir / n
	local arb = math.abs(dir.Y) < 0.9 and Vector3.new(0, 1, 0) or Vector3.new(1, 0, 0)
	local p1 = dir:Cross(arb)
	if p1.Magnitude < 1e-6 then
		p1 = Vector3.new(1, 0, 0)
	else
		p1 = p1.Unit
	end
	local p2 = dir:Cross(p1).Unit
	local ang = rng:NextNumber(0, 6.283185307179586)
	return p1 * math.cos(ang) + p2 * math.sin(ang)
end

local function displace(points, amount, passes)
	local pts = points
	local amt = amount
	for _ = 1, passes do
		local nxt = {}
		for i = 1, #pts - 1 do
			local a = pts[i]
			local b = pts[i + 1]
			nxt[#nxt + 1] = a
			local d = b - a
			if d.Magnitude < 1e-6 then
				nxt[#nxt + 1] = (a + b) * 0.5
			else
				nxt[#nxt + 1] = (a + b) * 0.5 + perp(d) * ((rng:NextNumber() - 0.5) * 2 * amt)
			end
		end
		nxt[#nxt + 1] = pts[#pts]
		pts = nxt
		amt *= 0.5
	end
	return pts
end

local function smoothPath(pts)
	if #pts < 3 then
		return pts
	end
	local out = { pts[1] }
	for i = 1, #pts - 1 do
		local a = pts[i]
		local b = pts[i + 1]
		out[#out + 1] = a * 0.75 + b * 0.25
		out[#out + 1] = a * 0.25 + b * 0.75
	end
	out[#out + 1] = pts[#pts]
	return out
end

local function spawnBolt(radius, yMin, yMax)
	local a0 = rng:NextNumber(0, 6.283185307179586)
	local span = math.max(0.4, yMax - yMin)
	local y0 = yMin + 0.1 + rng:NextNumber() * (span - 0.2)
	local r = radius * (0.7 + rng:NextNumber() * 0.35)
	local start = Vector3.new(math.cos(a0) * r, y0, math.sin(a0) * r)
	local da = (rng:NextNumber() - 0.5) * 3.2
	local dy = (rng:NextNumber() - 0.5) * span * 0.7
	local a1 = a0 + da
	local y1 = math.clamp(y0 + dy, yMin + 0.06, yMax - 0.06)
	local finish = Vector3.new(math.cos(a1) * r, y1, math.sin(a1) * r)
	local dir = finish - start
	local points = smoothPath(displace({ start, finish }, 0.12, 3))
	local branches = {}
	local bc = 2 + rng:NextInteger(0, 2)
	for _ = 1, bc do
		local idx = math.clamp(2 + rng:NextInteger(0, math.max(0, #points - 3)), 1, #points)
		local anchor = points[idx]
		local bdir = perp(dir)
		if rng:NextNumber() > 0.5 then
			bdir = -bdir
		end
		local bend = anchor + bdir * (0.28 + rng:NextNumber() * 0.45)
		branches[#branches + 1] = smoothPath(displace({ anchor, bend }, 0.08, 2))
	end
	return {
		points = points,
		branches = branches,
		spawn = os.clock(),
		life = 0.18 + rng:NextNumber() * 0.16,
		phase = rng:NextNumber() * 6.28,
	}
end

local function boltAlpha(bolt, now)
	local u = math.clamp((now - bolt.spawn) / bolt.life, 0, 1)
	if u < 0.08 then
		return u / 0.08
	end
	if u > 0.55 then
		return (1 - u) / 0.45
	end
	return 1
end

local function boltReveal(bolt, now)
	return math.clamp((now - bolt.spawn) / 0.045, 0, 1)
end

local function worldPath(cf, locals)
	local t = table.create(#locals)
	for i, lp in locals do
		t[i] = cf * lp
	end
	return t
end

local function pathLine(pts, now, thick, alpha, frac)
	local n = #pts - 1
	if n < 1 then
		return
	end
	local last = n
	if frac and frac < 1 then
		last = math.max(1, math.floor(n * frac + 0.5))
	end
	for i = 1, last do
		line3(pts[i], pts[i + 1], gradAlong((i - 0.5) / n + now * 0.28), thick, alpha)
	end
end

local function renderLightning(root, radius, yMin, yMax, appear, now, slots)
	local cf = root.CFrame
	for i = 1, 8 do
		local bolt = slots[i]
		if not bolt or now - bolt.spawn >= bolt.life then
			slots[i] = spawnBolt(radius, yMin, yMax)
			bolt = slots[i]
		end
		local a = boltAlpha(bolt, now) * appear * 0.95
		local rev = boltReveal(bolt, now)
		local pts = worldPath(cf, bolt.points)
		pathLine(pts, now, 2, a, rev)
		local coreUntil = math.clamp(rev * 0.7, 0, 1)
		pathLine(pts, now, 1, a, coreUntil)
		local brRev = math.max(0, (rev - 0.35) / 0.65)
		if brRev > 0 then
			for _, br in bolt.branches do
				pathLine(worldPath(cf, br), now, 1.5, a * 0.85, brRev)
			end
		end
	end
end

local function partPos(model, name)
	local p = model:FindFirstChild(name)
	if p and p:IsA("BasePart") then
		return p.Position
	end
	return nil
end

local function ellipseRing(cf, rx, rz, segs, now, thick, alpha, warp, colOff)
	for i = 1, segs do
		local a0 = (i - 1) / segs * 6.283185307179586
		local a1 = i / segs * 6.283185307179586
		local w0 = 1 + warp * math.sin(a0 * 2 + now * 0.9)
		local w1 = 1 + warp * math.sin(a1 * 2 + now * 0.9)
		local p0 = cf * Vector3.new(math.cos(a0) * rx * w0, 0, math.sin(a0) * rz * w0)
		local p1 = cf * Vector3.new(math.cos(a1) * rx * w1, 0, math.sin(a1) * rz * w1)
		line3(p0, p1, gradAlong(i / segs + now * 0.28 + (colOff or 0)), thick, alpha)
	end
end

local function sphereWire(pos, rad, now, alpha)
	if rad < 0.04 or alpha < 0.04 then
		return
	end
	ellipseRing(CFrame.new(pos), rad, rad, 8, now, 2, alpha, 0.05, 0)
	ellipseRing(CFrame.new(pos) * CFrame.Angles(1.5708, 0, 0), rad, rad, 8, now, 2, alpha, 0.05, 0.2)
	ellipseRing(CFrame.new(pos) * CFrame.Angles(0, 0, 1.5708), rad, rad, 8, now, 2, alpha, 0.05, 0.4)
end

local function shapePoly(kind, n, r)
	local pts = table.create(n + 1)
	kind = kind % 4
	for i = 1, n do
		local t = (i - 1) / n * 6.283185307179586
		local rr = r
		if kind == 1 then
			rr = r * (0.72 + 0.28 * math.cos(t * 3))
		elseif kind == 2 then
			rr = r * (0.62 / math.max(0.35, math.abs(math.cos(t)) + math.abs(math.sin(t))))
		elseif kind == 3 then
			local a = t + 0.5236
			rr = r * (0.78 / math.max(0.4, math.abs(math.cos(a * 2))))
		end
		pts[i] = Vector3.new(math.cos(t) * rr, 0, math.sin(t) * rr)
	end
	pts[n + 1] = pts[1]
	return pts
end

local function morphPoly(k0, k1, t, n, r)
	local a = shapePoly(k0, n, r)
	local b = shapePoly(k1, n, r)
	local out = table.create(n + 1)
	for i = 1, n + 1 do
		out[i] = a[i]:Lerp(b[i], t)
	end
	return out
end

local function renderSoul(model, root, radius, yMin, yMax, _color, appear, now)
	local ease = appear * appear * (3 - 2 * appear)
	local head = partPos(model, "Head") or (root.CFrame * Vector3.new(0, yMax, 0))
	local fl = partPos(model, "LeftFoot")
	local fr = partPos(model, "RightFoot")
	local foot = fl and fr and (fl + fr) * 0.5 or (fl or fr or (root.CFrame * Vector3.new(0, yMin, 0)))
	local top = head + Vector3.new(0, 0.45, 0)
	local bot = foot + Vector3.new(0, -0.4, 0)
	local span = math.max(0.4, top.Y - bot.Y)
	local stretch = math.clamp((span - 2.8) / 3.2, 0, 1)
	local vis = ease * 0.9
	local steps = 16
	local last = math.max(2, math.floor(steps * ease + 0.5))
	for wi = 1, 5 do
		local off = wi * 1.2566
		local prev
		for s = 0, last do
			local u = s / steps
			local base = bot:Lerp(top, u)
			local twist = off + now * 1.15 + u * 0.55
			twist += 0.55 * math.sin(u * 2.4 + now * 0.9 + wi)
			twist += (1 - u) * 0.55 * math.sin(now * 0.9 + wi)
			local flare = 1.08 + 0.12 * (1 - u)
			local rad = radius * flare * (0.85 + 0.12 * math.sin(u * 3.14159))
			local p = Vector3.new(base.X + math.cos(twist) * rad, base.Y, base.Z + math.sin(twist) * rad)
			if prev then
				local pulse = 0.55 + 0.45 * math.sin(now * 1.4 + wi)
				line3(prev, p, gradAlong(u + now * 0.22 + wi * 0.12), 2, vis * pulse)
			end
			prev = p
		end
	end
end

local function renderSkeleton(model, _root, _color, appear, now)
	local a0 = appear * 0.95
	local col = gradAlong(now * 0.18)
	for _, pair in BONES do
		local a = partPos(model, pair[1])
		local b = partPos(model, pair[2])
		if a and b then
			line3(a, b, col, 2, a0)
			local j = a:Lerp(b, 0.5)
			local side = (b - a)
			if side.Magnitude > 0.2 then
				side = side:Cross(Vector3.new(0, 1, 0))
				if side.Magnitude > 0.01 then
					side = side.Unit * 0.12
					line3(j - side, j + side, col, 1, a0 * 0.7)
				end
			end
		end
	end
end

local function renderPulse(root, radius, yMin, yMax, _color, appear, now)
	local mid = root.CFrame * Vector3.new(0, (yMin + yMax) * 0.5, 0)
	local s = radius * (1.05 + 0.18 * math.sin(now * 2.4))
	local v = {
		mid + Vector3.new(s, 0, 0),
		mid + Vector3.new(-s, 0, 0),
		mid + Vector3.new(0, s, 0),
		mid + Vector3.new(0, -s, 0),
		mid + Vector3.new(0, 0, s),
		mid + Vector3.new(0, 0, -s),
	}
	local edges = { { 1, 3 }, { 1, 4 }, { 1, 5 }, { 1, 6 }, { 2, 3 }, { 2, 4 }, { 2, 5 }, { 2, 6 }, { 3, 5 }, { 3, 6 }, { 4, 5 }, { 4, 6 } }
	local vis = appear * 0.94
	local col = gradAlong(now * 0.18)
	for _, e in edges do
		line3(v[e[1]], v[e[2]], col, 2, vis)
	end
end

local function renderCoil(root, radius, yMin, yMax, _color, appear, now)
	local origin = root.CFrame.Position
	local span = yMax - yMin
	local vis = appear * 0.94
	local pts = {}
	local steps = 22
	for s = 0, steps do
		local u = s / steps
		local y = yMin + u * span
		local ang = u * 10 + now * 1.3
		local rad = radius * 1.15
		pts[s + 1] = origin + Vector3.new(math.cos(ang) * rad, y, math.sin(ang) * rad)
	end
	pathLine(pts, now, 2, vis)
end

local function renderRift(root, radius, yMin, yMax, _color, appear, now)
	local ease = appear * appear * (3 - 2 * appear)
	local mid = root.CFrame * Vector3.new(0, (yMin + yMax) * 0.5, 0)
	local spin = now * 0.55
	local r = radius * 1.12 * (0.4 + 0.6 * ease)
	local function orbitPt(ang, i)
		local warp = 1 + 0.08 * math.sin(ang * 2 + now * 0.8)
		return mid + Vector3.new(math.cos(ang) * r * warp, math.sin(now * 1.4 + (i or 0)) * 0.16, math.sin(ang) * r * warp)
	end
	local segs = 32
	for i = 1, segs do
		if i % 2 == 1 then
			local a0 = spin + (i - 1) / segs * 6.283185307179586
			local a1 = spin + i / segs * 6.283185307179586
			line3(orbitPt(a0, i), orbitPt(a1, i + 1), gradAlong(i / segs + now * 0.18), 2, ease * 0.38)
		end
	end
	local shards = 8
	for i = 1, shards do
		local delay = (i - 1) / shards * 0.28
		local u = math.clamp((appear - delay) / 0.55, 0, 1)
		if u > 0.04 then
			local a = spin + i / shards * 6.283185307179586
			local p = orbitPt(a, i)
			local tangent = Vector3.new(-math.sin(a), 0.08, math.cos(a)) * (0.34 * u)
			local up = Vector3.new(0, 0.3 * u, 0)
			local gc = gradAlong(i / shards + now * 0.28)
			local vis = ease * 0.9 * u
			line3(p + tangent, p - tangent * 0.55 + up, gc, 2, vis)
			line3(p - tangent * 0.55 + up, p - tangent * 0.25 - up * 0.45, gc, 2, vis)
			line3(p - tangent * 0.25 - up * 0.45, p + tangent, gc, 2, vis)
		end
	end
end

local function renderWeave(root, radius, yMin, yMax, _color, appear, now)
	local mid = root.CFrame * Vector3.new(0, (yMin + yMax) * 0.5, 0)
	local vis = appear * 0.94
	local segs = 32
	for strand = 1, 2 do
		local pts = {}
		local ph = strand == 1 and 0 or 3.14159
		for s = 0, segs do
			local u = s / segs
			local a = u * 6.283185307179586 + now * 0.85 + ph
			local warp = 1 + 0.14 * math.sin(a * 2 + now * 1.05)
			local y = (yMax - yMin) * 0.38 * math.sin(a + ph)
			local rad = radius * 1.35 * warp
			pts[s + 1] = mid + Vector3.new(math.cos(a) * rad, y, math.sin(a) * rad)
		end
		pathLine(pts, now + strand, 2, vis)
	end
end

local BOX_EDGES = {
	{ Vector3.new(-1, -1, -1), Vector3.new(1, -1, -1) },
	{ Vector3.new(1, -1, -1), Vector3.new(1, -1, 1) },
	{ Vector3.new(1, -1, 1), Vector3.new(-1, -1, 1) },
	{ Vector3.new(-1, -1, 1), Vector3.new(-1, -1, -1) },
	{ Vector3.new(-1, 1, -1), Vector3.new(1, 1, -1) },
	{ Vector3.new(1, 1, -1), Vector3.new(1, 1, 1) },
	{ Vector3.new(1, 1, 1), Vector3.new(-1, 1, 1) },
	{ Vector3.new(-1, 1, 1), Vector3.new(-1, 1, -1) },
	{ Vector3.new(-1, -1, -1), Vector3.new(-1, 1, -1) },
	{ Vector3.new(1, -1, -1), Vector3.new(1, 1, -1) },
	{ Vector3.new(1, -1, 1), Vector3.new(1, 1, 1) },
	{ Vector3.new(-1, -1, 1), Vector3.new(-1, 1, 1) },
}

local hbRay = RaycastParams.new()
hbRay.FilterType = Enum.RaycastFilterType.Exclude

local function hitboxFloorY(cf)
	local ex = {}
	local function add(x)
		if x then
			ex[#ex + 1] = x
		end
	end
	for _, m in CollectionService:GetTagged("CustomCharacter") do
		add(m)
		local h = CharacterController:GetCharacterHandler(m)
		if h then
			add(h.OriginalModel)
			if h.Root then
				add(h.Root)
				add(h.Root.Parent)
			end
			if h.RemoteCollider then
				add(h.RemoteCollider)
			end
		end
	end
	for _, p in Players:GetPlayers() do
		add(p.Character)
	end
	hbRay.FilterDescendantsInstances = ex
	local origin = cf.Position + Vector3.new(0, 6, 0)
	local dir = Vector3.new(0, -80, 0)
	for _ = 1, 8 do
		local hit = workspace:Raycast(origin, dir, hbRay)
		if not hit then
			return cf.Position.Y - 3
		end
		local inst = hit.Instance
		local model = inst:FindFirstAncestorWhichIsA("Model")
		local skip = false
		if model then
			if model:FindFirstChildWhichIsA("Humanoid") or model:GetAttribute("UserId") or CollectionService:HasTag(model, "CustomCharacter") then
				skip = true
			end
		end
		if skip then
			add(model or inst)
			hbRay.FilterDescendantsInstances = ex
		else
			return hit.Position.Y
		end
	end
	return cf.Position.Y - 3
end

local HIT_SOUNDS = {
	Fatality = 115982072912004,
	Click = 95635059379804,
	Bell = 124010691633262,
	Neverlose = 139452805868562,
	SuccessFX = 18448089848,
}
local HIT_EFFECTS = {
	Cut = true,
	LightCut = true,
	Hit = true,
	LightHit = true,
	UltimateHit = true,
}
local PARRY_EFFECTS = {
	Parry = true,
	LightParry = true,
	UltimateParry = true,
}
local lastHitSnd = 0
local lastParrySnd = 0
local muteHitUntil = 0
local hitSparks = {}
local fxClock = 0

local function playIdSound(id, vol)
	if not id then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://" .. tostring(id)
	s.Volume = math.clamp(vol or 3.5, 0, 10)
	s.Looped = false
	s.Parent = SoundService
	s:Play()
	Debris:AddItem(s, 4)
end

local function playHitSound()
	if not Config.HitSound then
		return
	end
	local t = os.clock()
	if t - lastHitSnd < 0.12 then
		return
	end
	lastHitSnd = t
	muteHitUntil = t + 0.28
	playIdSound(HIT_SOUNDS[Config.HitSoundPreset] or 115982072912004, Config.HitSoundVolume)
end

local function playParrySound()
	if not Config.ParrySound then
		return
	end
	local t = os.clock()
	if t - lastParrySnd < 0.05 then
		return
	end
	lastParrySnd = t
	playIdSound(HIT_SOUNDS[Config.ParrySoundPreset] or 18448089848, Config.ParrySoundVolume)
end

local function spawnHitFX(pos)
	if not Config.HitRing then
		return
	end
	while #hitSparks > 4 do
		table.remove(hitSparks, 1)
	end
	local fy = hitboxFloorY(CFrame.new(pos))
	if math.abs(fy - pos.Y) > 8 then
		fy = pos.Y - 2.5
	end
	hitSparks[#hitSparks + 1] = {
		kind = "ring",
		pos = Vector3.new(pos.X, fy + 0.08, pos.Z),
		spawn = os.clock(),
		life = Config.HitRingLife or 1.85,
		r0 = Config.HitRingR0 or 0.45,
		r1 = Config.HitRingR1 or 5.6,
	}
end

local function onLocalConfirmedHit(pos)
	playHitSound()
	spawnHitFX(pos)
end

local function seedShards()
	local shards = {}
	local corners = {}
	local n = 0
	local function cornerKey(v)
		return string.format("%d,%d,%d", v.X, v.Y, v.Z)
	end
	local function addCorner(v, idx)
		local k = cornerKey(v)
		local t = corners[k]
		if not t then
			t = {}
			corners[k] = t
		end
		t[#t + 1] = idx
	end
	for _, e in BOX_EDGES do
		local prev
		for s = 0, 2 do
			n += 1
			local a = e[1]:Lerp(e[2], s / 3)
			local b = e[1]:Lerp(e[2], (s + 1) / 3)
			local mid = (a + b) * 0.5
			local dir = mid
			if dir.Magnitude < 0.1 then
				dir = Vector3.new(0, 1, 0)
			end
			local sh = {
				a = a,
				b = b,
				scatter = dir.Unit * (0.5 + rng:NextNumber() * 0.75),
				land = Vector3.new((rng:NextNumber() - 0.5) * 2.1, 0, (rng:NextNumber() - 0.5) * 2.1),
				burst = 1.2 + rng:NextNumber() * 1.15,
				rx = (rng:NextNumber() - 0.5) * 2.2,
				ry = (rng:NextNumber() - 0.5) * 2.2,
				rz = (rng:NextNumber() - 0.5) * 2.2,
				delay = (n - 1) / 36 * 0.14,
				lieWait = 0.07 + rng:NextNumber() * 0.1,
				k = n,
				near = {},
			}
			shards[n] = sh
			if prev then
				sh.near[#sh.near + 1] = prev
				shards[prev].near[#shards[prev].near + 1] = n
			end
			if s == 0 then
				addCorner(a, n)
			end
			if s == 2 then
				addCorner(b, n)
			end
			prev = n
		end
	end
	for _, list in corners do
		for i = 1, #list - 1 do
			for j = i + 1, #list do
				local ia, ib = list[i], list[j]
				shards[ia].near[#shards[ia].near + 1] = ib
				shards[ib].near[#shards[ib].near + 1] = ia
			end
		end
	end
	return shards
end

local function shardWarp(a, b, seed, now, amp)
	local d = b - a
	local mag = d.Magnitude
	if mag < 1e-4 then
		return a, a, b, b
	end
	local side
	if math.abs(d.Y) < 0.85 * mag then
		side = d:Cross(Vector3.new(0, 1, 0))
	else
		side = d:Cross(Vector3.new(1, 0, 0))
	end
	if side.Magnitude < 1e-6 then
		side = Vector3.new(0, 1, 0)
	else
		side = side.Unit
	end
	local along = d / mag
	local bin = side:Cross(along)
	if bin.Magnitude < 1e-6 then
		bin = Vector3.new(0, 1, 0)
	else
		bin = bin.Unit
	end
	local m1 = a:Lerp(b, 0.28) + side * (math.sin(now * 1.25 + seed) * amp) + bin * (math.sin(now * 0.85 + seed * 2.1) * amp * 0.4)
	local m2 = a:Lerp(b, 0.72) + side * (math.sin(now * 1.7 + seed * 1.3 + 0.9) * amp * 0.82) + bin * (math.sin(now * 1.05 + seed * 0.6) * amp * 0.35)
	return a, m1, m2, b
end

local function drawWarp(a, b, seed, now, amp, col, alpha)
	if alpha < 0.05 then
		return
	end
	local p0, p1, p2, p3 = shardWarp(a, b, seed, now, amp)
	line3(p0, p1, col, 2, alpha)
	line3(p1, p2, col, 2, alpha)
	line3(p2, p3, col, 2, alpha)
end

local function renderHitFX(now)
	fxClock = now
	for i = #hitSparks, 1, -1 do
		local p = hitSparks[i]
		local age = now - p.spawn
		if p.kind ~= "ring" or age > p.life then
			table.remove(hitSparks, i)
		else
			local t = age / p.life
			local s = 1 - (1 - t) * (1 - t)
			local rad = p.r0 + (p.r1 - p.r0) * s
			local fade = t < 0.45 and 1 or (1 - (t - 0.45) / 0.55)
			local alpha = math.clamp(fade, 0, 1) * 0.92
			local segs = 48
			local prev
			local y = p.pos.Y
			local col = gradAlong(now * 0.12, Config.HitRingColorA, Config.HitRingColorB)
			for k = 0, segs do
				local a = k / segs * 6.283185307179586
				local wob = 1 + 0.028 * math.sin(a * 2 + t * 1.6)
				local rr = rad * wob
				local pt = Vector3.new(p.pos.X + math.cos(a) * rr, y, p.pos.Z + math.sin(a) * rr)
				if prev then
					line3(prev, pt, col, Config.HitRingThick or 3, alpha)
				end
				prev = pt
			end
		end
	end
end

local function glassLerp(rest, land, p)
	p = math.clamp(p, 0, 1)
	local burst = p
	local fall = p * p * (3 - 2 * p)
	local arc = 0.85 * math.sin(p * math.pi)
	return Vector3.new(rest.X + (land.X - rest.X) * burst, rest.Y + (land.Y - rest.Y) * fall + arc, rest.Z + (land.Z - rest.Z) * burst)
end

local function renderMirror(boxCF, size, vis, now, shards, physics, floorY, restore, form, out, lie, sink)
	if vis <= 0.02 or not shards or #shards == 0 then
		return
	end
	local h = size * 0.5
	local floor = physics == "Floor" or physics == "UseAnother" or physics == "AddAnother"
	local restAmt = restore and restore * restore * (3 - 2 * restore)
	local leaving = (out or 0) > 0.001 or (lie or 0) > 0.001 or (sink or 0) > 0.001
	form = form or 0
	out = out or 0
	lie = lie or 0
	sink = sink or 0
	for _, sh in shards do
		local u = leaving and 1 or math.clamp((form - sh.delay) / 0.42, 0, 1)
		sh._u = u
		if u > 0.02 then
			local fly = leaving and out or (1 - u * u * (3 - 2 * u))
			local la = Vector3.new(sh.a.X * h.X, sh.a.Y * h.Y, sh.a.Z * h.Z)
			local lb = Vector3.new(sh.b.X * h.X, sh.b.Y * h.Y, sh.b.Z * h.Z)
			local restA = boxCF * la
			local restB = boxCF * lb
			local wa, wb
			if restAmt and sh.fromA and sh.fromB then
				wa = sh.fromA:Lerp(restA, restAmt)
				wb = sh.fromB:Lerp(restB, restAmt)
				fly = 1 - restAmt
			elseif floor then
				local fy = (floorY or restA.Y - 3) + 0.03
				local landA = Vector3.new(restA.X + sh.land.X, fy, restA.Z + sh.land.Z)
				local landB = Vector3.new(restB.X + sh.land.X, fy, restB.Z + sh.land.Z)
				local myOut = math.clamp((out - sh.delay * 0.4), 0, 1)
				local wait = sh.lieWait or 0.18
				if lie > wait then
					local s = math.clamp((lie - wait) / 0.45, 0, 1)
					local d = s * s * 6
					wa = Vector3.new(landA.X, landA.Y - d, landA.Z)
					wb = Vector3.new(landB.X, landB.Y - d, landB.Z)
					fly = 1
					sh._sink = s
				elseif lie > 0 or myOut >= 1 or out >= 1 then
					wa = landA
					wb = landB
					fly = 1
					sh._sink = 0
				elseif out > 0 then
					wa = glassLerp(restA, landA, myOut)
					wb = glassLerp(restB, landB, myOut)
					fly = myOut
					sh._sink = 0
				else
					local rot = CFrame.Angles(sh.rx * fly, sh.ry * fly, sh.rz * fly)
					local sc = sh.scatter * fly
					wa = boxCF * (rot * la + sc)
					wb = boxCF * (rot * lb + sc)
					sh._sink = 0
				end
			else
				local rot = CFrame.Angles(sh.rx * fly, sh.ry * fly, sh.rz * fly)
				local sc = sh.scatter * fly
				wa = boxCF * (rot * la + sc)
				wb = boxCF * (rot * lb + sc)
			end
			sh.wa = wa
			sh.wb = wb
			local amp = (wa - wb).Magnitude * (0.035 + 0.07 * fly)
			local p0, p1, p2, p3 = shardWarp(wa, wb, sh.k, now, amp)
			local col = gradAlong(sh.k / 36 + now * 0.28, Config.HitboxColorA, Config.HitboxColorB)
			local alpha = 0.94 * vis * u
			if (sh._sink or 0) > 0 then
				alpha *= math.max(0, 1 - sh._sink)
			end
			line3(p0, p1, col, 2, alpha)
			line3(p1, p2, col, 2, alpha)
			line3(p2, p3, col, 2, alpha)
		end
	end
end

local function isEnemyModel(model, localOriginal)
	if not model or model == localOriginal or model:GetAttribute("IsDead") then
		return false
	end
	local okLocal, isLocal = pcall(function()
		return CharacterController:IsLocalCharacterModel(model)
	end)
	if okLocal and isLocal then
		return false
	end
	if model:GetAttribute("UserId") == LocalPlayer.UserId then
		return false
	end
	if localOriginal and model.Name == localOriginal.Name .. "_Client" then
		return false
	end
	if not MatchController then
		return true
	end
	return MatchController:IsCharacterEnemyOfLocalPlayer(model) and true or false
end

local function modelRoot(model)
	local handler = CharacterController:GetCharacterHandler(model)
	if handler and handler.Root then
		return handler.Root, handler
	end
	return model:FindFirstChild("HumanoidRootPart"), handler
end

local function charBounds(model, root)
	local head = model:FindFirstChild("Head")
	local yMax = 1.4
	if head and root then
		yMax = (head.Position.Y - root.Position.Y) + 0.15
	end
	local yMin = -2.15
	local hum = model:FindFirstChildWhichIsA("Humanoid")
	if hum then
		yMin = -(hum.HipHeight + 0.35)
	end
	return 1.75, yMin, yMax
end

local function localHandler()
	return CharacterController:GetLocalCharacterHandler()
end

local function serverReady(lh)
	if not lh or lh:GetIgnoreInput() then
		return false
	end
	local model = lh.OriginalModel
	if model and model:GetAttribute("IsDead") then
		return false
	end
	if not lh.EquippedWeapon then
		return false
	end
	local am = lh.ActionManager
	if not am or am.IsSwappingWeapon or am.CurrentMiniStun then
		return false
	end
	return true
end

local function canQueueAttack(lh)
	if not serverReady(lh) then
		return false
	end
	local am = lh.ActionManager
	local cur = am.CurrentAction
	if cur and not (cur.CanQueueActions or cur.CanQueueBasicAttacks or cur.CanCancel or cur.CanChainBasicAttack) then
		return false
	end
	if am._queuedActionType then
		return false
	end
	return true
end

local function canStartInterrupt(lh)
	if not serverReady(lh) then
		return false
	end
	local am = lh.ActionManager
	if not am or am._queuedActionType then
		return false
	end
	local cur = am.CurrentAction
	if not cur then
		return true
	end
	return cur.CanCancel == true
end

local function curActName(lh)
	local am = lh and lh.ActionManager
	local cur = am and am.CurrentAction
	if not cur then
		return "none"
	end
	return string.format("%s cancel=%s qBA=%s", tostring(cur.ActionName or cur.Name or cur.Type or "act"), tostring(cur.CanCancel), tostring(cur.CanQueueBasicAttacks))
end

local function weStunned(lh)
	if not lh then
		return false
	end
	if lh.IsStaggered then
		return true
	end
	local am = lh.ActionManager
	if am and am.CurrentMiniStun then
		return true
	end
	local cur = am and am.CurrentAction
	return cur ~= nil and cur.ActionType == "Stagger"
end

local function enemyBroken(handler)
	if not handler then
		return false, 0
	end
	local am = handler.ActionManager
	local cur = am and am.CurrentAction
	if not (cur and cur.ActionType == "Stagger" and cur.IsPostureBreak) then
		return false, 0
	end
	local tr = cur.AnimationTrack
	local remain = 1.8
	if tr then
		local spd = tr.Speed
		if type(spd) ~= "number" or spd < 0.15 then
			spd = 1
		end
		local len = tr.Length
		if type(len) == "number" and len > 0 then
			remain = math.max(0, (len - (tr.TimePosition or 0)) / spd)
		end
	end
	return true, remain
end

local function pressGuard(lh, retap)
	if not serverReady(lh) then
		return false
	end
	if not retap then
		if lh.IsParrying then
			return true
		end
		if lh.IsBlocking then
			return false
		end
	end
	local am = lh.ActionManager
	if am and not retap and not am:CanStartBlock() then
		return false
	end
	local q = lh._blockInputQueue
	if type(q) ~= "table" or #q >= 2 then
		return false
	end
	q[#q + 1] = { state = true }
	return true
end

local function releaseGuard(lh)
	if not lh then
		return
	end
	local q = lh._blockInputQueue
	if type(q) == "table" then
		for i = #q, 1, -1 do
			local e = q[i]
			if e.state == true then
				e.state = 0.13333333333333333
			end
		end
	end
	local am = lh.ActionManager
	if am and am.BlockAction then
		am.BlockAction._wantsToRelease = true
	end
end

local lastDodgeAt = 0
local enemyMot = {}

local function enemyVel(model, root)
	if not root then
		return Vector3.zero
	end
	local now = os.clock()
	local p = root.Position
	local s = enemyMot[model]
	local vel = s and s.vel or Vector3.zero
	if s and now > s.t + 0.03 then
		local dt = now - s.t
		if dt < 0.3 then
			vel = (p - s.pos) / dt
		end
	end
	if not s or now - s.t >= 0.05 then
		enemyMot[model] = { pos = p, t = now, vel = vel }
	end
	return vel
end

local function recedingFrom(lh, root, vel)
	if not lh or not lh.Root or not root then
		return false
	end
	local to = Vector3.new(root.Position.X - lh.Root.Position.X, 0, root.Position.Z - lh.Root.Position.Z)
	if to.Magnitude < 0.2 then
		return false
	end
	local flat = Vector3.new(vel.X, 0, vel.Z)
	return flat:Dot(to.Unit) > 3
end

local function pressDodge(lh)
	if not serverReady(lh) then
		return false
	end
	if lh.IsDodging then
		return false
	end
	if os.clock() - lastDodgeAt < (Config.DodgeCooldown or 0) then
		return false
	end
	local am = lh.ActionManager
	if not am or not am:CanStartDodge() then
		return false
	end
	lh._desiredDodge = 0.26666666666666666
	lastDodgeAt = os.clock()
	return true
end

local function moveDirToward(lh, dest)
	local from = lh.Root.Position
	local p = dest
	if typeof(dest) ~= "Vector3" then
		p = dest.Position
	end
	local dir = Vector3.new(p.X - from.X, 0, p.Z - from.Z)
	if dir.Magnitude < 0.1 then
		dir = Vector3.new(lh.Root.CFrame.LookVector.X, 0, lh.Root.CFrame.LookVector.Z)
	end
	if dir.Magnitude < 0.1 then
		dir = Vector3.new(0, 0, -1)
	else
		dir = dir.Unit
	end
	local cam = workspace.CurrentCamera
	if cam and (lh.TargetLock or lh.AimingWithCamera) then
		local z = cam.CFrame:VectorToObjectSpace(dir).Z
		if z > 0.85 then
			local look = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
			if look.Magnitude > 0.1 then
				dir = look.Unit
			end
		end
	end
	lh.DesiredLookDirection = dir
	lh.DesiredLookResponsiveness = 90
	lh.DesiredMoveDirection = dir
	return dir
end

local function dodgeToward(lh, dest)
	if not lh or not lh.Root or not dest then
		return false
	end
	moveDirToward(lh, dest)
	return pressDodge(lh)
end

local function dodgeSide(lh, dest)
	if not lh or not lh.Root then
		return false
	end
	local from = lh.Root.Position
	local to = dest and Vector3.new(dest.X - from.X, 0, dest.Z - from.Z) or Vector3.new(0, 0, 0)
	if to.Magnitude > 0.1 then
		to = to.Unit
		lh.DesiredLookDirection = to
		lh.DesiredLookResponsiveness = 90
		lh.DesiredMoveDirection = Vector3.new(-to.Z, 0, to.X)
	else
		local look = Vector3.new(lh.Root.CFrame.LookVector.X, 0, lh.Root.CFrame.LookVector.Z)
		lh.DesiredMoveDirection = look.Magnitude > 0.1 and look.Unit or Vector3.new(0, 0, -1)
	end
	return pressDodge(lh)
end

local function dodgeAt(lh, dest, dist, forceToward)
	if forceToward or dist < 0 or dist >= 5.5 then
		return dodgeToward(lh, dest), "fwd"
	end
	return dodgeToward(lh, dest), "fwd"
end

local skinIdx = 1
local lastSkin = ""

local function weaponHandler(lh)
	if not lh then
		return nil
	end
	if lh.GetEquippedWeaponHandler then
		local wh = lh:GetEquippedWeaponHandler()
		if wh then
			return wh
		end
	end
	local w = lh.EquippedWeapon
	if w and lh.WeaponToHandler then
		return lh.WeaponToHandler[w]
	end
	return nil
end

local function cosmeticNames(wh)
	local names = {}
	local c = wh and wh.WeaponInfo and wh.WeaponInfo.Cosmetics
	if type(c) == "table" then
		for name, mod in c do
			if type(name) == "string" and mod ~= nil and type(mod) ~= "function" then
				names[#names + 1] = name
			end
		end
		table.sort(names)
	elseif typeof(c) == "Instance" then
		for _, ch in c:GetChildren() do
			names[#names + 1] = ch.Name
		end
		table.sort(names)
	end
	return names
end

local function applySkin(name)
	local lh = localHandler()
	if not lh or type(name) ~= "string" or name == "" then
		print("[DG-AP] skin fail: no character or empty name")
		return false
	end
	local wh = weaponHandler(lh)
	if not wh then
		print("[DG-AP] skin fail: no weapon handler w=" .. tostring(lh.EquippedWeapon))
		return false
	end
	local ok, err = pcall(function()
		if wh.WeaponInstance then
			wh.WeaponInstance:SetAttribute("CurrentCosmetic", name)
		end
		wh:SetCosmetic(name)
	end)
	if not ok then
		print("[DG-AP] skin err:", tostring(err))
		return false
	end
	Config.WeaponSkins[tostring(lh.EquippedWeapon)] = name
	lastSkin = name .. ":" .. tostring(lh.EquippedWeapon)
	print("[DG-AP] skin=" .. name .. " weapon=" .. tostring(lh.EquippedWeapon))
	return true
end

local function cycleSkin()
	local lh = localHandler()
	local wh = weaponHandler(lh)
	local names = cosmeticNames(wh)
	if #names == 0 then
		print("[DG-AP] skin: no cosmetics on " .. tostring(lh and lh.EquippedWeapon))
		return
	end
	skinIdx = skinIdx % #names + 1
	print("[DG-AP] skins:", table.concat(names, ","))
	applySkin(names[skinIdx])
end

local cosmeticStore = { body = {}, hlBody = nil, lastKey = "" }

local function parseMaterial(name)
	if type(name) ~= "string" or name == "" then
		return Enum.Material.ForceField
	end
	local ok, mat = pcall(function()
		return Enum.Material[name]
	end)
	if ok and typeof(mat) == "EnumItem" then
		return mat
	end
	return Enum.Material.ForceField
end

local function paintParts(root, matEnum, store, col, transp, mode)
	if not root then
		return
	end
	local function skip(d)
		local n = d.Name
		if n == "HumanoidRootPart" then
			return true
		end
		if n == "RightHandle" or n == "LeftHandle" then
			return true
		end
		if n == "Handle" and not d:FindFirstAncestorWhichIsA("Accessory") then
			return true
		end
		if string.find(n, "Blade", 1, true) or string.find(n, "Weapon", 1, true) or string.find(n, "Grip", 1, true) or string.find(n, "Hitbox", 1, true) or string.find(n, "Collider", 1, true) then
			return true
		end
		return false
	end
	for _, d in root:GetDescendants() do
		if d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") or d:IsA("Clothing") then
			if not store[d] then
				store[d] = { kind = "hide", parent = d.Parent }
			end
			d.Parent = nil
		end
	end
	local function paint(d)
		if not d:IsA("BasePart") or d.Name == "HumanoidRootPart" or skip(d) then
			return
		end
		if not store[d] then
			store[d] = {
				mat = d.Material,
				col = d.Color,
				tr = d.Transparency,
				ref = d.Reflectance,
				tex = d:IsA("MeshPart") and d.TextureID or nil,
				sa = {},
			}
		end
		for _, ch in d:GetChildren() do
			if ch:IsA("SurfaceAppearance") or ch:IsA("Texture") or ch:IsA("Decal") then
				if not store[d].sa[ch] then
					store[d].sa[ch] = ch.Parent
				end
				ch.Parent = nil
			elseif ch:IsA("SpecialMesh") then
				store[d].smTex = store[d].smTex or ch.TextureId
				ch.TextureId = ""
			end
		end
		d.Material = matEnum
		if typeof(col) == "Color3" then
			d.Color = col
		end
		if type(transp) == "number" then
			d.Transparency = transp
		end
		pcall(function()
			d.Reflectance = matEnum == Enum.Material.Glass and 0.4 or 0
		end)
		if d:IsA("MeshPart") then
			d.TextureID = ""
		end
	end
	for _, d in root:GetDescendants() do
		paint(d)
	end
	paint(root)
end

local function restoreParts(store)
	for inst, old in store do
		if inst.Parent then
			inst.Material = old.mat
			inst.Color = old.col
			if type(old.tr) == "number" then
				inst.Transparency = old.tr
			end
			if type(old.ref) == "number" then
				pcall(function()
					inst.Reflectance = old.ref
				end)
			end
			if inst:IsA("MeshPart") and type(old.tex) == "string" then
				inst.TextureID = old.tex
			end
			if old.sa then
				for ch, par in old.sa do
					if ch and par then
						ch.Parent = par
					end
				end
			end
			if type(old.smTex) == "string" then
				local sm = inst:FindFirstChildWhichIsA("SpecialMesh")
				if sm then
					sm.TextureId = old.smTex
				end
			end
		elseif old.kind == "hide" and old.parent then
			inst.Parent = old.parent
		end
	end
	table.clear(store)
end

local function ensureHighlight(parent, slot)
	local hl = cosmeticStore[slot]
	if hl and hl.Parent == parent then
		return hl
	end
	if hl then
		hl:Destroy()
	end
	if not parent then
		cosmeticStore[slot] = nil
		return nil
	end
	hl = Instance.new("Highlight")
	hl.Name = "DGAP_HL"
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.FillTransparency = 1
	hl.OutlineTransparency = 0.08
	hl.FillColor = Color3.fromRGB(255, 92, 163)
	hl.OutlineColor = Color3.fromRGB(255, 92, 163)
	hl.Parent = parent
	cosmeticStore[slot] = hl
	return hl
end

local function clearCosmetics()
	restoreParts(cosmeticStore.body)
	if cosmeticStore.hlBody then
		cosmeticStore.hlBody:Destroy()
		cosmeticStore.hlBody = nil
	end
	cosmeticStore.lastKey = ""
end

local function stepCosmetics(now, lh)
	if not Config.CustomModel then
		if cosmeticStore.lastKey ~= "" then
			clearCosmetics()
		end
		return
	end
	if not lh then
		return
	end
	if not cosmeticStore.scrubbed then
		cosmeticStore.scrubbed = true
		for _, root in { workspace, workspace.CurrentCamera, lh.Model, lh.OriginalModel } do
			if root then
				local av = root:FindFirstChild("DGAP_Avatar", true)
				if av then
					pcall(function()
						av:Destroy()
					end)
				end
			end
		end
		if lh.Model then
			for _, d in lh.Model:GetDescendants() do
				if d:IsA("BasePart") then
					d.LocalTransparencyModifier = 0
				end
			end
		end
	end
	local mat = parseMaterial(Config.CustomModelMaterial)
	local col = Config.CustomModelColor
	if typeof(col) ~= "Color3" then
		col = Color3.fromRGB(186, 150, 255)
	end
	local ol = Config.OutlineColor
	if typeof(ol) ~= "Color3" then
		ol = Color3.fromRGB(255, 92, 163)
	end
	local vis = lh.Model or lh.OriginalModel
	paintParts(vis, mat, cosmeticStore.body, col, Config.CustomModelTransparency or 0.18, "body")
	local hl = ensureHighlight(vis, "hlBody")
	if hl then
		hl.FillTransparency = 1
		hl.OutlineTransparency = 0.08
		hl.FillColor = ol
		hl.OutlineColor = ol
		hl.Enabled = true
	end
	cosmeticStore.lastKey = "on"
end

local function attackKind(name)
	if string.find(name, "Heavy", 1, true) or name == "DashHeavy" then
		return "Heavy"
	end
	if string.find(name, "Light", 1, true) or name == "DashLight" then
		return "Light"
	end
	return nil
end

local function allowAttacks(lh)
	local allow = { Light01 = true, Heavy01 = true }
	local w = equippedName(lh.OriginalModel)
	local pack = type(w) == "string" and catalog[w]
	if pack then
		for name in pack.attacks do
			if attackKind(name) then
				allow[name] = true
			end
		end
	end
	local am = lh.ActionManager
	if am then
		if type(am._nextLightAttackName) == "string" then
			allow[am._nextLightAttackName] = true
		end
		if type(am._nextHeavyAttackName) == "string" then
			allow[am._nextHeavyAttackName] = true
		end
	end
	return allow
end

local function pingPad()
	local p = PingController and PingController:GetPing() or 0
	if p > 2 then
		p = p / 1000
	end
	return math.clamp(p, 0, 0.08) + 0.02
end

local function dodgeTravel(lh)
	local w = equippedName(lh and lh.OriginalModel)
	local dd = 1
	if type(w) == "string" and catalog[w] then
		dd = catalog[w].dodgeDist or 1
	end
	return 7.8 * dd * (Config.DodgeRange or 1)
end

local function packAttackRec(pack, name)
	local atk = pack and pack.attacks[name]
	if not atk or not atk.impacts or not atk.impacts[1] then
		return nil
	end
	local imp = atk.impacts[1]
	local hit = math.max(0.05, (imp.markerTime or 0.25) / math.max(atk.speed or 1, 0.5))
	return { name = name, hit = hit, sa = imp.saDmg or 0, kind = attackKind(name), reach = math.abs(imp.cf.Position.Z) + imp.size.Z * 0.5 }
end

local function comboAttackName(lh, wantKind)
	local am = lh and lh.ActionManager
	local name
	if wantKind == "Heavy" then
		name = am and am._nextHeavyAttackName
		if type(name) ~= "string" or name == "DashHeavy" or name == "JumpAttack" or name == "Ultimate" then
			name = "Heavy01"
		end
	else
		name = am and am._nextLightAttackName
		if type(name) ~= "string" or name == "DashLight" or name == "JumpAttack" or name == "Ultimate" then
			name = "Light01"
		end
	end
	return name
end

local function bestOfKind(lh, threat, wantKind, needBreak)
	local w = equippedName(lh.OriginalModel)
	local pack = type(w) == "string" and catalog[w]
	if not pack then
		return nil
	end
	local pad = 0
	local atkName = tostring(threat.attack or "")
	local isUlt = atkName == "Ultimate" or string.find(atkName, "Ultimate", 1, true)
	if isUlt then
		pad = 0.10
	end
	local slack = 0.02
	if wantKind == "Heavy" and (isUlt or string.find(atkName, "Heavy", 1, true)) then
		slack = -0.05
	end
	local function fits(name)
		local rec = packAttackRec(pack, name)
		if not rec or rec.kind ~= wantKind then
			return nil
		end
		if rec.hit + pad > (threat.remain or 0) + slack then
			return nil
		end
		local ok = needBreak and rec.sa >= (threat.superArmor or 0) or (not needBreak and rec.sa < (threat.superArmor or 0))
		if not ok then
			return nil
		end
		return rec
	end
	local combo = comboAttackName(lh, wantKind)
	if Config.CustomCombo then
		local w = equippedName(lh.OriginalModel)
		local map = w and Config.ComboMap[w]
		local list = map and map[wantKind]
		if type(list) == "table" then
			for _, name in list do
				local rec = fits(name)
				if rec then
					return rec
				end
			end
		end
	end
	local rec = fits(combo)
	if rec then
		return rec
	end
	if Config.ComboOnly or Config.ComboMode == "GameCombo" then
		return nil
	end
	local starter = wantKind == "Heavy" and "Heavy01" or "Light01"
	if combo ~= starter then
		return fits(starter)
	end
	return nil
end

local function pickComboAttack(lh, threat)
	local br = bestOfKind(lh, threat, "Heavy", true) or bestOfKind(lh, threat, "Light", true)
	if br then
		br.mode = "interrupt"
		return br
	end
	local chip = bestOfKind(lh, threat, "Light", false) or bestOfKind(lh, threat, "Heavy", false)
	if chip and threat.remain > chip.hit + 0.12 then
		chip.mode = "chip"
		return chip
	end
	return nil
end

local function rollSticky(swing, key, chance)
	if not swing then
		return rng:NextNumber() <= chance
	end
	swing.rolls = swing.rolls or {}
	if swing.rolls[key] == nil then
		swing.rolls[key] = rng:NextNumber() <= chance
	end
	return swing.rolls[key]
end

local function planBreak(lh, threat, facing, jumpReady, jumpHit, jumpDist, jumpReach)
	local swing = threat.swing
	local cands = {}
	local atkName = tostring(threat.attack)
	local isUlt = atkName == "Ultimate" or string.find(atkName, "Ultimate", 1, true) ~= nil
	local isJump = atkName == "JumpAttack"
	local theirKind = attackKind(atkName)
	if Config.AutoDodge and Config.BreakDodge and threat.will and (not isUlt) and (not isJump) then
		local remain = threat.remain or 0
		local nImp = threat.impN or 1
		if not (nImp > 1 and Config.AutoParry and threat.canParry) and remain >= 0.05 then
			if rollSticky(swing, "priDodge", Config.DodgeChance) then
				return { kind = "dodge", rec = nil, weight = 1, abs = 1, mode = "dashatk" }
			end
		end
	end
	if Config.SmartInterrupt then
		local function addBreak(kind, rec, weight, abs)
			if not rec then
				return
			end
			local reach = rec.reach or 7
			if jumpDist <= reach + 0.2 then
				cands[#cands + 1] = { kind = kind, rec = rec, weight = weight, abs = abs, mode = "interrupt" }
			elseif threat.remain > rec.hit + 0.30 then
				local travel = dodgeTravel(lh)
				local gap = jumpDist - reach
				if gap > 0.5 and gap <= travel * 0.82 then
					cands[#cands + 1] = { kind = "gapclose", rec = rec, weight = weight, abs = abs, mode = "gapclose" }
				end
			end
		end
		if isUlt or theirKind == "Heavy" then
			if Config.BreakHeavy then
				addBreak("heavy", bestOfKind(lh, threat, "Heavy", true), Config.BreakHeavyChance, Config.BreakHeavyAbs)
			end
		elseif theirKind == "Light" then
			if Config.BreakLight then
				local rec = bestOfKind(lh, threat, "Light", true)
				if rec and (threat.remain or 0) >= rec.hit + 0.08 then
					addBreak("light", rec, Config.BreakLightChance, Config.BreakLightAbs)
				end
			end
			if #cands == 0 and Config.BreakHeavy then
				local rec = bestOfKind(lh, threat, "Heavy", true)
				if rec and (threat.remain or 0) >= rec.hit + 0.08 then
					addBreak("heavy", rec, Config.BreakHeavyChance, Config.BreakHeavyAbs)
				end
			end
		end
		local hasBreak = false
		for _, c in cands do
			if c.kind == "heavy" or c.kind == "light" or c.kind == "gapclose" then
				hasBreak = true
				break
			end
		end
		if not hasBreak and Config.BreakJump and Config.JumpAttackCounter and jumpReady then
			cands[#cands + 1] = { kind = "jump", weight = Config.BreakJumpChance, abs = Config.BreakJumpAbs, mode = "jump" }
		end
	end
	local banned = swing and swing.breakBan
	local pool = {}
	for _, c in cands do
		if not (banned and banned[c.kind]) and (c.weight or 0) > 0 then
			pool[#pool + 1] = c
		end
	end
	local plan = false
	if #pool > 0 then
		local tot = 0
		for _, c in pool do
			tot += math.max(0, c.weight or 0)
		end
		if tot > 0 then
			local r = rng:NextNumber() * tot
			for _, c in pool do
				r -= math.max(0, c.weight or 0)
				if r <= 0 then
					plan = c
					break
				end
			end
			plan = plan or pool[#pool]
		end
		if plan and not rollSticky(swing, plan.kind .. "Abs", plan.abs or 1) then
			if swing then
				swing.breakBan = swing.breakBan or {}
				swing.breakBan[plan.kind] = true
			end
			plan = false
		elseif plan and swing then
			swing.breakKind = plan.kind
		end
	end
	return plan
end

local function dist2d(a, b)
	local dx = a.X - b.X
	local dz = a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

local function isFacing(root, toPos, deg)
	local to = Vector3.new(toPos.X - root.Position.X, 0, toPos.Z - root.Position.Z)
	if to.Magnitude < 0.15 then
		return true
	end
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if look.Magnitude < 0.05 then
		return false
	end
	return look.Unit:Dot(to.Unit) >= math.cos(math.rad(deg or Config.FaceCone))
end

local function faceTarget(lh, enemyRoot, dt)
	if not lh or not lh.Root or not enemyRoot then
		return
	end
	local from = lh.Root.Position
	local aim = Vector3.new(enemyRoot.Position.X, from.Y, enemyRoot.Position.Z)
	local t = math.clamp((Config.AutoFaceSpeed or 16) * dt, 0, 1)
	if Config.AutoFaceMode == "LookAt" then
		local cam = workspace.CurrentCamera
		cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(cam.CFrame.Position, enemyRoot.Position), t)
	else
		local goal = CFrame.lookAt(from, aim)
		lh.Root.CFrame = CFrame.new(from) * lh.Root.CFrame.Rotation:Lerp(goal.Rotation, t)
	end
	local dir = aim - from
	if dir.Magnitude > 0.1 then
		lh.DesiredLookDirection = Vector3.new(dir.X, 0, dir.Z).Unit
		lh.DesiredLookResponsiveness = 90
	end
end

local function ourReach(lh, attackName)
	local w = equippedName(lh.OriginalModel)
	local pack = type(w) == "string" and catalog[w]
	local atk = pack and (pack.attacks[attackName] or pack.attacks.Light01)
	if not atk or not atk.impacts[1] then
		return 4
	end
	local imp = atk.impacts[1]
	return math.abs(imp.cf.Position.Z) + imp.size.Z * 0.5
end

local function enemyRadius(model)
	local w = equippedName(model)
	if type(w) == "string" and catalog[w] then
		return catalog[w].radius
	end
	return 2.5
end

local function lookAtFlat(from, to)
	local p = Vector3.new(to.X, from.Y, to.Z)
	if (p - from).Magnitude < 0.15 then
		return CFrame.new(from)
	end
	return CFrame.lookAt(from, p)
end

local function attackHits(lh, name, enemyRoot, enemyModel)
	if not lh or not lh.Root or not enemyRoot then
		return false
	end
	local w = equippedName(lh.OriginalModel)
	local pack = type(w) == "string" and catalog[w]
	local atk = pack and pack.attacks[name]
	if not atk or not atk.impacts or not atk.impacts[1] then
		return false
	end
	local imp = atk.impacts[1]
	local boxCF = lookAtFlat(lh.Root.Position, enemyRoot.Position) * imp.cf
	return obbHitsSphere(boxCF, imp.size, enemyRoot.Position, enemyRadius(enemyModel) * 0.72)
end

local function queueNamed(lh, rec)
	if not canQueueAttack(lh) then
		return false
	end
	local am = lh.ActionManager
	if rec.kind == "Heavy" then
		am:SetNextHeavyAttackName(rec.name, 1)
		return am:TryQueueBasicAttack("Heavy")
	end
	am:SetNextLightAttackName(rec.name, 1)
	return am:TryQueueBasicAttack("Light")
end

local lastSwing = {}
local airJump = {}
local lastTakenAt = 0
local lastAH = 0
local ahDodgeLock = {}
local pressed = { kind = nil, untilTime = 0, key = "", rec = nil }
local parrySigLh = nil

local dbg = {
	events = {},
	seen = {},
	will = 0,
	parry = 0,
	dodge = 0,
	interrupt = 0,
	chip = 0,
	skip = 0,
	taken = 0,
	helper = 0,
	enemyParry = 0,
	enemyBlock = 0,
	lastHp = nil,
	lastThreat = "",
	_cidx = {},
}

dbg._hd = function(remain, needRemain)
	if Config.NoDelay or not Config.HumanDelay then
		return 0
	end
	local lo = Config.HumanDelayMin or 0.016
	local hi = Config.HumanDelayMax or 0.045
	if hi < lo then
		hi = lo
	end
	local slack = math.max(0, (remain or 0) - (needRemain or 0.03) - 0.01)
	if slack <= 0.004 then
		return 0
	end
	local d = lo + rng:NextNumber() * (hi - lo)
	if d > slack then
		d = slack * (0.4 + rng:NextNumber() * 0.45)
	end
	return d
end

local function enemyLine(threat, lh)
	if not threat then
		return "enemy=?"
	end
	local model = threat.model
	local plr = model and Players:GetPlayerFromCharacter(model)
	local uid = model and model:GetAttribute("UserId")
	if not plr and uid then
		plr = Players:GetPlayerByUserId(uid)
	end
	local d = -1
	if lh and lh.Root and threat.root then
		d = dist2d(lh.Root.Position, threat.root.Position)
	end
	local ow = equippedName(lh and lh.OriginalModel)
	return string.format("enemy=%s uid=%s dist=%.2f ourW=%s theirW=%s atk=%s imp=%s/%s sa=%.0f t=%.3f last=%.3f tpos=%.3f will=%s", plr and plr.Name or "?", tostring(uid), d, tostring(ow), tostring(threat.weapon), tostring(threat.attack), tostring(threat.impIndex or 1), tostring(threat.impN or 1), threat.superArmor or 0, threat.remain, threat.lastRemain or threat.remain, threat.tpos or 0, tostring(threat.will))
end

local function ourHits(lh)
	local w = equippedName(lh and lh.OriginalModel)
	local pack = type(w) == "string" and catalog[w]
	if not pack then
		return "our=?"
	end
	local function one(name)
		local a = pack.attacks[name]
		if not a or not a.impacts or not a.impacts[1] then
			return name .. "=?"
		end
		local imp = a.impacts[1]
		local hit = math.max(0.05, (imp.markerTime or 0) / math.max(a.speed or 1, 0.5))
		return string.format("%s hit=%.3f sa=%.0f", name, hit, imp.saDmg or 0)
	end
	return one("Light01") .. " " .. one("Heavy01")
end

local function dlog(tag, msg)
	local t = tick()
	local ts = string.format("%s.%03d", os.date("%H:%M:%S", math.floor(t)), math.floor((t % 1) * 1000))
	local line = string.format("%s [%s] %s", ts, tag, msg)
	dbg.events[#dbg.events + 1] = line
	print("[AP-DBG]", line)
end

local function clog(tag, msg, threat, lh)
	dlog(tag, msg .. " | " .. enemyLine(threat, lh))
end

local function threatSwingId(threat)
	if not threat or not threat.model then
		return ""
	end
	return tostring(threat.model) .. ":" .. tostring(threat.attack)
end

local function parryUntil(now, threat, parryDur, isJump)
	local n = threat.impN or 1
	if n > 1 then
		return now + math.max(0.05, (threat.remain or 0) + 0.03)
	end
	local hold = math.max(threat.remain or 0.04, 0.04) + 0.02
	local cap = isJump and 0.16 or (parryDur - 0.04)
	return now + math.min(hold, cap)
end

local function noteSwing(model, attack, tpos, will)
	local k = tostring(model)
	local s = lastSwing[k]
	local tposDrop = s and (tpos + 0.05 < s.tpos)
	if not s or s.attack ~= attack or tposDrop then
		s = {
			attack = attack,
			tpos = tpos,
			born = os.clock(),
			uid = k .. ":" .. tostring(attack) .. ":" .. string.format("%.3f", os.clock()),
			handled = false,
			willCounted = false,
		}
		lastSwing[k] = s
	else
		s.tpos = tpos
	end
	if will and not s.willCounted then
		s.willCounted = true
		dbg.will += 1
	end
	return s
end

local function tryAttackHelper(lh, threat)
	if not Config.AttackHelper or not lh or weStunned(lh) or pressed.kind then
		return false
	end
	if threat then
		local an = tostring(threat.attack or "")
		if an == "JumpAttack" or an == "Ultimate" or string.find(an, "Ultimate", 1, true) then
			return false
		end
		if threat.will then
			return false
		end
	end
	if os.clock() - lastAH < 0.18 then
		return false
	end
	if not canStartInterrupt(lh) or not lh.Root then
		return false
	end
	local pad = pingPad()
	local now = os.clock()
	local ourW = equippedName(lh.OriginalModel)
	local pack = type(ourW) == "string" and catalog[ourW]

	local function hitT(name)
		local atk = pack and pack.attacks[name]
		if not atk or not atk.impacts or not atk.impacts[1] then
			return 0.22
		end
		local imp = atk.impacts[1]
		return math.max(0.05, ((imp.markerTime or 0.25) - (atk.pred or 0)) / math.max(atk.speed or 1, 0.5))
	end

	local function aimAt(root)
		local from = lh.Root.Position
		local dir = Vector3.new(root.Position.X - from.X, 0, root.Position.Z - from.Z)
		if dir.Magnitude > 0.1 then
			lh.DesiredLookDirection = dir.Unit
			lh.DesiredLookResponsiveness = 90
			lh.DesiredMoveDirection = dir.Unit
		end
	end

	local function fire(name, tag, model, root, remain)
		if not attackHits(lh, name, root, model) then
			return false
		end
		lastAH = now
		aimAt(root)
		local kind = attackKind(name) or "Light"
		if kind ~= "Heavy" then
			kind = "Light"
		end
		local rec = { name = name, kind = kind }
		local ok = queueNamed(lh, rec)
		clog("AH_" .. tag, string.format("ok=%s name=%s kind=%s dRemain=%.3f", tostring(ok), name, kind, remain or 0), {
			weapon = equippedName(model),
			attack = tag,
			remain = remain or 0,
			tpos = 0,
			will = false,
			superArmor = 0,
			model = model,
			root = root,
			impIndex = 1,
			impN = 1,
		}, lh)
		if ok then
			dbg.helper += 1
			pressed.kind = "ah"
			pressed.untilTime = now + hitT(name) + 0.04
			pressed.rec = rec
		end
		return ok
	end

	for _, model in CollectionService:GetTagged("CustomCharacter") do
		if isEnemyModel(model, lh.OriginalModel) then
			local root, handler = modelRoot(model)
			if root then
				if (root.Position.Y - lh.Root.Position.Y) > 2.2 then
					continue
				end
				enemyVel(model, root)
				local animator = handler and handler.Animator
				if not animator then
					local hum = model:FindFirstChildWhichIsA("Humanoid")
					animator = hum and hum:FindFirstChildWhichIsA("Animator")
				end
				local dodgeAge, isRev, recovering, jumping, swinging, blockingAnim, blockAge
				if animator then
					local okTracks, tracks = pcall(function()
						return animator:GetPlayingAnimationTracks()
					end)
					if okTracks and tracks then
						for _, track in tracks do
							local anim = track.Animation
							local id = anim and anim.AnimationId
							if id then
								if dodgeBackIds[id] then
									isRev = true
									dodgeAge = (track.TimePosition or 0) / math.max(track.Speed or 1, 0.7)
								elseif dodgeFwdIds[id] then
									isRev = false
									dodgeAge = (track.TimePosition or 0) / math.max(track.Speed or 1, 0.7)
								elseif jumpAnimIds[id] then
									jumping = true
								elseif blockAnimIds[id] then
									blockingAnim = true
									blockAge = (track.TimePosition or 0) / math.max(track.Speed or 1, 0.7)
								else
									local wname = equippedName(model)
									local entry = lookupAttack(wname, id)
									if entry then
										if entry.attack == "JumpAttack" or entry.windup then
											jumping = true
										elseif entry.impacts and #entry.impacts > 0 then
											local lastM = entry.impacts[#entry.impacts].markerTime or 0
											local firstM = entry.impacts[1].markerTime or 0
											local tpos = track.TimePosition or 0
											if tpos < lastM + 0.08 then
												swinging = true
											elseif tpos > lastM and tpos < (entry.canCancel or lastM + 0.45) then
												recovering = true
											end
										end
									end
								end
							end
						end
					end
				end
				if (jumping or swinging or (threat and threat.will and threat.model == model and not threat.windup)) and not dodgeAge then
					continue
				end
				local lockK = tostring(model)
				if not dodgeAge then
					ahDodgeLock[lockK] = nil
				end
				if Config.PerfectDodgeCounter and dodgeAge then
					local iframeLeft = 0.3 - dodgeAge
					local d = dist2d(lh.Root.Position, root.Position)
					local standName = comboAttackName(lh, "Light")
					local ht = hitT(standName)
					local standReach = ourReach(lh, standName)
					local travel = dodgeTravel(lh)
					local dReach = ourReach(lh, "DashLight")
					if isRev then
					elseif Config.AHJumpChase and swinging and not isRev and not ahDodgeLock[lockK] then
						local incoming = threat and threat.model == model and (threat.remain or 0) > 0.04 and not threat.windup
						if not incoming then
							local jHit = hitT("JumpAttack")
							local land = 0.08 + jHit
							if iframeLeft <= land + 0.05 and iframeLeft > -0.08 then
								local am = lh.ActionManager
								if am then
									aimAt(root)
									local to = root.Position - lh.Root.Position
									local flat = Vector3.new(to.X, 0, to.Z)
									local jdir = flat.Magnitude > 0.1 and flat.Unit or Vector3.new(0, 0, 0)
									local okj = am:TryQueueJump(jdir)
									if okj then
										ahDodgeLock[lockK] = true
										lastAH = now
										pressed.kind = "jumpatk"
										pressed.from = "ah"
										pressed.at = now
										pressed.untilTime = now + 0.55
										dbg.helper += 1
										clog("AH_JUMPCHASE", string.format("fwd dodge jump+atk iframe=%.3f d=%.2f", iframeLeft, d), {
											weapon = equippedName(model),
											attack = "JUMPCHASE",
											remain = iframeLeft,
											tpos = dodgeAge,
											will = false,
											superArmor = 0,
											model = model,
											root = root,
											impIndex = 1,
											impN = 1,
										}, lh)
										return true
									end
								end
							end
						end
					elseif not dodgeAge and iframeLeft <= ht + 0.02 and iframeLeft > -0.05 and not ahDodgeLock[lockK] and d <= standReach - 0.15 then
						if fire(standName, "PERFDODGE", model, root, iframeLeft) then
							ahDodgeLock[lockK] = true
							return true
						end
					end
					end
				local blocking = model:GetAttribute("IsBlocking") == true or model:GetAttribute("ClientIsBlocking") == true or (handler and handler.IsBlocking == true) or blockingAnim == true
				if blocking then
					if blockingAnim and (blockAge or 1) < 0.07 and blockSince[model] and (now - blockSince[model]) > 0.12 then
						blockSince[model] = now
						clog("AH_BLOCK_RETAP", string.format("age=%.3f reset wait", blockAge or 0), {
							weapon = equippedName(model),
							attack = "BLOCK",
							remain = 0.233,
							tpos = blockAge or 0,
							will = false,
							superArmor = 0,
							model = model,
							root = root,
							impIndex = 1,
							impN = 1,
						}, lh)
					elseif not blockSince[model] then
						blockSince[model] = now
						clog("AH_BLOCK_SEEN", string.format("parryWin hold start d=%.2f age=%.3f", dist2d(lh.Root.Position, root.Position), blockAge or 0), {
							weapon = equippedName(model),
							attack = "BLOCK",
							remain = 0.233,
							tpos = blockAge or 0,
							will = false,
							superArmor = 0,
							model = model,
							root = root,
							impIndex = 1,
							impN = 1,
						}, lh)
					end
				else
					local started = blockSince[model]
					if started then
						local held = now - started
						blockSince[model] = nil
						blockPunished[model] = nil
						if held >= 0.12 and held <= 0.34 then
							blockPunishUntil[model] = now + 0.22
						end
					end
				end
				local nextL = comboAttackName(lh, "Light")
				local holdT = blockSince[model] and (now - blockSince[model]) or 0
				local theirBlock = math.max(blockAge or 0, holdT)
				local d = dist2d(lh.Root.Position, root.Position)
				local travel = dodgeTravel(lh)
				local vel = enemyVel(model, root)
				local recede = recedingFrom(lh, root, vel)
				if Config.AHPunishBlock and blocking and not blockPunished[model] then
					local replicaAge = blockAge or 0
					local standR = ourReach(lh, nextL)
					local standOk = d <= standR
					local delay = replicaAge > 0.12 and 0.02 or 0.05
					if holdT >= delay then
						blockPunished[model] = true
						if standOk and fire(nextL, "BLOCKPUNISH", model, root, 0) then
							return true
						end
						if not standOk then
							local rec = { name = "DashLight", kind = "Light" }
							if d <= ourReach(lh, rec.name) + travel * 0.65 then
								if dodgeToward(lh, root.Position) then
									lastAH = now
									lastDodgeAt = now
									pressed.kind = "dashatk"
									pressed.untilTime = now + 0.38
									pressed.at = now
									pressed.from = "ah"
									pressed.rec = rec
									dbg.helper += 1
									clog("AH_BLOCKDASH", string.format("gap dodge+%s hold=%.3f age=%.3f d=%.2f recede=%s", rec.name, holdT, replicaAge, d, tostring(recede)), {
										weapon = equippedName(model),
										attack = "BLOCKDASH",
										remain = 0,
										tpos = replicaAge,
										will = false,
										superArmor = 0,
										model = model,
										root = root,
										impIndex = 1,
										impN = 1,
									}, lh)
									return true
								end
							end
						end
					end
				end
				if blockPunishUntil[model] and now < blockPunishUntil[model] then
					if fire(nextL, "BLOCKREC", model, root, blockPunishUntil[model] - now) then
						return true
					end
				end
				if Config.AHPunishWhiff and recovering and (now - lastAH) > 0.45 and (now - lastDodgeAt) > 0.5 and (now - lastTakenAt) > 0.65 then
					if fire(nextL, "WHIFF", model, root, 0) then
						return true
					end
				end
			end
		end
	end
	return false
end

local function dumpDebug()
	local acc = 0
	local acted = dbg.parry + dbg.dodge + dbg.interrupt + dbg.helper
	if dbg.will > 0 then
		acc = acted / dbg.will * 100
	end
	local clean = 0
	if dbg.will > 0 then
		clean = math.max(0, (dbg.will - dbg.taken) / dbg.will * 100)
	end
	local lines = {
		"Dueling Grounds AP debug  " .. os.date("%Y-%m-%d %H:%M:%S"),
		string.format("willHit=%d acted=%d (parry=%d dodge=%d interrupt=%d ah=%d) chip=%d skip=%d taken=%d enemyParry=%d enemyBlock=%d", dbg.will, acted, dbg.parry, dbg.dodge, dbg.interrupt, dbg.helper, dbg.chip, dbg.skip, dbg.taken, dbg.enemyParry, dbg.enemyBlock),
		string.format("acted_rate=%.1f%%  clean_rate=%.1f%% (1 - taken/willHit)", acc, clean),
		"----",
	}
	for _, e in dbg.events do
		lines[#lines + 1] = e
	end
	local name = "AP_debug_" .. os.date("%Y%m%d_%H%M%S") .. ".txt"
	writefile(name, table.concat(lines, "\n"))
	print("[AP-DBG] saved", name, #dbg.events, "events")
end

local function scanThreat(lh)
	if not lh or not lh.IsBaseLoaded or not lh.Root then
		return nil
	end
	if lh.OriginalModel and lh.OriginalModel:GetAttribute("IsDead") then
		return nil
	end
	local ourPos = lh.Root.Position
	local radius = ourRadius() + Config.ReachPad
	local best = nil
	for _, model in CollectionService:GetTagged("CustomCharacter") do
		if isEnemyModel(model, lh.OriginalModel) then
			local root, handler = modelRoot(model)
			local animator = handler and handler.Animator
			if not animator then
				local hum = model:FindFirstChildWhichIsA("Humanoid")
				animator = hum and hum:FindFirstChildWhichIsA("Animator")
			end
			if root and animator then
				local weaponName = equippedName(model) or model:GetAttribute("EquippedWeapon")
				local okTracks, tracks = pcall(function()
					return animator:GetPlayingAnimationTracks()
				end)
				if okTracks and tracks then
					for _, track in tracks do
						local anim = track.Animation
						local id = anim and anim.AnimationId
						if id then
							local entry = lookupAttack(weaponName, id)
							if entry then
								local tpos = track.TimePosition
								local wgt = 1
								local okw, wc = pcall(function()
									return track.WeightCurrent
								end)
								if okw and type(wc) == "number" then
									wgt = wc
								end
								if wgt < 0.03 then
									continue
								end
								if entry.windup then
								continue
							end
							local atkSpd = math.max(entry.speed or 1, 0.5)
							for _, impact in entry.impacts do
									local remain
									local expected = (impact.markerTime or 0.3) / atkSpd
									if entry.windup then
										local len = track.Length
										if len <= 0 then
											len = 0.4
										end
										remain = math.max(0, (len - tpos) / atkSpd) + impact.markerTime
									else
										remain = (impact.markerTime - tpos) / atkSpd
									end
									if remain > expected + 0.22 then
										remain = math.max(0.02, expected - tpos / atkSpd)
									end
								local remainMin = entry.attack == "JumpAttack" and 0.01 or 0.03
								if remain > remainMin and remain < 1.25 then
									local boxCF = root.CFrame * impact.cf
									local will = obbHitsSphere(boxCF, impact.size, ourPos, radius)
									if not will and entry.attack == "JumpAttack" and not entry.windup then
										local d = dist2d(ourPos, root.Position)
										if d <= 12 then
											will = true
										end
									end
										local score = remain
										if will then
											score -= 10
										end
										if not best or score < best.score then
											local lastRemain = remain
											for _, imp2 in entry.impacts do
												local r2
												if entry.windup then
													r2 = remain
												else
													r2 = (imp2.markerTime - tpos) / atkSpd
												end
												if r2 > lastRemain then
													lastRemain = r2
												end
											end
											best = {
												score = score,
												remain = remain,
												lastRemain = lastRemain,
												impIndex = impact.index or 1,
												impN = #entry.impacts,
												tpos = tpos,
												will = will,
												boxCF = boxCF,
												size = impact.size,
												weapon = entry.weapon,
												attack = entry.attack,
												canParry = impact.canParry,
												windup = entry.windup,
												superArmor = entry.superArmor or 0,
												saDmg = impact.saDmg or 0,
												canCancel = entry.canCancel or 0,
												cancelRemain = (entry.canCancel or 0) > 0 and (entry.canCancel - tpos) / math.max(atkSpd, 0.5) or (remain + 0.35),
												model = model,
												root = root,
												key = tostring(model) .. ":" .. entry.attack,
											}
										end
									end
								end
							end
						end
					end
				end
				local am = handler and handler.ActionManager
				local cur = am and am.CurrentAction
				if cur and cur.ActionType == "Jump" then
					airJump[model] = os.clock() + 1.5
				elseif airJump[model] and os.clock() > airJump[model] then
					airJump[model] = nil
				end
			end
		end
	end
	if best then
		best.swing = noteSwing(best.model, best.attack, best.tpos or 0, best.will)
	end
	return best
end

local pinStore = {}

local function stateFor(model)
	local s = pinStore[model]
	if not s then
		s = { appear = 0, bolts = {}, shards = {}, gens = {}, hbVis = 0, hbHold = 0 }
		pinStore[model] = s
	end
	return s
end

local function selectTwo(lh, threat)
	local out = {}
	local function push(model)
		if #out >= 2 or not model then
			return
		end
		for _, e in out do
			if e.model == model then
				return
			end
		end
		if not lh or not isEnemyModel(model, lh.OriginalModel) then
			return
		end
		local root = modelRoot(model)
		if root then
			out[#out + 1] = { model = model, root = root }
		end
	end
	if lh and lh.TargetLock then
		push(lh.TargetLock:FindFirstAncestorWhichIsA("Model") or lh.TargetLock.Parent)
	end
	if threat and threat.will then
		push(threat.model)
	end
	if lh and lh.Root then
		local list = {}
		for _, model in CollectionService:GetTagged("CustomCharacter") do
			if isEnemyModel(model, lh.OriginalModel) then
				local root = modelRoot(model)
				if root then
					list[#list + 1] = { model = model, d = (root.Position - lh.Root.Position).Magnitude }
				end
			end
		end
		table.sort(list, function(a, b)
			if a.d == b.d then
				return tostring(a.model) < tostring(b.model)
			end
			return a.d < b.d
		end)
		for _, e in list do
			push(e.model)
			if #out >= 2 then
				break
			end
		end
	end
	return out
end

local function styleIndex()
	for i, name in ESP_STYLES do
		if name == Config.EspStyle then
			return i
		end
	end
	return 1
end

bind(RunService.Heartbeat, function(dt)
	if not running or not Config.Enabled then
		return
	end
	if type(dt) ~= "number" then
		dt = 0.016
	end
	local lh = localHandler()
	if not lh then
		return
	end
	local w = tostring(lh.EquippedWeapon)
	local want = Config.WeaponSkins[w]
	if type(want) == "string" and want ~= "" and want ~= "Default" then
		local tag = want .. ":" .. w
		if tag ~= lastSkin then
			applySkin(want)
		end
	end
	local am = lh.ActionManager
	if Config.CustomCombo and am and not am._dgapWrap and type(am.TryQueueBasicAttack) == "function" then
		am._dgapWrap = true
		local old = am.TryQueueBasicAttack
		am.TryQueueBasicAttack = function(self, kind, ...)
			if kind == "Light" or kind == "Heavy" then
				local ww = equippedName(self.CharacterHandler and self.CharacterHandler.OriginalModel)
				local map = ww and Config.ComboMap[ww]
				local list = map and map[kind]
				if type(list) == "table" and #list > 0 then
					local key = ww .. tostring(kind)
					local i = (dbg._cidx[key] or 0) % #list + 1
					dbg._cidx[key] = i
					local name = list[i]
					if kind == "Light" then
						self:SetNextLightAttackName(name, 2)
					else
						self:SetNextHeavyAttackName(name, 2)
					end
				end
			end
			return old(self, kind, ...)
		end
	end
	local spdMul = Config.DodgeSpeed or 1
	local rngMul = Config.DodgeRange or 1
	if (spdMul ~= 1 or rngMul ~= 1) and lh.IsDodging and am then
		local act = am.CurrentAction
		if act and act.ActionType == "Dodge" and act.MovementProperties and act.MovementProperties.mode == "Slide" and act ~= dbg._dodgeAct then
			dbg._dodgeAct = act
			local dd = act.DodgeDistance or 1
			local v = 40 * dd * rngMul * spdMul
			act.MovementProperties.velocity = v
			act.MovementProperties.velocityDecay = v * 1.5
		end
	end
	if Config.NoStun then
		lh.IsStaggered = false
		local cur = am and am.CurrentAction
		if cur and cur.ActionType == "Stagger" then
			cur.CanCancel = true
			cur.CanChainBasicAttack = true
			pcall(function()
				cur:CompleteSequence()
			end)
		end
	end
	if Config.NoSlowdown and not lh.IsDodging then
		local cur = am and am.CurrentAction
		if not (cur and cur.MovementProperties) then
			local hum = lh.Humanoid
			local spd = 17
			local wh = weaponHandler(lh)
			if wh and wh.WeaponInfo and type(wh.WeaponInfo.RunSpeed) == "number" then
				spd = wh.WeaponInfo.RunSpeed
			end
			if hum and (hum.WalkSpeed or 0) < spd * 0.92 then
				hum.WalkSpeed = spd
			end
		end
	end
	if Config.Speed and lh.Root then
		local dir = lh.DesiredMoveDirection
		if typeof(dir) == "Vector3" and dir.Magnitude > 0.05 then
			lh.Root.CFrame = lh.Root.CFrame + dir.Unit * (Config.SpeedValue or 32) * dt
		end
	end
	if Config.NoClip then
		if lh.Root then
			lh.Root.CanCollide = false
		end
		if lh.RemoteCollider then
			lh.RemoteCollider.CanCollide = false
		end
	end
	if Config.GodMode then
		lh.IsDodging = true
		pressDodge(lh)
	end
end)

bind(RunService.RenderStepped, function(dt)
	if not running then
		return
	end
	beginFrame()
	if not Config.Enabled then
		endFrame()
		return
	end
	local lh = localHandler()
	if lh and lh ~= parrySigLh and lh.Parried then
		parrySigLh = lh
		bind(lh.Parried, playParrySound)
	end
	local threat = scanThreat(lh)
	local now = os.clock()
	pcall(stepCosmetics, now, lh)
	if lh and lh.OriginalModel then
		local hp = lh.OriginalModel:GetAttribute("Health")
		if dbg.lastHp and hp and hp < dbg.lastHp - 0.4 then
			dbg.taken += 1
			lastTakenAt = os.clock()
			clog("HIT_TAKEN", string.format("hp %.1f -> %.1f last=%s", dbg.lastHp, hp, dbg.lastThreat), threat, lh)
		end
		dbg.lastHp = hp
	end
	if pressed.kind == "dashatk" or pressed.kind == "gapclose" or pressed.kind == "jumpatk" then
	local skipFollow = false
	if pressed.kind == "dashatk" and threat and threat.will then
		local same = pressed.key ~= nil and threat.key == pressed.key
		if threat.attack == "JumpAttack" and not same then
			pressed.kind = nil
			pressed.rec = nil
			pressed.from = nil
			skipFollow = true
		elseif not same then
			skipFollow = true
			if pressed.from == "plan" then
				pressed.kind = nil
				pressed.rec = nil
				pressed.from = nil
			end
		end
	elseif pressed.kind == "dashatk" and (not pressed.rec or pressed.from == "plan" and (now - lastTakenAt) < 0.55) then
		skipFollow = true
		if (threat and threat.will) or (now - lastTakenAt) < 0.55 then
			pressed.kind = nil
			pressed.rec = nil
			pressed.from = nil
		end
	end
		if not skipFollow and pressed.kind then
			local ready = canQueueAttack(lh)
			if pressed.kind == "jumpatk" and ready then
				local d = 0
				if lh and lh.Root and threat and threat.root then
					d = dist2d(lh.Root.Position, threat.root.Position)
				end
				local reach = ourReach(lh, "JumpAttack")
				if d > reach + 1.5 then
					ready = false
				end
			end
			if pressed.kind == "dashatk" then
				local need = (pressed.from == "ah") and 0.04 or 0.18
				local waited = pressed.at and (now - pressed.at) >= need
				if not waited then
					ready = false
				end
			end
			if ready then
				if pressed.kind == "dashatk" then
					local am = lh.ActionManager
					if pressed.rec and pressed.rec.kind == "Heavy" then
						am:SetNextHeavyAttackName(pressed.rec.name or "DashHeavy", 0.35)
						am:TryQueueBasicAttack("Heavy")
						clog("DASHATK_HIT", "DashHeavy queued", threat, lh)
					else
						am:SetNextLightAttackName("DashLight", 0.35)
						am:TryQueueBasicAttack("Light")
						clog("DASHATK_HIT", "DashLight queued", threat, lh)
					end
				elseif pressed.kind == "gapclose" then
					if pressed.rec then
						queueNamed(lh, pressed.rec)
						clog("GAPCLOSE_HIT", "queued " .. tostring(pressed.rec.name), threat, lh)
					end
				else
					local am = lh.ActionManager
					am:SetNextLightAttackName("JumpAttack", 1)
					am:TryQueueBasicAttack("Light")
					clog("JUMPATK_HIT", "JumpAttack queued", threat, lh)
				end
				if threat and threat.swing then
					threat.swing.handled = true
				end
				pressed.kind = nil
				pressed.rec = nil
			elseif now >= pressed.untilTime then
				pressed.kind = nil
				pressed.rec = nil
			end
		end
	elseif pressed.kind and now >= pressed.untilTime then
		if pressed.kind == "chip" or pressed.kind == "ah" then
			if threat and threat.swing then
				threat.swing.handled = true
			end
			pressed.kind = nil
			pressed.rec = nil
			pressed.from = nil
		elseif pressed.kind == "parry" then
			releaseGuard(lh)
			local sameSwing = threat and threat.will and threatSwingId(threat) == pressed.swingId
			local more = sameSwing and (threat.impN or 1) > 1 and not pressed.tapped and (threat.lastRemain or 0) > 0.05
			if more then
				if pressGuard(lh, true) then
					pressed.kind = "parry"
					pressed.key = threat.key
					pressed.swingId = threatSwingId(threat)
					pressed.tapped = true
					pressed.untilTime = now + math.min((threat.lastRemain or threat.remain or 0.12) + 0.03, 0.20)
					if threat.swing then
						threat.swing.handled = true
					end
					clog("PARRY_TAP", string.format("repress imp=%s/%s remain=%.3f last=%.3f", tostring(threat.impIndex), tostring(threat.impN), threat.remain, threat.lastRemain or threat.remain), threat, lh)
				else
					pressed.untilTime = now + 0.03
					clog("PARRY_TAP_WAIT", string.format("queue full imp=%s/%s last=%.3f", tostring(threat.impIndex), tostring(threat.impN), threat.lastRemain or 0), threat, lh)
				end
			else
				pressed.kind = nil
				pressed.key = ""
				pressed.swingId = ""
				pressed.rec = nil
				pressed.from = nil
			end
		elseif pressed.kind == "block" then
			releaseGuard(lh)
			pressed.kind = nil
			pressed.key = ""
			pressed.swingId = ""
			pressed.rec = nil
			pressed.from = nil
		elseif pressed.kind == "wait" then
			pressed.pendKind = nil
			pressed.pendRec = nil
			pressed.kind = nil
			pressed.key = ""
			pressed.rec = nil
		else
			pressed.kind = nil
			pressed.key = ""
			pressed.rec = nil
			pressed.from = nil
		end
	end
	if pressed.kind == "parry" or pressed.kind == "block" then
		local same = threat and threat.will and threatSwingId(threat) == pressed.swingId
		if not same then
			releaseGuard(lh)
			pressed.kind = nil
			pressed.key = ""
			pressed.swingId = ""
			pressed.rec = nil
			pressed.from = nil
		end
	end
	if threat and threat.will then
		dbg.lastThreat = string.format("%s %s t=%.3f sa=%.0f swing=%s", tostring(threat.weapon), tostring(threat.attack), threat.remain, threat.superArmor or 0, threat.swing and threat.swing.uid or "?")
		if threat.swing and not dbg.seen[threat.swing.uid] then
			dbg.seen[threat.swing.uid] = true
			clog("THREAT", string.format("parryable=%s windup=%s saDmg=%.0f imp=%s/%s %s", tostring(threat.canParry), tostring(threat.windup), threat.saDmg or 0, tostring(threat.impIndex or 1), tostring(threat.impN or 1), ourHits(lh)), threat, lh)
		end
	end
	if lh and Config.AttackHelper and pressed.kind == nil then
		tryAttackHelper(lh, threat)
	end
	if pressed.kind == "ah" or pressed.kind == "jumpatk" then
		if threat and threat.will and not threat.windup then
			pressed.kind = nil
			pressed.rec = nil
			pressed.from = nil
		end
	end
	if pressed.pendKind then
		if not threat or not threat.will or pressed.pendKey ~= threat.key then
			pressed.pendKind = nil
			pressed.pendRec = nil
			if pressed.kind == "wait" then
				pressed.kind = nil
			end
		elseif now >= pressed.pendAt and lh then
			local pk = pressed.pendKind
			local prec = pressed.pendRec
			pressed.pendKind = nil
			pressed.pendRec = nil
			if pk == "parry" then
				if pressGuard(lh) then
					pressed.kind = "parry"
					pressed.key = threat.key
					pressed.swingId = threatSwingId(threat)
					pressed.tapped = false
					local strength = 1
					if lh.ActionManager and type(lh.ActionManager._blockStrength) == "number" then
						strength = lh.ActionManager._blockStrength
					end
					local pDur = 0.13333333333333333 + 0.1 * math.clamp(strength, 0, 1)
					pressed.untilTime = parryUntil(now, threat, pDur, threat.attack == "JumpAttack")
					dbg.parry += 1
					if threat.swing and (threat.impN or 1) <= 1 then
						threat.swing.handled = true
					end
					clog("PARRY", string.format("delayed remain=%.3f", threat.remain), threat, lh)
				else
					pressed.kind = nil
				end
			elseif pk == "block" then
				if pressGuard(lh) then
					pressed.kind = "block"
					pressed.key = threat.key
					pressed.swingId = threatSwingId(threat)
					pressed.tapped = true
					pressed.untilTime = now + math.max(0.14, (threat.remain or 0) + 0.1)
					if threat.swing then
						threat.swing.handled = true
					end
					clog("BLOCK_HOLD", string.format("delayed remain=%.3f", threat.remain), threat, lh)
				else
					pressed.kind = nil
				end
			elseif pk == "dodge" then
				local recede = recedingFrom(lh, threat.root, enemyVel(threat.model, threat.root))
				local d = (lh.Root and threat.root) and dist2d(lh.Root.Position, threat.root.Position) or 0
				local dodged, ddir = dodgeAt(lh, threat.root.Position, d, recede)
				if dodged then
					pressed.kind = "dashatk"
					pressed.key = threat.key
					pressed.untilTime = now + 0.42
					pressed.at = now
					pressed.from = "plan"
					pressed.rec = { name = "DashLight", kind = "Light" }
					dbg.dodge += 1
					lastDodgeAt = now
					clog("DASHATK", string.format("delayed remain=%.3f dir=%s", threat.remain, ddir), threat, lh)
				else
					pressed.kind = nil
				end
			elseif pk == "interrupt" and prec then
				if queueNamed(lh, prec) then
					pressed.kind = "interrupt"
					pressed.key = threat.key
					pressed.untilTime = now + prec.hit + 0.08
					pressed.rec = prec
					dbg.interrupt += 1
					if threat.swing then
						threat.swing.handled = true
					end
					clog("INTERRUPT_TRY", string.format("delayed ok=true name=%s", prec.name), threat, lh)
				else
					pressed.kind = nil
				end
			end
		end
	end
	local jumpAtk = threat and threat.attack == "JumpAttack" and not threat.windup
	local swingOn = threat and not threat.windup
	local theyFaceUs = threat and threat.root and lh and lh.Root and isFacing(threat.root, lh.Root.Position, 80)
	local interruptOn = swingOn and (threat.will or theyFaceUs)
	local combatOn = threat and threat.will and swingOn
	if (Config.AutoParry or Config.AutoDodge or Config.SmartInterrupt or Config.JumpAttackCounter) and (interruptOn or combatOn) and lh and serverReady(lh) and pressed.kind ~= "wait" and (Config.GodMode or not lh.IsDodging or (threat.remain or 1) <= 0.16) and not (threat.swing and threat.swing.handled) then
		local ping = PingController and PingController:GetPing() or 0
		local strength = 1
		if lh.ActionManager and type(lh.ActionManager._blockStrength) == "number" then
			strength = lh.ActionManager._blockStrength
		end
		local parryDur = 0.13333333333333333 + 0.1 * math.clamp(strength, 0, 1)
		local parryLead = Config.ParryLead
		if parryLead <= 0 then
			parryLead = math.clamp(parryDur * 0.5, 0.06, 0.14)
		end
		if ping > 0.35 then
			parryLead += 0.02
		end
		local dodgeLead = Config.DodgeLead
		local facing = isFacing(lh.Root, threat.root.Position, Config.FaceCone)
		if not facing and threat.swing and not dbg.seen[threat.swing.uid .. ":face"] then
			dbg.seen[threat.swing.uid .. ":face"] = true
			clog("FACE_BLOCK", string.format("cone=%s remain=%.3f", tostring(Config.FaceCone), threat.remain), threat, lh)
		end
		local rec = Config.SmartInterrupt and facing and pickComboAttack(lh, threat)
		local jumpHit, jumpDist, jumpReach = 0.35, -1, 0
		if lh.Root and threat.root then
			jumpDist = dist2d(lh.Root.Position, threat.root.Position)
			jumpReach = ourReach(lh, "JumpAttack")
			local jpack = catalog[equippedName(lh.OriginalModel) or ""]
			local jatk = jpack and jpack.attacks and jpack.attacks.JumpAttack
			if jatk and jatk.impacts and jatk.impacts[1] then
				jumpHit = math.max(0.05, ((jatk.impacts[1].markerTime or 0.35) - (jatk.pred or 0)) / math.max(jatk.speed or 1, 0.5))
			end
		end
		local ourLand = 0.08 + jumpHit
		local cancelR = threat.cancelRemain or (threat.remain + 0.35)
		local jumpOk = Config.JumpAttackCounter and facing and pressed.kind == nil and jumpDist >= 0 and jumpDist <= jumpReach + 1.4 and threat.remain >= 0.12 and ourLand < cancelR - 0.05 and lh.ActionManager and lh.ActionManager:CanQueueJump()
		local punished = weStunned(lh) or (now - lastTakenAt) < 0.45
		local plan = planBreak(lh, threat, facing, jumpOk, jumpHit, jumpDist, jumpReach)
		if punished and plan and (plan.kind == "light" or plan.kind == "heavy" or plan.kind == "gapclose") then
			plan = nil
		end
		if threat.swing and not dbg.seen[threat.swing.uid .. ":plan"] then
			dbg.seen[threat.swing.uid .. ":plan"] = true
			local hv = bestOfKind(lh, threat, "Heavy", true)
			local lv = bestOfKind(lh, threat, "Light", true)
			clog("BREAK_PLAN", string.format("kind=%s name=%s lightBr=%s heavyBr=%s lHit=%s hHit=%s remain=%.3f dist=%.2f cur=%s canStart=%s", tostring(plan and plan.kind), tostring(plan and plan.rec and plan.rec.name), lv and lv.name or "no", hv and hv.name or "no", lv and string.format("%.3f", lv.hit) or "-", hv and string.format("%.3f", hv.hit) or "-", threat.remain, jumpDist, curActName(lh), tostring(canStartInterrupt(lh))), threat, lh)
		end
		local waiting = false
		local coverRemain = ((threat.impN or 1) > 1) and (threat.lastRemain or threat.remain) or threat.remain
		if plan then
			if plan.kind == "dodge" and coverRemain > 0.26 then
				waiting = true
			elseif plan.kind == "jump" and not jumpOk and (threat.tpos or 0) < 0.08 then
				waiting = true
			end
		end
		if pressed.kind == "jumpatk" or pressed.kind == "dashatk" or pressed.kind == "gapclose" or pressed.kind == "chip" or pressed.kind == "parry" then
		elseif waiting then
		elseif plan and plan.kind == "gapclose" and plan.rec and pressed.kind == nil then
			local to = threat.root.Position - lh.Root.Position
			local flat = Vector3.new(to.X, 0, to.Z)
			if flat.Magnitude > 0.1 then
				lh.DesiredMoveDirection = flat.Unit
			end
			if pressDodge(lh) then
				pressed.kind = "gapclose"
				pressed.rec = plan.rec
				pressed.key = threat.key
				pressed.untilTime = now + 0.38
				dbg.dodge += 1
				if threat.swing then
					threat.swing.handled = true
				end
				clog("GAPCLOSE", string.format("dodge in then %s remain=%.3f d=%.2f travel=%.1f", plan.rec.name, threat.remain, jumpDist, dodgeTravel(lh)), threat, lh)
			end
		elseif plan and (plan.kind == "light" or plan.kind == "heavy") and plan.rec and pressed.kind ~= "chip" and pressed.kind ~= "interrupt" and pressed.kind ~= "ah" then
			if threat.root and lh.Root then
				local from = lh.Root.Position
				local dir = Vector3.new(threat.root.Position.X - from.X, 0, threat.root.Position.Z - from.Z)
				if dir.Magnitude > 0.1 then
					lh.DesiredLookDirection = dir.Unit
					lh.DesiredLookResponsiveness = 90
				end
			end
			if canStartInterrupt(lh) then
				local delay = dbg._hd(threat.remain, plan.rec.hit + 0.02)
				if delay > 0.01 then
					pressed.pendKind = "interrupt"
					pressed.pendAt = now + delay
					pressed.pendKey = threat.key
					pressed.pendRec = plan.rec
					pressed.kind = "wait"
					pressed.key = threat.key
					pressed.untilTime = pressed.pendAt + 0.04
				else
					local ok = queueNamed(lh, plan.rec)
					clog("INTERRUPT_TRY", string.format("ok=%s name=%s ourHit=%.3f their=%.3f ourSa=%.0f theirSa=%.0f kind=%s cur=%s", tostring(ok), plan.rec.name, plan.rec.hit, threat.remain, plan.rec.sa, threat.superArmor or 0, plan.kind, curActName(lh)), threat, lh)
					if ok then
						dbg.interrupt += 1
						pressed.kind = "interrupt"
						pressed.key = threat.key
						pressed.untilTime = now + plan.rec.hit + 0.08
						pressed.rec = plan.rec
						if threat.swing then
							threat.swing.handled = true
						end
					elseif threat.swing then
						threat.swing.breakBan = threat.swing.breakBan or {}
						threat.swing.breakBan[plan.kind] = true
						threat.swing.breakPlan = false
					end
				end
			else
				clog("INTERRUPT_BUSY", string.format("name=%s remain=%.3f cur=%s", plan.rec.name, threat.remain, curActName(lh)), threat, lh)
				local pmin = jumpAtk and 0.012 or 0.028
				if Config.AutoParry and combatOn and threat.canParry and threat.remain <= parryLead and threat.remain >= pmin and (pressed.kind == nil or pressed.kind == "ah" or pressed.kind == "interrupt") then
					if pressGuard(lh) then
						pressed.kind = "parry"
						pressed.key = threat.key
						pressed.swingId = threatSwingId(threat)
						pressed.tapped = false
						pressed.untilTime = parryUntil(now, threat, parryDur, jumpAtk)
						dbg.parry += 1
						if threat.swing and (threat.impN or 1) <= 1 then
							threat.swing.handled = true
						end
						clog("PARRY_FALLBACK", string.format("busy remain=%.3f last=%.3f lead=%.3f", threat.remain, threat.lastRemain or threat.remain, parryLead), threat, lh)
					end
				end
			end
		elseif plan and plan.kind == "jump" and jumpOk then
			local to = threat.root.Position - lh.Root.Position
			local flat = Vector3.new(to.X, 0, to.Z)
			local dir
			if jumpDist > jumpReach * 0.72 and flat.Magnitude > 0.1 then
				dir = flat.Unit * 0.32
			elseif flat.Magnitude > 0.1 then
				dir = Vector3.new(-flat.Z, 0, flat.X).Unit * 0.18
			else
				dir = Vector3.new(0, 0, 0)
			end
			lh.DesiredMoveDirection = dir.Magnitude > 0.1 and dir.Unit or nil
			local okj = lh.ActionManager:TryQueueJump(dir)
			clog("JUMPATK_TRY", string.format("ok=%s d=%.2f reach=%.2f jhit=%.3f remain=%.3f tpos=%.3f cancel=%.3f land=%.3f", tostring(okj), jumpDist, jumpReach, jumpHit, threat.remain, threat.tpos or 0, cancelR, ourLand), threat, lh)
			if okj then
				pressed.kind = "jumpatk"
				pressed.key = threat.key
				pressed.untilTime = now + 0.42
			elseif threat.swing then
				threat.swing.breakPlan = false
			end
		elseif plan and plan.kind == "dodge" and threat.will and coverRemain <= 0.26 and (threat.remain > parryLead or not threat.canParry) and pressed.kind == nil then
			local delay = dbg._hd(threat.remain, 0.04)
			if delay > 0.01 then
				pressed.pendKind = "dodge"
				pressed.pendAt = now + delay
				pressed.pendKey = threat.key
				pressed.kind = "wait"
				pressed.key = threat.key
				pressed.untilTime = pressed.pendAt + 0.04
			else
				local recede = recedingFrom(lh, threat.root, enemyVel(threat.model, threat.root))
				local dodged, ddir = dodgeAt(lh, threat.root.Position, jumpDist, recede)
				if dodged then
					pressed.kind = "dashatk"
					pressed.key = threat.key
					pressed.untilTime = now + 0.42
					pressed.at = now
					pressed.from = "plan"
					pressed.rec = punished and nil or { name = "DashLight", kind = "Light" }
					dbg.dodge += 1
					lastDodgeAt = now
					clog("DASHATK", string.format("iframe-cover remain=%.3f last=%.3f dist=%.2f dir=%s recede=%s", threat.remain, threat.lastRemain or threat.remain, jumpDist, ddir, tostring(recede)), threat, lh)
				end
			end
		elseif (not punished) and rec and rec.mode == "chip" and pressed.kind ~= "chip" and not plan and not threat.canParry then
			local ok = queueNamed(lh, rec)
			clog("CHIP_TRY", string.format("ok=%s name=%s ourHit=%.3f their=%.3f theirSa=%.0f", tostring(ok), rec.name, rec.hit, threat.remain, threat.superArmor or 0), threat, lh)
			if ok then
				pressed.kind = "chip"
				pressed.key = threat.key
				pressed.untilTime = now + math.max(0.03, rec.hit)
				dbg.chip += 1
				if threat.swing then
					threat.swing.handled = true
				end
			end
		else
			if Config.SmartInterrupt and not plan and not rec and not dbg.seen[threat.key .. ":noint"] then
				dbg.seen[threat.key .. ":noint"] = true
				clog("NO_INTERRUPT", string.format("%s remain=%.3f theirSa=%.0f", ourHits(lh), threat.remain, threat.superArmor or 0), threat, lh)
			end
			local parryMin = jumpAtk and 0.008 or 0.028
			local canDef = pressed.kind == nil or pressed.kind == "ah" or pressed.kind == "interrupt"
			if Config.IntentionalBlock and Config.AutoParry and combatOn and (not threat.windup) and threat.canParry and canDef and threat.remain > parryDur + 0.05 then
				if not rollSticky(threat.swing, "parry", Config.ParryChance) then
					if rollSticky(threat.swing, "block", Config.IntentionalBlockChance) then
						local delay = dbg._hd(threat.remain, parryDur + 0.05)
						if delay > 0.01 then
							pressed.pendKind = "block"
							pressed.pendAt = now + delay
							pressed.pendKey = threat.key
							pressed.kind = "wait"
							pressed.key = threat.key
							pressed.untilTime = pressed.pendAt + 0.04
						elseif pressGuard(lh) then
							pressed.kind = "block"
							pressed.key = threat.key
							pressed.swingId = threatSwingId(threat)
							pressed.tapped = true
							pressed.untilTime = now + math.max(0.14, threat.remain + 0.1)
							if threat.swing then
								threat.swing.handled = true
							end
							clog("BLOCK_HOLD", string.format("remain=%.3f dur=%.3f", threat.remain, parryDur), threat, lh)
						end
					end
				end
			end
			local doParry = Config.AutoParry and combatOn and (not threat.windup) and threat.canParry and threat.remain <= parryLead and threat.remain >= parryMin and canDef and pressed.kind == nil
			local dodgeCover = ((threat.impN or 1) > 1) and (threat.lastRemain or threat.remain) or threat.remain
			local dodgeDeclined = threat.swing and threat.swing.rolls and threat.swing.rolls.priDodge == false
			local doDodge = Config.AutoDodge and combatOn and (not threat.windup) and dodgeCover <= 0.26 and threat.remain >= 0.018 and (not threat.canParry or threat.remain < 0.04 or not Config.AutoParry or jumpAtk) and canDef and not dodgeDeclined
			if pressed.kind == "wait" or pressed.kind == "block" then
			elseif doParry then
				if rollSticky(threat.swing, "parry", Config.ParryChance) then
					local delay = dbg._hd(threat.remain, parryMin)
					if delay > 0.01 then
						pressed.pendKind = "parry"
						pressed.pendAt = now + delay
						pressed.pendKey = threat.key
						pressed.kind = "wait"
						pressed.key = threat.key
						pressed.untilTime = pressed.pendAt + 0.04
					elseif pressGuard(lh) then
						pressed.kind = "parry"
						pressed.key = threat.key
						pressed.swingId = threatSwingId(threat)
						pressed.tapped = false
						pressed.untilTime = parryUntil(now, threat, parryDur, jumpAtk)
						dbg.parry += 1
						if threat.swing and (threat.impN or 1) <= 1 then
							threat.swing.handled = true
						end
						clog("PARRY", string.format("remain=%.3f last=%.3f imp=%s/%s lead=%.3f chance=%.2f", threat.remain, threat.lastRemain or threat.remain, tostring(threat.impIndex or 1), tostring(threat.impN or 1), parryLead, Config.ParryChance), threat, lh)
					elseif jumpAtk and Config.AutoDodge and dodgeCover <= 0.26 then
						local recede = recedingFrom(lh, threat.root, enemyVel(threat.model, threat.root))
						local dodged, ddir = dodgeAt(lh, threat.root.Position, jumpDist, true)
						if dodged then
							pressed.kind = "dodge"
							pressed.key = threat.key
							pressed.untilTime = now + 0.32
							dbg.dodge += 1
							clog("DODGE", string.format("jump-fallback remain=%.3f dir=%s recede=%s", threat.remain, ddir, tostring(recede)), threat, lh)
						end
					end
				else
					dbg.skip += 1
					clog("PARRY_SKIP", "chance roll", threat, lh)
					pressed.kind = "skip"
					pressed.key = threat.key
					pressed.untilTime = now + 0.2
				end
			elseif (not doParry) and doDodge and pressed.kind ~= "dodge" then
				local delay = dbg._hd(threat.remain, 0.03)
				if delay > 0.01 then
					pressed.pendKind = "dodge"
					pressed.pendAt = now + delay
					pressed.pendKey = threat.key
					pressed.kind = "wait"
					pressed.key = threat.key
					pressed.untilTime = pressed.pendAt + 0.04
				else
					local recede = recedingFrom(lh, threat.root, enemyVel(threat.model, threat.root))
					local dodged, ddir = dodgeAt(lh, threat.root.Position, jumpDist, recede)
					if dodged then
						pressed.kind = "dodge"
						pressed.key = threat.key
						pressed.untilTime = now + math.max(0.32, (threat.lastRemain or 0) + 0.04)
						dbg.dodge += 1
						if threat.swing and (threat.impIndex or 1) >= (threat.impN or 1) then
							threat.swing.handled = true
						end
						clog("DODGE", string.format("remain=%.3f last=%.3f lead=%.3f dir=%s recede=%s", threat.remain, threat.lastRemain or threat.remain, dodgeLead, ddir, tostring(recede)), threat, lh)
					end
				end
			end
		end
	end
	if not Config.Visuals then
		renderHitFX(now)
		endFrame()
		return
	end
	local chosen = selectTwo(lh, threat)
	local seen = {}
	for _, c in chosen do
		seen[c.model] = true
		local st = stateFor(c.model)
		st.model = c.model
		st.root = c.root
		st.appear = math.min(1, st.appear + dt / 0.45)
	end
	local drop = {}
	for model, st in pinStore do
		if not seen[model] then
			st.appear = math.max(0, st.appear - dt / 0.4)
			if st.appear <= 0.01 and (st.hbVis or 0) <= 0.01 and not (st.gens and #st.gens > 0) then
				drop[#drop + 1] = model
			end
		end
	end
	for _, m in drop do
		pinStore[m] = nil
	end
	local style = Config.EspStyle
	local hbLive = Config.Hitbox and threat and threat.will and not threat.windup
	for model, st in pinStore do
		if st.appear > 0.01 and st.root and not (hbLive and threat.model == model) then
			local radius, yMin, yMax = charBounds(model, st.root)
			local a = st.appear
			if style == "Soul" then
				renderSoul(model, st.root, radius, yMin, yMax, nil, a, now)
			elseif style == "Skeleton" then
				renderSkeleton(model, st.root, nil, a, now)
			elseif style == "Rift" then
				renderRift(st.root, radius, yMin, yMax, nil, a, now)
			else
				renderWeave(st.root, radius, yMin, yMax, nil, a, now)
			end
		end
	end
	for _, c in chosen do
		local st = stateFor(c.model)
		local spd = math.max(0.2, Config.HitboxAnimSpeed or 0.7)
		local phys = Config.HitboxPhysics
		local useAnother = phys == "UseAnother" or phys == "AddAnother"
		local floorPhys = phys == "Floor" or useAnother
		local inT = 0.38 / spd
		local outT = floorPhys and math.max(0.12, Config.HitboxFallSpeed or 0.45) or (0.28 / spd)
		local live = Config.Hitbox and threat and threat.will and threat.model == c.model and threat.boxCF
		st.gens = st.gens or {}
		local leaving = (st.hbOut or 0) > 0 or (st.hbLie or 0) > 0
		if live then
			local newKey = st.hbKey and st.hbKey ~= threat.key
			if #st.shards > 0 and st.hbVis > 0.04 and newKey and (useAnother or (floorPhys and leaving)) then
				st.gens[#st.gens + 1] = {
					shards = st.shards,
					cf = st.hbCF,
					size = st.hbSize,
					vis = st.hbVis,
					form = 1,
					out = math.max(st.hbOut or 0, 0.01),
					lie = st.hbLie or 0,
					fy = st.hbFY,
				}
				st.shards = {}
				st.hbOut = 0
				st.hbLie = 0
				st.hbForm = 0
				st.hbVis = 0
				while #st.gens > 1 do
					table.remove(st.gens, 1)
				end
			end
			if #st.shards == 0 then
				st.shards = seedShards()
			end
			st.hbRestore = nil
			st.hbKey = threat.key
			st.hbTgtCF = threat.boxCF
			st.hbTgtSize = threat.size
			if not st.hbCF then
				st.hbCF = threat.boxCF
				st.hbSize = threat.size
			else
				st.hbCF = st.hbCF:Lerp(threat.boxCF, math.min(1, dt * 10))
				st.hbSize = st.hbSize:Lerp(threat.size, math.min(1, dt * 10))
			end
			if floorPhys and (not st.hbFY or now - (st.hbFYAt or 0) > 0.12) then
				st.hbFY = hitboxFloorY(st.hbCF)
				st.hbFYAt = now
			end
			st.hbVis = math.min(1, st.hbVis + dt / (0.16 / spd))
			st.hbHold = 0.12
			st.hbForm = math.min(1, (st.hbForm or 0) + dt / inT)
		else
			if st.hbCF and st.hbTgtCF then
				st.hbCF = st.hbCF:Lerp(st.hbTgtCF, math.min(1, dt * 7))
			end
			if st.hbSize and st.hbTgtSize then
				st.hbSize = st.hbSize:Lerp(st.hbTgtSize, math.min(1, dt * 7))
			end
			if (st.hbForm or 0) < 0.995 and (st.hbOut or 0) == 0 and (st.hbLie or 0) == 0 then
				st.hbForm = math.min(1, (st.hbForm or 0) + dt / inT)
				st.hbVis = math.min(1, st.hbVis + dt / (0.16 / spd))
			else
				st.hbHold = (st.hbHold or 0) - dt
				if (st.hbHold or 0) > 0 then
					st.hbForm = 1
					st.hbVis = math.max(st.hbVis, 0.95)
				elseif floorPhys then
					if (st.hbOut or 0) < 1 then
						st.hbOut = math.min(1, (st.hbOut or 0) + dt / outT)
						st.hbForm = 1 - st.hbOut
					else
						st.hbLie = (st.hbLie or 0) + dt
						st.hbOut = 1
						st.hbForm = 0
						if st.hbLie > 0.42 then
							st.hbVis = math.max(0, 1 - (st.hbLie - 0.42) / 0.18)
						end
					end
				else
					st.hbOut = math.min(1, (st.hbOut or 0) + dt / outT)
					st.hbForm = math.max(0, 1 - st.hbOut)
					st.hbVis = math.max(0, 1 - st.hbOut)
				end
			end
		end
		for gi = #st.gens, 1, -1 do
			local g = st.gens[gi]
			if (g.out or 0) < 1 then
				g.out = math.min(1, (g.out or 0) + dt / outT)
			else
				g.lie = (g.lie or 0) + dt
				g.out = 1
				if g.lie > 0.42 then
					g.vis = math.max(0, 1 - (g.lie - 0.42) / 0.18)
				end
			end
			if (g.vis or 0) <= 0.01 then
				table.remove(st.gens, gi)
			elseif g.cf and g.size then
				renderMirror(g.cf, g.size, g.vis, now, g.shards, "Floor", g.fy, nil, 1, g.out, g.lie, 0)
			end
		end
		if st.hbVis > 0.01 and st.hbCF and st.hbSize then
			renderMirror(st.hbCF, st.hbSize, st.hbVis, now, st.shards, phys, st.hbFY, nil, st.hbForm, st.hbOut, st.hbLie, st.hbSink)
		elseif st.hbVis <= 0.01 then
			table.clear(st.shards)
			st.hbCF = nil
			st.hbSize = nil
			st.hbTgtCF = nil
			st.hbTgtSize = nil
			st.hbKey = nil
			st.hbRestore = nil
			st.hbForm = 0
			st.hbOut = 0
			st.hbLie = 0
			st.hbSink = 0
		end
	end
	renderHitFX(now)
	endFrame()
end)

local function isLocalModel(model)
	return CharacterController:IsLocalCharacterModel(model) or model:GetAttribute("UserId") == LocalPlayer.UserId
end

local rem = ReplicatedStorage.Remotes.PlayerCharacter.Request.ResolveImpact
local oldResolve
oldResolve = hookfunction(rem.FireServer, function(self, id, result, a, b)
	if Config.GodMode and result == "GetHit" then
		result = "Dodge"
	end
	if result == "Parry" then
		playParrySound()
	end
	return oldResolve(self, id, result, a, b)
end)

if SoundModule then
	local oldPlay
	oldPlay = hookfunction(SoundModule.PlaySound, function(src, opts)
		if Config.HitSound and os.clock() < muteHitUntil then
			return nil
		end
		return oldPlay(src, opts)
	end)
end

local soundFolder = workspace:FindFirstChild("Sound")
if soundFolder then
	bind(soundFolder.DescendantAdded, function(inst)
		if inst:IsA("Sound") and Config.HitSound and os.clock() < muteHitUntil then
			inst.Volume = 0
			inst:Stop()
		end
	end)
end

bind(ReplicatedStorage.Remotes.Combat.Impact.OnClientEvent, function(_, effect, attacker, defender, props)
	local pos = props.cframe.Position
	if isLocalModel(attacker) and not PARRY_EFFECTS[effect] and effect ~= "Block" and effect ~= "LightBlock" and effect ~= "UltimateBlock" then
		onLocalConfirmedHit(pos)
		dlog("HIT_FX", "effect=" .. tostring(effect))
	end
	if isLocalModel(attacker) and PARRY_EFFECTS[effect] then
		dbg.enemyParry += 1
		dlog("ENEMY_PARRY", "effect=" .. tostring(effect) .. " def=" .. tostring(defender and defender.Name))
	end
	if isLocalModel(attacker) and (effect == "Block" or effect == "LightBlock" or effect == "UltimateBlock") then
		dbg.enemyBlock += 1
		dlog("ENEMY_BLOCK", "effect=" .. tostring(effect) .. " def=" .. tostring(defender and defender.Name))
	end
	if isLocalModel(defender) and PARRY_EFFECTS[effect] then
		playParrySound()
	end
end)

local function unload()
	running = false
	releaseGuard(localHandler())
	pcall(clearCosmetics)
	for _, c in conns do
		c:Disconnect()
	end
	table.clear(conns)
	for _, d in drawings do
		destroyDraw(d)
	end
	table.clear(drawings)
	genv._DGAP = nil
end

genv._DGAP = {
	unload = unload,
	start = function() end,
	stop = function()
		pcall(unload)
	end,
	config = Config,
	catalog = catalog,
	dbg = dbg,
	uiBound = false,
}

function genv._DGAP.buildUI(ctx)
	if type(ctx) ~= "table" or not ctx.tabs then
		return
	end
	genv._DGAP.uiBound = true
	genv._DGAP.maclib = ctx.MacLib
	local uiReady = false
	task.defer(function()
		uiReady = true
	end)
	local function notify(title, body)
		if uiReady then
			pcall(ctx.notify, title, body)
		end
	end
	local function disc(section, text)
		section:SubLabel({ Text = text })
	end
	local els = {}
	genv._DGAP.els = els
	local function feature(section, o)
		local guard, togEl = false, nil
		local function commit(val)
			val = val and true or false
			o.set(val)
			notify(o.Title, val and "Enabled" or "Disabled")
			guard = true
			if togEl then
				pcall(function()
					togEl:UpdateState(val)
				end)
			end
			guard = false
		end
		togEl = section:Toggle({
			Name = "Enabled",
			Default = o.get() and true or false,
			Callback = function(v)
				if not guard then
					commit(v)
				end
			end,
		}, ctx.flag(o.Flag))
		els[o.Flag] = togEl
		if o.Desc then
			disc(section, o.Desc)
		end
		ctx.keybind(section, {
			Name = "Keybind",
			Flag = ctx.flag(o.Flag .. "_KB"),
			Toggle = function()
				commit(not o.get())
			end,
		})
		return { commit = commit }
	end
	local function enable(section, flag, get, set, desc)
		local el = section:Toggle({
			Name = "Enabled",
			Default = get() and true or false,
			Callback = function(v)
				set(v and true or false)
				notify(flag, v and "Enabled" or "Disabled")
			end,
		}, ctx.flag(flag))
		els[flag] = el
		if desc then
			disc(section, desc)
		end
		return el
	end
	local function slider(section, o)
		local el = section:Slider({
			Name = o.Name,
			Default = o.Default,
			Minimum = o.Min,
			Maximum = o.Max,
			Precision = o.Precision or 0,
			Suffix = o.Suffix,
			Callback = o.Callback,
		}, ctx.flag(o.Flag))
		els[o.Flag] = el
		if o.Desc then
			disc(section, o.Desc)
		end
		return el
	end
	local function pushEl(flag, val)
		local el = els[flag]
		if not el then
			return
		end
		if el.UpdateState then
			pcall(function()
				el:UpdateState(val and true or false)
			end)
		elseif el.UpdateValue then
			pcall(function()
				el:UpdateValue(val, true)
			end)
		elseif el.UpdateSelection then
			pcall(function()
				el:UpdateSelection(val)
			end)
		elseif el.SetColor then
			pcall(function()
				el:SetColor(val)
			end)
		end
	end
	local PRESETS = {
		Blatant = {
			AutoParry = true,
			AutoDodge = true,
			SmartInterrupt = true,
			JumpAttackCounter = true,
			BreakLight = true,
			BreakHeavy = true,
			BreakJump = true,
			BreakDodge = true,
			BreakLightChance = 1,
			BreakHeavyChance = 1,
			BreakJumpChance = 1,
			BreakDodgeChance = 1,
			BreakLightAbs = 1,
			BreakHeavyAbs = 1,
			BreakJumpAbs = 1,
			BreakDodgeAbs = 1,
			ComboMode = "Fastest",
			ComboOnly = false,
			CustomCombo = false,
			ParryChance = 1,
			DodgeChance = 1,
			IntentionalBlock = false,
			IntentionalBlockChance = 0,
			HumanDelay = false,
			HumanDelayMin = 0,
			HumanDelayMax = 0,
			ParryLead = 0,
			DodgeLead = 0.22,
			AttackHelper = true,
			PerfectDodgeCounter = true,
			AHPunishBlock = true,
			AHPunishWhiff = true,
			AHJumpChase = true,
			NoDelay = false,
		},
		SemiLegit = {
			AutoParry = true,
			AutoDodge = true,
			SmartInterrupt = true,
			JumpAttackCounter = false,
			BreakLight = true,
			BreakHeavy = true,
			BreakJump = true,
			BreakDodge = true,
			BreakLightChance = 0.45,
			BreakHeavyChance = 0.7,
			BreakJumpChance = 0.28,
			BreakDodgeChance = 0.55,
			BreakLightAbs = 0.75,
			BreakHeavyAbs = 0.8,
			BreakJumpAbs = 0.5,
			BreakDodgeAbs = 0.75,
			ComboMode = "Fastest",
			ComboOnly = false,
			CustomCombo = false,
			ParryChance = 0.7,
			DodgeChance = 0.55,
			IntentionalBlock = true,
			IntentionalBlockChance = 0.18,
			HumanDelay = true,
			HumanDelayMin = 0.018,
			HumanDelayMax = 0.042,
			ParryLead = 0,
			DodgeLead = 0.22,
			AttackHelper = true,
			PerfectDodgeCounter = true,
			AHPunishBlock = true,
			AHPunishWhiff = false,
			AHJumpChase = false,
			NoDelay = false,
		},
		Legit = {
			AutoParry = true,
			AutoDodge = true,
			SmartInterrupt = true,
			JumpAttackCounter = false,
			BreakLight = true,
			BreakHeavy = true,
			BreakJump = true,
			BreakDodge = true,
			BreakLightChance = 0.25,
			BreakHeavyChance = 0.45,
			BreakJumpChance = 0.18,
			BreakDodgeChance = 0.4,
			BreakLightAbs = 0.7,
			BreakHeavyAbs = 0.65,
			BreakJumpAbs = 0.4,
			BreakDodgeAbs = 0.7,
			ComboMode = "Fastest",
			ComboOnly = false,
			CustomCombo = false,
			ParryChance = 0.48,
			DodgeChance = 0.36,
			IntentionalBlock = true,
			IntentionalBlockChance = 0.28,
			HumanDelay = true,
			HumanDelayMin = 0.032,
			HumanDelayMax = 0.078,
			ParryLead = 0,
			DodgeLead = 0.22,
			AttackHelper = true,
			PerfectDodgeCounter = true,
			AHPunishBlock = true,
			AHPunishWhiff = true,
			AHJumpChase = false,
			NoDelay = false,
		},
	}
	local presetGuard = false
	local function applyPreset(name)
		local p = PRESETS[name]
		if not p then
			return
		end
		presetGuard = true
		Config.Preset = name
		for k, v in p do
			Config[k] = v
			pushEl("DG_" .. k, v)
		end
		pushEl("DG_Preset", name)
		pushEl("DG_ComboMode", Config.ComboMode)
		presetGuard = false
		notify("Preset", name)
	end
	genv._DGAP.applyPreset = applyPreset

	local AutoParry = ctx.tabs.AutoParry
	local Attack = ctx.tabs.Attack
	local Movement = ctx.tabs.Movement
	local Visuals = ctx.tabs.Visuals
	local Misc = ctx.tabs.Misc
	local Debug = ctx.tabs.Debug
	if not AutoParry then
		return
	end

	local weapons = {}
	for name in catalog do
		weapons[#weapons + 1] = name
	end
	table.sort(weapons)
	if #weapons == 0 then
		weapons[1] = "Katana"
	end

	-- ════════════════════════════════ AutoParry ════════════════════════════
	local apBase = AutoParry:Section({ Side = "Left" })
	apBase:Header({ Name = "AutoParry" })
	feature(apBase, {
		Title = "AutoParry",
		Flag = "DG_Enabled",
		Desc = "Master switch. Off = the script does nothing.",
		get = function()
			return Config.Enabled
		end,
		set = function(v)
			Config.Enabled = v
			if not v then
				releaseGuard(localHandler())
				pressed.kind = nil
			end
		end,
	})
	els.DG_Preset = apBase:Dropdown({
		Name = "Preset",
		Options = { "Blatant", "SemiLegit", "Legit" },
		Default = Config.Preset or "Blatant",
		Callback = function(v)
			if not presetGuard then
				applyPreset(v)
			end
		end,
	}, ctx.flag("DG_Preset"))
	disc(apBase, "Blatant = always defend and always counter. SemiLegit = mixed. Legit = current human rolls.")

	apBase:Divider()
	apBase:Header({ Name = "Auto Parry" })
	enable(apBase, "DG_AutoParry", function()
		return Config.AutoParry
	end, function(v)
		Config.AutoParry = v
	end, "Tap guard into the 0.233s parry window.")

	apBase:Divider()
	apBase:Header({ Name = "Auto Dodge" })
	enable(apBase, "DG_AutoDodge", function()
		return Config.AutoDodge
	end, function(v)
		Config.AutoDodge = v
	end, "Iframe dodge. Highest priority when the roll lands.")

	local apChance = AutoParry:Section({ Side = "Left" })
	apChance:Header({ Name = "Chances" })
	disc(apChance, "Chance = how often this option is picked when it is available.")
	disc(apChance, "Commit = after pick, chance we actually do it. 1 = never skip.")
	slider(apChance, {
		Name = "Dodge Chance",
		Flag = "DG_DodgeChance",
		Default = Config.DodgeChance,
		Min = 0,
		Max = 1,
		Precision = 2,
		Desc = "First in the stack. If this roll fails, parry is considered.",
		Callback = function(v)
			Config.DodgeChance = v
		end,
	})
	slider(apChance, {
		Name = "Parry Chance",
		Flag = "DG_ParryChance",
		Default = Config.ParryChance,
		Min = 0,
		Max = 1,
		Precision = 2,
		Desc = "Used when dodge did not take the swing.",
		Callback = function(v)
			Config.ParryChance = v
		end,
	})
	slider(apChance, {
		Name = "Block Chance",
		Flag = "DG_IntentionalBlockChance",
		Default = Config.IntentionalBlockChance,
		Min = 0,
		Max = 1,
		Precision = 2,
		Desc = "Lowest. Hold guard so the parry window burns and the hit is a block.",
		Callback = function(v)
			Config.IntentionalBlockChance = v
		end,
	})

	local apDelay = AutoParry:Section({ Side = "Left" })
	apDelay:Header({ Name = "Human Delay" })
	enable(apDelay, "DG_HumanDelay", function()
		return Config.HumanDelay
	end, function(v)
		Config.HumanDelay = v
	end, "Random wait that still fits the remaining window. 0 = instant.")
	slider(apDelay, {
		Name = "Delay Min",
		Flag = "DG_HumanDelayMin",
		Default = Config.HumanDelayMin,
		Min = 0,
		Max = 0.2,
		Precision = 3,
		Suffix = "s",
		Callback = function(v)
			Config.HumanDelayMin = v
		end,
	})
	slider(apDelay, {
		Name = "Delay Max",
		Flag = "DG_HumanDelayMax",
		Default = Config.HumanDelayMax,
		Min = 0,
		Max = 0.2,
		Precision = 3,
		Suffix = "s",
		Callback = function(v)
			Config.HumanDelayMax = v
		end,
	})

	local apPlay = AutoParry:Section({ Side = "Right" })
	apPlay:Header({ Name = "AutoPlay" })
	enable(apPlay, "DG_SmartInterrupt", function()
		return Config.SmartInterrupt
	end, function(v)
		Config.SmartInterrupt = v
	end, "Break their swing with ours when our hit lands first.")

	apPlay:Divider()
	apPlay:Header({ Name = "Break Light" })
	enable(apPlay, "DG_BreakLight", function()
		return Config.BreakLight
	end, function(v)
		Config.BreakLight = v
	end, "Interrupt Lights with Light (or Heavy if Light does not fit).")
	slider(apPlay, {
		Name = "Chance",
		Flag = "DG_BreakLightChance",
		Default = Config.BreakLightChance,
		Min = 0,
		Max = 1,
		Precision = 2,
		Callback = function(v)
			Config.BreakLightChance = v
		end,
	})
	slider(apPlay, {
		Name = "Commit",
		Flag = "DG_BreakLightAbs",
		Default = Config.BreakLightAbs,
		Min = 0,
		Max = 1,
		Precision = 2,
		Callback = function(v)
			Config.BreakLightAbs = v
		end,
	})

	apPlay:Divider()
	apPlay:Header({ Name = "Break Heavy" })
	enable(apPlay, "DG_BreakHeavy", function()
		return Config.BreakHeavy
	end, function(v)
		Config.BreakHeavy = v
	end, "Interrupt Heavies/Ult with Heavy only if we land first.")
	slider(apPlay, {
		Name = "Chance",
		Flag = "DG_BreakHeavyChance",
		Default = Config.BreakHeavyChance,
		Min = 0,
		Max = 1,
		Precision = 2,
		Callback = function(v)
			Config.BreakHeavyChance = v
		end,
	})
	slider(apPlay, {
		Name = "Commit",
		Flag = "DG_BreakHeavyAbs",
		Default = Config.BreakHeavyAbs,
		Min = 0,
		Max = 1,
		Precision = 2,
		Callback = function(v)
			Config.BreakHeavyAbs = v
		end,
	})

	apPlay:Divider()
	apPlay:Header({ Name = "Break Jump" })
	enable(apPlay, "DG_BreakJump", function()
		return Config.BreakJump
	end, function(v)
		Config.BreakJump = v
	end)
	slider(apPlay, {
		Name = "Chance",
		Flag = "DG_BreakJumpChance",
		Default = Config.BreakJumpChance,
		Min = 0,
		Max = 1,
		Precision = 2,
		Callback = function(v)
			Config.BreakJumpChance = v
		end,
	})
	slider(apPlay, {
		Name = "Commit",
		Flag = "DG_BreakJumpAbs",
		Default = Config.BreakJumpAbs,
		Min = 0,
		Max = 1,
		Precision = 2,
		Callback = function(v)
			Config.BreakJumpAbs = v
		end,
	})

	apPlay:Divider()
	apPlay:Header({ Name = "Break Dodge" })
	enable(apPlay, "DG_BreakDodge", function()
		return Config.BreakDodge
	end, function(v)
		Config.BreakDodge = v
	end, "Dodge + DashLight follow when a standing interrupt is skipped.")
	slider(apPlay, {
		Name = "Chance",
		Flag = "DG_BreakDodgeChance",
		Default = Config.BreakDodgeChance,
		Min = 0,
		Max = 1,
		Precision = 2,
		Callback = function(v)
			Config.BreakDodgeChance = v
		end,
	})
	slider(apPlay, {
		Name = "Commit",
		Flag = "DG_BreakDodgeAbs",
		Default = Config.BreakDodgeAbs,
		Min = 0,
		Max = 1,
		Precision = 2,
		Callback = function(v)
			Config.BreakDodgeAbs = v
		end,
	})

	local apTime = AutoParry:Section({ Side = "Right" })
	apTime:Header({ Name = "Timing" })
	slider(apTime, {
		Name = "Parry Lead",
		Flag = "DG_ParryLead",
		Default = Config.ParryLead,
		Min = -0.05,
		Max = 0.2,
		Precision = 3,
		Suffix = "s",
		Desc = "Press this much before impact. 0 = marker time.",
		Callback = function(v)
			Config.ParryLead = v
		end,
	})
	slider(apTime, {
		Name = "Dodge Lead",
		Flag = "DG_DodgeLead",
		Default = Config.DodgeLead,
		Min = 0,
		Max = 0.4,
		Precision = 3,
		Suffix = "s",
		Desc = "Dodge earlier than parry. Iframe is 0.3s.",
		Callback = function(v)
			Config.DodgeLead = v
		end,
	})
	slider(apTime, {
		Name = "Hold After",
		Flag = "DG_HoldAfter",
		Default = Config.HoldAfter,
		Min = 0,
		Max = 0.2,
		Precision = 3,
		Suffix = "s",
		Callback = function(v)
			Config.HoldAfter = v
		end,
	})
	slider(apTime, {
		Name = "Reach Pad",
		Flag = "DG_ReachPad",
		Default = Config.ReachPad,
		Min = 0,
		Max = 2,
		Precision = 2,
		Desc = "Extra studs on will-hit.",
		Callback = function(v)
			Config.ReachPad = v
		end,
	})

	local apBlock = AutoParry:Section({ Side = "Right" })
	apBlock:Header({ Name = "Block" })
	enable(apBlock, "DG_IntentionalBlock", function()
		return Config.IntentionalBlock
	end, function(v)
		Config.IntentionalBlock = v
	end, "Hold instead of tap so the parry window expires. Chance is in Chances.")

	local apCombo = AutoParry:Section({ Side = "Right" })
	apCombo:Header({ Name = "Combo" })
	els.DG_ComboMode = apCombo:Dropdown({
		Name = "Combo Mode",
		Options = { "Fastest", "GameCombo", "Custom" },
		Default = Config.ComboMode or "Fastest",
		Callback = function(v)
			Config.ComboMode = v
			Config.ComboOnly = v == "GameCombo"
			Config.CustomCombo = v == "Custom"
		end,
	}, ctx.flag("DG_ComboMode"))
	disc(apCombo, "Fastest = if the next combo hit is too slow, throw 01 instead.")
	disc(apCombo, "GameCombo = always the game next Light/Heavy. Custom = order below.")

	-- ════════════════════════════════ Attack ═══════════════════════════════
	if Attack then
		local atL = Attack:Section({ Side = "Left" })
		atL:Header({ Name = "Attack Helper" })
		feature(atL, {
			Title = "Attack Helper",
			Flag = "DG_AttackHelper",
			Desc = "Punish parry / block / whiff. Light or dodge+DashLight.",
			get = function()
				return Config.AttackHelper
			end,
			set = function(v)
				Config.AttackHelper = v
			end,
		})
		enable(atL, "DG_PerfectDodgeCounter", function()
			return Config.PerfectDodgeCounter
		end, function(v)
			Config.PerfectDodgeCounter = v
		end, "Hit after their dodge iframe dies.")
		enable(atL, "DG_AHPunishBlock", function()
			return Config.AHPunishBlock
		end, function(v)
			Config.AHPunishBlock = v
		end, "Light (or DashLight) when they hold block past the parry window.")
		enable(atL, "DG_AHPunishWhiff", function()
			return Config.AHPunishWhiff
		end, function(v)
			Config.AHPunishWhiff = v
		end, "Light when they are in recovery after a miss.")
		enable(atL, "DG_AHJumpChase", function()
			return Config.AHJumpChase
		end, function(v)
			Config.AHJumpChase = v
		end, "Jump+attack into a forward dodge.")
		enable(atL, "DG_JumpAttackCounter", function()
			return Config.JumpAttackCounter
		end, function(v)
			Config.JumpAttackCounter = v
		end, "Jump slam as a defensive counter.")

		local atR = Attack:Section({ Side = "Right" })
		atR:Header({ Name = "No Delay" })
		feature(atR, {
			Title = "No Delay",
			Flag = "DG_NoDelay",
			Desc = "Skips our HumanDelay on queued hits. Does not touch game predictionEndTime (that 3x-speeds the anim and cancels unconfirmed attacks).",
			get = function()
				return Config.NoDelay
			end,
			set = function(v)
				Config.NoDelay = v
			end,
		})

		atR:Divider()
		atR:Header({ Name = "Custom Combo" })
		enable(atR, "DG_CustomCombo", function()
			return Config.CustomCombo
		end, function(v)
			Config.CustomCombo = v
			if v then
				Config.ComboMode = "Custom"
				Config.ComboOnly = false
			end
		end, "Rewrite Light/Heavy order per weapon. 2,3,4,1 instead of 1,2,3,4.")
		local lightOpts = { "Light01", "Light02", "Light03", "Light04", "DashLight", "none" }
		local heavyOpts = { "Heavy01", "Heavy02", "Heavy03", "DashHeavy", "none" }
		local comboWep = weapons[1]
		local lightSlots, heavySlots = {}, {}
		local function defaultOrder(kind)
			if kind == "Light" then
				return { "Light01", "Light02", "Light03", "Light04" }
			end
			return { "Heavy01", "Heavy02", "Heavy03" }
		end
		local function ensureMap(w)
			Config.ComboMap[w] = Config.ComboMap[w] or {}
			Config.ComboMap[w].Light = Config.ComboMap[w].Light or defaultOrder("Light")
			Config.ComboMap[w].Heavy = Config.ComboMap[w].Heavy or defaultOrder("Heavy")
			return Config.ComboMap[w]
		end
		local function writeSlot(kind, idx, val)
			local m = ensureMap(comboWep)
			local list = {}
			local src = m[kind]
			for i = 1, #src do
				list[i] = src[i]
			end
			if val == "none" then
				table.remove(list, idx)
			else
				list[idx] = val
			end
			m[kind] = list
		end
		local function loadSlots()
			local m = ensureMap(comboWep)
			for i, el in lightSlots do
				local v = m.Light[i] or "none"
				pcall(function()
					el:UpdateSelection(v)
				end)
			end
			for i, el in heavySlots do
				local v = m.Heavy[i] or "none"
				pcall(function()
					el:UpdateSelection(v)
				end)
			end
		end
		atR:Dropdown({
			Name = "Weapon",
			Options = weapons,
			Default = comboWep,
			Callback = function(v)
				comboWep = v
				loadSlots()
			end,
		}, ctx.flag("DG_ComboWep"))
		for i = 1, 4 do
			lightSlots[i] = atR:Dropdown({
				Name = "Light " .. tostring(i),
				Options = lightOpts,
				Default = defaultOrder("Light")[i] or "none",
				Callback = function(v)
					writeSlot("Light", i, v)
				end,
			}, ctx.flag("DG_CL" .. i))
		end
		for i = 1, 3 do
			heavySlots[i] = atR:Dropdown({
				Name = "Heavy " .. tostring(i),
				Options = heavyOpts,
				Default = defaultOrder("Heavy")[i] or "none",
				Callback = function(v)
					writeSlot("Heavy", i, v)
				end,
			}, ctx.flag("DG_CH" .. i))
		end
		atR:Button({
			Name = "Reset Order",
			Callback = function()
				Config.ComboMap[comboWep] = {
					Light = defaultOrder("Light"),
					Heavy = defaultOrder("Heavy"),
				}
				loadSlots()
				notify("Combo", "reset " .. tostring(comboWep))
			end,
		})
	end

	-- ════════════════════════════════ Movement ═════════════════════════════
	if Movement then
		local mvL = Movement:Section({ Side = "Left" })
		mvL:Header({ Name = "Speed" })
		feature(mvL, {
			Title = "Speed",
			Flag = "DG_Speed",
			Desc = "CFrame step along move direction.",
			get = function()
				return Config.Speed
			end,
			set = function(v)
				Config.Speed = v
			end,
		})
		slider(mvL, {
			Name = "Speed",
			Flag = "DG_SpeedValue",
			Default = Config.SpeedValue,
			Min = 8,
			Max = 80,
			Precision = 1,
			Callback = function(v)
				Config.SpeedValue = v
			end,
		})

		mvL:Divider()
		mvL:Header({ Name = "NoClip" })
		feature(mvL, {
			Title = "NoClip",
			Flag = "DG_NoClip",
			Desc = "Turns off collision on our root and parts.",
			get = function()
				return Config.NoClip
			end,
			set = function(v)
				Config.NoClip = v
			end,
		})

		mvL:Divider()
		mvL:Header({ Name = "No Slowdown" })
		feature(mvL, {
			Title = "No Slowdown",
			Flag = "DG_NoSlowdown",
			Desc = "Keeps WalkSpeed at weapon RunSpeed.",
			get = function()
				return Config.NoSlowdown
			end,
			set = function(v)
				Config.NoSlowdown = v
			end,
		})

		local mvR = Movement:Section({ Side = "Right" })
		mvR:Header({ Name = "No Stun" })
		feature(mvR, {
			Title = "No Stun",
			Flag = "DG_NoStun",
			Desc = "Cancels stagger so you can act through hitstun.",
			get = function()
				return Config.NoStun
			end,
			set = function(v)
				Config.NoStun = v
			end,
		})

		mvR:Divider()
		mvR:Header({ Name = "God Mode" })
		feature(mvR, {
			Title = "God Mode",
			Flag = "DG_GodMode",
			Desc = "Forces dodge iframe. ResolveImpact GetHit becomes Dodge.",
			get = function()
				return Config.GodMode
			end,
			set = function(v)
				Config.GodMode = v
			end,
		})

		mvR:Divider()
		mvR:Header({ Name = "Dodge" })
		slider(mvR, {
			Name = "Dodge Speed",
			Flag = "DG_DodgeSpeed",
			Default = Config.DodgeSpeed,
			Min = 0.5,
			Max = 3,
			Precision = 2,
			Desc = "Rewrites Dodge MovementProperties.velocity every frame. 1 = vanilla.",
			Callback = function(v)
				Config.DodgeSpeed = v
			end,
		})
		slider(mvR, {
			Name = "Dodge Range",
			Flag = "DG_DodgeRange",
			Default = Config.DodgeRange,
			Min = 0.5,
			Max = 3,
			Precision = 2,
			Desc = "DodgeDistance mul. Applied on the live Dodge action.",
			Callback = function(v)
				Config.DodgeRange = v
			end,
		})
		slider(mvR, {
			Name = "Dodge Cooldown",
			Flag = "DG_DodgeCooldown",
			Default = Config.DodgeCooldown,
			Min = 0.05,
			Max = 1.5,
			Precision = 2,
			Suffix = "s",
			Callback = function(v)
				Config.DodgeCooldown = v
			end,
		})
	end

	-- ════════════════════════════════ Visuals ══════════════════════════════
	if Visuals then
		local vsL = Visuals:Section({ Side = "Left" })
		vsL:Header({ Name = "Target ESP" })
		feature(vsL, {
			Title = "Target ESP",
			Flag = "DG_Visuals",
			Desc = "Draws on the two nearest enemies.",
			get = function()
				return Config.Visuals
			end,
			set = function(v)
				Config.Visuals = v
			end,
		})
		vsL:Dropdown({
			Name = "Style",
			Options = ESP_STYLES,
			Default = Config.EspStyle,
			Callback = function(v)
				if type(v) == "string" then
					Config.EspStyle = v
				end
			end,
		}, ctx.flag("DG_EspStyle"))
		slider(vsL, {
			Name = "Speed",
			Flag = "DG_EspSpeed",
			Default = Config.EspSpeed,
			Min = 0.1,
			Max = 4,
			Precision = 2,
			Callback = function(v)
				Config.EspSpeed = v
			end,
		})
		slider(vsL, {
			Name = "Thickness",
			Flag = "DG_EspThick",
			Default = Config.EspThick,
			Min = 1,
			Max = 6,
			Precision = 1,
			Callback = function(v)
				Config.EspThick = v
			end,
		})
		vsL:Colorpicker({
			Name = "Color A",
			Default = Config.EspColorA,
			Callback = function(c)
				if typeof(c) == "Color3" then
					Config.EspColorA = c
				end
			end,
		}, ctx.flag("DG_EspColorA"))
		vsL:Colorpicker({
			Name = "Color B",
			Default = Config.EspColorB,
			Callback = function(c)
				if typeof(c) == "Color3" then
					Config.EspColorB = c
				end
			end,
		}, ctx.flag("DG_EspColorB"))

		vsL:Divider()
		vsL:Header({ Name = "Hitbox" })
		feature(vsL, {
			Title = "Hitbox",
			Flag = "DG_Hitbox",
			Desc = "Live attack box on the current threat.",
			get = function()
				return Config.Hitbox
			end,
			set = function(v)
				Config.Hitbox = v
			end,
		})
		vsL:Dropdown({
			Name = "Physics",
			Options = { "UseAnother", "AddAnother", "Floor", "Scatter" },
			Default = Config.HitboxPhysics,
			Callback = function(v)
				Config.HitboxPhysics = v
			end,
		}, ctx.flag("DG_HitboxPhysics"))
		disc(vsL, "Scatter = shards fly in air. Floor/UseAnother = drop onto the ground.")
		slider(vsL, {
			Name = "Anim Speed",
			Flag = "DG_HitboxAnimSpeed",
			Default = Config.HitboxAnimSpeed,
			Min = 0.2,
			Max = 2,
			Precision = 2,
			Callback = function(v)
				Config.HitboxAnimSpeed = v
			end,
		})
		slider(vsL, {
			Name = "Fall Speed",
			Flag = "DG_HitboxFallSpeed",
			Default = Config.HitboxFallSpeed,
			Min = 0.1,
			Max = 1.5,
			Precision = 2,
			Suffix = "s",
			Callback = function(v)
				Config.HitboxFallSpeed = v
			end,
		})
		vsL:Colorpicker({
			Name = "Gradient A",
			Default = Config.HitboxColorA,
			Callback = function(c)
				if typeof(c) == "Color3" then
					Config.HitboxColorA = c
				end
			end,
		}, ctx.flag("DG_HitboxColorA"))
		vsL:Colorpicker({
			Name = "Gradient B",
			Default = Config.HitboxColorB,
			Callback = function(c)
				if typeof(c) == "Color3" then
					Config.HitboxColorB = c
				end
			end,
		}, ctx.flag("DG_HitboxColorB"))

		local vsR = Visuals:Section({ Side = "Right" })
		vsR:Header({ Name = "Custom Model" })
		feature(vsR, {
			Title = "Custom Model",
			Flag = "DG_CustomModel",
			Desc = "Glass body + outline. Clothes stripped. Weapon not touched.",
			get = function()
				return Config.CustomModel
			end,
			set = function(v)
				Config.CustomModel = v
				if not v then
					pcall(clearCosmetics)
				end
			end,
		})
		vsR:Dropdown({
			Name = "Material",
			Options = { "Glass", "ForceField", "Neon", "Ice", "SmoothPlastic", "Plastic", "Metal", "Foil" },
			Default = Config.CustomModelMaterial,
			Callback = function(v)
				Config.CustomModelMaterial = v
			end,
		}, ctx.flag("DG_CMMat"))
		slider(vsR, {
			Name = "Transparency",
			Flag = "DG_CustomModelTransparency",
			Default = Config.CustomModelTransparency,
			Min = 0,
			Max = 0.9,
			Precision = 2,
			Desc = "0 = solid glass. Higher = more see-through.",
			Callback = function(v)
				Config.CustomModelTransparency = v
			end,
		})
		vsR:Colorpicker({
			Name = "Glass Color",
			Default = Config.CustomModelColor,
			Callback = function(c)
				if typeof(c) == "Color3" then
					Config.CustomModelColor = c
				end
			end,
		}, ctx.flag("DG_CMCol"))
		vsR:Colorpicker({
			Name = "Outline Color",
			Default = Config.OutlineColor,
			Callback = function(c)
				if typeof(c) == "Color3" then
					Config.OutlineColor = c
				end
			end,
		}, ctx.flag("DG_CMOut"))

		vsR:Divider()
		vsR:Header({ Name = "Hit Ring" })
		feature(vsR, {
			Title = "Hit Ring",
			Flag = "DG_HitRing",
			Desc = "One floor ring on a confirmed hit.",
			get = function()
				return Config.HitRing
			end,
			set = function(v)
				Config.HitRing = v
			end,
		})
		slider(vsR, {
			Name = "Life",
			Flag = "DG_HitRingLife",
			Default = Config.HitRingLife,
			Min = 0.4,
			Max = 4,
			Precision = 2,
			Suffix = "s",
			Callback = function(v)
				Config.HitRingLife = v
			end,
		})
		slider(vsR, {
			Name = "Start Radius",
			Flag = "DG_HitRingR0",
			Default = Config.HitRingR0,
			Min = 0.1,
			Max = 3,
			Precision = 2,
			Callback = function(v)
				Config.HitRingR0 = v
			end,
		})
		slider(vsR, {
			Name = "End Radius",
			Flag = "DG_HitRingR1",
			Default = Config.HitRingR1,
			Min = 1,
			Max = 12,
			Precision = 2,
			Callback = function(v)
				Config.HitRingR1 = v
			end,
		})
		slider(vsR, {
			Name = "Thickness",
			Flag = "DG_HitRingThick",
			Default = Config.HitRingThick,
			Min = 1,
			Max = 8,
			Precision = 1,
			Callback = function(v)
				Config.HitRingThick = v
			end,
		})
		vsR:Colorpicker({
			Name = "Ring A",
			Default = Config.HitRingColorA,
			Callback = function(c)
				if typeof(c) == "Color3" then
					Config.HitRingColorA = c
				end
			end,
		}, ctx.flag("DG_HitRingColorA"))
		vsR:Colorpicker({
			Name = "Ring B",
			Default = Config.HitRingColorB,
			Callback = function(c)
				if typeof(c) == "Color3" then
					Config.HitRingColorB = c
				end
			end,
		}, ctx.flag("DG_HitRingColorB"))

		local vsS = Visuals:Section({ Side = "Right" })
		vsS:Header({ Name = "Hit Sound" })
		feature(vsS, {
			Title = "Hit Sound",
			Flag = "DG_HitSound",
			get = function()
				return Config.HitSound
			end,
			set = function(v)
				Config.HitSound = v
			end,
		})
		vsS:Dropdown({
			Name = "Preset",
			Options = { "Fatality", "Click", "Bell", "Neverlose", "SuccessFX" },
			Default = Config.HitSoundPreset,
			Callback = function(v)
				Config.HitSoundPreset = v
			end,
		}, ctx.flag("DG_HitSoundPreset"))
		slider(vsS, {
			Name = "Volume",
			Flag = "DG_HitSoundVolume",
			Default = Config.HitSoundVolume,
			Min = 0,
			Max = 10,
			Precision = 1,
			Callback = function(v)
				Config.HitSoundVolume = v
			end,
		})
		vsS:Button({
			Name = "Preview",
			Callback = function()
				playIdSound(HIT_SOUNDS[Config.HitSoundPreset] or 115982072912004, Config.HitSoundVolume)
			end,
		})

		vsS:Divider()
		vsS:Header({ Name = "Parry Sound" })
		feature(vsS, {
			Title = "Parry Sound",
			Flag = "DG_ParrySound",
			get = function()
				return Config.ParrySound
			end,
			set = function(v)
				Config.ParrySound = v
			end,
		})
		vsS:Dropdown({
			Name = "Preset",
			Options = { "Fatality", "Click", "Bell", "Neverlose", "SuccessFX" },
			Default = Config.ParrySoundPreset,
			Callback = function(v)
				Config.ParrySoundPreset = v
			end,
		}, ctx.flag("DG_ParrySoundPreset"))
		slider(vsS, {
			Name = "Volume",
			Flag = "DG_ParrySoundVolume",
			Default = Config.ParrySoundVolume,
			Min = 0,
			Max = 10,
			Precision = 1,
			Callback = function(v)
				Config.ParrySoundVolume = v
			end,
		})
		vsS:Button({
			Name = "Preview",
			Callback = function()
				playIdSound(HIT_SOUNDS[Config.ParrySoundPreset] or 18448089848, Config.ParrySoundVolume)
			end,
		})
	end

	-- ════════════════════════════════ Misc ═════════════════════════════════
	if Misc then
		local msL = Misc:Section({ Side = "Left" })
		msL:Header({ Name = "Skin Changer" })
		disc(msL, "Per-weapon cosmetic. Default = stock. Reset writes Default and refreshes UI.")
		local skinEls = {}
		for _, wname in weapons do
			local pack = catalog[wname]
			local opts = { "Default" }
			if pack and pack.cosmetics then
				for _, n in pack.cosmetics do
					if n ~= "Default" then
						opts[#opts + 1] = n
					end
				end
			end
			local cur = Config.WeaponSkins[wname] or "Default"
			skinEls[wname] = msL:Dropdown({
				Name = wname,
				Options = opts,
				Default = cur,
				Callback = function(v)
					Config.WeaponSkins[wname] = v
					local lh = localHandler()
					if lh and tostring(lh.EquippedWeapon) == wname then
						applySkin(v)
					end
				end,
			}, ctx.flag("DG_Skin_" .. wname))
		end
		msL:Button({
			Name = "Reset",
			Callback = function()
				for _, wname in weapons do
					Config.WeaponSkins[wname] = "Default"
					local el = skinEls[wname]
					if el then
						pcall(function()
							el:UpdateSelection("Default")
						end)
					end
				end
				applySkin("Default")
				notify("Skin", "reset")
			end,
		})

		local msR = Misc:Section({ Side = "Right" })
		msR:Header({ Name = "Staff Detect" })
		enable(msR, "DG_StaffDetect", function()
			return Config.StaffDetect
		end, function(v)
			Config.StaffDetect = v
		end, "Kick if a third player joins a 1v1.")
	end

	-- ════════════════════════════════ Debug ════════════════════════════════
	if Debug then
		local dbgS = Debug:Section({ Side = "Left" })
		dbgS:Header({ Name = "Log" })
		dbgS:Button({
			Name = "Dump",
			Callback = function()
				dumpDebug()
				notify("Dump", "written")
			end,
		})

		local dbgU = Debug:Section({ Side = "Right" })
		dbgU:Header({ Name = "Unload" })
		dbgU:Button({
			Name = "Unload Combat",
			Callback = function()
				pcall(unload)
				notify("DG-AP", "unloaded")
			end,
		})
	end
end

do
	local nW, nA = 0, 0
	for _, pack in catalog do
		nW += 1
		for _ in pack.attacks do
			nA += 1
		end
	end
	print("[DG-AP] loaded weapons=" .. nW .. " attacks=" .. nA)
	print("[DG-AP] loader module style=" .. Config.EspStyle)
end

return genv._DGAP
