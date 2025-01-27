--TODO:
--  * Add icon colors
--  * Add sort options
--  * Add Options for configuring the outline
local api = vim.api
local cmd = vim.api.nvim_create_autocmd
local ui = api.nvim_list_uis()[1]
local di = require'nvim-web-devicons'

require 'split'
local M = {
    opt = {
        main_win_width = 100,
        main_win_height = 30,
        main_win_style = "minimal",
        main_win_relavent = "win",
        main_win_border = true,
        preview_win_style = "minimal",
        preview_win_relavent = "win",
        preview_win_border = true,
        input_win_border = true,
        custom_keys = {}
    }
}

function M.setup(opt)
    if opt then
        M.opt = vim.tbl_deep_extend('force', M.opt, opt)
    end

    M.main_win = nil
    M.main_buf = nil
    M.preview_win = nil
    M.preview_buf = nil

    M.main_col = ui.width / 2 - M.opt.main_win_width / 2
    M.main_row = ui.height / 2 - M.opt.main_win_height / 2

    M.preview_win_width = ui.width / 2
    M.preview_win_height = ui.height / 2

    M.preview_col = M.opt.main_win_width / 2 - M.preview_win_width / 2
    M.preview_row = M.opt.main_win_height / 2 - M.preview_win_height / 2
end

function M.open()
    local buffers = api.nvim_list_bufs()
    local buffercount = 0
    for _, buffer in ipairs(buffers) do
        --check if buffers are avtive
        if api.nvim_buf_is_loaded(buffer) then
            local buffer_name = api.nvim_buf_get_name(buffer)

            if #buffer_name > 0 then
                buffercount = buffercount + 1
            end
        end
    end

    if buffercount == 0 then
        return
    end

    M.back_buf = api.nvim_get_current_buf()
    M.back_win = api.nvim_get_current_win()

    if not M.main_buf and not M.main_win then
        M.main_buf = api.nvim_create_buf(false, true)
        local win_id = api.nvim_open_win(M.main_buf, 1, {
            relative = M.opt.main_win_relavent,
            style = M.opt.main_win_style,
            row = math.floor(((vim.fn.winheight(M.back_win) - 5) / 2) - 1),
            col = math.floor((vim.fn.winwidth(M.back_win) - M.opt.main_win_width) / 2),
            width = M.opt.main_win_width,
            height = 5,
            border = M.opt.main_win_border,
        })
        M.main_win = win_id
        M.build_win()
        M.setKeys(M.back_win, M.main_buf)
        M.add_custom_keys()

        api.nvim_win_set_option(M.main_win, 'cursorline', true)
    else
        xpcall(function()
            api.nvim_win_close(M.main_win, false)
            api.nvim_buf_delete(M.main_buf, {})
            M.main_win = nil
            M.main_buf = nil
        end, function()
            M.main_win = nil
            M.main_buf = nil
            M.open()
        end)
    end
end

function M.add_custom_keys()
    for k, v in pairs(M.opt.custom_keys) do
        api.nvim_buf_set_keymap(M.main_buf, 'n', v.key,
            string.format([[:<C-U>lua require'outline'.set_saved_buffer(%s,%s)<CR>]], M.back_win, tonumber(v.buffer)),
            { nowait = true, noremap = true, silent = true })
    end
end

function M.set_saved_buffer(win, buf)
    api.nvim_win_set_buf(win, tonumber(buf))
    M.close()
end

function M.openPreview(buf)
    M.preview_buf = api.nvim_create_buf(false, true)
    -- rount float to int
    M.preview_win_width = math.floor(M.preview_win_width)
    M.preview_win_height = math.floor(M.preview_win_height)
    local cursor_pos = api.nvim_win_get_cursor(M.main_win)
    cursor_pos[1] = cursor_pos[1] - 1
    local lines = api.nvim_buf_get_lines(buf, cursor_pos[1], -1, false)[1]
    local buffer = tonumber(lines:split(" ")[1])
    M.preview_buf = buffer
    -- M.preview_buf = api.nvim_create_buf(false, true)

    local width = M.preview_win_width
    local height = M.preview_win_height
    local win_id = api.nvim_open_win(M.preview_buf, 0, {
        relative = M.opt.preview_win_relavent,
        style = M.opt.preview_win_style,
        row = math.floor((vim.fn.winheight(M.back_win) / 2) - 1),
        col = math.floor((vim.fn.winwidth(M.back_win) - M.opt.main_win_width) / 2),
        width = width,
        height = height,
        border = M.opt.preview_win_border,
    })

    M.preview_win = win_id
    api.nvim_buf_set_option(M.preview_buf, 'modifiable', false)
    api.nvim_win_set_option(M.preview_win, 'cursorline', false)
    M.setPreviewKeys(M.preview_buf)
end

function M.setPreviewKeys(buf)
    api.nvim_buf_set_keymap(0, 'n', 'q', ':lua require"outline".close_preview()<CR>',
        { nowait = true, noremap = true, silent = true })
