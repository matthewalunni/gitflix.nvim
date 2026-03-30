-- Run with:
-- nvim --headless -u NORC --cmd "set rtp+=." -c "luafile tests/test_invert_hunks.lua" -c "q"

local animator = require("gitflix.animator")
local invert = animator._invert_hunks

local function assert_eq(a, b, msg)
	if a ~= b then
		error(string.format("FAIL: %s\n  expected: %s\n  got: %s", msg, tostring(b), tostring(a)), 2)
	end
end

-- Test 1: ops are swapped
local hunk = {
	old_start = 3, old_count = 2,
	new_start = 5, new_count = 4,
	lines = {
		{ op = "-", text = "removed line" },
		{ op = "+", text = "added line" },
		{ op = " ", text = "context line" },
	},
}
local result = invert({ hunk })
assert_eq(#result, 1, "one hunk out")
assert_eq(result[1].lines[1].op, "+", "- becomes +")
assert_eq(result[1].lines[1].text, "removed line", "text preserved on - line")
assert_eq(result[1].lines[2].op, "-", "+ becomes -")
assert_eq(result[1].lines[2].text, "added line", "text preserved on + line")
assert_eq(result[1].lines[3].op, " ", "context unchanged")

-- Test 2: old/new start and count are swapped
assert_eq(result[1].old_start, 5, "old_start = h.new_start")
assert_eq(result[1].old_count, 4, "old_count = h.new_count")
assert_eq(result[1].new_start, 3, "new_start = h.old_start")
assert_eq(result[1].new_count, 2, "new_count = h.old_count")

-- Test 3: original hunks are not mutated
assert_eq(hunk.lines[1].op, "-", "original not mutated")
assert_eq(hunk.old_start, 3, "original start not mutated")

-- Test 4: empty hunk list
local empty = invert({})
assert_eq(#empty, 0, "empty in, empty out")

print("All invert_hunks tests passed.")
