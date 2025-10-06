local M = {}

-- Read preferred order from your config on-demand.
-- Falls back to a sane default if nil/empty.
local function prefer_order()
	local ok, cfg = pcall(require, "projektgunnar.config")
	local prefer = ok and cfg and cfg.options and cfg.options.prefer or nil
	if type(prefer) == "table" and #prefer > 0 then
		return prefer
	end
	return { "snacks", "telescope", "mini" }
end

local function has_snacks()
	local ok, snacks = pcall(require, "snacks")
	return ok and snacks and snacks.picker and snacks.picker.select
end

local function has_telescope()
	return pcall(require, "telescope")
end

local function has_mini_pick()
	return pcall(require, "mini.pick")
end

-- Snacks backend (latest Snacks API: picker.select(items, opts, cb))
local function pick_snacks_async(prompt, items, cb)
	local ok, Snacks = pcall(require, "snacks")
	if not ok or not Snacks or not Snacks.picker or not Snacks.picker.select then
		cb(nil)
		return
	end
	vim.schedule(function()
		Snacks.picker.select(items, { title = prompt or "Select" }, function(item)
			cb(type(item) == "string" and item or nil)
		end)
	end)
end

-- Telescope backend
local function pick_telescope_async(prompt, items, cb)
	local ok_p, pickers = pcall(require, "telescope.pickers")
	local ok_f, finders = pcall(require, "telescope.finders")
	local ok_c, confmod = pcall(require, "telescope.config")
	local ok_a, actions = pcall(require, "telescope.actions")
	local ok_s, state = pcall(require, "telescope.actions.state")
	if not (ok_p and ok_f and ok_c and ok_a and ok_s) then
		cb(nil)
		return
	end

	local conf = confmod.values
	local sorter = type(conf.generic_sorter) == "function" and conf.generic_sorter({}) or nil

	local picker = pickers.new({}, {
		prompt_title = prompt or "Select",
		finder = finders.new_table({
			results = items,
			entry_maker = function(entry)
				return { value = entry, display = entry, ordinal = entry }
			end,
		}),
		sorter = sorter,
		attach_mappings = function(bufnr, map)
			local function choose()
				local sel = state.get_selected_entry()
				local val = sel and (sel.value or sel[1]) or nil
				actions.close(bufnr)
				vim.schedule(function()
					cb(val)
				end)
			end
			local function cancel()
				actions.close(bufnr)
				vim.schedule(function()
					cb(nil)
				end)
			end
			map("i", "<CR>", choose)
			map("n", "<CR>", choose)
			map("i", "<C-c>", cancel)
			map("n", "<Esc>", cancel)
			map("n", "q", cancel)
			return true
		end,
	})
	vim.schedule(function()
		picker:find()
	end)
end

-- mini.pick backend
local function pick_mini_async(prompt, items, cb)
	local ok, mini = pcall(require, "mini.pick")
	if not ok then
		cb(nil)
		return
	end

	local height = math.floor(0.618 * vim.o.lines)
	local width = math.floor(0.618 * vim.o.columns)
	local config = {
		window = {
			prompt_prefix = (prompt or "Select") .. "> ",
			config = {
				anchor = "NW",
				height = height,
				width = width,
				row = math.floor(0.5 * (vim.o.lines - height)),
				col = math.floor(0.5 * (vim.o.columns - width)),
			},
		},
		source = { items = items },
	}

	vim.schedule(function()
		local ok_start, result = pcall(mini.start, config)
		cb(ok_start and result or nil)
	end)
end

--- Public API: present choices asynchronously; calls cb(choice|nil)
--- @param prompt string
--- @param items string[]
--- @param cb fun(choice: string|nil)
function M.ask_user_for_choice(prompt, items, cb)
	if type(cb) ~= "function" then
		error("[projektgunnar.picker] ask_user_for_choice requires a callback", 2)
	end
	if type(items) ~= "table" or #items == 0 then
		vim.schedule(function()
			vim.notify("No items to choose from", vim.log.levels.WARN)
			cb(nil)
		end)
		return
	end

	local available = {
		snacks = has_snacks(),
		telescope = has_telescope(),
		mini = has_mini_pick(),
	}

	for _, key in ipairs(prefer_order()) do
		if key == "snacks" and available.snacks then
			pick_snacks_async(prompt, items, cb)
			return
		elseif key == "telescope" and available.telescope then
			pick_telescope_async(prompt, items, cb)
			return
		elseif key == "mini" and available.mini then
			pick_mini_async(prompt, items, cb)
			return
		end
	end

	vim.schedule(function()
		vim.notify("No picker backend available (snacks.nvim / telescope.nvim / mini.pick)", vim.log.levels.ERROR)
		cb(nil)
	end)
end

return M