end

function M.close_preview()
    api.nvim_win_close(M.preview_win, false)
    api.nvim_buf_delete(M.preview_buf, {})
    M.preview_win = nil
    M.preview_buf = nil
    api.nvim_set_current_win(M.main_win)
end

function M.close()
    if M.main_win then
        api.nvim_win_close(M.main_win, false)
        api.nvim_buf_delete(M.main_buf, {})
        M.main_win = nil
        M.main_buf = nil
        if M.preview_buf ~= nil then
            M.close_preview()
        end
    end
end

function M.setKeys(win, buf)
    -- Basic window buffer configuration
    api.nvim_buf_set_keymap(buf, 'n', '<CR>',
        string.format([[:<C-U>lua require'outline'.set_buffer(%s,%s, 'window', vim.v.count)<CR>]], win, buf),
        { nowait = true, noremap = true, silent = true })
    api.nvim_buf_set_keymap(buf, 'n', 's',
        string.format([[:<C-U>lua require'outline'.set_buffer(%s,%s, 'hsplit', vim.v.count)<CR>]], win, buf),
        { nowait = true, noremap = true, silent = true })
    api.nvim_buf_set_keymap(buf, 'n', 'v',
        string.format([[:<C-U>lua require'outline'.set_buffer(%s,%s, 'vsplit', vim.v.count)<CR>]], win, buf),
        { nowait = true, noremap = true, silent = true })
    api.nvim_buf_set_keymap(buf, 'n', 'P',
        string.format([[:<C-U>lua require'outline'.openPreview(%s)<CR>]], buf),
        { nowait = true, noremap = true, silent = true })
    api.nvim_buf_set_keymap(buf, 'n', 'D',
        string.format([[:<C-U>lua require'outline'.close_buffer(%s)<CR>]], buf),
        { nowait = true, noremap = true, silent = true })
    api.nvim_buf_set_keymap(buf, 'n', 'B',
        string.format([[:<C-U>lua require'outline'.open_input_window(%s)<CR>]], buf),
        { nowait = true, noremap = true, silent = true })
    -- Navigation keymaps
    api.nvim_buf_set_keymap(buf, 'n', 'q', ':lua require"outline".close()<CR>',
        { nowait = true, noremap = true, silent = true })
    api.nvim_buf_set_keymap(buf, 'n', '<Esc>', ':lua require"outline".close()<CR>',
        { nowait = true, noremap = true, silent = true })
    api.nvim_buf_set_keymap(buf, 'n', '<Tab>', 'j',
        { nowait = true, noremap = true, silent = true })
    api.nvim_buf_set_keymap(buf, 'n', '<S-Tab>', 'k',
        { nowait = true, noremap = true, silent = true })
    -- vim.cmd(string.format("au CursorMoved <buffer=%s> if line(\".\") == 1 | call feedkeys('j', 'n') | endif", buf))
end

function M.build_win()
    api.nvim_buf_set_option(M.main_buf, "modifiable", true)
    M.list_buffers()
    api.nvim_buf_set_option(M.main_buf, "modifiable", false)
end

function M.list_buffers()
    --get open buffe
    local buffers = api.nvim_list_bufs()
    local buffer_names = {}
    table.sort(buffers)
    local current_line = 1
    local line = 0
    for _, buffer in ipairs(buffers) do
        --check if buffers are avtive
        if api.nvim_buf_is_loaded(buffer) then
            local buffer_name = api.nvim_buf_get_name(buffer)
            -- check if buffer has changed
            if buffer_name == "" or nil then goto continue end

            buffer_name = vim.fn.fnamemodify(buffer_name, ':.')
            local buffer_id = api.nvim_buf_get_number(buffer)
            local ext = vim.fn.fnamemodify(buffer_name, ':e')
            local buffer_icon, highlight = di.get_icon(buffer_name, ext)

            if not buffer_icon then
                buffer_icon = '  '
            end

            local max_width = M.opt.main_win_width - 11
            local buffer_name_width = #buffer_name
            if #buffer_name > max_width then
                buffer_name = "..." .. string.sub(buffer_name, 1 - max_width)
            end
            for b, bind in pairs(M.opt.custom_keys) do
                if bind.buffer == buffer_id then
                    buffer_name = string.format("%s %s", bind.key .. " ", buffer_name)
                end
            end

            local output = string.format("%-3s: %s %s", buffer_id, buffer_icon, buffer_name)
            api.nvim_buf_set_lines(M.main_buf, line, line + 1, false, { output })
            api.nvim_buf_add_highlight(M.main_buf, 0, 'Number', line, 0, 3)
            api.nvim_buf_add_highlight(M.main_buf, 0, highlight, line, 5, 9)
            api.nvim_buf_add_highlight(M.main_buf, 0, 'Directory', line, 9, -1)

            line = line + 1

            if M.back_buf == buffer then
                current_line = line
            end

            ::continue::
        end
    end

    vim.api.nvim_win_set_cursor(M.main_win, { current_line, 0 })
