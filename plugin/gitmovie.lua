-- GitMovie: Neovim plugin entrypoints

-- Define highlight groups for diff coloring
vim.api.nvim_set_hl(0, "GitMovieAdd", { fg = "#00cc44", bold = true })
vim.api.nvim_set_hl(0, "GitMovieDel", { fg = "#ff3333", bold = true })
vim.api.nvim_set_hl(0, "GitMovieCtx", { fg = "#888888" })

-- Open the interactive player UI (navigate commits manually with h/l)
vim.api.nvim_create_user_command("GitMovie", function()
	require("gitmovie").open_movie_player()
end, { desc = "Open GitMovie player" })

-- Start auto-playback (optional repo path argument)
vim.api.nvim_create_user_command("GitMovieStart", function(opts)
	local path = opts.args ~= "" and opts.args or nil
	require("gitmovie").start(path)
end, { nargs = "?", desc = "Start GitMovie auto-playback", complete = "dir" })

-- Stop playback and close the viewer
vim.api.nvim_create_user_command("GitMovieStop", function()
	require("gitmovie").stop()
end, { desc = "Stop GitMovie and close viewer" })

-- Set the repository path for subsequent commands
vim.api.nvim_create_user_command("GitMovieSetRepo", function(opts)
	require("gitmovie").set_repo(opts.args)
end, { nargs = 1, desc = "Set GitMovie repository path", complete = "dir" })

-- Set animation speed in milliseconds per frame
vim.api.nvim_create_user_command("GitMovieSpeed", function(opts)
	local ms = tonumber(opts.args)
	if not ms then
		vim.notify("GitMovieSpeed: expected a number (ms per frame)", vim.log.levels.ERROR)
		return
	end
	require("gitmovie").set_speed(ms)
end, { nargs = 1, desc = "Set GitMovie frame speed in ms" })
