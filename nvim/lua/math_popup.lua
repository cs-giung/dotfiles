-- Cursor-local LaTeX previews using image.nvim's configured backend (Sixel).
local M = {}
local generation = 0
local popup
local job
local debounce_timer
local failures = {}
local filetypes = { markdown = true, vimwiki = true, tex = true, plaintex = true }
local math_nodes = { inline_formula = true, displayed_equation = true, math_environment = true }
local cache_dir = vim.fn.stdpath("cache") .. "/math-popup"

local function trace(event, data)
    local path = vim.g.preview_debug_log
    if not path then return end
    local detail = data and vim.inspect(data, { newline = " ", indent = "" }) or ""
    vim.fn.writefile({ os.date("%H:%M:%S") .. " [math-popup] " .. event .. " " .. detail }, path, "a")
end

local function close()
    if not popup then return end
    local old = popup
    trace("close", { win = old.win })
    popup = nil
    pcall(old.image.clear, old.image)
    if vim.api.nvim_win_is_valid(old.win) then
        vim.api.nvim_win_close(old.win, true)
    end
end

local function cancel_job()
    if not job then return end
    trace("cancel conversion", { key = job.key })
    job.cancelled = true
    if job.process then job.process:kill(15) end
    job = nil
end

---Find the smallest math expression containing the cursor, including injected LaTeX.
---Coordinates are zero-based; the end of a syntax node is exclusive.
function M.find_math(buf, row, col)
    if not filetypes[vim.bo[buf].filetype] then return end
    local lang = (vim.bo[buf].filetype == "markdown" or vim.bo[buf].filetype == "vimwiki")
        and "markdown" or "latex"
    local ok, parser = pcall(vim.treesitter.get_parser, buf, lang)
    if not ok or not parser then return end
    local parsed = pcall(parser.parse, parser, true)
    if not parsed then return end
    local found
    parser:for_each_tree(function(tree, language)
        if language:lang() ~= "latex" then return end
        local node = tree:root():named_descendant_for_range(row, col, row, col)
        while node do
            local sr, sc, er, ec = node:range()
            local inside = (row > sr or (row == sr and col >= sc))
                and (row < er or (row == er and col < ec))
            if inside and math_nodes[node:type()] then
                found = vim.treesitter.get_node_text(node, buf)
                return
            end
            node = node:parent()
        end
    end)
    return found
end

local function colors()
    local hl = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
    local dark = vim.o.background == "dark"
    return string.format("%06X", hl.fg or (dark and 0xEEEEEE or 0x202020)),
        string.format("%06X", hl.bg or (dark and 0x202020 or 0xFFFFFF))
end

local function compile(text, callback)
    if #text > 16000 then return end
    local fg, bg = colors()
    local document = table.concat({
        "\\documentclass[preview,varwidth,border=4pt,12pt]{standalone}",
        "\\usepackage{amsmath,amssymb,amsfonts,mathtools,xcolor}",
        "\\pagestyle{empty}",
        "\\begin{document}",
        "\\color[HTML]{" .. fg .. "}",
        text,
        "\\end{document}",
    }, "\n")
    local key = vim.fn.sha256("v1\n" .. bg .. "\n" .. document)
    local output = cache_dir .. "/" .. key .. ".png"
    if vim.fn.filereadable(output) == 1 then
        trace("cache hit", { key = key })
        callback(output)
        return
    end
    if failures[key] then trace("previous conversion failure", { key = key }); return end
    if job and job.key == key then
        job.callback = callback
        return
    end
    cancel_job()
    for _, tool in ipairs({ "pdflatex", "magick" }) do
        if vim.fn.executable(tool) == 0 then
            failures[key] = true
            vim.notify("Math popup requires " .. tool, vim.log.levels.WARN)
            return
        end
    end
    vim.fn.mkdir(cache_dir, "p")
    -- Keep the build on the cache filesystem so the final rename is atomic.
    local dir = cache_dir .. "/.build-" .. vim.fn.getpid() .. "-" .. tostring(vim.uv.hrtime())
    vim.fn.mkdir(dir, "p", 448)
    vim.fn.writefile(vim.split(document, "\n", { plain = true }), dir .. "/formula.tex")
    local current = { key = key, callback = callback }
    trace("compile start", { key = key })
    job = current

    local function cleanup()
        vim.fn.delete(dir, "rf")
        if job == current then job = nil end
    end

    local function fail(message)
        trace("conversion failed", { key = key })
        local log = cache_dir .. "/" .. key .. ".log"
        vim.fn.writefile(vim.split(message, "\n", { plain = true }), log)
        failures[key] = true
        cleanup()
        vim.notify("Math popup conversion failed; see " .. log, vim.log.levels.WARN)
    end

    local function run(args, next_step)
        local ok, process = pcall(vim.system, args, {
            cwd = dir,
            text = true,
            timeout = 15000,
            -- Disable shell escape and restrict TeX file access; not a full sandbox.
            env = { openin_any = "p", openout_any = "p" },
        }, function(result)
            vim.schedule(function()
                if current.cancelled then
                    cleanup()
                elseif result.code ~= 0 then
                    fail((result.stdout or "") .. "\n" .. (result.stderr or ""))
                else
                    next_step()
                end
            end)
        end)
        if ok then current.process = process else fail(tostring(process)) end
    end

    run({ "pdflatex", "-no-shell-escape", "-interaction=nonstopmode", "-halt-on-error", "formula.tex" }, function()
        run({
            "magick", "-density", "192", "formula.pdf[0]", "-trim", "+repage",
            "-bordercolor", "none", "-border", "4", "-background", "#" .. bg,
            "-alpha", "remove", "-alpha", "off", "-resize", "1600x1000>", "formula.png",
        }, function()
            local ok, err = vim.uv.fs_rename(dir .. "/formula.png", output)
            if not ok then fail(tostring(err)); return end
            trace("conversion complete", { key = key })
            local done = current.callback
            cleanup()
            done(output)
        end)
    end)
