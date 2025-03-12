table.unpack = table.unpack or unpack

local M = {}

local global_config = {
    storage_path = vim.fn.expand(vim.env.HOME .. '/.scratchpads'),
    keybinds = {
        quit = 'q',
        new_scratchpad = 'n',
    },
    window = {
        border = 'single',
    },
}
local scratchpad_files = {}

local function fs_ls(path)
    local tbl = {}
    local tbl_size = 0
    local dir = assert(vim.uv.fs_scandir(path))
    local entry = nil
    repeat
        entry = vim.uv.fs_scandir_next(dir)
        tbl_size = tbl_size + 1
        tbl[tbl_size] = entry
    until (not entry)
    return tbl
end

function table.map(tbl, f)
    local t = {}
    for k, v in pairs(tbl) do
        t[k] = f(v)
    end
    return t
end

-- based on: https://github.com/nvim-neo-tree/neo-tree.nvim/blob/e968cda658089b56ee1eaa1772a2a0e50113b902/lua/neo-tree/utils.lua#L157-L165
local function find_buffer_by_name(name)
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        local buf_name = vim.api.nvim_buf_get_name(buf)
        local filename = vim.fs.basename(buf_name)
        if filename == name then
            return buf
        end
    end
    return -1
end

local function create_buffer(name, filetype)
    -- if the user previously closed the window with :q
    -- that does not delete the buffer, so we reuse it
    local buf = find_buffer_by_name(name)
    if buf ~= -1 then
        return buf
    else
        buf = vim.api.nvim_create_buf(true, true)
    end
    local formatted_files = table.map(scratchpad_files, function(file)
        return '. ' .. file
    end)
    vim.api.nvim_buf_set_lines(buf, 0, -1, true, formatted_files)
    vim.api.nvim_buf_set_name(buf, name)
    vim.api.nvim_set_option_value('filetype', filetype, { buf = buf })
    vim.api.nvim_set_option_value('readonly', true, { buf = buf })
    vim.api.nvim_set_option_value('modifiable', false, { buf = buf })
    return buf
end

local function get_win_size_pos()
    local width = math.floor(vim.o.columns / 2)
    local height = math.floor(vim.o.lines / 2)
    local col = math.floor(vim.o.columns / 2) - math.floor(width / 2)
    local row = math.floor(vim.o.lines / 2) - math.floor(height / 2)
    return { width = width, height = height, col = col, row = row }
end

local function open_window(buf)
    local win_size_pos = get_win_size_pos()
    local footer = global_config.keybinds.new_scratchpad .. ' -- new scratchpad, ' .. global_config.keybinds.quit .. ' -- quit'
    local window_config = {
        title = 'scratchpads',
        footer = footer,
        relative = 'editor',
        style = 'minimal',
        border = global_config.window.border,
        width = win_size_pos.width,
        height = win_size_pos.height,
        col = win_size_pos.col,
        row = win_size_pos.row
    }
    local win = vim.api.nvim_open_win(buf, true, window_config)
    return win
end

local function set_win_buf_keybinds(win, buf)
    local quit_callback = function()
        vim.api.nvim_win_close(win, false)
        vim.api.nvim_buf_delete(buf, {})
    end
    local edit_callback = function()
        local row, _ = table.unpack(vim.api.nvim_win_get_cursor(win))
        local file_path = global_config.storage_path .. '/' .. scratchpad_files[row]
        quit_callback()
        vim.cmd.edit(file_path)
    end
    local new_scratchpad_callback = function()
        local name = vim.fn.strftime('%Y-%m-%d')
        local file_path = global_config.storage_path .. '/' .. name .. '.md'
        quit_callback()
        vim.cmd.edit(file_path)
    end
    vim.api.nvim_buf_set_keymap(buf, 'n', global_config.keybinds.quit, '', {
        desc = 'Close the scratchpads listing window and delete its attached buffer',
        callback = quit_callback
    })
    vim.api.nvim_buf_set_keymap(buf, 'n', '<Enter>', '', {
        desc = 'Edit the current file under the cursor',
        callback = edit_callback
    })
    vim.api.nvim_buf_set_keymap(buf, 'n', global_config.keybinds.new_scratchpad, '', {
        desc = 'Edit a new file for the current date',
        callback = new_scratchpad_callback
    })
end

local function handle_win_resize(win)
    local callback = function()
        local win_size_pos = get_win_size_pos()
        vim.api.nvim_win_set_width(win, win_size_pos.width)
        vim.api.nvim_win_set_height(win, win_size_pos.height)
        vim.api.nvim_win_set_config(win, {
            relative = 'editor',
            col = win_size_pos.col,
            row = win_size_pos.row
        })
    end
    vim.api.nvim_create_autocmd('VimResized', { callback = callback })
end

local function open_list()
    scratchpad_files = fs_ls(global_config.storage_path)
    local buf = create_buffer("scratchpadlist", "txt")
    local win = open_window(buf)
    set_win_buf_keybinds(win, buf)
    handle_win_resize(win)
end

function M.setup(opts)
    global_config.storage_path = opts.storage_path or global_config.storage_path
    global_config.keybinds = vim.tbl_deep_extend("force", global_config.keybinds, opts.keybinds or {})
    global_config.window = vim.tbl_deep_extend("force", global_config.window, opts.window or {})
    vim.api.nvim_create_user_command('ScratchpadList', open_list,  {})
end

return M
