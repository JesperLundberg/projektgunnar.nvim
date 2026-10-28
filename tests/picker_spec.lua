local assert = require("luassert")
local stub = require("luassert.stub")

describe("picker", function()
	local picker = require("projektgunnar.picker")
	local config = require("projektgunnar.config")

	local notify_stub
	local original_prefer
	local saved_loaded
	local saved_preload

	local MODULES = {
		"snacks",
		"telescope",
		"telescope.pickers",
		"telescope.finders",
		"telescope.config",
		"telescope.actions",
		"telescope.actions.state",
		"mini.pick",
	}

	-- Make a module look installed
	local function fake(name, mod)
		package.preload[name] = nil
		package.loaded[name] = mod
	end

	local function wait_for(pred)
		return vim.wait(1000, pred, 5)
	end

	-- Collects calls to the picker callback
	local function make_cb()
		local state = { calls = 0, value = nil }
		state.fn = function(v)
			state.calls = state.calls + 1
			state.value = v
		end
		return state
	end

	before_each(function()
		notify_stub = stub(vim, "notify")
		original_prefer = config.options.prefer
		config.options.prefer = { "snacks", "telescope", "mini" }

		-- Hide every backend (even if really installed) so each test opts in
		saved_loaded, saved_preload = {}, {}
		for _, name in ipairs(MODULES) do
			saved_loaded[name] = package.loaded[name]
			saved_preload[name] = package.preload[name]
			package.loaded[name] = nil
			package.preload[name] = function()
				error("module '" .. name .. "' hidden by test")
			end
		end
	end)

	after_each(function()
		for _, name in ipairs(MODULES) do
			package.loaded[name] = saved_loaded[name]
			package.preload[name] = saved_preload[name]
		end
		config.options.prefer = original_prefer
		if notify_stub then
			notify_stub:revert()
		end
	end)

	describe("argument validation", function()
		it("should raise an error when no callback is given", function()
			assert.has_error(function()
				picker.ask_user_for_choice("Prompt", { "a" }, nil)
			end)
		end)

		it("should warn and call cb(nil) when items is empty", function()
			local cb = make_cb()
			picker.ask_user_for_choice("Prompt", {}, cb.fn)

			assert.is_true(wait_for(function()
				return cb.calls > 0
			end))
			assert.is_nil(cb.value)
			assert.stub(notify_stub).was_called_with("No items to choose from", vim.log.levels.WARN)
		end)

		it("should warn and call cb(nil) when items is not a table", function()
			local cb = make_cb()
			picker.ask_user_for_choice("Prompt", nil, cb.fn)

			assert.is_true(wait_for(function()
				return cb.calls > 0
			end))
			assert.is_nil(cb.value)
		end)
	end)

	describe("backend selection", function()
		it("should error and call cb(nil) when no backend is available", function()
			local cb = make_cb()
			picker.ask_user_for_choice("Prompt", { "a" }, cb.fn)

			assert.is_true(wait_for(function()
				return cb.calls > 0
			end))
			assert.is_nil(cb.value)
			assert
				.stub(notify_stub)
				.was_called_with("No picker backend available (snacks.nvim / telescope.nvim / mini.pick)", vim.log.levels.ERROR)
		end)

		it("should follow the configured preference order", function()
			local used = {}
			fake("snacks", {
				picker = {
					select = function(_, _, cb)
						used[#used + 1] = "snacks"
						cb("a")
					end,
				},
			})
			fake("mini.pick", {
				start = function()
					used[#used + 1] = "mini"
					return "a"
				end,
			})
			config.options.prefer = { "mini", "snacks" }

			local cb = make_cb()
			picker.ask_user_for_choice("Prompt", { "a" }, cb.fn)

			assert.is_true(wait_for(function()
				return cb.calls > 0
			end))
			assert.are.same({ "mini" }, used)
		end)

		it("should skip unavailable backends and use the next preferred one", function()
			fake("mini.pick", {
				start = function()
					return "from mini"
				end,
			})
			-- snacks and telescope are hidden
			local cb = make_cb()
			picker.ask_user_for_choice("Prompt", { "a" }, cb.fn)

			assert.is_true(wait_for(function()
				return cb.calls > 0
			end))
			assert.are.equal("from mini", cb.value)
		end)

		it("should ignore unknown names in the preference list", function()
			fake("mini.pick", {
				start = function()
					return "a"
				end,
			})
			config.options.prefer = { "nonsense", "mini" }

			local cb = make_cb()
			picker.ask_user_for_choice("Prompt", { "a" }, cb.fn)

			assert.is_true(wait_for(function()
				return cb.calls > 0
			end))
			assert.are.equal("a", cb.value)
		end)

		it("should fall back to the default order when prefer is empty", function()
			fake("mini.pick", {
				start = function()
					return "a"
				end,
			})
			config.options.prefer = {}

			local cb = make_cb()
			picker.ask_user_for_choice("Prompt", { "a" }, cb.fn)

			assert.is_true(wait_for(function()
				return cb.calls > 0
			end))
			assert.are.equal("a", cb.value)
		end)

		it("should only use backends listed in prefer", function()
			fake("mini.pick", {
				start = function()
					return "a"
				end,
			})
			config.options.prefer = { "snacks" }

			local cb = make_cb()
			picker.ask_user_for_choice("Prompt", { "a" }, cb.fn)

			assert.is_true(wait_for(function()
				return cb.calls > 0
			end))
			assert.is_nil(cb.value)
			assert.stub(notify_stub).was_called(1)
		end)
	end)

	describe("snacks backend", function()
		it("should pass items and title to snacks and return the chosen string", function()
			local seen
			fake("snacks", {
				picker = {
					select = function(items, opts, cb)
						seen = { items = items, title = opts.title }
						cb("b")
					end,
				},
			})

			local cb = make_cb()
			picker.ask_user_for_choice("Pick one", { "a", "b" }, cb.fn)

			assert.is_true(wait_for(function()
				return cb.calls > 0
			end))
			assert.are.same({ items = { "a", "b" }, title = "Pick one" }, seen)
			assert.are.equal("b", cb.value)
		end)

		it("should return nil when the user cancels", function()
			fake("snacks", {
				picker = {
					select = function(_, _, cb)
						cb(nil)
					end,
				},
			})

			local cb = make_cb()
			picker.ask_user_for_choice("Pick", { "a" }, cb.fn)

			assert.is_true(wait_for(function()
				return cb.calls > 0
			end))
			assert.is_nil(cb.value)
		end)

		it("should return nil when snacks yields a non-string item", function()
			fake("snacks", {
				picker = {
					select = function(_, _, cb)
						cb({ text = "a" })
					end,
				},
			})

			local cb = make_cb()
			picker.ask_user_for_choice("Pick", { "a" }, cb.fn)

			assert.is_true(wait_for(function()
				return cb.calls > 0
			end))
			assert.is_nil(cb.value)
		end)

		it("should not be selected when snacks has no picker.select", function()
			fake("snacks", { picker = {} })

			local cb = make_cb()
			picker.ask_user_for_choice("Pick", { "a" }, cb.fn)

			assert.is_true(wait_for(function()
				return cb.calls > 0
			end))
			assert.is_nil(cb.value)
			assert
				.stub(notify_stub)
				.was_called_with("No picker backend available (snacks.nvim / telescope.nvim / mini.pick)", vim.log.levels.ERROR)
		end)
	end)

	describe("mini.pick backend", function()
		it("should return the picked item", function()
			local seen
			fake("mini.pick", {
				start = function(cfg)
					seen = cfg
					return "b"
				end,
			})
			config.options.prefer = { "mini" }

			local cb = make_cb()
			picker.ask_user_for_choice("Pick one", { "a", "b" }, cb.fn)

			assert.is_true(wait_for(function()
				return cb.calls > 0
			end))
			assert.are.equal("b", cb.value)
			assert.are.same({ "a", "b" }, seen.source.items)
			assert.are.equal("Pick one> ", seen.window.prompt_prefix)
		end)

		it("should return nil when the user aborts", function()
			fake("mini.pick", {
				start = function()
					return nil
				end,
			})
			config.options.prefer = { "mini" }

			local cb = make_cb()
			picker.ask_user_for_choice("Pick", { "a" }, cb.fn)

			assert.is_true(wait_for(function()
				return cb.calls > 0
			end))
			assert.is_nil(cb.value)
		end)

		it("should return nil when mini.pick raises an error", function()
			fake("mini.pick", {
				start = function()
					error("kaboom")
				end,
			})
			config.options.prefer = { "mini" }

			local cb = make_cb()
			picker.ask_user_for_choice("Pick", { "a" }, cb.fn)

			assert.is_true(wait_for(function()
				return cb.calls > 0
			end))
			assert.is_nil(cb.value)
		end)
	end)

	describe("telescope backend", function()
		local spec -- the table passed to pickers.new
		local mappings
		local selected
		local bufnr

		-- Install fake telescope modules. `close` wipes the prompt buffer like the real one.
		local function install_telescope()
			spec, mappings, selected = nil, {}, nil

			bufnr = vim.api.nvim_create_buf(false, true)

			fake("telescope", {})
			fake("telescope.pickers", {
				new = function(_, s)
					spec = s
					return {
						find = function()
							s.attach_mappings(bufnr, function(mode, lhs, fn)
								mappings[mode .. lhs] = fn
							end)
						end,
					}
				end,
			})
			fake("telescope.finders", {
				new_table = function(t)
					return t
				end,
			})
			fake("telescope.config", {
				values = {
					generic_sorter = function()
						return "sorter"
					end,
				},
			})
			fake("telescope.actions", {
				close = function(b)
					if vim.api.nvim_buf_is_valid(b) then
						vim.api.nvim_buf_delete(b, { force = true })
					end
				end,
			})
			fake("telescope.actions.state", {
				get_selected_entry = function()
					return selected
				end,
			})
			config.options.prefer = { "telescope" }
		end

		after_each(function()
			if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
				vim.api.nvim_buf_delete(bufnr, { force = true })
			end
		end)

		it("should build the picker with the prompt title and items", function()
			install_telescope()

			local cb = make_cb()
			picker.ask_user_for_choice("Pick one", { "a", "b" }, cb.fn)

			assert.is_true(wait_for(function()
				return spec ~= nil and next(mappings) ~= nil
			end))
			assert.are.equal("Pick one", spec.prompt_title)
			assert.are.same({ "a", "b" }, spec.finder.results)
			assert.are.equal("sorter", spec.sorter)

			local entry = spec.finder.entry_maker("a")
			assert.are.same({ value = "a", display = "a", ordinal = "a" }, entry)
		end)

		it("should return the selected entry on <CR> in insert and normal mode", function()
			for _, mode in ipairs({ "i", "n" }) do
				install_telescope()
				selected = { value = "b" }

				local cb = make_cb()
				picker.ask_user_for_choice("Pick", { "a", "b" }, cb.fn)
				assert.is_true(wait_for(function()
					return mappings[mode .. "<CR>"] ~= nil
				end))

				mappings[mode .. "<CR>"]()

				assert.is_true(wait_for(function()
					return cb.calls > 0
				end))
				assert.are.equal("b", cb.value)
			end
		end)

		it("should return nil on <CR> when nothing is selected", function()
			install_telescope()
			selected = nil

			local cb = make_cb()
			picker.ask_user_for_choice("Pick", { "a" }, cb.fn)
			assert.is_true(wait_for(function()
				return mappings["i<CR>"] ~= nil
			end))

			mappings["i<CR>"]()

			assert.is_true(wait_for(function()
				return cb.calls > 0
			end))
			assert.is_nil(cb.value)
		end)

		it("should fall back to sel[1] when the entry has no value field", function()
			install_telescope()
			selected = { "plain" }

			local cb = make_cb()
			picker.ask_user_for_choice("Pick", { "plain" }, cb.fn)
			assert.is_true(wait_for(function()
				return mappings["i<CR>"] ~= nil
			end))

			mappings["i<CR>"]()

			assert.is_true(wait_for(function()
				return cb.calls > 0
			end))
			assert.are.equal("plain", cb.value)
		end)

		it("should call cb(nil) for each cancel mapping", function()
			for _, key in ipairs({ "i<C-c>", "n<Esc>", "nq" }) do
				install_telescope()
				selected = { value = "ignored" }

				local cb = make_cb()
				picker.ask_user_for_choice("Pick", { "a" }, cb.fn)
				assert.is_true(wait_for(function()
					return mappings[key] ~= nil
				end))

				mappings[key]()

				assert.is_true(wait_for(function()
					return cb.calls > 0
				end))
				assert.is_nil(cb.value)
			end
		end)

		it("should call cb(nil) when the picker buffer is closed some other way", function()
			install_telescope()

			local cb = make_cb()
			picker.ask_user_for_choice("Pick", { "a" }, cb.fn)
			assert.is_true(wait_for(function()
				return next(mappings) ~= nil
			end))

			-- e.g. :q, <C-q> or focus loss: no mapping is triggered
			vim.api.nvim_buf_delete(bufnr, { force = true })

			assert.is_true(wait_for(function()
				return cb.calls > 0
			end))
			assert.is_nil(cb.value)
		end)

		it("should call the callback exactly once when choosing closes the buffer", function()
			install_telescope()
			selected = { value = "a" }

			local cb = make_cb()
			picker.ask_user_for_choice("Pick", { "a" }, cb.fn)
			assert.is_true(wait_for(function()
				return mappings["i<CR>"] ~= nil
			end))

			-- choose() closes the buffer, which fires BufWipeout too
			mappings["i<CR>"]()

			assert.is_true(wait_for(function()
				return cb.calls > 0
			end))
			vim.wait(50)
			assert.are.equal(1, cb.calls)
			assert.are.equal("a", cb.value)
		end)

		it("should call the callback exactly once when cancelling closes the buffer", function()
			install_telescope()

			local cb = make_cb()
			picker.ask_user_for_choice("Pick", { "a" }, cb.fn)
			assert.is_true(wait_for(function()
				return mappings["n<Esc>"] ~= nil
			end))

			mappings["n<Esc>"]()

			assert.is_true(wait_for(function()
				return cb.calls > 0
			end))
			vim.wait(50)
			assert.are.equal(1, cb.calls)
		end)

		it("should call cb(nil) when a telescope submodule is missing", function()
			install_telescope()
			package.loaded["telescope.finders"] = nil
			package.preload["telescope.finders"] = function()
				error("missing")
			end

			local cb = make_cb()
			picker.ask_user_for_choice("Pick", { "a" }, cb.fn)

			assert.is_true(wait_for(function()
				return cb.calls > 0
			end))
			assert.is_nil(cb.value)
		end)
	end)
end)
