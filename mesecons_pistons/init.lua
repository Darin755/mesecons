--PISTONS

-- Get mesecon rules of pistons
piston_rules =
{{x=0,  y=0,  z=1}, --everything apart from z- (pusher side)
 {x=1,  y=0,  z=0},
 {x=-1, y=0,  z=0},
 {x=1,  y=1,  z=0},
 {x=1,  y=-1, z=0},
 {x=-1, y=1,  z=0},
 {x=-1, y=-1, z=0},
 {x=0,  y=1,  z=1},
 {x=0,  y=-1, z=1}}

local piston_get_rules = function (node)
	local rules = piston_rules
	for i = 1, node.param2 do
		rules = mesecon:rotate_rules_left(rules)
	end
	return rules
end

--starts the timer to make the piston update to its new state
local update = function(pos, node)
	local timer = minetest.env:get_node_timer(pos)
	timer:stop()
	timer:start(0)
end

--on_destruct callback, removes the piston pusher if it is present
local destruct = function(pos, oldnode)
	local dir = mesecon:piston_get_direction(oldnode)
	pos.x, pos.y, pos.z = pos.x + dir.x, pos.y + dir.y, pos.z + dir.z --move to first node to check

	--ensure piston is extended
	local checknode = minetest.env:get_node(pos)
	if checknode.name == "mesecons_pistons:piston_pusher_normal"
	or checknode.name == "mesecons_pistons:piston_pusher_sticky" then
		if checknode.param2 == oldnode.param2 then --pusher is facing the same direction as the piston
			minetest.env:remove_node(pos) --remove the pusher
		end
	elseif oldnode.name == "mesecons_pistons:piston_up_normal" or oldnode.name == "mesecons_pistons:piston_up_sticky" then
		if checknode.name == "mesecons_pistons:piston_up_pusher_normal" or checknode.name == "mesecons_pistons:piston_up_pusher_sticky" then
			minetest.env:remove_node(pos) --remove the pusher
		end
	elseif oldnode.name == "mesecons_pistons:piston_down_normal" or oldnode.name == "mesecons_pistons:piston_down_sticky" then
		if checknode.name == "mesecons_pistons:piston_down_pusher_normal" or checknode.name == "mesecons_pistons:piston_down_pusher_sticky" then
			minetest.env:remove_node(pos) --remove the pusher
		end
	end
end

--node timer callback, pushes/pulls the piston depending on whether it is powered
local timer = function(pos, elapsed)
	if mesecon:is_powered(pos) then
		mesecon:piston_push(pos)
	else
		mesecon:piston_pull(pos)
	end
	return false
end

--piston push action
function mesecon:piston_push(pos)
	local node = minetest.env:get_node(pos)
	local dir = mesecon:piston_get_direction(node)
	pos = addPosRule(pos, dir) --move to first node being pushed

	--determine the number of nodes that need to be pushed
	local count = 0
	local checkpos = {x=pos.x, y=pos.y, z=pos.z} --first node being pushed

	while true do
		local checknode = minetest.env:get_node(checkpos)

		--check for collision with stopper or bounds
		if mesecon:is_mvps_stopper(checknode.name) or checknode.name == "ignore" then
			return
		end

		--check for column end
		if checknode.name == "air"
		or not(minetest.registered_nodes[checknode.name].liquidtype == "none") then
			break
		end

		--limit piston pushing capacity
		count = count + 1
		if count > 15 then
			return
		end

		checkpos = addPosRule(checkpos, dir)
	end

	local thisnode = minetest.env:get_node(pos)
	minetest.env:remove_node(pos)
		mesecon.on_dignode(pos, thisnode)
	local nextnode

	--add pusher
	if node.name == "mesecons_pistons:piston_normal" then
		minetest.env:add_node(pos, {name="mesecons_pistons:piston_pusher_normal", param2=node.param2})
	elseif node.name == "mesecons_pistons:piston_sticky" then
		minetest.env:add_node(pos, {name="mesecons_pistons:piston_pusher_sticky", param2=node.param2})
	elseif node.name == "mesecons_pistons:piston_up_normal" then
		minetest.env:add_node(pos, {name="mesecons_pistons:piston_up_pusher_normal"})
	elseif node.name == "mesecons_pistons:piston_up_sticky" then
		minetest.env:add_node(pos, {name="mesecons_pistons:piston_up_pusher_sticky"})
	elseif node.name == "mesecons_pistons:piston_down_normal" then
		minetest.env:add_node(pos, {name="mesecons_pistons:piston_down_pusher_normal"})
	elseif node.name == "mesecons_pistons:piston_down_sticky" then
		minetest.env:add_node(pos, {name="mesecons_pistons:piston_down_pusher_sticky"})
	end

	--move nodes forward
	for i = 1, count do
		pos = addPosRule(pos, dir)  --move to the next node

		nextnode = minetest.env:get_node(pos)
		minetest.env:remove_node(pos)
			mesecon.on_dignode(pos, thisnode)
		minetest.env:add_node(pos, thisnode)
			mesecon.on_placenode(pos, thisnode)
		thisnode = nextnode
		nodeupdate(pos)
	end
