local M = {}

local function create_buffer()
    local buf = vim.api.nvim_create_buf(true, true)
    local local_date_time = vim.fn.strftime('%Y-%m-%d')
    vim.api.nvim_buf_set_name(buf, local_date_time .. '.md')
    vim.api.nvim_set_option_value('filetype', 'markdown', { buf = buf })
    return buf
end

local function get_win_size_pos()
    local width = math.floor(vim.o.columns / 2)
    local height = math.floor(vim.o.lines / 2)
    local col = math.floor(vim.o.columns / 2) - math.floor(width / 2)
    local row = math.floor(vim.o.lines / 2) - math.floor(height / 2)
    return { width = width, height = height, col = col, row = row }
end

local function create_window(buf)
    local win_size_pos = get_win_size_pos()
    local window_config = {
        title = 'scratchpads',
        relative = 'editor',
        style = 'minimal',
        border = 'single',
        width = win_size_pos.width,
        height = win_size_pos.height,
        col = win_size_pos.col,
        row = win_size_pos.row
    }
    local win = vim.api.nvim_open_win(buf, true, window_config)
    return win
end

local function set_win_buf_keybinds(win, buf, keybinds)
    vim.api.nvim_buf_set_keymap(buf, 'n', keybinds.quit, '', {
        desc = "Close the scratchpads listing window",
        callback = function()
            vim.api.nvim_win_close(win, false)
            vim.api.nvim_buf_delete(buf, {})
        end
    })
end

local function handle_win_resize(win)
    vim.api.nvim_create_autocmd('VimResized', {
        callback = function()
            local win_size_pos = get_win_size_pos()
            vim.api.nvim_win_set_width(win, win_size_pos.width)
            vim.api.nvim_win_set_height(win, win_size_pos.height)
            vim.api.nvim_win_set_config(win, {
                relative = 'editor',
                col = win_size_pos.col,
                row = win_size_pos.row
            })
        end
    })
end

local function open_list()
    local buf = create_buffer()
    local win = create_window(buf)
    set_win_buf_keybinds(win, buf, { quit = 'q' })
    handle_win_resize(win)
end

function M.setup()
    vim.api.nvim_create_user_command('ScratchpadList', open_list, {})
end

return M

