local api = vim.api

local M = {
	input = {},
	result = {},
}

-- ======================
-- Utils: sizing/centering
-- ======================

-- Get the drawable editor size from the active UI (handles cmdheight/tabline properly)
local function editor_size()
	local ui = api.nvim_list_uis()[1]
	if ui then
		return ui.width, ui.height
	end
	return vim.o.columns, vim.o.lines
end

--- Calculate centered window position and size
--- @param width integer content width
--- @param height integer content height
--- @return {width: integer, height: integer, row: integer, col: integer}
local function centered_opts(width, height)
	local columns, lines = editor_size()
	local win_width = math.max(1, math.floor(width))
	local win_height = math.max(1, math.floor(height))
	local row = math.floor((lines - win_height) / 2)
	local col = math.floor((columns - win_width) / 2)
	return {
		width = win_width,
		height = win_height,
		row = row,
		col = col,
	}
end

--- UTF-8 + wide-char safe centering for a single line
--- @param s string
local function center_line(s)
	local width = api.nvim_win_get_width(0)
	local disp = vim.fn.strdisplaywidth(s)
	local pad = math.max(0, math.floor((width - disp) / 2))
	return string.rep(" ", pad) .. s
end

-- ======================
-- Utils: safe buffer edits
-- ======================

--- Temporarily set modifiable, run fn, then restore original state
local function with_modifiable(buf, fn)
	local prev = vim.bo[buf].modifiable
	vim.bo[buf].modifiable = true
	local ok, err = pcall(fn)
	vim.bo[buf].modifiable = prev
	if not ok then
		error(err)
	end
end

--- Replace buffer lines from start_idx to end with given lines
local function set_lines(buf, start_idx, lines)
	with_modifiable(buf, function()
		api.nvim_buf_set_lines(buf, start_idx, -1, false, lines)
	end)
end

--- Append lines to the end of the buffer
local function append_lines(buf, lines)
	with_modifiable(buf, function()
		local curr = api.nvim_buf_get_lines(buf, 0, -1, false)
		api.nvim_buf_set_lines(buf, 0, -1, false, vim.list_extend(curr, lines))
	end)
end

-- ======================
-- Floats: single-window with built-in border/title
-- ======================

--- Open a floating window with built-in border/title (no separate border buffer)
--- @param opts table nvim_open_win config overrides (width/height/row/col required)
--- @return integer win, integer buf
local function open_float(opts)
	local buf = api.nvim_create_buf(false, true)

	-- Buffer-local options (ephemeral scratch)
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].filetype = "projektgunnar"
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].swapfile = false
	vim.bo[buf].buflisted = false
	vim.bo[buf].modifiable = false
	vim.bo[buf].readonly = false

	-- Open window
	local win = api.nvim_open_win(
		buf,
		true,
		vim.tbl_extend("force", {
			style = "minimal",
			relative = "editor",
			border = "rounded", -- Or a custom 8-char table if you prefer
			title = opts.title or "",
			title_pos = "center",
			noautocmd = true,
			zindex = 200,
			width = opts.width,
			height = opts.height,
			row = opts.row,
			col = opts.col,
		}, opts)
	)

	-- Window-local cosmetics
	vim.wo[win].number = false
	vim.wo[win].relativenumber = false
	vim.wo[win].signcolumn = "no"
	vim.wo[win].cursorline = false
	vim.wo[win].foldcolumn = "0"
	vim.wo[win].wrap = false
	vim.wo[win].list = false
	vim.wo[win].winblend = 0

	return win, buf
end

--- Keep a window centered when the UI resizes
--- @param win integer
--- @param width integer
--- @param height integer
local function recenter_on_resize(win, width, height)
	local aug = api.nvim_create_augroup("projektgunnar_recenter_" .. tostring(win), { clear = true })
	api.nvim_create_autocmd("VimResized", {
		group = aug,
		callback = function()
			if not api.nvim_win_is_valid(win) then
				return
			end
			local c = centered_opts(width, height)
			pcall(api.nvim_win_set_config, win, {
				relative = "editor",
				row = c.row,
				col = c.col,
				width = c.width,
				height = c.height,
			})
		end,
	})
end

-- ======================
-- Spinner: timer-based per buffer
-- ======================

local spinners = {} -- buf -> {timer=uv_timer, idx=int}
local spinner_chars = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

