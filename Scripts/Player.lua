Player = class( nil )

dofile "$CONTENT_DATA/Scripts/se_util.lua"
dofile "$CONTENT_DATA/Scripts/se_items.lua"
dofile "$SURVIVAL_DATA/Scripts/game/util/Timer.lua"


function Player.server_onCreate( self )
	self.sv = {}
	self:sv_init()

	self.sv.statsTimer = Timer()
	self.sv.statsTimer:start( 40 )

	self.sv.mmOpTimer = Timer()
	self.sv.dmgMultTimer = Timer()
	self.sv.spdMultTimer = Timer()
	self.sv.berserkTimer = Timer()
	self.sv.mmOpTimer:start(mmOPDuration)
	self.sv.dmgMultTimer:start(defaultPrpDuration)
	self.sv.spdMultTimer:start(defaultPrpDuration)
	self.sv.berserkTimer:start(defaultPrpDuration)

	--Glory Kill
	self.sv.gk = {
		anim = nil,
		duration = 0,
		timerEnd = 0,
		timer = 0,
		target = nil,
		range = 5
	}

	--Vault
	self.sv.vaultCount = 1

	--General grenade stuff
	self.sv.generalGrenade = {
		canThrow = true,
		throwTimer = Timer(),
		index = 1,
		current = grenades[1].throwable
	}
	self.sv.generalGrenade.throwTimer:start(grenadeThrowCoolDown)

	--Frag
	self.sv.grenade = {
		recharge = 0,
		rechargeMax = 10
	}

	--Ice
	self.sv.ice = {
		recharge = 0,
		rechargeMax = 10
	}

	--Flamethrower
	self.sv.flame = {
		recharge = 0,
		rechargeMax = 10,
		firingDuration = 2,
		active = false,
		trigger = nil
	}

	--Dash
	self.sv.dash = {
		inputCDCount = 0.25,
		inputCD = false,
		keys = { nil, nil },
		dir = sm.vec3.zero(),
		canDash = true,
		count = 2,
		useCD = 0.5,
		recharge = 0
	}

	--Double jump
	self.sv.jumpCount = 2
	self.sv.jumpChargeCheck = 0.1

	--Runes

	--Blood Fueled
	self.sv.bloodFueled = false
	self.sv.bloodFueledTimer = Timer( bloodFueledDuration )

	--Chrono Strike
	self.sv.gliding = false

	self.sv.punch = false
	self.sv.punchTimer = Timer()
	self.sv.punchTimer:start(punchDuration)

	self.player:setPublicData(
		{
			data = self:sv_createNewWPData(),
			stats = {
				health = 100, maxhealth = 200,
				armour = 0, maxarmour = 150
			},
			input = {
				[sm.interactable.actions.forward] = false,
				[sm.interactable.actions.backward] = false,
				[sm.interactable.actions.left] = false,
				[sm.interactable.actions.right] = false,
				[sm.interactable.actions.jump] = false,
				[sm.interactable.actions.use] = false,
				[sm.interactable.actions.zoomIn] = false,
				[sm.interactable.actions.zoomOut] = false,
				[sm.interactable.actions.attack] = false,
				[sm.interactable.actions.create] = false
			}
		}
	)

	self.sv.public = self.player:getPublicData()

	self.network:setClientData( self.sv.public )
end

