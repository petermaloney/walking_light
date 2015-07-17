-- list of all players seen by minetest.register_on_joinplayer
local players = {}
-- all player positions last time light was updated: {name : {x, y, z}}
local player_positions = {}
-- all light positions of light that currently is created {name : {x, y, z}}
local light_positions = {}
-- last item seen wielded by players
local last_wielded = {}

function round(num) 
	return math.floor(num + 0.5) 
end

local function poseq(pos1, pos2)
	return pos1.x == pos2.x and pos1.y == pos2.y and pos1.z == pos2.z
end

-- return true if the player moved since last player_positions update
local function player_moved(player)
	local player_name = player:get_player_name()
	local pos = player:getpos()
	local rounded_pos = vector.round(pos)
	local oldpos = player_positions[player_name]
	if not poseq(rounded_pos, oldpos) then
		print("DEBUG: walking_light, player_moved(); moved = true; rounded_pos = " .. dump(rounded_pos) .. ", oldpos = " .. dump(oldpos))
		return true
	end
--	print("DEBUG: walking_light, player_moved(); moved = false; rounded_pos = " .. dump(rounded_pos) .. ", oldpos = " .. dump(oldpos))
	return false
end

-- removes light at the given position
-- player is optional
local function remove_light(player, pos)
	local player_name
	if player then
		player_name = player:get_player_name()
	end
	local node = minetest.env:get_node_or_nil(pos)
	if node ~= nil and node.name == "walking_light:light" then
		minetest.env:add_node(pos,{type="node",name="walking_light:clear"})
		minetest.env:add_node(pos,{type="node",name="air"})
		if player_name then
			light_positions[player_name] = nil
		end
	else
		if node ~= nil then
			print("WARNING: walking_light.remove_light(), pos = " .. dump(pos) .. ", tried to remove light but node was " .. node.name)
		else
			print("WARNING: walking_light.remove_light(), pos = " .. dump(pos) .. ", tried to remove light but node was nil")
--			print("crash" .. nil)
		end
	end
end

-- removes all light owned by a player
local function remove_light_player(player)
	local player_name = player:get_player_name()
	-- currently one light... later may be many
	local old_pos = light_positions[player_name]
	print("DEBUG: walking_light globalstep, removing old light")
	remove_light(player, old_pos)
end

local function can_add_light(pos)
	local node  = minetest.env:get_node_or_nil(pos)
	if node == nil or node.name == "air" then
		return true
	elseif node.name == "walking_light:light" then
		return true
	end
	return false
end

local function pick_light_position(pos)
	if can_add_light(pos) then
		return pos
	end

	local pos2
	pos2 = vector.new(pos.x + 1, pos.y, pos.z)
	if can_add_light( pos2 ) then
		return pos2
	end

	pos2 = vector.new(pos.x - 1, pos.y, pos.z)
	if can_add_light( pos2 ) then
		return pos2
	end

	pos2 = vector.new(pos.x, pos.y, pos.z + 1)
	if can_add_light( pos2 ) then
		return pos2
	end

	pos2 = vector.new(pos.x, pos.y, pos.z - 1)
	if can_add_light( pos2 ) then
		return pos2
	end

	pos2 = vector.new(pos.x, pos.y + 1, pos.z)
	if can_add_light( pos2 ) then
		return pos2
	end

	pos2 = vector.new(pos.x, pos.y - 1, pos.z)
	if can_add_light( pos2 ) then
		return pos2
	end

	return nil
end

-- adds light at the given position
local function add_light(player, pos)
	local player_name = player:get_player_name()
	local node  = minetest.env:get_node_or_nil(pos)
	if node == nil then
		-- don't do anything for nil blocks... they are non-loaded blocks, so we don't want to overwrite anything there
		return false
	elseif node.name == "air" then
		-- wenn an aktueller Position "air" ist, Fackellicht setzen
		minetest.env:add_node(pos,{type="node",name="walking_light:light"})
		light_positions[player_name] = pos
