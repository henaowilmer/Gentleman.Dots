local function is_sql_buffer()
  local ft = vim.bo.filetype
  return ft == "sql" or ft == "mysql" or ft == "plsql"
end

local function line_is_blank(line)
  return line:match("^%s*$") ~= nil
end

local function current_statement_range(bufnr)
  local total = vim.api.nvim_buf_line_count(bufnr)
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  if row < 1 or row > total then
    return nil
  end

  if line_is_blank(lines[row] or "") then
    return nil
  end

  local start_row = row
  for i = row - 1, 1, -1 do
    if line_is_blank(lines[i] or "") then
      break
    end
    start_row = i
  end

  local end_row = row
  for i = row, total do
    if i ~= row and line_is_blank(lines[i] or "") then
      break
    end
    end_row = i
  end

  for i = row - 1, start_row, -1 do
    if (lines[i] or ""):find(";") then
      start_row = i + 1
      break
    end
  end

  for i = row, end_row do
    if (lines[i] or ""):find(";") then
      end_row = i
      break
    end
  end

  while start_row <= end_row and line_is_blank(lines[start_row] or "") do
    start_row = start_row + 1
  end

  while end_row >= start_row and line_is_blank(lines[end_row] or "") do
    end_row = end_row - 1
  end

  if start_row > end_row then
    return nil
  end

  return start_row, end_row
end

local function run_statement_at_cursor()
  if not is_sql_buffer() then
    vim.notify("This buffer is not SQL", vim.log.levels.WARN)
    return
  end

  local start_row, end_row = current_statement_range(0)
  if not start_row or not end_row then
    vim.notify("No SQL statement at cursor", vim.log.levels.WARN)
    return
  end

  vim.cmd(string.format("%d,%dDB", start_row, end_row))
end


return {
  {
    "tpope/vim-dadbod",
    ft = { "sql", "mysql", "plsql" },
    cmd = {
      "DB",
      "DBUI",
      "DBUIToggle",
      "DBUIAddConnection",
      "DBUIFindBuffer",
      "DBUIRenameBuffer",
      "DBUILastQueryInfo",
    },
    keys = {
      { "<leader>D", desc = "+database" },
      {
        "<leader>DD",
        function()
          vim.api.nvim_feedkeys(":DB ", "n", false)
        end,
        desc = "DB Prompt",
      },
      { "<leader>Du", "<cmd>DBUIToggle<cr>", desc = "DBUI Toggle" },
      { "<leader>Da", "<cmd>DBUIAddConnection<cr>", desc = "DBUI Add Connection" },
      { "<leader>Df", "<cmd>DBUIFindBuffer<cr>", desc = "DBUI Find Buffer" },
      { "<leader>Dr", "<cmd>DBUIRenameBuffer<cr>", desc = "DBUI Rename Buffer" },
      { "<leader>Dw", "<Plug>(DBUI_SaveQuery)", remap = true, desc = "Save as Saved Query" },
      { "<leader>Di", "<cmd>DBUILastQueryInfo<cr>", desc = "DBUI Last Query Info" },
      {
        "<leader>Ds",
        function()
          if is_sql_buffer() then
            vim.cmd("%DB")
            return
          end
          vim.notify("This buffer is not SQL", vim.log.levels.WARN)
        end,
        desc = "Run Script (Buffer)",
      },
      {
        "<leader>Dl",
        run_statement_at_cursor,
        desc = "Run Statement at Cursor",
      },
      {
        "<leader><CR>",
        run_statement_at_cursor,
        desc = "Run Statement at Cursor",
      },
      {
        "<leader>Dx",
        mode = "v",
        function()
          vim.cmd("'<,'>DB")
        end,
        desc = "Run Selection",
      },
    },
  },
  {
    "kristijanhusak/vim-dadbod-ui",
    dependencies = { "tpope/vim-dadbod" },
    cmd = { "DBUI", "DBUIToggle", "DBUIAddConnection", "DBUIFindBuffer", "DBUIRenameBuffer", "DBUILastQueryInfo" },
    init = function()
      local uv = vim.uv or vim.loop

      local preferred_root = "/work/dbs"
      local fallback_root = (vim.env.HOME or "") .. "/work/dbs"
      local dbs_root = uv.fs_stat(preferred_root) and preferred_root or fallback_root
      local scripts_root = dbs_root .. "/scripts"

      vim.fn.mkdir(scripts_root, "p")

      local connections_file = dbs_root .. "/connections.lua"
      if not uv.fs_stat(connections_file) then
        local template = {
          "return {",
          '  -- main = "postgres://user:pass@127.0.0.1:5432/app",',
          '  -- analytics = "mysql://user:pass@127.0.0.1:3306/analytics",',
          '  -- notes = "sqlite:/data/data/com.termux/files/home/storage/shared/notes.db",',
          "}",
          "",
        }
        vim.fn.writefile(template, connections_file)
      end

      local ok, dbs = pcall(dofile, connections_file)
      if ok and type(dbs) == "table" then
        vim.g.dbs = dbs
        for name, _ in pairs(dbs) do
          local safe_name = tostring(name):gsub("[^%w_-]", "_")
          vim.fn.mkdir(scripts_root .. "/" .. safe_name, "p")
        end
      end

      vim.g.db_ui_use_nerd_fonts = 1
      vim.g.db_ui_save_location = dbs_root .. "/.dbui"
      vim.g.db_ui_execute_on_save = 0
      vim.g.db_ui_disable_mappings_sql = 1

      local group = vim.api.nvim_create_augroup("DadbodUiAutoCloseDrawer", { clear = true })
      vim.api.nvim_create_autocmd("FileType", {
        group = group,
        pattern = { "sql", "mysql", "plsql" },
        callback = function(args)
          if vim.b[args.buf].dbui_db_key_name then
            vim.schedule(function()
              pcall(vim.cmd, "DBUIClose")
            end)
          end
        end,
      })
    end,
  },
  {
    "kristijanhusak/vim-dadbod-completion",
    dependencies = { "tpope/vim-dadbod" },
    ft = { "sql", "mysql", "plsql" },
    config = function()
      local group = vim.api.nvim_create_augroup("DadbodCompletion", { clear = true })

      vim.api.nvim_create_autocmd({ "FileType", "BufEnter" }, {
        group = group,
        pattern = { "*.sql", "*.mysql", "*.plsql", "sql", "mysql", "plsql" },
        callback = function(args)
          vim.bo[args.buf].omnifunc = "vim_dadbod_completion#omni"
        end,
      })

      if vim.bo.filetype == "sql" or vim.bo.filetype == "mysql" or vim.bo.filetype == "plsql" then
        vim.bo.omnifunc = "vim_dadbod_completion#omni"
      end
    end,
  },
}