function Player:sv_createNewWPData()
	local data = {
		currentWpnData = {
			mod = "none",
			using = false,
			ammo = 0,
			recharge = 0
		},
		playerData = {
			kills = {
				hay = 0,
				tote = 0,
				tape = 0,
				farm = 0
			},
			xp = 0,
			masteryXp = 0,
			damage = 0,
			upgradePoints = 100,
			masteryPoints = 100,
			suitPoints = 100,
			extraLives = 100,
			damageMultiplier = 1,
			speedMultiplier = 1,
			berserk = false,
			isInvincible = false,
			gkState = false,
			meathookAttached = false,
			hammerCharge = 0,
			mmOP = false,
			isOnWall = false
		},
		suitData = {
			statUpgrades = {
				health = 4,
				armor = 4,
				ammo = 4
			},
			upgrades = {

			},
			runes = {
				runes = {
					{
						name = "Dazed and Confused",
						owned = true,
						buff = {
							gkDurationMult = 2
						}
					},
					{
						name = "Seek and Destroy",
						owned = true,
						buff = {
							rangeMult = 3
						}
					},
					{
						name = "Saving Throw",
						owned = true,
						charge = 1,
						buff = {
							survive = true
						}
					},
					{
						name = "Equipment Fiend",
						owned = true,
						buff = {
							cdReduction = 0.85
						}
					},
					{
						name = "Blood Fueled",
						owned = true,
						buff = {
							boost = true
						}
					},
					{
						name = "Air Control",
						owned = true,
						buff = {
							control = true
						}
					},
					{
						name = "Punch and Weave",
						owned = true,
						buff = {
							dropMultiplier = 2
						}
					},
					{
						name = "Chrono Strike",
						owned = true,
						buff = {
							glide = true
						}
					},
					{
						name = "Savagery",
						owned = true,
						buff = {
							gkSpeedMultiplier = 5
						}
					}
				},
				equipped = {}
			},
			bloodpunch = {
				owned = true,
				charges = 2
			},
			launcher = {
				grenade = {
					charges = 2,
					upgrades = {
						
					}
				},
				icebomb = {
					charges = 1,
					upgrades = {
						
					}
				},
				flamethrower = {
					charges = 1,
					upgrades = {
						
					}
				}
			},
			chainsaw = {
				owned = true,
				charges = 3
			}
		},
		weaponData = {
			hammer = {
				uuid = tool_sledgehammer,
				tip = "hammer tip",
				ammo = "thirst",
				mod1 = {
					name = "Slam",
					owned = true,
					icon = "$CONTENT_DATA/Gui/UpgradeStation/icon_mod_stickybomb.png",
					tip = "slam tip",
					up1 = {
						owned = true
					},
					up2 = {
						owned = true
					},
					up3 = {
						owned = true
					}
				}
			},
			shotgun = {
				uuid = tool_shotgun,
				tip = "shotgun tip",
				ammo = "Shells",
				mod1 = {
					name = "Sticky Bombs",
					owned = true,
					icon = "$CONTENT_DATA/Gui/UpgradeStation/icon_mod_stickybomb.png",
					tip = "sticky bomb tip",
					up1 = {
						name = "Quick Rack",
						desc = "quick rack desc",
						cost = 3,
						owned = true
					},
					up2 = {
						name = "Bigger Boom",
						desc = "bigger boom desc",
						cost = 6,
						owned = true
					},
					mastery = {
						name = "Five Spot",
						icon = "$CONTENT_DATA/Gui/UpgradeStation/icon_mastery_bonus_ammo.png",
						desc = "sticky bomb mastery",
						challenge = "Destroy 25 Arachnotron\nturrets with the modi-\nfication.",
						challengeIcon = "$CONTENT_DATA/Gui/UpgradeStation/shotgun_5spots.png",
						progress = 0,
						max = 25,
						owned = true
					}
				},
				mod2 = {
					name = "Full Auto",
					owned = true,
					icon = "$CONTENT_DATA/Gui/UpgradeStation/icon_mod_fullauto.png",
					tip = "full auto tip",
					up1 = {
						name = "Quick Recovery",
						desc = "quick recovery desc",
						cost = 1,
						owned = true
					},
					up2 = {
						name = "Faster Transform",
						desc = "faster transform desc",
						cost = 3,
						owned = true
					},
					up3 = {
						name = "Fast Feet",
						desc = "fast feet desc",
						cost = 6,
						owned = true
					},
					mastery = {
						name = "Salvo Extender",
						icon = "$CONTENT_DATA/Gui/UpgradeStation/icon_mastery_salvoextender.png",
						desc = "full auto mastery",
						challenge = "Kill 15 Pinkies with the\nmodification.",
						challengeIcon = "$CONTENT_DATA/Gui/UpgradeStation/shotgun_salvo.png",
						progress = 0,
						max = 15,
						owned = true
					}
				}
			},
			hcannon = {
				uuid = tool_spudgun,
				tip = "heavy cannon tip",
				ammo = "Bullets",
				mod1 = {
					name = "Precision Bolt",
					owned = true,
					icon = "$CONTENT_DATA/Gui/UpgradeStation/icon_mod_boltaction.png",
					tip = "precision bolt tip",
					up1 = {name = "Mobility", desc = "mobility desc", cost = 3, owned = true},
					up2 = {name = "Fast Loader", desc = "fast loader desc", cost = 6, owned = true},
					mastery = {name = "Headshot Blast", icon = "$CONTENT_DATA/Gui/UpgradeStation/icon_mastery_headshotblast.png", desc = "precision bolt mastery", challenge = "Headshot 25 enemies with\nthe modification.", challengeIcon = "$CONTENT_DATA/Gui/UpgradeStation/heavycannon_headshotblast.png", progress = 0, max = 25, owned = true} 
				},
				mod2 = {
					name = "Micro Missiles",
					owned = true,
					icon = "$CONTENT_DATA/Gui/UpgradeStation/icon_mod_micromissiles.png",
					tip = "micro missile tip",
					up1 = {name = "Quick Recharger", desc = "quick recharger desc", cost = 1, owned = true},
					up2 = {name = "Instant Loader", desc = "instant loader desc", cost = 3, owned = true},
					up3 = {name = "Primary Charger", desc = "primary charger desc", cost = 6, owned = true},
					mastery = {name = "Bottomless Missiles", icon = "$CONTENT_DATA/Gui/UpgradeStation/icon_mastery_bottomlessmissiles.png", desc = "micro missiles mastery", challenge = "micro missiles challenge", challengeIcon = "$CONTENT_DATA/Gui/UpgradeStation/heavycannon_bottomless_missiles.png", progress = 0, max = 15, owned = true}
				}
			},
			plasma = {
				uuid = wpn_plasmarifle,
				tip = "plasma rifle tip",
				ammo = "Plasma Cells",
				mod1 = {
					name = "Heat Blast",
					owned = true,
					icon = "$CONTENT_DATA/Gui/UpgradeStation/icon_mod_heatblast.png",
					tip = "heat blast tip",
					up1 = {
						name = "Quick Fire",
						desc = "Firing delay after using the Heat Blast is reduced by 25%",
						cost = 3,
						owned = true
					},
					up2 = {
						name = "Super Heated Rounds",
						desc = "Heat Blast charge per shot is increased by 25%",
						cost = 6,
						owned = true
					},
					mastery = {
						name = "Power Surge",
						icon = "$CONTENT_DATA/Gui/UpgradeStation/icon_mastery_powersurge.png",
						desc = "After triggering a fully charged Heat Blast,\nthe plasma gun's projectiles will receive\na damage boost for a short time.",
						challenge = "heat blast challenge",
						challengeIcon = "$CONTENT_DATA/Gui/UpgradeStation/plasma_power_surge.png",
						progress = 0,
						max = 0,
						owned = true
					}
				},
				mod2 = {
					name = "Microwave Beam",
					owned = true,
					icon = "$CONTENT_DATA/Gui/UpgradeStation/icon_mod_microwave.png",
					tip = "microwave beam tip",
					up1 = {
						name = "Faster Beam Charge",
						desc = "Microwave Beam charge time is reduced by 66%",
						cost = 3,
						owned = true
					},
					up2 = {
						name = "Increased Range",
						desc = "Microwave Beam targeting range is increased by 50%",
						cost = 6,
						owned = true
					},
					mastery = {
						name = "Concussive Blast",
						icon = "$CONTENT_DATA/Gui/UpgradeStation/icon_mastery_concussiveblast.png",
						desc = "Demons that are detonated by the Microwave\nBeam will trigger a concussive blast that\nfalters nearby enemies.",
						challenge = "microwave beam challenge",
						challengeIcon = "$CONTENT_DATA/Gui/UpgradeStation/plasma_concussive_blast.png",
						progress = 0,
						max = 0,
						owned = true
					}
				}
			},
			rocket = {
				uuid = wpn_rocketlauncher,
				tip = "rocket launcher tip",
				ammo = "Rockets",
				mod1 = {
					name = "Remote Detonate",
					owned = true,
					icon = "$CONTENT_DATA/Gui/UpgradeStation/icon_mod_remotedetonate.png",
					tip = "rocket launcher tip",
					up1 = {name = "Proximity Fire", desc = "proximity fire desc", cost = 3, owned = true},
					up2 = {name = "Concussive Blast", desc = "concussive blast desc", cost = 6, owned = true},
					mastery = {name = "Explosive Array", icon = "$CONTENT_DATA/Gui/UpgradeStation/icon_mastery_explosivearray.png", desc = "remote detonate mastery", challenge = "remote detonate challenge", challengeIcon = "$CONTENT_DATA/Gui/UpgradeStation/rocket_explosive_array.png", progress = 0, max = 0, owned = true}
				},
				mod2 = {
					name = "Lock-On Burst",
					owned = true,
					icon = "$CONTENT_DATA/Gui/UpgradeStation/icon_mod_lockon.png",
					tip = "lock on burst tip",
					up1 = {
						name = "Fast Reset",
						desc = "fast reset desc",
						cost = 3,
						owned = true
					},
					up2 = {
						name = "Quick Lock",
						desc = "quick lock desc",
						cost = 6,
						owned = true
					},
					mastery = {
						name = "Dual Lock",
						icon = "$CONTENT_DATA/Gui/UpgradeStation/icon_mastery_duallock.png",
						desc = "lock on burst mastery",
						challenge = "lock on burst challenge",
						challengeIcon = "$CONTENT_DATA/Gui/UpgradeStation/rocket_stack_lock.png",
						progress = 0,
						max = 0,
						owned = true
					}
				}
			},
			ssg = {
				uuid = wpn_supershotgun,
				tip = "ssg tip",
				ammo = "Shells",
				mod1 = {
					name = "Meathook",
					owned = true,
					icon = "$CONTENT_DATA/Gui/UpgradeStation/icon_mod_meathook.png",
					tip = "meathook tip tip",
					up1 = {
						name = "Quick Hook",
						desc = "Meat Hook recharge time is reduced by 25%.",
						cost = 3,
						owned = true
					},
					up2 = {
						name = "Fast Hands",
						desc = "Super Shotgun reload speed increased by 33%.",
						cost = 6,
						owned = true
					},
					mastery = {
						name = "Flaming Hook",
						icon = "$CONTENT_DATA/Gui/UpgradeStation/icon_mastery_flaminghook.png",
						desc = "The Meat Hook will set enemies on fire for a brief time, causing them to drop armor from a Super Shotgun blast.",
						challenge = "Defeat 50 demons with the Super Shotgun while using the Meat Hook.",
						challengeIcon = "$CONTENT_DATA/Gui/UpgradeStation/supershotgun_firehook.png",
						progress = 0,
						max = 50,
						owned = true
					}
				}
			},
			ballista = {
				uuid = wpn_ballista,
				tip = "ballista tip",
				ammo = "Plasma Cells",
				mod1 = {
					name = "Arbalest",
					owned = true,
					icon = "$CONTENT_DATA/Gui/UpgradeStation/icon_mod_arbalest.png",
					tip = "arbalest tip",
					up1 = {
						name = "Full Speed",
						desc = "full speed desc",
						cost = 3,
						owned = true
					},
					up2 = {
						name = "Stronger Explosion",
						desc = "stronger explosion desc",
						cost = 6,
						owned = true
					},
					mastery = {
						name = "Instant Salvo",
						icon = "$CONTENT_DATA/Gui/UpgradeStation/icon_mastery_instantsalvo.png",
						desc = "arbalest mastery",
						challenge = "arbalest challenge",
						challengeIcon = "$CONTENT_DATA/Gui/UpgradeStation/ballista_instantsalvo.png",
						progress = 0,
						max = 0,
						owned = true
					}
				},
				mod2 = {
					name = "Destroyer Blade",
					owned = true,
					icon = "$CONTENT_DATA/Gui/UpgradeStation/icon_mod_destroyer.png",
					tip = "destroyer blade tip",
					up1 = {
						name = "Charging Blast",
						desc = "charging blast desc",
						cost = 1,
						owned = true
					},
					up2 = {
						name = "Rapid Chains",
						desc = "rapid chains desc",
						cost = 3,
						owned = true
					},
					mastery = {
						name = "Incremental Blade",
						icon = "$CONTENT_DATA/Gui/UpgradeStation/icon_mastery_incrementalblade.png",
						desc = "destroyer blade mastery",
						challenge = "destroyer blade challenge",
						challengeIcon = "$CONTENT_DATA/Gui/UpgradeStation/ballista_blade.png",
						progress = 0,
						max = 0,
						owned = true
					}
				}
			},
			chaingun = {
				uuid = tool_gatling,
				tip = "chaingun tip",
				ammo = "Bullets",
				mod1 = {
					name = "Mobile Turret",
					owned = true,
					icon = "$CONTENT_DATA/Gui/UpgradeStation/icon_mod_mobileturret.png",
					tip = "mobile turret tip",
					up1 = {
						name = "Rapid Deploy",
						desc = "Turret mode transform speed +50%.",
						cost = 3,
						owned = true
					},
					up2 = {
						name = "Fast Gunner",
						desc = " Increased movement speed while in Mobile Turret mode.",
						cost = 6,
						owned = true
					},
					mastery = {
						name = "Ultimate Cooling",
						icon = "$CONTENT_DATA/Gui/UpgradeStation/icon_mastery_ultimatecooling.png",
						desc = "Turret no longer stalls.",
						challenge = "Kill 5 enemies with a single turret without overheating, ten times.",
						challengeIcon = "$CONTENT_DATA/Gui/UpgradeStation/chaingun_mobile_turret.png",
						progress = 0,
						max = 10,
						owned = true
					}
				},
				mod2 = {
					name = "Energy Shield",
					owned = true,
					icon = "$CONTENT_DATA/Gui/UpgradeStation/icon_mod_energyshield.png",
					tip = "energy shield tip",
					up1 = {
						name = "Faster Recovery",
						desc = "Energy Shield recharge time reduced by 37.5%.",
						cost = 3,
						owned = true
					},
					up2 = {
						name = "Dash Smash",
						desc = "Dashing into Heavy demons will cause them to falter.",
						cost = 6,
						owned = true
					},
					mastery = {
						name = "Shield Launch",
						icon = "$CONTENT_DATA/Gui/UpgradeStation/icon_mastery_shieldlaunch.png",
						desc = "Dealing enough damage with the Chaingun while the Energy Shield is active will launch it forward on release. Any demons hit by this projectile will falter.",
						challenge = "Deal 20,000 damage while Energy Shield is active.",
						challengeIcon = "$CONTENT_DATA/Gui/UpgradeStation/chaingun_shield_launch.png",
						progress = 0,
						max = 20000,
						owned = true
					}
				}
			},
			bfg = {
				uuid = wpn_bfg,
				ammo = "Argent"
			},
			unmaykr = {
				uuid = wpn_unmaykr,
				ammo = "Argent"
			}
		}
	}

	data.suitData.runes.equipped[1] = data.suitData.runes.runes[1]
	data.suitData.runes.equipped[2] = data.suitData.runes.runes[2]
	data.suitData.runes.equipped[3] = data.suitData.runes.runes[3]

	return data