--		if node then
--			print("DEBUG: add_light(), node.name = " .. node.name .. ", pos = " .. dump(pos))
--		else
--			print("DEBUG: add_light(), node.name = nil, pos = " .. dump(pos))
--		end
		return true
	elseif node.name == "walking_light:light" then
		-- no point in adding light where it is already, but we should assign it to the player so it gets removed (in case it has no player)
--		print("DEBUG: add_light(), not adding; node.name = " .. node.name .. ", pos = " .. dump(pos))
		light_positions[player_name] = pos
		return true
	end
--	print("DEBUG: add_light(), not adding; node.name = " .. node.name)
	return false
end

-- updates all the light around the player, depending on what they are wielding
local function update_light_player(player)
	-- figure out if they wield light; this will be nil if not
	local wielded_item = get_wielded_light_item(player)

	local player_name = player:get_player_name()
	local pos = player:getpos()
	local rounded_pos = vector.round(pos)

--	if not player_moved(player) and wielded_item == last_wielded[player_name] then
--		-- no update needed if the wiedled light item is the same as before (including nil), and the player didn't move
--		return
--	end
	last_wielded[player_name] = wielded_item;

	local lightpos
	local wantpos = vector.new(rounded_pos.x, rounded_pos.y + 1, rounded_pos.z)
	if wielded_item then
		-- decide where light should be
		lightpos = pick_light_position(wantpos)
		print("DEBUG: walking_light update_light_player(); wantpos = " .. dump(wantpos) .. ", lightpos = " .. dump(lightpos))
	end

	-- go through all light owned by the player (currently only zero or one nodes) to remove all but what should be kept
	local oldlightpos = light_positions[player_name]
	if oldlightpos and oldlightpos.x and ( not lightpos or not poseq(lightpos, oldlightpos) ) then -- later this will be more like:  if not lightpos.contains(oldlightpos)
		remove_light(player, oldlightpos)
	end

	if wielded_item then
		-- add light that isn't already there
		add_light(player, lightpos)
	end

	player_positions[player_name] = vector.round(pos)
end

local function update_light_all()
	-- go through all players to check
	for i,player_name in ipairs(players) do
		local player = minetest.env:get_player_by_name(player_name)
		update_light_player(player)
	end
end

-- return true if item is a light item
function is_light_item(item)
	if item == "default:torch" or item == "walking_light:pick_mese" 
			or item == "walking_light:helmet_diamond" then
		return true
	end
	return false
end

-- returns a string, the name of the item found that is a light item
function get_wielded_light_item(player)
	local wielded_item = player:get_wielded_item():get_name()
	if is_light_item(wielded_item) then
		return wielded_item
	end

	-- check equipped armor - requires unified_inventory maybe
	local player_name = player:get_player_name()
	if player_name then
		local armor_inv = minetest.get_inventory({type="detached", name=player_name.."_armor"})
		if armor_inv then
--            print( dump(armor_inv:get_lists()) )
			local item_name = "walking_light:helmet_diamond"
			local stack = ItemStack(item_name)
			if armor_inv:contains_item("armor", stack) then
				return item_name
			end
		end
	end

	return nil
end

-- return true if player is wielding a light item
function wielded_light(player)
	return get_wielded_light_item(player) ~= nil
end

minetest.register_on_joinplayer(function(player)
	local player_name = player:get_player_name()
	table.insert(players, player_name)
	last_wielded[player_name] = get_wielded_light_item(player)
	local pos = player:getpos()
	player_positions[player_name] = vector.round(pos)
	light_positions[player_name] = {}
	update_light_player(player)
end)

minetest.register_on_leaveplayer(function(player)
	local player_name = player:get_player_name()
	for i,v in ipairs(players) do
		if v == player_name then 
			table.remove(players, i)
			last_wielded[player_name] = nil
			-- Neuberechnung des Lichts erzwingen
			local pos = player:getpos()
			local rounded_pos = vector.round(pos)
			remove_light_player(player)
			player_positions[player_name]["x"] = nil
			player_positions[player_name]["y"] = nil
			player_positions[player_name]["z"] = nil
			player_positions[player_name]["m"] = nil
			player_positions[player_name] = nil
		end
	end
end)

