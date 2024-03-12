local api = vim.api

local M = {}

-- Method to center a string in a window
-- @param str string
local function center(str)
	local width = api.nvim_win_get_width(0)
	local shift = math.floor(width / 2) - math.floor(string.len(str) / 2)
	return string.rep(" ", shift) .. str
end

-- Floating result window
-- @return number, number
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

	-- we can add title already here, because first line will never change
	api.nvim_buf_set_lines(buf, 0, -1, false, { center("ProjektGunnar"), "", "" })

	return win, buf -- Return window and buffer handles
end

function M.update_with_done_message(win, buf)
	-- Make the buffer modifiable
	api.nvim_buf_set_option(buf, "modifiable", true)

	-- Get the current lines in the buffer
	local current_lines = api.nvim_buf_get_lines(buf, 0, -1, false)

	local new_lines = {
		"Done!",
		"----------------------------------------",
	}

	-- Add the new lines to the current lines
	local lines_to_write = vim.list_extend(current_lines, new_lines)

	-- Set the updated lines
	api.nvim_buf_set_lines(buf, 0, -1, false, lines_to_write)

	-- Make the buffer unmodifiable
	api.nvim_buf_set_option(buf, "modifiable", false)

	-- Set the cursor to the last line
	api.nvim_win_set_cursor(win, { #lines_to_write, 0 })
end

-- Method to print what command will be run
-- @param win window handle
-- @param buf buffer handle
-- @param message string
function M.print_message(win, buf, message)
	-- Make the buffer modifiable
	api.nvim_buf_set_option(buf, "modifiable", true)

	-- Add delimiter under the message
	message = { message, "----------------------------------------" }

	-- Set the message
	api.nvim_buf_set_lines(buf, 2, -1, false, message)

	-- Make the buffer unmodifiable
	api.nvim_buf_set_option(buf, "modifiable", false)

	-- Set the cursor to the last line
	api.nvim_win_set_cursor(win, { #message, 2 })
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

	local status_symbol = success and "" or ""
	local status_message = success and "Success" or "Failed"

	local new_lines = {
		tostring(index) .. " out of " .. tostring(total),
		"Status: " .. status_message .. " " .. status_symbol,
		"Command: " .. command_output,
		"----------------------------------------",
	}

	-- Add the new lines to the current lines
	local lines_to_write = vim.list_extend(current_lines, new_lines)

	-- Set the updated lines
	api.nvim_buf_set_lines(buf, 0, -1, false, lines_to_write)

	-- Make the buffer unmodifiable
	api.nvim_buf_set_option(buf, "modifiable", false)

	-- Set the cursor to the last line
	api.nvim_win_set_cursor(win, { #lines_to_write, 0 })
end

function M.update_progress(win, buf, index, total)
	-- Make the buffer modifiable
	api.nvim_buf_set_option(buf, "modifiable", true)

	-- Get the current lines in the buffer
	local current_lines = api.nvim_buf_get_lines(buf, 0, -1, false)

	local new_lines = {
		"Updating project " .. tostring(index) .. " out of " .. tostring(total),
		"----------------------------------------",
	}

	-- Add the new lines to the current lines
	local lines_to_write = vim.list_extend(current_lines, new_lines)

	-- Set the updated lines
	api.nvim_buf_set_lines(buf, 0, -1, false, lines_to_write)

	-- Make the buffer unmodifiable
	api.nvim_buf_set_option(buf, "modifiable", false)

	-- Set the cursor to the last line
	api.nvim_win_set_cursor(win, { #lines_to_write, 0 })
end

return M
