MAX_BUILDING_QUEUE = 6
BUILDING_THINK = 0.01



if BuildingQueue == nil then
	print ('[BUILDINGQUEUE] creating BuildingQueue')
	_G.BuildingQueue = class({})
end

if RallyPoints == nil then
	print ('[RALLYPONTS] creating RallyPoints')
	_G.RallyPoints = class({})
end

function RallyPoints:PlayerSetRallyPointGround( event )
	local building = EntIndexToHScript(event.entIndex)
	local rallyPoint = event.targetPoint
	building:SetRallyPointGround(rallyPoint)
end

function RallyPoints:PlayerSetRallyPointEntity( event )
	local building = EntIndexToHScript(event.entIndex)
	local targetEntity = EntIndexToHScript(event.targetEntity)
	building:SetRallyPointEntity(targetEntity)
	--print("Target is:", targetEntity:GetUnitName())
end

function RallyPoints:PlayerRemovedRallyPoint( event )
	local building = EntIndexToHScript(event.entIndex)
	building:RemoveRallyPoint()
end

function RallyPoints:AttachRallyPointControl( building )

	-- Initial location of rally point is on the building itself
	local owner = building:GetOwner()
	building['RallyPoint'] = {}
	building['RallyPoint'].rallySet = false
	building['RallyPoint'].TargetRally = false
	building['RallyPoint'].GroundRally = false
	
	function building:SetRallyPointGround(location) -- Coordinates passed from PlayerSetRallyPoint		
	
		building['RallyPoint'].GroundRally = true
		building['RallyPoint'].TargetRally = false
		
		building['RallyPoint'].position = Vector(location["0"], location["1"], location["2"])
		--print("Vector:", building['RallyPoint'].position)
		building['RallyPoint'].rallySet = true 
	end
	
	function building:SetRallyPointEntity(unitHandle)
		
		building['RallyPoint'].TargetRally = true
		building['RallyPoint'].GroundRally = false
		
		building['RallyPoint'].targetEntity = unitHandle
		building['RallyPoint'].rallySet = true
	end
	
	function building:RemoveRallyPoint()
		building['RallyPoint'].TargetRally = false
		building['RallyPoint'].GroundRally = false
		building['RallyPoint'].position = building:GetAbsOrigin()
	end
	
	
	function building:MoveToRallyPoint(unit)
		
		if building['RallyPoint'].GroundRally == true then
			local order = {UnitIndex = unit:entindex(), OrderType = DOTA_UNIT_ORDER_MOVE_TO_POSITION, Position = building['RallyPoint'].position,	 Queue = true}
			ExecuteOrderFromTable(order)
		elseif building['RallyPoint'].TargetRally == true then
			print("Moving to ", building['RallyPoint'].targetEntity:GetUnitName(), building['RallyPoint'].targetEntity:entindex())
			local order = {UnitIndex = unit:entindex(), OrderType = DOTA_UNIT_ORDER_MOVE_TO_TARGET, TargetIndex = building['RallyPoint'].targetEntity:entindex(),	Queue = true}
			ExecuteOrderFromTable(order)
		end
		
		
		
	end
	
	function building:MoveToRallyPointEntity(unit)
		
		local order = {UnitIndex = unit:entindex(),
									 OrderType = DOTA_UNIT_ORDER_MOVE_TO_POSITION,
									 Position = building['RallyPoint'].position,
									 Queue = true}
		
		ExecuteOrderFromTable(order)
		
	end	
	

end



