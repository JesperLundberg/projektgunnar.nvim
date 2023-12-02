local api = vim.api
local M = {}

-- Method to center a string in a window
local function center(str)
	local width = api.nvim_win_get_width(0)
	local shift = math.floor(width / 2) - math.floor(string.len(str) / 2)
	return string.rep(" ", shift) .. str
end

-- Floating result window
function M.open()
	-- Create buffers for both windows
	local buf = api.nvim_create_buf(false, true)
	local border_buf = api.nvim_create_buf(false, true)

	api.nvim_buf_set_option(buf, "bufhidden", "wipe")
	api.nvim_buf_set_option(buf, "filetype", "ProjektGunnar")

	-- Get dimensions of neovim editor
	local width = api.nvim_get_option("columns")
	local height = api.nvim_get_option("lines")

	-- Calculate our floating window size so its 80% of the editor size
	local win_height = math.ceil(height * 0.8 - 4)
	local win_width = math.ceil(width * 0.8)
	local row = math.ceil((height - win_height) / 2 - 1)
	local col = math.ceil((width - win_width) / 2)

	local border_opts = {
		style = "minimal",
		relative = "editor",
		width = win_width + 2,
		height = win_height + 2,
		row = row - 1,
		col = col - 1,
	}

	local opts = {
		style = "minimal",
		relative = "editor",
		width = win_width,
		height = win_height,
		row = row,
		col = col,
	}

	-- Set border buffer lines
	local border_lines = { "╔" .. string.rep("═", win_width) .. "╗" }
	local middle_line = "║" .. string.rep(" ", win_width) .. "║"
	for _ = 1, win_height do
		table.insert(border_lines, middle_line)
	end
	table.insert(border_lines, "╚" .. string.rep("═", win_width) .. "╝")
	api.nvim_buf_set_lines(border_buf, 0, -1, false, border_lines)

	-- Open the border window first then the actual window
	api.nvim_open_win(border_buf, true, border_opts)
	local win = api.nvim_open_win(buf, true, opts)

	-- If the window is closed, close the border window as well
	api.nvim_command('au BufWipeout <buffer> exe "silent bwipeout! "' .. border_buf)

	-- highlight line with the cursor on it TODO: Not needed?!
	api.nvim_win_set_option(win, "cursorline", true)

	-- we can add title already here, because first line will never change
	api.nvim_buf_set_lines(buf, 0, -1, false, { center("ProjektGunnar"), "", "" })
	-- set the header highlight
	api.nvim_buf_add_highlight(buf, -1, "PGHeader", 0, 0, -1) -- TODO: Sort out the highlights

	return win, buf -- Return window and buffer handles
end

-- Method to set the content of the window
-- @param win window handle
-- @param buf buffer handle
-- @param index number
-- @param total number
-- @param success boolean
-- @param command_output string
function M.update(win, buf, index, total, success, command_output)
	-- Make the buffer modifiable
	api.nvim_buf_set_option(buf, "modifiable", true)

	-- Get the current lines in the buffer
	local current_lines = api.nvim_buf_get_lines(buf, 0, -1, false)

	-- Append the new lines
	local status_message = success and "Success" or "Failed"
	local new_lines = {
		tostring(index) .. " out of " .. tostring(total),
		"Status: " .. status_message, -- Highlight failed lines
		"Command: " .. command_output,
		"----------------------------------------",
	}
	local updated_lines = vim.list_extend(current_lines, new_lines)

	-- Set the updated lines
	api.nvim_buf_set_lines(buf, 0, -1, false, updated_lines)

	-- Make the buffer unmodifiable
	api.nvim_buf_set_option(buf, "modifiable", false)

	-- Set the cursor to the last line
	api.nvim_win_set_cursor(win, { #updated_lines, 0 })
end

return M
