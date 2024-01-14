local picker = require("mini.pick")

local M = {}

local chosen_item = nil

function M.AskUserForChoice(items)
	picker.ui_select(items, {}, function(choice)
		chosen_item = choice
	end)

	return chosen_item
end

return M
