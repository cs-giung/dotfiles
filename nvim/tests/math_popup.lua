-- Run: nvim --headless -u NONE -l nvim/tests/math_popup.lua
-- Requires installed markdown/markdown_inline/latex parsers, pdflatex and magick.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.runtimepath:prepend(root)
local tmp = vim.fn.tempname()
vim.fn.mkdir(tmp, "p")
local previous_cache = vim.env.XDG_CACHE_HOME
vim.env.XDG_CACHE_HOME = tmp
local cache = vim.fn.stdpath("cache") .. "/math-popup"
local rendered, cleared = {}, 0
local calls, killed = 0, 0
local real_system = vim.system
local messages = {}
local real_notify = vim.notify
vim.notify = function(message) messages[#messages + 1] = message end
vim.system = function(...)
    calls = calls + 1
    local process = real_system(...)
    return {
        kill = function(_, signal)
            killed = killed + 1
            return process:kill(signal)
        end,
    }
end
-- Exercise real floats, parsing and async conversion without emitting terminal graphics.
package.loaded["image"] = {
    from_file = function(path)
        assert(vim.fn.filereadable(path) == 1)
        return {
            image_width = 240,
            image_height = 80,
            render = function(self, geometry)
                assert(vim.api.nvim_win_is_valid(self.window))
                assert(geometry.width > 0 and geometry.height > 0)
                rendered[#rendered + 1] = path
            end,
            clear = function() cleared = cleared + 1 end,
        }
    end,
}
package.loaded["image/utils/term"] = {
    get_size = function() return { cell_width = 10, cell_height = 20 } end,
}
package.loaded["image/utils/math"] = {
    adjust_to_aspect_ratio = function(_, _, _, width, height) return width, height end,
}

local function run()
    for _, lang in ipairs({ "markdown", "markdown_inline", "latex" }) do
        assert(vim.treesitter.language.add(lang), "Missing parser: " .. lang)
    end
    for _, tool in ipairs({ "pdflatex", "magick" }) do
        assert(vim.fn.executable(tool) == 1, "Missing executable: " .. tool)
    end
    local mod = require("math_popup")
    local buf = vim.api.nvim_get_current_buf()
    local nonce = tostring(vim.uv.hrtime())
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "text $\\alpha + x^2 + " .. nonce .. "$ end",
        "plain text",
        "$$",
        "\\sum_{i=1}^{n} i",
        "$$",
        "`$not_math$`",
        "![picture](./picture.png)",
        "$\\nonexistentpopupcommand{x}$",
    })
    vim.bo[buf].filetype = "markdown"
    assert(mod.find_math(buf, 0, 8):match("alpha"), "inline math not found")
    assert(not mod.find_math(buf, 0, 0), "prose mistaken for math")
    assert(not mod.find_math(buf, 1, 0), "another line mistaken for math")
    assert(mod.find_math(buf, 3, 4):match("sum"), "multiline math not found")
    assert(mod.find_math(buf, 2, 0):match("sum"), "opening delimiter not found")
    assert(not mod.find_math(buf, 5, 4), "inline code mistaken for math")
    assert(not mod.find_math(buf, 6, 4), "image link mistaken for math")
    local inline = mod.find_math(buf, 0, 8)
    assert(not mod.find_math(buf, 0, 5 + #inline), "exclusive end matched")

    mod.setup()
    local function move(row, col)
        vim.api.nvim_win_set_cursor(0, { row, col })
        vim.api.nvim_exec_autocmds("CursorMoved", { buffer = buf })
    end
    local function wait_for(predicate, message)
        assert(vim.wait(20000, predicate, 20), message .. ": " .. table.concat(messages, "\n"))
    end
    local timers_before = #vim.fn.timer_info()
    for _ = 1, 40 do
        move(1, 8)
        move(2, 0)
    end
    move(1, 8)
    assert(#vim.fn.timer_info() == timers_before + 1, "cursor burst queued multiple debounce timers")
    assert(calls == 0, "conversion started before debounce elapsed")
    wait_for(function() return #rendered == 1 end, "inline math never rendered")
    assert(calls == 2, "expected one pdflatex and one magick invocation")
    local first_path = rendered[1]
    local probe = real_system({ "magick", "identify", first_path }, { text = true }):wait()
    assert(probe.code == 0 and probe.stdout:find("PNG"), "conversion did not produce a PNG")

    move(2, 0)
    assert(cleared > 0, "popup was not cleared on cursor movement")
    move(1, 8)
    wait_for(function() return #rendered == 2 end, "cached math never rendered")
    assert(calls == 2, "cache hit unexpectedly reran converter")
    assert(rendered[2] == first_path, "cache path changed")

    -- Cursor movement and scrolling often arrive together. Scrolling must rearm,
    -- not merely invalidate, the pending preview.
    move(2, 0)
    move(1, 8)
    vim.api.nvim_exec_autocmds("WinScrolled", { pattern = tostring(vim.api.nvim_get_current_win()) })
    wait_for(function() return #rendered == 3 end, "scroll cancelled preview without rescheduling")
    assert(calls == 2, "scroll should reuse the cached expression")
    local preview_win
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "math_popup" then preview_win = win end
    end
    assert(preview_win, "math popup missing")
    vim.api.nvim_exec_autocmds("WinScrolled", { pattern = tostring(preview_win) })
    assert(vim.api.nvim_win_is_valid(preview_win), "preview layout closed its own popup")

    -- Fast movement must not launch a stale conversion or popup.
    local before = #rendered
    move(4, 4)
    move(2, 0)
    vim.wait(600, function() return false end, 20)
    assert(#rendered == before and calls == 2, "debounce did not discard stale request")

    -- Invalid TeX should produce a useful log, not an empty popup or repeated jobs.
    move(8, 3)
    wait_for(function() return #messages > 0 end, "conversion failure was not reported")
    assert(messages[#messages]:find("conversion failed"), "unexpected warning")
    assert(#vim.fn.glob(cache .. "/*.log", false, true) == 1, "failure log missing")
    local failed_calls = calls
    move(2, 0)
    move(8, 3)
    vim.wait(600, function() return false end, 20)
    assert(calls == failed_calls and #rendered == before, "failed math was retried or rendered")

    -- Buffer switching while compilation is running must not open a stale float.
    move(4, 4)
    wait_for(function() return calls > failed_calls end, "block conversion did not start")
    local other = vim.api.nvim_create_buf(true, false)
    local killed_before = killed
    vim.api.nvim_set_current_buf(other)
    assert(killed > killed_before, "leaving the buffer did not cancel the conversion")
    assert(#vim.fn.timer_info() == timers_before, "unsupported buffer left a debounce timer running")
    vim.wait(2000, function() return false end, 20)
    assert(#rendered == before, "popup appeared after leaving its buffer")
    vim.api.nvim_set_current_buf(buf)
    move(4, 4)
    wait_for(function() return #rendered > before end, "block math never rendered")
    local before_resize = #rendered
    vim.api.nvim_exec_autocmds("VimResized", {})
    wait_for(function() return #rendered > before_resize end, "resize cancelled preview without rescheduling")
    vim.api.nvim_exec_autocmds("InsertEnter", { buffer = buf })
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        assert(vim.bo[vim.api.nvim_win_get_buf(win)].filetype ~= "math_popup", "insert mode left popup open")
    end

    -- Plain TeX is supported too; ordinary text remains untouched.
    local tex = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_lines(tex, 0, -1, false, { "Text \\(a+b\\)", "\\[x^2\\]", "\\begin{align}", "a&=b", "\\end{align}" })
    vim.bo[tex].filetype = "tex"
    assert(mod.find_math(tex, 0, 8), "TeX inline math missing")
    assert(mod.find_math(tex, 1, 3), "TeX display math missing")
    assert(mod.find_math(tex, 3, 1), "TeX math environment missing")
    assert(not mod.find_math(tex, 0, 0), "TeX prose mistaken for math")
    print("math_popup: parsing, real PNG conversion, caching, bounded debounce, cancellation, errors and lifecycle OK")
end

local ok, err = xpcall(run, debug.traceback)
vim.system = real_system
vim.notify = real_notify
vim.api.nvim_exec_autocmds("VimLeavePre", {})
vim.env.XDG_CACHE_HOME = previous_cache
vim.fn.delete(tmp, "rf")
if not ok then
    io.stderr:write(err .. "\n")
    vim.cmd("cquit 1")
else
    vim.cmd("qa!")
end