end

function Player:sv_resetWPData()
	self.sv.public.data = self:sv_createNewWPData()
	self:sv_displayMsg( { msg = "Player info has been reset!", dur = 2.5 } )
end

function Player:sv_saveWPData( data )
	self.sv.public.data.currentWpnData = data
end

function Player:sv_displayMsg( args )
	self.network:sendToClient( self.player, "cl_displayMsg", args )
end

function Player:sv_playSound( sound )
	self.network:sendToClient( self.player, "cl_playSound", sound )
end

function Player:sv_playEffect( args )
	self.network:sendToClient( self.player, "cl_playEffect", args )
end

function Player:sv_playParticle( args )
	self.network:sendToClient( self.player, "cl_playParticle", args )
end

function Player:sv_addDamage( dmg )
	print(dmg, self.sv.public.data.playerData.damage)
	self.sv.public.data.playerData.damage = self.sv.public.data.playerData.damage + dmg

	local mastery = self.sv.public.data.weaponData.chaingun.mod2.mastery
	mastery.progress = mastery.progress + dmg
	if mastery.progress >= mastery.max and not mastery.owned then
		mastery.owned = true
		self:sv_displayMsg( { msg = unlockMsgWrap(mastery.name), dur = 2.5 } )
	end
end

function Player:sv_addHealth( args )
end

function Player:sv_addArmour( args )
end

function Player:sv_addAmmo( args )
	sm.container.beginTransaction()
	sm.container.collect( self.player:getInventory(), args.item, args.quantity, 1 )
	sm.container.endTransaction()
end

function Player:sv_increaseslamCharge( increaseAmount )
	if self.sv.public.data.playerData.hammerCharge == 1 then return end

	self.sv.public.data.playerData.hammerCharge = self.sv.public.data.playerData.hammerCharge + increaseAmount
	if self.sv.public.data.playerData.hammerCharge >= 1 then
		self.sv.public.data.playerData.hammerCharge = 1
		self:sv_displayMsg( { msg = "You have regained a slam charge.", dur = 2.5 } )
		self:sv_playSound( "Blueprint - Open" )
	end
end

function Player:sv_activatePrimaryCharger()
	self.sv.public.data.playerData.mmOP = true
end

function Player:sv_toggleSlam( toggle )
	self.sv.public.data.playerData.hammerCharge = toggle and 0 or self.sv.public.data.playerData.hammerCharge
	self.sv.public.data.playerData.isInvincible = toggle

	self.network:sendToClient( self.player, "cl_toggleSlam", toggle )
end

function Player:cl_toggleSlam( toggle )
	self.cl.public.data.playerData.hammerCharge = toggle and 0 or self.cl.public.data.playerData.hammerCharge
	self.cl.public.data.playerData.isInvincible = toggle
end

function Player:sv_gkAnim( anim )
	self.player:sendCharacterEvent( anim.name )

	if anim.sound ~= "" then
		self:sv_playSound( anim.sound )
	end

	if anim.effect ~= "" then
		self:sv_playEffect( { effect = anim.effect, pos = self.player.character.worldPosition } )
	end
end

function Player:sv_killGkTarget( args )
	sm.event.sendToGame("sv_killGkTarget", args)
end

--1. sends event to char
--2. char plays anim
--3. if the animation reaches a certain point, the char calls the function below this one
function Player:sv_bloodPunchAnim()
	self.player:sendCharacterEvent( "punch" )
end

function Player:sv_bloodPunch()
	self.network:sendToClients("cl_bloodPunch")

	local trigger = sm.areaTrigger.createBox( sm.vec3.one(), self.playerPos + self.lookDir, sm.quat.identity(), sm.areaTrigger.filter.character )
	local playerChar = self.player:getCharacter()
    for i, char in pairs(trigger:getContents()) do
        if char:getId() ~= playerChar:getId() then
            local dir = playerChar:getDirection()
            sm.physics.applyImpulse( char, sm.vec3.new(10,10,10) * char:getMass() / 1.5 * sm.vec3.new(dir.x, dir.y, 1), true )
            sm.event.sendToUnit( char:getUnit(), "sv_se_takeDamage", { damage = 150, impact = dir, hitPos = char:getWorldPosition(), attacker = self.player } )
        end
    end
end

function Player:sv_grenadeParry( int )
	local data = sm.interactable.getPublicData( int )
	self.player:sendCharacterEvent( "parry" )
	self:sv_playSound("Sledgehammer - Swing")

	if data.mult < 2 then
		data.mult = data.mult + 0.25
		self:sv_playSound("Retrobass")
	else
		self:sv_playSound("RaftShark")
	end
end

function Player:sv_normalPunch()
	self.player:sendCharacterEvent( "normalPunch" )
	self:sv_playSound("Sledgehammer - Swing")
end

function Player:sv_normalPunchAttack()
	local char = self.player.character
	sm.melee.meleeAttack( "Sledgehammer", 5, char:getWorldPosition() + camPosDifference, char:getDirection() * 2, self.player, 0, 1000 )
end

function Player:sv_setChar( args )
	self.player:setCharacter( sm.character.createCharacter( self.player, args.char:getWorld(), args.pos, args.yaw, args.pitch ) )
	self.player:sendCharacterEvent( "resetVars" )
end

