-- GitMovie: Neovim plugin entrypoints

vim.keymap.set("n", "<leader>gms", function()
	require("gitmovie").play()
end, { desc = "GitMovie: play git history" })

vim.api.nvim_create_user_command("GitMovie", function()
	require("gitmovie").play()
end, {})
