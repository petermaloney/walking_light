local players = {}
local player_positions = {}
local light_positions = {}
local last_wielded = {}

function round(num) 
	return math.floor(num + 0.5) 
end

function remove_light(pos)
	local node = minetest.env:get_node_or_nil(pos)
	if node ~= nil and node.name == "walking_light:light" then
		minetest.env:add_node(pos,{type="node",name="walking_light:clear"})
		minetest.env:add_node(pos,{type="node",name="air"})
	end
end

local function add_light(pos)
	local node  = minetest.env:get_node_or_nil(pos)
	if node == nil or node.name == "air" then
		-- wenn an aktueller Position "air" ist, Fackellicht setzen
		minetest.env:add_node(pos,{type="node",name="walking_light:light"})
--		if node then
--			print("DEBUG: add_light(), node.name = " .. node.name .. ", pos = " .. dump(pos))
--		else
--			print("DEBUG: add_light(), node.name = nil, pos = " .. dump(pos))
--		end
		return true
	elseif node.name == "walking_light:light" then
--		print("DEBUG: add_light(), not adding; node.name = " .. node.name .. ", pos = " .. dump(pos))
		return true
	end
--	print("DEBUG: add_light(), not adding; node.name = " .. node.name)
	return false
end

local function add_light_near(pos)
	local pos2 = pos
	if add_light(pos) then
		return pos
	end

	pos2 = vector.new(pos.x + 1, pos.y, pos.z)
	if add_light( pos2 ) then
		return pos2
	end

	pos2 = vector.new(pos.x - 1, pos.y, pos.z)
	if add_light( pos2 ) then
		return pos2
	end

	pos2 = vector.new(pos.x, pos.y, pos.z + 1)
	if add_light( pos2 ) then
		return pos2
	end

	pos2 = vector.new(pos.x, pos.y, pos.z - 1)
	if add_light( pos2 ) then
		return pos2
	end

	pos2 = vector.new(pos.x, pos.y + 1, pos.z)
	if add_light( pos2 ) then
		return pos2
	end

	pos2 = vector.new(pos.x, pos.y - 1, pos.z)
	if add_light( pos2 ) then
		return pos2
	end

	return nil
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
			item_name = "walking_light:helmet_diamond"
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
	local rounded_pos = {x=round(pos.x),y=round(pos.y)+1,z=round(pos.z)}
	if not wielded_light(player) then
		remove_light(rounded_pos)
	else
		add_light_near(rounded_pos)
	end
	player_positions[player_name] = {}
	player_positions[player_name]["x"] = rounded_pos.x;
	player_positions[player_name]["y"] = rounded_pos.y;
	player_positions[player_name]["z"] = rounded_pos.z;
	light_positions[player_name] = {}
end)

minetest.register_on_leaveplayer(function(player)
	local player_name = player:get_player_name()
	for i,v in ipairs(players) do
		if v == player_name then 
			table.remove(players, i)
			last_wielded[player_name] = nil
			-- Neuberechnung des Lichts erzwingen
			local pos = player:getpos()
			local rounded_pos = {x=round(pos.x),y=round(pos.y)+1,z=round(pos.z)}
			remove_light(rounded_pos)
			player_positions[player_name]["x"] = nil
			player_positions[player_name]["y"] = nil
			player_positions[player_name]["z"] = nil
			player_positions[player_name]["m"] = nil
			player_positions[player_name] = nil
		end
	end
end)

local function poseq(pos1, pos2)
	return pos1.x == pos2.x and pos1.y == pos2.y and pos1.z == pos2.z
end

minetest.register_globalstep(function(dtime)
	for i,player_name in ipairs(players) do
		local player = minetest.env:get_player_by_name(player_name)
		local wielded_item = get_wielded_light_item(player)
		if is_light_item(wielded_item) then
			-- wielding light
			local pos = player:getpos()
			local rounded_pos = {x=round(pos.x),y=round(pos.y)+1,z=round(pos.z)}
			if not is_light_item(last_wielded[player_name]) or (player_positions[player_name]["x"] ~= rounded_pos.x or player_positions[player_name]["y"] ~= rounded_pos.y or player_positions[player_name]["z"] ~= rounded_pos.z) then
				-- wielding light, or player moved
				lightpos = add_light_near(rounded_pos)
				if lightpos and (player_positions[player_name]["x"] ~= rounded_pos.x or player_positions[player_name]["y"] ~= rounded_pos.y or player_positions[player_name]["z"] ~= rounded_pos.z) then
					-- remove light in old player position
					local old_pos = {x=player_positions[player_name]["x"], y=player_positions[player_name]["y"], z=player_positions[player_name]["z"]}
					if not poseq(old_pos, lightpos) then
						-- don't remove light that was just added
--						print("DEBUG: walking_light globalstep, removing player light")
						remove_light(old_pos)
					end
					local old_pos = {x=light_positions[player_name]["x"], y=light_positions[player_name]["y"], z=light_positions[player_name]["z"]}
					if not poseq(old_pos, lightpos) then
						-- don't remove light that was just added
--						print("DEBUG: walking_light globalstep, removing old light")
						remove_light(old_pos)
					end
				end
				-- gemerkte Position ist nun die gerundete neue Position
				player_positions[player_name]["x"] = rounded_pos.x
				player_positions[player_name]["y"] = rounded_pos.y
				player_positions[player_name]["z"] = rounded_pos.z
				if lightpos then
					light_positions[player_name]["x"] = lightpos.x
					light_positions[player_name]["y"] = lightpos.y
					light_positions[player_name]["z"] = lightpos.z
				end
			end

			last_wielded[player_name] = wielded_item;
		elseif is_light_item(last_wielded[player_name]) then
			-- Fackel nicht in der Hand, aber beim letzten Durchgang war die Fackel noch in der Hand
			local pos = player:getpos()
			local rounded_pos = {x=round(pos.x),y=round(pos.y)+1,z=round(pos.z)}
			repeat
				remove_light(rounded_pos)
			until minetest.env:get_node_or_nil(rounded_pos) ~= "walking_light:light"
			local old_pos = {x=player_positions[player_name]["x"], y=player_positions[player_name]["y"], z=player_positions[player_name]["z"]}
			repeat
				remove_light(old_pos)
			until minetest.env:get_node_or_nil(old_pos) ~= "walking_light:light"
			last_wielded[player_name] = wielded_item
		end
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