end

function M.set_buffer(win, buf, opt)
    local cursor_pos = api.nvim_win_get_cursor(M.main_win)
    cursor_pos[1] = cursor_pos[1] - 1
    local lines = api.nvim_buf_get_lines(buf, cursor_pos[1], -1, false)[1]
    local buffer = tonumber(lines:split(" ")[1])
    --check if window is split
    if opt == 'window' then
        api.nvim_win_set_buf(win, tonumber(buffer))
    elseif opt == 'hsplit' then
        api.nvim_command('vsplit')
        api.nvim_win_set_buf(api.nvim_get_current_win(), buffer)
    elseif opt == 'vsplit' then
        api.nvim_command('split')
        api.nvim_win_set_buf(api.nvim_get_current_win(), buffer)
    end
    M.close()
end

function M.close_buffer(buf)
    local cursor_pos = api.nvim_win_get_cursor(M.main_win)
    local lines = api.nvim_buf_get_lines(buf, cursor_pos[1] - 1, -1, false)[1]
    local buffer = tonumber(lines:split(' ')[1])
    -- close buffer
    vim.cmd(string.format('bd %s', buffer))
    -- reset the buffer loader
    M.close()
    M.open()
end

function M.open_input_window()
    M.input_buf = api.nvim_create_buf(false, true)
    local ok, result = pcall(vim.api.nvim_buf_get_var, M.input_buf, 'lsp_enabled')
    local win_id = api.nvim_open_win(M.input_buf, 1, {
        relative = 'win',
        style = 'minimal',
        row = math.floor(((vim.fn.winheight(M.back_win) - 1) / 2) - 1),
        col = math.floor(((vim.fn.winwidth(M.back_win) - 20) - M.opt.main_win_width) / 2),
        width = 20,
        height = 1,
        border = M.opt.input_win_border,
    })
    M.input_win = win_id
    M.set_input_keys(M.input_buf)
    -- turn off lsp for this buffer
    api.nvim_buf_set_option(M.input_buf, 'omnifunc', 'v:lua.vim.lsp.omnifunc')
    api.nvim_win_set_option(M.input_win, 'cursorline', true)
    api.nvim_set_current_win(M.input_win)
    api.nvim_win_set_cursor(M.input_win, { 1, 0 })
    api.nvim_command('startinsert')
    api.nvim_buf_set_option(M.input_buf, 'modifiable', true)
end

function M.set_input_keys(buf)

    api.nvim_buf_set_keymap(buf, 'i', '<CR>', '<Esc>:lua require"outline".bind_key_to_buffer()<CR>',
        { nowait = true, noremap = true, silent = true })
    api.nvim_buf_set_keymap(buf, 'i', '<C-c>', '<Esc>:lua require"outline".close_input_window()<CR>',
        { nowait = true, noremap = true, silent = true })
    api.nvim_buf_set_keymap(buf, 'i', 'q', '<Esc>:lua require"outline".close_input_window()<CR>',
        { nowait = true, noremap = true, silent = true })
    api.nvim_buf_set_keymap(buf, 'i', '<Esc>', '<Esc>:lua require"outline".close_input_window()<CR>',
        { nowait = true, noremap = true, silent = true })
end

function M.close_input_window()
    api.nvim_win_close(M.input_win, true)
    M.input_buf = nil
    M.input_win = nil
end

function M.bind_key_to_buffer()
    --get current line from window
    local main_cursor_pos = api.nvim_win_get_cursor(M.main_win)
    main_cursor_pos[1] = main_cursor_pos[1] - 1
    local lines = api.nvim_buf_get_lines(M.main_buf, main_cursor_pos[1], -1, false)[1]
    local buffer = tonumber(lines:split(" ")[1])
    local cursor_pos = api.nvim_win_get_cursor(M.input_win)
    local key = api.nvim_buf_get_lines(M.input_buf, cursor_pos[1] - 1, -1, false)[1]
    api.nvim_buf_set_keymap(M.main_buf, 'n', key,
        string.format([[:<C-U>lua require'outline'.set_buffer(%s,%s, 'window', vim.v.count)<CR>]], M.back_win, M.main_buf),
        { nowait = true, noremap = true, silent = true })
    -- add to custom keybindings
    --  check if buffer is already in custom keybindings
    --  if not add its
    for _, v in pairs(M.custom_keys) do
        if v.key == key then
            vim.notify('Key already exists')
            api.nvim_command('startinsert')
            return
        else if v.buffer == buffer then
                v.key = key
                vim.notify('Buffer binding changed.')
                M.close_input_window()
                M.close()
                M.open()

                return
            end
        end
    end
    M.custom_keys[#M.custom_keys + 1] = {
        key = key,
        buffer = buffer,
        window = M.back_win,
        opt = 'window'
    }
    M.close_input_window()
    vim.notify('Buffer binding added.')
    M.close()
    M.open()
end

return M
