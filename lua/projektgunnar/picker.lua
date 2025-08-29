local M = {}

---@class PGPickerConfig
---@field prefer string[]|nil  -- e.g. { "telescope", "mini" }
local cfg = {
	-- Prefer Telescope; if not available, fall back to mini.pick
	prefer = require("projektgunnar.config").options.prefer,
}

--- Configure picker behavior (priority order)
---@param user { prefer?: string[] }|nil
function M.setup(user)
	if type(user) == "table" and type(user.prefer) == "table" then
		cfg.prefer = user.prefer
	end
end

-- Does telescope exist?
local function has_telescope()
	return pcall(require, "telescope")
end

-- Does mini.pick exist?
local function has_mini_pick()
	return pcall(require, "mini.pick")
end

--- Telescope backend (async). Calls cb(choice|nil).
---@param prompt string
---@param items string[]
---@param cb fun(choice: string|nil)
local function pick_telescope_async(prompt, items, cb)
	if not has_telescope() then
		cb(nil)
		return
	end

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

	-- Robust sorter: prefer conf.generic_sorter({...}); fallback to sorters.get_generic_fuzzy_sorter()
	local sorter = nil
	if type(conf.generic_sorter) == "function" then
		sorter = conf.generic_sorter({})
	else
		local ok_sorters, sorters = pcall(require, "telescope.sorters")
		if ok_sorters and type(sorters.get_generic_fuzzy_sorter) == "function" then
			sorter = sorters.get_generic_fuzzy_sorter()
		end
	end

	local picker = pickers.new({}, {
		prompt_title = prompt or "Select",
		finder = finders.new_table({
			results = items,
			entry_maker = function(entry)
				return { value = entry, display = entry, ordinal = entry }
			end,
		}),
		sorter = sorter, -- may be nil; Telescope will still work (but will not fuzzy sort if nil)
		attach_mappings = function(bufnr, map)
			-- Return selected item
			local function choose()
				local sel = state.get_selected_entry()
				local val = sel and (sel.value or sel[1]) or nil
				actions.close(bufnr)
				vim.schedule(function()
					cb(val)
				end)
			end

			-- No choice was made and we will just cancel
			local function cancel()
				actions.close(bufnr)
				vim.schedule(function()
					cb(nil)
				end)
			end

			-- Mappings for telescope
			map("i", "<CR>", choose)
			map("n", "<CR>", choose)
			map("i", "<C-c>", cancel)
			map("n", "<Esc>", cancel)
			map("n", "q", cancel)

			return true
		end,
	})

	-- Schedule to avoid rendering hiccups
	vim.schedule(function()
		picker:find()
	end)
end

--- mini.pick backend (async). Calls cb(choice|nil).
---@param prompt string
---@param items string[]
---@param cb fun(choice: string|nil)
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

	-- Run on next tick; mini.start returns selected item or nil
	vim.schedule(function()
		local ok_start, result = pcall(mini.start, config)
		if ok_start then
			cb(result)
		else
			cb(nil)
		end
	end)
end

--- Present choices asynchronously; calls cb(choice|nil) when done.
---@param prompt string
---@param items string[]
---@param cb fun(choice: string|nil)
function M.ask_user_for_choice(prompt, items, cb)
	if type(cb) ~= "function" then
		error(
			"[projektgunnar.picker] ask_user_for_choice now requires a callback: ask_user_for_choice(prompt, items, function(choice) ... end)",
			2
		)
	end
	if type(items) ~= "table" or #items == 0 then
		vim.schedule(function()
			vim.notify("No items to choose from", vim.log.levels.WARN)
			cb(nil)
		end)
		return
	end

	local available = {
		telescope = has_telescope(),
		mini = has_mini_pick(),
	}

	for _, key in ipairs(cfg.prefer) do
		if key == "telescope" and available.telescope then
			pick_telescope_async(prompt, items, cb)
			return
		elseif key == "mini" and available.mini then
			pick_mini_async(prompt, items, cb)
			return
		end
	end

	vim.schedule(function()
		vim.notify("No picker backend available (install telescope.nvim or mini.pick)", vim.log.levels.ERROR)
		cb(nil)
	end)
end

return M