function Player:sv_throwGrenade( args )
	local char = self.player.character
	local velMult = char:isSprinting() and 1.75 or 1
	local thrown = sm.shape.createPart(args.uuid, args.pos - sm.vec3.one() / 4, sm.quat.identity(), true, true)

	sm.interactable.setPublicData( thrown:getInteractable(), { player = self.player, multiplier = 1 } )
	sm.physics.applyImpulse(thrown, sm.vec3.new(10, 10, 10) * thrown:getMass() * velMult * char:getDirection() )

	self.sv.generalGrenade.canThrow = false
	if self.sv.generalGrenade.current == grenades[1].throwable or self.sv.generalGrenade.current == grenades[3].throwable then
		self.sv.public.data.suitData.launcher.grenade.charges = self.sv.public.data.suitData.launcher.grenade.charges - 1
	else
		self.sv.public.data.suitData.launcher.icebomb.charges = 0
	end
end

function Player:sv_reduceRecharge( args )
	self.sv.grenade.rechargeMax = (args.equipment == "grenade" and self.sv.grenade.rechargeMax * args.reduction > 0.1) and self.sv.grenade.rechargeMax * args.reduction or self.sv.grenade.rechargeMax
	self.sv.ice.rechargeMax = (args.equipment == "ice" and self.sv.ice.rechargeMax * args.reduction > 0.1) and self.sv.ice.rechargeMax * args.reduction or self.sv.ice.rechargeMax
	self.sv.flame.rechargeMax = (args.equipment == "flame" and self.sv.flame.rechargeMax * args.reduction > 0.1) and self.sv.flame.rechargeMax * args.reduction or self.sv.flame.rechargeMax
end


function Player:sv_onInteract( args )
	if not args.state or self.sv.public.data.playerData.gkState then return end

	--Does two raycasts instead of one like previously
	--the range for grenade parrying and normal meleeing would be the same as the gk range
	--the problem comes when the player uses the seek and destroy rune which extends it

	--Glory Kill
	local hit, result = se.player.getRaycast( self.player, self.sv.gk.range )
	if hit and result:getCharacter() ~= nil and se.unitData[result:getCharacter():getId()].data.stats.gkState then
		self.sv.gk.target = result:getCharacter()
		self.sv.public.data.playerData.gkState = true
		sm.localPlayer.setLockedControls( true )
		self.sv.public.data.playerData.isInvincible = true

		sm.event.sendToUnit(self.sv.gk.target:getUnit(), "sv_extendGK", 100000)
		self:sv_gkSnap( "normal" )
		return
	end


	local hit, result = se.player.getRaycast( self.player, 7.5 )
	if hit and result:getCharacter() ~= nil then
		--Blood punch
		if self.sv.public.data.suitData.bloodpunch.charges > 1 then
			--print("Blood Punch performed")
			self:sv_bloodPunchAnim()
			self.sv.public.data.suitData.bloodpunch.charges = self.sv.public.data.suitData.bloodpunch.charges - 1
		else
			--normal punch
			self:sv_normalPunch()
			end
	elseif hit and (result:getShape() ~= nil and (result:getShape():getShapeUuid() == grn_grenade or result:getShape():getShapeUuid() == grn_imploGrenade) or result:getAreaTrigger() ~= nil ) then
		--grenade parry
		local shape
		if result:getAreaTrigger() ~= nil then
			shape = result:getAreaTrigger():getHostInteractable():getShape()
		else
			shape = result:getShape()
		end

		if shape ~= nil and (result:getShape():getShapeUuid() == grn_grenade or result:getShape():getShapeUuid() == grn_imploGrenade) then
			local force = 15 * shape:getMass()
			local impulse = sm.vec3.new( se.vec3.redirectVel( "x", force, shape ).x, se.vec3.redirectVel( "y", force, shape ).y, se.vec3.redirectVel( "z", force, shape ).z )
			sm.physics.applyImpulse( shape, impulse * self.player.character.direction, true )
			self:sv_grenadeParry(shape:getInteractable())
		end
	elseif not hit then
		--Grenade switch
		self.sv.generalGrenade.index = self.sv.generalGrenade.index < #grenades and self.sv.generalGrenade.index + 1 or 1
		local throwable = grenades[self.sv.generalGrenade.index]
		self.sv.generalGrenade.current = throwable.throwable

		self:sv_displayMsg( { msg = "Current grenade type: #ff9d00"..throwable.name, dur = 2.5 } )
		self:sv_playSound( "PaintTool - ColorPick" )
	elseif not self.sv.punch then
		--normal punch
		self.sv.punch = true
		self:sv_normalPunch()
	end
end

function Player:sv_updateDash( dt )
	--Dash
	if self.sv.dash.inputCD then
		self.sv.dash.inputCDCount = self.sv.dash.inputCDCount - dt
		if self.sv.dash.inputCDCount <= 0 then
			self.sv.dash.inputCD = false
			self.sv.dash.inputCDCount = 0.25
			self.sv.dash.keys = { nil, nil }
		end
	end

	--Dash recharge
	if self.sv.dash.count < 2 then
		self.sv.dash.recharge = self.sv.dash.recharge - dt
		if self.sv.dash.recharge <= 0 then
			self.sv.dash.recharge = 1.25
			self.sv.dash.count = self.sv.dash.count + 1
		end
	end

	--Dash use cooldown
	if not self.sv.dash.canDash then
		self.sv.dash.keys = { nil, nil }
		self.sv.dash.useCD = self.sv.dash.useCD - dt
		if self.sv.dash.useCD <= 0 then
			self.sv.dash.useCD = 0.5
			self.sv.dash.canDash = true
		end
	end
end

function Player:sv_checkForVault( pos, dir, char, grounded )
	--Vault
	if not grounded then
		if self.sv.vaultCount == 1 and not self.sv.public.data.playerData.meathookAttached and not char:isSwimming() and not char:isDiving() then
			local dir = dir / 2
			local hit, result = sm.physics.raycast( pos, pos + dir )

			if hit and not result:getCharacter() then
				local newPos = se.vec3.add( pos, "z", 0.6 )

				if not sm.physics.raycast( newPos, newPos + dir ) then
					local hit, result = sm.physics.raycast( newPos + dir, newPos + dir - sm.vec3.new(0,0,0.5) )

					if hit then
						local pos = result.pointWorld

						if not sm.physics.raycast( pos, pos + sm.vec3.new(0,0,1.4) ) then
							local pitch = 0 --math.acos(self.dir.z) / math.pi * 2 - 1
							local yaw = math.atan2( dir.y, dir.x ) - math.pi / 2

							self.network:sendToClient( self.player, "cl_vaultStart",
								{
									startDir = self.player.character.direction,
									endDir = dir,
									startPos = pos,
									endPos = pos + sm.vec3.new(0,0,1.4) --1.295
								}
							)

							self.sv.public.data.playerData.isInvincible = true
							self:sv_setChar({ char = char, pos = pos + sm.vec3.new(0,0,0.70), yaw = yaw, pitch = pitch })
							self.sv.vaultCount = 0
						end
					end
				end
			end
		end
	else
		self.sv.vaultCount = 1
	end
end

function Player:sv_updateGrenades( dt, data )
	--Grenade throw cooldown
	if not self.sv.generalGrenade.canThrow then
		self.sv.generalGrenade.throwTimer:tick()
		if self.sv.generalGrenade.throwTimer:done() then
			self.sv.generalGrenade.throwTimer:reset()
			self.sv.generalGrenade.canThrow = true
		end
	end

	--Frag recharge
	if data.suitData.launcher.grenade.charges < 2 then
		self.sv.grenade.recharge = self.sv.grenade.recharge + dt
		if self.sv.grenade.recharge >= self.sv.grenade.rechargeMax then
			self.sv.grenade.recharge = 0
			self.sv.grenade.rechargeMax = 10
			data.suitData.launcher.grenade.charges = data.suitData.launcher.grenade.charges + 1
			self:sv_displayMsg( { msg = "Frag Grenade recharged: #ff9d00"..data.suitData.launcher.grenade.charges.."#ffffff / 2", dur = 2.5 } )
		end
	end

	--ice bomb recharge
	if data.suitData.launcher.icebomb.charges < 1 then
		self.sv.ice.recharge = self.sv.ice.recharge + dt
		if self.sv.ice.recharge >= self.sv.ice.rechargeMax then
			self.sv.ice.recharge = 0
			self.sv.ice.rechargeMax = 10
			data.suitData.launcher.icebomb.charges = 1
			self:sv_displayMsg( { msg = "Ice Bomb recharged", dur = 2.5 } )
		end
	end