minetest.register_globalstep(function(dtime)
	for i,player_name in ipairs(players) do
		local player = minetest.env:get_player_by_name(player_name)
		update_light_player(player)
	end
end)

minetest.register_node("walking_light:clear", {
	drawtype = "glasslike",
	tile_images = {"walking_light.png"},
	-- tile_images = {"walking_light_debug.png"},
	--inventory_image = minetest.inventorycube("walking_light.png"),
	--paramtype = "light",
	walkable = false,
	--is_ground_content = true,
	light_propagates = true,
	sunlight_propagates = true,
	--light_source = 13,
	selection_box = {
		type = "fixed",
		fixed = {0, 0, 0, 0, 0, 0},
	},
})

minetest.register_node("walking_light:light", {
	drawtype = "glasslike",
	-- tile_images = {"walking_light.png"},
	tile_images = {"walking_light_debug.png"},
	inventory_image = minetest.inventorycube("walking_light.png"),
	paramtype = "light",
	walkable = false,
	is_ground_content = true,
	light_propagates = true,
	sunlight_propagates = true,
	light_source = 13,
	selection_box = {
		type = "fixed",
		fixed = {0, 0, 0, 0, 0, 0},
	},
})

minetest.register_tool("walking_light:pick_mese", {
	description = "Mese Pickaxe with light",
	inventory_image = "walking_light_mesepick.png",
	wield_image = "default_tool_mesepick.png",
	tool_capabilities = {
		full_punch_interval = 1.0,
		max_drop_level=3,
		groupcaps={
			cracky={times={[1]=2.0, [2]=1.0, [3]=0.5}, uses=20, maxlevel=3},
			crumbly={times={[1]=2.0, [2]=1.0, [3]=0.5}, uses=20, maxlevel=3},
			snappy={times={[1]=2.0, [2]=1.0, [3]=0.5}, uses=20, maxlevel=3}
		}
	},
})

minetest.register_tool("walking_light:helmet_diamond", {
	description = "Diamond Helmet with light",
	inventory_image = "walking_light_inv_helmet_diamond.png",
	wield_image = "3d_armor_inv_helmet_diamond.png",
	groups = {armor_head=15, armor_heal=12, armor_use=100},
	wear = 0,
})

minetest.register_craft({
	output = 'walking_light:pick_mese',
	recipe = {
		{'default:torch'},
		{'default:pick_mese'},
	}
})

minetest.register_craft({
	output = 'walking_light:helmet_diamond',
	recipe = {
		{'default:torch'},
		{'3d_armor:helmet_diamond'},
	}
})

minetest.register_chatcommand("mapclearlight", {
	params = "<size>",
	description = "Remove walking_light:light from the area",
	func = function(name, param)
		if minetest.check_player_privs(name, {server=true}) then
			return false, "You need the server privilege to use mapclearlight"
		end

		local pos = vector.round(minetest.get_player_by_name(name):getpos())
		local size = tonumber(param) or 40

		for x = pos.x - size, pos.x + size, 1 do
			for y = pos.y - size, pos.y + size, 1 do
				for z = pos.z - size, pos.z + size, 1 do
					local point = vector.new(x, y, z)
					print("walking_light.mapclearlight(), point = (" .. x .. "," .. y .. "," .. z .. ")" )
					remove_light(nil, point)
				end
			end
		end

		return true, "Done."
	end,
})

minetest.register_chatcommand("mapaddlight", {
	params = "<size>",
	description = "Add walking_light:light to a position, without a player owning it",
	func = function(name, param)
		if not minetest.check_player_privs(name, {server=true}) then
			return false, "You need the server privilege to use mapaddlight"
		end

		local pos = vector.round(minetest.get_player_by_name(name):getpos())
		pos = vector.new(pos.x, pos.y + 1, pos.z)

		if pos then
			minetest.env:add_node(pos,{type="node",name="walking_light:light"})
		end

		return true, "Done."
	end,
})