function BuildingQueue:InitializeBuildingEntity( building )

	local owner = building:GetOwner()
	
	if FindUnitLabel(building, "CanRally") then
		RallyPoints:AttachRallyPointControl( building )
	end
		
	
	building.queueCancelled = false
	building.IsBuilding = true;
	building.state = "Not Building"
	table.insert(owner['structures'], building)
	
	--print("Queue created for: ", buildingName)
	building['Queue'] = {}
	building['RUSlot'] = {}
	
	-- Queue slot flags for Research and Upgrade
	-- These flags will handle queue behavior for Researchs and Upgrades
	building['RUSlot'][1] = false;
	building['RUSlot'][2] = false;
	building['RUSlot'][3] = false;
	building['RUSlot'][4] = false;
	building['RUSlot'][5] = false;
	building['RUSlot'][6] = false;
	
	for buildingAbilities,_ in pairs(owner['QueueTrack']) do
		local buildingAbility = building:FindAbilityByName(buildingAbilities)
		if buildingAbility ~= nil then
			if owner['QueueTrack'][buildingAbilities].inQueue == true then
				buildingAbility:SetHidden(true)
			end
		end
	end

	function building:AddToQueue( abilityName, queueTime, queueType, whatToQueue )

		local queueTable = {whatToQueue = whatToQueue, queueTime = queueTime, abilityName = abilityName, queueType = queueType}
		
		if #building['Queue'] < MAX_BUILDING_QUEUE then
			table.insert(building['Queue'], queueTable)
			if queueType == ("Upgrade" or "Research") then
				owner['QueueTrack'][abilityName] = abilityName;
				owner['QueueTrack'][abilityName] = {};
				owner['QueueTrack'][abilityName].inQueue = true;
				ShowHideOrRemoveAbility(owner, abilityName, building['Queue'][1].whatToQueue)
			end
			CustomGameEventManager:Send_ServerToPlayer( owner, "add_to_queue", { queueTime = queueTime, abilityName = abilityName, entindex = building:entindex() })
			if building.state == "Not Building" then
				--print ("Starting queue")
				building:StartQueue(queueTime, queueType, abilityName)
			end
		else
			print("MAX QUEUE LIMIT REACHED!")
		end
	end
	
	function building:StartQueue( queueTime, queueType, abilityName )

		local currentGameTime = GameRules:GetGameTime();
		local endTime = building['Queue'][1].queueTime + currentGameTime
		print(queueType ,building['Queue'][1].whatToQueue, "has started, it will be finished in ", queueTime, " seconds.")
		building.state = "Building"
		CustomGameEventManager:Send_ServerToPlayer( owner, "show_timer", { queueTime = queueTime, currentGameTime = currentGameTime, index = building:entindex() })
	
		building:SetThink(function()
			local v = endTime - GameRules:GetGameTime()
			if building:IsAlive() then
				if v > 0 and building.queueCancelled ~= true and IsValidEntity(building) then
					return BUILDING_THINK
				elseif building.queueCancelled ~= true then
					if queueType == "Unit" then
						SpawnUnit(building['Queue'][1].whatToQueue, building, owner )
					elseif queueType == "Research" then
						UnlockResearch()
					elseif queueType =="Upgrade" then
						local upgradeName = building['Queue'][1].whatToQueue
						UpdatePlayerUpgrades( owner, building['Queue'][1].whatToQueue, abilityName )
					else	
						print("QueueType not specified... Breaking")
						return;
					end
					local x = table.remove(building['Queue'], 1)
					CustomGameEventManager:Send_ServerToPlayer( owner, "remove_from_queue", { entindex = building:entindex() })
					if #building['Queue'] > 0 then
						building:StartQueue( building['Queue'][1].queueTime, building['Queue'][1].queueType, building['Queue'][1].abilityName )
						return BUILDING_THINK
					else
						building.state = "Not Building"
						return nil
					end
				else
					building.queueCancelled = false
					if #building['Queue'] > 0 then
						return BUILDING_THINK
					else
						return nil
					end
				end	
			else
			 return nil
			end
		end)
	end
	
		
	function building:DestroyQueueTimer()
		building.queueCancelled = true
		if #building['Queue'] > 0 then
				building:StartQueue( building['Queue'][1].queueTime, building['Queue'][1].queueType )
				CustomGameEventManager:Send_ServerToPlayer( owner, "update_timer", { entindex = building:entindex() })
		else
			building.state = "Not Building"
			CustomGameEventManager:Send_ServerToPlayer( owner, "change_timer_state", { entindex = building:entindex() })
		return;
		end
	end
	
	function building:HideAbility( abilityName )
		local ability = building:FindAbilityByName(abilityName)
		if ability ~= nil then
			ability:SetHidden(true)
		end	
	end	
	
	function building:ShowAbility( abilityName )
		local ability = building:FindAbilityByName(abilityName)
		if ability ~= nil then
			ability:SetHidden(false)
		end
	end
	
	function building:RemoveAbility( abilityName )
		local ability = building:FindAbilityByName(abilityName)
		if ability ~= nil then
			ability:SetHidden(true)
			building:RemoveAbility(abilityName)
		end
	end
end