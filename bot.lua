
local BOT				=	FindMetaTable( "Player" )

bots = {}
marker = nil

if SERVER then
    print("Server")
    
    
else
    print("Client")
end

local function IsVecCloseEnough( start , endpos , dist )
	
	return start:DistToSqr( endpos ) < dist * dist
	
end

function CreateMarker( ply, cmd, args ) 
    marker = ply:GetPos()
end

function TBotCreate( ply , cmd , args )
    print("New bot")

		
	local NewBot =	player.CreateNextBot( args[1] ) 
        -- Create the bot and store it in a varaible.
    NewBot.IsTutorialBot		=	true 
	NewBot.RoutineIndex = 1

	
	NewBot.IsBot		=	true 
        -- Flag this as our bot so we don't control other bots, Only ours!
	
	
	NewBot:TBotCreateNavTimer()
	NewBot:TBotResetAI() -- Fully reset your bots AI.
	

	NewBot.Jump = false
	
    function NewBot:Use( activator )

        if ( activator:IsPlayer() ) then 

            activator:Kill()

        end

    end

    table.insert(bots, NewBot)
    print(table.getn(bots) .. " bots in game.")
end

local rePathDelay = 1

local function OriginCam()
	local CamData = {}
	CamData.angles = Angle(90,LocalPlayer():EyeAngles().yaw,0)
	CamData.origin = LocalPlayer():GetPos()+Vector(0,0,500)
	CamData.x = 0
	CamData.y = 0
	CamData.w = ScrW() / 3
	CamData.h = ScrH() / 3
	render.RenderView( CamData )
end
hook.Add("HUDPaint", "OriginCam", OriginCam)

function BOT:TBotResetAI()
	
	local index		=	self:EntIndex()
	timer.Create( "Think" .. index , math.Rand( 0.08 , 0.15 ) , 0 , function()
		if self.IsAlive then
			timer.Remove( "tutorial_bot_think" .. index ) -- We don't need to think while dead.
			
		end
		
	end )

	local ply = player.GetHumans()[1]
	
	self.Goal = ply:GetPos()
	
    self.Enemy = nil

	
	hook.Add( "StartCommand" , "TutorialBotAIHook" , function( bot , cmd )
      
	
	if !IsValid( bot ) or !bot:IsBot() or !bot:Alive() or !bot.IsBot then return end
	
	
	cmd:ClearButtons() -- Clear the bots buttons. Shooting, Running , jumping etc...
	cmd:ClearMovement() -- For when the bot is moving around.

	local state = IN_SPEED
    
    local d = ply:GetPos():Distance( bot:GetPos() )
    if bot.Jump and d > 250 then
    	bot:SetJumpPower(200)
    	cmd:SetButtons( bit.bor( IN_DUCK, IN_JUMP) )
    	bot.Jump = false
    	--- cmd:SetForwardMove( 400 )
    	
    	timer.Create("idle_" .. index, 2, 0, function()
				
				bot.Duck = true
		end)
    elseif !bot.Jump and bot.Duck and d > 300  then
    	cmd:SetButtons( bit.bor( IN_DUCK ) )
    	bot.Duck = false
    else
    	cmd:SetButtons( state )
    end
    
	local MovementAngle		= ( ply:GetPos() - bot:GetPos() ):GetNormalized():Angle()
    
	-- MovementAngle.yaw = - MovementAngle.yaw
	cmd:SetViewAngles(MovementAngle)
	bot:SetEyeAngles( MovementAngle )
	
	
	local index		=	self:EntIndex()
 
    
    if d < 50 then
    	cmd:SetForwardMove( -100 )
    elseif d < 100 then
			timer.Create("idle_" .. index, 2, 1, function()
				
				if !bot:IsValid() then
					return
				end
			end)
	elseif d < 200 then
		timer.Remove("idle_" .. index) -- We don't need to think while dead.
		cmd:SetForwardMove( 100 )
	else
		timer.Remove("idle_" .. index) -- We don't need to think while dead.
		cmd:SetForwardMove( 300 )
	end
	
	

	end)
end

concommand.Add( "newbot" , TBotCreate )
concommand.Add( "marker" , CreateMarker )

hook.Add( "PlayerDeath" , "BotDied" , function( ply )
	
	if ply:IsBot() and ply.IsTutorialBot then 
		
		print(ply:GetName() .. " died")
		
	end
	
end)

hook.Add( "PlayerSay" , "PlayerChat" , function( ply, text )
	if string.find(text, "hey") or text == "hey" then
            for k, v in pairs(bots) do
                v:Say("Hello")
            end

    end
        
    return true
end)