end

function Player:sv_updateGk( dt, data, lookDir, char )
	if data.playerData.gkState and not self.cl.cameraMove.active then
		local decrease = dt
		local equipped, equippedRune = se.player.isEquippedRune( self.player, "Savagery" )
		if equipped and equippedRune ~= nil then
			decrease = decrease * equippedRune.buff.gkSpeedMultiplier
		end

		if self.sv.gk.timer == self.sv.gk.duration then
			self:sv_gkAnim( self.sv.gk.anim )
		end

		self.sv.gk.timer = self.sv.gk.timer - decrease
		self.cl.chainsaw.counter = 1

		if self.sv.gk.timer <= self.sv.gk.timerEnd then
			data.playerData.gkState = false
			if data.playerData.hammerCharge < 1 then
				data.playerData.hammerCharge = data.playerData.hammerCharge + 0.5
			end
			data.suitData.bloodpunch.charges = data.suitData.bloodpunch.charges + 1
			data.playerData.isInvincible = false


			local delay = false
			local delayCD = 0
			local impulse = sm.vec3.zero()
			if self.sv.gk.anim.action == "throw" then
				delay = true
				delayCD = 0.5
				impulse = sm.vec3.new(1000 * lookDir.x, 1000 * lookDir.y, 500) * self.sv.gk.target:getMass() / 75
				sm.physics.applyImpulse(self.sv.gk.target, impulse, true)
			--[[elseif self.sv.gk.anim.action == "cut" then

			elseif self.sv.gk.anim.action == "" then

			elseif self.sv.gk.anim.action == "" then]]

			end

			sm.event.sendToUnit( self.sv.gk.target:getUnit(), "sv_se_onDeath", {player = self.player, impact = se.vec3.num(10) * lookDir, delay = delay, delayCD = delayCD } )
			self.player.character:setSwimming( false )

			--Blood Fueled #1
			if se.player.isEquippedRune( self.player, "Blood Fueled" ) then
				self.sv.bloodFueled = true
				char:setMovementSpeedFraction(bloodFueledSpeedFraction)
			end

			self.network:sendToClients("cl_gkEnd",
				{
					sound = self.sv.gk.anim.endSound,
					effect = self.sv.gk.anim.endEffect,
					pos = self.sv.gk.target:getWorldPosition()
				}
			)

			self.sv.gk.anim = nil
			self.sv.gk.duration = 0
			self.sv.gk.timerEnd = 0
			self.sv.gk.timer = 0
			self.sv.gk.target = nil
		end
	end
end

function Player:sv_updateRunes( dt, moveDirs, currentMoveDir, pos, char, grounded, vel )
	--Blood Fueled #2
	if self.sv.bloodFueled then
		self.sv.bloodFueledTimer:tick()
		if self.sv.bloodFueledTimer:done() then
			self.sv.bloodFueledTimer:reset()
			self.sv.bloodFueled = false
			self.player.character:setMovementSpeedFraction(1)
		end
	end

	--Air Control
	if se.player.isEquippedRune( self.player, "Air Control" ) and not grounded then
		sm.physics.applyImpulse( char, currentMoveDir * airControlSpeed, true )
	end

	--Chrono Strike
	--since you cant slow down time, Ill just make the character glide
	if se.player.isEquippedRune( self.player, "Chrono Strike" ) then
		local mouse1 = self.sv.public.input[sm.interactable.actions.attack]

		if (self.sv.gliding and not grounded or not sm.physics.raycast(pos, pos - sm.vec3.new(0,0,2.5))) and mouse1 then
			sm.physics.applyImpulse( char, (vel * -1) * se.vec3.num(20) + sm.vec3.new(75,75,0) * moveDirs[1].dir )
			self.sv.gliding = true
		elseif grounded or not mouse1 then
			self.sv.gliding = false
		end
	end
end

function Player:sv_changeRune( args )
	local equippedSlot = tonumber(args.button:sub(-1))
	self.sv.public.data.suitData.runes.equipped[equippedSlot] = self.sv.public.data.suitData.runes.runes[args.selected]

	for v, k in pairs(self.sv.public.data.suitData.runes.equipped) do
		if v ~= equippedSlot and k.name == self.sv.public.data.suitData.runes.equipped[equippedSlot].name then
			self.sv.public.data.suitData.runes.equipped[v] = nil
		end
	end

	--self.player:setPublicData( self.sv.public )
	sm.event.sendToInteractable(args.int, "sv_updateEquippedRunes", self.sv.public.data.suitData.runes)
end

function Player.server_onFixedUpdate( self, dt )
	local playerChar = self.player:getCharacter()
	if playerChar == nil then return end

	local lookDir = playerChar:getDirection()
	local playerVel = playerChar:getVelocity()
	local playerPos = playerChar:getWorldPosition()
	local onGround = se.player.isOnGround(self.player)
	local data = self.sv.public.data
	local currentMoveDir, moveDirs = se.player.getMoveDir( self.player, self.sv.public )

	self.sv.gk.range = 5
	local equipped, equippedRune = se.player.isEquippedRune( self.player, "Seek and Destroy" )
	if equipped and equippedRune ~= nil then
		self.sv.gk.range = self.sv.gk.range * equippedRune.buff.rangeMult
	end

	self:sv_updateDash( dt )
	self:sv_checkForVault( playerPos, moveDirs[1].dir, playerChar, onGround )
	self:sv_updateGrenades( dt, data )
	self:sv_updateGk( dt, data, playerChar )
	self:sv_updateRunes( dt, moveDirs, currentMoveDir, playerPos, playerChar, onGround, playerVel )

	if data.playerData.mmOP then
		self.sv.mmOpTimer:tick()
		if self.sv.mmOpTimer:done() then
			data.playerData.mmOP = false
			self.sv.mmOpTimer:reset()
		end
	end

	if self.sv.punch then
		self.sv.punchTimer:tick()
		if self.sv.punchTimer:done() then
			self.sv.punch = false
			self.sv.punchTimer:reset()
		end
	end

	--jump count reset
	--delay by one tick
	if self.sv.jumpChargeCheck < 0.1 then
		self.sv.jumpChargeCheck = self.sv.jumpChargeCheck + dt
		if self.sv.jumpChargeCheck > 0.1 then
			self.sv.jumpChargeCheck = 0.1
		end
	end

	--reset
	if onGround and self.sv.jumpChargeCheck == 0.1 then
		self.sv.jumpCount = 2
	end

	--Grenade throw
	local lockingInt = playerChar:getLockingInteractable()
	if lockingInt ~= nil and lockingInt:getShape():getShapeUuid() == sm.uuid.new("587a25d7-6d80-4cba-88c1-f52e5366899f") then
		if playerChar:isCrouching() and self.sv.generalGrenade.canThrow then
			local thrown
			if self.sv.generalGrenade.current == grenades[1].throwable or self.sv.generalGrenade.current == grenades[3].throwable then
				thrown = { ammo = data.suitData.launcher.grenade.charges, name = "grenade charges" }
			elseif self.sv.generalGrenade.current == grenades[2].throwable then
				thrown = { ammo = data.suitData.launcher.icebomb.charges, name = "ice bomb charges" }
			end

			if thrown.ammo > 0 then
				self:sv_throwGrenade( { uuid = self.sv.generalGrenade.current, pos = playerPos + camPosDifference + lookDir } )
				self:sv_displayMsg( { msg = "Current amount of "..thrown.name..": #ff9d00"..thrown.ammo-1, dur = 2.5 } )
			end
		end
	end

	if data.suitData.launcher.flamethrower.charges < 1 and self.sv.flame.firingDuration == 2 then
		self.sv.flame.recharge = self.sv.flame.recharge + dt
		if self.sv.flame.recharge >= self.sv.flame.rechargeMax then
			self.sv.flame.recharge = 0
			self.sv.flame.rechargeMax = 10
			data.suitData.launcher.flamethrower.charges = 1
			self:sv_displayMsg( { msg = "Flamethrower recharged", dur = 2.5 } )
		end
	end

	if self.sv.flame.active then
		self.sv.flame.firingDuration = self.sv.flame.firingDuration - dt
		if self.sv.flame.firingDuration <= 0 then
			self.sv.flame.firingDuration = 2
			self.sv.flame.active = false
			self.network:sendToClients("cl_flameEffect", false)
		end
	end

	--local prevPlayerData = data.playerData
	local displayTxt = (data.playerData.damageMultiplier > 1 or data.playerData.speedMultiplier > 1 or data.playerData.berserk) and "#ffffffPowerup cooldowns:" or ""

	if data.playerData.damageMultiplier > 1 then
		self.sv.dmgMultTimer:tick()
		displayTxt = displayTxt.." #6049c7DAMAGE: #ff9d00"..tostring(("%.0f"):format((self.sv.dmgMultTimer.ticks - self.sv.dmgMultTimer.count)/40))
		if self.sv.dmgMultTimer:done() then
			self.sv.dmgMultTimer:reset()
			data.playerData.damageMultiplier = 1
			self.network:sendToClients("cl_disablePrp", "damageMultiplier")
		end
	end

	if data.playerData.speedMultiplier > 1 then
		self.sv.spdMultTimer:tick()
		playerChar.movementSpeedFraction = data.playerData.speedMultiplier
		displayTxt = displayTxt.." #fff200SPEED: #ff9d00"..tostring(("%.0f"):format((self.sv.spdMultTimer.ticks - self.sv.spdMultTimer.count)/40))
		if self.sv.spdMultTimer:done() then
			self.sv.spdMultTimer:reset()
			data.playerData.speedMultiplier = 1
			self.player.character:setMovementSpeedFraction(1)
			self.network:sendToClients("cl_disablePrp", "speedMultiplier")
		end
	end

	if data.playerData.berserk then
		self.sv.berserkTimer:tick()
		--sm.tool.forceTool( sm.uuid.new("469ddbcd-eda9-4c78-b620-4270b7a36abf") )
		displayTxt = displayTxt.." #ff1100BERSERK: #ff9d00"..tostring(("%.0f"):format((self.sv.berserkTimer.ticks - self.sv.berserkTimer.count)/40))
		if self.sv.berserkTimer:done() then
			self.sv.berserkTimer:reset()
			data.playerData.berserk = false
			self.network:sendToClients("cl_disablePrp", "berserk")
		end
	end

	--print(playerChar:getMovementSpeedFraction())
	--[[if prevPlayerData ~= data.playerData then
		self.sv.public.data = data
		self.player:setPublicData( self.sv.public )
	end]]

	if data.currentWpnData.mod == "Energy Shield" and data.currentWpnData.using then
		if displayTxt ~= "" then
			displayTxt = displayTxt.."\n"
		end
		local text = data.playerData.damage < 500 and "#ff9d00"..tostring(data.playerData.damage).."#ffffff / "..tostring(500).." dmg" or "#ff9d00Shield Launch activated"
		displayTxt = displayTxt..text
	end

	local sentData = copyTable(self.sv.public)
	sentData.displayTxt = displayTxt

	self.sv.statsTimer:tick()
	if self.sv.statsTimer:done() then
		self.sv.statsTimer:reset()
		self.network:setClientData( sentData )
	end
