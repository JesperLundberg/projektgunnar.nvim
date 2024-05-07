local picker = require("mini.pick")

local M = {}

local chosen_item = nil

-- present user with a list of choices and return the choice
-- @param items table
-- @return string
function M.ask_user_for_choice(items)
	print("items: ", vim.inspect(items))

	picker.ui_select(items, {}, function(choice)
		chosen_item = choice
	end)

	print("chosen_item: ", chosen_item)

	return chosen_item
end

return M