---@diagnostic disable: need-check-nil
local function spinner_start(buf, interval_ms)
	if spinners[buf] then
		return
	end
	local timer = vim.uv.new_timer()
	local idx = 1

	timer:start(
		0,
		interval_ms or 80,
		vim.schedule_wrap(function()
			if not api.nvim_buf_is_valid(buf) then
				timer:stop()
				timer:close()
				spinners[buf] = nil
				return
			end
			with_modifiable(buf, function()
				local curr = api.nvim_buf_get_lines(buf, 0, -1, false)
				if #curr == 0 then
					curr = { "" }
				end
				local last = curr[#curr] or ""

				-- Strip a single leading UTF-8 char and optional space (previous spinner)
				local stripped = last:gsub("^[%z\1-\127\194-\244][\128-\191]*%s?", "")

				curr[#curr] = spinner_chars[idx] .. " " .. stripped
				api.nvim_buf_set_lines(buf, 0, -1, false, curr)
			end)
			idx = (idx % #spinner_chars) + 1
		end)
	)
	---@diagnostic enable: need-check-nil

	spinners[buf] = { timer = timer, idx = 1 }

	-- Auto-stop when buffer is wiped
	api.nvim_create_autocmd("BufWipeout", {
		buffer = buf,
		once = true,
		callback = function()
			local s = spinners[buf]
			if s then
				s.timer:stop()
				s.timer:close()
			end
			spinners[buf] = nil
		end,
	})
end

local function spinner_stop(buf)
	local s = spinners[buf]
	if not s then
		return
	end
	s.timer:stop()
	s.timer:close()
	spinners[buf] = nil
end

-- ======================
-- Public API: Input popup
-- ======================

--- Open a centered one-line input popup
--- @param on_confirm fun(text: string)
--- @param opts? { title?: string, width?: integer }
function M.input.open(on_confirm, opts)
	opts = opts or {}
	local title = opts.title or ""
	local width = opts.width or 25

	-- Only one content line for typing. Title is shown in the window border.
	local input_height = 1
	local c = centered_opts(width, input_height)

	-- Open float with a border title; no extra title line in the buffer
	local win, buf = open_float({
		width = c.width,
		height = c.height,
		row = c.row,
		col = c.col,
		title = title, -- shown in the border
	})

	recenter_on_resize(win, c.width, c.height)

	-- Initialize the buffer with a single empty line
	set_lines(buf, 0, { "" })

	-- IMPORTANT: allow typing
	vim.bo[buf].modifiable = true
	vim.bo[buf].readonly = false

	-- Focus the input line and enter insert mode
	api.nvim_set_current_win(win)
	api.nvim_win_set_cursor(win, { 1, 0 })
	vim.schedule(function()
		vim.cmd("startinsert")
	end)

	-- Close helpers (guard double-close)
	local closed = false
	local function close_win()
		if closed then
			return
		end
		closed = true
		if api.nvim_win_is_valid(win) then
			pcall(api.nvim_win_close, win, true)
		end
	end

	-- Close on BufLeave (nice for transient UI)
	api.nvim_create_autocmd("BufLeave", {
		buffer = buf,
		once = true,
		callback = close_win,
	})

	local kmopts = { buffer = buf, silent = true, noremap = true, nowait = true, desc = "ProjektGunnar input" }

	vim.keymap.set({ "i", "n" }, "<Esc>", close_win, kmopts)
	vim.keymap.set({ "i", "n" }, "<C-c>", close_win, kmopts)
	vim.keymap.set("n", "q", close_win, kmopts)

	vim.keymap.set({ "i", "n" }, "<CR>", function()
		local line = api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""
		line = vim.trim(line)
		close_win()
		pcall(on_confirm, line)
		pcall(vim.cmd.stopinsert)
	end, kmopts)

	return buf
end

-- ======================
-- Public API: Result window
-- ======================

--- Open a large centered result window (80% of editor)
--- @return integer buf
function M.result.open()
	local columns, lines = editor_size()
	local w = math.ceil(columns * 0.8)
	local h = math.ceil(lines * 0.8 - 2)
	local c = centered_opts(w, h)

	local win, buf = open_float({
		width = c.width,
		height = c.height,
		row = c.row,
		col = c.col,
		title = "ProjektGunnar", -- keep title in border only
	})

	recenter_on_resize(win, c.width, c.height)

	-- Header/help text without duplicating the title
	set_lines(buf, 0, {
		center_line("Close window with 'q'"),
		"",
		"",
	})

	local kmopts = { buffer = buf, silent = true, noremap = true, nowait = true, desc = "Close result window" }
	vim.keymap.set("n", "q", function()
		if api.nvim_win_is_valid(win) then
			pcall(api.nvim_win_close, win, true)
		end
	end, kmopts)

	api.nvim_create_autocmd("BufLeave", {
		buffer = buf,
		once = true,
		callback = function()
			if api.nvim_win_is_valid(win) then
				pcall(api.nvim_win_close, win, true)
			end
		end,
	})

	return buf
end

--- Print a single message (replaces content area below header)
--- @param buf integer
--- @param msg string
function M.result.print(buf, msg)
	set_lines(buf, 5, { msg, "----------------------------------------" })
end

--- Append a progress line ("Updating project X of Y")
--- @param buf integer
--- @param index integer
--- @param total integer
function M.result.progress(buf, index, total)
	append_lines(buf, {
		"Updating project " .. tostring(index) .. " out of " .. tostring(total),
		"----------------------------------------",
	})
end

--- Append a result block for one command (no highlights, as requested)
--- @param buf integer
--- @param index integer
--- @param total integer
--- @param success boolean
--- @param cmd string
function M.result.update(buf, index, total, success, cmd)
	local status_symbol = success and "" or ""
	local status_message = success and "Success" or "Failed"
	append_lines(buf, {
		tostring(index) .. " out of " .. tostring(total),
		"Status: " .. status_message .. " " .. status_symbol,
		"Command: " .. cmd,
		"----------------------------------------",
	})
end

--- Start/update spinner on the last line (timer-driven)
--- Public API: keep name but delegate to the timer-based spinner
--- @param buf integer
function M.result.spinner(buf)
	spinner_start(buf, 80)
end

--- Remove spinner and keep the text without the spinner prefix
--- @param buf integer
function M.result.clear_spinner(buf)
	spinner_stop(buf)
	-- Strip spinner char if present on the last line
	with_modifiable(buf, function()
		local curr = api.nvim_buf_get_lines(buf, 0, -1, false)
		if #curr == 0 then
			return
		end
		curr[#curr] = (curr[#curr] or ""):gsub("^[%z\1-\127\194-\244][\128-\191]*%s?", "")
		api.nvim_buf_set_lines(buf, 0, -1, false, curr)
	end)
end

--- Append a final "Done!" block
--- @param buf integer
function M.result.done(buf)
	append_lines(buf, { "Done!", "----------------------------------------" })
end

return M