end

function Player:sv_vaultEnd()
	self.sv.public.data.playerData.isInvincible = false
end

function Player:sv_gkSnap( animType )
	local playerPos = self.player.character.worldPosition
	local offsetMult = self.sv.gk.target:getCharacterType() == unit_farmbot and 2 or 1
	local dir = self.sv.gk.target:getDirection()
	local right = dir:cross( sm.vec3.new(0,0,1) )
	local gkPosOffsets = {
		sm.vec3.rotate(se.vec3.up(), math.rad(-90), right) * offsetMult,
		sm.vec3.rotate(se.vec3.up(), math.rad(90), right) * offsetMult,
		right * -1 * offsetMult,
		right * offsetMult,
		sm.vec3.new(0,0,1) * offsetMult
	}

	local targetPos = self.sv.gk.target:getWorldPosition()
	local offsetIndex = 1
	local offset = gkPosOffsets[offsetIndex]
	local targetOffsetPos = targetPos + offset
	local targetDir = targetOffsetPos - playerPos
	local minDistance = targetDir:length()
	for v, posOffset in pairs(gkPosOffsets) do
		targetOffsetPos = (targetPos + posOffset)
		targetDir = targetOffsetPos - playerPos
		local distance = targetDir:length()
		if distance < minDistance then
			minDistance = distance
			offsetIndex =  v
			offset = posOffset
		end
	end

	local lookDir = targetPos - (targetPos + offset)
	local yaw = math.atan2( lookDir.y, lookDir.x ) - math.pi / 2

	self.player:setCharacter( sm.character.createCharacter( self.player, self.player.character:getWorld(), targetPos + offset, yaw, 0 ) )

	--makes the character float for aerial gks
	if offset == gkPosOffsets[5] then
		self.player.character:setSwimming( true )
	end

	local animSet = gkAnims[offsetIndex][tostring(self.sv.gk.target:getCharacterType())][animType]
	local animIndex = #animSet > 1 and animSet[math.random(1, #animSet)] or 1
	local animToPlay = animSet[animIndex]

	self.sv.gk.anim = animToPlay
	self.sv.gk.duration = self.player.character:getAnimationInfo( self.sv.gk.anim.name ).duration
	self.sv.gk.timerEnd = self.sv.gk.duration / animToPlay.divide
	self.sv.gk.timer = self.sv.gk.duration

	self.network:sendToClients( "cl_gkSnap",
		{
			targetPos = targetPos,
			offset = offset,
			playerPos = playerPos,
			targetDir = targetDir,
			lookDir = lookDir,
			animType = animType
		}
	)
end


--random default stuff
function Player.server_onRefresh( self )
	self:sv_init()
end

function Player.sv_init( self ) end

function Player.server_onDestroy( self ) end

function Player.server_onProjectile( self, hitPos, hitTime, hitVelocity, projectileName, attacker, damage ) end

function Player.server_onMelee( self, hitPos, attacker, damage, power )
	if not sm.exists( attacker ) then
		return
	end

	if self.player.character and attacker.character then
		local attackDirection = ( hitPos - attacker.character.worldPosition ):normalize()
		-- Melee impulse
		if attacker and not self.sv.public.data.playerData.isInvincible then
			ApplyKnockback( self.player.character, attackDirection, power )
		end
	end
end

function Player.server_onExplosion( self, center, destructionLevel ) end

function Player.server_onCollision( self, other, collisionPosition, selfPointVelocity, otherPointVelocity, collisionNormal  ) end

function Player.sv_e_staminaSpend( self, stamina ) end

function Player.sv_e_receiveDamage( self, damageData ) end

function Player.sv_e_respawn( self ) end

function Player.sv_e_debug( self, params ) end

function Player.sv_e_eat( self, edibleParams )
	if edibleParams.dmgMult then
		self.sv.public.data.playerData.damageMultiplier = 4
	end

	if edibleParams.spdMult then
		self.sv.public.data.playerData.speedMultiplier = 2
	end

	if edibleParams.berserk then
		self.sv.public.data.playerData.berserk = true
	end

	self.network:sendToClients("cl_e_eat", edibleParams)
	--self.player:setPublicData( self.sv.public )
end

function Player.sv_e_feed( self, params ) end

function Player.sv_e_setRefiningState( self, params )
	local userPlayer = params.user:getPlayer()
	if userPlayer then
		if params.state == true then
			userPlayer:sendCharacterEvent( "refine" )
		else
			userPlayer:sendCharacterEvent( "refineEnd" )
		end
	end
end

function Player.sv_e_onLoot( self, params ) end

function Player.sv_e_onStayPesticide( self ) end

function Player.sv_e_onEnterFire( self ) end

function Player.sv_e_onStayFire( self ) end

function Player.sv_e_onEnterChemical( self ) end

function Player.sv_e_onStayChemical( self ) end

function Player.sv_e_startLocalCutscene( self, cutsceneInfoName ) end

function Player.client_onCancel( self ) end

function Player.client_onReload( self ) end

function Player.server_onShapeRemoved( self, removedShapes ) end


