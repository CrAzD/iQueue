--[[------------------------------------------------------------------------------
	SETUP
------------------------------------------------------------------------------]]--
if EntityManagement == nil then
	_G.EntityManagement = class({})
end


EntityManagement['version'] = '0.008'
EntityManagement['github'] = 'https://github.com/CrAzD/DotaEntityManager'
EntityManagement['description'] = 'An entity management library.'
print('\n\tEntityManagement:  '..EntityManagement['description']..'\n\t\tVersion:  '..EntityManagement['version']..'\n\t\tGithub URL:  '..EntityManagement['github']..'\n\t\tLibrary Initialized.\n')


ListenToGameEvent('npc_spawned', Dynamic_Wrap(EntityManagement, 'OnNpcSpawned'), EntityManagement)
ListenToGameEvent('entity_killed', Dynamic_Wrap(EntityManagement, 'OnEntityKilled'), EntityManagement)



--[[------------------------------------------------------------------------------
	EVENTS
------------------------------------------------------------------------------]]--
function EntityManagement:OnNpcSpawned(data)
	local entity = EntIndexToHScript(data['entindex'])
	if entity:GetOwner() == nil then
		return
	end
end


function EntityManagement:OnEntityKilled(data)
	local killed = EntIndexToHScript(data['entindex_killed'])
	local attacker = EntIndexToHScript(data['entindex_attacker']) or nil
end


function EntityManagement:OnPlayerPickHero(data)
	local player = EntityManagement:SetupPlayer(data['player'])
	if player == nil then
		return
	else
		local unit = EntIndexToHScript(data['heroindex'])
		if player['hero'] == nil then
			if unit['name'] ~= nil and unit['name'] ~= 'npc_dota_hero_wisp' then
				player['hero'] = unit
			end
		end

		if player['team'] == 3 and GameMode and GameMode['TITAN'] == nil then
			GameMode['TITAN'] = unit
		end
	end
end


--[[------------------------------------------------------------------------------
	FUNCTIONS
------------------------------------------------------------------------------]]--
function EntityManagement:CreateEntity(entity, player)
	if type(entity) ~= 'table' then
		print('[ENTITY MANAGEMENT]  entity argument must be a table.')

		return(nil)
	elseif type(player) ~= 'table' then
		print('[ENTITY MANAGEMENT]  player argument must be a table.')

		return(nil)
	elseif type(entity['name']) ~= 'string' then
		print('[ENTITY MANAGEMENT]  entity[\'name\'] is either missing or not an string.')

		return(nil)
	elseif type(entity['type']) ~= 'string' then
		print('[ENTITY MANAGEMENT]  entity[\'type\'] is either missing or not an string.')

		return(nil)
	elseif type(entity['handle']) ~= 'table' then
		print('[ENTITY MANAGEMENT]  entity[\'handle\'] is either missing or not a table.')

		return(nil)
	elseif type(entity['team']) ~= 'integer' then
		print('[ENTITY MANAGEMENT]  entity[\'team\'] is either missing or not an integer.')

		return(nil)
	else
		if string.find(entity['type'], 'unit') then
			local unit = CreateUnitByName(entity['name'], entity['spawnCords'], true, entity['handle'], player, entity['team'])

			unit['owners'] = {['entity'] = entity['handle'], ['player'] = player}
			unit['unitType'] = entity['type']

			return(EntityManagement:EntityConfiguration(unit, player))	
		elseif string.find(entity['type'], 'dummy') then
			return(CreateUnitByName(entity['name'], entity['spawnCords'], false, player['handle'], player, entity['team']))		
		elseif string.find(entity['type'], 'tavern') then
			local unit = CreateUnitByName(entity['name'], entity['spawnCords'], true, player['handle'], player, entity['team'])
			unit:SetAbilityPoints(0)

			if entity['team'] == 2 then
				for i=0, (GameMode.BUILDER_COUNT - 1) do
					unit:AddAbility(GameMode.BUILDER_SELECTION_ABILITY_LIST[i])
					unit:FindAbilityByName(GameMode.BUILDER_SELECTION_ABILITY_LIST[i]):SetLevel(1)
				end
			else
				unit:AddAbility('pick_titan_moltenious')
				unit:FindAbilityByName('pick_titan_moltenious'):SetLevel(1)
			end

			return(unit)

		else
			print('\n\nERROR: unitType argument error. \n\tunitType is invalid. Make sure your spelling is correct, if so make sure you have a check for that unitType. \n\tAlso, you can combine unit types together. \n\tExamples: \n\t\t\'unit\' \n\t\t\'unitpeasant\' or \'unit-peasant\' \n\t\t\'unithero\' or \'unit hero\' \n\t\t\'unit-building\'')

			return(nil)
		end
	end
