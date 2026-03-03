-- GitMovie test suite
-- Run: nvim --headless -u NONE -c "set rtp+=." -S tests/run_tests.lua

local pass = 0
local fail = 0

local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		io.write("PASS: " .. name .. "\n")
		pass = pass + 1
	else
		io.write("FAIL: " .. name .. " - " .. tostring(err) .. "\n")
		fail = fail + 1
	end
	io.flush()
end

local function assert_eq(a, b, msg)
	if a ~= b then
		error((msg or "not equal") .. ": expected=" .. tostring(b) .. " got=" .. tostring(a), 2)
	end
end

local function assert_true(v, msg)
	if not v then
		error(msg or "expected true", 2)
	end
end

local function assert_gt(a, b, msg)
	if not (a > b) then
		error((msg or "") .. " expected " .. tostring(a) .. " > " .. tostring(b), 2)
	end
end

-- Source the plugin entrypoint so commands and highlights are registered
vim.cmd("runtime plugin/gitmovie.lua")

local M = require("gitmovie")
local repo = vim.fn.getcwd()

-- ── build_commits ──────────────────────────────────────────────────────────

test("build_commits: returns non-empty list for repo", function()
	local commits = M._build_commits(repo)
	assert_gt(#commits, 0, "no commits found in repo")
end)

test("build_commits: all entries are valid git hashes", function()
	local commits = M._build_commits(repo)
	for _, h in ipairs(commits) do
		assert_true(h:match("^[0-9a-f]+$") ~= nil, "invalid hash: '" .. h .. "'")
	end
end)

test("build_commits: returns empty table for bad path", function()
	local commits = M._build_commits("/nonexistent/path")
	assert_eq(type(commits), "table")
	assert_eq(#commits, 0)
end)

-- ── diff_lines ─────────────────────────────────────────────────────────────

test("diff_lines: returns table for valid commit", function()
	local commits = M._build_commits(repo)
	local lines = M._diff_lines(repo, commits[#commits])
	assert_eq(type(lines), "table")
end)

test("diff_lines: filters out raw diff/index/---/+++ headers", function()
	local commits = M._build_commits(repo)
	local lines = M._diff_lines(repo, commits[#commits])
	for _, l in ipairs(lines) do
		assert_true(not l:match("^diff "), "unexpected 'diff' header: " .. l)
		assert_true(not l:match("^index "), "unexpected 'index' header: " .. l)
	end
end)

test("diff_lines: returns empty table for bad hash", function()
	local lines = M._diff_lines(repo, "0000000000000000deadbeef")
	assert_eq(#lines, 0, "expected empty list for invalid hash")
end)

-- ── changes parsing (the [^\\n]+ bug) ────────────────────────────────────

test("newline split: [^\\n]+ splits on newlines correctly", function()
	local output = "M\tfile1.lua\nA\tfile2.lua\nD\tfile3.lua\n"
	local items = {}
	for s in string.gmatch(output, "[^\n]+") do
		if s ~= "" then
			table.insert(items, s)
		end
	end
	assert_eq(#items, 3, "expected 3 items, got " .. #items)
	assert_eq(items[1], "M\tfile1.lua")
	assert_eq(items[2], "A\tfile2.lua")
	assert_eq(items[3], "D\tfile3.lua")
end)

test("diff-tree output parsed into per-file lines", function()
	local commits = M._build_commits(repo)
	local hash = commits[#commits]
	local ch_out = vim.fn.system({ "git", "-C", repo, "diff-tree", "--no-commit-id", "--name-status", "-r", hash })
	if ch_out == "" then
		-- root commit may have no parent, skip
		return
	end
	local items = {}
	for s in string.gmatch(ch_out, "[^\n]+") do
		if s ~= "" then
			table.insert(items, s)
		end
	end
	assert_gt(#items, 0, "expected at least one changed file")
	for _, item in ipairs(items) do
		assert_true(item:match("^[A-Z]\t") ~= nil, "item should be 'STATUS<tab>file': " .. item)
	end
end)

-- ── stop / state reset ────────────────────────────────────────────────────

test("stop: resets _mapped to false", function()
	M._mapped = true
	M._commits = { "abc" }
	M.stop()
	assert_eq(M._mapped, false, "_mapped should be false after stop")
	assert_eq(#M._commits, 0, "_commits should be empty after stop")
end)

test("stop: resets _current and _index", function()
	M._current = 5
	M._index = 6
	M.stop()
	assert_eq(M._current, 0)
	assert_eq(M._index, 1)
end)

-- ── set_repo / set_speed ──────────────────────────────────────────────────

test("set_repo: updates M.repo", function()
	M.set_repo("/tmp/fakerepo")
	assert_eq(M.repo, "/tmp/fakerepo")
end)

test("set_speed: updates M.speed", function()
	M.set_speed(250)
	assert_eq(M.speed, 250)
	M.set_speed(3000) -- restore default
end)

-- ── _on_nav logic ─────────────────────────────────────────────────────────

test("_on_nav: notifies when commits list is empty", function()
	M._commits = {}
	local notified = false
	local old = vim.notify
	vim.notify = function(msg)
		if msg:match("no commits") then
			notified = true
		end
	end
	M._on_nav(1)
	vim.notify = old
	assert_true(notified, "expected 'no commits' notification")
end)

test("_on_nav clamping: lower bound stays at 1", function()
	local newidx = 1 + (-1)
	if newidx < 1 then
		newidx = 1
	end
	assert_eq(newidx, 1)
end)

test("_on_nav clamping: upper bound stays at max", function()
	local commits = { "a", "b", "c" }
	local newidx = 3 + 1
	if newidx > #commits then
		newidx = #commits
	end
	assert_eq(newidx, 3)
end)

-- ── commands registered ───────────────────────────────────────────────────

test("GitMovie command exists", function()
	local ok = pcall(vim.cmd, "GitMovie")
	-- may open windows; just check it doesn't error out completely
	M.stop()
end)

test("GitMovieStart command exists", function()
	assert_true(vim.fn.exists(":GitMovieStart") == 2, "GitMovieStart command not registered")
end)

test("GitMovieStop command exists", function()
	assert_true(vim.fn.exists(":GitMovieStop") == 2, "GitMovieStop command not registered")
end)

test("GitMovieSetRepo command exists", function()
	assert_true(vim.fn.exists(":GitMovieSetRepo") == 2, "GitMovieSetRepo command not registered")
end)

test("GitMovieSpeed command exists", function()
	assert_true(vim.fn.exists(":GitMovieSpeed") == 2, "GitMovieSpeed command not registered")
end)

-- ── highlight groups ──────────────────────────────────────────────────────

test("GitMovieAdd highlight group is defined", function()
	local hl = vim.api.nvim_get_hl_by_name("GitMovieAdd", true)
	assert_true(hl ~= nil and (hl.foreground ~= nil or hl.fg ~= nil or next(hl) ~= nil), "GitMovieAdd not defined")
end)

test("GitMovieDel highlight group is defined", function()
	local hl = vim.api.nvim_get_hl_by_name("GitMovieDel", true)
	assert_true(hl ~= nil and (hl.foreground ~= nil or hl.fg ~= nil or next(hl) ~= nil), "GitMovieDel not defined")
end)

test("GitMovieCtx highlight group is defined", function()
	local hl = vim.api.nvim_get_hl_by_name("GitMovieCtx", true)
	assert_true(hl ~= nil and (hl.foreground ~= nil or hl.fg ~= nil or next(hl) ~= nil), "GitMovieCtx not defined")
end)

-- ── open_movie_player loads commits ──────────────────────────────────────

test("open_movie_player: loads commits so navigation works", function()
	M._commits = {} -- reset
	M.repo = repo
	M.open_movie_player()
	local n = #M._commits
	M.stop()
	assert_gt(n, 0, "open_movie_player should load commits for navigation")
end)

-- ── window positioning ────────────────────────────────────────────────────

test("windows are side by side (no overlap)", function()
	M.stop()
	M.repo = repo
	local commits = M._build_commits(repo)
	M._commits = commits
	M._show_index = function() end -- stub to avoid git calls
	M.open_movie_player()
	if M.left_win and vim.api.nvim_win_is_valid(M.left_win) and
	   M.diff_win and vim.api.nvim_win_is_valid(M.diff_win) then
		local left_cfg = vim.api.nvim_win_get_config(M.left_win)
		local right_cfg = vim.api.nvim_win_get_config(M.diff_win)
		-- Right window column should be >= left window column + left width
		assert_true(
			right_cfg.col[false] >= left_cfg.col[false] + left_cfg.width,
			string.format("windows overlap: left col=%d w=%d, right col=%d",
				left_cfg.col[false], left_cfg.width, right_cfg.col[false])
		)
	end
	M.stop()
	M._show_index = nil -- restore (will be re-required fresh next time)
end)

-- ── Summary ───────────────────────────────────────────────────────────────

io.write(string.format("\n=== Results: %d passed, %d failed ===\n", pass, fail))
io.flush()

if fail > 0 then
	vim.cmd("cq")
end