--doom control callbacks
function Player:sv_e_onJump( state )
	if state ~= sm.tool.interactState.start then return end

	local onGround = se.player.isOnGround( self.player )
	local playerChar = self.player.character

	--Wall dismount
	if self.sv.public.data.playerData.isOnWall then
		playerChar:setDiving(false)
		playerChar:setSwimming(false)
		playerChar:setMovementSpeedFraction(1)

		sm.physics.applyImpulse(playerChar, playerChar:getDirection() * 1750, true)
		return
	end

	--Double Jump
	if not self.sv.public.data.playerData.meathookAttached then
		if not self.sv.gliding then
			if onGround then
				--print("Jump performed")
				self.sv.jumpCount = 1
				self.sv.jumpChargeCheck = 0
			elseif not onGround and self.sv.jumpCount > 0  then
				--print("Double jump performed")
				self.sv.jumpCount = self.sv.jumpCount - 2
				sm.physics.applyImpulse( playerChar, se.vec3.redirectVel( "z", 750, playerChar ) )
				self:sv_playSound("WeldTool - Weld")
			end
		end
	end
end

function Player:sv_e_onCamOut( state )
	--Chainsaw
	if state ~= sm.tool.interactState.start or self.sv.public.data.playerData.gkState then return end

	self.network:sendToClients("cl_chainsawEffect")
	local hit, result = se.player.getRaycast( self.player, self.sv.gk.range )

	if hit and result:getCharacter() ~= nil then
		local target = result:getCharacter()
		local unitData = se.unitData[target:getId()]
		if unitData.cCharge <= self.sv.public.data.suitData.chainsaw.charges then
			self.sv.gk.target = target
			unitData.data.stats.cState = true
			self.sv.public.data.playerData.gkState = true
			self.sv.public.data.playerData.isInvincible = true
			sm.event.sendToUnit(self.sv.gk.target:getUnit(), "sv_extendGK", 100000)

			self:sv_gkSnap( "chainsaw" )
		end
	end
end

function Player:sv_e_onCamIn( state )
	--Flame belch
	if state ~= sm.tool.interactState.start or self.sv.public.data.suitData.launcher.flamethrower.charges ~= 1 then return end

	--local playerChar = self.player.character
	--se.physics.explode( playerChar:getWorldPosition(), 5, 10, 12, 10, "PropaneTank - ExplosionSmall", nil, self.player, false )

	self.sv.public.data.suitData.launcher.flamethrower.charges = 0
	self.sv.flame.active = true
	self.sv.flame.trigger = sm.areaTrigger.createBox( se.vec3.num(2), self.player.character.worldPosition, sm.quat.identity(), sm.areaTrigger.filter.character )
	self.network:sendToClients("cl_flameEffect", true)
end

function Player:sv_e_onMove( args )
	if args.state ~= sm.tool.interactState.start then return end

	local key = args.key
	local currentMoveDir, moveDirs = se.player.getMoveDir( self.player, self.sv.public )

	if self.sv.dash.canDash and self.sv.dash.count > 0 and not self.sv.public.data.playerData.meathookAttached and not self.sv.gliding then
		local index = self.sv.dash.keys[1] == nil and 1 or 2

		for v, moveDir in pairs(moveDirs) do
			local id = moveDir.id
			if key == id then
				self.sv.dash.keys[index] = id

				if self.sv.dash.inputCD then
					self.sv.dash.dir = moveDir.dir
				end

				self.sv.dash.inputCD = true
			end
		end

		if self.sv.dash.keys[1] ~= nil and self.sv.dash.keys[1] == self.sv.dash.keys[2] and self.sv.dash.inputCD then
			sm.physics.applyImpulse( self.player.character, dashImpulse * self.sv.dash.dir )
			self.sv.dash.canDash = false
			self.sv.dash.useCD = 0.5
			self.sv.dash.count = self.sv.dash.count - 1
			self.sv.dash.dir = sm.vec3.zero()
			self.sv.dash.keys = { nil, nil }
			self.sv.dash.inputCD = false
			self.sv.dash.inputCDCount = 0.25
			self.network:sendToClients("cl_playSound", "WeldTool - Weld")
			--print("Performed dash")
		end
	else
		self.sv.dash.keys = { nil, nil }
		self.sv.dash.dir = sm.vec3.zero()
	end
end

function Player:sv_se_onExplosion(args)

end



--Client
function Player.client_onCreate( self )
	self.cl = {}
	self:cl_init()

	self.cl.flameThrowerEffect = sm.effect.createEffect( "Fire - vertical" )
	self.cl.bloodPunchSound = sm.effect.createEffect( "BloodPunch", self.player.character )

	self.cl.chainsaw = {
		sound = sm.effect.createEffect( "GasEngine - Level 3", self.player.character ),
		counter = 0,
		blockDeplete = false
	}

	if self.player ~= sm.localPlayer.getPlayer() then return end

	self.cl.currentPowerupColor = nil

	self.cl.cameraMove = {
		active = false,
		progress = 0,
		speed = 1,
		startPos = sm.vec3.zero(),
		endPos = sm.vec3.zero(),
		startDir = sm.vec3.zero(),
		endDir = sm.vec3.zero(),
		mode = ""
	}

	g_survivalHud = sm.gui.createSurvivalHudGui()
	g_survivalHud:setVisible("WaterBar", false)
	g_survivalHud:open()

	--g_doomHud = sm.gui.createGuiFromLayout()

	self.cl.powerup = {
		colour = nil,
		text = ""
	}

	self.player:setClientPublicData(
		{
			data = {},
			weaponMod = {
				mod = "none",
				using = false,
				ammo = 0,
				recharge = 0
			},
			powerup = {
				speedMultiplier = { current = 1, active = 2, default = 1, colour = sm.color.new("#fff200") },
				damageMultiplier = { current = 1, active = 4, default = 1, colour = sm.color.new("#6049c7") },
				berserk = { current = false, active = true, default = false, colour = sm.color.new("#ff1100") }
			},
			input = {
				[sm.interactable.actions.forward] = false,
                [sm.interactable.actions.backward] = false,
                [sm.interactable.actions.left] = false,
                [sm.interactable.actions.right] = false,
				[sm.interactable.actions.jump] = false,
                [sm.interactable.actions.use] = false,
                [sm.interactable.actions.zoomIn] = false,
                [sm.interactable.actions.zoomOut] = false,
				[sm.interactable.actions.attack] = false,
				[sm.interactable.actions.create] = false
			}
		}
	)

	self.cl.public = self.player:getClientPublicData()
end

function Player.client_onRefresh( self )
	self:cl_init()
end

function Player.cl_init(self) end

function Player.client_onUpdate( self, dt )
	local playerChar = self.player:getCharacter()
	if playerChar == nil then return end

	local lookDir = playerChar:getDirection()
	local launcherPos = playerChar:getTpBonePos( "jnt_spine2" ) + playerChar:getTpBoneRot( "jnt_spine2" ) * sm.vec3.new(0.5,0,0.3) + lookDir / 2

	if self.cl.flameThrowerEffect:isPlaying() then
		self.cl.flameThrowerEffect:setPosition(launcherPos)
		self.cl.flameThrowerEffect:setRotation(sm.vec3.getRotation(up, lookDir))
	end

	self.cl.chainsaw.sound:setPosition(playerChar:getWorldPosition())
	if self.cl.chainsaw.counter > 0 and self.cl.chainsaw.sound:isPlaying() then
		if not self.cl.chainsaw.blockDeplete then
			self.cl.chainsaw.counter = self.cl.chainsaw.counter - dt * 1.75
			self.cl.chainsaw.sound:setParameter("rpm", self.cl.chainsaw.counter)
		end
	elseif self.cl.chainsaw.counter <= 0 and self.cl.chainsaw.sound:isPlaying() then
		self.cl.chainsaw.sound:stop()
		self.cl.chainsaw.counter = 0
	end

	if self.player ~= sm.localPlayer.getPlayer() then return end


	--Cam move code
	if self.cl.cameraMove.active then
		self.cl.cameraMove.progress = self.cl.cameraMove.progress + dt * self.cl.cameraMove.speed
		local newPos = sm.vec3.lerp( self.cl.cameraMove.startPos, self.cl.cameraMove.endPos, self.cl.cameraMove.progress )

		if (self.cl.cameraMove.endPos - newPos):length() > 0.1 * self.cl.cameraMove.speed then
			sm.camera.setPosition( newPos )

			if self.cl.cameraMove.startDir ~= sm.vec3.zero() and self.cl.cameraMove.endDir ~= sm.vec3.zero() then
				local newDir = sm.vec3.lerp( self.cl.cameraMove.startDir, self.cl.cameraMove.endDir, self.cl.cameraMove.progress )
				sm.camera.setDirection( newDir )
			end
		else
			if self.cl.cameraMove.mode == "vault" then
				self.network:sendToServer("sv_vaultEnd")
				sm.localPlayer.setLockedControls( false )
			end

			sm.camera.setCameraState( 1 )
			self.cl.cameraMove = {
				active = false,
				progress = 0,
				speed = 1,
				startPos = sm.vec3.zero(),
				endPos = sm.vec3.zero(),
				startDir = sm.vec3.zero(),
				endDir = sm.vec3.zero(),
				mode = ""
			}
		end
	end