end


function EntityManagement:EntityConfiguration(entity, player)
	entity['isHero'] = entity['isHero'] or false
	entity['isBuilding'] = entity['isBuilding'] or false
	entity['type'] = entity['type'] or 'unit'
	entity['id'] = entity['id'] or entity:GetOwner():GetPlayerID()
	entity['name'] = entity['name'] or entity:GetUnitName()
	entity['team'] = entity['team'] or entity:GetTeam()
	entity['handle'] = entity['handle'] or entity:GetEntityHandle()
	entity['hullRadius'] = entity['hullRadius'] or entity:GetHullRadius()
	entity['index'] = entity['index'] or entity:GetEntityIndex()
	entity['original'] = {['id'] = entity['id'], ['player'] = player}
	entity['vector'] = entity['vector'] or entity:GetAbsOrigin()
	entity['x'] = entity.vector['x']
	entity['y'] = entity.vector['y']
	entity['z'] = entity.vector['z']
	entity['origin'] = entity['vector']
	entity['owners'] = entity['owners'] or {['entity'] = entity:GetOwnerEntity(), ['player'] = player}
	entity['unitType'] = entity['unitType'] or entity['name']
	entity['queue'] = {}
	entity['inventory'] = {}

	if entity['team'] == 2 then
		entity['teamName'] = 'builder'
	elseif entity['team'] == 3 then
		entity['teamName'] = 'titan'
	end

	entity['ability'] = {['list'] = {}, ['count'] = -1}
	for i=0, 15 do
		local abi = entity:GetAbilityByIndex(i)
		if type(abi) == 'table' then
			entity.ability['count'] = entity.ability['count'] + 1

			abi:SetLevel(1)
			abi['cost'] = abi:GetGoldCost(-1)
			abi['name'] = abi:GetAbilityName()
			abi['caster'] = entity
			abi['position'] = entity.ability['count']

			entity.ability[entity.ability['count']] = abi
			entity.ability[abi['name']] = abi
			entity.ability.list[entity.ability['count']] = abi
		end
	end

	if string.find(entity['unitType'], 'hero') then
		if entity['abilityPoints'] then
			entity:SetAbilityPoints(entity['abilityPoints'])
		else
			entity:SetAbilityPoints(0)
		end
		entity['isHero'] = true
		entity['type'] = 'hero'
	end

	if string.find(entity['unitType'], 'building') then
		entity['isBuilding'] = true
		entity['construction'] = {}
	end

	if string.find(entity['unitType'], 'peasant') then
		entity['harvest'] = 0
		entity['sheltersNearby'] = {}
		entity['shelter'] = entity.owners['unit']

		entity:SetHullRadius(20)
		entity.ability['harvest'] = entity.ability['harvest_lumber_base']
		entity.ability['deposit_lumber']:ApplyDataDrivenModifier(entity, entity, 'modifier_has_lumber', nil)
	end

	FindClearSpaceForUnit(entity, entity['origin'], true)
	entity:SetHullRadius(entity['hullRadius'])
	entity:SetControllableByPlayer(entity['id'], true)

	if type(player['entities']) == 'table' then
		entity['positionInPlayerEntityList'] = #player['entities']
		player['entities'][entity['positionInPlayerEntityList']] = entity
	end

	entity['isConfigured'] = true

	return(entity)
end


function EntityManagement:EntityDestroy(entity)
	if type(entity) ~= 'table' then
		print('[ENTITY MANAGEMENT]  entity argument must be a table.')

		return(false)
	elseif entity:IsNull() then
		print('[ENTITY MANAGEMENT]  entity doesn\'t exist.')

		return(false)
	else
		entity:Destroy()
		entity.owners.player.entities['positionInPlayerEntityList'] = nil
	end
end


function EntityManagement:HeroReplace(entityNewName, player)
	local unit = PlayerResource:ReplaceHeroWith(player['id'], entityNewName, 0, 0)
	unit['isHero'] = true
	unit['unitType'] = 'hero'

	return(EntityManagement:EntityConfiguration(unit, player))
end


