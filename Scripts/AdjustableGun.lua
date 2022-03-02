AdjustableGun = class()
AdjustableGun.maxParentCount = 2
AdjustableGun.maxChildCount = 0
AdjustableGun.connectionInput = bit.bor( sm.interactable.connectionType.logic, sm.interactable.connectionType.ammo )
AdjustableGun.connectionOutput = sm.interactable.connectionType.none
AdjustableGun.colorNormal = sm.color.new( "#34f5ff" )
AdjustableGun.colorHighlight = sm.color.new( "#11f5ff" )
AdjustableGun.poseWeightCount = 1

fellowGuns = {}

templates = {}

local projectileTypes = {
	{ name = "Potato", projectile = "potato" },
	{ name = "Small Potato", projectile = "smallpotato" },
	{ name = "Fries", projectile = "fries" },
	{ name = "Tape", projectile = "tape" },
	{ name = "Explosive Tape", projectile = "explosivetape" },
	{ name = "Water", projectile = "water" },
	{ name = "Pesticide", projectile = "pesticide" },
	{ name = "Glowstick", projectile = "glowstick" }
}

function AdjustableGun:sv_save()
	self.storage:save(self.data)
end

function AdjustableGun.server_onCreate( self )
	self:sv_init()

	self.gunId = #fellowGuns+1
	fellowGuns[self.gunId] = self.interactable
end

function AdjustableGun.server_onRefresh( self )
	self:sv_init()
end

function AdjustableGun.sv_init( self )
	self.sv = {}
	self.sv.fireDelayProgress = 0
	self.sv.canFire = true
	self.sv.parentActive = false

	self.data = self.storage:load()
	if self.data == nil then
		self.data = {
			type = 1,
			damage = 28,
			shots = 1,
			spread = 1,
			delay = 8,
			fireForce = 130,
			fullAuto = false,
			templateCount = 0,
			controlled = false,
			isTemplate = false
		}
	end

	self.canSwitch = true
end


