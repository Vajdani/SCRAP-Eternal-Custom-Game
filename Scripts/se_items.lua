--Projectiles
grn_grenade = sm.uuid.new("c951da10-4f23-4321-84e9-1dd77d2a2d58")
grn_icebomb = sm.uuid.new("239765a7-217d-4c52-8b32-a8fdd984080b")
grn_imploGrenade = sm.uuid.new("117929a6-1394-421f-91ff-cf89d1e20c4f")

--Terrain
trn_boostpad = sm.uuid.new("450639d7-5a77-4900-8c49-a61314bc589b")
trn_monkeybar = sm.uuid.new("539e2ec8-cc49-484c-9d88-6e1cc6bbddc4")
trn_wallclimb_1 = sm.uuid.new("1c16ae84-26e6-4bf5-b4be-dc45448e0b89")
trn_wallclimb_2 = sm.uuid.new("3bbe152e-3658-442d-95c7-35e17d48affb")

--Tools
wpn_supershotgun = sm.uuid.new("8378e3ed-ded9-4a64-9887-76c3b295bc86")
wpn_ballista = sm.uuid.new("465b2e4e-e9ff-42bc-aab1-f256663d1c31")
wpn_plasmarifle = sm.uuid.new("b17f2fa7-1f04-40b5-8f9d-65a40bbf45c0")
wpn_rocketlauncher = sm.uuid.new("25417b29-546d-4a9d-9766-f6e0d3b82f0f")
wpn_bfg = sm.uuid.new("2cc2e981-4261-443b-b925-051ea94707ab")
wpn_unmaykr = sm.uuid.new("30baecf1-d083-4785-932c-4f2272494b5a")

g_allWeapons = {
    --the threat level of a weapon:
        --has the gun: player's threat level + gun's threat level
        --has the gun and mod 1 or mod 2: player's threat level + gun's threat level * 2
        --has the gun and both of the mods: player's threat level + gun's threat level * 3
    moddables = {
        { uuid = tool_sledgehammer, name = "Hammer", tableName = "hammer", threat = 0.5 },
        { uuid = tool_shotgun, name = "Combat Shotgun", tableName = "shotgun", threat = 4 },
        { uuid = tool_spudgun, name = "Heavy Cannon", tableName = "hcannon", threat = 4 },
        { uuid = wpn_plasmarifle, name = "Plasma Rifle", tableName = "plasma", threat = 4 },
        { uuid = wpn_rocketlauncher, name = "Rocket Launcher", tableName = "rocket", threat = 6 },
        { uuid = wpn_supershotgun, name = "Super Shotgun", tableName = "ssg", threat = 5 },
        { uuid = wpn_ballista, name = "Ballista", tableName = "ballista", threat = 5 },
        { uuid = tool_gatling, name = "Chaingun", tableName = "chaingun", threat = 5 }
    },
    upgradeStation = {
        { uuid = tool_shotgun, name = "Combat Shotgun", tableName = "shotgun", threat = 4 },
        { uuid = tool_spudgun, name = "Heavy Cannon", tableName = "hcannon", threat = 4 },
        { uuid = wpn_plasmarifle, name = "Plasma Rifle", tableName = "plasma", threat = 4 },
        { uuid = wpn_rocketlauncher, name = "Rocket Launcher", tableName = "rocket", threat = 6 },
        { uuid = wpn_supershotgun, name = "Super Shotgun", tableName = "ssg", threat = 5 },
        { uuid = wpn_ballista, name = "Ballista", tableName = "ballista", threat = 5 },
        { uuid = tool_gatling, name = "Chaingun", tableName = "chaingun", threat = 5 }
    },
    super = {
        { uuid = wpn_bfg, name = "BFG - 9000", tableName = "bfg", threat = 25 },
        { uuid = wpn_unmaykr, name = "Unmaykr", tableName = "unmaykr", threat = 25 }
    }
}

--ammo
se_ammo_plasma = sm.uuid.new("37051f7f-1661-4bd7-9f24-d61bd602616d")
se_ammo_argent = sm.uuid.new("72db5fe7-cda0-45a6-a175-3a46ba0cd150")
se_ammo_shells = sm.uuid.new("42cae6ca-b5fb-4869-8000-260d63eb1d2c")
se_ammo_rocket = sm.uuid.new("af1f3a89-7428-42af-9382-79337f60c25b")