end

--piston pull action
function mesecon:piston_pull(pos)
	local node = minetest.env:get_node(pos)
	local dir = mesecon:piston_get_direction(node)
	pos = {x=pos.x + dir.x, y=pos.y + dir.y, z=pos.z + dir.z} --move to first node being replaced

	--ensure piston is extended
	local checknode = minetest.env:get_node(pos)
	if node.name == "mesecons_pistons:piston_up_normal" or node.name == "mesecons_pistons:piston_up_sticky" then --up piston
		if checknode.name ~= "mesecons_pistons:piston_up_pusher_normal" and checknode.name ~= "mesecons_pistons:piston_up_pusher_sticky" then
			return --piston is not extended
		end
	elseif node.name == "mesecons_pistons:piston_down_normal" or node.name == "mesecons_pistons:piston_down_sticky" then --down piston
		if checknode.name ~= "mesecons_pistons:piston_down_pusher_normal" and checknode.name ~= "mesecons_pistons:piston_down_pusher_sticky" then
			return --piston is not extended
		end
	else --horizontal piston
		if checknode.name ~= "mesecons_pistons:piston_pusher_normal" and checknode.name ~= "mesecons_pistons:piston_pusher_sticky" then
			return --piston is not extended
		end
		if checknode.param2 ~= node.param2 then --pusher is not facing the same direction as the piston
			return --piston is not extended
		end
	end

	--retract piston
	minetest.env:remove_node(pos) --remove pusher
	if minetest.registered_nodes[node.name].is_sticky_piston then --retract block if piston is sticky
		local retractpos  = addPosRule(pos, dir)  --move to the node to be retracted
		local retractnode = minetest.env:get_node(retractpos)
		if  minetest.registered_nodes[retractnode.name].liquidtype == "none"
		and not mesecon:is_mvps_stopper(retractnode.name) then
			mesecon:move_node(retractpos, pos)
			mesecon.on_dignode(retractpos, retractnode)
			mesecon.on_placenode(pos, retractnode)
			nodeupdate(pos)
		end
	end
end

--push direction of a piston
function mesecon:piston_get_direction(node)
	if node.name == "mesecons_pistons:piston_up_normal" or node.name == "mesecons_pistons:piston_up_sticky" then
		return {x=0, y=1, z=0}
	elseif node.name == "mesecons_pistons:piston_down_normal" or node.name == "mesecons_pistons:piston_down_sticky" then
		return {x=0, y=-1, z=0}
	elseif node.param2 == 3 then
		return {x=1, y=0, z=0}
	elseif node.param2 == 2 then
		return {x=0, y=0, z=1}
	elseif node.param2 == 1 then
		return {x=-1, y=0, z=0}
	else --node.param2 == 0
		return {x=0, y=0, z=-1}
	end
end

--horizontal pistons
minetest.register_node("mesecons_pistons:piston_normal", {
	description = "Piston",
	tiles = {"jeija_piston_tb.png", "jeija_piston_tb.png", "jeija_piston_tb.png", "jeija_piston_tb.png", "jeija_piston_tb.png", "jeija_piston_side.png"},
	groups = {cracky=3, mesecon=2},
	paramtype2 = "facedir",
	after_destruct = destruct,
	on_timer = timer,
	on_place = function(itemstack, placer, pointed_thing)
		if pointed_thing.type ~= "node" then --can be placed only on nodes
			return itemstack
		end
		if not placer then
			return minetest.item_place(itemstack, placer, pointed_thing)
		end
		local dir = placer:get_look_dir()
		if math.abs(dir.y) > math.sqrt(dir.x ^ 2 + dir.z ^ 2) then --vertical look direction is most significant
			local fakestack
			if dir.y > 0 then
				fakestack = ItemStack("mesecons_pistons:piston_down_normal")
			else
				fakestack = ItemStack("mesecons_pistons:piston_up_normal")
			end
			local ret = minetest.item_place(fakestack, placer, pointed_thing)
			if ret:is_empty() then
				itemstack:take_item()
				return itemstack
			end
		end
		return minetest.item_place(itemstack, placer, pointed_thing) --place piston normally
	end,
	mesecons = {effector={
		action_change = update,
		rules = piston_get_rules
	}}
})