end

local function display(path, token)
    if token ~= generation then return end
    local term = require("image/utils/term").get_size()
    if not term then trace("no terminal dimensions"); return end
    local ok, image = pcall(require("image").from_file, path, {
        id = "math-popup",
        namespace = "math-popup",
        with_virtual_padding = false,
    })
    if not ok then
        vim.notify("Math popup: " .. tostring(image), vim.log.levels.WARN)
        return
    end
    if not image then return end
    local max_width = math.max(1, math.min(80, vim.o.columns - 4,
        math.ceil(image.image_width / term.cell_width)))
    local max_height = math.max(1, math.min(20, math.floor((vim.o.lines - vim.o.cmdheight - 4) / 2),
        math.ceil(image.image_height / term.cell_height)))
    local width, height = require("image/utils/math").adjust_to_aspect_ratio(
        term, image.image_width, image.image_height, max_width, max_height
    )
    width = math.max(1, math.min(max_width, width))
    height = math.max(1, math.min(max_height, height))
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].filetype = "math_popup"
    local win = vim.api.nvim_open_win(buf, false, {
        relative = "cursor",
        row = 1,
        col = 0,
        width = width,
        height = height,
        style = "minimal",
        border = "rounded",
        focusable = false,
        zindex = 60,
        noautocmd = true,
    })
    image.ignore_global_max_size = true
    image.window = win
    image.buffer = buf
    popup = { win = win, image = image }
    trace("open", { win = win, width = width, height = height, token = token })
    -- As with image.nvim's document popup, wait for the float's screen position.
    vim.defer_fn(function()
        if token ~= generation or not vim.api.nvim_win_is_valid(win) then return end
        trace("render request", { win = win, token = token })
        local ok, err = pcall(image.render, image, { x = 0, y = 0, width = width, height = height })
        if not ok then
            close()
            vim.notify("Math popup: " .. tostring(err), vim.log.levels.WARN)
        end
    end, 20)
end

local function invalidate(reason)
    if debounce_timer then
        vim.fn.timer_stop(debounce_timer)
        debounce_timer = nil
    end
    trace("invalidate", { reason = type(reason) == "table" and reason.event or reason, token = generation })
    generation = generation + 1
    close()
end

local function schedule(args)
    -- Layout changes in the preview itself must not close/reopen the preview.
    if args and args.event == "WinScrolled" and tonumber(args.match) ~= vim.api.nvim_get_current_win() then
        trace("ignore unrelated scroll", { win = args.match })
        return
    end
    invalidate(args or "schedule")
    local token = generation
    local buf, win = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
    if not filetypes[vim.bo[buf].filetype] or vim.fn.mode() ~= "n" then
        cancel_job()
        return
    end
    local cursor = vim.api.nvim_win_get_cursor(win)
    local tick = vim.api.nvim_buf_get_changedtick(buf)
    -- Cancel the previous timer rather than queueing one callback per cursor move.
    debounce_timer = vim.fn.timer_start(250, function()
        debounce_timer = nil
        if token ~= generation or vim.fn.mode() ~= "n" then return end
        if not vim.api.nvim_buf_is_valid(buf) or vim.api.nvim_get_current_buf() ~= buf
            or vim.api.nvim_get_current_win() ~= win then return end
        local text = M.find_math(buf, cursor[1] - 1, cursor[2])
        trace("detection", { buf = buf, cursor = cursor, found = text ~= nil, token = token })
        if not text then cancel_job(); return end
        compile(text, function(path)
            if token ~= generation or not vim.api.nvim_buf_is_valid(buf)
                or vim.api.nvim_get_current_win() ~= win or vim.api.nvim_get_current_buf() ~= buf
                or vim.api.nvim_buf_get_changedtick(buf) ~= tick or vim.fn.mode() ~= "n"
                or not vim.deep_equal(vim.api.nvim_win_get_cursor(win), cursor) then
                trace("discard stale result", { expected = token, actual = generation })
                return
            end
            display(path, token)
        end)
    end)
end

function M.setup()
    invalidate()
    cancel_job()
    local group = vim.api.nvim_create_augroup("sixel_math_popup", { clear = true })
    vim.api.nvim_create_autocmd({
        "CursorMoved", "BufEnter", "InsertLeave", "TextChanged", "WinScrolled", "VimResized", "ColorScheme",
    }, {
        group = group,
        callback = schedule,
    })
    vim.api.nvim_create_autocmd({ "InsertEnter", "BufLeave", "WinLeave" }, {
        group = group,
        callback = function(args)
            invalidate(args)
            cancel_job()
        end,
    })
    vim.api.nvim_create_autocmd("WinClosed", {
        group = group,
        callback = function(args)
            if popup and popup.win == tonumber(args.match) then invalidate() end
        end,
    })
    vim.api.nvim_create_autocmd("VimLeavePre", {
        group = group,
        callback = function()
            invalidate()
            cancel_job()
        end,
    })
end

return M
