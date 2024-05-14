local picker = require("mini.pick")

local M = {}

local chosen_item = nil

-- present user with a list of choices and return the choice
-- @param prompt string
-- @param items table
-- @return string
function M.ask_user_for_choice(prompt, items)
	local mini_pick_config = {
		window = {
			prompt_prefix = prompt .. "> ",
		},
		source = { items = items },
	}

	picker.start(mini_pick_config)

	return chosen_item
end

return M