minetest.register_node("mesecons_pistons:piston_sticky", {
	description = "Sticky Piston",
	tiles = {"jeija_piston_tb.png", "jeija_piston_tb.png", "jeija_piston_tb.png", "jeija_piston_tb.png", "jeija_piston_tb.png", "jeija_piston_sticky_side.png"},
	groups = {cracky=3, mesecon=2},
	paramtype2 = "facedir",
	after_destruct = destruct,
	on_timer = timer,
	is_sticky_piston = true,
	on_place = function(itemstack, placer, pointed_thing)
		if pointed_thing.type ~= "node" then --can be placed only on nodes
			return itemstack
		end
		if not placer then
			return minetest.item_place(itemstack, placer, pointed_thing)
		end
		local dir = placer:get_look_dir()
		if math.abs(dir.y) > math.sqrt(dir.x ^ 2 + dir.z ^ 2) then --vertical look direction is most significant
			local fakestack
			if dir.y > 0 then
				fakestack = ItemStack("mesecons_pistons:piston_down_sticky")
			else
				fakestack = ItemStack("mesecons_pistons:piston_up_sticky")
			end
			local ret = minetest.item_place(fakestack, placer, pointed_thing)
			if ret:is_empty() then
				itemstack:take_item()
				return itemstack
			end
		end
		return minetest.item_place(itemstack, placer, pointed_thing) --place piston normally
	end,
	mesecons = {effector={
		action_change = update,
		rules = piston_get_rules
	}}
})

minetest.register_node("mesecons_pistons:piston_pusher_normal", {
	drawtype = "nodebox",
	tiles = {"jeija_piston_pusher_normal.png"},
	paramtype = "light",
	paramtype2 = "facedir",
	diggable = false,
	selection_box = {
		type = "fixed",
		fixed = {
			{-0.2, -0.2, -0.3, 0.2, 0.2, 0.5},
			{-0.5, -0.5, -0.5, 0.5, 0.5, -0.3},
		},
	},
	node_box = {
		type = "fixed",
		fixed = {
			{-0.2, -0.2, -0.3, 0.2, 0.2, 0.5},
			{-0.5, -0.5, -0.5, 0.5, 0.5, -0.3},
		},
	},
})

minetest.register_node("mesecons_pistons:piston_pusher_sticky", {
	drawtype = "nodebox",
	tiles = {
		"jeija_piston_pusher_normal.png",
		"jeija_piston_pusher_normal.png",
		"jeija_piston_pusher_normal.png",
		"jeija_piston_pusher_normal.png",
		"jeija_piston_pusher_normal.png",
		"jeija_piston_pusher_sticky.png"
		},
	paramtype = "light",
	paramtype2 = "facedir",
	diggable = false,
	selection_box = {
		type = "fixed",
		fixed = {
			{-0.2, -0.2, -0.3, 0.2, 0.2, 0.5},
			{-0.5, -0.5, -0.5, 0.5, 0.5, -0.3},
		},
	},
	node_box = {
		type = "fixed",
		fixed = {
			{-0.2, -0.2, -0.3, 0.2, 0.2, 0.5},
			{-0.5, -0.5, -0.5, 0.5, 0.5, -0.3},
		},
	},
})

mesecon:register_mvps_stopper("mesecons_pistons:piston_pusher_normal")
mesecon:register_mvps_stopper("mesecons_pistons:piston_pusher_sticky")

--up pistons
minetest.register_node("mesecons_pistons:piston_up_normal", {
	tiles = {"jeija_piston_side.png", "jeija_piston_tb.png", "jeija_piston_tb.png", "jeija_piston_tb.png", "jeija_piston_tb.png", "jeija_piston_tb.png"},
	groups = {cracky=3, mesecon=2},
	after_destruct = destruct,
	on_timer = timer,
	is_sticky_piston = true,
	mesecons = {effector={
		action_change = update
	}},
	drop = "mesecons_pistons:piston_normal",
})

minetest.register_node("mesecons_pistons:piston_up_sticky", {
	tiles = {"jeija_piston_sticky_side.png", "jeija_piston_tb.png", "jeija_piston_tb.png", "jeija_piston_tb.png", "jeija_piston_tb.png", "jeija_piston_tb.png"},
	groups = {cracky=3, mesecon=2},
	after_destruct = destruct,
	on_timer = timer,
	mesecons = {effector={
		action_change = update
	}},
	drop = "mesecons_pistons:piston_sticky",
})

minetest.register_node("mesecons_pistons:piston_up_pusher_normal", {
	drawtype = "nodebox",
	tiles = {"jeija_piston_pusher_normal.png"},
	paramtype = "light",
	diggable = false,
	selection_box = {
		type = "fixed",
		fixed = {
			{-0.2, -0.5, -0.2, 0.2, 0.3, 0.2},
			{-0.5, 0.3, -0.5, 0.5, 0.5, 0.5},
		},
	},
	node_box = {
		type = "fixed",
		fixed = {
			{-0.2, -0.5, -0.2, 0.2, 0.3, 0.2},
			{-0.5, 0.3, -0.5, 0.5, 0.5, 0.5},
		},
	},
})