hook.Add( "PlayerDisconnected", "Playerleave", function(ply)
    print(ply:GetName() .. " left")
    for k, v in pairs(bots) do
        if (v:GetName() == ply:GetName()) then
            table.remove(bots, k)
            break
        end
    end
    
    print(table.getn(bots) .. " bots in game.")
end )

function BOT:TBotNavigation()

	print("Bot navigation")
	if !isvector( self.Goal ) then return end -- A double backup!
	
	-- The CNavArea we are standing on.
	self.StandingOnNode			=	navmesh.GetNearestNavArea( self:GetPos() )
	if !IsValid( self.StandingOnNode ) then return end -- The map has no navmesh.
	
	
	if !istable( self.Path ) or !istable( self.NavmeshNodes ) or table.IsEmpty( self.Path ) or table.IsEmpty( self.NavmeshNodes ) then
		
		
		if self.BlockPathFind != true then
			
		
			-- Get the nav area that is closest to our goal.
			local TargetArea		=	navmesh.GetNearestNavArea( self.Goal )
			
			self.Path				=	{} -- Reset that.
			
			-- Find a path through the navmesh to our TargetArea
			self.NavmeshNodes		=	TutorialBotPathfinder( self.StandingOnNode , TargetArea )
			
			
			-- Prevent spamming the pathfinder.
			self.BlockPathFind		=	true
			timer.Simple( 0.25 , function()
				
				if IsValid( self ) then
					
					self.BlockPathFind		=	false
					
				end
				
			end)
			
			
			-- Give the computer some time before it does more expensive checks.
			timer.Simple( 0.03 , function()
				
				-- If we can get there and is not already there, Then we will compute the visiblilty.
				if IsValid( self ) and istable( self.NavmeshNodes ) then
					
					self.NavmeshNodes	=	table.Reverse( self.NavmeshNodes )
					
					self:ComputeNavmeshVisibility()
					
				end
				
			end)
			
			
			-- There is no way we can get there! Remove our goal.
			if self.NavmeshNodes == false then
				
				self.Goal		=	nil
				
				return
			end
			
			
		end
		
		
	end
	local function IsVecCloseEnough( start , endpos , dist )
	
	return start:DistToSqr( endpos ) < dist * dist
	
end
	
	if istable( self.Path ) then
		
		if self.Path[0] then
			
			local Waypoint2D		=	Vector( self.Path[0].x , self.Path[0].y , self:GetPos().z )
			-- ALWAYS: Use 2D navigation, It helps by a large amount.
			
			if self.Path[0] and IsVecCloseEnough( self:GetPos() , Waypoint2D , 600 ) and SendBoxedLine( self.Path[0] , self:GetPos() + Vector( 0 , 0 , 15 ) ) == true and self.Path[0].z - 20 <= Waypoint2D.z then
				
				table.remove( self.Path , 1 )
				
			elseif IsVecCloseEnough( self:GetPos() , Waypoint2D , 24 ) then
				
				table.remove( self.Path , 1 )
				
			end
			
		end
		
	end
	
	
end

function BOT:TBotDebugWaypoints()
	if !istable( self.Path ) then return end
	if table.IsEmpty( self.Path ) then return end
	
	debugoverlay.Line( self.Path[0] , self:GetPos() + Vector( 0 , 0 , 44 ) , 0.08 , Color( 0 , 255 , 255 ) )
	debugoverlay.Sphere( self.Path[0] , 8 , 0.08 , Color( 0 , 255 , 255 ) , true )
	
	for k, v in ipairs( self.Path ) do
		
		if self.Path[v] then
			
			debugoverlay.Line( v , self.Path[v] , 0.08 , Color( 255 , 255 , 0 ) )
			
		end
		
		debugoverlay.Sphere( v , 8 , 0.08 , Color( 255 , 200 , 0 ) , true )
		
	end
	
end


function BOT:TBotCreateNavTimer()
	
	local index				=	self:EntIndex()
	local LastBotPos		=	self:GetPos()
	
	
	
	timer.Create( "tutorialbot_nav" .. index , 0.09 , 0 , function()
		print(self.Goal)
		
		if IsValid( self ) and self:Alive() and isvector( self.Goal ) then
			
			
			
			self:TBotNavigation()
			
			self:TBotDebugWaypoints()
			
			LastBotPos		=	Vector( LastBotPos.x , LastBotPos.y , self:GetPos().z )
			
			if IsVecCloseEnough( self:GetPos() , LastBotPos , 2 ) then
				
				self.Path	=	nil
				-- TODO/Challange: Make the bot jump a few times, If that does not work. Then recreate the path.
				self.Jump = true
				
			end
			LastBotPos		=	self:GetPos()
			
		else
			
			timer.Remove( "tutorialbot_nav" .. index )
			
		end
		
	end)
	
end