function EntityManagement:AbilityAdd(entity, abilityName)
	if type(entity) ~= 'table' then
		print('[ENTITY MANAGEMENT]  entity argument must be a table.')

		return(false)
	elseif type(abilityName) ~= 'string' then
		print('[ENTITY MANAGEMENT]  abilityName argument must be a string.')

		return(false)
	else
		if not entity['ability'] then
			print('[ENTITY MANAGEMENT]  you\'re trying to add an ability to an entity that has not yet been configured.')

			return(false)
		else
			entity:AddAbility(abilityName)
			local abi = entity:FindAbilityByName(abilityName)
			if type(abi) ~= 'table' then
				print('[ENTITY MANAGEMENT]  abilityName not found, make sure you typed the ability name correctly and that it exists.')

				return(false)
			else
				entity.ability['count'] = entity.ability['count'] + 1

				abi:SetLevel(1)
				abi['cost'] = abi:GetGoldCost(-1)
				abi['name'] = abi:GetAbilityName()
				abi['caster'] = entity
				abi['position'] = entity.ability['count']

				entity.ability[entity.ability['count']] = abi
				entity.ability[abi['name']] = abi
				entity.ability.list[entity.ability['count']] = abi

				return(true)
			end
		end
	end
end


function EntityManagement:AbilityReplace(entity, abilityOld, abilityNew)
	if type(entity) ~= 'table' then
		print('[ENTITY MANAGEMENT]  entity argument must be a table.')

		return(false)
	elseif type(abilityOld) ~= 'string' then
		print('[ENTITY MANAGEMENT]  abilityOld argument must be a string.')

		return(false)
	elseif type(abilityNew) ~= 'string' then
		print('[ENTITY MANAGEMENT]  abilityNew argument must be a string.')

		return(false)
	else
		if not entity['ability'] then
			print('[ENTITY MANAGEMENT]  you\'re trying to replace an ability on an entity that has not been configured first.')

			return(false)
		else
			entity:AddAbility(abilityNew)
			local old = entity.ability[abilityOld]
			local abi = entity:FindAbilityByName(abilityNew)
			if type(abi) ~= 'table' then
				print('[ENTITY MANAGEMENT]  abilityNew not found, make sure you typed the ability name correctly and that it exists.')

				return(false)
			elseif type(old) ~= 'table' then
				print('[ENTITY MANAGEMENT]  abilityOld not found, make sure you typed the ability name you want to replace correctly.')

				return(false)
			else
				abi:SetLevel(1)
				abi['cost'] = abi:GetGoldCost(-1)
				abi['name'] = abilityNew
				abi['caster'] = entity
				abi['position'] = old['position']

				entity.ability[abi['position']] = abi
				entity.ability[abilityNew] = abi
				entity.ability.list[abi['position']] = abi

				entity:RemoveAbility(abilityOld)
				entity.ability[abilityOld] = nil

				return(true)
			end
		end
	end
end


function EntityManagement:AbilityRemove(entity, abilityName)
	if type(entity) ~= 'table' then
		print('[ENTITY MANAGEMENT]  entity argument must be a table.')

		return(false)
	elseif type(abilityName) ~= 'string' then
		print('[ENTITY MANAGEMENT]  abilityName argument must be a string.')

		return(false)
	else
		if not entity['ability'] then
			print('[ENTITY MANAGEMENT]  you\'re trying to remove an ability from an entity that has not yet been configured.')

			return(false)
		else
			local abi = entity.ability[abilityName]
			if type(abi) ~= 'table' then
				print('[ENTITY MANAGEMENT]  abilityNew not found, make sure you typed the ability name correctly and that it exists.')

				return(false)
			else
				local position = abi['position']

				entity:RemoveAbility(abilityName)

				entity.ability[position] = nil
				entity.ability[abilityName] = nil
				entity.ability.list[position] = nil
				entity.ability['count'] = entity.ability['count'] - 1

				return(true)
			end
		end
	end
end


function EntityManagement:SetupPlayer(playerID)
	if type(player) ~= 'integer' then
		print('[ENTITY MANAGEMENT]  player argument must be an integer.')

		return(nil)
	end

	local player = EntIndexToHScript(playerID)
	if player['isConfigured'] == true then
		return(player)
	else
		player['id'] = playerID
		player['queue'] = {}
		player['units'] = {}
		player['structures'] = {}
		player['buildings'] = {}
		player['upgrades'] = {}
		player['gold'] = 0
		player['lumber'] = 0
		player['population'] = {['current'] = 0, ['maximum'] = 150}
		player['team'] = PlayerResource:GetTeam(player['id'])
		player['handle'] = PlayerResource:GetPlayer(player['id'])
		player['name'] = PlayerResource:GetPlayerName(player['id'])

		if player['team'] == 2 then
			player['faction'] = 'builder'
		elseif player['team'] == 3 then
			player['faction'] = 'titan'
		end

		player['isConfigured'] = true

		if GameMode and GameMode.PLAYERS then
			GameMode.Players[player['id']] = player
		end
	end

	return(player)
end