end

function Player:client_onFixedUpdate( dt )
	local playerChar = self.player:getCharacter()
	if playerChar == nil then return end

	if self.cl.flameThrowerEffect == nil or not sm.exists(self.cl.flameThrowerEffect) then
		self.cl.flameThrowerEffect = sm.effect.createEffect( "Fire - vertical" )
	end

	if self.cl.chainsaw.sound == nil or not sm.exists(self.cl.chainsaw.sound) then
		self.cl.chainsaw.sound = sm.effect.createEffect( "GasEngine - Level 3", playerChar )
	end

	if self.cl.bloodPunchSound == nil or not sm.exists(self.cl.bloodPunchSound) then
		self.cl.bloodPunchSound = sm.effect.createEffect( "BloodPunch", playerChar )
	end

	if self.cl.powerup.colour ~= nil then
		sm.particle.createParticle( "paint_smoke", playerChar:getTpBonePos( "jnt_spine2" ), sm.quat.identity(), self.cl.powerup.colour )
	end


	if self.player ~= sm.localPlayer.getPlayer() then return end
	--[[local lookDir = playerChar:getDirection()
	local playerVel = playerChar:getVelocity()
	local playerPos = playerChar:getWorldPosition()
	local onGround = se.player.isOnGround(self.player)
	local launcherPos = playerChar:getTpBonePos( "jnt_spine2" ) + playerChar:getTpBoneRot( "jnt_spine2" ) * sm.vec3.new(0.5,0,0.3) + lookDir / 2

	local inputs = self.cl.public.input
	local currentMoveDir, moveDirs = se.player.getMoveDir( self.player, self.cl.public )]]
end

function Player:client_onClientDataUpdate( data, channel )
	if sm.localPlayer.getPlayer() ~= self.player then return end

	self.cl.public.data = data.data
	--self.player:setClientPublicData( self.cl.public )

	self.cl.powerup.text = data.displayTxt
	if self.cl.powerup.text ~= nil and self.cl.powerup.text ~= "" then
		self:cl_displayMsg( { msg = self.cl.powerup.text, dur = 1 } )
	end

	g_survivalHud:setSliderData( "Health", data.stats.maxhealth * 10 + 1, data.stats.health * 10 )
	g_survivalHud:setSliderData( "Food", data.stats.maxarmour * 10 + 1, data.stats.armour * 10 )
end

function Player:cl_displayMsg( args )
	sm.gui.displayAlertText( args.msg, args.dur )
end

function Player:cl_playSound( sound )
	sm.audio.play( sound, self.player:getCharacter():getWorldPosition() )
end

function Player:cl_playEffect( args )
	sm.effect.playEffect( args.effect, args.pos, sm.vec3.zero(), sm.quat.identity() )
end

function Player:cl_playParticle( args )
	sm.particle.createParticle( args.particle, args.pos, sm.quat.identity(), args.colour )
end

function Player.client_onInteract( self, character, state )
	self.network:sendToServer("sv_onInteract", { char = character, state = state })
end

function Player:cl_vaultStart( args )
	local fov = sm.camera.getFov()
	sm.camera.setCameraState( 2 )
	sm.camera.setFov(fov)
	self.cl.cameraMove.mode = "vault"
	self.cl.cameraMove.startPos = args.startPos
	self.cl.cameraMove.endPos = args.endPos
	self.cl.cameraMove.startDir = args.startDir
	self.cl.cameraMove.endDir = args.endDir
	self.cl.cameraMove.speed = 2.5
	self.cl.cameraMove.active = true

	sm.localPlayer.setLockedControls( true )
end

function Player:cl_gkEnd( args )
	if args.effect ~= "" then
		self:cl_playEffect( { effect = args.effect, pos = args.pos } )
	end

	if args.sound == "" then
		self:cl_playSound(args.sound)
	end

	self.cl.chainsaw.blockDeplete = false

	if self.player ~= sm.localPlayer.getPlayer() then return end
	sm.localPlayer.setLockedControls( false )
end

function Player:cl_gkSnap( args )
	if args.animType == "chainsaw" then
		self.cl.chainsaw.sound:start()
		self.cl.chainsaw.counter = 2
		self.cl.chainsaw.blockDeplete = true
	end

	if self.player ~= sm.localPlayer.getPlayer() then return end

	local cameraState = 2 --looks bad in TP 		sm.localPlayer.isInFirstPersonView() and 2 or 3
	sm.camera.setCameraState( cameraState )
	local camDir = (args.targetPos + args.offset) - args.playerPos
	sm.camera.setDirection( camDir )
	self.cl.cameraMove.mode = "gk"
	self.cl.cameraMove.startDir = camDir
	self.cl.cameraMove.endDir = args.lookDir

	self.cl.cameraMove.startPos = args.playerPos + camPosDifference
	self.cl.cameraMove.endPos = args.targetPos + args.offset

	--correct camera position
	local heightAdjust = self.cl.cameraMove.startPos.z - self.cl.cameraMove.endPos.z --sm.util.clamp(math.abs(self.cl.cameraMove.startPos.z - self.cl.cameraMove.endPos.z), 0, 0.575)
	self.cl.cameraMove.endPos = self.cl.cameraMove.endPos + sm.vec3.new(0,0,heightAdjust)

	self.cl.cameraMove.speed = sm.util.clamp((args.targetDir):length() / gkDistanceDivider, gkMinSpeed, 69420)
	self.cl.cameraMove.active = true
end

function Player:cl_bloodPunch()
	if self.player == sm.localPlayer.getPlayer() then
		sm.camera.setShake( 0.1 )
	end

	self.cl.bloodPunchSound:start()
end

function Player:cl_flameEffect( toggle )
	if toggle then
		self.cl.flameThrowerEffect:start()
	else
		self.cl.flameThrowerEffect:stop()
	end
end

function Player:cl_chainsawEffect()
	self.cl.chainsaw.counter = 2
	self.cl.chainsaw.sound:start()
end

function Player:cl_e_eat( params )
	if self.player == sm.localPlayer.getPlayer() then
		self.cl.public.powerup.damageMultiplier.current = params.dmgMult ~= nil and self.cl.public.powerup.damageMultiplier.active or self.cl.public.powerup.damageMultiplier.default
		self.cl.public.powerup.speedMultiplier.current = params.spdMult ~= nil and self.cl.public.powerup.speedMultiplier.active or self.cl.public.powerup.speedMultiplier.default
		self.cl.public.powerup.berserk.current = params.berserk ~= nil and self.cl.public.powerup.berserk.active or self.cl.public.powerup.berserk.default
	end

	self:cl_refreshPrpColour()
	--self.player:setClientPublicData( self.cl.public )
end

function Player:cl_disablePrp( index )
	if self.player == sm.localPlayer.getPlayer() then
		self.cl.public.powerup[index].current = self.cl.public.powerup[index].default
	end

	self:cl_refreshPrpColour()
	--self.player:setClientPublicData( self.cl.public )
	--print(self.cl.public.powerup[index], index)
end

function Player:cl_refreshPrpColour()
	self.cl.powerup.colour = nil
	for k, powerup in pairs(self.player:getClientPublicData().powerup) do
		if powerup.current == powerup.active then
			self.cl.powerup.colour = powerup.colour
			break
		end
	end
end