function AdjustableGun.server_onFixedUpdate( self, timeStep )
	if self.data.isTemplate and self.data ~= self.interactable:getPublicData() then
		sm.interactable.setPublicData( self.interactable, { name = tostring(self.gunId), data = self.data } )
	end

	if self.interactable == fellowGuns[1] then
		templates = {}

		for v, gun in pairs(fellowGuns) do
			if sm.exists(gun) then
				templates[#templates+1] = gun:getPublicData()
			end
		end
	end

	if #templates > 0 then
		if self.data.templateCount > 0 and not self.data.isTemplate then
			local data = templates[self.data.templateCount].data
			self.data = {
				type = data.type,
				damage = data.damage,
				shots = data.shots,
				spread = data.spread,
				delay = data.delay,
				fireForce = data.fireForce,
				fullAuto = data.fullAuto,
				templateCount = self.data.templateCount,
				controlled = true,
				isTemplate = false
			}
		else
			self.data.controlled = false
		end
	end

	if not self.sv.canFire then
		self.sv.fireDelayProgress = self.sv.fireDelayProgress + 1
		if self.sv.fireDelayProgress >= self.data.delay then
			self.sv.fireDelayProgress = 0
			self.sv.canFire = true
		end
	end
	self:sv_tryFire()
	local logicInteractables, _ = self:getInputs()
	if logicInteractables[1] then
		self.sv.parentActive = logicInteractables[1]:isActive()
	end

	if logicInteractables[2] then
		if logicInteractables[2]:isActive() and self.canSwitch then
			self.canSwitch = false
			self.network:sendToClients("cl_template")
		elseif not logicInteractables[2]:isActive() and not self.canSwitch then
			self.canSwitch = true
		end
	end
end

function AdjustableGun:client_onFixedUpdate( dt )
	self.cl.shootEffect = self.effects[self.data.type]
	local rot = self.shape:getWorldRotation()
	local offset = (projectileTypes[self.data.type].projectile == "potato" or projectileTypes[self.data.type].projectile == "water") and sm.vec3.zero() or rot * sm.vec3.new( 0, 0.6, 0 )
	self.cl.shootEffect:setOffsetPosition( offset )
end

function AdjustableGun.sv_tryFire( self )
	local logicInteractables, ammoInteractable = self:getInputs()
	local active = logicInteractables[1] and logicInteractables[1]:isActive() or false
	local ammoContainer = ammoInteractable and ammoInteractable:getContainer( 0 ) or nil
	local freeFire = not sm.game.getEnableAmmoConsumption() and not ammoContainer

	if freeFire then
		if active and (self.data.fullAuto or not self.sv.parentActive) and self.sv.canFire then
			self:sv_fire()
		end
	else
		if active and (self.data.fullAuto or not self.sv.parentActive) and self.sv.canFire and ammoContainer then
			sm.container.beginTransaction()
			sm.container.spend( ammoContainer, obj_plantables_potato, 1 )
			if sm.container.endTransaction() then
				self:sv_fire()
			end
		end
	end
end

function AdjustableGun.sv_fire( self )
	self.sv.canFire = false
	local firePos = sm.vec3.new( 0.0, 0.0, 0.375 )
	--local MinForce = 125.0
	--local MaxForce = 135.0
	--local fireForce = math.random( MinForce, MaxForce )

	for i = 1, self.data.shots do
		local dir = sm.noise.gunSpread( sm.vec3.new( 0.0, 0.0, 1.0 ), self.data.spread )
		sm.projectile.shapeProjectileAttack( projectileTypes[self.data.type].projectile, self.data.damage, firePos, dir * self.data.fireForce, self.shape )
	end

	self.network:sendToClients( "cl_onShoot" )
end

function AdjustableGun.client_onCreate( self )
	self.gui = sm.gui.createGuiFromLayout( "$CONTENT_d9e6682a-1885-44b2-9cda-11bf5fec9dac/Gui/AdjustableGun.layout" )
	self.gui:setButtonCallback( "projType", "cl_projType" )
	self.gui:setButtonCallback( "fullAuto", "cl_fullAuto" )
	self.gui:setButtonCallback( "dmgInc", "cl_dmg" )
	self.gui:setButtonCallback( "dmgDec", "cl_dmg" )
	self.gui:setButtonCallback( "sprdInc", "cl_sprd" )
	self.gui:setButtonCallback( "sprdDec", "cl_sprd" )
	self.gui:setButtonCallback( "rldInc", "cl_rld" )
	self.gui:setButtonCallback( "rldDec", "cl_rld" )
	self.gui:setButtonCallback( "projInc", "cl_proj" )
	self.gui:setButtonCallback( "projDec", "cl_proj" )
	self.gui:setButtonCallback( "velInc", "cl_vel" )
	self.gui:setButtonCallback( "velDec", "cl_vel" )

	self.gui:setButtonCallback( "template", "cl_template")

	self.effect = sm.effect.createEffect( "Template Highlight", self.interactable )
	self.idGUI = sm.gui.createNameTagGui()

	self.effects = {
		sm.effect.createEffect( "MountedPotatoRifle - Shoot", self.interactable ),
		sm.effect.createEffect( "SpudgunSpinner - SpinnerMuzzel", self.interactable ),
		sm.effect.createEffect( "SpudgunFrier - FrierMuzzel", self.interactable ),
		sm.effect.createEffect( "TapeBot - Shoot", self.interactable ),
		sm.effect.createEffect( "TapeBot - Shoot", self.interactable ),
		sm.effect.createEffect( "Mountedwatercanon - Shoot", self.interactable ),
		sm.effect.createEffect( "Farmbot - Shoot", self.interactable ),
		sm.effect.createEffect( "Glowstick - Throw", self.interactable )
	}

	self.cl = {}
	self.cl.boltValue = 0.0
	self.cl.shootEffect = self.effects[1]
end

function AdjustableGun:cl_projType(button)
	if not self.data.controlled then
		self.data.type = self.data.type < #projectileTypes and self.data.type + 1 or 1
		self.network:sendToServer("sv_save")
	end
end

function AdjustableGun:cl_fullAuto(button)
	if not self.data.controlled then
		self.data.fullAuto = not self.data.fullAuto
		self.network:sendToServer("sv_save")
	end
end

function AdjustableGun:cl_dmg(button)
	if not self.data.controlled then
		if button == "dmgInc" then
			self.data.damage = self.data.damage + 1
		elseif button == "dmgDec" and self.data.damage > 0 then
			self.data.damage = self.data.damage - 1
		end
		self.network:sendToServer("sv_save")
	end
end

function AdjustableGun:cl_sprd(button)
	if not self.data.controlled then
		if button == "sprdInc" then
			self.data.spread = self.data.spread + 1
		elseif button == "sprdDec" and self.data.spread > 0 then
			self.data.spread = self.data.spread - 1
		end
		self.network:sendToServer("sv_save")
	end
end

function AdjustableGun:cl_rld(button)
	if not self.data.controlled then
		if button == "rldInc" then
			self.data.delay = self.data.delay + 1
		elseif button == "rldDec" and self.data.delay > 0 then
			self.data.delay = self.data.delay - 1
		end
		self.network:sendToServer("sv_save")
	end
end

function AdjustableGun:cl_proj(button)
	if not self.data.controlled then
		if button == "projInc" then
			self.data.shots = self.data.shots + 1
		elseif button == "projDec" and self.data.shots > 1 then
			self.data.shots = self.data.shots - 1
		end
		self.network:sendToServer("sv_save")
	end
end

function AdjustableGun:cl_vel(button)
	if not self.data.controlled then
		if button == "velInc" then
			self.data.fireForce = self.data.fireForce + 10
		elseif button == "velDec" and self.data.fireForce > 0 then
			self.data.fireForce = self.data.fireForce - 10
		end
		self.network:sendToServer("sv_save")
	end
end

function AdjustableGun:cl_template()
	if #templates > 0 and not self.data.isTemplate then
		self.data.templateCount = self.data.templateCount < #templates and self.data.templateCount + 1 or 0
		if self.data.templateCount == 0 then
			self.data = {
				type = 1,
				damage = 28,
				shots = 1,
				spread = 1,
				delay = 8,
				fireForce = 130,
				fullAuto = false,
				templateCount = 0,
				controlled = false,
				isTemplate = false
			}
		end

		self.network:sendToServer("sv_save")
	else
		sm.gui.displayAlertText("Cant find any templates!", 2.5)
		sm.audio.play("RaftShark")
	end
end

function AdjustableGun:client_canInteract()
	sm.gui.setInteractionText( "", sm.gui.getKeyBinding( "Use" ), "Tune gun settings" )
	sm.gui.setInteractionText( "", sm.gui.getKeyBinding( "Tinker" ), "Create template" )

    return true
end

function AdjustableGun:client_onInteract( char, lookAt )
	if lookAt then
		self.gui:open()
	end
end

function AdjustableGun:client_onTinker( character, lookAt )
	if lookAt then
		if not self.data.controlled and not self.data.isTemplate then
			self.data.isTemplate = true
			sm.gui.displayAlertText("Template of this spudgun has been created!", 2.5)
			self.network:sendToServer("sv_save")
			self.effect:start()
		else
			sm.gui.displayAlertText("Cant create template!", 2.5)
			sm.audio.play("RaftShark")
		end
	end
end

function AdjustableGun.client_onUpdate( self, dt )
	if self.data.isTemplate then
		self.idGUI:setText("Text", "Template id: #ff9d00"..tostring(self.gunId))
		self.idGUI:setWorldPosition(self.shape:getWorldPosition() + sm.vec3.new(0,0,0.5))
		self.idGUI:open()
	end

	if self.gui:isActive() then
		self.gui:setText("projType", projectileTypes[self.data.type].name)
		self.gui:setText("projCount", tostring(self.data.shots))
		self.gui:setText("dmg", tostring(self.data.damage))
		self.gui:setText("spread", tostring(self.data.spread))
		self.gui:setText("reload", tostring(self.data.delay))
		self.gui:setText("velocity", tostring(self.data.fireForce))

		local txt = self.data.fullAuto and "#269e44ON" or "#9e2626OFF"
		self.gui:setText("fullAuto", txt)

		if not self.data.isTemplate then
			local txt = #templates > 0 and self.data.templateCount > 0 and templates[self.data.templateCount].name or "none"
			self.gui:setText("template", txt)
		else
			self.gui:setText("template", "#9e2626DISABLED")
			self.gui:setVisible("template", true)
		end
	end

	if self.data.isTemplate and not self.effect:isPlaying() then
		self.effect:start()
	end

	if self.effect:isPlaying() then
		local minColor = sm.color.new( 0.0, 0.0, 0.25, 0.1 )
		local maxColor = sm.color.new( 0.0, 0.3, 0.75, 1 )
		self.effect:setParameter( "minColor", minColor )
		self.effect:setParameter( "maxColor", maxColor )

		self.effect:setScale(sm.vec3.new(0.25,0.25,0.25)) --why doesnt the effect get scaled correctly by default? lol
		self.effect:setOffsetPosition( sm.vec3.new( 0.0, 0.0, 0.016 ) )
	end

	if self.cl.boltValue > 0.0 then
		self.cl.boltValue = self.cl.boltValue - dt * 10
	end
	if self.cl.boltValue ~= self.cl.prevBoltValue then
		self.interactable:setPoseWeight( 0, self.cl.boltValue )
		self.cl.prevBoltValue = self.cl.boltValue
	end
end

function AdjustableGun.client_getAvailableParentConnectionCount( self, connectionType )
	if bit.band( connectionType, sm.interactable.connectionType.logic ) ~= 0 then
		return self.maxParentCount - #self.interactable:getParents( sm.interactable.connectionType.logic )
	end
	if bit.band( connectionType, sm.interactable.connectionType.ammo ) ~= 0 then
		return 1 - #self.interactable:getParents( sm.interactable.connectionType.ammo )
	end
	return 0
end

function AdjustableGun.cl_onShoot( self )
	self.cl.boltValue = 1.0
	self.cl.shootEffect:start()
	local impulse = sm.vec3.new( 0, 0, -1 ) * 500
	sm.physics.applyImpulse( self.shape, impulse )
end

function AdjustableGun.getInputs( self )
	local logicInteractables = { nil, nil }
	local ammoInteractable = nil
	--local parents = self.interactable:getParents()

	for v, parent in pairs(self.interactable:getParents()) do
		if parent:hasOutputType( sm.interactable.connectionType.logic ) then
			if logicInteractables[1] == nil then
				logicInteractables[1] = parent
			else
				logicInteractables[2] = parent
			end
		elseif parent:hasOutputType( sm.interactable.connectionType.ammo ) then
			ammoInteractable = parent
		end
	end

	--[[if parents[2] then
		if parents[2]:hasOutputType( sm.interactable.connectionType.logic ) then
			logicInteractable = parents[2]
		elseif parents[2]:hasOutputType( sm.interactable.connectionType.ammo ) then
			ammoInteractable = parents[2]
		end
	end
	if parents[1] then
		if parents[1]:hasOutputType( sm.interactable.connectionType.logic ) then
			logicInteractable = parents[1]
		elseif parents[1]:hasOutputType( sm.interactable.connectionType.ammo ) then
			ammoInteractable = parents[1]
		end
	end]]

	return logicInteractables, ammoInteractable
end

function AdjustableGun:client_onDestroy()
	self.idGUI:close()
	self.gui:close()

	self.idGUI:destroy()
	self.gui:destroy()
end

function AdjustableGun:server_onDestroy()
	fellowGuns[self.gunId] = nil
end