minetest.register_node("mesecons_pistons:piston_up_pusher_sticky", {
	drawtype = "nodebox",
	tiles = {
		"jeija_piston_pusher_sticky.png",
		"jeija_piston_pusher_normal.png",
		"jeija_piston_pusher_normal.png",
		"jeija_piston_pusher_normal.png",
		"jeija_piston_pusher_normal.png",
		"jeija_piston_pusher_normal.png"
		},
	paramtype = "light",
	diggable = false,
	selection_box = {
		type = "fixed",
		fixed = {
			{-0.2, -0.5, -0.2, 0.2, 0.3, 0.2},
			{-0.5, 0.3, -0.5, 0.5, 0.5, 0.5},
		},
	},
	node_box = {
		type = "fixed",
		fixed = {
			{-0.2, -0.5, -0.2, 0.2, 0.3, 0.2},
			{-0.5, 0.3, -0.5, 0.5, 0.5, 0.5},
		},
	},
})

mesecon:register_mvps_stopper("mesecons_pistons:piston_up_pusher_normal")
mesecon:register_mvps_stopper("mesecons_pistons:piston_up_pusher_sticky")

--down pistons
minetest.register_node("mesecons_pistons:piston_down_normal", {
	tiles = {"jeija_piston_tb.png", "jeija_piston_side.png", "jeija_piston_tb.png", "jeija_piston_tb.png", "jeija_piston_tb.png", "jeija_piston_tb.png"},
	groups = {cracky=3, mesecon=2},
	after_destruct = destruct,
	on_timer = timer,
	mesecons = {effector={
		action_change = update
	}},
	drop = "mesecons_pistons:piston_normal",
})

minetest.register_node("mesecons_pistons:piston_down_sticky", {
	tiles = {"jeija_piston_tb.png", "jeija_piston_sticky_side.png", "jeija_piston_tb.png", "jeija_piston_tb.png", "jeija_piston_tb.png", "jeija_piston_tb.png"},
	groups = {cracky=3, mesecon=2},
	after_destruct = destruct,
	on_timer = timer,
	is_sticky_piston = true,
	mesecons = {effector={
		action_change = update
	}},
	drop = "mesecons_pistons:piston_sticky",
})

minetest.register_node("mesecons_pistons:piston_down_pusher_normal", {
	drawtype = "nodebox",
	tiles = {"jeija_piston_pusher_normal.png"},
	paramtype = "light",
	diggable = false,
	selection_box = {
		type = "fixed",
		fixed = {
			{-0.2, -0.3, -0.2, 0.2, 0.5, 0.2},
			{-0.5, -0.5, -0.5, 0.5, -0.3, 0.5},
		},
	},
	node_box = {
		type = "fixed",
		fixed = {
			{-0.2, -0.3, -0.2, 0.2, 0.5, 0.2},
			{-0.5, -0.5, -0.5, 0.5, -0.3, 0.5},
		},
	},
})

minetest.register_node("mesecons_pistons:piston_down_pusher_sticky", {
	drawtype = "nodebox",
	tiles = {
		"jeija_piston_pusher_normal.png",
		"jeija_piston_pusher_sticky.png",
		"jeija_piston_pusher_normal.png",
		"jeija_piston_pusher_normal.png",
		"jeija_piston_pusher_normal.png",
		"jeija_piston_pusher_normal.png"
		},
	paramtype = "light",
	diggable = false,
	selection_box = {
		type = "fixed",
		fixed = {
			{-0.2, -0.3, -0.2, 0.2, 0.5, 0.2},
			{-0.5, -0.5, -0.5, 0.5, -0.3, 0.5},
		},
	},
	node_box = {
		type = "fixed",
		fixed = {
			{-0.2, -0.3, -0.2, 0.2, 0.5, 0.2},
			{-0.5, -0.5, -0.5, 0.5, -0.3, 0.5},
		},
	},
})

mesecon:register_mvps_stopper("mesecons_pistons:piston_down_pusher_normal")
mesecon:register_mvps_stopper("mesecons_pistons:piston_down_pusher_sticky")

--craft recipes
minetest.register_craft({
	output = '"mesecons_pistons:piston_normal" 2',
	recipe = {
		{"default:wood", "default:wood", "default:wood"},
		{"default:cobble", "default:steel_ingot", "default:cobble"},
		{"default:cobble", "group:mesecon_conductor_craftable", "default:cobble"},
	}
})

minetest.register_craft({
	output = "mesecons_pistons:piston_sticky",
	recipe = {
		{"mesecons_materials:glue"},
		{"mesecons_pistons:piston_normal"},
	}
})
