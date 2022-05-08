Grenade = class()

function Grenade:server_onCreate()
	self.countdownActive = false
	self.countdown = 2
end

function Grenade:server_onFixedUpdate( dt )
	if self.countdownActive then
		self.countdown = self.countdown - dt
		if self.countdown <= 0 then
			self:sv_destroy()
		end
	end
end

function Grenade:server_onCollision( other, pos, velocity, otherVelocity, normal )
	self.countdownActive = true
end

function Grenade:sv_destroy()
	sm.physics.explode( self.shape:getWorldPosition(), 4, 5, 5.5, 20, "PropaneTank - ExplosionSmall" )
	self.shape:destroyPart()
end