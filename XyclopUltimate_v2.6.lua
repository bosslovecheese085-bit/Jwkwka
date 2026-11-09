--[[
	Xyclop Ultimate v2.6  (LocalScript)
	Put it in: StarterPlayer > StarterPlayerScripts

	v2.1: bright sky-blue cinematic loader, floating hide/show button (+ Right Shift),
	"Floating button" switch in Settings, resize by dragging the bottom-right corner,
	rounded bottom edge fix (content is now clipped to the rounded window).

	v2.1.1 FIX: "attempt to call a nil value" on run. The script had ~225 top-level
	local variables, but Luau allows max 200 per function, so it failed to compile
	(loadstring returned nil). UI sections are now wrapped in do ... end blocks.
	Nothing else was changed.

	v2.2: Home page (avatar, name, live player + server stats), Update Log tab,
	cinematic tab-switch animation (logo + tab name), 5 selectable loading screens
	(Settings > Loading screen, with Preview), settings saved to a file when the
	executor supports writefile/readfile.

	v2.3: QUICK FLY DIAL. Press and HOLD the floating button: the charge ring fills up,
	then the button morphs into an instant fly button with a circular speed dial around
	the icon.
	  - Tap the icon          = fly on / off immediately
	  - Drag around the ring  = change the speed (synced with the Fly tab slider)
	  - Hold + slide          = keep your finger down and slide in a circle
	  - Hold the icon again   = close the dial
	All new code lives inside the [S:float] block (no new top-level locals).

	v2.4: COMBAT + VISUAL tabs (aim lock, FOV scope, target marker / ESP) and the Combat + Visual
	quick dials.

	v2.5:
	  - PLAYER tab: walk speed, jump power, gravity (+ reset), and a 4th quick dial with three
	    liquid tubes (hold the floating button: Fly -> Combat -> Visual -> Player -> closed).
	  - COMBAT: LOCK ON arms instantly and locks the first target that enters the FOV, NPC lock
	    switch, random body part, nearest / farthest / crosshair priority, FOV idle + locked colors.
	  - MISC tab: Shift Lock button (move, pin, hold-for-size-ring), customizable crosshair,
	    Anti AFK, Auto Execute, Rejoin, smallest server, server hop and a server list.
	    Auto Execute needs your loader line once (paste it in the Misc tab) or set
	    getgenv().XyclopSource before running this script.
	  - SETTINGS: rainbow theme.

	v2.6:
	  - MUSIC PLAYER on the left of the window (note button in the title bar). It plays every
	    .mp3 / .ogg in  workspace/XyclopXR/Music , with loop (off / all / one) and shuffle.
	  - COMBAT: NEXT button (and the arrows on the Combat dial) switch to another target without unlocking.
	  - ATMOSPHERE tab: Fullbright and No Fog.
	  - CREDITS: new cinematic page that shows the maker picture from  workspace/XyclopXR/DvplPF/Profile.png
	  - XyclopXR/Music and XyclopXR/DvplPF/Profile.png are created / downloaded from GitHub automatically.
]]

-------------------------------------------------- SERVICES
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local TS=game:GetService("TweenService")
local Lighting=game:GetService("Lighting")
local CP=game:GetService("ContentProvider")
local Debris=game:GetService("Debris")
local LocService=game:GetService("LocalizationService")
local TextService=game:GetService("TextService")
local player=Players.LocalPlayer
local playerGui=player:WaitForChild("PlayerGui")

for _,n in ipairs({"NeonFlyGui","NeonFlyLoading"}) do
	local o=playerGui:FindFirstChild(n)
	if o then o:Destroy() end
end
local oldBlur=Lighting:FindFirstChild("NeonFlyBlur")
if oldBlur then oldBlur:Destroy() end
for _,o in ipairs(playerGui:GetChildren()) do
	if o.Name=="NeonFlyBB" then o:Destroy() end
end
pcall(function() RunService:UnbindFromRenderStep("NeonFlyAim") end)
pcall(function() RunService:UnbindFromRenderStep("NeonFlySL") end)

-------------------------------------------------- CONFIG
local MIN_SPEED,MAX_SPEED,DEFAULT_SPEED=10,300,60
local W,H_OPEN,H_MIN,TAB_H=340,320,44,42
local MIN_SCALE,MAX_SCALE=0.7,1.6
local C={
	Text=Color3.fromRGB(240,244,255),Muted=Color3.fromRGB(125,133,168),
	Off=Color3.fromRGB(48,52,76),Danger=Color3.fromRGB(255,77,109),
	White=Color3.new(1,1,1),Ink=Color3.fromRGB(10,11,19),
}
-- loading screen palette (bright sky blue)
local LB={
	top=Color3.fromRGB(86,186,255),
	bot=Color3.fromRGB(16,98,230),
	a1=Color3.fromRGB(255,255,255),
	a2=Color3.fromRGB(140,228,255),
	deep=Color3.fromRGB(8,56,160),
	soft=Color3.fromRGB(224,244,255),
}

-- loading screen styles (pick one in Settings): palette + layout flags
local LSTYLES={
	{name="Sky Warp",bar="pill",rays=true,P=LB},
	{name="Synthwave",bar="seg",P={
		top=Color3.fromRGB(46,8,84),bot=Color3.fromRGB(12,2,30),
		a1=Color3.fromRGB(255,64,200),a2=Color3.fromRGB(0,240,255),
		deep=Color3.fromRGB(24,4,52),soft=Color3.fromRGB(255,214,246)}},
	{name="Matrix",bar="ascii",term=true,P={
		top=Color3.fromRGB(0,24,10),bot=Color3.fromRGB(0,4,2),
		a1=Color3.fromRGB(120,255,160),a2=Color3.fromRGB(0,200,90),
		deep=Color3.fromRGB(0,40,18),soft=Color3.fromRGB(180,255,200)}},
	{name="Hyperspace",bar="pill",P={
		top=Color3.fromRGB(18,10,52),bot=Color3.fromRGB(2,2,14),
		a1=Color3.fromRGB(170,200,255),a2=Color3.fromRGB(150,90,255),
		deep=Color3.fromRGB(10,8,40),soft=Color3.fromRGB(214,228,255)}},
	{name="Aurora",bar="pill",glass=true,P={
		top=Color3.fromRGB(8,34,56),bot=Color3.fromRGB(4,10,28),
		a1=Color3.fromRGB(90,255,200),a2=Color3.fromRGB(170,120,255),
		deep=Color3.fromRGB(4,24,40),soft=Color3.fromRGB(215,255,240)}},
}

local SFX_IDS={
	click="rbxasset://sounds/button.wav",
	switch="rbxasset://sounds/switch.wav",
	tick="rbxasset://sounds/clickfast.wav",
	ping="rbxasset://sounds/electronicpingshort.wav",
	whoosh="rbxasset://sounds/action_falling.mp3",
	land="rbxasset://sounds/action_jump_land.mp3",
	wind="rbxasset://sounds/action_falling.mp3",
}

local THEMES={
	{"Neon",Color3.fromRGB(0,229,255),Color3.fromRGB(150,90,255)},
	{"Sunset",Color3.fromRGB(255,140,70),Color3.fromRGB(255,60,130)},
	{"Matrix",Color3.fromRGB(170,255,90),Color3.fromRGB(0,200,140)},
	{"Ocean",Color3.fromRGB(64,160,255),Color3.fromRGB(0,230,200)},
	{"Rose",Color3.fromRGB(255,120,200),Color3.fromRGB(190,90,255)},
	{"Gold",Color3.fromRGB(255,214,70),Color3.fromRGB(255,130,40)},
	{"Ice",Color3.fromRGB(190,235,255),Color3.fromRGB(120,150,255)},
	{"Crimson",Color3.fromRGB(255,80,90),Color3.fromRGB(255,160,60)},
}

local LANGS={
	{code="en",name="English"},
	{code="th",name="ไทย"},
	{code="zh",name="简体中文"},
	{code="ja",name="日本語"},
	{code="ko",name="한국어"},
	{code="es",name="Español"},
	{code="pt",name="Português"},
	{code="ru",name="Русский"},
	{code="id",name="Indonesia"},
	{code="vi",name="Tiếng Việt"},
}

local L={
	en={sub="Flight module",tab_fly="Fly",tab_set="Settings",fly_mode="Fly mode",on="Active",off="Disabled",
		speed="Speed",now="Current",lang="Language",theme="Theme color",hue="Custom hue",grp_fx="Sound & effects",
		sfx="Sound effects",volume="Volume",vfx="Visual effects",
		ld1="Preparing interface",ld2="Loading sounds",ld3="Setting up effects",ld4="Ready!",
		tip1="Space / E to rise · Q / Ctrl to descend · or use ▲ ▼",
		tip2="Pick your colors in Settings",tip3="Drag the title bar to move the window",
		t_on="Fly enabled",t_off="Fly disabled",t_fail="Character not found",
		tab_credit="Credits",cr_thanks="Thanks for using Xyclop Ultimate",
		grp_ui="Interface",float="Floating button",
		tip4="Drag the bottom-right corner to resize the window",
		tip5="Tap the floating X button or press Right Shift to hide / show",
		tab_home="Home",tab_log="Updates",welcome="Welcome back",grp_player="Player",
		grp_server="Server",days="days",st_health="Health",st_walk="Walk speed",
		st_jump="Jump",st_height="Height",st_flyspd="Fly speed",sv_players="Players",
		sv_uptime="Uptime",sv_ping="Ping",sv_fps="FPS",sv_mem="Memory",
		sv_place="Place ID",grp_load="Loading screen",preview="Preview",tip6="Change the loading screen style in Settings",
		tip7="Hold the floating button to open Quick Fly",
		qf_hint="Tap the icon to fly · Drag the ring for speed · Hold for Combat",
		qf_hint3="Tap the icon for ESP on / off · Drag the ring to change color · Hold for Player",
		qf_hint4="Drag a tube: speed · jump · gravity · Tap for mods ON / OFF · Hold to close",
		tab_combat="Combat",tab_visual="Visual",tab_player="Player",tab_misc="Misc",
		tip8="Hold the floating button again: Combat, then Visual, then Player",
		cb_aim="Aim lock",cb_lock="LOCK ON",cb_unlock="UNLOCK",cb_locked="LOCKED",cb_search="SCANNING",cb_ready="READY",
		cb_none="No target inside the FOV",cb_scan="scanning…",
		cb_part="Target part",cb_head="Head",cb_torso="Torso",cb_root="Root",cb_feet="Feet",cb_random="Random",
		cb_prio="Target priority",cb_pcross="Crosshair",cb_pnear="Nearest",cb_pfar="Farthest",
		cb_filters="Filters",cb_wall="Wall check",cb_team="Ignore team",cb_auto="Auto switch on death",
		cb_npc="Lock NPCs",cb_showfov="Show FOV circle",
		cb_fov="FOV",cb_colors="FOV colors",cb_cidle="Idle color",cb_clock="Locked color",
		cb_players="Pick a target",cb_noplayers="No other players",
		vz_sub="See players through walls",vz_feat="ESP features",vz_lines="Lines (tracers)",vz_box="Hitbox (box)",
		vz_hp="Health bar",vz_name="Names",vz_color="ESP color",
		pl_mods="Player mods",pl_sub="Speed · Jump · Gravity",pl_speed="Walk speed",pl_jump="Jump power",pl_grav="Gravity",
		pl_reset="Reset to game default",rainbow="Rainbow theme",
		ms_sl="Shift Lock",ms_slbtn="Shift Lock button",ms_pin="Pin button position",ms_slsize="Button size",
		ms_xh="Crosshair",ms_xhon="Show crosshair",ms_xhsl="Show in Shift Lock",
		ms_style="Crosshair style",ms_shape="Shape",ms_size="Size",ms_thick="Thickness",ms_gap="Center gap",
		ms_op="Opacity",ms_spin="Spin speed",ms_color="Color & effects",ms_hue="Color",ms_rainbow="Rainbow color",
		ms_dot="Center dot",ms_outline="Outline",ms_glow="Glow",ms_react="React to lock-on",
		ms_util="Utilities",ms_afk="Anti AFK",ms_aex="Auto Execute",
		ms_aexhint="Paste your loadstring line (or script URL) once. It runs again after Rejoin / server hop / teleport.",
		ms_nosrc="Paste your loadstring line first",ms_noq="Executor has no queue_on_teleport",
		ms_servers="Servers",ms_rejoin="Rejoin",ms_small="Smallest",ms_hop="Server hop",
		ms_list="Server list",ms_fewest="Fewest",ms_most="Most",ms_refresh="Refresh",ms_join="JOIN",
		ms_busy="Searching…",ms_nohttp="Could not reach Roblox (the executor needs HTTP support)",
		ms_nosrv="No suitable server found",ms_joining="Teleporting…",ms_listhint="Press Refresh to load servers",
		qf_hint2="Tap = lock · ▶▶ = next target · Drag ring = FOV · Hold = Visual",
		mp_title="Music",mp_tracks="tracks",mp_empty="No music found",
		mp_hint="Put .mp3 / .ogg files in workspace/XyclopXR/Music",
		mp_noapi="This executor cannot play local files (needs listfiles + getcustomasset)",mp_pick="Pick a song",
		tab_atmo="Atmosphere",at_fb="Fullbright",at_fbsub="Light up the whole map",at_nf="No Fog",
		at_nfsub="Clear the fog and haze",at_str="Brightness",cb_next="NEXT",
		log_new="NEW"},
	th={sub="โมดูลการบิน",tab_fly="บิน",tab_set="ตั้งค่า",fly_mode="โหมดบิน",on="เปิดใช้งาน",off="ปิดอยู่",
		speed="ความเร็ว",now="ตอนนี้",lang="ภาษา",theme="สีธีม",hue="ปรับสีเอง",grp_fx="เสียงและเอฟเฟกต์",
		sfx="เสียงเอฟเฟกต์",volume="ระดับเสียง",vfx="เอฟเฟกต์ภาพ",
		ld1="กำลังเตรียมหน้าจอ",ld2="กำลังโหลดเสียง",ld3="กำลังตั้งค่าเอฟเฟกต์",ld4="พร้อมแล้ว!",
		tip1="Space / E เพื่อขึ้น · Q / Ctrl เพื่อลง · หรือใช้ปุ่ม ▲ ▼",
		tip2="เลือกสีที่ชอบได้ในหน้าตั้งค่า",tip3="ลากแถบชื่อเพื่อย้ายหน้าต่าง",
		t_on="เปิดโหมดบินแล้ว",t_off="ปิดโหมดบินแล้ว",t_fail="ไม่พบตัวละคร",
		tab_credit="เครดิต",cr_thanks="ขอบคุณที่ใช้ Xyclop Ultimate",
		grp_ui="หน้าต่าง",float="ปุ่มลอย",
		tip4="ลากมุมขวาล่างเพื่อปรับขนาดหน้าต่าง",
		tip5="แตะปุ่ม X ลอย หรือกด Right Shift เพื่อซ่อน / แสดง",
		tab_home="หน้าหลัก",tab_log="อัปเดต",welcome="ยินดีต้อนรับกลับมา",grp_player="ผู้เล่น",
		grp_server="เซิร์ฟเวอร์",days="วัน",st_health="พลังชีวิต",st_walk="ความเร็วเดิน",
		st_jump="การกระโดด",st_height="ความสูง",st_flyspd="ความเร็วบิน",sv_players="ผู้เล่น",
		sv_uptime="เวลาเซิร์ฟ",sv_ping="ปิง",sv_fps="FPS",sv_mem="หน่วยความจำ",
		sv_place="Place ID",grp_load="หน้าจอโหลด",preview="พรีวิว",tip6="เปลี่ยนสไตล์หน้าโหลดได้ในหน้าตั้งค่า",
		tip7="กดค้างที่ปุ่มลอยเพื่อเปิด Quick Fly",
		qf_hint="แตะไอคอนเพื่อบิน · ลากวงแหวนเพื่อปรับความเร็ว · กดค้างไป Combat",
		qf_hint3="แตะไอคอนเปิด / ปิด ESP · ลากวงแหวนเปลี่ยนสี · กดค้างไป Player",
		qf_hint4="ลากหลอด: ความเร็ว · กระโดด · แรงโน้มถ่วง · แตะเพื่อ เปิด / ปิด · กดค้างเพื่อปิด",
		tab_combat="ต่อสู้",tab_visual="วิชวล",tab_player="ผู้เล่น",tab_misc="อื่นๆ",
		tip8="กดค้างที่ปุ่มลอยซ้ำเพื่อสลับ Combat แล้ว Visual แล้ว Player",
		cb_aim="ล็อคเป้า",cb_lock="ล็อคเป้า",cb_unlock="ปลดล็อค",cb_locked="ล็อคแล้ว",cb_search="กำลังสแกน",cb_ready="พร้อม",
		cb_none="ไม่มีเป้าหมายใน FOV",cb_scan="กำลังสแกน…",
		cb_part="ส่วนของร่างกาย",cb_head="หัว",cb_torso="ลำตัว",cb_root="กลางตัว",cb_feet="เท้า",cb_random="สุ่ม",
		cb_prio="ลำดับเป้าหมาย",cb_pcross="ใกล้เป้ากลางจอ",cb_pnear="ใกล้สุด",cb_pfar="ไกลสุด",
		cb_filters="ตัวกรอง",cb_wall="เช็คกำแพง",cb_team="ไม่สนใจทีมเดียวกัน",cb_auto="เปลี่ยนเป้าเมื่อตาย",
		cb_npc="ล็อค NPC",cb_showfov="แสดงวง FOV",
		cb_fov="FOV",cb_colors="สีวง FOV",cb_cidle="สีปกติ",cb_clock="สีตอนล็อค",
		cb_players="เลือกเป้าหมาย",cb_noplayers="ไม่มีผู้เล่นอื่น",
		vz_sub="มองเห็นผู้เล่นทะลุกำแพง",vz_feat="ฟีเจอร์ ESP",vz_lines="เส้น (Tracer)",vz_box="กรอบฮิตบ็อกซ์",
		vz_hp="หลอดเลือด",vz_name="ชื่อ",vz_color="สี ESP",
		pl_mods="ปรับค่าผู้เล่น",pl_sub="ความเร็ว · กระโดด · แรงโน้มถ่วง",pl_speed="ความเร็วเดิน",pl_jump="แรงกระโดด",pl_grav="แรงโน้มถ่วง",
		pl_reset="รีเซ็ตเป็นค่าเกม",rainbow="ธีมสีรุ้ง",
		ms_sl="ชิฟท์ล็อค",ms_slbtn="ปุ่มชิฟท์ล็อค",ms_pin="ล็อคตำแหน่งปุ่ม",ms_slsize="ขนาดปุ่ม",
		ms_xh="เป้าเล็ง (Crosshair)",ms_xhon="แสดงเป้าเล็ง",ms_xhsl="แสดงตอนเปิดชิฟท์ล็อค",
		ms_style="สไตล์เป้าเล็ง",ms_shape="รูปทรง",ms_size="ขนาด",ms_thick="ความหนา",ms_gap="ช่องว่างกลาง",
		ms_op="ความโปร่งใส",ms_spin="ความเร็วหมุน",ms_color="สีและเอฟเฟกต์",ms_hue="สี",ms_rainbow="สีรุ้งวิ่ง",
		ms_dot="จุดกลาง",ms_outline="ขอบดำ",ms_glow="แสงเรือง",ms_react="ตอบสนองตอนล็อคเป้า",
		ms_util="เครื่องมือ",ms_afk="กันหลุด (Anti AFK)",ms_aex="รันสคริปต์อัตโนมัติ",
		ms_aexhint="วางบรรทัด loadstring (หรือลิงก์สคริปต์) ไว้ครั้งเดียว สคริปต์จะรันซ้ำหลัง Rejoin / ย้ายเซิร์ฟ",
		ms_nosrc="วางบรรทัด loadstring ก่อน",ms_noq="Executor ไม่รองรับ queue_on_teleport",
		ms_servers="เซิร์ฟเวอร์",ms_rejoin="เข้าใหม่",ms_small="คนน้อยสุด",ms_hop="สุ่มเซิร์ฟ",
		ms_list="รายชื่อเซิร์ฟเวอร์",ms_fewest="คนน้อย",ms_most="คนเยอะ",ms_refresh="รีเฟรช",ms_join="เข้า",
		ms_busy="กำลังค้นหา…",ms_nohttp="เชื่อมต่อ Roblox ไม่ได้ (Executor ต้องรองรับ HTTP)",
		ms_nosrv="ไม่พบเซิร์ฟเวอร์ที่เหมาะสม",ms_joining="กำลังย้ายเซิร์ฟเวอร์…",ms_listhint="กดรีเฟรชเพื่อโหลดรายชื่อเซิร์ฟเวอร์",
		qf_hint2="แตะ = ล็อค · ▶▶ = เป้าถัดไป · ลากวง = FOV · กดค้าง = Visual",
		mp_title="เพลง",mp_tracks="เพลง",mp_empty="ไม่พบไฟล์เพลง",
		mp_hint="ใส่ไฟล์ .mp3 / .ogg ไว้ที่ workspace/XyclopXR/Music",
		mp_noapi="Executor นี้เล่นไฟล์ในเครื่องไม่ได้ (ต้องมี listfiles + getcustomasset)",mp_pick="เลือกเพลง",
		tab_atmo="บรรยากาศ",at_fb="Fullbright",at_fbsub="สว่างทั้งแมพ",at_nf="No Fog",
		at_nfsub="ลบหมอกและความมัว",at_str="ความสว่าง",cb_next="ถัดไป",
		log_new="ใหม่"},
	zh={sub="飞行模块",tab_fly="飞行",tab_set="设置",fly_mode="飞行模式",on="已启用",off="已关闭",
		speed="速度",now="当前",lang="语言",theme="主题颜色",hue="自定义色相",grp_fx="声音与特效",
		sfx="音效",volume="音量",vfx="视觉特效",
		ld1="正在准备界面",ld2="正在加载音效",ld3="正在设置特效",ld4="准备就绪！",
		tip1="按 Space / E 上升 · Q / Ctrl 下降 · 或使用 ▲ ▼",
		tip2="可在设置中选择你喜欢的颜色",tip3="拖动标题栏即可移动窗口",
		t_on="飞行已开启",t_off="飞行已关闭",t_fail="未找到角色",
		tab_credit="致谢",cr_thanks="感谢使用 Xyclop Ultimate",
		grp_ui="界面",float="悬浮按钮",
		tip4="拖动右下角即可调整窗口大小",
		tip5="点击悬浮 X 按钮或按右 Shift 以隐藏 / 显示",
		tab_home="主页",tab_log="更新",welcome="欢迎回来",grp_player="玩家",
		grp_server="服务器",days="天",st_health="生命值",st_walk="行走速度",
		st_jump="跳跃",st_height="高度",st_flyspd="飞行速度",sv_players="玩家数",
		sv_uptime="运行时间",sv_ping="延迟",sv_fps="FPS",sv_mem="内存",
		sv_place="地图 ID",grp_load="加载画面",preview="预览",tip6="可在设置中更改加载画面样式",
		log_new="新"},
	ja={sub="飛行モジュール",tab_fly="飛行",tab_set="設定",fly_mode="飛行モード",on="有効",off="無効",
		speed="速度",now="現在",lang="言語",theme="テーマカラー",hue="カスタム色相",grp_fx="サウンドとエフェクト",
		sfx="効果音",volume="音量",vfx="視覚エフェクト",
		ld1="インターフェースを準備中",ld2="サウンドを読み込み中",ld3="エフェクトを設定中",ld4="準備完了！",
		tip1="Space / E で上昇 · Q / Ctrl で下降 · ▲ ▼ ボタンも使えます",
		tip2="設定で好きな色を選べます",tip3="タイトルバーをドラッグしてウィンドウを移動",
		t_on="飛行を有効にしました",t_off="飛行を無効にしました",t_fail="キャラクターが見つかりません",
		tab_credit="クレジット",cr_thanks="Xyclop Ultimate をご利用いただきありがとうございます",
		grp_ui="インターフェース",float="フローティングボタン",
		tip4="右下の角をドラッグしてウィンドウのサイズを変更",
		tip5="フローティング X ボタンか Right Shift で表示 / 非表示",
		tab_home="ホーム",tab_log="更新",welcome="おかえりなさい",grp_player="プレイヤー",
		grp_server="サーバー",days="日",st_health="体力",st_walk="歩行速度",
		st_jump="ジャンプ",st_height="高度",st_flyspd="飛行速度",sv_players="人数",
		sv_uptime="稼働時間",sv_ping="Ping",sv_fps="FPS",sv_mem="メモリ",
		sv_place="Place ID",grp_load="ロード画面",preview="プレビュー",tip6="設定でロード画面のスタイルを変更できます",
		log_new="NEW"},
	ko={sub="비행 모듈",tab_fly="비행",tab_set="설정",fly_mode="비행 모드",on="활성",off="비활성",
		speed="속도",now="현재",lang="언어",theme="테마 색상",hue="사용자 지정 색조",grp_fx="사운드 및 효과",
		sfx="효과음",volume="볼륨",vfx="시각 효과",
		ld1="인터페이스 준비 중",ld2="사운드 불러오는 중",ld3="효과 설정 중",ld4="준비 완료!",
		tip1="Space / E 상승 · Q / Ctrl 하강 · ▲ ▼ 버튼도 사용 가능",
		tip2="설정에서 원하는 색상을 고르세요",tip3="제목 표시줄을 드래그해 창을 이동하세요",
		t_on="비행 켜짐",t_off="비행 꺼짐",t_fail="캐릭터를 찾을 수 없습니다",
		tab_credit="크레딧",cr_thanks="Xyclop Ultimate를 사용해 주셔서 감사합니다",
		grp_ui="인터페이스",float="플로팅 버튼",
		tip4="오른쪽 아래 모서리를 드래그해 창 크기를 조절하세요",
		tip5="플로팅 X 버튼 또는 Right Shift로 숨기기 / 보이기",
		tab_home="홈",tab_log="업데이트",welcome="다시 오신 것을 환영합니다",grp_player="플레이어",
		grp_server="서버",days="일",st_health="체력",st_walk="걷기 속도",
		st_jump="점프",st_height="높이",st_flyspd="비행 속도",sv_players="인원",
		sv_uptime="가동 시간",sv_ping="핑",sv_fps="FPS",sv_mem="메모리",
		sv_place="Place ID",grp_load="로딩 화면",preview="미리보기",tip6="설정에서 로딩 화면 스타일을 바꿀 수 있어요",
		log_new="NEW"},
	es={sub="Módulo de vuelo",tab_fly="Volar",tab_set="Ajustes",fly_mode="Modo vuelo",on="Activo",off="Desactivado",
		speed="Velocidad",now="Actual",lang="Idioma",theme="Color del tema",hue="Tono personalizado",grp_fx="Sonido y efectos",
		sfx="Efectos de sonido",volume="Volumen",vfx="Efectos visuales",
		ld1="Preparando la interfaz",ld2="Cargando sonidos",ld3="Configurando efectos",ld4="¡Listo!",
		tip1="Espacio / E para subir · Q / Ctrl para bajar · o usa ▲ ▼",
		tip2="Elige tus colores en Ajustes",tip3="Arrastra la barra de título para mover la ventana",
		t_on="Vuelo activado",t_off="Vuelo desactivado",t_fail="Personaje no encontrado",
		tab_credit="Créditos",cr_thanks="Gracias por usar Xyclop Ultimate",
		grp_ui="Interfaz",float="Botón flotante",
		tip4="Arrastra la esquina inferior derecha para cambiar el tamaño",
		tip5="Toca el botón X flotante o pulsa Right Shift para ocultar / mostrar",
		tab_home="Inicio",tab_log="Novedades",welcome="Bienvenido de nuevo",grp_player="Jugador",
		grp_server="Servidor",days="días",st_health="Salud",st_walk="Vel. al andar",
		st_jump="Salto",st_height="Altura",st_flyspd="Vel. de vuelo",sv_players="Jugadores",
		sv_uptime="Tiempo activo",sv_ping="Ping",sv_fps="FPS",sv_mem="Memoria",
		sv_place="ID del lugar",grp_load="Pantalla de carga",preview="Vista previa",tip6="Cambia el estilo de la pantalla de carga en Ajustes",
		log_new="NUEVO"},
	pt={sub="Módulo de voo",tab_fly="Voar",tab_set="Config.",fly_mode="Modo de voo",on="Ativo",off="Desativado",
		speed="Velocidade",now="Atual",lang="Idioma",theme="Cor do tema",hue="Matiz personalizada",grp_fx="Som e efeitos",
		sfx="Efeitos sonoros",volume="Volume",vfx="Efeitos visuais",
		ld1="Preparando a interface",ld2="Carregando sons",ld3="Configurando efeitos",ld4="Pronto!",
		tip1="Espaço / E para subir · Q / Ctrl para descer · ou use ▲ ▼",
		tip2="Escolha suas cores em Configurações",tip3="Arraste a barra de título para mover a janela",
		t_on="Voo ativado",t_off="Voo desativado",t_fail="Personagem não encontrado",
		tab_credit="Créditos",cr_thanks="Obrigado por usar o Xyclop Ultimate",
		grp_ui="Interface",float="Botão flutuante",
		tip4="Arraste o canto inferior direito para redimensionar",
		tip5="Toque no botão X flutuante ou pressione Right Shift para ocultar / mostrar",
		tab_home="Início",tab_log="Novidades",welcome="Bem-vindo de volta",grp_player="Jogador",
		grp_server="Servidor",days="dias",st_health="Vida",st_walk="Vel. de caminhada",
		st_jump="Pulo",st_height="Altura",st_flyspd="Vel. de voo",sv_players="Jogadores",
		sv_uptime="Tempo ativo",sv_ping="Ping",sv_fps="FPS",sv_mem="Memória",
		sv_place="ID do local",grp_load="Tela de carregamento",preview="Prévia",tip6="Mude o estilo da tela de carregamento em Configurações",
		log_new="NOVO"},
	ru={sub="Модуль полёта",tab_fly="Полёт",tab_set="Настройки",fly_mode="Режим полёта",on="Включён",off="Выключен",
		speed="Скорость",now="Сейчас",lang="Язык",theme="Цвет темы",hue="Свой оттенок",grp_fx="Звук и эффекты",
		sfx="Звуковые эффекты",volume="Громкость",vfx="Визуальные эффекты",
		ld1="Подготовка интерфейса",ld2="Загрузка звуков",ld3="Настройка эффектов",ld4="Готово!",
		tip1="Space / E — вверх · Q / Ctrl — вниз · или кнопки ▲ ▼",
		tip2="Выберите цвета в настройках",tip3="Перетащите заголовок, чтобы переместить окно",
		t_on="Полёт включён",t_off="Полёт выключен",t_fail="Персонаж не найден",
		tab_credit="Авторы",cr_thanks="Спасибо, что используете Xyclop Ultimate",
		grp_ui="Интерфейс",float="Плавающая кнопка",
		tip4="Потяните правый нижний угол, чтобы изменить размер окна",
		tip5="Нажмите плавающую кнопку X или Right Shift, чтобы скрыть / показать",
		tab_home="Главная",tab_log="Обновления",welcome="С возвращением",grp_player="Игрок",
		grp_server="Сервер",days="дн.",st_health="Здоровье",st_walk="Скор. ходьбы",
		st_jump="Прыжок",st_height="Высота",st_flyspd="Скор. полёта",sv_players="Игроки",
		sv_uptime="Аптайм",sv_ping="Пинг",sv_fps="FPS",sv_mem="Память",
		sv_place="ID места",grp_load="Экран загрузки",preview="Просмотр",tip6="Стиль экрана загрузки меняется в настройках",
		log_new="НОВОЕ"},
	id={sub="Modul terbang",tab_fly="Terbang",tab_set="Pengaturan",fly_mode="Mode terbang",on="Aktif",off="Nonaktif",
		speed="Kecepatan",now="Saat ini",lang="Bahasa",theme="Warna tema",hue="Rona kustom",grp_fx="Suara & efek",
		sfx="Efek suara",volume="Volume",vfx="Efek visual",
		ld1="Menyiapkan antarmuka",ld2="Memuat suara",ld3="Menyiapkan efek",ld4="Siap!",
		tip1="Space / E untuk naik · Q / Ctrl untuk turun · atau pakai ▲ ▼",
		tip2="Pilih warna favoritmu di Pengaturan",tip3="Seret bilah judul untuk memindahkan jendela",
		t_on="Terbang diaktifkan",t_off="Terbang dinonaktifkan",t_fail="Karakter tidak ditemukan",
		tab_credit="Kredit",cr_thanks="Terima kasih telah memakai Xyclop Ultimate",
		grp_ui="Antarmuka",float="Tombol mengambang",
		tip4="Seret sudut kanan bawah untuk mengubah ukuran jendela",
		tip5="Ketuk tombol X mengambang atau tekan Right Shift untuk sembunyikan / tampilkan",
		tab_home="Beranda",tab_log="Pembaruan",welcome="Selamat datang kembali",grp_player="Pemain",
		grp_server="Server",days="hari",st_health="Nyawa",st_walk="Kec. jalan",
		st_jump="Lompat",st_height="Tinggi",st_flyspd="Kec. terbang",sv_players="Pemain",
		sv_uptime="Waktu aktif",sv_ping="Ping",sv_fps="FPS",sv_mem="Memori",
		sv_place="ID tempat",grp_load="Layar muat",preview="Pratinjau",tip6="Ubah gaya layar muat di Pengaturan",
		log_new="BARU"},
	vi={sub="Mô-đun bay",tab_fly="Bay",tab_set="Cài đặt",fly_mode="Chế độ bay",on="Đang bật",off="Đang tắt",
		speed="Tốc độ",now="Hiện tại",lang="Ngôn ngữ",theme="Màu giao diện",hue="Tùy chỉnh sắc độ",grp_fx="Âm thanh & hiệu ứng",
		sfx="Hiệu ứng âm thanh",volume="Âm lượng",vfx="Hiệu ứng hình ảnh",
		ld1="Đang chuẩn bị giao diện",ld2="Đang tải âm thanh",ld3="Đang thiết lập hiệu ứng",ld4="Sẵn sàng!",
		tip1="Space / E để bay lên · Q / Ctrl để hạ xuống · hoặc dùng ▲ ▼",
		tip2="Chọn màu yêu thích trong Cài đặt",tip3="Kéo thanh tiêu đề để di chuyển cửa sổ",
		t_on="Đã bật chế độ bay",t_off="Đã tắt chế độ bay",t_fail="Không tìm thấy nhân vật",
		tab_credit="Tác giả",cr_thanks="Cảm ơn bạn đã sử dụng Xyclop Ultimate",
		grp_ui="Giao diện",float="Nút nổi",
		tip4="Kéo góc dưới bên phải để đổi kích thước cửa sổ",
		tip5="Chạm nút X nổi hoặc nhấn Right Shift để ẩn / hiện",
		tab_home="Trang chủ",tab_log="Cập nhật",welcome="Chào mừng trở lại",grp_player="Người chơi",
		grp_server="Máy chủ",days="ngày",st_health="Máu",st_walk="Tốc độ đi",
		st_jump="Nhảy",st_height="Độ cao",st_flyspd="Tốc độ bay",sv_players="Người chơi",
		sv_uptime="Thời gian chạy",sv_ping="Ping",sv_fps="FPS",sv_mem="Bộ nhớ",
		sv_place="ID bản đồ",grp_load="Màn hình tải",preview="Xem trước",tip6="Đổi kiểu màn hình tải trong Cài đặt",
		log_new="MỚI"},
}

-------------------------------------------------- HELPERS
local function new(class,props,parent)
	local i=Instance.new(class)
	for k,v in pairs(props) do i[k]=v end
	i.Parent=parent
	return i
end
local function tween(i,t,p,s,d)
	local tw=TS:Create(i,TweenInfo.new(t,s or Enum.EasingStyle.Quad,d or Enum.EasingDirection.Out),p)
	tw:Play()
	return tw
end
local function corner(p,r) return new("UICorner",{CornerRadius=UDim.new(0,r)},p) end
local function stroke(p,c,t,tr) return new("UIStroke",{Color=c,Thickness=t,Transparency=tr,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},p) end
local function grad(p,a,b,r) return new("UIGradient",{Color=ColorSequence.new(a,b),Rotation=r or 0},p) end
local function label(props,p)
	props.BackgroundTransparency=1
	props.Font=props.Font or Enum.Font.GothamBold
	props.TextColor3=props.TextColor3 or C.Text
	props.BorderSizePixel=0
	props.TextTruncate=props.TextTruncate or Enum.TextTruncate.AtEnd
	return new("TextLabel",props,p)
end
-- text outline (starts invisible; use fade() to show)
local function tstroke(l,col,th)
	return new("UIStroke",{Color=col,Thickness=th,Transparency=1,ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual,LineJoinMode=Enum.LineJoinMode.Round},l)
end
local function fade(l,t,tt)
	tween(l,t,{TextTransparency=tt})
	local st=l:FindFirstChildOfClass("UIStroke")
	if st then tween(st,t,{Transparency=(tt>=0.99) and 1 or 0.4}) end
end
local function isPress(i) return i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch end
local function isMove(i) return i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch end
local conns={}
local function connect(sig,fn) local c=sig:Connect(fn) table.insert(conns,c) return c end

-------------------------------------------------- STATE
local alive=true
local flying=false
local speed=DEFAULT_SPEED
local lang="en"
local themeIdx=1
local minimized=false
local touchVert=0
local activeTab=1
local revealed=false
local closing=false
local uiVisible=true
local floatOn=true
local uiScale
local S={sfx=true,vfx=true,volume=80}
local loadGui,blurFx,loadConn,runLoader,loaderStyle

-- settings: kept on the Player (same session) and in a json file when the executor has writefile/readfile
local pref,savePref
do -- [S:prefs]
local HttpService=game:GetService("HttpService")
local FILE="XyclopUltimate_settings.json"
local store={}
pcall(function()
	if isfile and readfile and isfile(FILE) then
		local d=HttpService:JSONDecode(readfile(FILE))
		if type(d)=="table" then store=d end
	end
end)
local saveTok=0
function pref(k,d)
	local v=player:GetAttribute("NeonFly_"..k)
	if v==nil then v=store[k] end
	if v==nil then return d end
	return v
end
function savePref(k,v)
	pcall(function() player:SetAttribute("NeonFly_"..k,v) end)
	store[k]=v
	saveTok=saveTok+1
	local tok=saveTok
	task.delay(1,function()
		if tok~=saveTok then return end
		pcall(function()
			if writefile then writefile(FILE,HttpService:JSONEncode(store)) end
		end)
	end)
end
end -- [E:prefs]

S.sfx=pref("sfx",true)
S.vfx=pref("vfx",true)
S.volume=pref("vol",80)
floatOn=pref("float",true)
speed=math.clamp(pref("speed",DEFAULT_SPEED),MIN_SPEED,MAX_SPEED)
loaderStyle=math.clamp(math.floor(tonumber(pref("loader",1)) or 1),1,#LSTYLES)

-- Settings for the tabs below (the engines, pages and quick dials all read these tables)
S.rainbow=pref("rainbow",false)
S.at={fb=pref("atfb",false),nf=pref("atnf",false),str=math.clamp(math.floor(tonumber(pref("atstr",3)) or 3),1,8)}
S.pal={cb1=Color3.fromRGB(255,72,96),cb2=Color3.fromRGB(255,178,64)}
S.cb={lock=false,tgt=nil,blocked=false,dialOpen=false,fovT=0,prevLockT=0,rnd="Head",rndT=0,
	fov=math.clamp(tonumber(pref("cbfov",220)) or 220,30,600),
	part=pref("cbpart","Head"),prio=pref("cbprio","Cross"),
	wall=pref("cbwall",true),team=pref("cbteam",true),auto=pref("cbauto",true),
	npc=pref("cbnpc",false),showFov=pref("cbshow",true),
	h1=math.floor(tonumber(pref("cbh1",351)) or 351)%360,h2=math.floor(tonumber(pref("cbh2",354)) or 354)%360}
if not ({Head=1,Torso=1,Root=1,Feet=1,Random=1})[S.cb.part] then S.cb.part="Head" end
if not ({Cross=1,Near=1,Far=1})[S.cb.prio] then S.cb.prio="Cross" end
S.vz={on=false,tOn=0,lines=pref("vzlines",true),box=pref("vzbox",true),hp=pref("vzhp",true),
	name=pref("vzname",true),hue=math.floor(tonumber(pref("vzhue",200)) or 200)%360}
S.pl={on=pref("plon",true),defS=16,defJ=50,defG=196.2,
	lo={speed=8,jump=10,grav=10},hi={speed=250,jump=300,grav=400},
	speed=math.clamp(math.floor((tonumber(pref("plspeed",16)) or 16)+0.5),8,250),
	jump=math.clamp(math.floor((tonumber(pref("pljump",50)) or 50)+0.5),10,300),
	grav=math.clamp(tonumber(pref("plgrav",196.2)) or 196.2,10,400)}
S.ms={sl=pref("mssl",false),slOn=false,slLock=pref("mslock",false),slOff=1.75,
	slSize=math.clamp(math.floor(tonumber(pref("mssize",58)) or 58),36,120),
	slX=tonumber(pref("mslx",-1)) or -1,slY=tonumber(pref("msly",-1)) or -1,
	afk=pref("msafk",true),aex=pref("msaex",false),asrc=tostring(pref("msasrc",""))}
S.xh={on=pref("xhon",false),withSl=pref("xhsl",true),
	style=math.clamp(math.floor(tonumber(pref("xhstyle",1)) or 1),1,7),
	hue=math.floor(tonumber(pref("xhhue",170)) or 170)%360,rainbow=pref("xhrb",false),
	size=math.clamp(math.floor(tonumber(pref("xhsize",64)) or 64),16,200),
	thick=math.clamp(math.floor(tonumber(pref("xhthick",2)) or 2),1,8),
	gap=math.clamp(math.floor(tonumber(pref("xhgap",8)) or 8),0,60),
	op=math.clamp(math.floor(tonumber(pref("xhop",100)) or 100),20,100),
	spin=math.clamp(math.floor(tonumber(pref("xhspin",0)) or 0),0,240),
	dot=pref("xhdot",true),outline=pref("xhout",true),glow=pref("xhglow",true),react=pref("xhreact",true)}

-------------------------------------------------- THEME SYSTEM
local T={A1=THEMES[1][2],A2=THEMES[1][3]}
local themed={}
local function onTheme(fn) table.insert(themed,fn) fn() end
local function applyTheme() for _,fn in ipairs(themed) do fn() end end
local function tgrad(p,rot)
	local g=new("UIGradient",{Rotation=rot or 0},p)
	onTheme(function() g.Color=ColorSequence.new(T.A1,T.A2) end)
	return g
end
local function hueColors(h)
	return Color3.fromHSV((h%360)/360,0.85,1),Color3.fromHSV(((h+55)%360)/360,0.8,1)
end
local themeTok=0
local function setTheme(a1,a2,instant)
	themeTok=themeTok+1
	local tok=themeTok
	if instant then
		T.A1,T.A2=a1,a2
		applyTheme()
		return
	end
	local f1,f2=T.A1,T.A2
	task.spawn(function()
		local t0=os.clock()
		repeat
			local a=math.clamp((os.clock()-t0)/0.4,0,1)
			local e=a*a*(3-2*a)
			T.A1=f1:Lerp(a1,e)
			T.A2=f2:Lerp(a2,e)
			applyTheme()
			if a>=1 then break end
			RunService.RenderStepped:Wait()
		until tok~=themeTok or not alive
	end)
end

themeIdx=pref("theme",1)
if themeIdx>=1 and THEMES[themeIdx] then
	T.A1,T.A2=THEMES[themeIdx][2],THEMES[themeIdx][3]
else
	themeIdx=0
	T.A1,T.A2=hueColors(pref("hue",190))
end

-------------------------------------------------- LANGUAGE SYSTEM
local langFns,boundLbls={},{}
local function tr(k)
	local t=L[lang]
	return (t and t[k]) or L.en[k] or k
end
local function onLang(fn) table.insert(langFns,fn) fn() end
local function bindText(lbl,k)
	table.insert(boundLbls,lbl)
	onLang(function() lbl.Text=tr(k) end)
	return lbl
end
local function applyLang(pulse)
	for _,fn in ipairs(langFns) do fn() end
	if pulse then
		for _,l in ipairs(boundLbls) do
			l.TextTransparency=1
			tween(l,0.3,{TextTransparency=0})
		end
	end
end

lang=pref("lang",nil)
if not lang then
	local ok,loc=pcall(function() return LocService.RobloxLocaleId end)
	local code="en"
	if ok and type(loc)=="string" then code=loc:lower():sub(1,2) end
	lang="en"
	for _,lg in ipairs(LANGS) do
		if lg.code==code then lang=lg.code end
	end
end

-------------------------------------------------- ROOT GUI + SOUNDS
local gui=new("ScreenGui",{Name="NeonFlyGui",ResetOnSpawn=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,IgnoreGuiInset=true,DisplayOrder=100},playerGui)

local sounds={}
for name,id in pairs(SFX_IDS) do
	sounds[name]=new("Sound",{Name=name,SoundId=id,Volume=0.5},gui)
end
local lastSfx={}
local function sfx(name,vol,pitch)
	if not S.sfx or not alive then return end
	local tpl=sounds[name]
	if not tpl then return end
	local now=os.clock()
	if lastSfx[name] and now-lastSfx[name]<0.04 then return end
	lastSfx[name]=now
	local s=tpl:Clone()
	s.Volume=(vol or 0.5)*(S.volume/100)
	s.PlaybackSpeed=pitch or 1
	s.Parent=gui
	s:Play()
	Debris:AddItem(s,4)
end

-- screen-edge energy glow (shows while flying fast)
local rim={}
local function rimEdge(pos,size,rot)
	local f=new("Frame",{Position=pos,Size=size,BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0,Visible=false,ZIndex=1},gui)
	local g=new("UIGradient",{Rotation=rot,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.4),NumberSequenceKeypoint.new(1,1)})},f)
	onTheme(function() g.Color=ColorSequence.new(T.A1,T.A2) end)
	table.insert(rim,f)
end
rimEdge(UDim2.fromScale(0,0),UDim2.new(1,0,0.22,0),90)
rimEdge(UDim2.fromScale(0,0.78),UDim2.new(1,0,0.22,0),270)
rimEdge(UDim2.fromScale(0,0),UDim2.new(0.12,0,1,0),0)
rimEdge(UDim2.fromScale(0.88,0),UDim2.new(0.12,0,1,0),180)

-------------------------------------------------- UI FACTORIES
local function makeSwitch(parent,pos,init)
	local sw=new("Frame",{Size=UDim2.fromOffset(52,28),AnchorPoint=Vector2.new(1,0.5),Position=pos,BackgroundColor3=C.Off,BorderSizePixel=0},parent)
	corner(sw,999)
	local fillF=new("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0},sw)
	corner(fillF,999) tgrad(fillF,0)
	local knob=new("Frame",{Size=UDim2.fromOffset(22,22),AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,3,0.5,0),BackgroundColor3=C.White,BorderSizePixel=0},sw)
	corner(knob,999)
	local obj={}
	function obj.set(on,instant)
		local tp=on and 0 or 1
		local kp=on and UDim2.new(1,-25,0.5,0) or UDim2.new(0,3,0.5,0)
		if instant then
			fillF.BackgroundTransparency=tp
			knob.Position=kp
		else
			tween(fillF,0.2,{BackgroundTransparency=tp})
			tween(knob,0.25,{Position=kp},Enum.EasingStyle.Back)
		end
	end
	obj.set(init,true)
	return obj
end

local function makeSlider(o)
	local track=new("Frame",{Position=UDim2.fromOffset(o.x,o.y),Size=UDim2.fromOffset(o.width,6),AnchorPoint=Vector2.new(0,0.5),BackgroundColor3=C.White,BackgroundTransparency=0.88,BorderSizePixel=0},o.parent)
	corner(track,999)
	local fill
	if o.rainbow then
		track.BackgroundTransparency=0
		local keys={}
		for n=0,6 do
			table.insert(keys,ColorSequenceKeypoint.new(n/6,Color3.fromHSV(n/6,0.85,1)))
		end
		new("UIGradient",{Color=ColorSequence.new(keys)},track)
	else
		fill=new("Frame",{Size=UDim2.fromScale(0,1),BackgroundColor3=C.White,BorderSizePixel=0},track)
		corner(fill,999) tgrad(fill,0)
	end
	local knob=new("Frame",{Size=UDim2.fromOffset(18,18),AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0,0.5),BackgroundColor3=C.White,BorderSizePixel=0},track)
	corner(knob,999)
	local ks=stroke(knob,C.White,2,0)
	onTheme(function() ks.Color=T.A1 end)
	local hit=new("TextButton",{Position=UDim2.fromOffset(o.x-10,o.y-17),Size=UDim2.fromOffset(o.width+20,34),BackgroundTransparency=1,Text="",AutoButtonColor=false},o.parent)

	local value=nil
	local function setValue(v,silent)
		v=math.clamp(math.floor(v+0.5),o.min,o.max)
		local a=(v-o.min)/(o.max-o.min)
		if fill then fill.Size=UDim2.fromScale(a,1) end
		knob.Position=UDim2.fromScale(a,0.5)
		local changed=(v~=value)
		value=v
		if changed and not silent and o.onChange then o.onChange(v,a) end
	end
	local sliding=false
	local function slideTo(x)
		local a=math.clamp((x-track.AbsolutePosition.X)/math.max(track.AbsoluteSize.X,1),0,1)
		setValue(o.min+a*(o.max-o.min))
	end
	setValue(o.value,true)
	hit.InputBegan:Connect(function(i)
		if isPress(i) then
			sliding=true
			if o.scroller then o.scroller.ScrollingEnabled=false end
			slideTo(i.Position.X)
			tween(knob,0.12,{Size=UDim2.fromOffset(22,22)})
		end
	end)
	connect(UIS.InputChanged,function(i)
		if sliding and isMove(i) then slideTo(i.Position.X) end
	end)
	connect(UIS.InputEnded,function(i)
		if sliding and isPress(i) then
			sliding=false
			if o.scroller then o.scroller.ScrollingEnabled=true end
			tween(knob,0.12,{Size=UDim2.fromOffset(18,18)})
		end
	end)
	return {set=setValue}
end

local function card(parent,h,y,order)
	local f=new("Frame",{Size=UDim2.fromOffset(W-24,h),BackgroundColor3=C.White,BackgroundTransparency=0.95,BorderSizePixel=0,LayoutOrder=order or 0},parent)
	if y then f.Position=UDim2.fromOffset(12,y) end
	corner(f,12) stroke(f,C.White,1,0.92)
	return f
end

-- ripple (aware of the window's UI scale)
local function ripple(btn,i)
	local sc=(uiScale and uiScale.Scale) or 1
	local lw=btn.AbsoluteSize.X/sc
	local lh=btn.AbsoluteSize.Y/sc
	local rx=math.clamp((i.Position.X-btn.AbsolutePosition.X)/sc,0,lw)
	local r=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromOffset(rx,lh/2),Size=UDim2.fromOffset(0,0),BackgroundColor3=C.White,BackgroundTransparency=0.78,BorderSizePixel=0,ZIndex=3},btn)
	corner(r,999)
	local d=lw*1.6+20
	tween(r,0.55,{Size=UDim2.fromOffset(d,d),BackgroundTransparency=1})
	Debris:AddItem(r,0.6)
end

-- palette gradient: fixed colors when pal is given, otherwise follows the theme
local function pg(p,rot,pal)
	if pal then
		return new("UIGradient",{Color=ColorSequence.new(pal.a1,pal.a2),Rotation=rot or 0},p)
	end
	return tgrad(p,rot)
end

-- Stylized "X" mark (parent must be square).
-- mode "ink"  = dark X for gradient badges, "neon" = gradient X with white slashes
local function makeXMark(parent,mode,pal)
	local holder=new("Frame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0},parent)
	local parts={}
	local function bar(len,th,cx,cy,rot,themedBar)
		local f=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(cx,cy),Size=UDim2.fromScale(len,th),Rotation=rot,BackgroundColor3=(mode=="ink") and C.Ink or C.White,BorderSizePixel=0},holder)
		new("UICorner",{CornerRadius=UDim.new(0.5,0)},f)
		if mode=="neon" and themedBar then pg(f,0,pal) end
		table.insert(parts,{f=f,size=f.Size})
		return f
	end
	bar(1.0,0.17,0.5,0.5,45,true)
	bar(0.36,0.17,0.712,0.288,-45,false)
	bar(0.36,0.17,0.288,0.712,-45,false)
	return holder,parts
end

-- Letter-by-letter text row (for animated title reveals)
local function makeLetters(parent,text,size,font,y,gap,colorFn,width,strokeCol,fixed)
	local holder=new("Frame",{AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0,y),Size=UDim2.fromOffset(width,size+10),BackgroundTransparency=1,BorderSizePixel=0},parent)
	new("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,HorizontalAlignment=Enum.HorizontalAlignment.Center,VerticalAlignment=Enum.VerticalAlignment.Center,Padding=UDim.new(0,gap),SortOrder=Enum.SortOrder.LayoutOrder},holder)
	local list={}
	local n=#text
	for i=1,n do
		local ch=text:sub(i,i)
		local ok,ts=pcall(function() return TextService:GetTextSize(ch,size,font,Vector2.new(1000,1000)) end)
		local w=(ok and ts.X or size*0.7)+2
		local cell=new("Frame",{LayoutOrder=i,Size=UDim2.fromOffset(w,size+10),BackgroundTransparency=1,BorderSizePixel=0},holder)
		local l=label({Size=UDim2.fromScale(1,1),Position=UDim2.fromOffset(0,16),Text=ch,TextSize=size,Font=font,TextTransparency=1,TextTruncate=Enum.TextTruncate.None},cell)
		if strokeCol then tstroke(l,strokeCol,math.max(1.5,size/14)) end
		if fixed then
			l.TextColor3=colorFn(i,n)
		else
			onTheme(function() l.TextColor3=colorFn(i,n) end)
		end
		table.insert(list,l)
	end
	return list
end

local function shimmerLetters(list,colorFn,flash)
	local n=#list
	for i,l in ipairs(list) do
		task.delay((i-1)*0.05,function()
			if not alive or not l.Parent then return end
			tween(l,0.14,{TextColor3=flash or C.White})
			task.delay(0.16,function()
				if alive and l.Parent then tween(l,0.4,{TextColor3=colorFn(i,n)}) end
			end)
		end)
	end
end

local function shockwave(parent,pos,s0,s1,thick,dur,delay,pal,t0)
	task.delay(delay or 0,function()
		if not alive or not parent.Parent then return end
		local r=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=pos,Size=UDim2.fromOffset(s0,s0),BackgroundTransparency=1,BorderSizePixel=0},parent)
		corner(r,999)
		local s=stroke(r,pal and pal.a1 or T.A1,thick,t0 or 0.05)
		tween(r,dur,{Size=UDim2.fromOffset(s1,s1)},Enum.EasingStyle.Quint)
		tween(s,dur,{Transparency=1})
		Debris:AddItem(r,dur+0.1)
	end)
end

local function burst(parent,pos,count,pal,dist)
	local rnd=Random.new()
	for n=1,count do
		local a=math.rad((n-1)*360/count+rnd:NextNumber(-8,8))
		local sz=rnd:NextInteger(3,7)
		local p=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=pos,Size=UDim2.fromOffset(sz,sz),BackgroundColor3=(n%2==0) and pal.a1 or pal.a2,BorderSizePixel=0,ZIndex=40},parent)
		corner(p,999)
		local d=dist*rnd:NextNumber(0.55,1.1)
		tween(p,0.9,{Position=pos+UDim2.fromOffset(math.sin(a)*d,-math.cos(a)*d),BackgroundTransparency=1},Enum.EasingStyle.Quint)
		Debris:AddItem(p,1)
	end
end

-- Animated emblem: glow + spinning arcs + orbiting dots + X mark.
-- pal = fixed palette (loader). nil = follows the theme.
local function makeEmblem(parent,D,pos,pal)
	local E={tok=0}
	local thick=math.max(1.5,D/70)
	local root=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=pos,Size=UDim2.fromOffset(D+8,D+8),BackgroundTransparency=1,BorderSizePixel=0},parent)
	E.root=root

	local function glow(d)
		local g=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(d,d),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0},root)
		corner(g,999) pg(g,45,pal)
		return g
	end
	E.glow1=glow(D*0.74)
	E.glow2=glow(D*0.52)

	if pal then
		E.plate=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(D*0.58,D*0.58),BackgroundColor3=pal.deep,BackgroundTransparency=1,BorderSizePixel=0},root)
		corner(E.plate,999)
		E.plateStroke=stroke(E.plate,C.White,2,1)
	end

	local function ring(d,th,trans,arc)
		local r=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(0,0),BackgroundTransparency=1,BorderSizePixel=0},root)
		corner(r,999)
		local s=stroke(r,C.White,th,trans)
		local g
		if arc then
			g=new("UIGradient",{Transparency=arc},s)
			if pal then
				g.Color=ColorSequence.new(pal.a1,pal.a2)
			else
				onTheme(function() g.Color=ColorSequence.new(T.A1,T.A2) end)
			end
		end
		return {f=r,s=s,g=g,d=d}
	end
	E.r1=ring(D,thick,0,NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(0.4,1),NumberSequenceKeypoint.new(1,1)}))
	E.r2=ring(D*0.8,thick*0.75,0,NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(0.6,1),NumberSequenceKeypoint.new(1,1)}))
	E.r3=ring(D*0.6,math.max(1,thick*0.5),0.82,nil)

	local function orbit(d,count,dsz)
		local o=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(d,d),BackgroundTransparency=1,BorderSizePixel=0},root)
		local dots={}
		for k=0,count-1 do
			local a=math.rad(k*360/count)
			local dt=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5+0.5*math.sin(a),0.5-0.5*math.cos(a)),Size=UDim2.fromOffset(dsz,dsz),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0},o)
			corner(dt,999) pg(dt,45,pal)
			table.insert(dots,dt)
		end
		return o,dots
	end
	local o1,d1=orbit(D,3,math.max(4,D/28))
	local o2,d2=orbit(D*0.8,2,math.max(3,D/40))
	E.orb1,E.orb2=o1,o2
	E.dots={}
	for _,x in ipairs(d1) do table.insert(E.dots,x) end
	for _,x in ipairs(d2) do table.insert(E.dots,x) end

	local xd=D*0.44
	local xh=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(xd,xd),BackgroundTransparency=1,BorderSizePixel=0},root)
	local _,xparts=makeXMark(xh,"neon",pal)
	E.xh,E.xparts=xh,xparts

	function E.update(t)
		E.r1.g.Rotation=(t*230)%360
		E.r2.g.Rotation=(-t*170)%360
		E.orb1.Rotation=(-t*70)%360
		E.orb2.Rotation=(t*110)%360
		local p=math.sin(t*2.4)
		local g1=D*0.74*(1+0.04*p)
		local g2=D*0.52*(1-0.05*p)
		E.glow1.Size=UDim2.fromOffset(g1,g1)
		E.glow2.Size=UDim2.fromOffset(g2,g2)
		local s=xd*(1+0.025*p)
		E.xh.Size=UDim2.fromOffset(s,s)
	end

	function E.reset()
		E.tok=E.tok+1
		for _,r in ipairs({E.r1,E.r2,E.r3}) do r.f.Size=UDim2.fromOffset(0,0) end
		for _,p in ipairs(E.xparts) do p.f.Size=UDim2.fromScale(0,p.size.Y.Scale) end
		E.xh.Rotation=-90
		E.glow1.BackgroundTransparency=1
		E.glow2.BackgroundTransparency=1
		if E.plate then
			E.plate.BackgroundTransparency=1
			E.plateStroke.Transparency=1
		end
		for _,d in ipairs(E.dots) do d.BackgroundTransparency=1 end
	end

	function E.intro()
		local tok=E.tok
		local function live() return alive and tok==E.tok and root.Parent~=nil end
		for i,r in ipairs({E.r1,E.r2,E.r3}) do
			task.delay((i-1)*0.1,function()
				if live() then tween(r.f,0.9,{Size=UDim2.fromOffset(r.d,r.d)},Enum.EasingStyle.Back) end
			end)
		end
		task.delay(0.3,function()
			if not live() then return end
			for i,p in ipairs(E.xparts) do
				task.delay((i-1)*0.07,function()
					if live() then tween(p.f,0.5,{Size=p.size},Enum.EasingStyle.Back) end
				end)
			end
			tween(E.xh,0.8,{Rotation=0},Enum.EasingStyle.Back)
			tween(E.glow1,0.7,{BackgroundTransparency=pal and 0.86 or 0.9})
			tween(E.glow2,0.7,{BackgroundTransparency=pal and 0.74 or 0.8})
			if E.plate then
				tween(E.plate,0.7,{BackgroundTransparency=0.45})
				tween(E.plateStroke,0.7,{Transparency=0.55})
			end
			for _,d in ipairs(E.dots) do tween(d,0.5,{BackgroundTransparency=0}) end
		end)
	end

	E.reset()
	return E
end

-------------------------------------------------- WINDOW
local function screenSize()
	local s=gui.AbsoluteSize
	if s.X<50 or s.Y<50 then
		local cam=workspace.CurrentCamera
		s=cam and cam.ViewportSize or Vector2.new(1280,720)
	end
	return s
end
local sz0=screenSize()

local startScale=pref("scale",nil)
if type(startScale)~="number" then
	startScale=math.min(1,(sz0.Y-24)/H_OPEN,(sz0.X-16)/W)
end
startScale=math.clamp(startScale,MIN_SCALE,MAX_SCALE)

-- anchor = invisible point that holds the window position (moved by dragging)
local anchor=new("Frame",{
	Name="WindowAnchor",Size=UDim2.fromOffset(0,0),
	Position=UDim2.fromOffset(math.max(0,math.floor((sz0.X-W*startScale)/2)),math.floor(sz0.Y*0.12)),
	BackgroundTransparency=1,BorderSizePixel=0,Visible=false,ZIndex=5},gui)
-- main = frame + border + background (UIScale lives here)
local main=new("Frame",{
	Name="Window",Size=UDim2.fromOffset(W,0),Position=UDim2.fromOffset(0,0),
	BackgroundColor3=C.White,BackgroundTransparency=0.04,BorderSizePixel=0,Active=true},anchor)
uiScale=new("UIScale",{Scale=startScale},main)
corner(main,18)
grad(main,Color3.fromRGB(26,28,48),Color3.fromRGB(10,11,19),90)
local mainStroke=stroke(main,C.White,1.5,0.35)
local strokeGrad=new("UIGradient",{},mainStroke)
onTheme(function()
	strokeGrad.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,T.A1),ColorSequenceKeypoint.new(0.5,T.A2),ColorSequenceKeypoint.new(1,T.A1)})
end)
-- win = rounded clipping layer: everything inside is cut to the rounded corners (fixes the bottom edge)
local win=new("CanvasGroup",{Name="Clip",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0,Active=true},main)
corner(win,18)

-- soft theme aura at the top
local aura=new("Frame",{Size=UDim2.new(1,0,0,90),BackgroundColor3=C.White,BorderSizePixel=0,ZIndex=1},win)
corner(aura,18)
local auraG=tgrad(aura,90)
auraG.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.8),NumberSequenceKeypoint.new(1,1)})

-- floating sparkles in the window background
local bgFx=new("Frame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=1},win)
for n=1,7 do
	task.spawn(function()
		local rnd=Random.new(n*31+7)
		local sz=rnd:NextInteger(2,5)
		local d=new("Frame",{Size=UDim2.fromOffset(sz,sz),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0},bgFx)
		corner(d,999) tgrad(d,0)
		task.wait(rnd:NextNumber(0,3))
		while alive and d.Parent do
			local x=rnd:NextNumber(0.05,0.95)
			local dur=rnd:NextNumber(5,9)
			d.Position=UDim2.fromScale(x,1.02)
			d.BackgroundTransparency=1
			tween(d,dur,{Position=UDim2.fromScale(x+rnd:NextNumber(-0.06,0.06),-0.02)},Enum.EasingStyle.Linear)
			tween(d,dur*0.25,{BackgroundTransparency=rnd:NextNumber(0.55,0.8)})
			task.wait(dur*0.75)
			tween(d,dur*0.25,{BackgroundTransparency=1})
			task.wait(dur*0.25)
		end
	end)
end

-- title bar
local titleBar=new("Frame",{Size=UDim2.new(1,0,0,H_MIN),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=2},win)
local dragArea=new("Frame",{Size=UDim2.new(1,-84,1,0),BackgroundTransparency=1,BorderSizePixel=0,Active=true},titleBar)
local logo=new("Frame",{Size=UDim2.fromOffset(28,28),Position=UDim2.new(0,12,0.5,0),AnchorPoint=Vector2.new(0,0.5),BackgroundColor3=C.White,BorderSizePixel=0},titleBar)
corner(logo,9) tgrad(logo,45)
makeXMark(logo,"ink")
local title=label({Position=UDim2.fromOffset(48,5),Size=UDim2.fromOffset(210,18),Text="Xyclop Ultimate",TextSize=15,Font=Enum.Font.GothamBlack,TextColor3=C.White,TextXAlignment=Enum.TextXAlignment.Left},titleBar)
tgrad(title,0)
bindText(label({Position=UDim2.fromOffset(48,23),Size=UDim2.fromOffset(170,14),Text="",TextSize=10,Font=Enum.Font.Gotham,TextColor3=C.Muted,TextXAlignment=Enum.TextXAlignment.Left},titleBar),"sub")

local function iconBtn(x)
	local b=new("TextButton",{Size=UDim2.fromOffset(26,26),AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,x,0.5,0),BackgroundColor3=C.White,BackgroundTransparency=0.92,Text="",AutoButtonColor=false,BorderSizePixel=0},titleBar)
	corner(b,8)
	return b
end
local function bar(p,w,h,rot)
	local f=new("Frame",{Size=UDim2.fromOffset(w,h),AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Rotation=rot or 0,BackgroundColor3=C.Text,BorderSizePixel=0},p)
	corner(f,2)
	return f
end
local function hover(b,col,trn)
	b.MouseEnter:Connect(function()
		tween(b,0.15,{BackgroundColor3=col,BackgroundTransparency=trn})
		if UIS.MouseEnabled then sfx("tick",0.1,1.8) end
	end)
	b.MouseLeave:Connect(function() tween(b,0.15,{BackgroundColor3=C.White,BackgroundTransparency=0.92}) end)
end
local minBtn=iconBtn(-44)
bar(minBtn,10,2)
local plusBar=bar(minBtn,10,2,90) plusBar.BackgroundTransparency=1
hover(minBtn,C.White,0.8)
local closeBtn=iconBtn(-12)
bar(closeBtn,12,2,45) bar(closeBtn,12,2,-45)
hover(closeBtn,C.Danger,0.15)

local divider=new("Frame",{Position=UDim2.fromOffset(0,H_MIN),Size=UDim2.new(1,0,0,1),BackgroundColor3=C.White,BackgroundTransparency=0.9,BorderSizePixel=0,ZIndex=2},win)

-- toast  (block-scoped: only `toast` is needed outside)
local toast
do -- [S:toast]
local TOAST_Y=H_OPEN-TAB_H-8
local toastF=new("Frame",{AnchorPoint=Vector2.new(0.5,1),Position=UDim2.new(0.5,0,0,TOAST_Y+30),Size=UDim2.fromOffset(250,30),BackgroundColor3=C.Ink,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=20},win)
corner(toastF,15)
local toastStroke=stroke(toastF,C.White,1.2,1)
onTheme(function() toastStroke.Color=T.A1 end)
local toastLbl=label({Size=UDim2.fromScale(1,1),Text="",TextSize=12,TextTransparency=1},toastF)
local toastTok=0
function toast(text)
	toastTok=toastTok+1
	local tok=toastTok
	toastLbl.Text=text
	toastF.Position=UDim2.new(0.5,0,0,TOAST_Y+14)
	tween(toastF,0.35,{Position=UDim2.new(0.5,0,0,TOAST_Y),BackgroundTransparency=0.05},Enum.EasingStyle.Back)
	tween(toastLbl,0.2,{TextTransparency=0})
	tween(toastStroke,0.2,{Transparency=0.4})
	task.delay(1.9,function()
		if tok~=toastTok or not alive then return end
		tween(toastF,0.3,{Position=UDim2.new(0.5,0,0,TOAST_Y+14),BackgroundTransparency=1})
		tween(toastLbl,0.25,{TextTransparency=1})
		tween(toastStroke,0.25,{Transparency=1})
	end)
end
end -- [E:toast]

-------------------------------------------------- FLOATING BUTTON + QUICK DIALS (Fly / Combat / Visual) + SHOW/HIDE
-- (block-scoped: only fb, fbScale, fbGrad, fbDot and setFloat are needed outside)
local fb,fbScale,fbGrad,fbDot,setFloat
do -- [S:float]
fb=new("Frame",{
	Name="FloatButton",AnchorPoint=Vector2.new(0.5,0.5),Size=UDim2.fromOffset(52,52),
	Position=UDim2.fromOffset(math.max(40,sz0.X-46),math.floor(sz0.Y*0.4)),
	BackgroundColor3=C.White,BorderSizePixel=0,Visible=false,ZIndex=60},gui)
fbScale=new("UIScale",{Scale=0},fb)
corner(fb,26)
grad(fb,Color3.fromRGB(32,35,60),Color3.fromRGB(12,13,22),90)
local fbStroke=stroke(fb,C.White,2.2,0.05)
fbGrad=new("UIGradient",{},fbStroke)
onTheme(function()
	fbGrad.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,T.A1),ColorSequenceKeypoint.new(0.5,T.A2),ColorSequenceKeypoint.new(1,T.A1)})
end)
local fbX=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(26,26),BackgroundTransparency=1,BorderSizePixel=0},fb)
makeXMark(fbX,"neon")
fbDot=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(1,-6,0,6),Size=UDim2.fromOffset(12,12),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=3},fb)
corner(fbDot,999) tgrad(fbDot,45)
local fbBtn=new("TextButton",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Text="",AutoButtonColor=false,ZIndex=4},fb)

------------------------------------------------ QUICK DIALS: shared state
-- Hold the button to cycle:   closed -> FLY -> COMBAT -> VISUAL -> PLAYER -> closed
-- Each dial is a table Q.D[m] = {root,scale,gapDir,gapHalf,frame,open,close,tap,ring,getF}
--   FLY    (m=1): segmented bar ring            -> speed        (theme colors)
--   COMBAT (m=2): scope bezel + lock brackets    -> FOV radius   (crimson / amber)
--   VISUAL (m=3): rainbow bead ring              -> ESP color    (hue wheel)
--   PLAYER (m=4): three liquid tubes             -> speed / jump / gravity
-- Angles are degrees measured from the top, clockwise.
local Q={mode=0,open=false,tok=0,hTok=0,hs=0,charging=false,shown=false,cl={},cn=-1,
	rg=false,grab=false,lastF=0,D={}}
local HOLD,NC=0.38,28
local function backE(x) -- easeOutBack
	x=x-1
	return 1+2.70158*x*x*x+1.70158*x*x
end
local function restScale() return Q.open and 1.14 or 1 end

-- keeps the button (and the whole dial around it) on screen
function Q.clampFb(x,y)
	local s=screenSize()
	if Q.open then
		return math.clamp(x,math.min(122,s.X/2),math.max(s.X-122,s.X/2)),
			math.clamp(y,math.min(104,s.Y/2),math.max(s.Y-150,s.Y/2))
	end
	return math.clamp(x,26,math.max(26,s.X-26)),math.clamp(y,26,math.max(26,s.Y-26))
end

-- palette of a mode (used for shockwaves, particles, charge ring)
function Q.pal(m)
	if m==2 then
		local a,b=S.pal.cb1,S.pal.cb2
		if S.cbCols then a,b=S.cbCols() end
		return {a1=a,a2=b}
	end
	if m==4 then return {a1=Color3.fromRGB(90,200,255),a2=Color3.fromRGB(120,255,150)} end
	if m==3 then
		local h=S.vz.hue
		return {a1=Color3.fromHSV(h/360,0.8,1),a2=Color3.fromHSV(((h+60)%360)/360,0.8,1)}
	end
	return {a1=T.A1,a2=T.A2}
end

------------------------------------------------ shared: charge ring, hint, ring input, mode switching
do -- [dial-shared]
-- chg = charge ring + shockwaves + particles + hint (always centered on the button)
local chg=new("Frame",{Name="QuickCharge",AnchorPoint=Vector2.new(0.5,0.5),Size=UDim2.fromOffset(120,120),Position=fb.Position,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=59},gui)
Q.chg=chg

local chgDots,chgG={},{}
for k=1,NC do
	local rot=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(2,2),Rotation=(k-1)/NC*360,BackgroundTransparency=1,BorderSizePixel=0},chg)
	local d=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,-40),Size=UDim2.fromOffset(4,4),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0},rot)
	corner(d,999)
	chgG[k]=new("UIGradient",{Color=ColorSequence.new(T.A1,T.A2),Rotation=45},d)
	chgDots[k]=d
end
local chgGlow=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(60,60),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=0},chg)
corner(chgGlow,999)
local chgGlowG=new("UIGradient",{Color=ColorSequence.new(T.A1,T.A2),Rotation=45},chgGlow)

-- the charge ring is tinted with the palette of the dial that is about to open
function Q.setChgPal(m)
	if m==0 then
		for k=1,NC do chgG[k].Color=ColorSequence.new(C.Text,C.Muted) end
		chgGlowG.Color=ColorSequence.new(C.Text,C.Muted)
	elseif m==3 then
		for k=1,NC do
			local c=Color3.fromHSV((k-1)/NC,0.85,1)
			chgG[k].Color=ColorSequence.new(c,c)
		end
		local h=S.vz.hue/360
		chgGlowG.Color=ColorSequence.new(Color3.fromHSV(h,0.8,1),Color3.fromHSV((h+0.15)%1,0.8,1))
	elseif m==4 then
		local cc={Color3.fromRGB(90,200,255),Color3.fromRGB(120,255,150),Color3.fromRGB(190,130,255)}
		for k=1,NC do
			local c=cc[k%3+1]
			chgG[k].Color=ColorSequence.new(c,c)
		end
		chgGlowG.Color=ColorSequence.new(cc[1],cc[3])
	else
		local p=Q.pal(m)
		for k=1,NC do chgG[k].Color=ColorSequence.new(p.a1,p.a2) end
		chgGlowG.Color=ColorSequence.new(p.a1,p.a2)
	end
end

-- hint pill under the dial
local hint=new("Frame",{AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0.5,106),Size=UDim2.fromOffset(240,34),BackgroundColor3=C.Ink,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=7},chg)
corner(hint,12)
local hintS=stroke(hint,C.White,1.2,1)
onTheme(function() hintS.Color=T.A1 end)
local hintL=label({Position=UDim2.fromOffset(8,0),Size=UDim2.new(1,-16,1,0),Text="",TextSize=10,Font=Enum.Font.GothamBold,TextTransparency=1,TextWrapped=true,TextTruncate=Enum.TextTruncate.None,ZIndex=8},hint)
function Q.showHint(key)
	hintL.Text=tr(key)
	tween(hint,0.3,{BackgroundTransparency=0.12})
	tween(hintS,0.3,{Transparency=0.35})
	tween(hintL,0.3,{TextTransparency=0})
end
function Q.hideHint()
	tween(hint,0.25,{BackgroundTransparency=1})
	tween(hintS,0.25,{Transparency=1})
	tween(hintL,0.25,{TextTransparency=1})
end

-- charge ring (fills while you hold the button) -------------------------
function Q.chargeStart()
	Q.charging=true
	Q.shown=false
	Q.hs=os.clock()
	Q.cn=-1
	for k=1,NC do Q.cl[k]=false end
	Q.setChgPal((Q.mode+1)%5)
end
function Q.chargeUpdate()
	local el=os.clock()-Q.hs
	if el<0.12 then return end -- quick taps never show the ring
	if not Q.shown then
		Q.shown=true
		for _,d in ipairs(chgDots) do
			d.Position=UDim2.new(0.5,0,0.5,-40)
			tween(d,0.2,{Size=UDim2.fromOffset(4,4),BackgroundTransparency=0.72})
		end
	end
	local p=math.clamp((el-0.12)/(HOLD-0.12),0,1)
	local n=math.floor(p*NC)
	for k=1,NC do
		local on=(k<=n)
		if on~=Q.cl[k] then
			Q.cl[k]=on
			if on then
				tween(chgDots[k],0.18,{Size=UDim2.fromOffset(7,7),BackgroundTransparency=0},Enum.EasingStyle.Back)
			end
		end
	end
	if n~=Q.cn then
		Q.cn=n
		if n>0 and n%4==0 then sfx("tick",0.18,0.8+p*1.3) end
	end
	chgGlow.BackgroundTransparency=1-0.45*p
	local gs=60+34*p
	chgGlow.Size=UDim2.fromOffset(gs,gs)
end
function Q.chargeCancel()
	if not Q.charging then return end
	Q.charging=false
	if not Q.shown then return end
	Q.shown=false
	for k,d in ipairs(chgDots) do
		Q.cl[k]=false
		tween(d,0.2,{Size=UDim2.fromOffset(4,4),BackgroundTransparency=1})
	end
	tween(chgGlow,0.25,{BackgroundTransparency=1})
end
function Q.chargeSnap() -- the ring is complete: the dots fly outward and become the next dial
	Q.charging=false
	Q.shown=false
	for k,d in ipairs(chgDots) do
		Q.cl[k]=false
		tween(d,0.45,{Position=UDim2.new(0.5,0,0.5,-76),BackgroundTransparency=1,Size=UDim2.fromOffset(2,2)},Enum.EasingStyle.Quint)
	end
	tween(chgGlow,0.4,{BackgroundTransparency=1})
	sfx("ping",0.3,1.7)
end

-- ring input -----------------------------------------------------------------
local lastQT=0
function Q.tickSfx(f)
	local now=os.clock()
	if now-lastQT>0.05 then
		lastQT=now
		sfx("tick",0.2,0.8+f*1.2)
	end
end
-- v = vector from the dial center (screen pixels). Converts the angle to 0..1 for the active dial.
function Q.ringTo(v)
	local d=Q.D[Q.mode]
	if not d or v.Magnitude<6 then return end
	if d.touched then d.touched() end
	-- dials with several concentric tracks: a pressed zone fixes the track, hold + slide picks it by distance
	local tube=Q.rgTube
	if not tube and d.tubeAt then tube=d.tubeAt(v.Magnitude) end
	if tube~=Q.lastTube then
		Q.lastTube=tube
		Q.lastF=d.getF(tube)
	end
	local a=math.deg(math.atan2(v.X,-v.Y))
	local r=(a-d.gapDir+540)%360-180
	local f
	if d.gapHalf>0 and math.abs(r)<d.gapHalf then
		-- pointer is inside the gap: stick to the nearest end (no jumping across the gap)
		f=(Q.lastF>=0.5) and 1 or 0
	else
		local u=(r<0) and (r+360) or r
		f=math.clamp((u-d.gapHalf)/(360-2*d.gapHalf),0,1)
	end
	Q.lastF=f
	Q.grab=true
	d.ring(f,tube)
end
function Q.rgEnd()
	Q.rg=false
	Q.rgMode=nil
	Q.rgIn=nil
	Q.rgTube=nil
	Q.lastTube=nil
	Q.grab=false
end
-- called when a ring touch zone is pressed. ang/rad = where that zone sits on the dial.
function Q.ringBegin(i,ang,rad,sc,m,tube)
	if Q.mode~=m or Q.rg then return end
	local d=Q.D[m]
	Q.rg=true
	Q.rgMode="ring"
	Q.rgTube=tube
	Q.lastTube=tube
	Q.rgIn=i
	Q.rgP0=i.Position
	-- anchor = where the pressed zone is on screen. After that only finger movement (deltas)
	-- is used, so it behaves the same on every device regardless of the top bar inset.
	local s=sc.Scale
	local rr=math.rad(ang)
	local cx,cy=fb.Position.X.Offset,fb.Position.Y.Offset
	Q.rgG0=Vector2.new(cx+math.sin(rr)*rad*s,cy-math.cos(rr)*rad*s)
	Q.lastF=d.getF(tube)
	sfx("click",0.25,1.4)
	Q.ringTo(Q.rgG0-Vector2.new(cx,cy))
	i.Changed:Connect(function()
		if i.UserInputState==Enum.UserInputState.End and Q.rgIn==i then Q.rgEnd() end
	end)
end

-- mode switching -----------------------------------------------------------------
function Q.fitDial()
	local x,y=Q.clampFb(fb.Position.X.Offset,fb.Position.Y.Offset)
	if math.abs(x-fb.Position.X.Offset)>1 or math.abs(y-fb.Position.Y.Offset)>1 then
		tween(fb,0.45,{Position=UDim2.fromOffset(x,y)},Enum.EasingStyle.Back)
	end
end
function Q.fx(m) -- opening burst in the palette of mode m
	local p=Q.pal(m)
	local mid=UDim2.fromScale(0.5,0.5)
	shockwave(chg,mid,46,260,3,0.8,0,p)
	shockwave(chg,mid,40,200,1.5,0.65,0.1,p)
	shockwave(chg,mid,36,150,1,0.55,0.2,p)
	burst(chg,mid,22,p,96)
end
function Q.setMode(m)
	if m==Q.mode then return end
	local old=Q.mode
	Q.mode=m
	Q.open=(m~=0)
	Q.tok=Q.tok+1
	Q.rgEnd()
	Q.hideHint()
	if old~=0 then Q.D[old].close() end
	if m~=0 then
		Q.fitDial()
		Q.D[m].open(Q.tok)
	else
		shockwave(chg,UDim2.fromScale(0.5,0.5),210,40,2,0.4,0)
		sfx("whoosh",0.35,0.85)
		sfx("switch",0.3,0.8)
	end
	tween(fbScale,0.35,{Scale=restScale()},Enum.EasingStyle.Back)
end
function Q.closeDial() Q.setMode(0) end
end -- [E:dial-shared]

------------------------------------------------ DIAL 1: FLY  (segmented bar ring -> speed)
do -- [dial1: fly]
local F={ap=0,apT=0,dv=0,tv=0,gk=0,sweeping=false,txt="",eng=0,flash=0}
local N,R,ARC0,ARC1=54,66,-140,140
local function s2f(v) return math.clamp((v-MIN_SPEED)/(MAX_SPEED-MIN_SPEED),0,1) end
local function f2s(f) return math.floor(MIN_SPEED+math.clamp(f,0,1)*(MAX_SPEED-MIN_SPEED)+0.5) end

local dial=new("Frame",{Name="FlyDial",AnchorPoint=Vector2.new(0.5,0.5),Size=UDim2.fromOffset(200,200),Position=fb.Position,BackgroundTransparency=1,BorderSizePixel=0,Visible=false,ZIndex=58},gui)
local dScale=new("UIScale",{Scale=0.3},dial)

local function disc(d,z)
	local f=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(d,d),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=z},dial)
	corner(f,999)
	return f
end

-- glowing halos + dark glass plate + thin inner ring
local halo1=disc(206,0) tgrad(halo1,45)
local halo2=disc(190,0) tgrad(halo2,225)
local plate=disc(176,1)
plate.Active=true
grad(plate,Color3.fromRGB(36,39,68),Color3.fromRGB(10,11,19),90)
local plateStroke=stroke(plate,C.White,2,1)
local plateSG=new("UIGradient",{},plateStroke)
onTheme(function()
	plateSG.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,T.A1),ColorSequenceKeypoint.new(0.5,T.A2),ColorSequenceKeypoint.new(1,T.A1)})
end)
local inner=disc(114,1)
local innerS=stroke(inner,C.White,1,1)

-- two counter-rotating arcs around the icon
local function spinRing(d,th,arc)
	local f=disc(d,2)
	local s=stroke(f,C.White,th,1)
	local g=new("UIGradient",{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(arc,1),NumberSequenceKeypoint.new(1,1)})},s)
	onTheme(function() g.Color=ColorSequence.new(T.A1,T.A2) end)
	return s,g
end
local spA,spAg=spinRing(100,1.6,0.42)
local spB,spBg=spinRing(86,1.1,0.6)

-- the segmented ring: every segment is a thin bar that grows outward when lit.
-- rot (rotating pivot at the dial center) -> bar (visual) + zone (touch target)
local segs={}
for k=1,N do
	local a=ARC0+(k-0.5)/N*(ARC1-ARC0)
	local rot=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(10,10),Rotation=a,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=3},dial)
	local bar=new("Frame",{AnchorPoint=Vector2.new(0.5,1),Position=UDim2.new(0.5,0,0.5,-(R-10)),Size=UDim2.fromOffset(3,0),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=3},rot)
	corner(bar,2)
	local zone=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,-R),Size=UDim2.fromOffset(10,46),BackgroundTransparency=1,BorderSizePixel=0,Active=true,ZIndex=4},rot)
	zone.InputBegan:Connect(function(i)
		if isPress(i) then Q.ringBegin(i,a,R,dScale,1) end
	end)
	segs[k]=bar
end

-- glowing handle that rides on the ring
local knobRot=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(10,10),Rotation=ARC0,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=5},dial)
local knobGlow=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,-R),Size=UDim2.fromOffset(0,0),BackgroundColor3=C.White,BackgroundTransparency=0.7,BorderSizePixel=0,ZIndex=5},knobRot)
corner(knobGlow,999) tgrad(knobGlow,45)
local knob=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,-R),Size=UDim2.fromOffset(0,0),BackgroundColor3=C.White,BorderSizePixel=0,ZIndex=6},knobRot)
corner(knob,999)
local knobS=stroke(knob,C.White,2.5,0)
onTheme(function() knobS.Color=T.A1 end)

-- readout (bottom gap) + status (top, inside the ring)
local rdNum=label({AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,50),Size=UDim2.fromOffset(72,24),Text="",TextSize=21,Font=Enum.Font.GothamBlack,TextColor3=C.White,TextTransparency=1,ZIndex=6},dial)
tgrad(rdNum,0)
local rdUnit=label({AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,68),Size=UDim2.fromOffset(72,12),Text="st/s",TextSize=9,Font=Enum.Font.Gotham,TextColor3=C.Muted,TextTransparency=1,ZIndex=6},dial)
local stLbl=label({AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,-42),Size=UDim2.fromOffset(84,12),Text="",TextSize=10,Font=Enum.Font.GothamBold,TextTransparency=1,ZIndex=6},dial)
local function paint()
	stLbl.Text=flying and tr("on") or tr("off")
	stLbl.TextColor3=flying and T.A1 or C.Muted
end
onLang(paint)
onTheme(paint)

local function frame(t,dt)
	if F.ap<F.apT then
		F.ap=math.min(F.apT,F.ap+dt/0.8)
	elseif F.ap>F.apT then
		F.ap=math.max(F.apT,F.ap-dt/0.4)
	end
	local ap=F.ap
	if F.apT==0 and ap<=0 then
		dial.Visible=false
		return
	end
	local flyOn=flying
	if not F.sweeping and Q.mode==1 then F.tv=s2f(speed) end
	F.dv=F.dv+(F.tv-F.dv)*math.min(1,dt*(Q.rg and 18 or 7))
	F.gk=F.gk+((Q.grab and 1 or 0)-F.gk)*math.min(1,dt*14)
	F.flash=math.max(0,F.flash-dt*2.2)
	local dv=math.clamp(F.dv,0,1)
	local pulse=math.sin(t*2.2)

	-- body
	dScale.Scale=0.3+0.7*backE(math.clamp(ap/0.65,0,1))
	plate.BackgroundTransparency=1-ap*0.86
	plateStroke.Transparency=1-ap*0.8
	plateSG.Rotation=(t*(flyOn and 120 or 40))%360
	innerS.Transparency=1-ap*0.14
	local hb=0.1+(flyOn and 0.09 or 0)+0.22*F.flash+0.02*pulse
	halo1.BackgroundTransparency=math.clamp(1-ap*hb,0,1)
	halo2.BackgroundTransparency=math.clamp(1-ap*(hb+0.06),0,1)
	local h1=206+8*pulse
	halo1.Size=UDim2.fromOffset(h1,h1)
	local sa=1-math.clamp((ap-0.25)/0.5,0,1)
	spA.Transparency=sa
	spB.Transparency=sa
	spAg.Rotation=(t*150)%360
	spBg.Rotation=(-t*110)%360

	-- segments (stagger in clockwise, grow when lit, head boost, thrust wave while flying)
	local c1,c2=T.A1,T.A2
	for k=1,N do
		local p=(k-0.5)/N
		local f=math.clamp(dv*N-(k-1),0,1)
		local pop=math.clamp((ap-(k-1)/N*0.6)/0.4,0,1)
		local e=backE(pop)
		local boost=math.max(0,1-math.abs(p-dv)*10)
		local h=7+9*f+9*boost
		if flyOn and f>0.99 then h=h+3*(0.5+0.5*math.sin(t*7-k*0.45)) end
		h=math.max(h*e,0)
		local bar=segs[k]
		bar.Size=UDim2.fromOffset(3,h)
		bar.BackgroundColor3=C.White:Lerp(c1:Lerp(c2,p),f)
		bar.BackgroundTransparency=1-pop*(0.2+0.8*f)
	end

	-- handle
	knobRot.Rotation=ARC0+dv*(ARC1-ARC0)
	local ke=backE(math.clamp((ap-0.55)/0.4,0,1))
	local ks=math.max((15+8*F.gk)*ke,0)
	local gs=math.max((34+14*F.gk+(flyOn and 5*math.sin(t*7) or 0))*ke,0)
	knob.Size=UDim2.fromOffset(ks,ks)
	knobGlow.Size=UDim2.fromOffset(gs,gs)

	-- readout
	local txt=tostring(f2s(dv))
	if txt~=F.txt then
		F.txt=txt
		rdNum.Text=txt
	end
	local lt=1-math.clamp((ap-0.5)/0.3,0,1)
	rdNum.TextTransparency=lt
	rdUnit.TextTransparency=math.min(1,lt+0.3)
	stLbl.TextTransparency=lt

	-- engine pulse rings while flying
	if flyOn and Q.mode==1 and t>F.eng then
		F.eng=t+0.85
		shockwave(Q.chg,UDim2.fromScale(0.5,0.5),54,150,1.5,0.9,0,nil,0.5)
	end
end

local function open(tok)
	dial.Visible=true
	F.apT=1
	F.dv=0
	F.tv=0
	F.txt=""
	F.sweeping=true
	F.flash=1
	F.eng=os.clock()+1
	Q.fx(1)
	sfx("whoosh",0.45,1.6)
	sfx("ping",0.35,1.1)
	-- "rev up": the ring sweeps to full, then settles on the real speed
	task.delay(0.28,function()
		if Q.mode==1 and Q.tok==tok and F.sweeping then
			F.tv=1
			sfx("whoosh",0.25,2.0)
		end
	end)
	task.delay(1.0,function()
		if Q.mode==1 and Q.tok==tok and F.sweeping then
			F.sweeping=false
			sfx("ping",0.3,1.5)
		end
	end)
	task.delay(0.6,function()
		if Q.mode==1 and Q.tok==tok then Q.showHint("qf_hint") end
	end)
	task.delay(4.6,function()
		if Q.tok==tok then Q.hideHint() end
	end)
end

Q.D[1]={root=dial,scale=dScale,gapDir=180,gapHalf=40,frame=frame,open=open,
	close=function()
		F.apT=0
		F.sweeping=false
	end,
	tap=function()
		if S.toggleFly then S.toggleFly() end
	end,
	ring=function(f)
		local ns=f2s(f)
		if ns~=speed then
			if S.setSpeed then S.setSpeed(ns) end
			Q.tickSfx(f)
		end
	end,
	getF=function() return s2f(speed) end,
	touched=function() F.sweeping=false end}

-- fly on/off feedback (called from refreshToggle)
function S.onFlyState(on)
	paint()
	F.flash=1
	if Q.mode==1 then
		local mid=UDim2.fromScale(0.5,0.5)
		shockwave(Q.chg,mid,50,on and 270 or 160,3,0.7,0)
		burst(Q.chg,mid,on and 22 or 10,{a1=T.A1,a2=T.A2},on and 100 or 70)
		F.eng=os.clock()+0.8
	end
end
end -- [E:dial1]

------------------------------------------------ DIAL 2: COMBAT  (scope bezel + lock brackets -> FOV)
do -- [dial2: combat]
local NT,RC=60,62
local GD,GH=0,34                   -- the gap of this ring sits at the top
local FMIN,FMAX=30,600
local P1,P2=S.pal.cb1,S.pal.cb2
local RED=Color3.fromRGB(255,40,60)
local K={ap=0,apT=0,lk=0,flash=0,scan=-1,dv=0,gk=0,was=false,st=-1,txt=""}

local root=new("Frame",{Name="CombatDial",AnchorPoint=Vector2.new(0.5,0.5),Size=UDim2.fromOffset(200,200),Position=fb.Position,BackgroundTransparency=1,BorderSizePixel=0,Visible=false,ZIndex=58},gui)
local sc=new("UIScale",{Scale=0.3},root)
local function disc(d,z)
	local f=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(d,d),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=z},root)
	corner(f,999)
	return f
end

-- glow + dark plate + hairline (their colors follow the FOV colors chosen in the Combat tab)
local halo=disc(208,0)
local haloG=grad(halo,P1,P2,45)
local plate=disc(172,1)
plate.Active=true
grad(plate,Color3.fromRGB(42,14,22),Color3.fromRGB(12,6,10),90)
local plateS=stroke(plate,C.White,2,1)
local plateSG=new("UIGradient",{},plateS)
local hair=disc(108,1)
local hairS=stroke(hair,P1,1,1)

-- four rotating corner brackets: they close in when a target is locked
local brk=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(4,4),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=3},root)
local bh,bv={},{}
for k=0,3 do
	local pv=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(4,4),Rotation=k*90,BackgroundTransparency=1,BorderSizePixel=0},brk)
	bh[k+1]=new("Frame",{Position=UDim2.new(0.5,-34,0.5,-34),Size=UDim2.fromOffset(12,2),BackgroundColor3=P2,BackgroundTransparency=1,BorderSizePixel=0},pv)
	bv[k+1]=new("Frame",{Position=UDim2.new(0.5,-34,0.5,-34),Size=UDim2.fromOffset(2,12),BackgroundColor3=P2,BackgroundTransparency=1,BorderSizePixel=0},pv)
end

-- scope bezel: ticks around the ring (major tick every 6th), the ring has a gap at the top
local ticks={}
for k=1,NT do
	local a=GD+GH+(k-1)/(NT-1)*(360-2*GH)
	local rot=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(10,10),Rotation=a,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=3},root)
	local bar=new("Frame",{AnchorPoint=Vector2.new(0.5,1),Position=UDim2.new(0.5,0,0.5,-RC),Size=UDim2.fromOffset(2,0),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=3},rot)
	corner(bar,1)
	local zone=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,-(RC+5)),Size=UDim2.fromOffset(10,46),BackgroundTransparency=1,BorderSizePixel=0,Active=true,ZIndex=4},rot)
	zone.InputBegan:Connect(function(i)
		if isPress(i) then Q.ringBegin(i,a,RC+5,sc,2) end
	end)
	ticks[k]=bar
end

-- diamond marker riding outside the bezel
local kRot=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(10,10),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=5},root)
local kGlow=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,-(RC+15)),Size=UDim2.fromOffset(0,0),Rotation=45,BackgroundColor3=P1,BackgroundTransparency=0.7,BorderSizePixel=0,ZIndex=5},kRot)
corner(kGlow,4)
local kDia=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,-(RC+15)),Size=UDim2.fromOffset(0,0),Rotation=45,BackgroundColor3=C.White,BorderSizePixel=0,ZIndex=6},kRot)
corner(kDia,2)
local kS=stroke(kDia,P1,2,0)

-- readout: FOV number (bottom), status (inside the top gap)
local num=label({AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,43),Size=UDim2.fromOffset(72,20),Text="",TextSize=18,Font=Enum.Font.GothamBlack,TextColor3=C.White,TextTransparency=1,ZIndex=6},root)
local numG=grad(num,P1,P2,0)
local unit=label({AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,58),Size=UDim2.fromOffset(40,10),Text="FOV",TextSize=9,Font=Enum.Font.GothamBold,TextColor3=C.Muted,TextTransparency=1,ZIndex=6},root)
local stL=label({AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,-60),Size=UDim2.fromOffset(64,12),Text="",TextSize=10,Font=Enum.Font.GothamBold,TextTransparency=1,ZIndex=6},root)
-- tap the arrows under the status text = switch to the next target without unlocking
local nextB=new("TextButton",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,-52),Size=UDim2.fromOffset(84,30),BackgroundTransparency=1,Text="",AutoButtonColor=false,Active=true,ZIndex=7},root)
local chev=label({AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,-46),Size=UDim2.fromOffset(40,10),Text="▶▶",TextSize=8,Font=Enum.Font.GothamBlack,TextColor3=C.Muted,TextTransparency=1,TextTruncate=Enum.TextTruncate.None,ZIndex=6},root)
nextB.Activated:Connect(function()
	if Q.mode==2 and S.cbNext then
		sfx("click",0.35,1.5)
		S.cbNext()
	end
end)
onLang(function() K.st=-1 end)

local function frame(t,dt)
	if K.ap<K.apT then
		K.ap=math.min(K.apT,K.ap+dt/0.8)
	elseif K.ap>K.apT then
		K.ap=math.max(K.apT,K.ap-dt/0.4)
	end
	local ap=K.ap
	if K.apT==0 and ap<=0 then
		root.Visible=false
		return
	end
	local cb=S.cb
	local c1,c2,rd=P1,P2,RED
	if S.cbCols then c1,c2,rd=S.cbCols() end
	local lockedNow=(cb.lock and cb.tgt~=nil)
	if lockedNow~=K.was then
		K.was=lockedNow
		K.flash=1
		if Q.mode==2 then
			local mid=UDim2.fromScale(0.5,0.5)
			if lockedNow then
				shockwave(Q.chg,mid,230,40,3,0.45,0,{a1=rd},0.05)
				burst(Q.chg,mid,16,{a1=rd,a2=c2},84)
				sfx("ping",0.45,1.5)
			else
				shockwave(Q.chg,mid,50,230,2,0.6,0,{a1=c1},0.2)
			end
		end
	end
	K.lk=K.lk+((lockedNow and 1 or 0)-K.lk)*math.min(1,dt*9)
	K.flash=math.max(0,K.flash-dt*2.4)
	local f=math.clamp((cb.fov-FMIN)/(FMAX-FMIN),0,1)
	K.dv=K.dv+(f-K.dv)*math.min(1,dt*(Q.rg and 18 or 8))
	K.gk=K.gk+((Q.grab and 1 or 0)-K.gk)*math.min(1,dt*14)
	local lk,dv=K.lk,K.dv
	if K.scan>=0 then
		K.scan=K.scan+dt/0.9
		if K.scan>1.2 then K.scan=-1 end
	end
	local pulse=math.sin(t*2.6)

	-- body
	sc.Scale=0.3+0.7*backE(math.clamp(ap/0.65,0,1))
	plate.BackgroundTransparency=1-ap*0.88
	plateS.Transparency=1-ap*0.85
	plateSG.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,c1),ColorSequenceKeypoint.new(0.5,c2),ColorSequenceKeypoint.new(1,c1)})
	plateSG.Rotation=(t*(40+110*lk))%360
	hairS.Color=c1
	hairS.Transparency=1-ap*(0.3+0.25*lk)
	haloG.Color=ColorSequence.new(c1,c2)
	numG.Color=ColorSequence.new(c1,c2)
	halo.BackgroundTransparency=math.clamp(1-ap*(0.1+0.14*lk+0.2*K.flash+0.02*pulse),0,1)
	local hs=208+8*pulse
	halo.Size=UDim2.fromOffset(hs,hs)

	-- brackets
	local e=backE(math.clamp(ap/0.7,0,1))
	local bs=34+42*(1-e)-7*lk+1.5*pulse
	local bl=12+5*lk
	brk.Rotation=(t*(25+160*lk)+(1-e)*160)%360
	local bcol=c2:Lerp(C.White,math.clamp(0.25*lk+K.flash,0,1))
	local bt=1-math.clamp(ap*1.2,0,1)*(0.55+0.45*lk)
	for k=1,4 do
		local h,v=bh[k],bv[k]
		h.Position=UDim2.new(0.5,-bs,0.5,-bs)
		v.Position=UDim2.new(0.5,-bs,0.5,-bs)
		h.Size=UDim2.fromOffset(bl,2)
		v.Size=UDim2.fromOffset(2,bl)
		h.BackgroundColor3=bcol
		v.BackgroundColor3=bcol
		h.BackgroundTransparency=bt
		v.BackgroundTransparency=bt
	end

	-- bezel ticks (appear counter-clockwise, a comet sweeps once around when the dial opens)
	local head=K.scan*NT
	for k=1,NT do
		local p=(k-1)/(NT-1)
		local fl=math.clamp(dv*NT-(k-1),0,1)
		local pop=math.clamp((ap-(NT-k)/NT*0.6)/0.4,0,1)
		local ee=backE(pop)
		local major=(k%6==1)
		local boost=0
		if K.scan>=0 then boost=math.max(0,1-math.abs(k-head)/6) end
		boost=math.max(boost,K.flash*0.5*fl)
		local h=(major and 10 or 6)+7*fl*(major and 1 or 0.7)+8*boost
		local mark=math.max(0,1-math.abs(p-dv)*14)
		h=math.max((h+7*mark)*ee,0)
		local col=c1:Lerp(c2,p):Lerp(rd,lk*fl):Lerp(C.White,math.clamp(boost*0.8,0,1))
		local bar=ticks[k]
		bar.Size=UDim2.fromOffset(major and 3 or 2,h)
		bar.BackgroundColor3=C.White:Lerp(col,math.max(fl,boost))
		bar.BackgroundTransparency=1-pop*(0.25+0.75*math.max(fl,boost))
	end

	-- diamond marker
	kRot.Rotation=GD+GH+dv*(360-2*GH)
	local ke=backE(math.clamp((ap-0.55)/0.4,0,1))
	local ks=math.max((11+5*K.gk)*ke,0)
	local gs=math.max((24+10*K.gk+3*pulse)*ke,0)
	kDia.Size=UDim2.fromOffset(ks,ks)
	kGlow.Size=UDim2.fromOffset(gs,gs)
	local kc=c1:Lerp(rd,lk)
	kGlow.BackgroundColor3=kc
	kS.Color=kc

	-- readout
	local txt=tostring(math.floor(FMIN+dv*(FMAX-FMIN)+0.5))
	if txt~=K.txt then
		K.txt=txt
		num.Text=txt
	end
	local st=0
	if cb.lock then st=cb.tgt and 1 or 2 end
	if st~=K.st then
		K.st=st
		stL.Text=(st==1) and tr("cb_locked") or ((st==2) and tr("cb_search") or tr("cb_ready"))
	end
	stL.TextColor3=(st==1) and rd or ((st==2) and c2 or C.Muted)
	local lt=1-math.clamp((ap-0.5)/0.3,0,1)
	num.TextTransparency=lt
	unit.TextTransparency=math.min(1,lt+0.3)
	stL.TextTransparency=lt
	chev.TextTransparency=math.min(1,lt+(cb.lock and 0 or 0.55))
	chev.TextColor3=cb.lock and rd or C.Muted
	chev.Position=UDim2.new(0.5,math.sin(t*6)*(cb.lock and 3 or 0),0.5,-46)
end

local function open(tok)
	root.Visible=true
	K.apT=1
	K.scan=0
	K.flash=1
	K.dv=0
	K.txt=""
	K.st=-1
	S.cb.dialOpen=true
	Q.fx(2)
	sfx("whoosh",0.45,1.2)
	sfx("ping",0.35,0.9)
	task.delay(0.6,function()
		if Q.mode==2 and Q.tok==tok then Q.showHint("qf_hint2") end
	end)
	task.delay(4.6,function()
		if Q.tok==tok then Q.hideHint() end
	end)
end

Q.D[2]={root=root,scale=sc,gapDir=GD,gapHalf=GH,frame=frame,open=open,
	close=function()
		K.apT=0
		S.cb.dialOpen=false
	end,
	tap=function()
		if S.cbToggle then S.cbToggle() end
	end,
	ring=function(f)
		local v=math.floor(FMIN+f*(FMAX-FMIN)+0.5)
		if v~=S.cb.fov then
			if S.setFov then S.setFov(v) end
			Q.tickSfx(f)
		end
	end,
	getF=function() return math.clamp((S.cb.fov-FMIN)/(FMAX-FMIN),0,1) end}
end -- [E:dial2]


------------------------------------------------ DIAL 3: VISUAL  (rainbow bead ring -> ESP color)
do -- [dial3: visual]
local NB,RV=60,66
local V={ap=0,apT=0,on=0,gk=0,flash=0,txt="",st=-1}

local root=new("Frame",{Name="VisualDial",AnchorPoint=Vector2.new(0.5,0.5),Size=UDim2.fromOffset(200,200),Position=fb.Position,BackgroundTransparency=1,BorderSizePixel=0,Visible=false,ZIndex=58},gui)
local sc=new("UIScale",{Scale=0.3},root)
local function disc(d,z)
	local f=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(d,d),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=z},root)
	corner(f,999)
	return f
end

-- glow in the chosen color + dark plate + glowing core
local glow=disc(206,0)
local plate=disc(172,1)
plate.Active=true
grad(plate,Color3.fromRGB(18,20,40),Color3.fromRGB(8,9,18),90)
local plateS=stroke(plate,C.White,2,1)
local plateSG=new("UIGradient",{},plateS)
local core=disc(100,1)
local coreS=stroke(core,C.White,1.2,1)

-- bead ring: one bead per hue, they bloom outward in a scattered sparkle order
local beads={}
for k=1,NB do
	local a=(k-1)*360/NB
	local rot=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(10,10),Rotation=a,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=3},root)
	local bead=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,-RV),Size=UDim2.fromOffset(0,0),BackgroundColor3=Color3.fromHSV(a/360,0.85,1),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=3},rot)
	corner(bead,999)
	local zone=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,-RV),Size=UDim2.fromOffset(14,46),BackgroundTransparency=1,BorderSizePixel=0,Active=true,ZIndex=4},rot)
	zone.InputBegan:Connect(function(i)
		if isPress(i) then Q.ringBegin(i,a,RV,sc,3) end
	end)
	beads[k]=bead
end

-- selection ring that sits on the chosen hue
local selRot=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(10,10),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=5},root)
local selHalo=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,-RV),Size=UDim2.fromOffset(0,0),BackgroundColor3=C.White,BackgroundTransparency=0.7,BorderSizePixel=0,ZIndex=5},selRot)
corner(selHalo,999)
local selRing=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,-RV),Size=UDim2.fromOffset(0,0),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=6},selRot)
corner(selRing,999)
local selS=stroke(selRing,C.White,2.5,0)

-- three satellites orbiting inside the ring
local sats={}
for k=1,3 do
	local rot=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(4,4),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=3},root)
	local d=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,-(46+k*2)),Size=UDim2.fromOffset(0,0),BackgroundColor3=C.White,BorderSizePixel=0,ZIndex=3},rot)
	corner(d,999)
	sats[k]={rot=rot,d=d}
end

-- readout: ESP state (top) + hue (bottom)
local stL=label({AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,-44),Size=UDim2.fromOffset(72,12),Text="",TextSize=10,Font=Enum.Font.GothamBold,TextTransparency=1,ZIndex=6},root)
local num=label({AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,46),Size=UDim2.fromOffset(72,20),Text="",TextSize=17,Font=Enum.Font.GothamBlack,TextColor3=C.White,TextTransparency=1,ZIndex=6},root)

local function frame(t,dt)
	if V.ap<V.apT then
		V.ap=math.min(V.apT,V.ap+dt/0.8)
	elseif V.ap>V.apT then
		V.ap=math.max(V.apT,V.ap-dt/0.4)
	end
	local ap=V.ap
	if V.apT==0 and ap<=0 then
		root.Visible=false
		return
	end
	local vz=S.vz
	V.on=V.on+((vz.on and 1 or 0)-V.on)*math.min(1,dt*6)
	V.flash=math.max(0,V.flash-dt*2.2)
	V.gk=V.gk+((Q.grab and 1 or 0)-V.gk)*math.min(1,dt*14)
	local on=V.on
	local hue=vz.hue
	local c1=Color3.fromHSV(hue/360,0.85,1)
	local c2=Color3.fromHSV(((hue+60)%360)/360,0.8,1)
	local pulse=math.sin(t*2.4)

	-- body
	sc.Scale=0.3+0.7*backE(math.clamp(ap/0.65,0,1))
	plate.BackgroundTransparency=1-ap*0.88
	plateS.Transparency=1-ap*0.8
	plateSG.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,c1),ColorSequenceKeypoint.new(0.5,c2),ColorSequenceKeypoint.new(1,c1)})
	plateSG.Rotation=(t*(40+80*on))%360
	glow.BackgroundColor3=c1
	glow.BackgroundTransparency=math.clamp(1-ap*(0.08+0.1*on+0.2*V.flash+0.015*pulse),0,1)
	local gz=206+6*pulse
	glow.Size=UDim2.fromOffset(gz,gz)
	core.BackgroundColor3=c1
	core.BackgroundTransparency=math.clamp(1-ap*(0.14+0.18*on+0.03*pulse),0,1)
	local cz=100+(on*8)*pulse
	core.Size=UDim2.fromOffset(cz,cz)
	coreS.Color=c2
	coreS.Transparency=1-ap*(0.3+0.4*on)

	-- beads
	for k=1,NB do
		local a=(k-1)*360/NB
		local d=math.abs(((a-hue+540)%360)-180)
		local near=math.max(0,1-d/22)
		local ord=((k*17)%NB)/NB
		local pop=math.clamp((ap-ord*0.6)/0.4,0,1)
		local e=backE(pop)
		local wave=0.5+0.5*math.sin(t*3.2-k*0.35)
		local size=math.max((6+9*near+3*wave*on)*e,0)
		local rr=RV*(0.35+0.65*e)
		local bead=beads[k]
		bead.Position=UDim2.new(0.5,0,0.5,-rr)
		bead.Size=UDim2.fromOffset(size,size)
		bead.BackgroundTransparency=1-pop*(0.35+0.65*math.max(near,on*(0.7+0.3*wave)))
	end

	-- selection ring
	selRot.Rotation=hue
	local ke=backE(math.clamp((ap-0.55)/0.4,0,1))
	local rz=math.max((20+5*V.gk)*ke,0)
	selRing.Size=UDim2.fromOffset(rz,rz)
	local hz=math.max((38+8*pulse)*ke,0)
	selHalo.Size=UDim2.fromOffset(hz,hz)
	selHalo.BackgroundColor3=c1

	-- satellites
	for k=1,3 do
		local s=sats[k]
		s.rot.Rotation=(t*(35+110*on)*(k%2==0 and -1 or 1)+k*120)%360
		local ds=math.max((3+2*on)*ke,0)
		s.d.Size=UDim2.fromOffset(ds,ds)
		s.d.BackgroundColor3=c1:Lerp(c2,k/3)
		s.d.BackgroundTransparency=0.15
	end

	-- readout
	local txt=tostring(math.floor(hue+0.5)).."°"
	if txt~=V.txt then
		V.txt=txt
		num.Text=txt
	end
	num.TextColor3=c1
	local st=vz.on and 1 or 0
	if st~=V.st then
		V.st=st
		stL.Text=vz.on and "ESP ON" or "ESP OFF"
	end
	stL.TextColor3=vz.on and c1 or C.Muted
	local lt=1-math.clamp((ap-0.5)/0.3,0,1)
	num.TextTransparency=lt
	stL.TextTransparency=lt

	-- color pulses rolling out of the core while ESP is on
	if vz.on and Q.mode==3 and t>(V.eng or 0) then
		V.eng=t+1.1
		shockwave(Q.chg,UDim2.fromScale(0.5,0.5),50,150,1.5,0.9,0,{a1=c1},0.5)
	end
end

local function open(tok)
	root.Visible=true
	V.apT=1
	V.flash=1
	V.txt=""
	V.st=-1
	V.eng=os.clock()+1
	Q.fx(3)
	sfx("whoosh",0.4,1.9)
	sfx("ping",0.35,1.4)
	task.delay(0.6,function()
		if Q.mode==3 and Q.tok==tok then Q.showHint("qf_hint3") end
	end)
	task.delay(4.6,function()
		if Q.tok==tok then Q.hideHint() end
	end)
end

Q.D[3]={root=root,scale=sc,gapDir=0,gapHalf=0,frame=frame,open=open,
	close=function() V.apT=0 end,
	tap=function()
		if S.setEsp then S.setEsp(not S.vz.on) end
	end,
	ring=function(f)
		if S.setHue then S.setHue(f*360) end
		Q.tickSfx(f)
	end,
	getF=function() return (S.vz.hue%360)/360 end}

-- ESP on/off feedback (called from S.setEsp)
function S.onEspState(on)
	V.flash=1
	if Q.mode==3 then
		local p=Q.pal(3)
		local mid=UDim2.fromScale(0.5,0.5)
		shockwave(Q.chg,mid,50,on and 280 or 160,3,0.7,0,p)
		burst(Q.chg,mid,on and 24 or 10,p,on and 104 or 70)
	end
end
end -- [E:dial3]

------------------------------------------------ DIAL 4: PLAYER  (three liquid tubes -> speed / jump / gravity)
do -- [dial4: player]
local KEYS={"speed","jump","grav"}
local ABB={"SPD","JMP","GRV"}
local RT={76,64,52}                -- radius of the three tubes (outer = speed, inner = gravity)
local N=44
local A0,SPAN=140,260              -- the tubes start at 140 degrees, the gap sits on the right
local COL={Color3.fromRGB(90,200,255),Color3.fromRGB(120,255,150),Color3.fromRGB(190,130,255)}
local pl=S.pl
local G={ap=0,apT=0,on=0,flash=0,gk={0,0,0},dv={0,0,0},txt={"","",""},st=-1}

local root=new("Frame",{Name="PlayerDial",AnchorPoint=Vector2.new(0.5,0.5),Size=UDim2.fromOffset(200,200),Position=fb.Position,BackgroundTransparency=1,BorderSizePixel=0,Visible=false,ZIndex=58},gui)
local sc=new("UIScale",{Scale=0.3},root)
local function disc(d,z)
	local f=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(d,d),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=z},root)
	corner(f,999)
	return f
end

-- teal glow + dark glass plate + faint core ring
local halo=disc(206,0)
grad(halo,Color3.fromRGB(60,220,200),Color3.fromRGB(150,110,255),45)
local plate=disc(172,1)
plate.Active=true
grad(plate,Color3.fromRGB(12,30,36),Color3.fromRGB(6,12,18),90)
local plateS=stroke(plate,C.White,2,1)
new("UIGradient",{Color=ColorSequence.new({ColorSequenceKeypoint.new(0,COL[1]),ColorSequenceKeypoint.new(0.5,COL[2]),ColorSequenceKeypoint.new(1,COL[3])})},plateS)
local core=disc(86,1)
local coreS=stroke(core,C.White,1,1)

-- three tubes made of overlapping beads. rot = pivot at the dial center, dot = visual, zone = touch target
local dots={}
for ti=1,3 do
	dots[ti]={}
	for k=1,N do
		local a=A0+(k-0.5)/N*SPAN
		local rot=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(10,10),Rotation=a,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=3},root)
		local d=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,-RT[ti]),Size=UDim2.fromOffset(0,0),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=3},rot)
		corner(d,999)
		local zone=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,-RT[ti]),Size=UDim2.fromOffset(9,12),BackgroundTransparency=1,BorderSizePixel=0,Active=true,ZIndex=4},rot)
		zone.InputBegan:Connect(function(i)
			if isPress(i) then Q.ringBegin(i,a,RT[ti],sc,4,ti) end
		end)
		dots[ti][k]=d
	end
end

-- a glowing orb rides on the head of every tube
local orbRot,orbHalo,orb={},{},{}
for ti=1,3 do
	orbRot[ti]=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(10,10),Rotation=A0,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=5},root)
	orbHalo[ti]=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,-RT[ti]),Size=UDim2.fromOffset(0,0),BackgroundColor3=COL[ti],BackgroundTransparency=0.7,BorderSizePixel=0,ZIndex=5},orbRot[ti])
	corner(orbHalo[ti],999)
	orb[ti]=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,-RT[ti]),Size=UDim2.fromOffset(0,0),BackgroundColor3=C.White,BorderSizePixel=0,ZIndex=6},orbRot[ti])
	corner(orb[ti],999)
	stroke(orb[ti],COL[ti],2,0)
end

-- readouts in the gap on the right + status on top
local lbl={}
for ti=1,3 do
	lbl[ti]=label({AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,60,0.5,(ti-2)*16),Size=UDim2.fromOffset(58,13),Text="",TextSize=10,Font=Enum.Font.GothamBold,TextColor3=COL[ti],TextTransparency=1,ZIndex=6},root)
end
local stL=label({AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,-40),Size=UDim2.fromOffset(64,11),Text="",TextSize=9,Font=Enum.Font.GothamBold,TextTransparency=1,ZIndex=6},root)

local function frame(t,dt)
	if G.ap<G.apT then
		G.ap=math.min(G.apT,G.ap+dt/0.8)
	elseif G.ap>G.apT then
		G.ap=math.max(G.apT,G.ap-dt/0.4)
	end
	local ap=G.ap
	if G.apT==0 and ap<=0 then
		root.Visible=false
		return
	end
	G.on=G.on+((pl.on and 1 or 0)-G.on)*math.min(1,dt*6)
	G.flash=math.max(0,G.flash-dt*2.2)
	local on=G.on
	for ti=1,3 do
		local key=KEYS[ti]
		local f=math.clamp((pl[key]-pl.lo[key])/(pl.hi[key]-pl.lo[key]),0,1)
		local act=Q.rg and Q.lastTube==ti
		G.dv[ti]=G.dv[ti]+(f-G.dv[ti])*math.min(1,dt*(act and 18 or 8))
		G.gk[ti]=G.gk[ti]+((act and 1 or 0)-G.gk[ti])*math.min(1,dt*14)
	end
	local pulse=math.sin(t*2.2)

	-- body
	sc.Scale=0.3+0.7*backE(math.clamp(ap/0.65,0,1))
	plate.BackgroundTransparency=1-ap*0.88
	plateS.Transparency=1-ap*(0.5+0.3*on)
	halo.BackgroundTransparency=math.clamp(1-ap*(0.08+0.08*on+0.22*G.flash+0.015*pulse),0,1)
	coreS.Transparency=1-ap*(0.2+0.3*on)
	local cz=86+6*on*pulse
	core.Size=UDim2.fromOffset(cz,cz)

	-- tubes: beads fill up like liquid, a shimmer runs along the lit part, the head bulges
	for ti=1,3 do
		local col=COL[ti]
		local dvt=G.dv[ti]
		local tube=dots[ti]
		for k=1,N do
			local f=math.clamp(dvt*N-(k-1),0,1)
			local pop=math.clamp((ap-(ti-1)*0.12-(k-1)/N*0.5)/0.35,0,1)
			local e=backE(pop)
			local p=(k-0.5)/N
			local near=math.max(0,1-math.abs(p-dvt)*12)
			local wave=0.5+0.5*math.sin(t*4-k*0.5+ti*1.3)
			local sz=math.max((6+1.6*wave*f*on+3.5*near)*e,0)
			local d=tube[k]
			d.Size=UDim2.fromOffset(sz,sz)
			d.BackgroundColor3=Color3.fromRGB(70,80,105):Lerp(col:Lerp(C.White,0.3*wave*on+0.45*near),f)
			d.BackgroundTransparency=1-pop*(0.3+0.7*f*(0.35+0.65*on))
		end
		-- head orb
		orbRot[ti].Rotation=A0+dvt*SPAN
		local ke=backE(math.clamp((ap-0.55-(ti-1)*0.05)/0.4,0,1))
		local oz=math.max((13+5*G.gk[ti])*ke,0)
		local hz=math.max((28+10*G.gk[ti]+4*math.sin(t*6+ti))*ke,0)
		orb[ti].Size=UDim2.fromOffset(oz,oz)
		orbHalo[ti].Size=UDim2.fromOffset(hz,hz)
		orbHalo[ti].BackgroundTransparency=1-(0.25+0.2*G.gk[ti])*ke*(0.4+0.6*on)
	end

	-- readouts
	local lt=1-math.clamp((ap-0.5)/0.3,0,1)
	for ti=1,3 do
		local v=math.floor(pl[KEYS[ti]]+0.5)
		if v~=G.txt[ti] then
			G.txt[ti]=v
			lbl[ti].Text=ABB[ti].." "..v
		end
		lbl[ti].TextTransparency=lt
	end
	local st=pl.on and 1 or 0
	if st~=G.st then
		G.st=st
		stL.Text=pl.on and "MODS ON" or "MODS OFF"
		stL.TextColor3=pl.on and COL[2] or C.Muted
	end
	stL.TextTransparency=lt
end

local function open(tok)
	root.Visible=true
	G.apT=1
	G.flash=1
	G.dv={0,0,0}
	G.txt={"","",""}
	G.st=-1
	Q.fx(4)
	sfx("whoosh",0.4,1.3)
	sfx("ping",0.35,1.0)
	task.delay(0.6,function()
		if Q.mode==4 and Q.tok==tok then Q.showHint("qf_hint4") end
	end)
	task.delay(4.6,function()
		if Q.tok==tok then Q.hideHint() end
	end)
end

Q.D[4]={root=root,scale=sc,gapDir=90,gapHalf=50,frame=frame,open=open,
	close=function() G.apT=0 end,
	tap=function()
		if S.setPlOn then S.setPlOn(not pl.on) end
	end,
	ring=function(f,tube)
		tube=tube or 1
		local key=KEYS[tube]
		if S.setPl then S.setPl(key,pl.lo[key]+f*(pl.hi[key]-pl.lo[key])) end
		Q.tickSfx(f)
	end,
	getF=function(tube)
		local key=KEYS[tube or 1]
		return math.clamp((pl[key]-pl.lo[key])/(pl.hi[key]-pl.lo[key]),0,1)
	end,
	-- hold + slide: the distance from the middle chooses the tube
	tubeAt=function(rad)
		if rad>=70 then return 1 end
		if rad>=58 then return 2 end
		return 3
	end}

-- player mods on/off feedback (called from S.setPlOn)
function S.onPlState(on)
	G.flash=1
	if Q.mode==4 then
		local p=Q.pal(4)
		local mid=UDim2.fromScale(0.5,0.5)
		shockwave(Q.chg,mid,50,on and 270 or 160,3,0.7,0,p)
		burst(Q.chg,mid,on and 22 or 10,p,on and 100 or 70)
	end
end
end -- [E:dial4]


------------------------------------------------ show / hide + float switch + input
local visTok=0
local function setUiVisible(v)
	if v==uiVisible or not revealed or closing or not alive then return end
	uiVisible=v
	visTok=visTok+1
	local tok=visTok
	local h=minimized and H_MIN or H_OPEN
	if v then
		anchor.Visible=true
		tween(main,0.45,{Size=UDim2.fromOffset(W,h),BackgroundTransparency=0.04},Enum.EasingStyle.Back)
		tween(mainStroke,0.35,{Transparency=flying and 0 or 0.35})
		tween(fbStroke,0.3,{Transparency=0.05})
		sfx("switch",0.4,1.3)
	else
		tween(main,0.3,{Size=UDim2.fromOffset(W,0),BackgroundTransparency=1},Enum.EasingStyle.Quint,Enum.EasingDirection.In)
		tween(mainStroke,0.25,{Transparency=1})
		tween(fbStroke,0.3,{Transparency=0.55})
		sfx("switch",0.4,0.8)
		task.delay(0.32,function()
			if tok==visTok and not uiVisible then anchor.Visible=false end
		end)
	end
end

function setFloat(on)
	floatOn=on
	if not on then Q.closeDial() end
	if not revealed then return end
	if on then
		fb.Visible=true
		tween(fbScale,0.45,{Scale=1},Enum.EasingStyle.Back)
	else
		tween(fbScale,0.25,{Scale=0},Enum.EasingStyle.Quint,Enum.EasingDirection.In)
		task.delay(0.28,function()
			if not floatOn then fb.Visible=false end
		end)
	end
end

-- press handling:
--   quick tap  = hide / show the window  (or the dial's action while a dial is open:
--                fly on/off, lock on/off, ESP on/off)
--   hold       = next dial: Fly -> Combat -> Visual -> Player -> closed  (the charge ring fills first)
--   drag       = move the button
local fbDrag,fbMoved,fbLong,fbStart,fbPos0=false,false,false,nil,nil
local function longPress(i)
	Q.chargeSnap()
	Q.setMode((Q.mode+1)%5)
	if Q.mode~=0 then
		-- keep the finger down and slide in a circle to change the value
		Q.rg=true
		Q.rgMode="slide"
		Q.rgIn=i
		Q.rgP0=i.Position
		Q.lastF=Q.D[Q.mode].getF()
	end
end

fbBtn.InputBegan:Connect(function(i)
	if isPress(i) and not fbDrag then
		fbDrag=true fbMoved=false fbLong=false fbStart=i.Position fbPos0=fb.Position
		Q.hTok=Q.hTok+1
		local tok=Q.hTok
		Q.chargeStart()
		tween(fbScale,0.12,{Scale=restScale()*0.88})
		task.delay(HOLD,function()
			if tok==Q.hTok and fbDrag and not fbMoved and not fbLong and alive then
				fbLong=true
				longPress(i)
			end
		end)
		i.Changed:Connect(function()
			if i.UserInputState==Enum.UserInputState.End then
				fbDrag=false
				Q.hTok=Q.hTok+1
				Q.chargeCancel()
				if Q.rgMode=="slide" then Q.rgEnd() end
				tween(fbScale,0.25,{Scale=restScale()},Enum.EasingStyle.Back)
				if not fbMoved and not fbLong then
					sfx("click",0.35,1.2)
					if Q.open then
						local d=Q.D[Q.mode]
						if d and d.tap then d.tap() end
					else
						setUiVisible(not uiVisible)
					end
				end
			end
		end)
	end
end)

connect(UIS.InputChanged,function(i)
	-- dragging the button
	if fbDrag and not fbLong and isMove(i) then
		local d=i.Position-fbStart
		if not fbMoved and d.Magnitude>6 then
			fbMoved=true
			Q.chargeCancel()
		end
		if fbMoved then
			local nx,ny=Q.clampFb(fbPos0.X.Offset+d.X,fbPos0.Y.Offset+d.Y)
			fb.Position=UDim2.fromOffset(nx,ny)
		end
	end
	-- dragging around the ring
	if Q.rg and isMove(i) then
		local d=Vector2.new(i.Position.X-Q.rgP0.X,i.Position.Y-Q.rgP0.Y)
		if Q.rgMode=="ring" then
			local c=Vector2.new(fb.Position.X.Offset,fb.Position.Y.Offset)
			Q.ringTo(Q.rgG0+d-c)
		elseif d.Magnitude>24 then
			Q.ringTo(d)
		end
	end
end)

-- per-frame: everything that follows the button + the dial animations
connect(RunService.RenderStepped,function(dt)
	local t=os.clock()
	Q.chg.Position=fb.Position
	if Q.charging then Q.chargeUpdate() end
	for m=1,4 do
		local d=Q.D[m]
		d.root.Position=fb.Position
		if d.root.Visible then d.frame(t,dt) end
	end
end)

fbBtn.MouseEnter:Connect(function()
	if UIS.MouseEnabled and not fbDrag and fbScale.Scale>0.5 then
		tween(fbScale,0.15,{Scale=restScale()*1.1})
		sfx("tick",0.1,1.8)
	end
end)
fbBtn.MouseLeave:Connect(function()
	if not fbDrag and fbScale.Scale>0.5 then tween(fbScale,0.15,{Scale=restScale()}) end
end)

-- keyboard shortcut
connect(UIS.InputBegan,function(i,gp)
	if gp then return end
	if i.KeyCode==Enum.KeyCode.RightShift then
		setUiVisible(not uiVisible)
	end
end)
end -- [E:float]


-------------------------------------------------- FILES  (executor workspace folders + GitHub downloads)
-- workspace/XyclopXR/Music              <- put your .mp3 / .ogg songs here (the music player scans it)
-- workspace/XyclopXR/DvplPF/Profile.png <- maker picture shown on the Credits page
-- Both folders are created automatically and filled from GitHub the first time the script runs.
do -- [S:files]
local DIR="XyclopXR"
local RAW="https://raw.githubusercontent.com/bosslovecheese085-bit/XyclopXR/main/"
S.fs={
	dir=DIR,music=DIR.."/Music",pfDir=DIR.."/DvplPF",pf=DIR.."/DvplPF/Profile.png",
	pfUrl=RAW.."DvplPF/Profile.png",keepUrl=RAW.."music/.gitkeep",ready=false}

-- body of an URL (may be an empty string) or nil when the request failed
function S.http(url)
	local ok,res=pcall(function()
		local req=(syn and syn.request) or http_request or request or (fluxus and fluxus.request)
		if req then
			local r=req({Url=url,Method="GET"})
			if r and (r.StatusCode==nil or r.StatusCode==200) then return r.Body end
			return nil
		end
		return game:HttpGet(url)
	end)
	if ok and type(res)=="string" then return res end
	return nil
end
-- local file -> content id that a Sound / ImageLabel can use (nil when the executor cannot do it)
function S.asset(path)
	local fn=getcustomasset or getsynasset
	if not fn then return nil end
	local ok,res=pcall(fn,path)
	if ok and type(res)=="string" and #res>0 then return res end
	return nil
end
function S.hasFile(path)
	local ok,res=pcall(function() return isfile and isfile(path) end)
	return ok and res==true
end
local function ensureDir(p)
	pcall(function()
		if isfolder and makefolder and not isfolder(p) then makefolder(p) end
	end)
end

task.spawn(function()
	ensureDir(DIR)
	ensureDir(S.fs.music)
	ensureDir(S.fs.pfDir)
	if writefile and isfile then
		-- the music folder placeholder comes from the GitHub repo (music/.gitkeep)
		if not S.hasFile(S.fs.music.."/.gitkeep") then
			local b=S.http(S.fs.keepUrl)
			if b then pcall(writefile,S.fs.music.."/.gitkeep",b) end
		end
		-- the profile picture: downloaded, and replaced when the repo has a newer one
		local b=S.http(S.fs.pfUrl)
		if b and #b>100 then
			local same=false
			if S.hasFile(S.fs.pf) then
				local ok,old=pcall(readfile,S.fs.pf)
				same=(ok and old==b)
			end
			if not same then pcall(writefile,S.fs.pf,b) end
		end
	end
	S.fs.ready=true
	if S.onFilesReady then S.onFilesReady() end
end)
end -- [E:S:files]

-------------------------------------------------- PAGES
local pagesHolder=new("Frame",{Position=UDim2.fromOffset(0,H_MIN+1),Size=UDim2.fromOffset(W,H_OPEN-H_MIN-1-TAB_H),BackgroundTransparency=1,BorderSizePixel=0,ClipsDescendants=true,ZIndex=2},win)
local flyPage=new("Frame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0},pagesHolder)
local setPage=new("ScrollingFrame",{
	Position=UDim2.fromScale(1,0),Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0,
	ScrollBarThickness=3,ScrollBarImageColor3=C.White,ScrollBarImageTransparency=0.6,
	CanvasSize=UDim2.new(0,0,0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollingDirection=Enum.ScrollingDirection.Y},pagesHolder)
new("UIListLayout",{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder,HorizontalAlignment=Enum.HorizontalAlignment.Center},setPage)
new("UIPadding",{PaddingTop=UDim.new(0,10),PaddingBottom=UDim.new(0,12)},setPage)

local pages={}
pages[2]=flyPage
pages[8]=setPage

-------------------------------------------------- HOME PAGE
-- (block-scoped: nothing in here is needed outside; it registers itself as page 1)
do -- [S:home]
local homePage=new("ScrollingFrame",{
	Position=UDim2.fromScale(0,0),Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0,
	ScrollBarThickness=3,ScrollBarImageColor3=C.White,ScrollBarImageTransparency=0.6,
	CanvasSize=UDim2.new(0,0,0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollingDirection=Enum.ScrollingDirection.Y},pagesHolder)
pages[1]=homePage

local GREEN,YELLOW,RED=Color3.fromRGB(110,255,170),Color3.fromRGB(255,214,70),Color3.fromRGB(255,96,110)

-- profile card: avatar + name + id/account age
local prof=card(homePage,76,10)
local avRing=new("Frame",{Position=UDim2.fromOffset(12,10),Size=UDim2.fromOffset(56,56),BackgroundTransparency=1,BorderSizePixel=0},prof)
corner(avRing,999)
local avStroke=stroke(avRing,C.White,2.5,0)
local avG=new("UIGradient",{},avStroke)
onTheme(function()
	avG.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,T.A1),ColorSequenceKeypoint.new(0.5,T.A2),ColorSequenceKeypoint.new(1,T.A1)})
end)
local avatar=new("ImageLabel",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.new(1,-9,1,-9),BackgroundColor3=C.Off,BorderSizePixel=0,Image="",ImageTransparency=1,ScaleType=Enum.ScaleType.Crop},avRing)
corner(avatar,999)
local online=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(1,-6,1,-6),Size=UDim2.fromOffset(12,12),BackgroundColor3=GREEN,BorderSizePixel=0,ZIndex=3},avRing)
corner(online,999)
stroke(online,C.Ink,2,0)
task.spawn(function()
	local ok,img=pcall(function()
		return Players:GetUserThumbnailAsync(player.UserId,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size150x150)
	end)
	if ok and type(img)=="string" and avatar.Parent then
		avatar.Image=img
		tween(avatar,0.4,{ImageTransparency=0})
	end
end)
bindText(label({Position=UDim2.fromOffset(80,8),Size=UDim2.fromOffset(224,12),Text="",TextSize=10,Font=Enum.Font.Gotham,TextColor3=C.Muted,TextXAlignment=Enum.TextXAlignment.Left},prof),"welcome")
local nameLbl=label({Position=UDim2.fromOffset(80,19),Size=UDim2.fromOffset(224,22),Text=player.DisplayName,TextSize=17,Font=Enum.Font.GothamBlack,TextColor3=C.White,TextXAlignment=Enum.TextXAlignment.Left},prof)
tgrad(nameLbl,0)
label({Position=UDim2.fromOffset(80,41),Size=UDim2.fromOffset(224,14),Text="@"..player.Name,TextSize=11,Font=Enum.Font.Gotham,TextColor3=C.Text,TextXAlignment=Enum.TextXAlignment.Left},prof)
local metaLbl=label({Position=UDim2.fromOffset(80,56),Size=UDim2.fromOffset(224,14),Text="",TextSize=10,Font=Enum.Font.Gotham,TextColor3=C.Muted,TextXAlignment=Enum.TextXAlignment.Left},prof)
onLang(function() metaLbl.Text="ID "..player.UserId.."  ·  "..player.AccountAge.." "..tr("days") end)

-- stat cards (player on the left, server on the right)
local function statCard(x,key,rowKeys)
	local f=new("Frame",{Position=UDim2.fromOffset(x,92),Size=UDim2.fromOffset(154,133),BackgroundColor3=C.White,BackgroundTransparency=0.95,BorderSizePixel=0},homePage)
	corner(f,12) stroke(f,C.White,1,0.92)
	local hd=bindText(label({Position=UDim2.fromOffset(12,5),Size=UDim2.fromOffset(80,16),Text="",TextSize=12,Font=Enum.Font.GothamBlack,TextColor3=C.White,TextXAlignment=Enum.TextXAlignment.Left},f),key)
	tgrad(hd,0)
	local vals={}
	for n,rk in ipairs(rowKeys) do
		local y=24+(n-1)*17
		bindText(label({Position=UDim2.fromOffset(12,y),Size=UDim2.fromOffset(62,16),Text="",TextSize=10,Font=Enum.Font.Gotham,TextColor3=C.Muted,TextXAlignment=Enum.TextXAlignment.Left},f),rk)
		vals[n]=label({AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-10,0,y),Size=UDim2.fromOffset(76,16),Text="–",TextSize=11,TextColor3=C.Text,TextXAlignment=Enum.TextXAlignment.Right},f)
	end
	return vals,f
end
local pv=statCard(12,"grp_player",{"st_health","st_walk","st_jump","st_height","speed","st_flyspd"})
local sv,svCard=statCard(174,"grp_server",{"sv_players","sv_uptime","sv_ping","sv_fps","sv_mem","sv_place"})
sv[6].TextSize=9
local gameLbl=label({AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-10,0,8),Size=UDim2.fromOffset(70,12),Text="",TextSize=9,Font=Enum.Font.Gotham,TextColor3=C.Muted,TextXAlignment=Enum.TextXAlignment.Right},svCard)
task.spawn(function()
	local ok,info=pcall(function() return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId) end)
	if ok and type(info)=="table" and type(info.Name)=="string" and gameLbl.Parent then gameLbl.Text=info.Name end
end)

local function fmtTime(s)
	s=math.floor(s)
	return string.format("%d:%02d:%02d",math.floor(s/3600),math.floor(s/60)%60,s%60)
end

local StatsSvc=game:GetService("Stats")
local frames,fpsT=0,os.clock()
connect(RunService.RenderStepped,function()
	frames=frames+1
	if activeTab==1 and uiVisible and not minimized then
		avG.Rotation=(os.clock()*70)%360
	end
end)

local function refresh()
	local now=os.clock()
	local fps=frames/math.max(now-fpsT,0.001)
	frames=0
	fpsT=now
	-- player
	local ch=player.Character
	local hrp=ch and ch:FindFirstChild("HumanoidRootPart")
	local hum=ch and ch:FindFirstChildOfClass("Humanoid")
	if hum then
		local hp,mhp=hum.Health,math.max(hum.MaxHealth,1)
		local r=hp/mhp
		pv[1].Text=math.floor(hp+0.5).."/"..math.floor(mhp+0.5)
		pv[1].TextColor3=(r>0.6) and GREEN or ((r>0.3) and YELLOW or RED)
		pv[2].Text=tostring(math.floor(hum.WalkSpeed*10+0.5)/10)
		pv[3].Text=tostring(math.floor((hum.UseJumpPower and hum.JumpPower or hum.JumpHeight)*10+0.5)/10)
	else
		for k=1,3 do pv[k].Text="–" pv[k].TextColor3=C.Text end
	end
	if hrp then
		pv[4].Text=math.floor(hrp.Position.Y+0.5).." st"
		pv[5].Text=math.floor(hrp.AssemblyLinearVelocity.Magnitude+0.5).." st/s"
	else
		pv[4].Text="–"
		pv[5].Text="–"
	end
	pv[6].Text=speed.." st/s"
	-- server
	sv[1].Text=#Players:GetPlayers().."/"..Players.MaxPlayers
	sv[2].Text=fmtTime(workspace.DistributedGameTime)
	local okp,ping=pcall(function() return StatsSvc.Network.ServerStatsItem["Data Ping"]:GetValue() end)
	if not okp or type(ping)~="number" then ping=player:GetNetworkPing()*2000 end
	sv[3].Text=math.floor(ping+0.5).." ms"
	sv[3].TextColor3=(ping<90) and GREEN or ((ping<180) and YELLOW or RED)
	sv[4].Text=tostring(math.floor(fps+0.5))
	sv[4].TextColor3=(fps>=50) and GREEN or ((fps>=30) and YELLOW or RED)
	local okm,mem=pcall(function() return StatsSvc:GetTotalMemoryUsageMb() end)
	sv[5].Text=(okm and type(mem)=="number") and (math.floor(mem+0.5).." MB") or "–"
	sv[6].Text=tostring(game.PlaceId)
end

task.spawn(function()
	while alive do
		if activeTab==1 and uiVisible and not minimized then
			pcall(refresh)
		else
			frames=0
			fpsT=os.clock()
		end
		task.wait(0.5)
	end
end)
end -- [E:home]

-------------------------------------------------- FLY PAGE
local flyCard=card(flyPage,56,10)
local dot=new("Frame",{Size=UDim2.fromOffset(8,8),Position=UDim2.new(0,20,0.5,0),AnchorPoint=Vector2.new(0.5,0.5),BackgroundColor3=C.Off,BorderSizePixel=0},flyCard)
corner(dot,999)
bindText(label({Position=UDim2.fromOffset(34,10),Size=UDim2.fromOffset(170,18),Text="",TextSize=14,TextXAlignment=Enum.TextXAlignment.Left},flyCard),"fly_mode")
local statusLbl=label({Position=UDim2.fromOffset(34,28),Size=UDim2.fromOffset(170,16),Text="",TextSize=11,Font=Enum.Font.Gotham,TextColor3=C.Muted,TextXAlignment=Enum.TextXAlignment.Left},flyCard)
onLang(function() statusLbl.Text=flying and tr("on") or tr("off") end)
onTheme(function()
	dot.BackgroundColor3=flying and T.A1 or C.Off
	statusLbl.TextColor3=flying and T.A1 or C.Muted
end)
local flySwitch=makeSwitch(flyCard,UDim2.new(1,-14,0.5,0),false)
local toggleBtn=new("TextButton",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Text="",AutoButtonColor=false,ClipsDescendants=true,ZIndex=2},flyCard)

local speedCard=card(flyPage,68,74)
bindText(label({Position=UDim2.fromOffset(16,10),Size=UDim2.fromOffset(150,16),Text="",TextSize=12,TextColor3=C.Muted,TextXAlignment=Enum.TextXAlignment.Left},speedCard),"speed")
local speedValue=label({AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-16,0,7),Size=UDim2.fromOffset(80,22),Text=tostring(speed),TextSize=18,Font=Enum.Font.GothamBlack,TextColor3=C.White,TextXAlignment=Enum.TextXAlignment.Right},speedCard)
tgrad(speedValue,0)
local lastTick=0
local function tickSfx(a)
	local now=os.clock()
	if now-lastTick<0.06 then return end
	lastTick=now
	sfx("tick",0.22,0.8+a*1.2)
end
S.speedSlider=makeSlider({parent=speedCard,x=16,y=46,width=W-24-32,min=MIN_SPEED,max=MAX_SPEED,value=speed,onChange=function(v,a)
	speed=v
	speedValue.Text=tostring(v)
	savePref("speed",v)
	tickSfx(a)
end})
-- used by the Quick Fly dial: changes the speed from outside and keeps this slider in sync
function S.setSpeed(v)
	v=math.clamp(math.floor(v+0.5),MIN_SPEED,MAX_SPEED)
	if v==speed then return end
	speed=v
	speedValue.Text=tostring(v)
	S.speedSlider.set(v,true)
	savePref("speed",v)
end

local infoCard=card(flyPage,58,150)
bindText(label({Position=UDim2.fromOffset(16,9),Size=UDim2.fromOffset(170,14),Text="",TextSize=11,TextColor3=C.Muted,TextXAlignment=Enum.TextXAlignment.Left},infoCard),"now")
local velLbl=label({Position=UDim2.fromOffset(16,24),Size=UDim2.fromOffset(180,26),Text="0 st/s",TextSize=20,Font=Enum.Font.GothamBlack,TextColor3=C.White,TextXAlignment=Enum.TextXAlignment.Left},infoCard)
tgrad(velLbl,0)
local function vertBtn(x,txt,dirv)
	local b=new("TextButton",{Position=UDim2.fromOffset(x,11),Size=UDim2.fromOffset(40,36),BackgroundColor3=C.White,BackgroundTransparency=0.9,Text=txt,TextSize=14,Font=Enum.Font.GothamBold,TextColor3=C.Text,AutoButtonColor=false,BorderSizePixel=0,ClipsDescendants=true},infoCard)
	corner(b,10)
	stroke(b,C.White,1,0.9)
	b.InputBegan:Connect(function(i)
		if isPress(i) then
			touchVert=dirv
			ripple(b,i)
			sfx("tick",0.3,dirv>0 and 1.4 or 0.9)
			tween(b,0.1,{BackgroundTransparency=0.7})
			i.Changed:Connect(function()
				if i.UserInputState==Enum.UserInputState.End then
					if touchVert==dirv then touchVert=0 end
					tween(b,0.15,{BackgroundTransparency=0.9})
				end
			end)
		end
	end)
	return b
end
vertBtn(212,"▲",1)
vertBtn(260,"▼",-1)

-------------------------------------------------- SETTINGS PAGE
-- (block-scoped: nothing in here is needed outside)
do -- [S:settings]
-- Language
local chips={}
local function paintChips(instant)
	for _,c in ipairs(chips) do
		local sel=(c.code==lang)
		local tp=sel and 0 or 1
		local tc=sel and C.Ink or C.Text
		if instant then
			c.fill.BackgroundTransparency=tp
			c.lbl.TextColor3=tc
		else
			tween(c.fill,0.25,{BackgroundTransparency=tp})
			tween(c.lbl,0.25,{TextColor3=tc})
		end
	end
end
local function setLang(code)
	if code==lang then return end
	lang=code
	savePref("lang",code)
	applyLang(true)
	paintChips(false)
	sfx("ping",0.35,1.3)
	for _,lg in ipairs(LANGS) do
		if lg.code==code then toast(lg.name) end
	end
end

local langCard=card(setPage,214,nil,1)
bindText(label({Position=UDim2.fromOffset(14,8),Size=UDim2.new(1,-28,0,18),Text="",TextSize=14,TextXAlignment=Enum.TextXAlignment.Left},langCard),"lang")
local langGrid=new("Frame",{Position=UDim2.fromOffset(8,32),Size=UDim2.fromOffset(300,174),BackgroundTransparency=1,BorderSizePixel=0},langCard)
new("UIGridLayout",{CellSize=UDim2.fromOffset(146,30),CellPadding=UDim2.fromOffset(8,6),SortOrder=Enum.SortOrder.LayoutOrder},langGrid)
for idx,lg in ipairs(LANGS) do
	local b=new("TextButton",{Name=lg.code,LayoutOrder=idx,BackgroundColor3=C.White,BackgroundTransparency=0.93,Text="",AutoButtonColor=false,BorderSizePixel=0,ClipsDescendants=true},langGrid)
	corner(b,10)
	local f=new("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0},b)
	corner(f,10) tgrad(f,0)
	local l=label({Size=UDim2.fromScale(1,1),Text=lg.name,TextSize=13,TextColor3=C.Text,ZIndex=2},b)
	table.insert(chips,{code=lg.code,fill=f,lbl=l})
	b.MouseEnter:Connect(function() if UIS.MouseEnabled then sfx("tick",0.1,1.8) end end)
	b.InputBegan:Connect(function(i)
		if isPress(i) then ripple(b,i) end
	end)
	b.Activated:Connect(function()
		sfx("click",0.4,1.1)
		setLang(lg.code)
	end)
end
paintChips(true)

-- Theme colors
local swatches={}
local function paintSwatches(instant)
	for n,s in ipairs(swatches) do
		local sel=(themeIdx==n)
		local ringT=sel and 0 or 1
		local sz=sel and 34 or 30
		if instant then
			s.ring.Transparency=ringT
			s.dotF.Size=UDim2.fromOffset(sz,sz)
		else
			tween(s.ring,0.25,{Transparency=ringT})
			tween(s.dotF,0.3,{Size=UDim2.fromOffset(sz,sz)},Enum.EasingStyle.Back)
		end
	end
end
local hueSlider

local themeCard=card(setPage,240,nil,2)
bindText(label({Position=UDim2.fromOffset(14,8),Size=UDim2.new(1,-28,0,18),Text="",TextSize=14,TextXAlignment=Enum.TextXAlignment.Left},themeCard),"theme")
local swGrid=new("Frame",{Position=UDim2.fromOffset(8,32),Size=UDim2.fromOffset(300,98),BackgroundTransparency=1,BorderSizePixel=0},themeCard)
new("UIGridLayout",{CellSize=UDim2.fromOffset(44,44),CellPadding=UDim2.fromOffset(41,10),SortOrder=Enum.SortOrder.LayoutOrder,HorizontalAlignment=Enum.HorizontalAlignment.Center},swGrid)
for n,th in ipairs(THEMES) do
	local holder=new("TextButton",{LayoutOrder=n,BackgroundTransparency=1,Text="",AutoButtonColor=false,BorderSizePixel=0},swGrid)
	local ringF=new("Frame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0},holder)
	corner(ringF,999)
	local ring=stroke(ringF,C.White,2,1)
	local dotF=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(30,30),BackgroundColor3=C.White,BorderSizePixel=0},holder)
	corner(dotF,999)
	grad(dotF,th[2],th[3],45)
	table.insert(swatches,{ring=ring,dotF=dotF})
	holder.Activated:Connect(function()
		sfx("click",0.4,1.2)
		if S.rainbow then S.setRainbow(false,true,true) end
		themeIdx=n
		savePref("theme",n)
		paintSwatches(false)
		setTheme(th[2],th[3])
		local h=th[2]:ToHSV()
		if hueSlider then hueSlider.set(h*360,true) end
		toast(th[1])
	end)
end
paintSwatches(true)

bindText(label({Position=UDim2.fromOffset(16,140),Size=UDim2.fromOffset(200,16),Text="",TextSize=12,TextColor3=C.Muted,TextXAlignment=Enum.TextXAlignment.Left},themeCard),"hue")
local startHue=pref("hue",190)
if themeIdx>=1 and THEMES[themeIdx] then startHue=THEMES[themeIdx][2]:ToHSV()*360 end
hueSlider=makeSlider({parent=themeCard,x=16,y=174,width=W-24-32,min=0,max=360,value=startHue,rainbow=true,scroller=setPage,onChange=function(v)
	if S.rainbow then S.setRainbow(false,true,true) end
	themeIdx=0
	savePref("theme",0)
	savePref("hue",v)
	paintSwatches(false)
	local a1,a2=hueColors(v)
	setTheme(a1,a2,true)
	tickSfx(v/360)
end})

-- Rainbow theme: the theme colors cycle through the whole spectrum
local rbSwitch
do
	bindText(label({AnchorPoint=Vector2.new(0,0.5),Position=UDim2.fromOffset(16,216),Size=UDim2.fromOffset(190,18),Text="",TextSize=13,TextXAlignment=Enum.TextXAlignment.Left},themeCard),"rainbow")
	rbSwitch=makeSwitch(themeCard,UDim2.new(1,-14,0,216),S.rainbow)
	local rbBtn=new("TextButton",{Position=UDim2.fromOffset(0,198),Size=UDim2.new(1,0,0,36),BackgroundTransparency=1,Text="",AutoButtonColor=false,ClipsDescendants=true},themeCard)
	rbBtn.InputBegan:Connect(function(i) if isPress(i) then ripple(rbBtn,i) end end)
	rbBtn.Activated:Connect(function() S.setRainbow(not S.rainbow) end)
end
function S.setRainbow(on,quiet,skipRestore)
	if S.rainbow==on then return end
	S.rainbow=on
	savePref("rainbow",on)
	rbSwitch.set(on)
	if not on and not skipRestore then
		if themeIdx>=1 and THEMES[themeIdx] then
			setTheme(THEMES[themeIdx][2],THEMES[themeIdx][3])
		else
			local c1,c2=hueColors(pref("hue",190))
			setTheme(c1,c2)
		end
	end
	if not quiet then sfx("switch",0.6,on and 1.25 or 0.8) end
end
local rbAcc=0
connect(RunService.RenderStepped,function(dt)
	if not S.rainbow then return end
	local h=(os.clock()*42)%360
	T.A1=Color3.fromHSV(h/360,0.85,1)
	T.A2=Color3.fromHSV(((h+60)%360)/360,0.8,1)
	rbAcc=rbAcc+dt
	if rbAcc>0.05 then
		rbAcc=0
		applyTheme()
	end
end)

-- Sound & effects
local fxCard=card(setPage,172,nil,3)
bindText(label({Position=UDim2.fromOffset(14,8),Size=UDim2.new(1,-28,0,18),Text="",TextSize=14,TextXAlignment=Enum.TextXAlignment.Left},fxCard),"grp_fx")

bindText(label({AnchorPoint=Vector2.new(0,0.5),Position=UDim2.fromOffset(16,50),Size=UDim2.fromOffset(190,18),Text="",TextSize=13,TextXAlignment=Enum.TextXAlignment.Left},fxCard),"sfx")
local sfxSwitch=makeSwitch(fxCard,UDim2.new(1,-14,0,50),S.sfx)
local sfxBtn=new("TextButton",{Position=UDim2.fromOffset(0,32),Size=UDim2.new(1,0,0,36),BackgroundTransparency=1,Text="",AutoButtonColor=false,ClipsDescendants=true},fxCard)
sfxBtn.InputBegan:Connect(function(i) if isPress(i) then ripple(sfxBtn,i) end end)
sfxBtn.Activated:Connect(function()
	if S.sfx then sfx("switch",0.6,0.8) end
	S.sfx=not S.sfx
	sfxSwitch.set(S.sfx)
	savePref("sfx",S.sfx)
	if S.sfx then sfx("switch",0.6,1.25) end
end)

bindText(label({AnchorPoint=Vector2.new(0,0.5),Position=UDim2.fromOffset(16,82),Size=UDim2.fromOffset(150,16),Text="",TextSize=12,TextColor3=C.Muted,TextXAlignment=Enum.TextXAlignment.Left},fxCard),"volume")
local volLbl=label({AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-16,0,82),Size=UDim2.fromOffset(60,18),Text=S.volume.."%",TextSize=13,Font=Enum.Font.GothamBlack,TextColor3=C.White,TextXAlignment=Enum.TextXAlignment.Right},fxCard)
tgrad(volLbl,0)
makeSlider({parent=fxCard,x=16,y=106,width=W-24-32,min=0,max=100,value=S.volume,scroller=setPage,onChange=function(v,a)
	S.volume=v
	volLbl.Text=v.."%"
	savePref("vol",v)
	tickSfx(a)
end})

bindText(label({AnchorPoint=Vector2.new(0,0.5),Position=UDim2.fromOffset(16,142),Size=UDim2.fromOffset(190,18),Text="",TextSize=13,TextXAlignment=Enum.TextXAlignment.Left},fxCard),"vfx")
local vfxSwitch=makeSwitch(fxCard,UDim2.new(1,-14,0,142),S.vfx)
local vfxBtn=new("TextButton",{Position=UDim2.fromOffset(0,124),Size=UDim2.new(1,0,0,36),BackgroundTransparency=1,Text="",AutoButtonColor=false,ClipsDescendants=true},fxCard)
vfxBtn.InputBegan:Connect(function(i) if isPress(i) then ripple(vfxBtn,i) end end)
vfxBtn.Activated:Connect(function()
	S.vfx=not S.vfx
	vfxSwitch.set(S.vfx)
	savePref("vfx",S.vfx)
	sfx("switch",0.6,S.vfx and 1.25 or 0.8)
end)

-- Loading screen style (5 styles) + preview
local ldCard=card(setPage,148,nil,4)
bindText(label({Position=UDim2.fromOffset(14,8),Size=UDim2.new(1,-28,0,18),Text="",TextSize=14,TextXAlignment=Enum.TextXAlignment.Left},ldCard),"grp_load")
local ldGrid=new("Frame",{Position=UDim2.fromOffset(8,32),Size=UDim2.fromOffset(300,106),BackgroundTransparency=1,BorderSizePixel=0},ldCard)
new("UIGridLayout",{CellSize=UDim2.fromOffset(146,30),CellPadding=UDim2.fromOffset(8,6),SortOrder=Enum.SortOrder.LayoutOrder},ldGrid)
local ldChips={}
local function paintLd(instant)
	for _,c in ipairs(ldChips) do
		local sel=(c.idx==loaderStyle)
		local tp=sel and 0 or 1
		local tc=sel and C.Ink or C.Text
		if instant then
			c.fill.BackgroundTransparency=tp
			c.lbl.TextColor3=tc
		else
			tween(c.fill,0.25,{BackgroundTransparency=tp})
			tween(c.lbl,0.25,{TextColor3=tc})
		end
	end
end
for idx,st in ipairs(LSTYLES) do
	local b=new("TextButton",{Name="ld"..idx,LayoutOrder=idx,BackgroundColor3=C.White,BackgroundTransparency=0.93,Text="",AutoButtonColor=false,BorderSizePixel=0,ClipsDescendants=true},ldGrid)
	corner(b,10)
	local f=new("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0},b)
	corner(f,10) tgrad(f,0)
	local dotc=new("Frame",{AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,10,0.5,0),Size=UDim2.fromOffset(12,12),BackgroundColor3=C.White,BorderSizePixel=0,ZIndex=2},b)
	corner(dotc,999) grad(dotc,st.P.a1,st.P.a2,45)
	local l=label({Position=UDim2.fromOffset(28,0),Size=UDim2.new(1,-32,1,0),Text=st.name,TextSize=12,TextColor3=C.Text,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=2},b)
	table.insert(ldChips,{idx=idx,fill=f,lbl=l})
	b.MouseEnter:Connect(function() if UIS.MouseEnabled then sfx("tick",0.1,1.8) end end)
	b.InputBegan:Connect(function(i)
		if isPress(i) then ripple(b,i) end
	end)
	b.Activated:Connect(function()
		sfx("click",0.4,1.1)
		if loaderStyle~=idx then
			loaderStyle=idx
			savePref("loader",idx)
			paintLd(false)
			toast(st.name)
		end
	end)
end
paintLd(true)

local pvBtn=new("TextButton",{Name="ldPreview",LayoutOrder=#LSTYLES+1,BackgroundColor3=C.White,BackgroundTransparency=0.93,Text="",AutoButtonColor=false,BorderSizePixel=0,ClipsDescendants=true},ldGrid)
corner(pvBtn,10)
local pvFill=new("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=C.White,BackgroundTransparency=0.15,BorderSizePixel=0},pvBtn)
corner(pvFill,10) tgrad(pvFill,0)
local pvLbl=label({Size=UDim2.fromScale(1,1),Text="",TextSize=13,TextColor3=C.Ink,ZIndex=2},pvBtn)
onLang(function() pvLbl.Text="▶  "..tr("preview") end)
pvBtn.InputBegan:Connect(function(i)
	if isPress(i) then ripple(pvBtn,i) end
end)
pvBtn.Activated:Connect(function()
	if loadGui or not runLoader then return end
	sfx("click",0.4,1.3)
	task.spawn(function()
		local ok,err=pcall(runLoader,loaderStyle,true)
		if not ok then
			warn("[NeonFly] preview error: "..tostring(err))
			if loadConn then loadConn:Disconnect() loadConn=nil end
			if loadGui then loadGui:Destroy() loadGui=nil end
			if blurFx then blurFx:Destroy() blurFx=nil end
		end
	end)
end)

-- Interface (floating button on/off)
local uiCard=card(setPage,78,nil,5)
bindText(label({Position=UDim2.fromOffset(14,8),Size=UDim2.new(1,-28,0,18),Text="",TextSize=14,TextXAlignment=Enum.TextXAlignment.Left},uiCard),"grp_ui")
bindText(label({AnchorPoint=Vector2.new(0,0.5),Position=UDim2.fromOffset(16,50),Size=UDim2.fromOffset(190,18),Text="",TextSize=13,TextXAlignment=Enum.TextXAlignment.Left},uiCard),"float")
local floatSwitch=makeSwitch(uiCard,UDim2.new(1,-14,0,50),floatOn)
local floatBtn=new("TextButton",{Position=UDim2.fromOffset(0,32),Size=UDim2.new(1,0,0,36),BackgroundTransparency=1,Text="",AutoButtonColor=false,ClipsDescendants=true},uiCard)
floatBtn.InputBegan:Connect(function(i) if isPress(i) then ripple(floatBtn,i) end end)
floatBtn.Activated:Connect(function()
	sfx("switch",0.6,floatOn and 0.8 or 1.25)
	setFloat(not floatOn)
	floatSwitch.set(floatOn)
	savePref("float",floatOn)
end)

label({Size=UDim2.fromOffset(W-24,18),Text="Xyclop Ultimate  ·  v2.6",TextSize=10,Font=Enum.Font.Gotham,TextColor3=C.Muted,LayoutOrder=9},setPage)
end -- [E:settings]

-------------------------------------------------- CREDITS PAGE  (maker profile picture + cinematic intro)
-- The picture is read from  workspace/XyclopXR/DvplPF/Profile.png  (downloaded from GitHub by the files block).
-- Without it (or without getcustomasset) the animated X emblem is shown instead.
-- (block-scoped: only creditsPage, crEmb, crStrokeGrad and crPlay are needed outside)
local creditsPage,crEmb,crStrokeGrad,crPlay
do -- [S:credits]
creditsPage=new("Frame",{Position=UDim2.fromScale(9,0),Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0},pagesHolder)
pages[10]=creditsPage
local CW,CH=W-24,H_OPEN-H_MIN-1-TAB_H-20
local AX,AY=CW/2,76                         -- center of the picture
local crCard=new("CanvasGroup",{Position=UDim2.fromOffset(12,10),Size=UDim2.fromOffset(CW,CH),BackgroundColor3=C.White,BackgroundTransparency=0,BorderSizePixel=0},creditsPage)
corner(crCard,16)
grad(crCard,Color3.fromRGB(22,24,48),Color3.fromRGB(7,8,16),90)
local crStroke=stroke(crCard,C.White,1.5,0.2)
crStrokeGrad=new("UIGradient",{},crStroke)
onTheme(function()
	crStrokeGrad.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,T.A1),ColorSequenceKeypoint.new(0.5,T.A2),ColorSequenceKeypoint.new(1,T.A1)})
end)

local function eb(x) -- easeOutBack
	x=math.clamp(x,0,1)-1
	return 1+2.70158*x*x*x+1.70158*x*x
end

-- progress values of the intro (all drawn in update); anim() moves one of them smoothly
local K={ray=0,glow=0,tick=0,ring=0,pic=0,orb=0,flash=0}
local kTok=0
local function anim(key,to,dur,delay,back)
	local my=kTok
	task.spawn(function()
		if delay and delay>0 then task.wait(delay) end
		if my~=kTok or not alive then return end
		local from=K[key]
		local t0=os.clock()
		while alive and my==kTok do
			local a=math.clamp((os.clock()-t0)/dur,0,1)
			local e=back and eb(a) or (1-(1-a)*(1-a))
			K[key]=from+(to-from)*e
			if a>=1 then break end
			RunService.RenderStepped:Wait()
		end
	end)
end

------------------------------------------------ background: aurora, stars, rays
do
local function blob(x,y,d,rot,dx,dy,dur)
	local h=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(d,d),BackgroundTransparency=1,BorderSizePixel=0},crCard)
	for k=1,3 do
		local s=d*(1-(k-1)*0.28)
		local c=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(s,s),BackgroundColor3=C.White,BackgroundTransparency=0.93-(k-1)*0.02,BorderSizePixel=0},h)
		corner(c,999) tgrad(c,rot)
	end
	TS:Create(h,TweenInfo.new(dur,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{Position=UDim2.fromOffset(x+dx,y+dy)}):Play()
end
blob(30,190,200,45,40,-24,6)
blob(300,24,170,225,-34,26,7)
blob(200,230,150,135,-40,-16,8)
-- twinkling stars
for n=1,26 do
	task.spawn(function()
		local rnd=Random.new(n*53+9)
		local sz=rnd:NextInteger(1,3)
		local d=new("Frame",{Position=UDim2.fromOffset(rnd:NextInteger(6,CW-6),rnd:NextInteger(4,CH-6)),Size=UDim2.fromOffset(sz,sz),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0},crCard)
		corner(d,999)
		task.wait(rnd:NextNumber(0,3))
		while alive and d.Parent do
			tween(d,rnd:NextNumber(0.7,1.4),{BackgroundTransparency=rnd:NextNumber(0.15,0.55)})
			task.wait(rnd:NextNumber(1.2,2.4))
			tween(d,rnd:NextNumber(0.7,1.4),{BackgroundTransparency=0.95})
			task.wait(rnd:NextNumber(1.2,2.4))
		end
	end)
end
-- rising sparkles
for n=1,9 do
	task.spawn(function()
		local rnd=Random.new(n*47+5)
		local sz=rnd:NextInteger(2,4)
		local d=new("Frame",{Size=UDim2.fromOffset(sz,sz),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0},crCard)
		corner(d,999) tgrad(d,0)
		task.wait(rnd:NextNumber(0,3))
		while alive and d.Parent do
			local x=rnd:NextNumber(0.05,0.95)
			local dur=rnd:NextNumber(4,8)
			d.Position=UDim2.fromScale(x,1.03)
			d.BackgroundTransparency=1
			tween(d,dur,{Position=UDim2.fromScale(x+rnd:NextNumber(-0.06,0.06),-0.03)},Enum.EasingStyle.Linear)
			tween(d,dur*0.25,{BackgroundTransparency=rnd:NextNumber(0.4,0.7)})
			task.wait(dur*0.75)
			tween(d,dur*0.25,{BackgroundTransparency=1})
			task.wait(dur*0.25)
		end
	end)
end
end

------------------------------------------------ the picture group
local av=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromOffset(AX,AY),Size=UDim2.fromOffset(4,4),BackgroundTransparency=1,BorderSizePixel=0},crCard)
local P={}      -- visual parts that update() animates

do
-- light rays behind the picture
P.rays=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(4,4),BackgroundTransparency=1,BorderSizePixel=0},av)
P.rayF={}
for k=0,9 do
	local pv=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(4,4),Rotation=k*36,BackgroundTransparency=1,BorderSizePixel=0},P.rays)
	local r=new("Frame",{AnchorPoint=Vector2.new(0.5,1),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(10+(k%3)*8,250),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0},pv)
	tgrad(r,90).Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(0.35,0.5),NumberSequenceKeypoint.new(1,0)})
	P.rayF[#P.rayF+1]=r
end
-- glow discs
local function disc(d,z)
	local f=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(d,d),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=z},av)
	corner(f,999)
	return f
end
P.gA=disc(150,1) tgrad(P.gA,45)
P.gB=disc(104,1) tgrad(P.gB,225)
-- ticks with a running comet
P.NT=44
P.tk=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(4,4),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=2},av)
P.ticks={}
for k=1,P.NT do
	local pv=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(4,4),Rotation=(k-1)*360/P.NT,BackgroundTransparency=1,BorderSizePixel=0},P.tk)
	P.ticks[k]=new("Frame",{AnchorPoint=Vector2.new(0.5,1),Position=UDim2.new(0.5,0,0.5,-61),Size=UDim2.fromOffset(2,0),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0},pv)
end
-- two counter-rotating arc rings
local function arcRing(d,th,arc)
	local f=disc(d,2)
	local s=stroke(f,C.White,th,1)
	local g=new("UIGradient",{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(arc,1),NumberSequenceKeypoint.new(1,1)})},s)
	onTheme(function() g.Color=ColorSequence.new(T.A1,T.A2) end)
	return {f=f,s=s,g=g,d=d}
end
P.arcA=arcRing(108,2,0.42)
P.arcB=arcRing(94,1.4,0.6)
-- orbiting beads
P.orb=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(4,4),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=3},av)
P.beads={}
for k=0,4 do
	local pv=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(4,4),Rotation=k*72,BackgroundTransparency=1,BorderSizePixel=0},P.orb)
	local d=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,-74),Size=UDim2.fromOffset(5,5),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0},pv)
	corner(d,999) tgrad(d,45)
	P.beads[k+1]=d
end
-- border ring + the circular picture (+ emblem fallback)
P.ring=disc(84,4)
P.ring.BackgroundColor3=Color3.fromRGB(10,11,19)
P.ringS=stroke(P.ring,C.White,3,0)
P.ringG=new("UIGradient",{},P.ringS)
onTheme(function()
	P.ringG.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,T.A1),ColorSequenceKeypoint.new(0.5,T.A2),ColorSequenceKeypoint.new(1,T.A1)})
end)
P.pic=new("ImageLabel",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(0,0),BackgroundColor3=Color3.fromRGB(26,28,48),BorderSizePixel=0,Image="",ImageTransparency=1,ScaleType=Enum.ScaleType.Crop,Visible=false,ZIndex=5},av)
corner(P.pic,999)
P.emb=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(0,0),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=5},av)
makeXMark(P.emb,"neon")
P.flash=disc(60,8)
end

-- tap on the picture = play the intro again
local hit=new("TextButton",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromOffset(AX,AY),Size=UDim2.fromOffset(100,100),BackgroundTransparency=1,Text="",AutoButtonColor=false,ZIndex=20},crCard)

------------------------------------------------ text: name, pills, line, thanks
local nameColor=function(i,n) return T.A1:Lerp(T.A2,(i-1)/math.max(n-1,1)) end
local NAME="Code_Name_Xyclop"
local crLetters=makeLetters(crCard,NAME,20,Enum.Font.GothamBlack,158,1,nameColor,CW)
local crPills={}
do
local defs={{"DEVELOPER",84},{"XyclopXR",72},{"v2.6",44}}
local gap=8
local total=-gap
for _,d in ipairs(defs) do total=total+d[2]+gap end
local x=(CW-total)/2
for _,d in ipairs(defs) do
	local p=new("Frame",{Position=UDim2.fromOffset(x,188),Size=UDim2.fromOffset(d[2],20),BackgroundColor3=C.Ink,BackgroundTransparency=1,BorderSizePixel=0},crCard)
	corner(p,10)
	local s=stroke(p,C.White,1.2,1)
	local g=new("UIGradient",{},s)
	onTheme(function() g.Color=ColorSequence.new(T.A1,T.A2) end)
	local l=label({Size=UDim2.fromScale(1,1),Text=d[1],TextSize=9,Font=Enum.Font.GothamBlack,TextColor3=C.White,TextTransparency=1},p)
	tgrad(l,0)
	local sc=new("UIScale",{Scale=0},p)
	crPills[#crPills+1]={f=p,s=s,l=l,sc=sc}
	x=x+d[2]+gap
end
end
local crLine=new("Frame",{AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0,214),Size=UDim2.fromOffset(0,2),BackgroundColor3=C.White,BorderSizePixel=0},crCard)
corner(crLine,2)
tgrad(crLine,0).Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(0.5,0),NumberSequenceKeypoint.new(1,1)})
local crThanks=bindText(label({AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0,218),Size=UDim2.fromOffset(CW-20,14),Text="",TextSize=10,Font=Enum.Font.Gotham,TextColor3=C.Muted,TextTransparency=1},crCard),"cr_thanks")

------------------------------------------------ picture loading
local hasPic=false
local function tryLoad()
	if hasPic or not (S.fs and S.hasFile(S.fs.pf)) then return end
	local id=S.asset(S.fs.pf)
	if id then
		P.pic.Image=id
		P.pic.Visible=true
		hasPic=true
	end
end
tryLoad()

------------------------------------------------ per-frame animation (called from the main loop while this tab is open)
local lastPoll=0
crEmb={root=av}
function crEmb.update(t)
	local g,r,tk,pc,ob,ry,fl=K.glow,K.ring,K.tick,K.pic,K.orb,K.ray,K.flash
	if not hasPic and t-lastPoll>1 then
		lastPoll=t
		tryLoad()
	end
	local pulse=math.sin(t*2)
	-- rays
	P.rays.Rotation=(t*6)%360
	for i,f in ipairs(P.rayF) do
		f.BackgroundTransparency=1-math.clamp(0.2*ry*(0.7+0.3*math.sin(t*1.4+i)),0,1)
	end
	-- glow
	local s1=(150+8*pulse)*g
	local s2=(104-6*pulse)*g
	P.gA.Size=UDim2.fromOffset(s1,s1)
	P.gB.Size=UDim2.fromOffset(s2,s2)
	P.gA.BackgroundTransparency=1-math.clamp((0.16+0.04*pulse)*g,0,1)
	P.gB.BackgroundTransparency=1-math.clamp(0.22*g,0,1)
	-- ticks + comet
	P.tk.Rotation=(t*9)%360
	local head=((t*0.5)%1)*P.NT
	for k=1,P.NT do
		local pop=math.clamp((tk-(k-1)/P.NT*0.7)/0.3,0,1)
		local dd=math.abs(k-head)
		dd=math.min(dd,P.NT-dd)
		local boost=math.max(0,1-dd/7)
		local major=(k%4==1)
		local bar=P.ticks[k]
		bar.Size=UDim2.fromOffset(2,math.max(0,((major and 7 or 4)+6*boost)*eb(pop)))
		bar.BackgroundColor3=nameColor(k,P.NT):Lerp(C.White,boost*0.8)
		bar.BackgroundTransparency=1-pop*(0.35+0.65*boost)
	end
	-- arc rings + border ring
	local a1=108*r
	local a2=94*r
	P.arcA.f.Size=UDim2.fromOffset(a1,a1)
	P.arcB.f.Size=UDim2.fromOffset(a2,a2)
	P.arcA.s.Transparency=1-math.clamp(r,0,1)
	P.arcB.s.Transparency=1-math.clamp(r*0.8,0,1)
	P.arcA.g.Rotation=(t*190)%360
	P.arcB.g.Rotation=(-t*130)%360
	local rs=84*r
	P.ring.Size=UDim2.fromOffset(rs,rs)
	P.ring.BackgroundTransparency=1-math.clamp(r,0,1)
	P.ringS.Transparency=1-math.clamp(r*1.1,0,1)
	P.ringG.Rotation=(t*110)%360
	-- the picture (or the emblem): spins and zooms in, fades in
	local ps=74*math.max(pc,0)
	P.pic.Size=UDim2.fromOffset(ps,ps)
	P.pic.Rotation=(1-math.clamp(pc,0,1))*-220
	P.pic.ImageTransparency=1-math.clamp(pc*1.6,0,1)
	P.pic.BackgroundTransparency=1-math.clamp(pc*1.6,0,1)
	local es=46*math.max(pc,0)
	P.emb.Size=UDim2.fromOffset(es,es)
	P.emb.Rotation=(1-math.clamp(pc,0,1))*-220
	P.emb.Visible=not hasPic
	-- orbit
	P.orb.Rotation=(t*45)%360
	for k,d in ipairs(P.beads) do
		local sz=(4+2*math.sin(t*3+k*1.3))*math.clamp(ob,0,1)
		d.Size=UDim2.fromOffset(sz,sz)
		d.BackgroundTransparency=1-math.clamp(ob,0,1)
	end
	-- flash
	local fs=60+240*fl
	P.flash.Size=UDim2.fromOffset(fs,fs)
	P.flash.BackgroundTransparency=1-math.clamp(0.85*fl,0,1)
	-- gentle float
	av.Position=UDim2.fromOffset(AX,AY+math.sin(t*1.6)*2)
end

------------------------------------------------ the intro
local ready=false
local function reset()
	kTok=kTok+1
	ready=false
	for k in pairs(K) do K[k]=0 end
	for _,l in ipairs(crLetters) do
		l.TextTransparency=1
		l.Position=UDim2.fromOffset(0,16)
	end
	for _,p in ipairs(crPills) do
		p.sc.Scale=0
		p.l.TextTransparency=1
		p.s.Transparency=1
		p.f.BackgroundTransparency=1
	end
	crLine.Size=UDim2.fromOffset(0,2)
	crThanks.TextTransparency=1
	crThanks.Position=UDim2.new(0.5,0,0,226)
end
local CH_SET="01ABCDEFGHJKLMNPQRSTUVWXYZ$#%*+=?"
function crPlay()
	reset()
	tryLoad()
	local my=kTok
	local function live() return alive and my==kTok end
	local mid=UDim2.fromScale(0.5,0.5)
	sfx("whoosh",0.25,1.8)
	anim("ray",1,1.4,0)
	anim("glow",1,1.1,0.1)
	anim("tick",1,1.0,0.25)
	-- rings open
	task.delay(0.35,function()
		if not live() then return end
		sfx("tick",0.2,0.8)
		shockwave(av,mid,40,260,2.5,0.9,0)
	end)
	anim("ring",1,0.8,0.45,true)
	-- the picture appears with a flash and a burst of particles
	task.delay(0.8,function()
		if not live() then return end
		anim("pic",1,1.0,0,true)
		anim("flash",1,0.1,0)
		anim("flash",0,0.7,0.1)
		burst(av,mid,28,{a1=T.A1,a2=T.A2},130)
		shockwave(av,mid,60,320,3.5,1.1,0)
		shockwave(av,mid,40,230,2,1.3,0.12,nil,0.3)
		sfx("ping",0.45,1.1)
		task.delay(0.12,function() if live() then sfx("ping",0.4,1.5) end end)
	end)
	anim("orb",1,0.9,1.35)
	-- name: every letter scrambles, then lands
	for i,l in ipairs(crLetters) do
		task.delay(1.35+(i-1)*0.055,function()
			if not live() then return end
			local final=NAME:sub(i,i)
			l.Position=UDim2.fromOffset(0,0)
			for _=1,5 do
				local r=math.random(1,#CH_SET)
				l.Text=CH_SET:sub(r,r)
				l.TextTransparency=0.25
				task.wait(0.04)
				if not live() then return end
			end
			l.Text=final
			tween(l,0.3,{TextTransparency=0})
			if i%3==1 then sfx("tick",0.14,1.0+i*0.05) end
		end)
	end
	local tEnd=1.35+#crLetters*0.055+0.35
	-- role pills pop in
	for i,p in ipairs(crPills) do
		task.delay(tEnd+(i-1)*0.12,function()
			if not live() then return end
			tween(p.sc,0.45,{Scale=1},Enum.EasingStyle.Back)
			tween(p.l,0.3,{TextTransparency=0})
			tween(p.s,0.3,{Transparency=0.15})
			tween(p.f,0.3,{BackgroundTransparency=0.35})
			sfx("tick",0.16,1.3+i*0.2)
		end)
	end
	-- line + thanks
	task.delay(tEnd+0.5,function()
		if not live() then return end
		tween(crLine,0.6,{Size=UDim2.fromOffset(200,2)},Enum.EasingStyle.Quint)
		sfx("ping",0.2,1.5)
	end)
	task.delay(tEnd+0.7,function()
		if live() then tween(crThanks,0.5,{TextTransparency=0,Position=UDim2.new(0.5,0,0,218)},Enum.EasingStyle.Quint) end
	end)
	task.delay(tEnd+1.0,function()
		if not live() then return end
		ready=true
		shimmerLetters(crLetters,nameColor)
	end)
end
reset()
hit.Activated:Connect(function()
	shockwave(av,UDim2.fromScale(0.5,0.5),50,220,2.5,0.8)
	sfx("ping",0.3,1.4)
	crPlay()
end)

-- periodic shimmer across the name while the tab is open
task.spawn(function()
	while alive do
		task.wait(4)
		if alive and activeTab==10 and not minimized and uiVisible and ready then
			shimmerLetters(crLetters,nameColor)
		end
	end
end)
end -- [E:credits]


-------------------------------------------------- UPDATE LOG PAGE
-- (block-scoped: nothing in here is needed outside; it registers itself as page 4)
-- Each entry has English text (fallback for every language) and Thai text.
do -- [S:log]
local logPage=new("ScrollingFrame",{
	Position=UDim2.fromScale(3,0),Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0,
	ScrollBarThickness=3,ScrollBarImageColor3=C.White,ScrollBarImageTransparency=0.6,
	CanvasSize=UDim2.new(0,0,0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollingDirection=Enum.ScrollingDirection.Y},pagesHolder)
pages[9]=logPage
new("UIListLayout",{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder,HorizontalAlignment=Enum.HorizontalAlignment.Center},logPage)
new("UIPadding",{PaddingTop=UDim.new(0,10),PaddingBottom=UDim.new(0,12)},logPage)

local LOG={
	{v="v2.6",new=true,
		en={"New music player on the left of the window: plays XyclopXR/Music, loop and shuffle, vinyl + visualizer",
			"Combat: NEXT button and dial arrows switch target without unlocking",
			"New Atmosphere tab: Fullbright and No Fog",
			"New Credits page with the maker picture, folders and picture are fetched from GitHub automatically"},
		th={"เครื่องเล่นเพลงใหม่ด้านซ้ายของหน้าต่าง: เล่นไฟล์จาก XyclopXR/Music ตั้งลูปและสุ่มได้ มีแผ่นเสียงและกราฟเสียง",
			"Combat: ปุ่ม NEXT และลูกศรบนวงแหวนเปลี่ยนเป้าได้โดยไม่ต้องปลดล็อค",
			"แท็บบรรยากาศใหม่: Fullbright และ No Fog",
			"หน้าเครดิตใหม่พร้อมรูปคนทำ สร้างโฟลเดอร์และดึงรูปจาก GitHub อัตโนมัติ"}},
	{v="v2.5",
		en={"New Player tab: walk speed, jump power and gravity with reset buttons",
			"4th quick dial: three liquid tubes for speed, jump and gravity",
			"Combat: LOCK ON arms instantly and locks the first target that enters the FOV. NPC lock, random body part, nearest / farthest priority, FOV circle colors",
			"New Misc tab: Shift Lock button, customizable crosshair, Anti AFK, Auto Execute, Rejoin, smallest server, server hop and server list",
			"Rainbow theme in Settings"},
		th={"แท็บ Player ใหม่: ปรับความเร็วเดิน แรงกระโดด แรงโน้มถ่วง พร้อมปุ่มรีเซ็ต",
			"วงแหวนอันที่ 4: สามหลอดปรับความเร็ว แรงกระโดด แรงโน้มถ่วง",
			"Combat: กดล็อคแล้วรอเป้าเข้า FOV ล็อคเองทันที ล็อค NPC สุ่มส่วนร่างกาย เลือกใกล้ / ไกลก่อน เปลี่ยนสีวง FOV",
			"แท็บ Misc ใหม่: ปุ่มชิฟท์ล็อค เป้าเล็งปรับแต่งได้ Anti AFK รันสคริปต์อัตโนมัติ Rejoin หาเซิร์ฟคนน้อย สุ่มเซิร์ฟ และรายชื่อเซิร์ฟเวอร์",
			"ธีมสีรุ้งในหน้าตั้งค่า"}},
	{v="v2.4",
		en={"New Combat tab: LOCK ON button, animated target marker, body part picker, wall check, ignore team, auto switch when the target dies, FOV slider and player list",
			"FOV circle drawn as an animated radar scope that reacts to lock / search / blocked",
			"New Visual tab: ESP with lines, hitbox, health bar and names, plus a color picker",
			"Hold the floating button to cycle Fly, Combat and Visual dials, each with its own ring design"},
		th={"แท็บ Combat ใหม่: ปุ่มล็อคเป้า ไอคอนบนตัวเป้าหมาย เลือกส่วนร่างกาย เช็คกำแพง ไม่สนใจทีมเดียวกัน เปลี่ยนเป้าเมื่อตายอัตโนมัติ ปรับ FOV และรายชื่อผู้เล่น",
			"วง FOV เป็นเรดาร์สโคปเคลื่อนไหว เปลี่ยนตามสถานะ ล็อค / สแกน / ถูกบัง",
			"แท็บ Visual ใหม่: ESP เส้น ฮิตบ็อกซ์ หลอดเลือด ชื่อ และเลือกสีได้",
			"กดค้างที่ปุ่มลอยเพื่อสลับวงแหวน Fly, Combat, Visual แต่ละอันหน้าตาไม่ซ้ำกัน"}},
	{v="v2.3",
		en={"New Quick Fly: press and hold the floating button, the charge ring fills up and the button turns into an instant fly button",
			"Circular speed dial around the icon with a cinematic open / close animation",
			"Drag around the ring, or hold and slide in a circle, to change the speed (synced with the Fly tab)",
			"Tap the icon to fly on / off, hold it again to close the dial"},
		th={"Quick Fly ใหม่: กดค้างที่ปุ่มลอย วงแหวนชาร์จเต็มแล้วปุ่มจะกลายเป็นปุ่มกดบินได้ทันที",
			"สไลเดอร์ความเร็วแบบวงกลมรอบไอคอน พร้อมอนิเมชั่นเปิด / ปิดสุดเท่",
			"ลากรอบวงแหวน หรือกดค้างแล้วลากเป็นวงกลมเพื่อปรับความเร็ว (ซิงก์กับแท็บบิน)",
			"แตะไอคอนเพื่อเปิด / ปิดการบิน กดค้างอีกครั้งเพื่อปิดวงแหวน"}},
	{v="v2.2",
		en={"New Home page: your avatar, name, live player stats and server stats",
			"New Update Log tab",
			"Cinematic tab-switch animation with the logo and tab name",
			"5 loading screen styles, pick one in Settings (with a Preview button)",
			"Your settings are now saved between sessions on executors that support files"},
		th={"หน้า Home ใหม่ แสดงรูปโปรไฟล์ ชื่อ และสเตตัสผู้เล่น + เซิร์ฟเวอร์แบบเรียลไทม์",
			"เพิ่มแท็บ Update Log",
			"อนิเมชั่นเปลี่ยนแท็บสุดเท่ มีโลโก้และชื่อแท็บ",
			"หน้าโหลด 5 สไตล์ เลือกได้ในตั้งค่า (มีปุ่มพรีวิว)",
			"บันทึกการตั้งค่าข้ามรอบได้ ถ้า executor รองรับการเขียนไฟล์"}},
	{v="v2.1.1",
		en={"Fixed the launch crash: attempt to call a nil value"},
		th={"แก้บั๊กสคริปต์เปิดไม่ขึ้น: attempt to call a nil value"}},
	{v="v2.1",
		en={"Floating hide / show button (and Right Shift)",
			"Resize the window by dragging the bottom-right corner",
			"Bright sky-blue cinematic loading screen",
			"Rounded bottom edge fix"},
		th={"ปุ่มลอยซ่อน / แสดงหน้าต่าง (และปุ่ม Right Shift)",
			"ลากมุมขวาล่างเพื่อปรับขนาดหน้าต่าง",
			"หน้าโหลดสีฟ้าสดแบบภาพยนตร์",
			"แก้ขอบล่างของหน้าต่างให้โค้งมน"}},
	{v="v2.0",
		en={"Fly mode with speed slider and up / down buttons",
			"8 theme colors plus a custom hue slider",
			"10 languages",
			"Sound and visual effects"},
		th={"โหมดบินปรับความเร็วได้ พร้อมปุ่มขึ้น / ลง",
			"ธีมสี 8 แบบ และปรับสีเองได้",
			"รองรับ 10 ภาษา",
			"เสียงและเอฟเฟกต์ภาพ"}},
}

local entries={}
for idx,e in ipairs(LOG) do
	local cardF=new("Frame",{LayoutOrder=idx,Size=UDim2.fromOffset(W-24,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundColor3=C.White,BackgroundTransparency=0.95,BorderSizePixel=0},logPage)
	corner(cardF,12) stroke(cardF,C.White,1,0.92)
	new("UIPadding",{PaddingTop=UDim.new(0,10),PaddingBottom=UDim.new(0,10),PaddingLeft=UDim.new(0,14),PaddingRight=UDim.new(0,14)},cardF)
	new("UIListLayout",{Padding=UDim.new(0,5),SortOrder=Enum.SortOrder.LayoutOrder},cardF)
	local head=new("Frame",{LayoutOrder=0,Size=UDim2.new(1,0,0,22),BackgroundTransparency=1,BorderSizePixel=0},cardF)
	local ver=label({Size=UDim2.new(1,-50,1,0),Text=e.v,TextSize=16,Font=Enum.Font.GothamBlack,TextColor3=C.White,TextXAlignment=Enum.TextXAlignment.Left},head)
	tgrad(ver,0)
	if e.new then
		local tag=new("Frame",{AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,0,0.5,0),Size=UDim2.fromOffset(46,18),BackgroundColor3=C.White,BorderSizePixel=0},head)
		corner(tag,9) tgrad(tag,0)
		bindText(label({Size=UDim2.fromScale(1,1),Text="",TextSize=10,Font=Enum.Font.GothamBlack,TextColor3=C.Ink},tag),"log_new")
	end
	local lbls={}
	for k=1,#e.en do
		lbls[k]=label({LayoutOrder=k,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,Text="",TextSize=12,Font=Enum.Font.Gotham,TextColor3=C.Text,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,TextTruncate=Enum.TextTruncate.None},cardF)
	end
	entries[idx]={e=e,lbls=lbls}
end
onLang(function()
	for _,en in ipairs(entries) do
		local src=en.e[lang] or en.e.en
		for k,l in ipairs(en.lbls) do
			l.Text="•  "..(src[k] or en.e.en[k])
		end
	end
end)
end -- [E:log]


-------------------------------------------------- MUSIC PLAYER  (slides out on the left of the window)
-- Plays every .mp3 / .ogg / .wav it finds in  <executor>/workspace/XyclopXR/Music
-- Needs an executor with listfiles + getcustomasset. Open / close it with the note button in the title bar.
do -- [S:music]
local fs=S.fs
local PW=206
local M={files={},sig="",idx=0,hist={},spd=0,rot=0,ap=0,seekT=0,scanT=0,lv=0,switching=false,playing=false,
	started=false,arm=0,
	vol=math.clamp(tonumber(pref("mpvol",60)) or 60,0,100),
	loop=pref("mploop","all"),shuffle=pref("mpshuf",false),open=pref("mpopen",sz0.X>=640)}
if not ({off=1,all=1,one=1})[M.loop] then M.loop="all" end
local U={rows={}}
local snd=new("Sound",{Name="XyclopMusic",Volume=M.vol/100*0.8,Looped=false},gui)

local function eb(x) -- easeOutBack
	x=math.clamp(x,0,1)-1
	return 1+2.70158*x*x*x+1.70158*x*x
end
local function fmt(s)
	s=math.max(0,math.floor(s or 0))
	return string.format("%d:%02d",math.floor(s/60),s%60)
end
local function scan()
	local out={}
	local ok,files=pcall(function()
		if listfiles and isfolder and isfolder(fs.music) then return listfiles(fs.music) end
	end)
	if ok and type(files)=="table" then
		for _,p in ipairs(files) do
			local path=tostring(p)
			local name=path:match("([^/\\]+)$")
			local ext=name and name:match("%.(%w+)$")
			ext=ext and ext:lower()
			if ext=="mp3" or ext=="ogg" or ext=="wav" then
				out[#out+1]={path=path,name=(name:gsub("%.%w+$","")),ext=ext}
			end
		end
	end
	table.sort(out,function(a,b) return a.name:lower()<b.name:lower() end)
	return out
end

------------------------------------------------ the panel (a child of the window, so it follows move / resize)
local shell=new("Frame",{Name="MusicPanel",AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0,-PW/2-10,0.5,0),Size=UDim2.new(0,PW,1,0),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0,Visible=false,ZIndex=2},main)
corner(shell,18)
grad(shell,Color3.fromRGB(26,28,48),Color3.fromRGB(10,11,19),90)
local shellS=stroke(shell,C.White,1.5,1)
local shellG=new("UIGradient",{},shellS)
onTheme(function()
	shellG.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,T.A1),ColorSequenceKeypoint.new(0.5,T.A2),ColorSequenceKeypoint.new(1,T.A1)})
end)
local pScale=new("UIScale",{Scale=0.92},shell)
local cg=new("CanvasGroup",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0,GroupTransparency=1,Active=true},shell)
corner(cg,18)
local aura=new("Frame",{Size=UDim2.new(1,0,0,80),BackgroundColor3=C.White,BorderSizePixel=0},cg)
local auraG=tgrad(aura,90)
auraG.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.8),NumberSequenceKeypoint.new(1,1)})
-- floating sparkles
for n=1,6 do
	task.spawn(function()
		local rnd=Random.new(n*37+3)
		local sz=rnd:NextInteger(2,4)
		local d=new("Frame",{Size=UDim2.fromOffset(sz,sz),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0},cg)
		corner(d,999) tgrad(d,0)
		task.wait(rnd:NextNumber(0,3))
		while alive and d.Parent do
			local x=rnd:NextNumber(0.05,0.95)
			local dur=rnd:NextNumber(5,9)
			d.Position=UDim2.fromScale(x,1.02)
			d.BackgroundTransparency=1
			tween(d,dur,{Position=UDim2.fromScale(x+rnd:NextNumber(-0.05,0.05),-0.02)},Enum.EasingStyle.Linear)
			tween(d,dur*0.25,{BackgroundTransparency=rnd:NextNumber(0.55,0.8)})
			task.wait(dur*0.75)
			tween(d,dur*0.25,{BackgroundTransparency=1})
			task.wait(dur*0.25)
		end
	end)
end

------------------------------------------------ header + note button in the title bar
do
local ttl=label({Position=UDim2.fromOffset(34,8),Size=UDim2.fromOffset(90,18),Text="",TextSize=14,Font=Enum.Font.GothamBlack,TextColor3=C.White,TextXAlignment=Enum.TextXAlignment.Left},cg)
tgrad(ttl,0)
bindText(ttl,"mp_title")
U.count=label({AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-40,0,10),Size=UDim2.fromOffset(70,14),Text="",TextSize=10,Font=Enum.Font.Gotham,TextColor3=C.Muted,TextXAlignment=Enum.TextXAlignment.Right},cg)
-- little equalizer next to the title
U.hq={}
for i=1,3 do
	local b=new("Frame",{AnchorPoint=Vector2.new(0,1),Position=UDim2.fromOffset(14+(i-1)*5,22),Size=UDim2.fromOffset(3,4),BackgroundColor3=C.White,BorderSizePixel=0},cg)
	corner(b,1) tgrad(b,90)
	U.hq[i]=b
end
-- refresh button: ring + arrow head
local rb=new("TextButton",{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-10,0,5),Size=UDim2.fromOffset(24,24),BackgroundColor3=C.White,BackgroundTransparency=0.92,Text="",AutoButtonColor=false,BorderSizePixel=0,ClipsDescendants=true},cg)
corner(rb,12)
local rr=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(12,12),BackgroundTransparency=1,BorderSizePixel=0},rb)
corner(rr,999)
stroke(rr,C.Text,1.6,0)
label({AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,5,0.5,-5),Size=UDim2.fromOffset(8,8),Text="▶",TextSize=7,TextColor3=C.Text,TextTruncate=Enum.TextTruncate.None,ZIndex=3},rb)
U.rbIcon=rr
rb.InputBegan:Connect(function(i) if isPress(i) then ripple(rb,i) end end)
rb.Activated:Connect(function()
	sfx("click",0.35,1.3)
	M.scanT=0
	M.dirty=true
	tween(rr,0.5,{Rotation=rr.Rotation+360},Enum.EasingStyle.Quint)
end)
end

------------------------------------------------ now playing card: vinyl + title + visualizer
do
local card=new("Frame",{Position=UDim2.fromOffset(10,34),Size=UDim2.fromOffset(PW-20,96),BackgroundColor3=C.White,BackgroundTransparency=0.95,BorderSizePixel=0,ClipsDescendants=true},cg)
corner(card,14)
stroke(card,C.White,1,0.92)
-- vinyl
local vin=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromOffset(42,48),Size=UDim2.fromOffset(70,70),BackgroundTransparency=1,BorderSizePixel=0},card)
local halo=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(86,86),BackgroundColor3=C.White,BackgroundTransparency=0.88,BorderSizePixel=0},vin)
corner(halo,999) tgrad(halo,45)
U.halo=halo
local disc=new("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(16,16,24),BorderSizePixel=0},vin)
corner(disc,999)
stroke(disc,C.White,1,0.8)
U.spin=new("Frame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0},disc)
for _,d in ipairs({60,52,44,36}) do
	local g=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(d,d),BackgroundTransparency=1,BorderSizePixel=0},U.spin)
	corner(g,999)
	stroke(g,C.White,1,0.9)
end
-- glints on the grooves (rotating arcs)
U.glint={}
for k,d in ipairs({66,48}) do
	local g=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(d,d),BackgroundTransparency=1,BorderSizePixel=0},U.spin)
	corner(g,999)
	local s=stroke(g,C.White,2,0.2)
	new("UIGradient",{Rotation=k*70,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.1),NumberSequenceKeypoint.new(0.18,1),NumberSequenceKeypoint.new(0.5,1),NumberSequenceKeypoint.new(0.68,0.1),NumberSequenceKeypoint.new(0.86,1),NumberSequenceKeypoint.new(1,1)})},s)
	U.glint[k]=g
end
-- label in the middle (theme colored, with a mark so the rotation is visible) + spindle hole
local lab=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(26,26),BackgroundColor3=C.White,BorderSizePixel=0},U.spin)
corner(lab,999)
U.labG=tgrad(lab,0)
local mark=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,-8),Size=UDim2.fromOffset(4,4),BackgroundColor3=C.Ink,BorderSizePixel=0},lab)
corner(mark,999)
local hole=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(6,6),BackgroundColor3=Color3.fromRGB(16,16,24),BorderSizePixel=0,ZIndex=2},disc)
corner(hole,999)
-- static glare over the disc
local glare=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromScale(1,1),BackgroundColor3=C.White,BackgroundTransparency=0.9,BorderSizePixel=0,ZIndex=3},disc)
corner(glare,999)
new("UIGradient",{Rotation=-40,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(0.42,1),NumberSequenceKeypoint.new(0.5,0),NumberSequenceKeypoint.new(0.58,1),NumberSequenceKeypoint.new(1,1)})},glare)
-- tonearm (swings onto the record while playing)
U.arm=new("Frame",{AnchorPoint=Vector2.new(0.5,0),Position=UDim2.fromOffset(70,12),Size=UDim2.fromOffset(4,4),Rotation=-50,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=4},card)
local armBar=new("Frame",{AnchorPoint=Vector2.new(0.5,0),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(3,40),BackgroundColor3=Color3.fromRGB(190,196,220),BorderSizePixel=0,ZIndex=4},U.arm)
corner(armBar,2)
local armHead=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,1),Size=UDim2.fromOffset(7,10),BackgroundColor3=C.White,BorderSizePixel=0,ZIndex=4},armBar)
corner(armHead,2)
tgrad(armHead,0)
local pivot=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(9,9),BackgroundColor3=Color3.fromRGB(190,196,220),BorderSizePixel=0,ZIndex=5},U.arm)
corner(pivot,999)

-- title (scrolls when too long) + info
U.tclip=new("Frame",{Position=UDim2.fromOffset(86,10),Size=UDim2.fromOffset(PW-20-94,18),BackgroundTransparency=1,BorderSizePixel=0,ClipsDescendants=true},card)
U.title=label({Position=UDim2.fromOffset(0,0),Size=UDim2.fromOffset(300,18),Text="",TextSize=13,Font=Enum.Font.GothamBlack,TextColor3=C.White,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.None},U.tclip)
tgrad(U.title,0)
U.info=label({Position=UDim2.fromOffset(86,30),Size=UDim2.fromOffset(PW-20-94,12),Text="",TextSize=10,Font=Enum.Font.Gotham,TextColor3=C.Muted,TextXAlignment=Enum.TextXAlignment.Left},card)
-- visualizer: 14 bars driven by the real loudness of the sound
U.bars={}
for i=1,14 do
	local b=new("Frame",{AnchorPoint=Vector2.new(0,1),Position=UDim2.fromOffset(86+(i-1)*7,88),Size=UDim2.fromOffset(5,3),BackgroundColor3=C.White,BorderSizePixel=0},card)
	corner(b,2)
	tgrad(b,90)
	U.bars[i]=b
end
end

------------------------------------------------ seek bar + time
do
U.seek=makeSlider({parent=cg,x=12,y=140,width=PW-24,min=0,max=1000,value=0,onChange=function(v)
	M.seekT=os.clock()
	if M.idx>0 and snd.TimeLength>0 then snd.TimePosition=snd.TimeLength*v/1000 end
end})
U.cur=label({Position=UDim2.fromOffset(12,149),Size=UDim2.fromOffset(60,12),Text="0:00",TextSize=9,Font=Enum.Font.Gotham,TextColor3=C.Muted,TextXAlignment=Enum.TextXAlignment.Left},cg)
U.tot=label({AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-12,0,149),Size=UDim2.fromOffset(60,12),Text="0:00",TextSize=9,Font=Enum.Font.Gotham,TextColor3=C.Muted,TextXAlignment=Enum.TextXAlignment.Right},cg)
end

------------------------------------------------ controls: shuffle  prev  PLAY  next  loop
do
local function circle(x,size)
	local b=new("TextButton",{AnchorPoint=Vector2.new(0,0.5),Position=UDim2.fromOffset(x,188),Size=UDim2.fromOffset(size,size),BackgroundColor3=C.White,BackgroundTransparency=0.92,Text="",AutoButtonColor=false,BorderSizePixel=0,ClipsDescendants=true},cg)
	corner(b,size)
	b.InputBegan:Connect(function(i) if isPress(i) then ripple(b,i) end end)
	return b
end
local function arrow(parent,rot,size)
	return label({AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(size,size),Text="▶",TextSize=size,TextColor3=C.Text,Rotation=rot,TextTruncate=Enum.TextTruncate.None,ZIndex=3},parent)
end
local function bar(parent,x,w,h)
	local f=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,x,0.5,0),Size=UDim2.fromOffset(w,h),BackgroundColor3=C.Text,BorderSizePixel=0,ZIndex=3},parent)
	corner(f,1)
	return f
end

-- shuffle: two crossing lines with arrow heads
U.bShuf=circle(11,26)
U.shufParts={}
for _,r in ipairs({32,-32}) do
	local f=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(15,2),Rotation=r,BackgroundColor3=C.Text,BorderSizePixel=0,ZIndex=3},U.bShuf)
	corner(f,1)
	U.shufParts[#U.shufParts+1]=f
end
U.shufParts[3]=label({AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,6,0.5,-6),Size=UDim2.fromOffset(7,7),Text="▶",TextSize=6,TextColor3=C.Text,TextTruncate=Enum.TextTruncate.None,ZIndex=3},U.bShuf)
U.shufParts[4]=label({AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,6,0.5,6),Size=UDim2.fromOffset(7,7),Text="▶",TextSize=6,TextColor3=C.Text,TextTruncate=Enum.TextTruncate.None,ZIndex=3},U.bShuf)

-- prev / next: arrow + bar
U.bPrev=circle(43,32)
U.pvA=arrow(U.bPrev,180,13)
U.pvB=bar(U.bPrev,-7,2,11)
U.bNext=circle(131,32)
U.nxA=arrow(U.bNext,0,13)
U.nxB=bar(U.bNext,7,2,11)

-- play / pause (big, theme gradient)
U.bPlay=new("TextButton",{AnchorPoint=Vector2.new(0,0.5),Position=UDim2.fromOffset(81,188),Size=UDim2.fromOffset(44,44),BackgroundColor3=C.White,Text="",AutoButtonColor=false,BorderSizePixel=0,ClipsDescendants=true},cg)
corner(U.bPlay,44)
tgrad(U.bPlay,45)
U.bPlay.InputBegan:Connect(function(i) if isPress(i) then ripple(U.bPlay,i) end end)
U.plA=label({AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,2,0.5,0),Size=UDim2.fromOffset(18,18),Text="▶",TextSize=17,TextColor3=C.Ink,TextTruncate=Enum.TextTruncate.None,ZIndex=3},U.bPlay)
U.pause={}
for _,x in ipairs({-4,4}) do
	local f=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,x,0.5,0),Size=UDim2.fromOffset(4,15),BackgroundColor3=C.Ink,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=3},U.bPlay)
	corner(f,2)
	U.pause[#U.pause+1]=f
end

-- loop: rounded rectangle + arrow head (+ "1" in the single-track mode)
U.bLoop=circle(169,26)
U.loopRing=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(16,11),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=3},U.bLoop)
corner(U.loopRing,5)
U.loopS=stroke(U.loopRing,C.Text,1.6,0)
U.loopA=label({AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,5,0.5,-5.5),Size=UDim2.fromOffset(7,7),Text="▶",TextSize=6,TextColor3=C.Text,TextTruncate=Enum.TextTruncate.None,ZIndex=4},U.bLoop)
U.loopOne=label({AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(8,8),Text="1",TextSize=8,Font=Enum.Font.GothamBlack,TextColor3=C.Text,TextTransparency=1,ZIndex=4},U.bLoop)

U.bShuf.Activated:Connect(function() M.setShuffle(not M.shuffle) end)
U.bLoop.Activated:Connect(function() M.cycleLoop() end)
U.bPlay.Activated:Connect(function() M.toggle() end)
U.bPrev.Activated:Connect(function() M.prev() end)
U.bNext.Activated:Connect(function() M.next(false) end)
end

------------------------------------------------ volume + playlist
do
-- speaker icon
local sp=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromOffset(17,222),Size=UDim2.fromOffset(5,7),BackgroundColor3=C.Muted,BorderSizePixel=0},cg)
corner(sp,1)
label({AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromOffset(22,222),Size=UDim2.fromOffset(9,9),Text="▶",TextSize=9,TextColor3=C.Muted,Rotation=180,TextTruncate=Enum.TextTruncate.None},cg)
makeSlider({parent=cg,x=36,y=222,width=PW-36-14,min=0,max=100,value=M.vol,onChange=function(v)
	M.vol=v
	snd.Volume=v/100*0.8
	savePref("mpvol",v)
end})
U.list=new("ScrollingFrame",{Position=UDim2.fromOffset(8,240),Size=UDim2.new(1,-16,1,-248),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=2,ScrollBarImageColor3=C.White,ScrollBarImageTransparency=0.6,CanvasSize=UDim2.new(0,0,0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollingDirection=Enum.ScrollingDirection.Y},cg)
new("UIListLayout",{Padding=UDim.new(0,3),SortOrder=Enum.SortOrder.LayoutOrder},U.list)
U.empty=label({AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0,244),Size=UDim2.new(1,-24,0,64),Text="",TextSize=10,Font=Enum.Font.Gotham,TextColor3=C.Muted,TextWrapped=true,TextTruncate=Enum.TextTruncate.None,Visible=false},cg)
end

------------------------------------------------ the toggle button in the title bar (drawn note)
do
U.mb=iconBtn(-76)
dragArea.Size=UDim2.new(1,-116,1,0)
hover(U.mb,C.White,0.8)
U.note={}
local function part(props)
	props.BackgroundColor3=C.Text
	props.BorderSizePixel=0
	props.ZIndex=2
	local f=new("Frame",props,U.mb)
	U.note[#U.note+1]=f
	return f
end
corner(part({AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,-3,0.5,5),Size=UDim2.fromOffset(8,6),Rotation=-20}),3)
corner(part({AnchorPoint=Vector2.new(0.5,1),Position=UDim2.new(0.5,1,0.5,4),Size=UDim2.fromOffset(2,12)}),1)
corner(part({AnchorPoint=Vector2.new(0,0),Position=UDim2.new(0.5,1,0.5,-8),Size=UDim2.fromOffset(6,3),Rotation=25}),1)
U.mb.Activated:Connect(function()
	M.open=not M.open
	savePref("mpopen",M.open)
	sfx("switch",0.4,M.open and 1.25 or 0.8)
	if M.open then M.dirty=true end
end)
end

------------------------------------------------ playback logic
function M.rebuild()
	for _,r in ipairs(U.rows) do r.b:Destroy() end
	U.rows={}
	for i,f in ipairs(M.files) do
		local b=new("TextButton",{LayoutOrder=i,Size=UDim2.new(1,-4,0,24),BackgroundColor3=C.White,BackgroundTransparency=0.93,Text="",AutoButtonColor=false,BorderSizePixel=0,ClipsDescendants=true},U.list)
		corner(b,8)
		local sel=new("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0},b)
		corner(sel,8)
		tgrad(sel,0)
		label({Position=UDim2.fromOffset(7,0),Size=UDim2.fromOffset(16,24),Text=tostring(i),TextSize=9,Font=Enum.Font.Gotham,TextColor3=C.Muted,ZIndex=2},b)
		local nm=label({Position=UDim2.fromOffset(26,0),Size=UDim2.new(1,-54,1,0),Text=f.name,TextSize=11,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=2},b)
		local eq={}
		for k=1,3 do
			local e=new("Frame",{AnchorPoint=Vector2.new(0,1),Position=UDim2.new(1,-22+(k-1)*5,1,-7),Size=UDim2.fromOffset(3,3),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=2},b)
			corner(e,1)
			eq[k]=e
		end
		b.InputBegan:Connect(function(inp) if isPress(inp) then ripple(b,inp) end end)
		b.Activated:Connect(function()
			sfx("click",0.35,1.2)
			M.load(i,true)
		end)
		U.rows[i]={b=b,sel=sel,nm=nm,eq=eq,on=false}
	end
	U.count.Text=#M.files.." "..tr("mp_tracks")
	if #M.files==0 then
		local noapi=not (getcustomasset or getsynasset) or not listfiles
		U.empty.Text=noapi and tr("mp_noapi") or (tr("mp_empty").."\n"..tr("mp_hint"))
		U.empty.Visible=true
	else
		U.empty.Visible=false
	end
end

-- starts track i (pushHist = remember the previous one for the "prev" button)
function M.load(i,pushHist)
	local f=M.files[i]
	if not f then return end
	local id=S.asset(f.path)
	if not id then
		toast(tr("mp_noapi"))
		return
	end
	if pushHist and M.idx>0 and M.idx~=i then
		M.hist[#M.hist+1]=M.idx
		if #M.hist>40 then table.remove(M.hist,1) end
	end
	M.switching=true
	pcall(function() snd:Stop() end)
	M.idx=i
	snd.SoundId=id
	snd.TimePosition=0
	snd.Looped=(M.loop=="one")
	snd:Play()
	M.started=true
	M.arm=1
	U.title.Text=f.name
	task.delay(0.3,function() M.switching=false end)
end
function M.next(auto)
	local n=#M.files
	if n==0 then return end
	local ni
	if M.shuffle then
		if n==1 then
			ni=1
		else
			repeat ni=math.random(n) until ni~=M.idx
		end
	else
		ni=M.idx+1
		if ni>n then
			if auto and M.loop=="off" then
				M.started=false
				M.playing=false
				pcall(function() snd:Stop() end)
				return
			end
			ni=1
		end
	end
	M.load(ni,true)
end
function M.prev()
	if M.idx>0 and snd.TimePosition>3 then
		snd.TimePosition=0
		return
	end
	local h=table.remove(M.hist)
	if h and M.files[h] then
		M.load(h,false)
	elseif M.idx>1 then
		M.load(M.idx-1,false)
	elseif #M.files>0 then
		M.load(#M.files,false)
	end
end
function M.toggle()
	if #M.files==0 then
		sfx("ping",0.4,0.6)
		return
	end
	sfx("click",0.35,1.2)
	if M.idx==0 or not M.started then
		M.load(M.shuffle and math.random(#M.files) or math.max(M.idx,1),false)
	elseif snd.IsPlaying then
		snd:Pause()
	elseif snd.IsPaused then
		snd:Resume()
	else
		snd:Play()
	end
end
function M.setShuffle(on)
	M.shuffle=on
	savePref("mpshuf",on)
	sfx("switch",0.4,on and 1.25 or 0.8)
end
function M.cycleLoop()
	M.loop=(M.loop=="off") and "all" or ((M.loop=="all") and "one" or "off")
	snd.Looped=(M.loop=="one")
	savePref("mploop",M.loop)
	sfx("switch",0.4,M.loop=="off" and 0.8 or 1.25)
end
snd.Ended:Connect(function()
	if M.switching or not M.started then return end
	M.next(true)
end)
S.onFilesReady=function() M.dirty=true end

------------------------------------------------ per-frame animation
connect(RunService.RenderStepped,function(dt)
	local t=os.clock()
	M.playing=snd.IsPlaying
	M.arm=math.max(0,M.arm-dt*2)
	M.spd=M.spd+((M.playing and 1 or 0)-M.spd)*math.min(1,dt*3)

	-- the note button in the title bar glows while music plays
	local nc=M.playing and T.A1:Lerp(C.White,0.5+0.5*math.sin(t*5)) or C.Text
	for _,f in ipairs(U.note) do f.BackgroundColor3=nc end

	-- slide in / out
	M.ap=M.ap+((M.open and 1 or 0)-M.ap)*math.min(1,dt*9)
	local ap=M.ap
	local show=ap>0.01 and not minimized
	shell.Visible=show
	if not show then return end
	shell.Position=UDim2.new(0,-PW/2-10+(1-ap)*34,0.5,0)
	pScale.Scale=0.9+0.1*eb(ap)
	shell.BackgroundTransparency=1-0.95*ap
	shellS.Transparency=1-0.65*ap
	cg.GroupTransparency=1-ap
	shellG.Rotation=(t*50)%360

	-- rescan the folder
	M.scanT=M.scanT-dt
	if M.dirty or M.scanT<=0 then
		M.dirty=false
		M.scanT=6
		local list=scan()
		local sig=""
		for _,f in ipairs(list) do sig=sig..f.path.."|" end
		if sig~=M.sig then
			local curPath=M.files[M.idx] and M.files[M.idx].path
			M.sig=sig
			M.files=list
			M.hist={}
			M.idx=0
			if curPath then
				for i,f in ipairs(list) do if f.path==curPath then M.idx=i end end
				if M.idx==0 then
					M.started=false
					M.switching=true
					pcall(function() snd:Stop() end)
					task.delay(0.3,function() M.switching=false end)
				end
			end
			M.rebuild()
		end
	end

	-- vinyl + tonearm
	M.rot=(M.rot+dt*150*M.spd)%360
	U.spin.Rotation=M.rot
	U.labG.Rotation=(t*90*M.spd+M.rot)%360
	U.halo.BackgroundTransparency=1-(0.1+0.14*M.spd+0.05*math.sin(t*3)*M.spd+0.1*M.arm)
	local want=M.playing and -22 or -50
	U.arm.Rotation=U.arm.Rotation+(want-U.arm.Rotation)*math.min(1,dt*4)

	-- visualizer from the real loudness
	local loud=M.playing and snd.PlaybackLoudness or 0
	M.lv=M.lv+(math.clamp(loud/450,0,1)-M.lv)*math.min(1,dt*10)
	for i=1,14 do
		local shape=0.55+0.45*math.sin(math.pi*(i-0.5)/14)
		local wob=0.55+0.45*(0.5+0.5*math.sin(t*(5+i*0.7)+i*1.9))
		local h=3+(M.playing and 4*(0.5+0.5*math.sin(t*3+i)) or 0)+30*M.lv*shape*wob
		U.bars[i].Size=UDim2.fromOffset(5,math.floor(h+0.5))
		U.bars[i].BackgroundTransparency=M.playing and 0.05 or 0.6
	end
	for i=1,3 do
		U.hq[i].Size=UDim2.fromOffset(3,math.floor(4+(M.playing and (4+8*M.lv)*(0.5+0.5*math.sin(t*6+i*1.7)) or 0)))
	end

	-- title marquee + time + seek
	local f=M.files[M.idx]
	local tb=U.title.TextBounds.X
	local clipW=U.tclip.AbsoluteSize.X/math.max(uiScale.Scale,0.01)
	if tb>clipW+2 then
		local over=tb-clipW
		local ph=(t*0.35)%2
		local k=(ph<1) and ph or (2-ph)
		k=math.clamp((k-0.15)/0.7,0,1)
		U.title.Position=UDim2.fromOffset(-over*k,0)
	else
		U.title.Position=UDim2.fromOffset(0,0)
	end
	if f then
		U.info.Text=string.upper(f.ext).."  ·  "..(M.shuffle and "shuffle" or ("#"..M.idx))
		local len=snd.TimeLength
		U.cur.Text=fmt(snd.TimePosition)
		U.tot.Text=fmt(len)
		if len>0 and t-M.seekT>0.4 then
			U.seek.set(math.floor(snd.TimePosition/len*1000),true)
		end
	else
		if U.title.Text~="" then U.title.Text="" end
		U.info.Text=""
		U.cur.Text="0:00"
		U.tot.Text="0:00"
		U.seek.set(0,true)
	end
	if #M.files>0 and not f then
		U.title.Text=tr("mp_pick")
	end

	-- play / pause icon + toggle colors
	U.plA.TextTransparency=M.playing and 1 or 0
	for _,p in ipairs(U.pause) do p.BackgroundTransparency=M.playing and 0 or 1 end
	local lit=T.A1
	for _,p in ipairs(U.shufParts) do
		if p:IsA("TextLabel") then p.TextColor3=M.shuffle and lit or C.Text else p.BackgroundColor3=M.shuffle and lit or C.Text end
	end
	U.bShuf.BackgroundTransparency=M.shuffle and 0.8 or 0.92
	local lc=(M.loop=="off") and C.Muted or lit
	U.loopS.Color=lc
	U.loopA.TextColor3=lc
	U.loopOne.TextColor3=lit
	U.loopOne.TextTransparency=(M.loop=="one") and 0 or 1
	U.bLoop.BackgroundTransparency=(M.loop=="off") and 0.92 or 0.8

	-- playlist: highlight + mini equalizer on the current row
	for i,r in ipairs(U.rows) do
		local on=(i==M.idx)
		if on~=r.on then
			r.on=on
			tween(r.sel,0.25,{BackgroundTransparency=on and 0.55 or 1})
		end
		for k=1,3 do
			local e=r.eq[k]
			if on then
				e.BackgroundTransparency=0
				e.Size=UDim2.fromOffset(3,math.floor(3+(M.playing and 8*(0.5+0.5*math.sin(t*7+k*2)) or 1)))
			else
				e.BackgroundTransparency=1
			end
		end
	end
end)

gui.Destroying:Connect(function()
	pcall(function() snd:Stop() end)
end)
end -- [E:S:music]


-------------------------------------------------- COMBAT TAB  (aim lock + FOV circle + target marker)
-- (block-scoped: registers pages[4] and the S.cb* hooks the quick dial uses)
-- The lock is "arm and wait": press LOCK ON and it locks the first valid target that enters the FOV.
do -- [S:combat]
local cb=S.cb
local P1,P2=S.pal.cb1,S.pal.cb2     -- default palette (buttons / chips); circle + marker use X.cols()
local X={}
local U={}

-- shared helper: a labeled switch row (used by the Combat, Visual and Misc tabs)
function S.mkRow(parent,y,key,init,fn)
	bindText(label({AnchorPoint=Vector2.new(0,0.5),Position=UDim2.fromOffset(16,y),Size=UDim2.fromOffset(190,18),Text="",TextSize=13,TextXAlignment=Enum.TextXAlignment.Left},parent),key)
	local sw=makeSwitch(parent,UDim2.new(1,-14,0,y),init)
	local btn=new("TextButton",{Position=UDim2.fromOffset(0,y-18),Size=UDim2.new(1,0,0,36),BackgroundTransparency=1,Text="",AutoButtonColor=false,ClipsDescendants=true},parent)
	btn.InputBegan:Connect(function(i) if isPress(i) then ripple(btn,i) end end)
	btn.Activated:Connect(function() fn() end)
	return sw
end

------------------------------------------------ targets: players + (optional) NPCs
do -- [cb:core]
local PARTS={Head={"Head"},Torso={"UpperTorso","Torso"},Root={"HumanoidRootPart"},Feet={"LeftFoot","RightFoot","Left Leg","Right Leg"}}
local RND={"Head","Torso","Root","Feet"}
local rp=RaycastParams.new()
rp.FilterType=Enum.RaycastFilterType.Exclude
pcall(function() rp.RespectCanCollide=true end)
local ents={}          -- character -> entity {char,hum,plr,name}
X.npcs={}              -- model -> humanoid (filled while "Lock NPCs" has been used)

-- the body part that is aimed at right now ("Random" re-rolls every second or so)
function X.sel()
	if cb.part=="Random" then return cb.rnd end
	return cb.part
end
function X.roll()
	cb.rnd=RND[math.random(#RND)]
	cb.rndT=os.clock()+0.8+math.random()*0.8
end
function X.getPart(char,sel)
	for _,n in ipairs(PARTS[sel] or PARTS.Head) do
		local p=char:FindFirstChild(n)
		if p and p:IsA("BasePart") then return p end
	end
	return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
end
function X.entOf(char,plr)
	local hum=char:FindFirstChildOfClass("Humanoid")
	local e=ents[char]
	if not e then
		if not hum then return nil end
		e={char=char,hum=hum,plr=plr,name=plr and plr.DisplayName or char.Name}
		ents[char]=e
	elseif hum and e.hum~=hum then
		e.hum=hum
	end
	return e
end
function X.prune()
	for ch in pairs(ents) do
		if not ch.Parent then ents[ch]=nil end
	end
end
function X.alive(e)
	return e.char.Parent~=nil and e.hum.Parent~=nil and e.hum.Health>0
end
function X.sameTeam(plr)
	return player.Team~=nil and plr.Team==player.Team
end

-- colors of the FOV circle / marker / combat dial: idle, idle 2, locked
function X.cols()
	local h1=cb.h1
	return Color3.fromHSV(h1/360,0.72,1),Color3.fromHSV(((h1+45)%360)/360,0.75,1),Color3.fromHSV(cb.h2/360,0.84,1)
end
S.cbCols=X.cols

-- NPC tracking: every Humanoid in the workspace that does not belong to a player
do
local tracking=false
local function consider(inst)
	if inst:IsA("Humanoid") then
		local m=inst.Parent
		if m and m:IsA("Model") and not Players:GetPlayerFromCharacter(m) and m~=player.Character then
			X.npcs[m]=inst
		end
	end
end
function X.trackNpcs()
	if tracking then return end
	tracking=true
	connect(workspace.DescendantAdded,consider)
	connect(workspace.DescendantRemoving,function(inst)
		if inst:IsA("Humanoid") and inst.Parent then X.npcs[inst.Parent]=nil end
	end)
	task.spawn(function()
		local n=0
		for _,d in ipairs(workspace:GetDescendants()) do
			consider(d)
			n=n+1
			if n%1500==0 then task.wait() end
		end
	end)
end
end

-- all entities that may be targeted right now (team filter applies to players)
function X.cands()
	local list={}
	for _,plr in ipairs(Players:GetPlayers()) do
		if plr~=player and not (cb.team and X.sameTeam(plr)) then
			local ch=plr.Character
			if ch then
				local e=X.entOf(ch,plr)
				if e then list[#list+1]=e end
			end
		end
	end
	if cb.npc then
		for m,hum in pairs(X.npcs) do
			if not m.Parent or not hum.Parent then
				X.npcs[m]=nil
			elseif not Players:GetPlayerFromCharacter(m) and m~=player.Character then
				local e=X.entOf(m,nil)
				if e then list[#list+1]=e end
			end
		end
	end
	return list
end

-- characters never count as walls for the wall check
function X.buildFilter()
	local list={}
	for _,p in ipairs(Players:GetPlayers()) do
		if p.Character then list[#list+1]=p.Character end
	end
	if cb.npc then
		for m in pairs(X.npcs) do list[#list+1]=m end
	end
	rp.FilterDescendantsInstances=list
end
function X.visible(part)
	local c=workspace.CurrentCamera
	if not c then return true end
	local o=c.CFrame.Position
	return workspace:Raycast(o,part.Position-o,rp)==nil
end

-- best candidate inside the FOV circle. Priority: closest to the crosshair / nearest / farthest
function X.pick(exclude)
	local c=workspace.CurrentCamera
	if not c then return nil end
	local center=c.ViewportSize/2
	local cpos=c.CFrame.Position
	local sel=X.sel()
	if cb.wall then X.buildFilter() end
	local best,bs=nil,nil
	for _,e in ipairs(X.cands()) do
		if e~=exclude and X.alive(e) then
			local part=X.getPart(e.char,sel)
			if part then
				local v=c:WorldToViewportPoint(part.Position)
				if v.Z>0 then
					local sd=(Vector2.new(v.X,v.Y)-center).Magnitude
					if sd<=cb.fov and (not cb.wall or X.visible(part)) then
						local wd=(part.Position-cpos).Magnitude
						local score=sd
						if cb.prio=="Near" then score=wd elseif cb.prio=="Far" then score=-wd end
						if bs==nil or score<bs then
							best,bs=e,score
						end
					end
				end
			end
		end
	end
	return best
end
-- every valid candidate inside the FOV, best first (used by the "next target" button)
function X.ranked(exclude)
	local c=workspace.CurrentCamera
	if not c then return {} end
	local center=c.ViewportSize/2
	local cpos=c.CFrame.Position
	local sel=X.sel()
	if cb.wall then X.buildFilter() end
	local arr={}
	for _,e in ipairs(X.cands()) do
		if e~=exclude and X.alive(e) then
			local part=X.getPart(e.char,sel)
			if part then
				local v=c:WorldToViewportPoint(part.Position)
				if v.Z>0 then
					local sd=(Vector2.new(v.X,v.Y)-center).Magnitude
					if sd<=cb.fov and (not cb.wall or X.visible(part)) then
						local wd=(part.Position-cpos).Magnitude
						local score=sd
						if cb.prio=="Near" then score=wd elseif cb.prio=="Far" then score=-wd end
						arr[#arr+1]={e=e,s=score}
					end
				end
			end
		end
	end
	table.sort(arr,function(a,b) return a.s<b.s end)
	local out={}
	for i,v in ipairs(arr) do out[i]=v.e end
	return out
end
end -- [E:cb:core]

------------------------------------------------ FOV circle on screen (radar scope)
do -- [cb:fov]
local NT2=72
local GREY1,GREY2=Color3.fromRGB(150,160,190),Color3.fromRGB(110,120,150)
local Fv={fa=0,fr=cb.fov,ap=-1,c1=P1,c2=P2,flash=0,rip=0,hold=0}

local fov=new("Frame",{Name="FovCircle",AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(4,4),BackgroundTransparency=1,BorderSizePixel=0,Visible=false,ZIndex=3},gui)
local fScale=new("UIScale",{Scale=0.9},fov)
local function disc(z)
	local f=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(4,4),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=z},fov)
	corner(f,999)
	return f
end
local d1,d2,r1,r2=disc(1),disc(1),disc(2),disc(2)
local r1s=stroke(r1,C.White,1.4,1)
local r2s=stroke(r2,C.White,1,1)

local function holder(z)
	return new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(4,4),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=z},fov)
end
-- bezel ticks (rotate slowly, a bright comet runs around them)
local tkHold=holder(3)
local ticks={}
for k=1,NT2 do
	local rot=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(4,4),Rotation=(k-1)*360/NT2,BackgroundTransparency=1,BorderSizePixel=0},tkHold)
	ticks[k]=new("Frame",{AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0.5,-100),Size=UDim2.fromOffset(2,6),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0},rot)
end
-- radar sweep: 14 fading beams trailing a rotating line
local swHold=holder(2)
local sweeps={}
for k=1,14 do
	local rot=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(4,4),Rotation=-(k-1)*3.4,BackgroundTransparency=1,BorderSizePixel=0},swHold)
	local bar=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,-50),Size=UDim2.fromOffset(2,100),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0},rot)
	new("UIGradient",{Rotation=90,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(1,1)})},bar)
	sweeps[k]=bar
end
-- tiny crosshair in the middle
local crossHold=holder(3)
local cross={}
for k=0,3 do
	local rot=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(4,4),Rotation=k*90,BackgroundTransparency=1,BorderSizePixel=0},crossHold)
	cross[k+1]=new("Frame",{AnchorPoint=Vector2.new(0.5,1),Position=UDim2.new(0.5,0,0.5,-5),Size=UDim2.fromOffset(2,8),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0},rot)
end
local cdot=disc(3)

local function applyRadius(fr)
	Fv.ap=fr
	local d=fr*2
	d1.Size=UDim2.fromOffset(d,d)
	local s2=d*0.72
	d2.Size=UDim2.fromOffset(s2,s2)
	r1.Size=UDim2.fromOffset(d,d)
	local s3=d*0.84
	r2.Size=UDim2.fromOffset(s3,s3)
	for k=1,NT2 do ticks[k].Position=UDim2.new(0.5,0,0.5,-fr) end
	local w=math.max(2,fr*0.058)
	for k=1,14 do
		sweeps[k].Position=UDim2.new(0.5,0,0.5,-fr/2)
		sweeps[k].Size=UDim2.fromOffset(w,fr)
	end
end

function X.fovFrame(t,dt)
	local want=cb.dialOpen or (cb.showFov and (cb.lock or (activeTab==4 and uiVisible and not minimized))) or t<Fv.hold
	Fv.fa=Fv.fa+((want and 1 or 0)-Fv.fa)*math.min(1,dt*7)
	local fa=Fv.fa
	if fa<0.01 then
		fov.Visible=false
		Fv.fr=cb.fov
		Fv.ap=-1
		return
	end
	fov.Visible=true
	Fv.fr=Fv.fr+(cb.fov-Fv.fr)*math.min(1,dt*10)
	if math.abs(Fv.fr-Fv.ap)>0.4 then applyRadius(Fv.fr) end
	local fr=Fv.fr

	local i1,i2,lk=X.cols()
	local locked=cb.lock and cb.tgt~=nil
	local searching=cb.lock and cb.tgt==nil
	local t1,t2
	if cb.lock then
		if cb.tgt then
			if cb.blocked then t1,t2=GREY1,GREY2 else t1,t2=lk,i1 end
		else
			t1,t2=i2,i2
		end
	elseif t<cb.prevLockT+0.7 then
		t1,t2=lk,i1                       -- previewing the "locked" color while its slider is moved
	else
		t1,t2=i1,i2
	end
	local kk=math.min(1,dt*8)
	Fv.c1=Fv.c1:Lerp(t1,kk)
	Fv.c2=Fv.c2:Lerp(t2,kk)
	local c1,c2=Fv.c1,Fv.c2
	Fv.flash=math.max(0,Fv.flash-dt*2.2)
	local fl=Fv.flash
	local pulse=math.sin(t*2.2)

	fScale.Scale=0.9+0.1*fa+0.04*fl
	d1.BackgroundColor3=c1
	d1.BackgroundTransparency=1-math.clamp((0.06+0.03*pulse+0.2*fl)*fa,0,1)
	d2.BackgroundColor3=c2
	d2.BackgroundTransparency=1-math.clamp((0.05+0.02*pulse+0.08*fl)*fa,0,1)
	r1s.Color=c1
	r1s.Transparency=1-math.clamp((0.6+0.3*fl)*fa,0,1)
	r2s.Color=c2
	r2s.Transparency=1-0.28*fa

	-- ticks + comet
	tkHold.Rotation=(t*(locked and 22 or 6))%360
	local head=((t*(searching and 1.1 or 0.45))%1)*NT2
	for k=1,NT2 do
		local major=(k%6==1)
		local dd=math.abs(k-head)
		dd=math.min(dd,NT2-dd)
		local boost=math.max(0,1-dd/9)
		local al=math.clamp(((major and 0.75 or 0.4)+boost*0.6+fl*0.3)*fa,0,1)
		local tk=ticks[k]
		tk.BackgroundTransparency=1-al
		tk.BackgroundColor3=c1:Lerp(c2,math.sin((k-1)/NT2*math.pi)):Lerp(C.White,boost*0.7)
		tk.Size=UDim2.fromOffset(2,(major and 12 or 6)+boost*7)
	end

	-- radar sweep (fast while searching, dim while locked)
	swHold.Rotation=(t*(searching and 220 or 75))%360
	local sa=(locked and 0.3 or 1)*fa
	for k=1,14 do
		local bar=sweeps[k]
		bar.BackgroundColor3=c1
		bar.BackgroundTransparency=1-sa*0.5*(1-(k-1)/14)^1.6
	end

	-- crosshair
	crossHold.Rotation=(t*(locked and 120 or 20))%360
	for k=1,4 do
		cross[k].BackgroundColor3=c1
		cross[k].BackgroundTransparency=1-0.55*fa
	end
	local cs=3+(locked and 3 or 0)+pulse
	cdot.Size=UDim2.fromOffset(cs,cs)
	cdot.BackgroundColor3=locked and lk or c1
	cdot.BackgroundTransparency=1-0.8*fa

	-- ripple rings while the radius is being changed
	if t-cb.fovT<0.3 and t>Fv.rip then
		Fv.rip=t+0.11
		shockwave(fov,UDim2.fromScale(0.5,0.5),fr*2,fr*2+70,1.5,0.5,0,{a1=c1},0.4)
	end
end

function X.fovFx(kind)
	Fv.hold=os.clock()+0.9
	local i1,i2,lk=X.cols()
	local mid=UDim2.fromScale(0.5,0.5)
	local d=Fv.fr*2
	if kind=="lock" then
		Fv.flash=1
		shockwave(fov,mid,d,40,3,0.5,0,{a1=lk},0.05)
		shockwave(fov,mid,60,d+90,1.5,0.7,0.15,{a1=i2},0.3)
	elseif kind=="arm" then
		Fv.flash=0.6
		shockwave(fov,mid,40,d+40,2,0.6,0,{a1=i2},0.2)
	elseif kind=="switch" then
		Fv.flash=0.7
		shockwave(fov,mid,60,d+60,2,0.5,0,{a1=i2},0.2)
	else -- "drop"
		shockwave(fov,mid,60,d+120,2,0.6,0,{a1=i1},0.3)
	end
end
end -- [E:cb:fov]

------------------------------------------------ target marker (icon on the locked target)
do -- [cb:marker]
local GREY=Color3.fromRGB(150,160,190)
local mk={}

local function arcRing(parent,d,th)
	local f=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(d,d),BackgroundTransparency=1,BorderSizePixel=0},parent)
	corner(f,999)
	local s=stroke(f,C.White,th,1)
	local g=new("UIGradient",{Color=ColorSequence.new(P1,P2),Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(0.38,1),NumberSequenceKeypoint.new(1,1)})},s)
	return s,g
end

function X.newMarker(e,part,style)
	local bb=new("BillboardGui",{Name="NeonFlyBB",Adornee=part,AlwaysOnTop=true,Size=UDim2.fromOffset(190,190),LightInfluence=0,ResetOnSpawn=false},playerGui)
	local root=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(120,120),BackgroundTransparency=1,BorderSizePixel=0},bb)
	local scl=new("UIScale",{Scale=2.4},root)
	local sA,gA=arcRing(root,100,2.2)
	local sB,gB=arcRing(root,72,1.6)

	-- four corner brackets that snap in
	local brk=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(4,4),BackgroundTransparency=1,BorderSizePixel=0},root)
	local bars={}
	for k=0,3 do
		local pv=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(4,4),Rotation=k*90,BackgroundTransparency=1,BorderSizePixel=0},brk)
		bars[#bars+1]=new("Frame",{Position=UDim2.new(0.5,-40,0.5,-40),Size=UDim2.fromOffset(14,2),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0},pv)
		bars[#bars+1]=new("Frame",{Position=UDim2.new(0.5,-40,0.5,-40),Size=UDim2.fromOffset(2,14),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0},pv)
	end
	-- crosshair ticks + glowing core
	local tks={}
	for k=0,3 do
		local pv=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(4,4),Rotation=k*90,BackgroundTransparency=1,BorderSizePixel=0},root)
		tks[k+1]=new("Frame",{AnchorPoint=Vector2.new(0.5,1),Position=UDim2.new(0.5,0,0.5,-16),Size=UDim2.fromOffset(2,9),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0},pv)
	end
	local glow=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(20,20),BackgroundColor3=P1,BackgroundTransparency=1,BorderSizePixel=0},root)
	corner(glow,999)
	local dot=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(6,6),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0},root)
	corner(dot,999)
	-- name / distance / health under the reticle
	local lbl=label({AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0.5,64),Size=UDim2.fromOffset(180,14),Text=e.name,TextSize=12,Font=Enum.Font.GothamBold,TextTransparency=1},bb)
	local lblS=tstroke(lbl,C.Ink,1.6)
	local hpBg=new("Frame",{AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0.5,81),Size=UDim2.fromOffset(72,5),BackgroundColor3=C.Ink,BackgroundTransparency=1,BorderSizePixel=0},bb)
	corner(hpBg,3)
	local hpFill=new("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(110,255,170),BackgroundTransparency=1,BorderSizePixel=0},hpBg)
	corner(hpFill,3)

	local M={e=e,part=part,bb=bb,root=root,scl=scl,sA=sA,sB=sB,gA=gA,gB=gB,brk=brk,bars=bars,tks=tks,
		glow=glow,dot=dot,lbl=lbl,lblS=lblS,hpBg=hpBg,hpFill=hpFill,age=0,a=0,dying=false,style=style,cs=-1,hp=1,acc=1}
	mk[#mk+1]=M

	-- lock-in effect
	local i1,i2,lk=X.cols()
	local mid=UDim2.fromScale(0.5,0.5)
	if style=="lock" then
		shockwave(root,mid,30,170,2.5,0.6,0,{a1=lk},0.1)
		shockwave(root,mid,20,120,1.5,0.5,0.12,{a1=i2},0.2)
		burst(root,mid,12,{a1=lk,a2=i2},70)
	else
		shockwave(root,mid,24,130,2,0.45,0,{a1=i2},0.15)
	end
	return M
end

function X.killMarker(M,style)
	if not M or M.dying then return end
	M.dying=true
	M.style=style
	if style=="kill" then
		local _,i2,lk=X.cols()
		local mid=UDim2.fromScale(0.5,0.5)
		shockwave(M.root,mid,40,190,3,0.6,0,{a1=lk},0.05)
		burst(M.root,mid,18,{a1=lk,a2=i2},80)
	end
end

local function applyAlpha(M,a)
	M.sA.Transparency=1-a
	M.sB.Transparency=1-a*0.8
	for _,b in ipairs(M.bars) do b.BackgroundTransparency=1-a end
	for _,tk in ipairs(M.tks) do tk.BackgroundTransparency=1-a*0.8 end
	M.dot.BackgroundTransparency=1-a
	M.glow.BackgroundTransparency=1-0.45*a
	M.lbl.TextTransparency=1-a
	M.lblS.Transparency=1-0.65*a
	M.hpBg.BackgroundTransparency=1-0.6*a
	M.hpFill.BackgroundTransparency=1-a
end

local function hpColor(r)
	if r>0.5 then
		return Color3.fromRGB(255,214,70):Lerp(Color3.fromRGB(110,255,170),(r-0.5)*2)
	end
	return Color3.fromRGB(255,80,90):Lerp(Color3.fromRGB(255,214,70),r*2)
end

function X.markerFrame(t,dt)
	for i=#mk,1,-1 do
		local M=mk[i]
		M.age=M.age+dt
		if M.dying then
			local kill=(M.style=="kill")
			M.a=M.a-dt*(kill and 1.7 or 4.2)
			if M.a<=0 then
				M.bb:Destroy()
				table.remove(mk,i)
			else
				M.scl.Scale=kill and (1+(1-M.a)*1.2) or (1-(1-M.a)*0.35)
				if kill then M.brk.Rotation=M.brk.Rotation+dt*260 end
				applyAlpha(M,M.a)
			end
		else
			M.a=math.min(1,M.a+dt*7)
			local blocked=cb.blocked
			local a=M.a*(blocked and 0.55 or 1)
			local _,i2,lk=X.cols()
			local c1,c2=lk,i2
			if blocked then c1,c2=GREY,GREY end
			M.gA.Color=ColorSequence.new(c1,c2)
			M.gB.Color=ColorSequence.new(c2,c1)
			M.glow.BackgroundColor3=c1
			local intro=math.max(0,1-M.age/0.55)
			M.scl.Scale=1+1.4*intro*intro
			M.gA.Rotation=(t*150)%360
			M.gB.Rotation=(-t*105)%360
			M.brk.Rotation=(t*28+170*intro)%360
			local bs=38+30*intro*intro+2*math.sin(t*4)
			local bc=C.White:Lerp(c1,math.clamp(M.age*3,0,1))
			for _,b in ipairs(M.bars) do
				b.Position=UDim2.new(0.5,-bs,0.5,-bs)
				b.BackgroundColor3=bc
			end
			for _,tk in ipairs(M.tks) do tk.BackgroundColor3=bc end
			local ds=6+3*math.sin(t*6)
			M.dot.Size=UDim2.fromOffset(ds,ds)
			local gs=18+8*math.sin(t*6+1)
			M.glow.Size=UDim2.fromOffset(gs,gs)
			applyAlpha(M,a)

			-- name / distance / health (a few times per second)
			M.acc=M.acc+dt
			if M.acc>0.15 then
				M.acc=0
				local cam=workspace.CurrentCamera
				local dist=(cam and M.part.Parent) and (cam.CFrame.Position-M.part.Position).Magnitude or 0
				M.lbl.Text=M.e.name.."  ·  "..math.floor(dist).." st"
				M.lbl.TextColor3=blocked and GREY or C.White
				if M.e.hum.Parent then M.hpT=math.clamp(M.e.hum.Health/math.max(M.e.hum.MaxHealth,1),0,1) end
			end
			M.hp=M.hp+((M.hpT or 1)-M.hp)*math.min(1,dt*8)
			M.hpFill.Size=UDim2.fromScale(M.hp,1)
			M.hpFill.BackgroundColor3=hpColor(M.hp)
		end
	end
end

function X.clearMarkers()
	for _,M in ipairs(mk) do
		if M.bb then M.bb:Destroy() end
	end
	mk={}
end
end -- [E:cb:marker]

------------------------------------------------ lock logic: arm -> wait for a target -> lock -> auto switch
do -- [cb:logic]
local curM=nil
local aimOn=false
local scan=0
local prune=0

local function aimStep()
	local e=cb.tgt
	if not e then return end
	local part=X.getPart(e.char,X.sel())
	local c=workspace.CurrentCamera
	if not part or not c then return end
	if cb.wall then
		X.buildFilter()
		if not X.visible(part) then
			cb.blocked=true
			return
		end
	end
	cb.blocked=false
	c.CFrame=CFrame.new(c.CFrame.Position,part.Position)
end
local function bindAim()
	if aimOn then return end
	aimOn=true
	pcall(function() RunService:UnbindFromRenderStep("NeonFlyAim") end)
	RunService:BindToRenderStep("NeonFlyAim",Enum.RenderPriority.Camera.Value+1,aimStep)
end
local function unbindAim()
	if not aimOn then return end
	aimOn=false
	pcall(function() RunService:UnbindFromRenderStep("NeonFlyAim") end)
end

local function spawnMarker(e,style)
	local part=X.getPart(e.char,X.sel())
	if not part then return end
	if curM then X.killMarker(curM,"drop") end
	curM=X.newMarker(e,part,style)
end
local function tgtOk(e)
	return e.char.Parent~=nil and e.hum.Parent~=nil and e.hum.Health>0 and X.getPart(e.char,X.sel())~=nil
end

-- a target was found: lock it
local function acquire(e,style)
	cb.tgt=e
	cb.blocked=false
	spawnMarker(e,style)
	X.fovFx(style=="lock" and "lock" or "switch")
	sfx("ping",0.5,style=="lock" and 1.6 or 1.2)
	sfx("switch",0.4,1.4)
	toast(tr("cb_locked").."  "..e.name)
end
-- armed: keeps scanning until something enters the FOV
local function arm()
	cb.lock=true
	cb.tgt=nil
	cb.blocked=false
	if cb.npc then X.trackNpcs() end
	bindAim()
	X.fovFx("arm")
	sfx("switch",0.5,1.3)
	local e=X.pick(nil)
	if e then acquire(e,"lock") end
end
local function disarm()
	cb.lock=false
	cb.tgt=nil
	cb.blocked=false
	unbindAim()
	if curM then
		X.killMarker(curM,"drop")
		curM=nil
	end
	X.fovFx("drop")
	sfx("switch",0.4,0.8)
end

function S.cbToggle()
	if cb.lock then disarm() else arm() end
end
-- jump to the next target (in priority order) without unlocking; arms first if it was off
function S.cbNext()
	if not cb.lock then
		arm()
		return
	end
	local list=X.ranked(nil)
	if #list==0 then
		sfx("ping",0.4,0.6)
		X.fovFx("arm")
		return
	end
	local cur=cb.tgt
	local pick=list[1]
	if cur then
		for i,e in ipairs(list) do
			if e==cur then
				pick=list[i%#list+1]
				break
			end
		end
		if pick==cur then
			sfx("ping",0.4,0.6)
			return
		end
	end
	acquire(pick,"switch")
end
-- lock one specific player (from the player list); tapping the same player again unlocks
function S.cbLockPlayer(plr)
	local ch=plr.Character
	local e=ch and X.entOf(ch,plr)
	if not e or not X.alive(e) then
		sfx("ping",0.4,0.6)
		return
	end
	if cb.lock and cb.tgt==e then
		disarm()
	elseif cb.lock then
		acquire(e,"switch")
	else
		cb.lock=true
		cb.blocked=false
		bindAim()
		acquire(e,"lock")
	end
end

-- the current target died / left / lost its body part
local function lost()
	if curM then
		X.killMarker(curM,"kill")
		curM=nil
	end
	cb.tgt=nil
	sfx("ping",0.4,0.7)
	if cb.auto then
		local n=X.pick(nil)
		if n then acquire(n,"switch") end   -- otherwise it simply keeps scanning
	else
		disarm()
	end
end

function S.setFov(v)
	v=math.clamp(math.floor(v+0.5),30,600)
	if v==cb.fov then return end
	cb.fov=v
	cb.fovT=os.clock()
	savePref("cbfov",v)
	if S.fovUI then S.fovUI(v) end
end

connect(RunService.RenderStepped,function(dt)
	local t=os.clock()
	if cb.part=="Random" and t>cb.rndT then X.roll() end
	if cb.lock then
		if cb.tgt then
			if not tgtOk(cb.tgt) then
				lost()
			elseif curM then
				-- the body part changed (menu or random roll): move the marker
				local part=X.getPart(cb.tgt.char,X.sel())
				if part and part~=curM.part then
					curM.part=part
					curM.bb.Adornee=part
					sfx("tick",0.3,1.5)
				end
			end
		else
			scan=scan+dt
			if scan>0.15 then
				scan=0
				local n=X.pick(nil)
				if n then acquire(n,"lock") end
			end
		end
	end
	prune=prune+dt
	if prune>6 then
		prune=0
		X.prune()
	end
	X.fovFrame(t,dt)
	X.markerFrame(t,dt)
end)

gui.Destroying:Connect(function()
	unbindAim()
	X.clearMarkers()
end)
end -- [E:cb:logic]

------------------------------------------------ the tab itself
do -- [cb:ui]
local page=new("ScrollingFrame",{
	Position=UDim2.fromScale(3,0),Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0,
	ScrollBarThickness=3,ScrollBarImageColor3=C.White,ScrollBarImageTransparency=0.6,
	CanvasSize=UDim2.new(0,0,0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollingDirection=Enum.ScrollingDirection.Y},pagesHolder)
pages[4]=page
new("UIListLayout",{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder,HorizontalAlignment=Enum.HorizontalAlignment.Center},page)
new("UIPadding",{PaddingTop=UDim.new(0,10),PaddingBottom=UDim.new(0,12)},page)

local function title(parent,key)
	local l=bindText(label({Position=UDim2.fromOffset(14,8),Size=UDim2.new(1,-28,0,18),Text="",TextSize=14,Font=Enum.Font.GothamBlack,TextColor3=C.White,TextXAlignment=Enum.TextXAlignment.Left},parent),key)
	grad(l,P1,P2,0)
	return l
end

-- a row of equal chips; `get` returns the selected key, `set` changes it
local function chipRow(parent,y,keys,tkeys,w,get,set)
	local grid=new("Frame",{Position=UDim2.fromOffset(8,y),Size=UDim2.fromOffset(300,70),BackgroundTransparency=1,BorderSizePixel=0},parent)
	new("UIGridLayout",{CellSize=UDim2.fromOffset(w,30),CellPadding=UDim2.fromOffset(9,6),SortOrder=Enum.SortOrder.LayoutOrder},grid)
	local chips={}
	local function paint(instant)
		for _,c in ipairs(chips) do
			local sel=(get()==c.key)
			local tp=sel and 0 or 1
			local tc=sel and C.White or C.Text
			if instant then
				c.fill.BackgroundTransparency=tp
				c.lbl.TextColor3=tc
			else
				tween(c.fill,0.25,{BackgroundTransparency=tp})
				tween(c.lbl,0.25,{TextColor3=tc})
			end
		end
	end
	for idx,key in ipairs(keys) do
		local b=new("TextButton",{LayoutOrder=idx,BackgroundColor3=C.White,BackgroundTransparency=0.93,Text="",AutoButtonColor=false,BorderSizePixel=0,ClipsDescendants=true},grid)
		corner(b,10)
		local f=new("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0},b)
		corner(f,10)
		grad(f,P1,P2,0)
		local l=bindText(label({Size=UDim2.fromScale(1,1),Text="",TextSize=12,TextColor3=C.Text,ZIndex=2},b),tkeys[idx])
		chips[idx]={key=key,fill=f,lbl=l}
		b.InputBegan:Connect(function(i) if isPress(i) then ripple(b,i) end end)
		b.Activated:Connect(function()
			sfx("click",0.4,1.1)
			if get()~=key then
				set(key)
				paint(false)
			end
		end)
	end
	paint(true)
end

-- 1) the big LOCK button ---------------------------------------------------------
do
local lc=card(page,112,nil,1)
title(lc,"cb_aim")
U.info=label({AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-14,0,9),Size=UDim2.fromOffset(190,14),Text="",TextSize=10,Font=Enum.Font.Gotham,TextColor3=C.Muted,TextXAlignment=Enum.TextXAlignment.Right},lc)
local btn=new("TextButton",{Position=UDim2.fromOffset(14,34),Size=UDim2.fromOffset(W-24-28-72,64),BackgroundColor3=C.White,Text="",AutoButtonColor=false,BorderSizePixel=0,ClipsDescendants=true},lc)
corner(btn,14)
local bfill=grad(btn,P1,P2,0)
local veil=new("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=C.Ink,BackgroundTransparency=0.5,BorderSizePixel=0,ZIndex=1},btn)
corner(veil,14)
local bstroke=stroke(btn,C.White,2,0.35)
local bsg=new("UIGradient",{Color=ColorSequence.new({ColorSequenceKeypoint.new(0,C.White),ColorSequenceKeypoint.new(0.5,P2),ColorSequenceKeypoint.new(1,C.White)})},bstroke)

-- animated reticle icon
local ret=new("Frame",{AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,18,0.5,0),Size=UDim2.fromOffset(40,40),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=3},btn)
local retScale=new("UIScale",{Scale=1},ret)
local ring=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(26,26),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=3},ret)
corner(ring,999)
stroke(ring,C.White,2,0)
for k=0,3 do
	local pv=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(4,4),Rotation=k*90,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=3},ret)
	new("Frame",{AnchorPoint=Vector2.new(0.5,1),Position=UDim2.new(0.5,0,0.5,-12),Size=UDim2.fromOffset(2,8),BackgroundColor3=C.White,BorderSizePixel=0,ZIndex=3},pv)
end
local rdot=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(6,6),BackgroundColor3=C.White,BorderSizePixel=0,ZIndex=3},ret)
corner(rdot,999)

local btnL=label({Position=UDim2.fromOffset(72,11),Size=UDim2.new(1,-84,0,24),Text="",TextSize=17,Font=Enum.Font.GothamBlack,TextColor3=C.White,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=3},btn)
U.sub=label({Position=UDim2.fromOffset(72,36),Size=UDim2.new(1,-84,0,14),Text="",TextSize=10,Font=Enum.Font.Gotham,TextColor3=C.Text,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=3},btn)

btn.InputBegan:Connect(function(i) if isPress(i) then ripple(btn,i) end end)
btn.Activated:Connect(function()
	sfx("click",0.4,1.1)
	S.cbToggle()
end)

-- NEXT: switch to another target without unlocking
local nb=new("TextButton",{Position=UDim2.fromOffset(14+(W-24-28-72)+8,34),Size=UDim2.fromOffset(64,64),BackgroundColor3=C.White,Text="",AutoButtonColor=false,BorderSizePixel=0,ClipsDescendants=true},lc)
corner(nb,14)
local nbF=grad(nb,P2,P1,0)
local nbV=new("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=C.Ink,BackgroundTransparency=0.55,BorderSizePixel=0,ZIndex=1},nb)
corner(nbV,14)
local nbS=stroke(nb,C.White,2,0.5)
local nbC={}
for k=1,2 do
	nbC[k]=label({AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,(k-1.5)*9,0.42,0),Size=UDim2.fromOffset(16,16),Text="▶",TextSize=16,TextColor3=C.White,TextTruncate=Enum.TextTruncate.None,ZIndex=3},nb)
end
bindText(label({AnchorPoint=Vector2.new(0.5,1),Position=UDim2.new(0.5,0,1,-6),Size=UDim2.new(1,0,0,12),Text="",TextSize=9,Font=Enum.Font.GothamBlack,TextColor3=C.Text,ZIndex=3},nb),"cb_next")
nb.InputBegan:Connect(function(i) if isPress(i) then ripple(nb,i) end end)
nb.Activated:Connect(function()
	sfx("click",0.4,1.4)
	S.cbNext()
end)

local lkv,wasLock=0,nil
local function paintText()
	btnL.Text=cb.lock and tr("cb_unlock") or tr("cb_lock")
end
onLang(function() wasLock=nil paintText() end)
connect(RunService.RenderStepped,function(dt)
	if not (activeTab==4 and uiVisible and not minimized) then return end
	local t=os.clock()
	if wasLock~=cb.lock then
		wasLock=cb.lock
		paintText()
	end
	local _,_,lk=X.cols()
	lkv=lkv+((cb.lock and 1 or 0)-lkv)*math.min(1,dt*8)
	bfill.Color=ColorSequence.new(P1:Lerp(lk,lkv),P2:Lerp(P1,lkv))
	bsg.Rotation=(t*(90+120*lkv))%360
	bstroke.Transparency=0.35-0.2*lkv*(0.5+0.5*math.sin(t*6))
	ret.Rotation=(t*(40+300*lkv))%360
	retScale.Scale=1-0.16*lkv+0.05*math.sin(t*5)
	rdot.BackgroundColor3=C.White:Lerp(lk,lkv)
	-- NEXT button: chevrons slide while a lock is armed, dim otherwise
	for k=1,2 do
		nbC[k].Position=UDim2.new(0.5,(k-1.5)*9+3*lkv*math.sin(t*7-k),0.42,0)
		nbC[k].TextTransparency=0.6-0.6*lkv
	end
	nbS.Transparency=0.55-0.35*lkv
	nbF.Color=ColorSequence.new(P2:Lerp(lk,lkv),P1:Lerp(lk,lkv))
end)
end

-- 2) body part (Head / Torso / Root / Feet / Random) -------------------------------------
do
local pc=card(page,108,nil,2)
title(pc,"cb_part")
chipRow(pc,32,{"Head","Torso","Root","Feet","Random"},{"cb_head","cb_torso","cb_root","cb_feet","cb_random"},94,
	function() return cb.part end,
	function(k)
		cb.part=k
		savePref("cbpart",k)
		if k=="Random" then X.roll() end
	end)
end

-- 3) priority: crosshair / nearest / farthest ---------------------------------------------
do
local pc=card(page,76,nil,3)
title(pc,"cb_prio")
chipRow(pc,32,{"Cross","Near","Far"},{"cb_pcross","cb_pnear","cb_pfar"},94,
	function() return cb.prio end,
	function(k)
		cb.prio=k
		savePref("cbprio",k)
	end)
end

-- 4) filters -----------------------------------------------------------------------
do
local fc=card(page,222,nil,4)
title(fc,"cb_filters")
local function row(y,key,field,pk,after)
	local sw
	sw=S.mkRow(fc,y,key,cb[field],function()
		cb[field]=not cb[field]
		sw.set(cb[field])
		savePref(pk,cb[field])
		sfx("switch",0.6,cb[field] and 1.25 or 0.8)
		if after then after(cb[field]) end
	end)
end
row(48,"cb_wall","wall","cbwall")
row(86,"cb_team","team","cbteam")
row(124,"cb_auto","auto","cbauto")
row(162,"cb_npc","npc","cbnpc",function(on) if on then X.trackNpcs() end end)
row(200,"cb_showfov","showFov","cbshow")
if cb.npc then X.trackNpcs() end
end

-- 5) FOV slider --------------------------------------------------------------------
do
local fc=card(page,70,nil,5)
bindText(label({Position=UDim2.fromOffset(16,10),Size=UDim2.fromOffset(150,16),Text="",TextSize=12,TextColor3=C.Muted,TextXAlignment=Enum.TextXAlignment.Left},fc),"cb_fov")
local fv=label({AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-16,0,7),Size=UDim2.fromOffset(80,22),Text=tostring(cb.fov),TextSize=18,Font=Enum.Font.GothamBlack,TextColor3=C.White,TextXAlignment=Enum.TextXAlignment.Right},fc)
grad(fv,P1,P2,0)
local sl=makeSlider({parent=fc,x=16,y=48,width=W-24-32,min=30,max=600,value=cb.fov,scroller=page,onChange=function(v,a)
	S.setFov(v)
	tickSfx(a)
end})
function S.fovUI(v)
	fv.Text=tostring(v)
	sl.set(v,true)
end
end

-- 6) FOV colors (idle + locked) ------------------------------------------------------
do
local cc=card(page,136,nil,6)
title(cc,"cb_colors")
local sw={}
local function hueRow(y,key,field,pk,isLock)
	bindText(label({Position=UDim2.fromOffset(16,y),Size=UDim2.fromOffset(150,14),Text="",TextSize=11,TextColor3=C.Muted,TextXAlignment=Enum.TextXAlignment.Left},cc),key)
	local s=new("Frame",{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-16,0,y-1),Size=UDim2.fromOffset(36,14),BackgroundColor3=C.White,BorderSizePixel=0},cc)
	corner(s,7)
	makeSlider({parent=cc,x=16,y=y+26,width=W-24-32,min=0,max=359,value=cb[field],rainbow=true,scroller=page,onChange=function(v)
		cb[field]=v
		savePref(pk,v)
		if isLock then cb.prevLockT=os.clock() end
		tickSfx(v/359)
	end})
	return s
end
sw.idle=hueRow(34,"cb_cidle","h1","cbh1",false)
sw.lock=hueRow(86,"cb_clock","h2","cbh2",true)
connect(RunService.RenderStepped,function()
	if not (activeTab==4 and uiVisible and not minimized) then return end
	local i1,_,lk=X.cols()
	sw.idle.BackgroundColor3=i1
	sw.lock.BackgroundColor3=lk
end)
end

-- 7) pick a player -----------------------------------------------------------------
do
local pc=card(page,172,nil,7)
title(pc,"cb_players")
local list=new("ScrollingFrame",{Position=UDim2.fromOffset(8,32),Size=UDim2.fromOffset(300,132),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=2,ScrollBarImageColor3=C.White,ScrollBarImageTransparency=0.6,CanvasSize=UDim2.new(0,0,0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollingDirection=Enum.ScrollingDirection.Y},pc)
new("UIListLayout",{Padding=UDim.new(0,4),SortOrder=Enum.SortOrder.LayoutOrder},list)
local empty=bindText(label({Position=UDim2.fromOffset(0,40),Size=UDim2.new(1,0,0,20),Text="",TextSize=11,Font=Enum.Font.Gotham,TextColor3=C.Muted,Visible=false},pc),"cb_noplayers")
local rows,order={},0

local function makeRow(plr)
	order=order+1
	local b=new("TextButton",{LayoutOrder=order,Size=UDim2.new(1,-6,0,28),BackgroundColor3=C.White,BackgroundTransparency=0.93,Text="",AutoButtonColor=false,BorderSizePixel=0,ClipsDescendants=true},list)
	corner(b,8)
	local sel=new("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0},b)
	corner(sel,8)
	grad(sel,P1,P2,0)
	local nm=label({Position=UDim2.fromOffset(10,0),Size=UDim2.new(1,-92,1,0),Text=plr.DisplayName,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=2},b)
	local ds=label({AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-10,0,0),Size=UDim2.fromOffset(74,28),Text="",TextSize=10,Font=Enum.Font.Gotham,TextColor3=C.Muted,TextXAlignment=Enum.TextXAlignment.Right,ZIndex=2},b)
	b.InputBegan:Connect(function(i) if isPress(i) then ripple(b,i) end end)
	b.Activated:Connect(function()
		sfx("click",0.4,1.1)
		S.cbLockPlayer(plr)
	end)
	rows[plr]={b=b,sel=sel,nm=nm,ds=ds,on=false}
end

local function sync()
	local cam=workspace.CurrentCamera
	local n=0
	for plr,r in pairs(rows) do
		if not plr.Parent then
			r.b:Destroy()
			rows[plr]=nil
		end
	end
	for _,plr in ipairs(Players:GetPlayers()) do
		if plr~=player then
			n=n+1
			if not rows[plr] then makeRow(plr) end
			local r=rows[plr]
			local ch=plr.Character
			local hum=ch and ch:FindFirstChildOfClass("Humanoid")
			local alive=hum~=nil and hum.Health>0
			local part=alive and ch:FindFirstChild("HumanoidRootPart")
			if part and cam then
				r.ds.Text=math.floor((cam.CFrame.Position-part.Position).Magnitude).." st"
			else
				r.ds.Text="–"
			end
			r.nm.TextTransparency=alive and 0 or 0.55
			local on=(cb.lock and cb.tgt~=nil and cb.tgt.plr==plr)
			if on~=r.on then
				r.on=on
				tween(r.sel,0.25,{BackgroundTransparency=on and 0.45 or 1})
			end
		end
	end
	empty.Visible=(n==0)
end

local acc=1
connect(RunService.RenderStepped,function(dt)
	if not (activeTab==4 and uiVisible and not minimized) then return end
	acc=acc+dt
	if acc>0.4 then
		acc=0
		pcall(sync)
		-- one-line summary on the lock card
		local txt="–"
		if cb.lock then
			if cb.tgt then
				txt=cb.tgt.name..(cb.blocked and "  ·  wall" or "")
			else
				txt=tr("cb_scan")
			end
		end
		U.info.Text=txt
		U.sub.Text=tr("cb_"..string.lower(cb.part)).."  ·  FOV "..cb.fov
	end
end)
end
end -- [E:cb:ui]
end -- [E:S:combat]


-------------------------------------------------- VISUAL TAB  (ESP: box / lines / health bar / names)
-- (block-scoped: registers pages[4] and the S.setEsp / S.setHue hooks the quick dial uses)
do -- [S:visual]
local vz=S.vz

------------------------------------------------ ESP engine
do -- [vz:esp]
local ents={}
local order=0
-- full-screen holder for the tracer lines + scan waves (sits under the window)
local hold=new("Frame",{Name="EspLines",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=2},gui)

local function cols()
	local h=vz.hue
	return Color3.fromHSV(h/360,0.85,1),Color3.fromHSV(((h+55)%360)/360,0.8,1)
end
local function hpColor(r)
	if r>0.5 then
		return Color3.fromRGB(255,214,70):Lerp(Color3.fromRGB(110,255,170),(r-0.5)*2)
	end
	return Color3.fromRGB(255,80,90):Lerp(Color3.fromRGB(255,214,70),r*2)
end
local function kill(E)
	if E.bb then E.bb:Destroy() end
	if E.tb then E.tb:Destroy() end
	if E.tr then E.tr:Destroy() end
end

-- one entity per enemy: box billboard + name/health billboard + screen-space tracer line
local function make(plr,ch)
	local hrp=ch:FindFirstChild("HumanoidRootPart")
	local hum=ch:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum then return nil end
	local head=ch:FindFirstChild("Head") or hrp
	order=order+1
	local E={plr=plr,char=ch,hrp=hrp,hum=hum,sB=0,sN=0,sH=0,sL=0,hp=1,ph=math.random(),d=(order%12)*0.05,hv=-1}

	-- box (the billboard is 4 x 6 studs, so it scales with distance)
	E.bb=new("BillboardGui",{Name="NeonFlyBB",Adornee=hrp,AlwaysOnTop=true,Size=UDim2.new(4,0,6,0),LightInfluence=0,ResetOnSpawn=false,Enabled=false},playerGui)
	E.box=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromScale(1,1),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0},E.bb)
	E.us=new("UIScale",{Scale=1.5},E.box)
	new("UIGradient",{Rotation=90,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.92),NumberSequenceKeypoint.new(1,0.65)})},E.box)
	E.bs=stroke(E.box,C.White,1.4,1)
	E.bsg=new("UIGradient",{},E.bs)
	E.cor={}
	for _,c in ipairs({{0,0},{1,0},{0,1},{1,1}}) do
		local ax,ay=c[1],c[2]
		E.cor[#E.cor+1]=new("Frame",{AnchorPoint=Vector2.new(ax,ay),Position=UDim2.fromScale(ax,ay),Size=UDim2.new(0.3,0,0,3),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0},E.box)
		E.cor[#E.cor+1]=new("Frame",{AnchorPoint=Vector2.new(ax,ay),Position=UDim2.fromScale(ax,ay),Size=UDim2.new(0,3,0.2,0),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0},E.box)
	end

	-- name + health bar (fixed pixel size, floats above the head)
	E.tb=new("BillboardGui",{Name="NeonFlyBB",Adornee=head,AlwaysOnTop=true,Size=UDim2.fromOffset(150,34),StudsOffsetWorldSpace=Vector3.new(0,2.5,0),LightInfluence=0,ResetOnSpawn=false,Enabled=false},playerGui)
	E.nm=label({AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0,0),Size=UDim2.fromOffset(150,16),Text=plr.DisplayName,TextSize=13,Font=Enum.Font.GothamBold,TextTransparency=1},E.tb)
	E.nms=tstroke(E.nm,C.Ink,1.6)
	E.hb=new("Frame",{AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0,21),Size=UDim2.fromOffset(74,6),BackgroundColor3=C.Ink,BackgroundTransparency=1,BorderSizePixel=0,ClipsDescendants=true},E.tb)
	corner(E.hb,3)
	E.hf=new("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(110,255,170),BackgroundTransparency=1,BorderSizePixel=0},E.hb)
	corner(E.hf,3)
	E.shine=new("Frame",{Size=UDim2.fromScale(0.3,1),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0},E.hb)
	new("UIGradient",{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(0.5,0.3),NumberSequenceKeypoint.new(1,1)})},E.shine)
	E.hbs=stroke(E.hb,C.White,1,1)

	-- tracer: a glowing line from the bottom of the screen with a pulse running along it
	E.tr=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Size=UDim2.fromOffset(0,2),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0,Visible=false},hold)
	E.trg=new("UIGradient",{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.9),NumberSequenceKeypoint.new(1,0)})},E.tr)
	E.pl=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Size=UDim2.fromOffset(7,7),Position=UDim2.new(0,0,0.5,0),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0},E.tr)
	corner(E.pl,999)
	E.ed=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Size=UDim2.fromOffset(9,9),Position=UDim2.new(1,0,0.5,0),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0},E.tr)
	corner(E.ed,999)
	return E
end

local function upd(E,t,dt,c1,c2,cam,vp)
	local alive=E.hum.Health>0
	local en=(vz.on and alive and t>=vz.tOn+E.d) and 1 or 0
	local k=math.min(1,dt*6)
	E.sB=E.sB+(en*(vz.box and 1 or 0)-E.sB)*k
	E.sN=E.sN+(en*(vz.name and 1 or 0)-E.sN)*k
	E.sH=E.sH+(en*(vz.hp and 1 or 0)-E.sH)*k
	E.sL=E.sL+(en*(vz.lines and 1 or 0)-E.sL)*k

	if E.hv~=vz.hue then
		E.hv=vz.hue
		E.bsg.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,c1),ColorSequenceKeypoint.new(0.5,c2),ColorSequenceKeypoint.new(1,c1)})
		E.box.BackgroundColor3=c1
		for _,f in ipairs(E.cor) do f.BackgroundColor3=c1 end
		E.nm.TextColor3=c1:Lerp(C.White,0.45)
		E.trg.Color=ColorSequence.new(c2,c1)
		E.ed.BackgroundColor3=c1
	end

	-- box: corners snap in from a bigger box, border gradient keeps rotating
	local eB=E.sB
	E.bb.Enabled=eB>0.02
	if eB>0.02 then
		local inv=1-eB
		E.us.Scale=1+0.6*inv*inv
		E.box.BackgroundTransparency=1-eB
		E.bs.Transparency=1-eB
		E.bsg.Rotation=(t*90+E.ph*360)%360
		local br=0.3+0.025*math.sin(t*3+E.ph*6)
		for i,f in ipairs(E.cor) do
			f.BackgroundTransparency=1-eB
			if i%2==1 then
				f.Size=UDim2.new(br,0,0,3)
			else
				f.Size=UDim2.new(0,3,br*0.66,0)
			end
		end
	end

	-- name + health bar
	local eN,eH=E.sN,E.sH
	local tagOn=(eN>0.02 or eH>0.02)
	E.tb.Enabled=tagOn
	if tagOn then
		E.nm.TextTransparency=1-eN
		E.nms.Transparency=1-0.65*eN
		E.nm.Position=UDim2.new(0.5,0,0,6*(1-eN))
		local ratio=math.clamp(E.hum.Health/math.max(E.hum.MaxHealth,1),0,1)
		E.hp=E.hp+(ratio-E.hp)*math.min(1,dt*8)
		E.hf.Size=UDim2.new(E.hp,0,1,0)
		E.hf.BackgroundColor3=hpColor(E.hp)
		E.hb.BackgroundTransparency=1-0.6*eH
		E.hf.BackgroundTransparency=1-eH
		E.hbs.Transparency=1-0.5*eH
		E.shine.BackgroundTransparency=1-0.6*eH
		E.shine.Position=UDim2.new((t*0.9+E.ph)%1.6-0.3,0,0,0)
	end

	-- tracer (draws itself in from the bottom of the screen)
	local eL=E.sL
	if eL>0.02 then
		local v=cam:WorldToViewportPoint(E.hrp.Position)
		local px,py=v.X,v.Y
		if v.Z<0 then
			px=vp.X-px
			py=vp.Y-py
		end
		local ox,oy=vp.X/2,vp.Y
		local dx,dy=px-ox,py-oy
		local len=math.sqrt(dx*dx+dy*dy)
		if len>4 then
			local l2=len*eL
			E.tr.Visible=true
			E.tr.Position=UDim2.fromOffset(ox+dx/len*l2/2,oy+dy/len*l2/2)
			E.tr.Size=UDim2.fromOffset(l2,2)
			E.tr.Rotation=math.deg(math.atan2(dy,dx))
			E.tr.BackgroundTransparency=1-eL*0.9
			E.pl.Position=UDim2.new((t*0.7+E.ph)%1,0,0.5,0)
			E.pl.BackgroundTransparency=1-eL
			E.ed.BackgroundTransparency=1-eL
		else
			E.tr.Visible=false
		end
	else
		E.tr.Visible=false
	end
end

-- screen-wide scan wave when ESP is switched on / off
function S.espPulse(on)
	local c1,c2=cols()
	local cam=workspace.CurrentCamera
	local vp=cam and cam.ViewportSize or screenSize()
	local m=math.max(vp.X,vp.Y)*1.6
	local mid=UDim2.fromScale(0.5,0.5)
	if on then
		shockwave(hold,mid,40,m,3,1.0,0,{a1=c1},0.1)
		shockwave(hold,mid,40,m,2,1.2,0.12,{a1=c2},0.3)
		shockwave(hold,mid,40,m,1.5,1.4,0.26,{a1=c1},0.5)
	else
		shockwave(hold,mid,m*0.6,40,2.5,0.7,0,{a1=c1},0.2)
	end
end

function S.setEsp(on)
	if vz.on==on then return end
	vz.on=on
	if on then vz.tOn=os.clock() end
	S.espPulse(on)
	sfx("switch",0.6,on and 1.25 or 0.8)
	sfx("whoosh",0.3,on and 1.8 or 0.8)
	if S.espUI then S.espUI(on) end
	if S.onEspState then S.onEspState(on) end
end
function S.setHue(h)
	h=math.floor(((h%360)+360)%360+0.5)%360
	if h==vz.hue then return end
	vz.hue=h
	savePref("vzhue",h)
	if S.hueUI then S.hueUI(h) end
end

local acc=0
connect(RunService.RenderStepped,function(dt)
	local t=os.clock()
	acc=acc+dt
	if acc>0.35 then
		acc=0
		for plr,E in pairs(ents) do
			if not plr.Parent or plr.Character~=E.char or not E.hrp.Parent then
				kill(E)
				ents[plr]=nil
			end
		end
		if vz.on then
			for _,plr in ipairs(Players:GetPlayers()) do
				if plr~=player and not ents[plr] and plr.Character then
					local E=make(plr,plr.Character)
					if E then ents[plr]=E end
				end
			end
		end
	end
	if next(ents)==nil then return end
	local cam=workspace.CurrentCamera
	if not cam then return end
	local vp=cam.ViewportSize
	local c1,c2=cols()
	for plr,E in pairs(ents) do
		upd(E,t,dt,c1,c2,cam,vp)
		if not vz.on and E.sB<0.01 and E.sN<0.01 and E.sH<0.01 and E.sL<0.01 then
			kill(E)
			ents[plr]=nil
		end
	end
end)

gui.Destroying:Connect(function()
	for _,E in pairs(ents) do kill(E) end
	ents={}
end)
end -- [E:vz:esp]

------------------------------------------------ the tab itself
do -- [vz:ui]
local page=new("ScrollingFrame",{
	Position=UDim2.fromScale(3,0),Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0,
	ScrollBarThickness=3,ScrollBarImageColor3=C.White,ScrollBarImageTransparency=0.6,
	CanvasSize=UDim2.new(0,0,0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollingDirection=Enum.ScrollingDirection.Y},pagesHolder)
pages[5]=page
new("UIListLayout",{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder,HorizontalAlignment=Enum.HorizontalAlignment.Center},page)
new("UIPadding",{PaddingTop=UDim.new(0,10),PaddingBottom=UDim.new(0,12)},page)

-- these are filled in below and animated by the loop at the end of this block
local R={}

-- 1) ESP master card: eye icon that opens, title, switch, scanning bar -------------------
do
local mc=card(page,86,nil,1)
mc.ClipsDescendants=true
R.mcStroke=mc:FindFirstChildOfClass("UIStroke")
R.eye=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromOffset(40,36),Size=UDim2.fromOffset(40,5),BackgroundTransparency=1,BorderSizePixel=0},mc)
corner(R.eye,20)
R.eyeS=stroke(R.eye,C.White,2,0)
R.pupil=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(0,0),BackgroundColor3=C.White,BorderSizePixel=0},R.eye)
corner(R.pupil,999)
R.glint=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,3,0.5,-3),Size=UDim2.fromOffset(0,0),BackgroundColor3=C.Ink,BorderSizePixel=0,ZIndex=2},R.eye)
corner(R.glint,999)
R.title=label({Position=UDim2.fromOffset(74,14),Size=UDim2.fromOffset(150,24),Text="ESP",TextSize=20,Font=Enum.Font.GothamBlack,TextColor3=C.White,TextXAlignment=Enum.TextXAlignment.Left},mc)
bindText(label({Position=UDim2.fromOffset(74,40),Size=UDim2.fromOffset(170,14),Text="",TextSize=10,Font=Enum.Font.Gotham,TextColor3=C.Muted,TextXAlignment=Enum.TextXAlignment.Left},mc),"vz_sub")
R.mSw=makeSwitch(mc,UDim2.new(1,-14,0,36),vz.on)
local mb=new("TextButton",{Size=UDim2.new(1,0,0,72),BackgroundTransparency=1,Text="",AutoButtonColor=false,ClipsDescendants=true},mc)
mb.InputBegan:Connect(function(i) if isPress(i) then ripple(mb,i) end end)
mb.Activated:Connect(function() S.setEsp(not vz.on) end)
-- scanning bar sweeping along the bottom edge while ESP is on
R.scan=new("Frame",{Position=UDim2.new(-0.4,0,1,-3),Size=UDim2.new(0.4,0,0,3),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0},mc)
R.scanG=new("UIGradient",{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(0.5,0),NumberSequenceKeypoint.new(1,1)})},R.scan)
end

-- 2) feature toggles ---------------------------------------------------------------------
do
local fc=card(page,184,nil,2)
local tt=bindText(label({Position=UDim2.fromOffset(14,8),Size=UDim2.new(1,-28,0,18),Text="",TextSize=14,Font=Enum.Font.GothamBlack,TextColor3=C.White,TextXAlignment=Enum.TextXAlignment.Left},fc),"vz_feat")
tgrad(tt,0)
local function row(y,key,field,pk)
	local sw
	sw=S.mkRow(fc,y,key,vz[field],function()
		vz[field]=not vz[field]
		sw.set(vz[field])
		savePref(pk,vz[field])
		sfx("switch",0.6,vz[field] and 1.25 or 0.8)
	end)
end
row(48,"vz_lines","lines","vzlines")
row(86,"vz_box","box","vzbox")
row(124,"vz_hp","hp","vzhp")
row(162,"vz_name","name","vzname")
end

-- 3) color: hue slider (same value as the third quick dial) + animated preview -----------
do
local cc=card(page,104,nil,3)
R.cTitle=bindText(label({Position=UDim2.fromOffset(16,10),Size=UDim2.fromOffset(150,16),Text="",TextSize=12,TextColor3=C.Muted,TextXAlignment=Enum.TextXAlignment.Left},cc),"vz_color")
R.cVal=label({AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-16,0,7),Size=UDim2.fromOffset(80,22),Text="",TextSize=18,Font=Enum.Font.GothamBlack,TextColor3=C.White,TextXAlignment=Enum.TextXAlignment.Right},cc)
R.hueSl=makeSlider({parent=cc,x=16,y=48,width=W-24-32,min=0,max=359,value=vz.hue,rainbow=true,scroller=page,onChange=function(v)
	S.setHue(v)
end})
-- preview bar with a flowing gradient and a bright streak
R.prev=new("Frame",{Position=UDim2.fromOffset(16,72),Size=UDim2.fromOffset(W-24-32,18),BackgroundColor3=C.White,BorderSizePixel=0,ClipsDescendants=true},cc)
corner(R.prev,9)
R.prevG=new("UIGradient",{},R.prev)
R.streak=new("Frame",{Position=UDim2.new(-0.3,0,0,0),Size=UDim2.new(0.3,0,1,0),BackgroundColor3=C.White,BackgroundTransparency=0.45,BorderSizePixel=0},R.prev)
new("UIGradient",{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(0.5,0),NumberSequenceKeypoint.new(1,1)})},R.streak)
end

-- hooks used by S.setEsp / S.setHue (also called from the quick dial)
local open=vz.on and 1 or 0
function S.espUI(on)
	R.mSw.set(on)
end
function S.hueUI(h)
	R.hueSl.set(h,true)
end

connect(RunService.RenderStepped,function(dt)
	if not (activeTab==5 and uiVisible and not minimized) then return end
	local t=os.clock()
	local h=vz.hue
	local c1=Color3.fromHSV(h/360,0.85,1)
	local c2=Color3.fromHSV(((h+55)%360)/360,0.8,1)
	open=open+((vz.on and 1 or 0.12)-open)*math.min(1,dt*6)
	-- eye: lid opens, pupil grows and breathes, slow blink every few seconds
	local blink=(t%4.5<0.16) and 0.15 or 1
	local eh=5+19*open*blink
	R.eye.Size=UDim2.fromOffset(40,eh)
	R.eyeS.Color=c1
	local ps=math.max(0,(9+3*math.sin(t*3)*(vz.on and 1 or 0))*open*blink)
	R.pupil.Size=UDim2.fromOffset(ps,ps)
	R.pupil.BackgroundColor3=c1
	local gs=ps*0.35
	R.glint.Size=UDim2.fromOffset(gs,gs)
	R.title.TextColor3=vz.on and c1 or C.Muted
	if R.mcStroke then R.mcStroke.Color=vz.on and c1 or C.White end
	-- scanning bar
	if vz.on then
		R.scan.BackgroundColor3=c1
		R.scan.BackgroundTransparency=0
		R.scan.Position=UDim2.new(((t*0.9)%1.5)-0.4,0,1,-3)
	else
		R.scan.BackgroundTransparency=1
	end
	-- value + preview
	R.cVal.Text=h.."°"
	R.cVal.TextColor3=c1
	R.prevG.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,c1),ColorSequenceKeypoint.new(0.5,c2),ColorSequenceKeypoint.new(1,c1)})
	R.prevG.Offset=Vector2.new(math.sin(t*1.4)*0.35,0)
	R.streak.Position=UDim2.new(((t*0.7)%1.6)-0.3,0,0,0)
end)
end -- [E:vz:ui]
end -- [E:S:visual]


-------------------------------------------------- PLAYER TAB  (walk speed / jump power / gravity)
-- (block-scoped: registers pages[3] and the S.setPl / S.setPlOn hooks the quick dial uses)
do -- [S:player]
local pl=S.pl
local KEYS={"speed","jump","grav"}
local TKEY={"pl_speed","pl_jump","pl_grav"}
local COL={Color3.fromRGB(90,200,255),Color3.fromRGB(120,255,150),Color3.fromRGB(190,130,255)}
local DEF={speed="defS",jump="defJ",grav="defG"}

------------------------------------------------ engine: applies the values every frame
do -- [pl:engine]
-- "def*" always follows what the game itself sets, so switching the mods off (or pressing reset)
-- hands control back to the game with its own values.
local last={}
local jumpMod=false
local origUse=nil
connect(RunService.Heartbeat,function()
	local ch=player.Character
	local hum=ch and ch:FindFirstChildOfClass("Humanoid")
	if hum then
		-- walk speed
		if hum.WalkSpeed~=last.speed then pl.defS=hum.WalkSpeed end
		local tgt=(pl.on and pl.speed~=pl.defS) and pl.speed or pl.defS
		if hum.WalkSpeed~=tgt then hum.WalkSpeed=tgt end
		last.speed=tgt
		-- jump power (switches the humanoid to JumpPower mode while a custom value is active)
		if pl.on and pl.jump~=pl.defJ then
			if not jumpMod then
				jumpMod=true
				origUse=hum.UseJumpPower
			end
			if not hum.UseJumpPower then hum.UseJumpPower=true end
			if hum.JumpPower~=pl.jump then hum.JumpPower=pl.jump end
		elseif jumpMod then
			jumpMod=false
			if origUse==false then hum.UseJumpPower=false end
			hum.JumpPower=pl.defJ
		else
			pl.defJ=hum.JumpPower
		end
	end
	-- gravity
	local g=workspace.Gravity
	if g~=last.grav then pl.defG=g end
	local tg=(pl.on and pl.grav~=pl.defG) and pl.grav or pl.defG
	if g~=tg then workspace.Gravity=tg end
	last.grav=tg
end)

gui.Destroying:Connect(function()
	local ch=player.Character
	local hum=ch and ch:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed=pl.defS
		if jumpMod then
			if origUse==false then hum.UseJumpPower=false end
			hum.JumpPower=pl.defJ
		end
	end
	workspace.Gravity=pl.defG
end)
end -- [E:pl:engine]

------------------------------------------------ setters (used by the tab and by the quick dial)
function S.setPl(key,v)
	v=math.clamp(math.floor(v+0.5),pl.lo[key],pl.hi[key])
	if v==pl[key] then return end
	pl[key]=v
	savePref("pl"..key,v)
	if not pl.on then S.setPlOn(true,true) end
	if S.plUI then S.plUI(key,v) end
end
function S.plReset(key)
	pl[key]=pl[DEF[key]]
	savePref("pl"..key,pl[key])
	if S.plUI then S.plUI(key,pl[key]) end
end
function S.setPlOn(on,quiet)
	if pl.on==on then return end
	pl.on=on
	savePref("plon",on)
	if S.plOnUI then S.plOnUI(on) end
	if not quiet then
		sfx("switch",0.6,on and 1.25 or 0.8)
		if S.onPlState then S.onPlState(on) end
	end
end

------------------------------------------------ the tab itself
do -- [pl:ui]
local page=new("ScrollingFrame",{
	Position=UDim2.fromScale(2,0),Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0,
	ScrollBarThickness=3,ScrollBarImageColor3=C.White,ScrollBarImageTransparency=0.6,
	CanvasSize=UDim2.new(0,0,0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollingDirection=Enum.ScrollingDirection.Y},pagesHolder)
pages[3]=page
new("UIListLayout",{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder,HorizontalAlignment=Enum.HorizontalAlignment.Center},page)
new("UIPadding",{PaddingTop=UDim.new(0,10),PaddingBottom=UDim.new(0,12)},page)

local U={}
local function fmt(key,v)
	if key=="grav" then return tostring(math.floor(v+0.5)) end
	return tostring(math.floor(v+0.5))
end

-- master card: three little level bars + switch -------------------------------------------
do
local mc=card(page,68,nil,1)
local ttl=bindText(label({Position=UDim2.fromOffset(74,12),Size=UDim2.fromOffset(170,20),Text="",TextSize=16,Font=Enum.Font.GothamBlack,TextColor3=C.White,TextXAlignment=Enum.TextXAlignment.Left},mc),"pl_mods")
tgrad(ttl,0)
bindText(label({Position=UDim2.fromOffset(74,36),Size=UDim2.fromOffset(170,14),Text="",TextSize=10,Font=Enum.Font.Gotham,TextColor3=C.Muted,TextXAlignment=Enum.TextXAlignment.Left},mc),"pl_sub")
U.bars={}
for i=1,3 do
	local x=18+(i-1)*17
	local track=new("Frame",{Position=UDim2.fromOffset(x,16),Size=UDim2.fromOffset(10,38),BackgroundColor3=C.White,BackgroundTransparency=0.9,BorderSizePixel=0},mc)
	corner(track,4)
	local fill=new("Frame",{AnchorPoint=Vector2.new(0,1),Position=UDim2.fromScale(0,1),Size=UDim2.fromScale(1,0.5),BackgroundColor3=COL[i],BorderSizePixel=0},track)
	corner(fill,4)
	U.bars[i]=fill
end
local sw=makeSwitch(mc,UDim2.new(1,-14,0,34),pl.on)
local btn=new("TextButton",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Text="",AutoButtonColor=false,ClipsDescendants=true},mc)
btn.InputBegan:Connect(function(i) if isPress(i) then ripple(btn,i) end end)
btn.Activated:Connect(function() S.setPlOn(not pl.on) end)
function S.plOnUI(on) sw.set(on) end
end

-- one card per value --------------------------------------------------------------------
local function statCard(idx)
	local key=KEYS[idx]
	local c=card(page,98,nil,idx+1)
	bindText(label({Position=UDim2.fromOffset(16,10),Size=UDim2.fromOffset(150,16),Text="",TextSize=12,TextColor3=C.Muted,TextXAlignment=Enum.TextXAlignment.Left},c),TKEY[idx])
	local val=label({AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-16,0,7),Size=UDim2.fromOffset(120,22),Text=fmt(key,pl[key]),TextSize=18,Font=Enum.Font.GothamBlack,TextColor3=COL[idx],TextXAlignment=Enum.TextXAlignment.Right},c)
	local sl=makeSlider({parent=c,x=16,y=48,width=W-24-32,min=pl.lo[key],max=pl.hi[key],value=pl[key],scroller=page,onChange=function(v,a)
		S.setPl(key,v)
		tickSfx(a)
	end})
	local rb=new("TextButton",{Position=UDim2.fromOffset(16,68),Size=UDim2.fromOffset(130,22),BackgroundColor3=C.White,BackgroundTransparency=0.93,Text="",AutoButtonColor=false,BorderSizePixel=0,ClipsDescendants=true},c)
	corner(rb,11)
	local rl=label({Size=UDim2.fromScale(1,1),Text="",TextSize=10,TextColor3=C.Text},rb)
	rb.InputBegan:Connect(function(i) if isPress(i) then ripple(rb,i) end end)
	rb.Activated:Connect(function()
		sfx("click",0.4,1.1)
		S.plReset(key)
	end)
	U[key]={val=val,sl=sl,rl=rl}
end
for idx=1,3 do statCard(idx) end

function S.plUI(key,v)
	local u=U[key]
	if not u then return end
	u.val.Text=fmt(key,v)
	u.sl.set(v,true)
end

local acc=1
connect(RunService.RenderStepped,function(dt)
	if not (activeTab==3 and uiVisible and not minimized) then return end
	local t=os.clock()
	for i=1,3 do
		local key=KEYS[i]
		local f=math.clamp((pl[key]-pl.lo[key])/(pl.hi[key]-pl.lo[key]),0,1)
		local wave=pl.on and 0.04*math.sin(t*4+i*1.4) or 0
		U.bars[i].Size=UDim2.fromScale(1,math.clamp(f*0.9+0.1+wave,0.08,1))
		U.bars[i].BackgroundTransparency=pl.on and 0 or 0.65
	end
	acc=acc+dt
	if acc>0.4 then
		acc=0
		for i=1,3 do
			local key=KEYS[i]
			U[key].rl.Text=tr("pl_reset").."  ("..fmt(key,pl[DEF[key]])..")"
		end
	end
end)
end -- [E:pl:ui]
end -- [E:S:player]


-------------------------------------------------- ATMOSPHERE TAB  (Fullbright / No Fog)
-- (block-scoped: registers pages[6])
do -- [S:atmo]
local at=S.at
local L=Lighting

------------------------------------------------ engine
-- drive() owns a property while a switch is on and gives the game's own value back when it is turned off
do -- [at:engine]
local last,orig={},{}
local function drive(key,inst,prop,want)
	local cur=inst[prop]
	if want~=nil then
		if last[key]==nil or cur~=last[key] then orig[key]=cur end   -- the game changed it: remember its new value
		if cur~=want then inst[prop]=want end
		last[key]=want
	elseif last[key]~=nil then
		if cur==last[key] then inst[prop]=orig[key] end
		last[key]=nil
	end
end
local function on(flag,v)
	if flag then return v end
	return nil
end
local function pass()
	local fb,nf=at.fb,at.nf
	drive("br",L,"Brightness",on(fb,at.str))
	drive("ct",L,"ClockTime",on(fb,14))
	drive("gs",L,"GlobalShadows",on(fb,false))
	drive("am",L,"Ambient",on(fb,Color3.fromRGB(170,170,170)))
	drive("oa",L,"OutdoorAmbient",on(fb,Color3.fromRGB(190,190,190)))
	drive("fe",L,"FogEnd",on(nf,1e9))
	drive("fs",L,"FogStart",on(nf,1e9))
	local atm=L:FindFirstChildOfClass("Atmosphere")
	if atm then
		drive("ad",atm,"Density",on(nf,0))
		drive("ah",atm,"Haze",on(nf,0))
	end
end
connect(RunService.Heartbeat,function() pcall(pass) end)
gui.Destroying:Connect(function()
	at.fb=false
	at.nf=false
	pcall(pass)
end)
end -- [E:at:engine]

-- soft full-screen flash when a switch is turned on
local flash=new("Frame",{Name="AtmoFlash",Size=UDim2.fromScale(1,1),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=2,Active=false},gui)
local function pulse(col,a)
	flash.BackgroundColor3=col
	flash.BackgroundTransparency=a
	tween(flash,0.7,{BackgroundTransparency=1},Enum.EasingStyle.Quint)
end

function S.setFb(on)
	if at.fb==on then return end
	at.fb=on
	savePref("atfb",on)
	sfx("switch",0.6,on and 1.25 or 0.8)
	if on then
		sfx("whoosh",0.25,1.9)
		pulse(Color3.fromRGB(255,244,200),0.55)
	end
	if S.fbUI then S.fbUI(on) end
end
function S.setNf(on)
	if at.nf==on then return end
	at.nf=on
	savePref("atnf",on)
	sfx("switch",0.6,on and 1.25 or 0.8)
	if on then
		sfx("whoosh",0.25,1.6)
		pulse(Color3.fromRGB(200,230,255),0.6)
	end
	if S.nfUI then S.nfUI(on) end
end

------------------------------------------------ the tab
do -- [at:ui]
local page=new("ScrollingFrame",{
	Position=UDim2.fromScale(5,0),Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0,
	ScrollBarThickness=3,ScrollBarImageColor3=C.White,ScrollBarImageTransparency=0.6,
	CanvasSize=UDim2.new(0,0,0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollingDirection=Enum.ScrollingDirection.Y},pagesHolder)
pages[6]=page
new("UIListLayout",{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder,HorizontalAlignment=Enum.HorizontalAlignment.Center},page)
new("UIPadding",{PaddingTop=UDim.new(0,10),PaddingBottom=UDim.new(0,12)},page)

local GRAYC=Color3.fromRGB(110,118,146)
local A={fb=at.fb and 1 or 0,nf=at.nf and 1 or 0}
local I={}     -- icon parts

-- a card with an icon holder (56 x 56) on the left, title, subtitle and a switch
local function header(order,h,tkey,skey,get,set,hookName)
	local c=card(page,h,nil,order)
	local ico=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromOffset(44,38),Size=UDim2.fromOffset(56,56),BackgroundTransparency=1,BorderSizePixel=0},c)
	local t=bindText(label({Position=UDim2.fromOffset(84,18),Size=UDim2.fromOffset(150,20),Text="",TextSize=16,Font=Enum.Font.GothamBlack,TextColor3=C.White,TextXAlignment=Enum.TextXAlignment.Left},c),tkey)
	tgrad(t,0)
	bindText(label({Position=UDim2.fromOffset(84,40),Size=UDim2.fromOffset(150,14),Text="",TextSize=10,Font=Enum.Font.Gotham,TextColor3=C.Muted,TextXAlignment=Enum.TextXAlignment.Left},c),skey)
	local sw=makeSwitch(c,UDim2.new(1,-14,0,38),get())
	local btn=new("TextButton",{Size=UDim2.new(1,0,0,76),BackgroundTransparency=1,Text="",AutoButtonColor=false,ClipsDescendants=true},c)
	btn.InputBegan:Connect(function(i) if isPress(i) then ripple(btn,i) end end)
	btn.Activated:Connect(function() set(not get()) end)
	S[hookName]=function(on) sw.set(on) end
	return c,ico
end

-- 1) Fullbright: animated sun ---------------------------------------------------------------
do
local c,ico=header(1,132,"at_fb","at_fbsub",function() return at.fb end,S.setFb,"fbUI")
I.sunGlow=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(56,56),BackgroundColor3=Color3.fromRGB(255,214,90),BackgroundTransparency=1,BorderSizePixel=0},ico)
corner(I.sunGlow,999)
I.rays=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(4,4),BackgroundTransparency=1,BorderSizePixel=0},ico)
I.rayB={}
for k=0,9 do
	local pv=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(4,4),Rotation=k*36,BackgroundTransparency=1,BorderSizePixel=0},I.rays)
	I.rayB[k+1]=new("Frame",{AnchorPoint=Vector2.new(0.5,1),Position=UDim2.new(0.5,0,0.5,-17),Size=UDim2.fromOffset(3,6),BackgroundColor3=C.White,BorderSizePixel=0},pv)
	corner(I.rayB[k+1],2)
end
I.core=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(24,24),BackgroundColor3=C.White,BorderSizePixel=0},ico)
corner(I.core,999)
-- brightness slider
bindText(label({Position=UDim2.fromOffset(16,80),Size=UDim2.fromOffset(150,16),Text="",TextSize=12,TextColor3=C.Muted,TextXAlignment=Enum.TextXAlignment.Left},c),"at_str")
local vl=label({AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-16,0,77),Size=UDim2.fromOffset(60,20),Text=tostring(at.str),TextSize=15,Font=Enum.Font.GothamBlack,TextColor3=C.White,TextXAlignment=Enum.TextXAlignment.Right},c)
tgrad(vl,0)
makeSlider({parent=c,x=16,y=108,width=W-24-32,min=1,max=8,value=at.str,scroller=page,onChange=function(v,a)
	at.str=v
	vl.Text=tostring(v)
	savePref("atstr",v)
	tickSfx(a)
end})
end

-- 2) No Fog: drifting fog banks that clear away ---------------------------------------------
do
local c,ico=header(2,78,"at_nf","at_nfsub",function() return at.nf end,S.setNf,"nfUI")
I.fog={}
for k,d in ipairs({{40,10,-9},{30,10,0},{36,10,9}}) do
	local f=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,d[3]),Size=UDim2.fromOffset(d[1],d[2]),BackgroundColor3=GRAYC,BorderSizePixel=0},ico)
	corner(f,5)
	I.fog[k]={f=f,y=d[3]}
end
I.sparks={}
for k=1,3 do
	local s=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,(k-2)*14,0.5,(k%2==0) and -6 or 5),Size=UDim2.fromOffset(4,4),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0},ico)
	corner(s,999)
	tgrad(s,45)
	I.sparks[k]=s
end
end

connect(RunService.RenderStepped,function(dt)
	if not (activeTab==6 and uiVisible and not minimized) then return end
	local t=os.clock()
	local k=math.min(1,dt*6)
	A.fb=A.fb+((at.fb and 1 or 0)-A.fb)*k
	A.nf=A.nf+((at.nf and 1 or 0)-A.nf)*k
	-- sun: rays spin faster and grow, the core warms up, the glow breathes
	local fb=A.fb
	local warm=Color3.fromRGB(255,214,90):Lerp(Color3.fromRGB(255,150,60),0.5+0.5*math.sin(t*2))
	local col=GRAYC:Lerp(warm,fb)
	I.rays.Rotation=(t*(18+110*fb))%360
	for i,r in ipairs(I.rayB) do
		local len=5+8*fb*(0.6+0.4*math.sin(t*4+i))
		r.Size=UDim2.fromOffset(3,len)
		r.BackgroundColor3=col
	end
	I.core.BackgroundColor3=col
	local cs=22+3*fb*math.sin(t*3)
	I.core.Size=UDim2.fromOffset(cs,cs)
	local gs=40+16*fb+4*fb*math.sin(t*3)
	I.sunGlow.Size=UDim2.fromOffset(gs,gs)
	I.sunGlow.BackgroundTransparency=1-0.28*fb
	-- fog: banks drift; when "No Fog" is on they fade away and sparkles appear
	local nf=A.nf
	for i,b in ipairs(I.fog) do
		b.f.Position=UDim2.new(0.5,math.sin(t*0.9+i*1.7)*6*(1-nf),0.5,b.y)
		b.f.BackgroundTransparency=0.15+0.85*nf
	end
	for i,s in ipairs(I.sparks) do
		local sz=(3+2*math.sin(t*5+i*2))*nf
		s.Size=UDim2.fromOffset(sz,sz)
		s.BackgroundTransparency=1-nf*(0.6+0.4*math.sin(t*4+i))
	end
end)
end -- [E:at:ui]
end -- [E:S:atmo]


-------------------------------------------------- MISC TAB  (shift lock, crosshair, anti AFK, auto execute, servers)
-- (block-scoped: registers pages[6])
do -- [S:misc]
local ms=S.ms
local xh=S.xh
local M={}

------------------------------------------------ utilities: anti AFK, auto execute, rejoin, server finder
do -- [ms:util]
local HttpService=game:GetService("HttpService")
local TeleportService=game:GetService("TeleportService")

-- Anti AFK: answers Roblox's idle check, plus a gentle nudge every minute
local VU=nil
pcall(function() VU=game:GetService("VirtualUser") end)
local function nudge()
	if not VU or not ms.afk then return end
	pcall(function()
		VU:CaptureController()
		VU:ClickButton2(Vector2.new(0,0))
	end)
end
connect(player.Idled,nudge)
task.spawn(function()
	while alive do
		task.wait(55)
		if ms.afk then nudge() end
	end
end)

-- Auto Execute: queue the script again for the next teleport / rejoin / server hop.
-- It needs the loader line once (paste it in the Misc tab) or getgenv().XyclopSource.
local function aexSource()
	local s=ms.asrc
	if type(s)=="string" and #s>0 then
		if s:match("^https?://") then
			return 'loadstring(game:HttpGet("'..s..'"))()'
		end
		return s
	end
	if getgenv then
		local g=getgenv()
		if g and g.XyclopSource then return tostring(g.XyclopSource) end
	end
	return nil
end
function S.aexSource() return aexSource() end
function S.aexQueue()
	local src=aexSource()
	if not src then return false end
	-- executors that have an autoexec folder inside the workspace run it on every fresh join
	pcall(function()
		if writefile and isfolder and isfolder("autoexec") then writefile("autoexec/XyclopUltimate.lua",src) end
	end)
	local q=queue_on_teleport or queueonteleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
	if not q then return false end
	return (pcall(q,src))
end
function S.aexClear()
	pcall(function()
		if delfile and isfile and isfile("autoexec/XyclopUltimate.lua") then delfile("autoexec/XyclopUltimate.lua") end
	end)
end
connect(player.OnTeleport,function()
	if ms.aex then S.aexQueue() end
end)
if ms.aex then task.defer(S.aexQueue) end

-- HTTP through whatever the executor offers
local function httpGet(url)
	local ok,res=pcall(function()
		local req=(syn and syn.request) or http_request or request or (fluxus and fluxus.request)
		if req then
			local r=req({Url=url,Method="GET"})
			return r and r.Body
		end
		return game:HttpGet(url)
	end)
	if ok and type(res)=="string" and #res>0 then return res end
	return nil
end
function S.fetchServers(order,limit)
	local url="https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder="..order.."&excludeFullGames=true&limit="..limit
	local body=httpGet(url)
	if not body then return nil end
	local ok,data=pcall(function() return HttpService:JSONDecode(body) end)
	if ok and type(data)=="table" and type(data.data)=="table" then return data.data end
	return nil
end
function S.tpServer(id)
	pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId,id,player) end)
end
function S.rejoin()
	pcall(function()
		if #Players:GetPlayers()<=1 then
			player:Kick("\nRejoining...")
			task.wait()
			TeleportService:Teleport(game.PlaceId,player)
		else
			TeleportService:TeleportToPlaceInstance(game.PlaceId,game.JobId,player)
		end
	end)
end
-- returns true, or false + reason ("http" / "none")
local function pickServer(order,fewest)
	local list=S.fetchServers(order,100)
	if not list then return false,"http" end
	local pool={}
	for _,s in ipairs(list) do
		if s.id~=game.JobId and s.playing and s.maxPlayers and s.playing<s.maxPlayers then pool[#pool+1]=s end
	end
	if #pool==0 then return false,"none" end
	local s
	if fewest then
		table.sort(pool,function(a,b) return a.playing<b.playing end)
		s=pool[math.random(1,math.min(3,#pool))]
	else
		s=pool[math.random(1,#pool)]
	end
	S.tpServer(s.id)
	return true
end
function S.smallestServer() return pickServer("Asc",true) end
function S.hopServer() return pickServer("Desc",false) end
end -- [E:ms:util]

------------------------------------------------ crosshair (factory: used on screen and in the preview card)
do -- [ms:xh]
local STY={
	{arms=4},                           -- 1 Cross
	{ring=true,big=true},               -- 2 Dot
	{arms=4,ring=true,short=true},      -- 3 Ring
	{brk=true},                         -- 4 Bracket
	{chev=true},                        -- 5 Chevron
	{orbit=true,arcs=true},             -- 6 Orbit
	{arms=8,ring=true,faint=true},      -- 7 Star
}
M.names={"Cross","Dot","Ring","Bracket","Chevron","Orbit","Star"}

local function pivot(parent,rot)
	return new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(4,4),Rotation=rot or 0,BackgroundTransparency=1,BorderSizePixel=0},parent)
end
local function bar(parent,pos,size,anchor)
	local f=new("Frame",{AnchorPoint=anchor or Vector2.new(0,0),Position=pos,Size=size,BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0},parent)
	return f,stroke(f,C.Ink,1,1)
end

function M.build(parent,z)
	local o={}
	o.root=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(4,4),BackgroundTransparency=1,BorderSizePixel=0,Visible=false,ZIndex=z},parent)
	o.us=new("UIScale",{Scale=1},o.root)
	o.glow=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(10,10),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0},o.root)
	corner(o.glow,999)
	o.spin=pivot(o.root,0)
	-- eight arms (cross uses 4, star uses 8)
	o.arm={}
	for k=0,7 do
		local pv=pivot(o.spin,k*45)
		local b,s=bar(pv,UDim2.new(0.5,0,0.5,-8),UDim2.fromOffset(2,10),Vector2.new(0.5,1))
		o.arm[k+1]={bar=b,os=s}
	end
	-- four chevrons (two bars each)
	o.chev={}
	for k=0,3 do
		local pv=pivot(o.spin,k*90)
		local list={}
		for _,sgn in ipairs({-1,1}) do
			local tip=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,-10),Size=UDim2.fromOffset(4,4),Rotation=sgn*40,BackgroundTransparency=1,BorderSizePixel=0},pv)
			local b,s=bar(tip,UDim2.fromScale(0.5,0.5),UDim2.fromOffset(2,8),Vector2.new(0.5,1))
			list[#list+1]={tip=tip,bar=b,os=s}
		end
		o.chev[k+1]=list
	end
	-- four corner brackets
	o.brk={}
	for k=0,3 do
		local pv=pivot(o.spin,k*90)
		local h,hs=bar(pv,UDim2.new(0.5,-20,0.5,-20),UDim2.fromOffset(10,2))
		local v,vs=bar(pv,UDim2.new(0.5,-20,0.5,-20),UDim2.fromOffset(2,10))
		o.brk[k+1]={h=h,v=v,hs=hs,vs=vs}
	end
	-- ring, center dot
	o.ring=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(40,40),BackgroundTransparency=1,BorderSizePixel=0},o.root)
	corner(o.ring,999)
	o.ringS=stroke(o.ring,C.White,2,1)
	o.dot=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(4,4),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0},o.root)
	corner(o.dot,999)
	o.dotS=stroke(o.dot,C.Ink,1,1)
	-- orbit: four beads on a rotating circle + two rotating arcs
	o.orb=pivot(o.root,0)
	o.beads={}
	for k=0,3 do
		local pv=pivot(o.orb,k*90)
		local d=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,-20),Size=UDim2.fromOffset(4,4),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0},pv)
		corner(d,999)
		o.beads[k+1]=d
	end
	o.arcs={}
	for k=1,2 do
		local f=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(40,40),BackgroundTransparency=1,BorderSizePixel=0},o.root)
		corner(f,999)
		local s=stroke(f,C.White,2,1)
		local g=new("UIGradient",{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(k==1 and 0.4 or 0.6,1),NumberSequenceKeypoint.new(1,1)})},s)
		o.arcs[k]={f=f,s=s,g=g}
	end

	-- P = settings table, lk = locked-on factor 0..1, fl = flash 0..1, am = overall alpha 0..1
	function o.update(P,t,lk,fl,am)
		local st=STY[P.style] or STY[1]
		local hue=P.rainbow and (t*60)%360 or P.hue
		local c1=Color3.fromHSV(hue/360,0.85,1)
		local c2=Color3.fromHSV(((hue+45)%360)/360,0.8,1)
		local react=P.react and lk or 0
		if react>0.01 and S.cbCols then
			local _,_,rd=S.cbCols()
			c1=c1:Lerp(rd,react)
			c2=c2:Lerp(C.White,react*0.4)
		end
		local alpha=math.clamp(P.op/100*am,0,1)
		local R=P.size/2
		local th=P.thick
		local gap=P.gap*(1-0.4*react)
		local olT=P.outline and (1-0.8*alpha) or 1
		o.us.Scale=1+0.035*math.sin(t*3)+0.06*fl
		o.spin.Rotation=(t*P.spin)%360

		-- soft glow
		if P.glow then
			local gs=P.size*1.6
			o.glow.Size=UDim2.fromOffset(gs,gs)
			o.glow.BackgroundColor3=c1
			o.glow.BackgroundTransparency=1-math.clamp(0.1*alpha+0.12*fl,0,1)
		else
			o.glow.BackgroundTransparency=1
		end

		-- arms
		local an=st.arms or 0
		for k=1,8 do
			local a=o.arm[k]
			local on=(an==8) or (an==4 and k%2==1)
			if on then
				local len=math.max(2,(R-gap)*((an==8 and k%2==0) and 0.55 or 1)*(st.short and 0.35 or 1))
				a.bar.Position=UDim2.new(0.5,0,0.5,-gap)
				a.bar.Size=UDim2.fromOffset(th,len)
				a.bar.BackgroundColor3=(an==8 and k%2==0) and c2 or c1
				a.bar.BackgroundTransparency=1-alpha
				a.os.Transparency=olT
			else
				a.bar.BackgroundTransparency=1
				a.os.Transparency=1
			end
		end
		-- chevrons
		for k=1,4 do
			for _,ar in ipairs(o.chev[k]) do
				if st.chev then
					ar.tip.Position=UDim2.new(0.5,0,0.5,-(gap+R*0.18))
					ar.bar.Size=UDim2.fromOffset(th,math.max(3,R*0.3))
					ar.bar.BackgroundColor3=c1
					ar.bar.BackgroundTransparency=1-alpha
					ar.os.Transparency=olT
				else
					ar.bar.BackgroundTransparency=1
					ar.os.Transparency=1
				end
			end
		end
		-- brackets
		for k=1,4 do
			local b=o.brk[k]
			if st.brk then
				local off=R*0.7+gap*0.2
				local len=R*0.4
				b.h.Position=UDim2.new(0.5,-off,0.5,-off)
				b.v.Position=UDim2.new(0.5,-off,0.5,-off)
				b.h.Size=UDim2.fromOffset(len,th)
				b.v.Size=UDim2.fromOffset(th,len)
				b.h.BackgroundColor3=c1
				b.v.BackgroundColor3=c1
				b.h.BackgroundTransparency=1-alpha
				b.v.BackgroundTransparency=1-alpha
				b.hs.Transparency=olT
				b.vs.Transparency=olT
			else
				b.h.BackgroundTransparency=1
				b.v.BackgroundTransparency=1
				b.hs.Transparency=1
				b.vs.Transparency=1
			end
		end
		-- ring
		if st.ring then
			local d=P.size*(st.faint and 0.9 or (st.big and 0.55 or 1))
			o.ring.Size=UDim2.fromOffset(d,d)
			o.ringS.Color=c1
			o.ringS.Thickness=th*(st.faint and 0.6 or 1)
			o.ringS.Transparency=1-alpha*(st.faint and 0.45 or (st.big and 0.5 or 0.95))
		else
			o.ringS.Transparency=1
		end
		-- center dot
		if P.dot or st.big then
			local ds=st.big and (th*3+5) or (th*2+1)
			o.dot.Size=UDim2.fromOffset(ds,ds)
			o.dot.BackgroundColor3=c2
			o.dot.BackgroundTransparency=1-alpha
			o.dotS.Transparency=olT
		else
			o.dot.BackgroundTransparency=1
			o.dotS.Transparency=1
		end
		-- orbit beads + arcs
		o.orb.Rotation=(-t*(80+P.spin))%360
		for k=1,4 do
			local d=o.beads[k]
			if st.orbit then
				local ds=th*2+2
				d.Position=UDim2.new(0.5,0,0.5,-R*0.85)
				d.Size=UDim2.fromOffset(ds,ds)
				d.BackgroundColor3=(k%2==1) and c1 or c2
				d.BackgroundTransparency=1-alpha
			else
				d.BackgroundTransparency=1
			end
		end
		for k=1,2 do
			local a=o.arcs[k]
			if st.arcs then
				local d=P.size*(k==1 and 1 or 0.74)
				a.f.Size=UDim2.fromOffset(d,d)
				a.s.Color=(k==1) and c1 or c2
				a.s.Thickness=math.max(1,th*0.8)
				a.s.Transparency=1-alpha*0.9
				a.g.Rotation=(t*(k==1 and 150 or -110))%360
			else
				a.s.Transparency=1
			end
		end
	end
	return o
end

-- the crosshair on the screen (shown when "Crosshair" is on, or while Shift Lock is active)
local main=M.build(gui,4)
local xa,lkv,fl,wasLocked=0,0,0,false
connect(RunService.RenderStepped,function(dt)
	local t=os.clock()
	local locked=S.cb.lock and S.cb.tgt~=nil
	lkv=lkv+((locked and 1 or 0)-lkv)*math.min(1,dt*8)
	if locked~=wasLocked then
		wasLocked=locked
		fl=1
	end
	fl=math.max(0,fl-dt*2.5)
	local show=xh.on or (xh.withSl and ms.slOn)
	xa=xa+((show and 1 or 0)-xa)*math.min(1,dt*8)
	if xa<0.01 then
		main.root.Visible=false
	else
		main.root.Visible=true
		main.update(xh,t,lkv,fl,xa)
	end
	-- live preview inside the Misc tab
	if M.prev and activeTab==7 and uiVisible and not minimized then
		M.prev.root.Visible=true
		M.prev.update(xh,t,lkv,fl,1)
	elseif M.prev then
		M.prev.root.Visible=false
	end
end)
end -- [E:ms:xh]

------------------------------------------------ Shift Lock: floating shortcut button
-- tap = lock / unlock the camera over the shoulder, drag = move, pin = cannot be moved,
-- hold = a ring opens around the button to resize it
do -- [ms:sl]
local SMIN,SMAX=36,120
local GRAY=Color3.fromRGB(150,160,190)
local function eb(x) -- easeOutBack
	x=math.clamp(x,0,1)-1
	return 1+2.70158*x*x*x+1.70158*x*x
end

-- padlock drawn with frames: the shackle slides up when "open"
local function lockGlyph(parent,k)
	local g={parts={}}
	g.root=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromScale(k,k),BackgroundTransparency=1,BorderSizePixel=0},parent)
	g.shk=new("Frame",{Position=UDim2.fromScale(0,0),Size=UDim2.fromScale(1,0.55),BackgroundTransparency=1,BorderSizePixel=0},g.root)
	local function part(x,y,w,h,r,par)
		local f=new("Frame",{Position=UDim2.fromScale(x,y),Size=UDim2.fromScale(w,h),BackgroundColor3=C.White,BorderSizePixel=0},par)
		corner(f,r)
		g.parts[#g.parts+1]=f
		return f
	end
	part(0.2,0.12,0.14,0.88,3,g.shk)
	part(0.66,0.12,0.14,0.88,3,g.shk)
	part(0.2,0,0.6,0.22,4,g.shk)
	part(0.06,0.45,0.88,0.55,5,g.root)
	g.key=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.72),Size=UDim2.fromScale(0.14,0.14),BackgroundColor3=C.Ink,BorderSizePixel=0},g.root)
	corner(g.key,999)
	function g.setOpen(f) g.shk.Position=UDim2.fromScale(0,-0.34*f) end
	function g.setColor(c) for _,p in ipairs(g.parts) do p.BackgroundColor3=c end end
	function g.setAlpha(a)
		for _,p in ipairs(g.parts) do p.BackgroundTransparency=1-a end
		g.key.BackgroundTransparency=1-a
	end
	return g
end

------------------------------------------------ the button
local pos0=UDim2.fromOffset(math.max(60,sz0.X-46),math.floor(sz0.Y*0.58))
if ms.slX>=0 and ms.slY>=0 then pos0=UDim2.fromOffset(ms.slX,ms.slY) end
local B=new("Frame",{Name="ShiftLockBtn",AnchorPoint=Vector2.new(0.5,0.5),Size=UDim2.fromOffset(ms.slSize,ms.slSize),Position=pos0,BackgroundTransparency=1,BorderSizePixel=0,Visible=false,ZIndex=55},gui)
local bScale=new("UIScale",{Scale=0},B)
local V={}
do
local glow=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromScale(1.6,1.6),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0},B)
corner(glow,999)
tgrad(glow,45)
local body=new("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=C.White,BorderSizePixel=0},B)
corner(body,999)
grad(body,Color3.fromRGB(34,37,62),Color3.fromRGB(12,13,22),90)
local bst=stroke(body,C.White,2.4,0.1)
local bsg=new("UIGradient",{},bst)
local gl=lockGlyph(body,0.46)
-- small padlock badge in the corner while the button is pinned
local badge=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.86,0.14),Size=UDim2.fromScale(0.34,0.34),BackgroundColor3=C.Ink,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=3},B)
corner(badge,999)
local badgeS=stroke(badge,C.White,1.5,1)
local bgl=lockGlyph(badge,0.6)
bgl.setOpen(0)

function V.paint(t,act,bd)
	local col=GRAY:Lerp(T.A1,act)
	bsg.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,col),ColorSequenceKeypoint.new(0.5,GRAY:Lerp(T.A2,act)),ColorSequenceKeypoint.new(1,col)})
	bsg.Rotation=(t*(50+130*act))%360
	gl.setColor(GRAY:Lerp(C.White,act*0.9))
	gl.setOpen(1-act)
	glow.BackgroundTransparency=1-act*(0.24+0.06*math.sin(t*4))
	badge.BackgroundTransparency=1-0.8*bd
	badgeS.Transparency=1-0.7*bd
	bgl.setAlpha(bd)
	bgl.setColor(T.A1)
end
end
local bt=new("TextButton",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Text="",AutoButtonColor=false,ZIndex=4},B)

------------------------------------------------ the resize ring (opens on long press)
local E=new("Frame",{Name="ShiftLockRing",AnchorPoint=Vector2.new(0.5,0.5),Size=UDim2.fromOffset(4,4),Position=pos0,BackgroundTransparency=1,BorderSizePixel=0,Visible=false,ZIndex=54},gui)
local eScale=new("UIScale",{Scale=0.4},E)
local NE=48                       -- ring from 30 to 330 degrees, the gap on top holds the pin button
local Rr=ms.slSize/2+24
local ED={}
local ed={open=false,ap=0,idle=0,rg=false,lastF=0,stepOn=false,off=0}
local ringBegin

local pinB=new("TextButton",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,-Rr),Size=UDim2.fromOffset(30,30),BackgroundColor3=C.Ink,BackgroundTransparency=0.15,Text="",AutoButtonColor=false,BorderSizePixel=0,ZIndex=3},E)
corner(pinB,15)
local pinS=stroke(pinB,C.White,1.6,0.3)
local pinG=lockGlyph(pinB,0.5)
local rdL=label({AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,Rr+16),Size=UDim2.fromOffset(70,16),Text="",TextSize=13,Font=Enum.Font.GothamBlack,TextTransparency=1,ZIndex=3},E)
tgrad(rdL,0)

for k=1,NE do
	local a=30+(k-0.5)/NE*300
	local rot=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(4,4),Rotation=a,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=2},E)
	local bar=new("Frame",{AnchorPoint=Vector2.new(0.5,1),Position=UDim2.new(0.5,0,0.5,-Rr),Size=UDim2.fromOffset(2,0),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=2},rot)
	corner(bar,1)
	local zone=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,-Rr),Size=UDim2.fromOffset(10,30),BackgroundTransparency=1,BorderSizePixel=0,Active=true,ZIndex=3},rot)
	zone.InputBegan:Connect(function(i)
		if isPress(i) then ringBegin(i,a) end
	end)
	ED[k]={bar=bar,zone=zone}
end

local function applyR()
	for k=1,NE do
		ED[k].bar.Position=UDim2.new(0.5,0,0.5,-Rr)
		ED[k].zone.Position=UDim2.new(0.5,0,0.5,-Rr)
	end
	pinB.Position=UDim2.new(0.5,0,0.5,-Rr)
	rdL.Position=UDim2.new(0.5,0,0.5,Rr+16)
end

local function setSize(v)
	v=math.clamp(math.floor(v+0.5),SMIN,SMAX)
	if v==ms.slSize then return end
	ms.slSize=v
	B.Size=UDim2.fromOffset(v,v)
	Rr=v/2+24
	applyR()
	savePref("mssize",v)
	if S.slSizeUI then S.slSizeUI(v) end
end
S.setSlSize=setSize

local function ringTo(v)
	if v.Magnitude<6 then return end
	ed.idle=0
	local a=math.deg(math.atan2(v.X,-v.Y))
	local r=(a+540)%360-180
	local f
	if math.abs(r)<30 then
		f=(ed.lastF>=0.5) and 1 or 0
	else
		local u=(r<0) and (r+360) or r
		f=math.clamp((u-30)/300,0,1)
	end
	ed.lastF=f
	local ns=math.floor(SMIN+f*(SMAX-SMIN)+0.5)
	if ns~=ms.slSize then
		setSize(ns)
		sfx("tick",0.15,0.8+f*1.2)
	end
end
function ringBegin(i,a)
	if ed.rg or not ed.open then return end
	ed.rg=true
	ed.idle=0
	ed.P0=i.Position
	local rr=math.rad(a)
	local cx,cy=B.Position.X.Offset,B.Position.Y.Offset
	ed.G0=Vector2.new(cx+math.sin(rr)*Rr*eScale.Scale,cy-math.cos(rr)*Rr*eScale.Scale)
	ed.lastF=(ms.slSize-SMIN)/(SMAX-SMIN)
	sfx("click",0.25,1.4)
	ringTo(ed.G0-Vector2.new(cx,cy))
	i.Changed:Connect(function()
		if i.UserInputState==Enum.UserInputState.End then ed.rg=false end
	end)
end

local function openEdit()
	if ed.open then return end
	ed.open=true
	ed.idle=0
	E.Visible=true
	sfx("whoosh",0.35,1.5)
	sfx("ping",0.3,1.2)
	shockwave(E,UDim2.fromScale(0.5,0.5),ms.slSize,ms.slSize*2+60,2.5,0.6,0,nil,0.1)
end
local function closeEdit()
	if not ed.open then return end
	ed.open=false
	ed.rg=false
	sfx("switch",0.3,0.8)
end

------------------------------------------------ shift lock itself (camera over the shoulder, body follows the camera)
local function step()
	local ch=player.Character
	local hum=ch and ch:FindFirstChildOfClass("Humanoid")
	local hrp=ch and ch:FindFirstChild("HumanoidRootPart")
	local cam=workspace.CurrentCamera
	if not (hum and hrp and cam) then return end
	ed.off=ed.off+((ms.slOn and ms.slOff or 0)-ed.off)*0.2
	if not ms.slOn and math.abs(ed.off)<0.02 then
		ed.off=0
		hum.CameraOffset=Vector3.new(0,0,0)
		hum.AutoRotate=true
		UIS.MouseBehavior=Enum.MouseBehavior.Default
		ed.stepOn=false
		pcall(function() RunService:UnbindFromRenderStep("NeonFlySL") end)
		return
	end
	hum.CameraOffset=Vector3.new(ed.off,0,0)
	if ms.slOn then
		UIS.MouseBehavior=Enum.MouseBehavior.LockCenter
		if not flying and hum.Health>0 and not hum.Sit then
			hum.AutoRotate=false
			local lv=cam.CFrame.LookVector
			hrp.CFrame=CFrame.new(hrp.Position)*CFrame.Angles(0,math.atan2(-lv.X,-lv.Z),0)
		end
	end
end
local function bindStep()
	if ed.stepOn then return end
	ed.stepOn=true
	pcall(function() RunService:UnbindFromRenderStep("NeonFlySL") end)
	RunService:BindToRenderStep("NeonFlySL",Enum.RenderPriority.Camera.Value+2,step)
end
local function setSl(on)
	if on and not ms.sl then return end
	if ms.slOn==on then return end
	ms.slOn=on
	bindStep()
	sfx("switch",0.6,on and 1.25 or 0.8)
	shockwave(B,UDim2.fromScale(0.5,0.5),ms.slSize*0.6,ms.slSize*1.8,2.5,0.6,0,{a1=on and T.A1 or GRAY},0.2)
end
S.setSl=setSl

function S.setSlFeature(on)
	ms.sl=on
	savePref("mssl",on)
	if not on then
		setSl(false)
		closeEdit()
	end
	sfx("switch",0.6,on and 1.25 or 0.8)
	if S.slFeatureUI then S.slFeatureUI(on) end
end
function S.setSlLock(on)
	ms.slLock=on
	savePref("mslock",on)
	sfx("switch",0.5,on and 1.3 or 0.8)
	shockwave(E,UDim2.fromScale(0.5,0.5),30,ms.slSize+80,2,0.5,0,{a1=on and T.A1 or GRAY},0.2)
	if S.slPinUI then S.slPinUI(on) end
end
pinB.Activated:Connect(function()
	ed.idle=0
	S.setSlLock(not ms.slLock)
end)

-- keyboard: LeftShift toggles it while the feature is enabled
connect(UIS.InputBegan,function(i,gp)
	if gp then return end
	if ms.sl and i.KeyCode==Enum.KeyCode.LeftShift then setSl(not ms.slOn) end
end)

------------------------------------------------ press / drag / hold on the button
local P={drag=false,moved=false,longp=false,tok=0}
local sh={act=0,Ba=0,press=1,shake=0,bd=0}
bt.InputBegan:Connect(function(i)
	if isPress(i) and not P.drag then
		P.drag=true P.moved=false P.longp=false P.start=i.Position P.p0=B.Position
		P.tok=P.tok+1
		local my=P.tok
		ed.idle=0
		task.delay(0.45,function()
			if my==P.tok and P.drag and not P.moved and not P.longp then
				P.longp=true
				if ed.open then closeEdit() else openEdit() end
			end
		end)
		i.Changed:Connect(function()
			if i.UserInputState==Enum.UserInputState.End then
				P.drag=false
				P.tok=P.tok+1
				if P.moved then
					if not ms.slLock then
						ms.slX=B.Position.X.Offset
						ms.slY=B.Position.Y.Offset
						savePref("mslx",ms.slX)
						savePref("msly",ms.slY)
					end
				elseif not P.longp then
					if ed.open then closeEdit() else setSl(not ms.slOn) end
				end
			end
		end)
	end
end)
connect(UIS.InputChanged,function(i)
	if P.drag and not P.longp and isMove(i) then
		local d=i.Position-P.start
		if not P.moved and d.Magnitude>6 then
			P.moved=true
			if ms.slLock then
				sh.shake=1
				sfx("ping",0.3,0.6)
			end
		end
		if P.moved and not ms.slLock then
			local s=screenSize()
			local h=ms.slSize/2
			B.Position=UDim2.fromOffset(math.clamp(P.p0.X.Offset+d.X,h,s.X-h),math.clamp(P.p0.Y.Offset+d.Y,h,s.Y-h))
		end
	end
	if ed.rg and isMove(i) then
		local d=Vector2.new(i.Position.X-ed.P0.X,i.Position.Y-ed.P0.Y)
		local c=Vector2.new(B.Position.X.Offset,B.Position.Y.Offset)
		ringTo(ed.G0+d-c)
	end
end)

------------------------------------------------ per-frame animation
connect(RunService.RenderStepped,function(dt)
	local t=os.clock()
	local want=ms.sl and revealed
	sh.Ba=sh.Ba+((want and 1 or 0)-sh.Ba)*math.min(1,dt*9)
	if sh.Ba<0.02 then
		B.Visible=false
		if ed.open then closeEdit() end
	else
		B.Visible=true
		sh.press=sh.press+((P.drag and not P.moved and 0.9 or 1)-sh.press)*math.min(1,dt*16)
		bScale.Scale=eb(sh.Ba)*sh.press
		sh.act=sh.act+((ms.slOn and 1 or 0)-sh.act)*math.min(1,dt*8)
		sh.shake=math.max(0,sh.shake-dt*2.5)
		B.Rotation=math.sin(t*55)*9*sh.shake
		sh.bd=sh.bd+((ms.slLock and 1 or 0)-sh.bd)*math.min(1,dt*10)
		V.paint(t,sh.act,sh.bd)
	end

	-- resize ring
	E.Position=B.Position
	if ed.open then
		ed.idle=ed.idle+dt
		if ed.idle>5 and not ed.rg then closeEdit() end
	end
	ed.ap=ed.ap+((ed.open and 1 or 0)-ed.ap)*math.min(1,dt*9)
	if ed.ap<0.01 then
		E.Visible=false
	else
		E.Visible=true
		local ap=ed.ap
		eScale.Scale=0.4+0.6*eb(ap)
		local f=(ms.slSize-SMIN)/(SMAX-SMIN)
		local c1,c2=T.A1,T.A2
		for k=1,NE do
			local lit=math.clamp(f*NE-(k-1),0,1)
			local pop=math.clamp((ap-(k-1)/NE*0.5)/0.5,0,1)
			local wave=0.5+0.5*math.sin(t*5-k*0.4)
			local bar=ED[k].bar
			local h=math.max((6+8*lit+5*lit*wave+((k%4==1) and 4 or 0))*eb(pop),0)
			bar.Size=UDim2.fromOffset(2,h)
			bar.BackgroundColor3=C.White:Lerp(c1:Lerp(c2,k/NE),lit)
			bar.BackgroundTransparency=1-pop*(0.25+0.75*lit)
		end
		pinB.BackgroundTransparency=1-0.85*ap
		pinS.Transparency=1-0.7*ap
		pinG.setAlpha(ap)
		pinG.setColor(ms.slLock and T.A1 or GRAY)
		pinG.setOpen(ms.slLock and 0 or 1)
		rdL.Text=tostring(ms.slSize)
		rdL.TextTransparency=1-ap
	end
end)

gui.Destroying:Connect(function()
	pcall(function() RunService:UnbindFromRenderStep("NeonFlySL") end)
	local ch=player.Character
	local hum=ch and ch:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.CameraOffset=Vector3.new(0,0,0)
		hum.AutoRotate=true
	end
	UIS.MouseBehavior=Enum.MouseBehavior.Default
end)
end -- [E:ms:sl]

------------------------------------------------ the tab itself
do -- [ms:ui]
local page=new("ScrollingFrame",{
	Position=UDim2.fromScale(5,0),Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0,
	ScrollBarThickness=3,ScrollBarImageColor3=C.White,ScrollBarImageTransparency=0.6,
	CanvasSize=UDim2.new(0,0,0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollingDirection=Enum.ScrollingDirection.Y},pagesHolder)
pages[7]=page
new("UIListLayout",{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder,HorizontalAlignment=Enum.HorizontalAlignment.Center},page)
new("UIPadding",{PaddingTop=UDim.new(0,10),PaddingBottom=UDim.new(0,12)},page)

local function title(parent,key)
	local l=bindText(label({Position=UDim2.fromOffset(14,8),Size=UDim2.new(1,-28,0,18),Text="",TextSize=14,Font=Enum.Font.GothamBlack,TextColor3=C.White,TextXAlignment=Enum.TextXAlignment.Left},parent),key)
	tgrad(l,0)
	return l
end
-- label + value + slider (the slider sits 28px under y)
local function sliderRow(card_,y,key,mn,mx,val,fmt,onChange,rainbow)
	bindText(label({Position=UDim2.fromOffset(16,y),Size=UDim2.fromOffset(150,16),Text="",TextSize=12,TextColor3=C.Muted,TextXAlignment=Enum.TextXAlignment.Left},card_),key)
	local vl=label({AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-16,0,y-3),Size=UDim2.fromOffset(90,20),Text=fmt(val),TextSize=15,Font=Enum.Font.GothamBlack,TextColor3=C.White,TextXAlignment=Enum.TextXAlignment.Right},card_)
	tgrad(vl,0)
	local sl=makeSlider({parent=card_,x=16,y=y+28,width=W-24-32,min=mn,max=mx,value=val,rainbow=rainbow,scroller=page,onChange=function(v,a)
		vl.Text=fmt(v)
		onChange(v)
		tickSfx(a)
	end})
	return sl,vl
end
local function px(v) return tostring(math.floor(v+0.5)) end
local function pct(v) return math.floor(v+0.5).."%" end
local function deg(v) return math.floor(v+0.5).."°" end
local function dps(v) return math.floor(v+0.5).."°/s" end
local function switchRow(card_,y,key,get,set,after)
	local sw
	sw=S.mkRow(card_,y,key,get(),function()
		set(not get())
		sw.set(get())
		sfx("switch",0.6,get() and 1.25 or 0.8)
		if after then after(get()) end
	end)
	return sw
end

-- 1) Shift Lock ---------------------------------------------------------------------
do
local c=card(page,168,nil,1)
title(c,"ms_sl")
local sw1=S.mkRow(c,46,"ms_slbtn",ms.sl,function() S.setSlFeature(not ms.sl) end)
local sw2=S.mkRow(c,84,"ms_pin",ms.slLock,function() S.setSlLock(not ms.slLock) end)
local sl,vl=sliderRow(c,112,"ms_slsize",36,120,ms.slSize,px,function(v) S.setSlSize(v) end)
function S.slFeatureUI(on) sw1.set(on) end
function S.slPinUI(on) sw2.set(on) end
function S.slSizeUI(v)
	vl.Text=px(v)
	sl.set(v,true)
end
end

-- 2) Crosshair: live preview + on/off ---------------------------------------------------
do
local c=card(page,214,nil,2)
title(c,"ms_xh")
local pv=new("Frame",{Position=UDim2.fromOffset(14,32),Size=UDim2.fromOffset(W-24-28,96),BackgroundColor3=C.Ink,BackgroundTransparency=0.35,BorderSizePixel=0,ClipsDescendants=true},c)
corner(pv,12)
stroke(pv,C.White,1,0.85)
for k=1,3 do
	new("Frame",{Position=UDim2.fromScale(k/4,0),Size=UDim2.new(0,1,1,0),BackgroundColor3=C.White,BackgroundTransparency=0.94,BorderSizePixel=0},pv)
end
new("Frame",{Position=UDim2.fromScale(0,0.5),Size=UDim2.new(1,0,0,1),BackgroundColor3=C.White,BackgroundTransparency=0.94,BorderSizePixel=0},pv)
local holder=new("Frame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0},pv)
local fit=new("UIScale",{Scale=1},holder)
M.prev=M.build(holder,2)
connect(RunService.RenderStepped,function()
	if activeTab==7 then fit.Scale=math.min(1,76/math.max(xh.size*1.15,20)) end
end)
switchRow(c,152,"ms_xhon",function() return xh.on end,function(v) xh.on=v savePref("xhon",v) end)
switchRow(c,190,"ms_xhsl",function() return xh.withSl end,function(v) xh.withSl=v savePref("xhsl",v) end)
end

-- 3) Crosshair style ----------------------------------------------------------------
do
local c=card(page,150,nil,3)
title(c,"ms_style")
local grid=new("Frame",{Position=UDim2.fromOffset(8,32),Size=UDim2.fromOffset(300,108),BackgroundTransparency=1,BorderSizePixel=0},c)
new("UIGridLayout",{CellSize=UDim2.fromOffset(94,30),CellPadding=UDim2.fromOffset(9,6),SortOrder=Enum.SortOrder.LayoutOrder},grid)
local chips={}
local function paint(instant)
	for _,ch in ipairs(chips) do
		local sel=(xh.style==ch.idx)
		local tp=sel and 0 or 1
		local tc=sel and C.Ink or C.Text
		if instant then
			ch.fill.BackgroundTransparency=tp
			ch.lbl.TextColor3=tc
		else
			tween(ch.fill,0.25,{BackgroundTransparency=tp})
			tween(ch.lbl,0.25,{TextColor3=tc})
		end
	end
end
for idx,name in ipairs(M.names) do
	local b=new("TextButton",{LayoutOrder=idx,BackgroundColor3=C.White,BackgroundTransparency=0.93,Text="",AutoButtonColor=false,BorderSizePixel=0,ClipsDescendants=true},grid)
	corner(b,10)
	local f=new("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0},b)
	corner(f,10)
	tgrad(f,0)
	local l=label({Size=UDim2.fromScale(1,1),Text=name,TextSize=12,TextColor3=C.Text,ZIndex=2},b)
	chips[idx]={idx=idx,fill=f,lbl=l}
	b.InputBegan:Connect(function(i) if isPress(i) then ripple(b,i) end end)
	b.Activated:Connect(function()
		sfx("click",0.4,1.1)
		if xh.style~=idx then
			xh.style=idx
			savePref("xhstyle",idx)
			paint(false)
		end
	end)
end
paint(true)
end

-- 4) Crosshair shape -----------------------------------------------------------------
do
local c=card(page,294,nil,4)
title(c,"ms_shape")
sliderRow(c,40,"ms_size",16,200,xh.size,px,function(v) xh.size=v savePref("xhsize",v) end)
sliderRow(c,90,"ms_thick",1,8,xh.thick,px,function(v) xh.thick=v savePref("xhthick",v) end)
sliderRow(c,140,"ms_gap",0,60,xh.gap,px,function(v) xh.gap=v savePref("xhgap",v) end)
sliderRow(c,190,"ms_op",20,100,xh.op,pct,function(v) xh.op=v savePref("xhop",v) end)
sliderRow(c,240,"ms_spin",0,240,xh.spin,dps,function(v) xh.spin=v savePref("xhspin",v) end)
end

-- 5) Crosshair color + effects ------------------------------------------------------------
do
local c=card(page,288,nil,5)
title(c,"ms_color")
sliderRow(c,40,"ms_hue",0,359,xh.hue,deg,function(v) xh.hue=v savePref("xhhue",v) end,true)
switchRow(c,114,"ms_rainbow",function() return xh.rainbow end,function(v) xh.rainbow=v savePref("xhrb",v) end)
switchRow(c,152,"ms_dot",function() return xh.dot end,function(v) xh.dot=v savePref("xhdot",v) end)
switchRow(c,190,"ms_outline",function() return xh.outline end,function(v) xh.outline=v savePref("xhout",v) end)
switchRow(c,228,"ms_glow",function() return xh.glow end,function(v) xh.glow=v savePref("xhglow",v) end)
switchRow(c,266,"ms_react",function() return xh.react end,function(v) xh.react=v savePref("xhreact",v) end)
end

-- 6) Anti AFK + Auto Execute ---------------------------------------------------------------
do
local c=card(page,184,nil,6)
title(c,"ms_util")
switchRow(c,46,"ms_afk",function() return ms.afk end,function(v) ms.afk=v savePref("msafk",v) end)
switchRow(c,84,"ms_aex",function() return ms.aex end,function(v) ms.aex=v savePref("msaex",v) end,function(on)
	if on then
		if not S.aexSource() then
			toast(tr("ms_nosrc"))
		elseif not S.aexQueue() then
			toast(tr("ms_noq"))
		end
	else
		S.aexClear()
	end
end)
local tb=new("TextBox",{Position=UDim2.fromOffset(14,110),Size=UDim2.fromOffset(W-24-28,30),BackgroundColor3=C.White,BackgroundTransparency=0.93,Text=ms.asrc or "",PlaceholderText=[[loadstring(game:HttpGet("https://..."))()  or a URL]],PlaceholderColor3=C.Muted,TextColor3=C.Text,Font=Enum.Font.Code,TextSize=11,ClearTextOnFocus=false,TextXAlignment=Enum.TextXAlignment.Left,BorderSizePixel=0,ClipsDescendants=true},c)
corner(tb,8)
new("UIPadding",{PaddingLeft=UDim.new(0,8),PaddingRight=UDim.new(0,8)},tb)
stroke(tb,C.White,1,0.9)
tb.FocusLost:Connect(function()
	ms.asrc=tb.Text
	savePref("msasrc",tb.Text)
	if ms.aex then S.aexQueue() end
end)
bindText(label({Position=UDim2.fromOffset(16,146),Size=UDim2.new(1,-32,0,30),Text="",TextSize=10,Font=Enum.Font.Gotham,TextColor3=C.Muted,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,TextTruncate=Enum.TextTruncate.None},c),"ms_aexhint")
end

-- 7) Rejoin / smallest server / server hop ---------------------------------------------------
do
local c=card(page,108,nil,7)
title(c,"ms_servers")
local grid=new("Frame",{Position=UDim2.fromOffset(8,32),Size=UDim2.fromOffset(300,36),BackgroundTransparency=1,BorderSizePixel=0},c)
new("UIGridLayout",{CellSize=UDim2.fromOffset(94,30),CellPadding=UDim2.fromOffset(9,6),SortOrder=Enum.SortOrder.LayoutOrder},grid)
local stat=label({Position=UDim2.fromOffset(16,76),Size=UDim2.new(1,-32,0,24),Text="",TextSize=10,Font=Enum.Font.Gotham,TextColor3=C.Muted,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,TextTruncate=Enum.TextTruncate.None},c)
M.stat=stat
local busy=false
local function run(fn)
	if busy then return end
	busy=true
	stat.Text=tr("ms_busy")
	task.spawn(function()
		local ok,res,why=pcall(fn)
		busy=false
		if not ok then
			stat.Text=tr("ms_nohttp")
		elseif res==false then
			stat.Text=(why=="http") and tr("ms_nohttp") or tr("ms_nosrv")
		else
			stat.Text=tr("ms_joining")
		end
	end)
end
local function button(order,key,fn)
	local b=new("TextButton",{LayoutOrder=order,BackgroundColor3=C.White,BackgroundTransparency=0.93,Text="",AutoButtonColor=false,BorderSizePixel=0,ClipsDescendants=true},grid)
	corner(b,10)
	local f=new("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=C.White,BackgroundTransparency=0.15,BorderSizePixel=0},b)
	corner(f,10)
	tgrad(f,0)
	bindText(label({Size=UDim2.fromScale(1,1),Text="",TextSize=12,TextColor3=C.Ink,ZIndex=2},b),key)
	b.InputBegan:Connect(function(i) if isPress(i) then ripple(b,i) end end)
	b.Activated:Connect(function()
		sfx("click",0.4,1.2)
		fn()
	end)
end
button(1,"ms_rejoin",function() run(function() S.rejoin() return true end) end)
button(2,"ms_small",function() run(S.smallestServer) end)
button(3,"ms_hop",function() run(S.hopServer) end)
end

-- 8) Server browser ----------------------------------------------------------------------
do
local c=card(page,240,nil,8)
title(c,"ms_list")
local order="Asc"
local rows={}
local busy=false
local list=new("ScrollingFrame",{Position=UDim2.fromOffset(8,72),Size=UDim2.fromOffset(300,160),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=2,ScrollBarImageColor3=C.White,ScrollBarImageTransparency=0.6,CanvasSize=UDim2.new(0,0,0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollingDirection=Enum.ScrollingDirection.Y},c)
new("UIListLayout",{Padding=UDim.new(0,4),SortOrder=Enum.SortOrder.LayoutOrder},list)
local note=label({Position=UDim2.fromOffset(16,112),Size=UDim2.new(1,-32,0,40),Text="",TextSize=11,Font=Enum.Font.Gotham,TextColor3=C.Muted,TextWrapped=true,TextTruncate=Enum.TextTruncate.None},c)

local function clear()
	for _,r in ipairs(rows) do r:Destroy() end
	rows={}
end
local function addRow(idx,s)
	local b=new("TextButton",{LayoutOrder=idx,Size=UDim2.new(1,-6,0,28),BackgroundColor3=C.White,BackgroundTransparency=0.93,Text="",AutoButtonColor=false,BorderSizePixel=0,ClipsDescendants=true},list)
	corner(b,8)
	local here=(s.id==game.JobId)
	label({Position=UDim2.fromOffset(10,0),Size=UDim2.fromOffset(70,28),Text=(here and "• " or "")..s.playing.."/"..s.maxPlayers,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=2},b)
	label({Position=UDim2.fromOffset(84,0),Size=UDim2.fromOffset(90,28),Text=s.ping and (math.floor(s.ping).." ms") or "",TextSize=10,Font=Enum.Font.Gotham,TextColor3=C.Muted,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=2},b)
	local pill=new("Frame",{AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-6,0.5,0),Size=UDim2.fromOffset(54,20),BackgroundColor3=C.White,BorderSizePixel=0,ZIndex=2},b)
	corner(pill,10)
	tgrad(pill,0)
	bindText(label({Size=UDim2.fromScale(1,1),Text="",TextSize=10,TextColor3=C.Ink,ZIndex=3},pill),"ms_join")
	b.InputBegan:Connect(function(i) if isPress(i) then ripple(b,i) end end)
	b.Activated:Connect(function()
		sfx("click",0.4,1.2)
		note.Text=tr("ms_joining")
		note.Visible=true
		S.tpServer(s.id)
	end)
	rows[#rows+1]=b
end
local function refresh()
	if busy then return end
	busy=true
	clear()
	note.Text=tr("ms_busy")
	note.Visible=true
	task.spawn(function()
		local data=S.fetchServers(order,50)
		busy=false
		if not data then
			note.Text=tr("ms_nohttp")
		elseif #data==0 then
			note.Text=tr("ms_nosrv")
		else
			note.Visible=false
			for idx,s in ipairs(data) do
				if idx>40 then break end
				if s.playing and s.maxPlayers then addRow(idx,s) end
			end
		end
	end)
end

-- sort chips (fewest / most players) + refresh
local chipsFx={}
local function paint(instant)
	for _,ch in ipairs(chipsFx) do
		local sel=(order==ch.key)
		local tp=sel and 0 or 1
		local tc=sel and C.Ink or C.Text
		if instant then
			ch.fill.BackgroundTransparency=tp
			ch.lbl.TextColor3=tc
		else
			tween(ch.fill,0.25,{BackgroundTransparency=tp})
			tween(ch.lbl,0.25,{TextColor3=tc})
		end
	end
end
local function chip(x,w,key,tkey,isAction)
	local b=new("TextButton",{Position=UDim2.fromOffset(x,34),Size=UDim2.fromOffset(w,30),BackgroundColor3=C.White,BackgroundTransparency=0.93,Text="",AutoButtonColor=false,BorderSizePixel=0,ClipsDescendants=true},c)
	corner(b,10)
	local f=new("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=C.White,BackgroundTransparency=isAction and 0.15 or 1,BorderSizePixel=0},b)
	corner(f,10)
	tgrad(f,0)
	local l=bindText(label({Size=UDim2.fromScale(1,1),Text="",TextSize=12,TextColor3=isAction and C.Ink or C.Text,ZIndex=2},b),tkey)
	if not isAction then chipsFx[#chipsFx+1]={key=key,fill=f,lbl=l} end
	b.InputBegan:Connect(function(i) if isPress(i) then ripple(b,i) end end)
	b.Activated:Connect(function()
		sfx("click",0.4,1.1)
		if isAction then
			refresh()
		elseif order~=key then
			order=key
			paint(false)
			refresh()
		end
	end)
end
chip(8,94,"Asc","ms_fewest",false)
chip(111,94,"Desc","ms_most",false)
chip(214,94,"","ms_refresh",true)
paint(true)
note.Text=tr("ms_listhint")
end
end -- [E:ms:ui]
end -- [E:S:misc]


-------------------------------------------------- TAB BAR
-- (block-scoped: only tabBar and setTab are needed outside)
local tabBar,setTab
do -- [S:tabs]
local NTAB=10
local TAB_KEYS={"tab_home","tab_fly","tab_player","tab_combat","tab_visual","tab_atmo","tab_misc","tab_set","tab_log","tab_credit"}
local TAB_ICONS={"home","fly","player","combat","visual","atmo","misc","set","log","credit"}
tabBar=new("Frame",{Position=UDim2.fromOffset(0,H_OPEN-TAB_H),Size=UDim2.fromOffset(W,TAB_H),BackgroundColor3=C.Ink,BackgroundTransparency=0.45,BorderSizePixel=0,ZIndex=2},win)
new("Frame",{Size=UDim2.new(1,0,0,1),BackgroundColor3=C.White,BackgroundTransparency=0.9,BorderSizePixel=0},tabBar)
local TW=56
local tabScroll=new("ScrollingFrame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=0,CanvasSize=UDim2.fromOffset(NTAB*TW,0),ScrollingDirection=Enum.ScrollingDirection.X},tabBar)
local indicator=new("Frame",{AnchorPoint=Vector2.new(0.5,0),Position=UDim2.fromOffset(TW/2,0),Size=UDim2.fromOffset(34,3),BackgroundColor3=C.White,BorderSizePixel=0},tabScroll)
corner(indicator,2) tgrad(indicator,0)

local tabs={}
local function mkIcon(kind,parent)
	local h=new("Frame",{AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0,5),Size=UDim2.fromOffset(16,16),BackgroundTransparency=1,BorderSizePixel=0},parent)
	local parts={}
	local function part(w,hh,x,y,rot,round)
		local f=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,hh),Rotation=rot or 0,BackgroundColor3=C.Muted,BorderSizePixel=0},h)
		corner(f,round or 2)
		table.insert(parts,f)
	end
	if kind=="home" then
		part(9,2,4.6,5.2,-38) part(9,2,11.4,5.2,38)
		part(2,6,3.5,11.5) part(2,6,12.5,11.5) part(11,2,8,14)
	elseif kind=="fly" then
		part(10,2,5,6,-53) part(10,2,11,6,53)
		part(10,2,5,11,-53) part(10,2,11,11,53)
	elseif kind=="log" then
		part(2,8,8,9) part(6.4,2,5.75,4.75,-45) part(6.4,2,10.25,4.75,45) part(12,2,8,14.5)
	elseif kind=="player" then
		part(5,5,8,3.5,0,3) part(9,5,8,9.5,0,2) part(2.5,4,6.5,14.5) part(2.5,4,9.5,14.5)
	elseif kind=="combat" then
		part(2,5,8,2.5) part(2,5,8,13.5) part(5,2,2.5,8) part(5,2,13.5,8) part(4,4,8,8,0,2)
	elseif kind=="visual" then
		part(8,2,5,6,-30) part(8,2,11,6,30) part(8,2,5,10,30) part(8,2,11,10,-30) part(4,4,8,8,0,2)
	elseif kind=="atmo" then
		part(6,6,8,8,0,3) part(2,3,8,2.5) part(2,3,8,13.5) part(3,2,2.5,8) part(3,2,13.5,8)
	elseif kind=="misc" then
		part(5,5,4.5,4.5,0,2) part(5,5,11.5,4.5,0,2) part(5,5,4.5,11.5,0,2) part(5,5,11.5,11.5,0,2)
	elseif kind=="credit" then
		part(12,2,8,8,0) part(12,2,8,8,90)
		part(11,2,8,8,45) part(11,2,8,8,-45)
	else
		part(12,2,8,3) part(12,2,8,8) part(12,2,8,13)
		part(5,5,5,3,0,3) part(5,5,11,8,0,3) part(5,5,6,13,0,3)
	end
	return parts
end
local function paintTab(t,on,instant)
	local col=on and T.A1 or C.Muted
	for _,p in ipairs(t.parts) do
		if instant then p.BackgroundColor3=col else tween(p,0.25,{BackgroundColor3=col}) end
	end
	if instant then t.lbl.TextColor3=col else tween(t.lbl,0.25,{TextColor3=col}) end
end
local function makeTab(idx)
	local b=new("TextButton",{Position=UDim2.fromOffset((idx-1)*TW,0),Size=UDim2.fromOffset(TW,TAB_H),BackgroundTransparency=1,Text="",AutoButtonColor=false,ClipsDescendants=true},tabScroll)
	local parts=mkIcon(TAB_ICONS[idx],b)
	local l=bindText(label({Position=UDim2.fromOffset(0,22),Size=UDim2.new(1,0,0,16),Text="",TextSize=10,TextColor3=C.Muted},b),TAB_KEYS[idx])
	local t={btn=b,parts=parts,lbl=l}
	tabs[idx]=t
	return t
end

-- cinematic tab transition: a themed panel sweeps over the pages and shows the logo + tab name
local trans=new("Frame",{Name="TabTransition",Size=UDim2.fromScale(1,1),Position=UDim2.fromScale(-1.1,0),BackgroundColor3=C.White,BorderSizePixel=0,Visible=false,ZIndex=40,ClipsDescendants=true},pagesHolder)
tgrad(trans,25)
new("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=C.Ink,BackgroundTransparency=0.45,BorderSizePixel=0,ZIndex=41},trans)
local bandA=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(-0.3,0.5),Size=UDim2.fromOffset(34,420),Rotation=18,BackgroundColor3=C.White,BackgroundTransparency=0.8,BorderSizePixel=0,ZIndex=42},trans)
local bandB=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(-0.3,0.5),Size=UDim2.fromOffset(12,420),Rotation=18,BackgroundColor3=C.White,BackgroundTransparency=0.7,BorderSizePixel=0,ZIndex=42},trans)
local badge=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,-24),Size=UDim2.fromOffset(60,60),BackgroundColor3=C.Ink,BackgroundTransparency=0.1,BorderSizePixel=0,ZIndex=43},trans)
corner(badge,18)
stroke(badge,C.White,2,0.1)
local badgeScale=new("UIScale",{Scale=0},badge)
local xh=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(34,34),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=44},badge)
makeXMark(xh,"neon")
local nameL=label({AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0.5,16),Size=UDim2.fromOffset(290,26),Text="",TextSize=22,Font=Enum.Font.GothamBlack,TextColor3=C.White,TextTransparency=1,ZIndex=43},trans)
local nameStroke=tstroke(nameL,C.Ink,2)
local lineB=new("Frame",{AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0.5,50),Size=UDim2.fromOffset(0,2),BackgroundColor3=C.White,BorderSizePixel=0,ZIndex=43},trans)
corner(lineB,2)

local transTok=0
local function playTrans(idx)
	transTok=transTok+1
	local tok=transTok
	local function live() return alive and tok==transTok end
	nameL.Text=tr(TAB_KEYS[idx])
	if not trans.Visible then
		trans.Position=UDim2.fromScale(-1.1,0)
		trans.Visible=true
	end
	badgeScale.Scale=0
	xh.Rotation=-180
	nameL.TextTransparency=1
	nameStroke.Transparency=1
	lineB.Size=UDim2.fromOffset(0,2)
	bandA.Position=UDim2.fromScale(-0.3,0.5)
	bandB.Position=UDim2.fromScale(-0.3,0.5)
	tween(trans,0.26,{Position=UDim2.fromScale(0,0)},Enum.EasingStyle.Quint)
	tween(bandA,0.75,{Position=UDim2.fromScale(1.3,0.5)},Enum.EasingStyle.Linear)
	task.delay(0.08,function()
		if live() then tween(bandB,0.7,{Position=UDim2.fromScale(1.3,0.5)},Enum.EasingStyle.Linear) end
	end)
	task.delay(0.24,function()
		if not live() then return end
		-- the panel fully covers the pages now: swap the page instantly underneath it
		for i=1,NTAB do pages[i].Position=UDim2.fromScale(i-idx,0) end
		tween(badgeScale,0.4,{Scale=1},Enum.EasingStyle.Back)
		tween(xh,0.55,{Rotation=0},Enum.EasingStyle.Back)
		tween(nameL,0.25,{TextTransparency=0})
		tween(nameStroke,0.25,{Transparency=0.35})
		tween(lineB,0.45,{Size=UDim2.fromOffset(120,2)},Enum.EasingStyle.Quint)
		sfx("ping",0.2,0.9+idx*0.14)
	end)
	task.delay(0.78,function()
		if not live() then return end
		tween(badgeScale,0.2,{Scale=0.7})
		tween(nameL,0.2,{TextTransparency=1})
		tween(nameStroke,0.2,{Transparency=1})
		tween(trans,0.28,{Position=UDim2.fromScale(1.1,0)},Enum.EasingStyle.Quint,Enum.EasingDirection.In)
		task.delay(0.3,function()
			if live() then trans.Visible=false end
		end)
	end)
end

function setTab(idx,noFx)
	local changed=(idx~=activeTab)
	activeTab=idx
	tween(indicator,0.35,{Position=UDim2.fromOffset((idx-0.5)*TW,0)},Enum.EasingStyle.Quint)
	local tx=math.clamp((idx-0.5)*TW-W/2,0,math.max(0,NTAB*TW-W))
	tween(tabScroll,0.35,{CanvasPosition=Vector2.new(tx,0)},Enum.EasingStyle.Quint)
	for n,t in ipairs(tabs) do paintTab(t,n==idx,false) end
	if changed and not noFx and S.vfx and revealed then
		playTrans(idx)
	else
		for i=1,NTAB do tween(pages[i],0.4,{Position=UDim2.fromScale(i-idx,0)},Enum.EasingStyle.Quint) end
	end
end
for i=1,NTAB do makeTab(i) end
for n,t in ipairs(tabs) do
	t.btn.InputBegan:Connect(function(i) if isPress(i) then ripple(t.btn,i) end end)
	t.btn.Activated:Connect(function()
		if activeTab~=n then
			sfx("click",0.35,0.85+n*0.15)
			if n==10 then task.delay(S.vfx and 0.6 or 0.18,crPlay) end
		end
		setTab(n)
	end)
	paintTab(t,n==activeTab,true)
end
onTheme(function()
	for n,t in ipairs(tabs) do paintTab(t,n==activeTab,true) end
end)
for i=1,NTAB do pages[i].Position=UDim2.fromScale(i-activeTab,0) end
end -- [E:tabs]

-------------------------------------------------- RESIZE GRIP (bottom-right corner)
-- (block-scoped: only grip is needed outside)
local grip
do -- [S:grip]
grip=new("TextButton",{Name="ResizeGrip",AnchorPoint=Vector2.new(1,1),Position=UDim2.new(1,-2,1,-2),Size=UDim2.fromOffset(26,26),BackgroundTransparency=1,Text="",AutoButtonColor=false,ZIndex=30},win)
local gripBars={}
for _,b in ipairs({{19,19,6},{15,15,12},{11,11,18}}) do
	local f=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromOffset(b[1],b[2]),Size=UDim2.fromOffset(b[3],2),Rotation=-45,BackgroundColor3=C.Muted,BorderSizePixel=0,ZIndex=31},grip)
	corner(f,1)
	table.insert(gripBars,f)
end
local sizeTag=new("Frame",{AnchorPoint=Vector2.new(1,1),Position=UDim2.new(1,-34,1,-10),Size=UDim2.fromOffset(54,20),BackgroundColor3=C.Ink,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=31},win)
corner(sizeTag,10)
local sizeTagLbl=label({Size=UDim2.fromScale(1,1),Text="100%",TextSize=11,TextTransparency=1,ZIndex=32},sizeTag)

local resizing=false
local rsStart,rsScale0
local lastRsTick=0
local function gripColor(col)
	for _,b in ipairs(gripBars) do tween(b,0.2,{BackgroundColor3=col}) end
end
grip.MouseEnter:Connect(function() if not resizing then gripColor(T.A1) end end)
grip.MouseLeave:Connect(function() if not resizing then gripColor(C.Muted) end end)

local function endResize()
	if not resizing then return end
	resizing=false
	savePref("scale",uiScale.Scale)
	gripColor(C.Muted)
	tween(sizeTag,0.3,{BackgroundTransparency=1})
	tween(sizeTagLbl,0.3,{TextTransparency=1})
	-- keep the window on screen
	local s=screenSize()
	local sc=uiScale.Scale
	local p=anchor.Position
	local nx=math.clamp(p.X.Offset,0,math.max(0,s.X-W*sc))
	local ny=math.clamp(p.Y.Offset,0,math.max(0,s.Y-H_OPEN*sc))
	tween(anchor,0.25,{Position=UDim2.fromOffset(nx,ny)},Enum.EasingStyle.Quint)
end
grip.InputBegan:Connect(function(i)
	if isPress(i) and not resizing then
		resizing=true
		rsStart=i.Position
		rsScale0=uiScale.Scale
		gripColor(T.A1)
		sfx("tick",0.25,1.3)
		sizeTagLbl.Text=math.floor(rsScale0*100+0.5).."%"
		tween(sizeTag,0.2,{BackgroundTransparency=0.15})
		tween(sizeTagLbl,0.2,{TextTransparency=0})
		i.Changed:Connect(function()
			if i.UserInputState==Enum.UserInputState.End then endResize() end
		end)
	end
end)
connect(UIS.InputChanged,function(i)
	if resizing and isMove(i) then
		local d=i.Position-rsStart
		local s=screenSize()
		local maxS=math.max(MIN_SCALE,math.min(MAX_SCALE,(s.X-4)/W,(s.Y-4)/H_OPEN))
		local ns=math.clamp(rsScale0+(d.X/W+d.Y/H_OPEN)/2,MIN_SCALE,maxS)
		uiScale.Scale=ns
		sizeTagLbl.Text=math.floor(ns*100+0.5).."%"
		local now=os.clock()
		if now-lastRsTick>0.08 then
			lastRsTick=now
			sfx("tick",0.08,0.8+ns*0.6)
		end
	end
end)
end -- [E:grip]

-------------------------------------------------- FLY LOGIC + VFX
local bv,bg
local curVel=Vector3.new(0,0,0)
local controls
local fx,windSnd,baseFov
task.spawn(function()
	pcall(function()
		local ps=player:WaitForChild("PlayerScripts",5)
		local pm=ps and ps:WaitForChild("PlayerModule",5)
		if pm then controls=require(pm):GetControls() end
	end)
end)

local function getChar()
	local ch=player.Character
	if not ch then return end
	return ch,ch:FindFirstChild("HumanoidRootPart"),ch:FindFirstChildOfClass("Humanoid")
end

local function getMove(hum,cam)
	if controls then
		local ok,v=pcall(function() return controls:GetMoveVector() end)
		if ok and v then return v.X,-v.Z end
	end
	local md=hum.MoveDirection
	if md.Magnitude>0 then
		local l,r=cam.CFrame.LookVector,cam.CFrame.RightVector
		local fl,fr=Vector3.new(l.X,0,l.Z),Vector3.new(r.X,0,r.Z)
		if fl.Magnitude>0.01 and fr.Magnitude>0.01 then
			return md:Dot(fr.Unit),md:Dot(fl.Unit)
		end
	end
	return 0,0
end

local function destroyFx()
	if fx then
		for _,o in ipairs(fx.list) do
			if o and o.Parent then o:Destroy() end
		end
		fx=nil
	end
	if windSnd then
		windSnd:Destroy()
		windSnd=nil
	end
end

local function buildFx(hrp)
	destroyFx()
	local f={list={},trails={}}
	local cs=ColorSequence.new(T.A1,T.A2)
	for _,x in ipairs({-1.1,1.1}) do
		local a0=new("Attachment",{Position=Vector3.new(x,0.7,0.6)},hrp)
		local a1=new("Attachment",{Position=Vector3.new(x,-0.9,0.6)},hrp)
		local t=new("Trail",{
			Attachment0=a0,Attachment1=a1,Lifetime=0.55,FaceCamera=true,LightEmission=1,MinLength=0.05,Color=cs,
			Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.15),NumberSequenceKeypoint.new(1,1)}),
			WidthScale=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,0)}),
			Enabled=false},hrp)
		table.insert(f.list,a0) table.insert(f.list,a1) table.insert(f.list,t)
		table.insert(f.trails,t)
	end
	f.emit=new("ParticleEmitter",{
		Rate=0,Lifetime=NumberRange.new(0.5,1.1),Speed=NumberRange.new(1,5),SpreadAngle=Vector2.new(180,180),
		Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0.7),NumberSequenceKeypoint.new(1,0)}),
		Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.1),NumberSequenceKeypoint.new(1,1)}),
		LightEmission=1,Color=cs,Rotation=NumberRange.new(0,360),RotSpeed=NumberRange.new(-90,90),
		EmissionDirection=Enum.NormalId.Back,LockedToPart=false},hrp)
	table.insert(f.list,f.emit)
	f.light=new("PointLight",{Color=T.A1,Brightness=0,Range=16,Shadows=false},hrp)
	table.insert(f.list,f.light)
	fx=f
end

onTheme(function()
	if fx then
		local cs=ColorSequence.new(T.A1,T.A2)
		for _,t in ipairs(fx.trails) do t.Color=cs end
		fx.emit.Color=cs
		fx.light.Color=T.A1
	end
end)

local function ringBurst(pos,size)
	if not S.vfx then return end
	local parent=workspace.CurrentCamera or workspace
	for n=1,2 do
		local d=size*(n==1 and 1 or 1.6)
		local p=new("Part",{
			Anchored=true,CanCollide=false,CanQuery=false,CanTouch=false,CastShadow=false,
			Material=Enum.Material.Neon,Color=(n==1) and T.A1 or T.A2,Shape=Enum.PartType.Cylinder,
			Size=Vector3.new(0.3,1,1),Transparency=0.3,
			CFrame=CFrame.new(pos)*CFrame.Angles(0,0,math.rad(90))},parent)
		TS:Create(p,TweenInfo.new(0.5+0.15*n,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{Size=Vector3.new(0.3,d,d),Transparency=1}):Play()
		Debris:AddItem(p,1)
	end
end

local function startFly()
	local _,hrp,hum=getChar()
	if not hrp or not hum or hum.Health<=0 then return false end
	local cam=workspace.CurrentCamera
	bv=new("BodyVelocity",{MaxForce=Vector3.new(9e9,9e9,9e9),Velocity=Vector3.new(0,0,0)},hrp)
	bg=new("BodyGyro",{MaxTorque=Vector3.new(9e9,9e9,9e9),P=9e4,D=1e3,CFrame=hrp.CFrame},hrp)
	hum.PlatformStand=true
	curVel=Vector3.new(0,14,0)
	baseFov=cam and cam.FieldOfView or 70
	buildFx(hrp)
	if S.vfx and fx then fx.emit:Emit(40) end
	ringBurst(hrp.Position,16)
	sfx("whoosh",0.5,1.5)
	windSnd=sounds.wind:Clone()
	windSnd.Looped=true
	windSnd.Volume=0
	windSnd.Parent=gui
	windSnd:Play()
	return true
end

local function stopFly(quiet)
	if bv then bv:Destroy() bv=nil end
	if bg then bg:Destroy() bg=nil end
	curVel=Vector3.new(0,0,0)
	touchVert=0
	destroyFx()
	local cam=workspace.CurrentCamera
	if cam and baseFov then
		if quiet then cam.FieldOfView=baseFov else tween(cam,0.5,{FieldOfView=baseFov}) end
	end
	local _,hrp,hum=getChar()
	if hrp then
		local l=hrp.CFrame.LookVector
		local flat=Vector3.new(l.X,0,l.Z)
		if flat.Magnitude>0.01 then hrp.CFrame=CFrame.new(hrp.Position,hrp.Position+flat) end
		hrp.Velocity=Vector3.new(0,0,0)
		if not quiet then
			ringBurst(hrp.Position,10)
			sfx("land",0.5,1)
		end
	end
	if hum then
		hum.PlatformStand=false
		hum:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
end

local function refreshToggle(on)
	flySwitch.set(on)
	tween(dot,0.2,{BackgroundColor3=on and T.A1 or C.Off})
	tween(statusLbl,0.2,{TextColor3=on and T.A1 or C.Muted})
	if uiVisible then tween(mainStroke,0.3,{Transparency=on and 0 or 0.35}) end
	tween(fbDot,0.25,{BackgroundTransparency=on and 0 or 1})
	statusLbl.Text=on and tr("on") or tr("off")
	if S.onFlyState then S.onFlyState(on) end
	if not on then
		dot.Size=UDim2.fromOffset(8,8)
		velLbl.Text="0 st/s"
	end
end

local function setFlying(state,quiet)
	if state==flying then return true end
	if state then
		if not startFly() then
			sfx("ping",0.4,0.6)
			toast(tr("t_fail"))
			return false
		end
	else
		stopFly(false)
	end
	flying=state
	refreshToggle(state)
	if not quiet then
		sfx("switch",0.6,state and 1.25 or 0.8)
		toast(state and tr("t_on") or tr("t_off"))
	end
	return true
end

-- used by the Quick Fly dial (tap on the icon)
function S.toggleFly() setFlying(not flying) end

-------------------------------------------------- BUTTONS / DRAG
toggleBtn.InputBegan:Connect(function(i) if isPress(i) then ripple(toggleBtn,i) end end)
toggleBtn.Activated:Connect(function() setFlying(not flying) end)

local dragging,dragStart,startPos=false,nil,nil
dragArea.InputBegan:Connect(function(i)
	if isPress(i) then
		dragging=true dragStart=i.Position startPos=anchor.Position
		i.Changed:Connect(function()
			if i.UserInputState==Enum.UserInputState.End then dragging=false end
		end)
	end
end)
connect(UIS.InputChanged,function(i)
	if dragging and isMove(i) then
		local d=i.Position-dragStart
		local s=screenSize()
		local sc=uiScale.Scale
		local x=math.clamp(startPos.X.Offset+d.X,-(W*sc-80),s.X-80)
		local y=math.clamp(startPos.Y.Offset+d.Y,0,s.Y-H_MIN*sc)
		anchor.Position=UDim2.fromOffset(x,y)
	end
end)

minBtn.Activated:Connect(function()
	minimized=not minimized
	sfx("click",0.35,minimized and 0.9 or 1.2)
	if minimized then
		grip.Visible=false
		tween(main,0.3,{Size=UDim2.fromOffset(W,H_MIN)},Enum.EasingStyle.Quint)
		tween(plusBar,0.2,{BackgroundTransparency=0})
		task.delay(0.3,function()
			if minimized then pagesHolder.Visible=false tabBar.Visible=false divider.Visible=false end
		end)
	else
		pagesHolder.Visible=true tabBar.Visible=true divider.Visible=true
		grip.Visible=true
		tween(main,0.4,{Size=UDim2.fromOffset(W,H_OPEN)},Enum.EasingStyle.Back)
		tween(plusBar,0.2,{BackgroundTransparency=1})
	end
end)

local cleaned=false
local function cleanup()
	if cleaned then return end
	cleaned=true
	alive=false
	if flying then
		flying=false
		stopFly(true)
	end
	destroyFx()
	for _,c in ipairs(conns) do c:Disconnect() end
	if blurFx then blurFx:Destroy() blurFx=nil end
	if loadGui then loadGui:Destroy() loadGui=nil end
end
gui.Destroying:Connect(cleanup)

closeBtn.Activated:Connect(function()
	if closing then return end
	closing=true
	sfx("switch",0.5,0.7)
	setFlying(false,true)
	tween(main,0.25,{Size=UDim2.fromOffset(W,0),BackgroundTransparency=1},Enum.EasingStyle.Quint,Enum.EasingDirection.In)
	tween(mainStroke,0.25,{Transparency=1})
	tween(fbScale,0.25,{Scale=0})
	task.delay(0.28,function() gui:Destroy() end)
end)

-------------------------------------------------- LOOP
local lastHud=0
local rimT=1
connect(RunService.RenderStepped,function(dt)
	local now0=os.clock()
	strokeGrad.Rotation=(now0*60)%360
	if fb.Visible then fbGrad.Rotation=(now0*80)%360 end
	if activeTab==10 and not minimized and uiVisible then
		crEmb.update(now0)
		crStrokeGrad.Rotation=(now0*50)%360
	end
	local frac=0
	if flying then
		local _,hrp,hum=getChar()
		local cam=workspace.CurrentCamera
		if not hrp or not hum or hum.Health<=0 or not bv or not bv.Parent or not cam then
			setFlying(false)
		else
			local right,fwd=getMove(hum,cam)
			local dir=cam.CFrame.RightVector*right+cam.CFrame.LookVector*fwd
			local vert=touchVert
			if not UIS:GetFocusedTextBox() then
				if UIS:IsKeyDown(Enum.KeyCode.Space) or UIS:IsKeyDown(Enum.KeyCode.E) then vert=vert+1 end
				if UIS:IsKeyDown(Enum.KeyCode.Q) or UIS:IsKeyDown(Enum.KeyCode.LeftControl) then vert=vert-1 end
			end
			dir=dir+Vector3.new(0,vert,0)
			if dir.Magnitude>1 then dir=dir.Unit end
			curVel=curVel:Lerp(dir*speed,math.clamp(dt*12,0,1))
			bv.Velocity=curVel
			bg.CFrame=cam.CFrame

			-- effects
			local vel=curVel.Magnitude
			frac=math.clamp(vel/200,0,1)
			local on=S.vfx
			if fx then
				for _,t in ipairs(fx.trails) do t.Enabled=on and vel>4 end
				fx.emit.Rate=on and frac*80 or 0
				fx.light.Brightness=on and (0.6+frac*1.8) or 0
			end
			if windSnd then
				windSnd.Volume=S.sfx and (0.45*frac*(S.volume/100)) or 0
				windSnd.PlaybackSpeed=0.7+frac*0.8
			end
			local fovT=on and (baseFov+frac*22) or baseFov
			cam.FieldOfView=cam.FieldOfView+(fovT-cam.FieldOfView)*math.min(1,dt*5)

			-- HUD
			local p=(math.sin(os.clock()*6)+1)/2
			dot.Size=UDim2.fromOffset(8+p*4,8+p*4)
			local now=os.clock()
			if now-lastHud>0.08 then
				lastHud=now
				velLbl.Text=math.floor(vel+0.5).." st/s"
			end
		end
	end
	local target=(flying and S.vfx) and (1-0.7*frac) or 1
	rimT=rimT+(target-rimT)*math.min(1,dt*6)
	for _,f in ipairs(rim) do
		f.BackgroundTransparency=rimT
		f.Visible=rimT<0.985
	end
end)

connect(player.CharacterAdded,function()
	if flying then
		flying=false
		bv,bg=nil,nil
		destroyFx()
		touchVert=0
		local cam=workspace.CurrentCamera
		if cam and baseFov then cam.FieldOfView=baseFov end
		refreshToggle(false)
	end
end)

-------------------------------------------------- LOADING SCREEN (5 styles, pick one in Settings)
local function reveal()
	if revealed or not alive then return end
	revealed=true
	anchor.Visible=true
	tween(main,0.55,{Size=UDim2.fromOffset(W,H_OPEN)},Enum.EasingStyle.Back)
	setTab(1,true)
	if floatOn then
		fb.Visible=true
		fbScale.Scale=0
		task.delay(0.35,function()
			if alive and floatOn then tween(fbScale,0.5,{Scale=1},Enum.EasingStyle.Back) end
		end)
	end
end

-- styleIdx: 1 Sky Warp, 2 Synthwave, 3 Matrix, 4 Hyperspace, 5 Aurora
-- preview=true plays a shorter version (Settings > Preview) and does not touch the real UI
function runLoader(styleIdx,preview)
	local sid=(LSTYLES[styleIdx] and styleIdx) or 1
	local ST=LSTYLES[sid]
	local P=ST.P
	local function wt(s) task.wait(preview and s*0.45 or s) end

	local lg=new("ScreenGui",{Name="NeonFlyLoading",ResetOnSpawn=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,IgnoreGuiInset=true,DisplayOrder=200},playerGui)
	loadGui=lg
	blurFx=new("BlurEffect",{Name="NeonFlyBlur",Size=0},Lighting)
	tween(blurFx,0.8,{Size=20})

	local bd=new("CanvasGroup",{Size=UDim2.fromScale(1,1),BackgroundColor3=C.White,BackgroundTransparency=0,BorderSizePixel=0,GroupTransparency=1,Active=true},lg)
	grad(bd,P.top,P.bot,90)
	tween(bd,0.5,{GroupTransparency=0})

	local ctx={warp=0,oy=0}
	local upd={}
	local function liveL() return alive and lg.Parent~=nil end

	local function softGlow(parent,pos,d,col,t0)
		local h=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=pos,Size=UDim2.fromOffset(d,d),BackgroundTransparency=1,BorderSizePixel=0},parent)
		for k=1,4 do
			local s=d*(1-(k-1)*0.22)
			local c=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(s,s),BackgroundColor3=col,BackgroundTransparency=t0,BorderSizePixel=0},h)
			new("UICorner",{CornerRadius=UDim.new(0.5,0)},c)
		end
		return h
	end

	---------------- backgrounds (one per style) ----------------
	local BG={}

	-- 1) Sky Warp: speed streaks + rising bubbles
	BG[1]=function()
		local st=new("Frame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0,ClipsDescendants=true},bd)
		for n=1,14 do
			task.spawn(function()
				local rnd=Random.new(n*53+11)
				local f=new("Frame",{AnchorPoint=Vector2.new(0,0.5),BackgroundColor3=C.White,BorderSizePixel=0,Visible=false},st)
				new("UIGradient",{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,0.1)})},f)
				task.wait(rnd:NextNumber(0,1.2))
				while liveL() do
					local len=rnd:NextInteger(90,300)
					local y=rnd:NextNumber(0.04,0.96)
					local dur=rnd:NextNumber(0.55,1.4)/(1+ctx.warp*1.6)
					f.Size=UDim2.fromOffset(len,rnd:NextInteger(1,2))
					f.BackgroundTransparency=rnd:NextNumber(0.1,0.55)
					f.Position=UDim2.new(-0.1,-len,y,0)
					f.Visible=true
					tween(f,dur,{Position=UDim2.new(1.1,0,y,0)},Enum.EasingStyle.Linear)
					task.wait(dur+rnd:NextNumber(0,0.5))
				end
			end)
		end
		local bub=new("Frame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0},bd)
		for n=1,18 do
			task.spawn(function()
				local rnd=Random.new(n*97+3)
				local sz=rnd:NextInteger(8,34)
				local d=new("Frame",{Size=UDim2.fromOffset(sz,sz),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0},bub)
				corner(d,999)
				local bs=stroke(d,C.White,1.5,1)
				task.wait(rnd:NextNumber(0,2.5))
				while liveL() do
					local x=rnd:NextNumber(0.03,0.97)
					local dur=rnd:NextNumber(5,10)
					d.Position=UDim2.fromScale(x,1.06)
					d.BackgroundTransparency=1
					bs.Transparency=1
					tween(d,dur,{Position=UDim2.fromScale(x+rnd:NextNumber(-0.07,0.07),-0.08)},Enum.EasingStyle.Linear)
					tween(d,dur*0.2,{BackgroundTransparency=0.88})
					tween(bs,dur*0.2,{Transparency=rnd:NextNumber(0.3,0.6)})
					task.wait(dur*0.8)
					tween(d,dur*0.2,{BackgroundTransparency=1})
					tween(bs,dur*0.2,{Transparency=1})
					task.wait(dur*0.2)
				end
			end)
		end
	end

	-- 2) Synthwave: twinkling stars, rising striped sun, scrolling perspective neon grid
	BG[2]=function()
		local HZ=0.6
		for n=1,22 do
			task.spawn(function()
				local rnd=Random.new(n*71+9)
				local sz=rnd:NextInteger(2,3)
				local s=new("Frame",{Position=UDim2.fromScale(rnd:NextNumber(0.02,0.98),rnd:NextNumber(0.03,HZ-0.06)),Size=UDim2.fromOffset(sz,sz),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0},bd)
				new("UICorner",{CornerRadius=UDim.new(0.5,0)},s)
				task.wait(rnd:NextNumber(0,2))
				while liveL() do
					tween(s,rnd:NextNumber(0.6,1.2),{BackgroundTransparency=rnd:NextNumber(0.1,0.5)})
					task.wait(rnd:NextNumber(1,1.8))
					tween(s,rnd:NextNumber(0.6,1.2),{BackgroundTransparency=0.9})
					task.wait(rnd:NextNumber(1,1.8))
				end
			end)
		end
		local sunBox=new("Frame",{AnchorPoint=Vector2.new(0.5,1),Position=UDim2.fromScale(0.5,HZ+0.32),Size=UDim2.fromScale(1,0.5),BackgroundTransparency=1,BorderSizePixel=0},bd)
		new("UIAspectRatioConstraint",{AspectRatio=1,DominantAxis=Enum.DominantAxis.Height},sunBox)
		local halo=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromScale(1.8,1.8),BackgroundColor3=P.a1,BackgroundTransparency=0.93,BorderSizePixel=0},sunBox)
		new("UICorner",{CornerRadius=UDim.new(0.5,0)},halo)
		local halo2=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromScale(1.35,1.35),BackgroundColor3=P.a1,BackgroundTransparency=0.88,BorderSizePixel=0},sunBox)
		new("UICorner",{CornerRadius=UDim.new(0.5,0)},halo2)
		local sun=new("CanvasGroup",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0},sunBox)
		new("UICorner",{CornerRadius=UDim.new(0.5,0)},sun)
		local sunFill=new("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=C.White,BorderSizePixel=0},sun)
		new("UIGradient",{Color=ColorSequence.new(Color3.fromRGB(255,228,96),P.a1),Rotation=90},sunFill)
		local barCol=P.top:Lerp(P.bot,0.62)
		for k=1,6 do
			new("Frame",{Position=UDim2.fromScale(0,0.45+k*0.085),Size=UDim2.fromScale(1,0.008+0.009*k),BackgroundColor3=barCol,BorderSizePixel=0},sun)
		end
		tween(sunBox,1.8,{Position=UDim2.fromScale(0.5,HZ+0.1)},Enum.EasingStyle.Quint)

		local band=new("Frame",{AnchorPoint=Vector2.new(0.5,1),Position=UDim2.fromScale(0.5,HZ),Size=UDim2.fromScale(1,0.12),BackgroundColor3=P.a1,BorderSizePixel=0},bd)
		new("UIGradient",{Rotation=90,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,0.55)})},band)
		local floor=new("Frame",{Position=UDim2.fromScale(0,HZ),Size=UDim2.fromScale(1,1-HZ),BackgroundColor3=C.White,BorderSizePixel=0,ClipsDescendants=true},bd)
		new("UIGradient",{Color=ColorSequence.new(Color3.fromRGB(58,10,96),P.bot),Rotation=90},floor)
		local hl={}
		for k=1,9 do
			hl[k]=new("Frame",{AnchorPoint=Vector2.new(0.5,0),BackgroundColor3=P.a2,BorderSizePixel=0},floor)
		end
		local vl={}
		for k=-7,7 do
			local f=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),BackgroundColor3=P.a1,BorderSizePixel=0},floor)
			new("UIGradient",{Rotation=90,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(0.35,0.4),NumberSequenceKeypoint.new(1,0.1)})},f)
			vl[#vl+1]={f=f,k=k}
		end
		new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,HZ),Size=UDim2.new(1,0,0,2),BackgroundColor3=P.a2,BorderSizePixel=0},bd)
		local ph=0
		table.insert(upd,function(t,dt)
			local s=bd.AbsoluteSize
			local fw,fh=s.X,s.Y*(1-HZ)
			ph=ph+dt*(0.25+0.35*ctx.warp)
			for k,f in ipairs(hl) do
				local z=((k-1)/#hl+ph)%1
				local zz=z*z
				f.Position=UDim2.fromOffset(fw/2,zz*fh)
				f.Size=UDim2.fromOffset(fw,1+zz*3)
				f.BackgroundTransparency=1-math.min(zz*1.2,0.9)
			end
			for _,v in ipairs(vl) do
				local dx=v.k*fw*0.16
				local L=math.sqrt(dx*dx+fh*fh)
				v.f.Position=UDim2.fromOffset(fw/2+dx/2,fh/2)
				v.f.Size=UDim2.fromOffset(2,L)
				v.f.Rotation=-math.deg(math.atan2(dx,fh))
			end
		end)
	end

	-- 3) Matrix: falling code rain
	BG[3]=function()
		local rain=new("Frame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0,ClipsDescendants=true},bd)
		local NC=20
		local chars="01ABCDEFGHJKLMNPQRSTUVWXYZ$#%*+=?"
		for n=1,NC do
			task.spawn(function()
				local rnd=Random.new(n*89+17)
				local colx=(n-0.5)/NC
				local col=new("TextLabel",{AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(colx,0,0,-400),Size=UDim2.fromOffset(18,400),BackgroundTransparency=1,BorderSizePixel=0,Font=Enum.Font.Code,TextSize=15,TextColor3=P.a2,TextYAlignment=Enum.TextYAlignment.Bottom,TextXAlignment=Enum.TextXAlignment.Center,RichText=true,Text="",TextTruncate=Enum.TextTruncate.None,TextWrapped=false},rain)
				new("UIGradient",{Rotation=90,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(0.7,0.55),NumberSequenceKeypoint.new(1,0)})},col)
				task.wait(rnd:NextNumber(0,3))
				while liveL() do
					local len=rnd:NextInteger(8,20)
					local parts={}
					for k=1,len do
						local r=rnd:NextInteger(1,#chars)
						parts[k]=chars:sub(r,r)
					end
					parts[len]='<font color="rgb(220,255,230)">'..parts[len]..'</font>'
					col.Text=table.concat(parts,"\n")
					local sy=bd.AbsoluteSize.Y
					col.Position=UDim2.new(colx,0,0,-400)
					local dur=rnd:NextNumber(2.4,5)/(1+ctx.warp*0.8)
					tween(col,dur,{Position=UDim2.new(colx,0,0,sy+20)},Enum.EasingStyle.Linear)
					task.wait(dur+rnd:NextNumber(0,1.2))
				end
			end)
		end
	end

	-- 4) Hyperspace: radial warp stars + drifting nebula
	BG[4]=function()
		local nebs={{0.22,0.3,P.a2},{0.8,0.7,P.a1},{0.62,0.18,P.a2}}
		for k,nb in ipairs(nebs) do
			local g=softGlow(bd,UDim2.fromScale(nb[1],nb[2]),560,nb[3],0.94)
			TS:Create(g,TweenInfo.new(5+k*1.5,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{Position=UDim2.fromScale(nb[1]+0.08,nb[2]-0.06)}):Play()
		end
		local sf=new("Frame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0,ClipsDescendants=true},bd)
		local rs=Random.new(4242)
		local stars={}
		for k=1,44 do
			local f=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),BackgroundColor3=(k%3==0) and P.a2 or C.White,BorderSizePixel=0,Visible=false},sf)
			stars[k]={f=f,a=rs:NextNumber(0,math.pi*2),r=rs:NextNumber(10,700),v=rs:NextNumber(0.6,1.4)}
		end
		table.insert(upd,function(t,dt)
			local s=bd.AbsoluteSize
			local rmax=math.sqrt(s.X*s.X+s.Y*s.Y)/2+60
			local sp=1+ctx.warp*2.2
			for _,st in ipairs(stars) do
				st.r=st.r+dt*st.v*(60+st.r*1.6)*sp*0.55
				if st.r>rmax then
					st.r=rs:NextNumber(6,30)
					st.a=rs:NextNumber(0,math.pi*2)
					st.v=rs:NextNumber(0.6,1.4)
				end
				st.f.Visible=true
				st.f.Position=UDim2.new(0.5,math.cos(st.a)*st.r,0.5,math.sin(st.a)*st.r+ctx.oy)
				st.f.Size=UDim2.fromOffset(3+st.r*0.12*sp,2)
				st.f.Rotation=math.deg(st.a)
				st.f.BackgroundTransparency=math.clamp(1-st.r/200,0,1)
			end
		end)
	end

	-- 5) Aurora: glowing blobs, waving curtains, drifting sparkles (+ glass card behind the logo)
	BG[5]=function()
		local blobs={{0.2,0.25,640,P.a1},{0.8,0.3,700,P.a2},{0.5,0.85,760,P.a1},{0.15,0.8,560,P.a2}}
		for k,b in ipairs(blobs) do
			local g=softGlow(bd,UDim2.fromScale(b[1],b[2]),b[3],b[4],0.94)
			local dir=(k%2==0) and 1 or -1
			TS:Create(g,TweenInfo.new(6+k*1.7,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{Position=UDim2.fromScale(b[1]+0.1*dir,b[2]-0.08)}):Play()
		end
		for k=1,7 do
			local x=0.08+k*0.12
			local dir=(k%2==0) and 1 or -1
			local r=new("Frame",{AnchorPoint=Vector2.new(0.5,0),Position=UDim2.fromScale(x,0),Size=UDim2.new(0,46,0.7,0),BackgroundColor3=(k%2==0) and P.a1 or P.a2,BorderSizePixel=0},bd)
			new("UIGradient",{Rotation=90,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(0.45,0.88),NumberSequenceKeypoint.new(1,1)})},r)
			TS:Create(r,TweenInfo.new(4+k*0.9,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{Position=UDim2.fromScale(x+0.05*dir,0),Size=UDim2.new(0,90+k*8,0.7,0)}):Play()
		end
		for n=1,16 do
			task.spawn(function()
				local rnd=Random.new(n*61+13)
				local sz=rnd:NextInteger(2,5)
				local d=new("Frame",{Size=UDim2.fromOffset(sz,sz),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0},bd)
				new("UICorner",{CornerRadius=UDim.new(0.5,0)},d)
				task.wait(rnd:NextNumber(0,3))
				while liveL() do
					local x=rnd:NextNumber(0.03,0.97)
					local dur=rnd:NextNumber(6,11)
					d.Position=UDim2.fromScale(x,1.03)
					d.BackgroundTransparency=1
					tween(d,dur,{Position=UDim2.fromScale(x+rnd:NextNumber(-0.05,0.05),-0.03)},Enum.EasingStyle.Linear)
					tween(d,dur*0.25,{BackgroundTransparency=rnd:NextNumber(0.3,0.6)})
					task.wait(dur*0.75)
					tween(d,dur*0.25,{BackgroundTransparency=1})
					task.wait(dur*0.25)
				end
			end)
		end
	end

	local okB,errB=pcall(BG[sid])
	if not okB then warn("[NeonFly] loader background error: "..tostring(errB)) end

	---------------- HUD corner brackets + corner text ----------------
	local brackets,cornerTxt={},{}
	local function bracket(ax,ay)
		local h=new("Frame",{AnchorPoint=Vector2.new(ax,ay),Position=UDim2.new(ax,ax==0 and 20 or -20,ay,ay==0 and 20 or -20),Size=UDim2.fromOffset(0,0),BackgroundTransparency=1,BorderSizePixel=0},bd)
		new("Frame",{AnchorPoint=Vector2.new(ax,ay),Position=UDim2.fromScale(ax,ay),Size=UDim2.new(1,0,0,3),BackgroundColor3=P.a1,BorderSizePixel=0},h)
		new("Frame",{AnchorPoint=Vector2.new(ax,ay),Position=UDim2.fromScale(ax,ay),Size=UDim2.new(0,3,1,0),BackgroundColor3=P.a1,BorderSizePixel=0},h)
		table.insert(brackets,h)
	end
	bracket(0,0) bracket(1,0) bracket(0,1) bracket(1,1)
	local function cornerText(ax,ay,txt)
		local l=label({AnchorPoint=Vector2.new(ax,ay),Position=UDim2.new(ax,ax==0 and 62 or -62,ay,ay==0 and 19 or -19),Size=UDim2.fromOffset(170,14),Text=txt,TextSize=11,Font=ST.term and Enum.Font.Code or Enum.Font.GothamBold,TextColor3=P.soft,TextTransparency=1,TextXAlignment=(ax==0) and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right},bd)
		table.insert(cornerTxt,l)
		return l
	end
	cornerText(0,0,"Xyclop Ultimate")
	cornerText(1,0,"v2.6")
	cornerText(0,1,"Code_Name_Xyclop")
	local stageLbl=cornerText(1,1,"00 / 04")

	---------------- center stage (auto-scales to the screen) ----------------
	local EY=125
	local fit=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(360,450),BackgroundTransparency=1,BorderSizePixel=0},bd)
	local sc=new("UIScale",{Scale=1},fit)

	if ST.glass then
		local gp=new("Frame",{AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0,0),Size=UDim2.fromOffset(340,450),BackgroundColor3=C.White,BackgroundTransparency=0.92,BorderSizePixel=0},fit)
		corner(gp,26)
		stroke(gp,C.White,1.5,0.7)
	end

	local rays,wm
	if ST.rays then
		rays=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0,EY),Size=UDim2.fromOffset(2600,2600),BackgroundTransparency=1,BorderSizePixel=0},fit)
		local rw={70,120,46,96,60,140}
		for k=0,5 do
			local r=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(rw[k+1],2600),Rotation=k*30,BackgroundColor3=C.White,BorderSizePixel=0},rays)
			new("UIGradient",{Rotation=90,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(0.5,0.84),NumberSequenceKeypoint.new(1,1)})},r)
		end
	end
	local gcol=(sid==1) and C.White or P.a1
	local glows={}
	for k,d in ipairs({1000,760,560,400,290}) do
		local g=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0,EY),Size=UDim2.fromOffset(d,d),BackgroundColor3=gcol,BackgroundTransparency=0.94-k*0.01,BorderSizePixel=0},fit)
		corner(g,999)
		glows[k]={f=g,d=d}
	end
	if ST.rays then
		wm=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0,EY),Size=UDim2.fromOffset(520,520),BackgroundTransparency=1,BorderSizePixel=0},fit)
		local _,wmParts=makeXMark(wm,"neon",P)
		for _,p in ipairs(wmParts) do p.f.BackgroundTransparency=0.9 end
	end

	local E=makeEmblem(fit,210,UDim2.new(0.5,0,0,EY),P)

	local col1,col2
	if sid==1 then
		col1=function() return C.White end
		col2=function() return P.soft end
	elseif sid==3 then
		col1=function() return P.a1 end
		col2=function() return P.a2 end
	elseif sid==4 then
		col1=function(i,n) return C.White:Lerp(P.a1,(i-1)/math.max(n-1,1)) end
		col2=function() return P.a1 end
	else
		col1=function(i,n) return P.a1:Lerp(P.a2,(i-1)/math.max(n-1,1)) end
		col2=function() return P.soft end
	end
	local tfont=ST.term and Enum.Font.Code or Enum.Font.GothamBlack
	local L1=makeLetters(fit,"XYCLOP",46,tfont,240,6,col1,360,P.deep,true)
	local L2=makeLetters(fit,"ULTIMATE",15,ST.term and Enum.Font.Code or Enum.Font.GothamBold,298,11,col2,360,P.deep,true)

	local status=label({AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0,336),Size=UDim2.fromOffset(360,18),Text="",TextSize=14,Font=ST.term and Enum.Font.Code or Enum.Font.GothamBold,TextColor3=C.White,TextTransparency=1},fit)
	tstroke(status,P.deep,2)

	---------------- progress bar (pill / segments / ascii) ----------------
	local kind=ST.bar
	local BARW=320
	local NSEG=20
	local barTrack,barStroke,barFill,head,asciiLbl,pct
	local segs={}
	if kind=="seg" then
		barTrack=new("Frame",{AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0,364),Size=UDim2.fromOffset(BARW,14),BackgroundTransparency=1,BorderSizePixel=0,Visible=false},fit)
		new("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,4),SortOrder=Enum.SortOrder.LayoutOrder},barTrack)
		local sw=(BARW-(NSEG-1)*4)/NSEG
		for k=1,NSEG do
			local s=new("Frame",{LayoutOrder=k,Size=UDim2.fromOffset(sw,14),BackgroundColor3=P.a1:Lerp(P.a2,(k-1)/(NSEG-1)),BackgroundTransparency=0.88,BorderSizePixel=0},barTrack)
			corner(s,3)
			segs[k]=s
		end
	elseif kind=="ascii" then
		asciiLbl=label({AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0,360),Size=UDim2.fromOffset(360,22),Text="",TextSize=15,Font=Enum.Font.Code,TextColor3=P.a1,TextTransparency=1,TextTruncate=Enum.TextTruncate.None},fit)
	else
		local BH=(sid==1) and 14 or 6
		barTrack=new("Frame",{AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0,(sid==1) and 364 or 368),Size=UDim2.fromOffset(BARW,BH),BackgroundColor3=P.deep,BackgroundTransparency=1,BorderSizePixel=0},fit)
		corner(barTrack,999)
		barStroke=stroke(barTrack,C.White,1.5,1)
		barFill=new("Frame",{Size=UDim2.fromScale(0,1),BackgroundColor3=C.White,BorderSizePixel=0,ClipsDescendants=true},barTrack)
		corner(barFill,999)
		new("UIGradient",{Color=ColorSequence.new(P.a2,P.a1)},barFill)
		local strip=new("Frame",{Position=UDim2.new(0,-60,0,0),Size=UDim2.new(0,50,1,0),BackgroundColor3=C.White,BorderSizePixel=0},barFill)
		new("UIGradient",{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(0.5,0.1),NumberSequenceKeypoint.new(1,1)})},strip)
		TS:Create(strip,TweenInfo.new(1.1,Enum.EasingStyle.Linear,Enum.EasingDirection.Out,-1),{Position=UDim2.new(1,10,0,0)}):Play()
		head=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0,0,0.5,0),Size=UDim2.fromOffset(BH*2+2,BH*2+2),BackgroundColor3=P.a1,BackgroundTransparency=0.65,BorderSizePixel=0,Visible=false},barTrack)
		corner(head,999)
		local headDot=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(BH-2,BH-2),BackgroundColor3=C.White,BorderSizePixel=0},head)
		corner(headDot,999)
	end
	if kind~="ascii" then
		pct=label({AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0,386),Size=UDim2.fromOffset(160,30),Text="0%",TextSize=24,Font=Enum.Font.GothamBlack,TextColor3=C.White,TextTransparency=1},fit)
		tstroke(pct,P.deep,2.5)
	end
	local function showBar()
		if kind=="seg" then
			barTrack.Visible=true
		elseif kind=="ascii" then
			tween(asciiLbl,0.4,{TextTransparency=0})
		else
			tween(barTrack,0.4,{BackgroundTransparency=0.45})
			tween(barStroke,0.4,{Transparency=0.5})
		end
		if pct then fade(pct,0.4,0) end
	end

	local tip=label({AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0,424),Size=UDim2.fromOffset(360,26),Text="",TextSize=12,Font=Enum.Font.GothamBold,TextColor3=P.soft,TextWrapped=true,TextTransparency=1},fit)
	tstroke(tip,P.deep,1.5)
	task.spawn(function()
		local n=1
		while liveL() do
			tip.Text="✦  "..tr("tip"..n)
			fade(tip,0.35,0)
			task.wait(2.2)
			fade(tip,0.35,1)
			task.wait(0.4)
			n=n%8+1
		end
	end)

	local flash=new("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=50},bd)

	---------------- per-frame driver ----------------
	local barOn=false
	local bob=false
	local shown,target=0,0
	local zoom,zoomT=1,1
	local t0=os.clock()
	local lc=connect(RunService.RenderStepped,function(dt)
		local t=os.clock()-t0
		local s=screenSize()
		local fs=math.clamp(math.min(s.X/430,s.Y/490),0.45,1.35)
		zoom=zoom+(zoomT-zoom)*math.min(1,dt*7)
		sc.Scale=fs*zoom
		ctx.oy=(EY-225)*sc.Scale
		E.update(t)
		if rays then rays.Rotation=(t*5)%360 end
		if wm then wm.Rotation=(t*3)%360 end
		for k,g in ipairs(glows) do
			local d=g.d*(1+0.035*math.sin(t*1.7+k))
			g.f.Size=UDim2.fromOffset(d,d)
		end
		if bob then
			for i,l in ipairs(L1) do
				l.Position=UDim2.fromOffset(0,math.sin(t*3+i*0.7)*3)
			end
		end
		for i=#upd,1,-1 do
			local okU,eU=pcall(upd[i],t,dt)
			if not okU then
				warn("[NeonFly] loader fx error: "..tostring(eU))
				table.remove(upd,i)
			end
		end
		shown=shown+(target-shown)*math.min(1,dt*4)
		if barOn then
			local f=math.clamp(shown,0,1)
			if kind=="seg" then
				for k,sg in ipairs(segs) do
					local a=math.clamp(f*NSEG-(k-1),0,1)
					sg.BackgroundTransparency=0.88-0.88*a
				end
			elseif kind=="ascii" then
				local nb=math.floor(f*24+0.5)
				asciiLbl.Text="["..string.rep("#",nb)..string.rep("-",24-nb).."]  "..math.floor(f*100+0.5).."%"
			else
				barFill.Size=UDim2.fromScale(f,1)
				head.Position=UDim2.new(f,0,0.5,0)
				head.Visible=f>0.01
				head.BackgroundTransparency=0.65+0.12*math.sin(t*8)
			end
			if pct then pct.Text=math.floor(f*100+0.5).."%" end
		end
	end)
	loadConn=lc

	local function setStatus(txt)
		if ST.term then txt="> "..string.upper(txt).."_" end
		fade(status,0.12,1)
		task.delay(0.12,function()
			if not alive or not status.Parent then return end
			status.Text=txt
			fade(status,0.22,0)
		end)
	end
	local function setStage(n,tg,wp)
		target=tg
		ctx.warp=wp
		stageLbl.Text=string.format("%02d / 04",n)
		setStatus(tr("ld"..n))
		if n>1 then sfx("tick",0.35,0.8+n*0.15) end
	end

	---------------- title reveal (different per style) ----------------
	local SCR="01ABCDEFGHJKLMNPQRSTUVWXYZ$#%*+=?"
	local function revealLetters(list,step,pitch,mode)
		for i,l in ipairs(list) do
			task.delay((i-1)*step,function()
				if not alive or not l.Parent then return end
				local ls=l:FindFirstChildOfClass("UIStroke")
				sfx("tick",0.25,pitch+i*0.09)
				if mode=="flicker" then
					l.Position=UDim2.fromOffset(0,0)
					for k=1,6 do
						l.TextTransparency=(k%2==1) and 0.65 or 0
						if ls then ls.Transparency=(k%2==1) and 0.9 or 0.35 end
						task.wait(0.05)
						if not l.Parent then return end
					end
					l.TextTransparency=0
					if ls then ls.Transparency=0.35 end
				elseif mode=="scramble" then
					local final=l.Text
					l.Position=UDim2.fromOffset(0,0)
					l.TextTransparency=0
					if ls then ls.Transparency=0.35 end
					for k=1,8 do
						local r=math.random(1,#SCR)
						l.Text=SCR:sub(r,r)
						task.wait(0.05)
						if not l.Parent then return end
					end
					l.Text=final
				else
					local slow=(mode=="slow")
					tween(l,slow and 0.8 or 0.45,{Position=UDim2.fromOffset(0,0),TextTransparency=0},slow and Enum.EasingStyle.Quint or Enum.EasingStyle.Back)
					if ls then tween(ls,0.45,{Transparency=0.35}) end
				end
			end)
		end
	end
	local function spreadTitle()
		local lay=L1[1].Parent.Parent:FindFirstChildOfClass("UIListLayout")
		if lay then
			lay.Padding=UDim.new(0,40)
			if not pcall(function() tween(lay,1.1,{Padding=UDim.new(0,6)},Enum.EasingStyle.Quint) end) then
				lay.Padding=UDim.new(0,6)
			end
		end
		for _,l in ipairs(L1) do
			l.Position=UDim2.fromOffset(0,0)
			local ls=l:FindFirstChildOfClass("UIStroke")
			tween(l,0.9,{TextTransparency=0})
			if ls then tween(ls,0.9,{Transparency=0.35}) end
		end
		sfx("whoosh",0.3,1.4)
	end
	local function revealTitle()
		if sid==2 then revealLetters(L1,0.1,0.7,"flicker")
		elseif sid==3 then revealLetters(L1,0.12,0.7,"scramble")
		elseif sid==4 then spreadTitle()
		elseif sid==5 then revealLetters(L1,0.1,0.7,"slow")
		else revealLetters(L1,0.07,0.7,"rise") end
		task.delay(sid==5 and 1.7 or 0.95,function() bob=(sid==1 or sid==5) end)
	end

	---------------- timeline ----------------
	wt(0.35)
	for _,b in ipairs(brackets) do tween(b,0.8,{Size=UDim2.fromOffset(34,34)},Enum.EasingStyle.Quint) end
	for _,l in ipairs(cornerTxt) do tween(l,0.6,{TextTransparency=0}) end
	sfx("tick",0.3,0.6)
	wt(0.25)

	sfx("whoosh",0.35,1.7)
	E.intro()
	wt(0.35)
	sfx("ping",0.3,0.8)
	shockwave(E.root,UDim2.fromScale(0.5,0.5),90,380,3,1.0,0,P)
	task.spawn(function()
		task.wait(0.6)
		while liveL() do
			shockwave(fit,UDim2.new(0.5,0,0,EY),120,460,2,1.8,0,P,0.55)
			task.wait(1.2)
		end
	end)
	wt(0.55)

	revealTitle()
	wt(0.5)
	revealLetters(L2,0.045,1.2,(sid==3) and "scramble" or "rise")
	wt(0.3)
	shimmerLetters(L1,col1,P.a2)

	barOn=true
	showBar()
	wt(0.35)

	setStage(1,0.22,0.3)
	wt(0.6)

	setStage(2,0.55,0.7)
	local list={}
	for _,s in pairs(sounds) do table.insert(list,s) end
	local done=preview and true or false
	if not preview then
		task.spawn(function()
			pcall(function() CP:PreloadAsync(list) end)
			done=true
		end)
	end
	wt(0.7)
	local tp=os.clock()
	while alive and not done and os.clock()-tp<4 do task.wait(0.05) end

	setStage(3,0.82,1.2)
	wt(0.6)

	setStage(4,1,2)
	wt(0.5)

	-- finale
	shown=1 target=1
	wt(0.15)
	flash.BackgroundTransparency=0.35
	tween(flash,0.7,{BackgroundTransparency=1})
	shockwave(E.root,UDim2.fromScale(0.5,0.5),150,700,4,1.0,0,P)
	shockwave(E.root,UDim2.fromScale(0.5,0.5),120,980,2,1.3,0.1,P)
	burst(fit,UDim2.new(0.5,0,0,EY),26,P,260)
	shimmerLetters(L1,col1,P.a2)
	sfx("ping",0.45,1.0)
	task.delay(0.1,function() sfx("ping",0.4,1.26) end)
	task.delay(0.2,function() sfx("ping",0.45,1.5) end)
	zoomT=1.06
	wt(0.7)

	reveal()
	zoomT=1.5
	sfx("whoosh",0.4,1.2)
	tween(bd,0.7,{GroupTransparency=1})
	if blurFx then tween(blurFx,0.7,{Size=0}) end
	task.wait(0.75)
	lc:Disconnect()
	loadConn=nil
	lg:Destroy()
	loadGui=nil
	if blurFx then blurFx:Destroy() blurFx=nil end
end

local okL,errL=pcall(runLoader,loaderStyle,false)
if not okL then
	warn("[NeonFly] loader error: "..tostring(errL))
	if loadConn then loadConn:Disconnect() loadConn=nil end
	if loadGui then loadGui:Destroy() loadGui=nil end
	if blurFx then blurFx:Destroy() blurFx=nil end
	if loaderStyle~=1 and alive then
		okL,errL=pcall(runLoader,1,false)
		if not okL then warn("[NeonFly] fallback loader error: "..tostring(errL)) end
	end
end
if loadConn then loadConn:Disconnect() loadConn=nil end
if loadGui then loadGui:Destroy() loadGui=nil end
if blurFx then blurFx:Destroy() blurFx=nil end
reveal()