--consumables
prp_berserk = sm.uuid.new("9b89e4b2-b3b2-4031-8d20-a2e3f48d3a1e")
prp_haste = sm.uuid.new("31e9b738-8825-4d2d-9ae6-325587d1d102")
prp_quad = sm.uuid.new("c6111b61-9618-412f-bcbf-12a9df4cc5bd")
prp_all = sm.uuid.new("d5253e09-9092-4d4d-b5f1-fa9ea729ba84")

--droplets
hvs_remains_hammer = sm.uuid.new( "9e6c698f-d316-45a1-96fa-edb080e50ea8" )
drop_health = sm.uuid.new("9e73c859-5fa8-4ece-9ddc-39e39ba27c24")
drop_armour = sm.uuid.new("90c551bb-1378-408a-9a85-c3af3c6d1ec3")
drop_ammo = sm.uuid.new("7ebe5d3b-10f8-4c80-b725-65fc7a30df4e")
drop_hammer = sm.uuid.new("")

--projectiles
proj_pb = sm.uuid.new("5e41cb04-c26a-4440-94bb-c47c0c687bdd")
proj_csg = sm.uuid.new("ef1319ec-1d3d-417f-8014-48f16b4e333c")
proj_ssg = sm.uuid.new("f80ca98f-87f4-4963-a043-e711718bbabe")
proj_ballista = sm.uuid.new("8d32d7e2-c079-4a03-b6b7-086695413ccd")
proj_plasma = sm.uuid.new("23ddb1c6-326d-4515-b083-2d0b8f554f04")
proj_unmaykr = sm.uuid.new("5f033768-d419-481b-aeb6-e0038d743fdb")
proj_health = sm.uuid.new("fea0e388-8a29-44f1-aee3-f9110780ee82")
proj_armour = sm.uuid.new("59648271-ad12-475d-b72d-456d2cb7aa52")
proj_ammo = sm.uuid.new("56c3d9b5-7736-4c64-8714-7a64dd7911cc")

--scripted projectiles
--= sm.uuid.new("")
proj_bfgBall_sob = sm.uuid.new("5b4592b8-89a4-49a1-8558-2ac9f603c219")
proj_rocket_sob = sm.uuid.new("59b7e8a7-e633-4d8d-8873-4bd7ce021be4")
proj_arbalest_sob = sm.uuid.new("b65a6025-fb6e-4341-b18f-128102e11cfc")
proj_blade_sob = sm.uuid.new("1dcf8c1c-fae1-41a0-b90f-9f64cb362544")
proj_shield_sob = sm.uuid.new("bc2a2db6-6d0e-405b-bd70-4afb559552b4")

--gui
gui_runes = {
    {
        name = "Dazed and Confused",
        icon = "$CONTENT_DATA/Gui/PlayerUpgradesBot/icon_rune_dazed.png",
        desc = "Extends the duration of glory kill stuns."
    },
    {
        name = "Seek and Destroy",
        icon = "$CONTENT_DATA/Gui/PlayerUpgradesBot/icon_rune_seek.png",
        desc = "Extends glory kill range."
    },
    {
        name = "Saving Throw",
        icon = "$CONTENT_DATA/Gui/PlayerUpgradesBot/icon_rune_saving.png",
        desc = "Allows you to die once. Recharges every\n3 in game days."
    },
    {
        name = "Equipment Fiend",
        icon = "$CONTENT_DATA/Gui/PlayerUpgradesBot/icon_rune_equipment.png",
        desc = "If an enemy dies to your equipment, that\nspecific equipment'scooldown will get\nreduced until it recharges."
    },
    {
        name = "Blood Fueled",
        icon = "$CONTENT_DATA/Gui/PlayerUpgradesBot/icon_rune_blood.png",
        desc = "A speed boost gets applied to the\nplayer after performing a glory kill."
    },
    {
        name = "Air Control",
        icon = "$CONTENT_DATA/Gui/PlayerUpgradesBot/icon_rune_mobility.png",
        desc = "Gives you more control over your\nmovement while in the air."
    },
    {
        name = "Punch and Weave",
        icon = "$CONTENT_DATA/Gui/PlayerUpgradesBot/icon_rune_bloodpunch.png",
        desc = "Enemies drop more health after\ndying to a blood punch."
    },
    {
        name = "Chrono Strike",
        icon = "$CONTENT_DATA/Gui/PlayerUpgradesBot/icon_rune_target.png",
        desc = "Holding right click with a few\nweapons will make you glide\nin the air."
    },
    {
        name = "Savagery",
        icon = "$CONTENT_DATA/Gui/PlayerUpgradesBot/icon_rune_savagery.png",
        desc = "Perform glory kills faster."
    }
}