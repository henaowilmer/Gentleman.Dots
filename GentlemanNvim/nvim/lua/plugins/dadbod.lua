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

local function find_git_root(start_dir)
  local uv = vim.uv or vim.loop
  local dir = start_dir

  if not dir or dir == "" then
    return nil
  end

  while dir and dir ~= "" do
    if uv.fs_stat(dir .. "/.git") then
      return dir
    end

    local parent = vim.fn.fnamemodify(dir, ":h")
    if not parent or parent == dir then
      break
    end
    dir = parent
  end

  return nil
end

local function find_project_root()
  local uv = vim.uv or vim.loop
  local buf_name = vim.api.nvim_buf_get_name(0)

  if buf_name and buf_name ~= "" then
    local buf_dir = vim.fn.fnamemodify(buf_name, ":p:h")
    local from_buf = find_git_root(buf_dir)
    if from_buf then
      return from_buf
    end
  end

  local cwd = uv.cwd() or vim.fn.getcwd()
  local from_cwd = find_git_root(cwd)
  if from_cwd then
    return from_cwd
  end

  return cwd
end

local function parse_env_file(env_file, env_vars)
  local uv = vim.uv or vim.loop
  if not env_file or env_file == "" or not uv.fs_stat(env_file) then
    return
  end

  local lines = vim.fn.readfile(env_file)

  local function normalize_value(value)
    local trimmed = vim.trim(value or "")
    if trimmed:match('^".*"$') then
      return trimmed:sub(2, -2)
    end
    if trimmed:match("^'.*'$") then
      return trimmed:sub(2, -2)
    end

    local without_comment = trimmed:gsub("%s+#.*$", "")
    return vim.trim(without_comment)
  end

  for _, line in ipairs(lines) do
    local key, value = line:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
    if not key then
      key, value = line:match("^%s*export%s+([%w_]+)%s*=%s*(.-)%s*$")
    end
    if key and value then
      env_vars[key] = normalize_value(value)
    end
  end
end

local function load_env_connections(project_root)
  local uv = vim.uv or vim.loop
  if not project_root or project_root == "" then
    return nil
  end

  local dbs = {}
  local tunnels = {}
  local env_vars = {}
  local env_files = {
    project_root .. "/.env",
    project_root .. "/.env.local",
  }

  local loaded_any_env = false
  for _, env_file in ipairs(env_files) do
    if uv.fs_stat(env_file) then
      loaded_any_env = true
      parse_env_file(env_file, env_vars)
    end
  end

  if not loaded_any_env then
    return nil
  end

  local function resolve_env_refs(value)
    if not value then
      return ""
    end
    return (
      value
        :gsub("%${([%w_]+)}", function(name)
          return env_vars[name] or vim.env[name] or ""
        end)
        :gsub("%$([%w_]+)", function(name)
          return env_vars[name] or vim.env[name] or ""
        end)
    )
  end

  for key, value in pairs(env_vars) do
    local connection_name = key:match("^DB_UI_([%w_]+)$")
    if connection_name then
      local resolved = resolve_env_refs(value)
      if resolved:find("://", 1, true) then
        dbs[connection_name:lower()] = resolved
      end
    end
  end

  local dbui_url = env_vars.DBUI_URL and resolve_env_refs(env_vars.DBUI_URL) or nil
  if dbui_url and dbui_url ~= "" then
    local dbui_name = env_vars.DBUI_NAME or "default"
    dbs[dbui_name:lower()] = dbui_url
  end

  local database_url = env_vars.DATABASE_URL and resolve_env_refs(env_vars.DATABASE_URL) or nil
  if database_url and database_url ~= "" then
    dbs.default = database_url
  end

  if not next(dbs) and env_vars.DB_CONNECTION then
    local scheme = resolve_env_refs(env_vars.DB_CONNECTION):lower()
    local host = resolve_env_refs(env_vars.DB_HOST or "")
    local port = resolve_env_refs(env_vars.DB_PORT or "")
    local database = resolve_env_refs(env_vars.DB_DATABASE or "")
    local username = resolve_env_refs(env_vars.DB_USERNAME or "")
    local password = resolve_env_refs(env_vars.DB_PASSWORD or "")

    if scheme == "pgsql" then
      scheme = "postgres"
    end

    if scheme == "sqlite" then
      if database ~= "" then
        dbs.default = "sqlite:" .. database
      end
    elseif (scheme == "mysql" or scheme == "postgres") and host ~= "" and database ~= "" then
      local auth = ""
      if username ~= "" and password ~= "" then
        auth = username .. ":" .. password .. "@"
      elseif username ~= "" then
        auth = username .. "@"
      end

      local host_part = host
      if port ~= "" then
        host_part = host_part .. ":" .. port
      end

      dbs.default = string.format("%s://%s%s/%s", scheme, auth, host_part, database)
    end
  end

  local function is_truthy(value)
    local normalized = vim.trim((value or ""):lower())
    return normalized == "1" or normalized == "true" or normalized == "yes" or normalized == "on"
  end

  for name, _ in pairs(dbs) do
    local env_name = tostring(name):upper():gsub("[^%w]", "_")
    local base_key = "DB_UI_" .. env_name .. "_TUNNEL"
    local key_prefix = base_key .. "_"

    local tunnel_cmd = resolve_env_refs(env_vars[key_prefix .. "CMD"])
    local tunnel_host = resolve_env_refs(env_vars[key_prefix .. "HOST"])
    local ssh_host = resolve_env_refs(env_vars[key_prefix .. "SSH_HOST"])
    local remote_host = resolve_env_refs(env_vars[key_prefix .. "REMOTE_HOST"])
    local local_port = resolve_env_refs(env_vars[key_prefix .. "LOCAL_PORT"])
    local remote_port = resolve_env_refs(env_vars[key_prefix .. "REMOTE_PORT"])
    local has_tunnel_vars = tunnel_cmd ~= "" or tunnel_host ~= "" or ssh_host ~= ""
    local tunnel_enabled = is_truthy(resolve_env_refs(env_vars[base_key])) or has_tunnel_vars

    if tunnel_enabled then
      tunnels[name] = {
        cmd = tunnel_cmd,
        host = tunnel_host ~= "" and tunnel_host or ssh_host,
        user = resolve_env_refs(env_vars[key_prefix .. "USER"]),
        jump = resolve_env_refs(env_vars[key_prefix .. "JUMP"]),
        identity_file = resolve_env_refs(env_vars[key_prefix .. "IDENTITY_FILE"]),
        ssh_port = resolve_env_refs(env_vars[key_prefix .. "SSH_PORT"]),
        local_port = local_port,
        remote_host = remote_host,
        remote_port = remote_port,
      }
    end
  end

  if next(dbs) then
    return dbs, tunnels
  end

  return nil
end

local tunnel_state = {}

-- Returns true if something is accepting TCP connections on 127.0.0.1:port.
-- Uses libuv directly so it works in Termux where `nc`/`ss` may be missing.
local function is_port_listening(port, timeout_ms)
  local uv = vim.uv or vim.loop
  port = tonumber(port)
  if not port then
    return false
  end
  timeout_ms = timeout_ms or 800

  local client = uv.new_tcp()
  local done = false
  local reachable = false

  local function finish(success)
    if done then
      return
    end
    done = true
    reachable = success
    if client and not client:is_closing() then
      client:close()
    end
  end

  local ok = pcall(function()
    client:connect("127.0.0.1", port, function(err)
      finish(err == nil)
    end)
  end)

  if not ok then
    finish(false)
    return false
  end

  vim.wait(timeout_ms, function()
    return done
  end, 20)
  finish(false)

  return reachable
end

-- Kills a stale ssh tunnel still holding this connection's local forward.
-- Only structured (non custom-command) tunnels can be identified safely.
local function kill_stale_tunnel(spec)
  if spec.cmd and spec.cmd ~= "" then
    return
  end
  if spec.local_port == "" or spec.remote_host == "" or spec.remote_port == "" then
    return
  end

  local forward = string.format("%s:%s:%s", spec.local_port, spec.remote_host, spec.remote_port)
  local pattern = "ssh .*-L .*" .. forward:gsub("%.", "\\.")
  vim.fn.system({ "pkill", "-f", pattern })
end

local function build_tunnel_command(spec)
  if spec.cmd and spec.cmd ~= "" then
    return spec.cmd
  end

  if spec.host == "" or spec.local_port == "" or spec.remote_host == "" or spec.remote_port == "" then
    return nil
  end

  local target = spec.host
  if spec.user and spec.user ~= "" then
    target = spec.user .. "@" .. target
  end

  local cmd = {
    "ssh",
    "-fN",
    "-o", "ExitOnForwardFailure=yes",
    "-o", "ConnectTimeout=10",
    "-o", "ServerAliveInterval=30",
    "-o", "ServerAliveCountMax=3",
    "-o", "BatchMode=yes",
    "-o", "StrictHostKeyChecking=accept-new",
    "-L",
    string.format("%s:%s:%s", spec.local_port, spec.remote_host, spec.remote_port),
  }

  if spec.jump and spec.jump ~= "" then
    table.insert(cmd, "-J")
    table.insert(cmd, spec.jump)
  end

  if spec.identity_file and spec.identity_file ~= "" then
    table.insert(cmd, "-i")
    table.insert(cmd, spec.identity_file)
  end

  if spec.ssh_port and spec.ssh_port ~= "" then
    table.insert(cmd, "-p")
    table.insert(cmd, spec.ssh_port)
  end

  table.insert(cmd, target)
  return cmd
end

local function ensure_tunnels(project_root, tunnels)
  if type(tunnels) ~= "table" or not next(tunnels) then
    return
  end

  local project_key = project_root or "global"
  tunnel_state[project_key] = tunnel_state[project_key] or {}

  for name, spec in pairs(tunnels) do
    local local_port = spec.local_port

    -- Tunnel already up and listening (this or a previous session) -> reuse it.
    if local_port and local_port ~= "" and is_port_listening(local_port) then
      tunnel_state[project_key][name] = true
    else
      local cmd = build_tunnel_command(spec)
      if not cmd then
        vim.notify("Dadbod tunnel config incomplete for connection: " .. tostring(name), vim.log.levels.WARN)
      else
        local established = false
        local last_result = ""

        -- Two attempts: kill any stale ssh holding the port, re-open, then verify.
        for _ = 1, 2 do
          kill_stale_tunnel(spec)
          last_result = vim.fn.system(cmd)

          if local_port and local_port ~= "" then
            vim.wait(2000, function()
              return is_port_listening(local_port, 300)
            end, 100)
            established = is_port_listening(local_port, 300)
          else
            established = vim.v.shell_error == 0
          end

          if established then
            break
          end
        end

        tunnel_state[project_key][name] = established

        if not established then
          local details = vim.trim(last_result or "")
          if details == "" then
            details = "unknown error"
          end
          vim.notify("Dadbod tunnel failed for " .. tostring(name) .. ": " .. details, vim.log.levels.ERROR)
        end
      end
    end
  end
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
      { "<leader>d", desc = "+database" },
      {
        "<leader>dD",
        function()
          vim.api.nvim_feedkeys(":DB ", "n", false)
        end,
        desc = "DB Prompt",
      },
      { "<leader>du", "<cmd>DBUIToggle<cr>", desc = "DBUI Toggle" },
      { "<leader>da", "<cmd>DBUIAddConnection<cr>", desc = "DBUI Add Connection" },
      { "<leader>df", "<cmd>DBUIFindBuffer<cr>", desc = "DBUI Find Buffer" },
      { "<leader>dr", "<cmd>DBUIRenameBuffer<cr>", desc = "DBUI Rename Buffer" },
      { "<leader>dw", "<Plug>(DBUI_SaveQuery)", remap = true, desc = "Save as Saved Query" },
      { "<leader>di", "<cmd>DBUILastQueryInfo<cr>", desc = "DBUI Last Query Info" },
      {
        "<leader>ds",
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
        "<leader>dl",
        run_statement_at_cursor,
        desc = "Run Statement at Cursor",
      },
      {
        "<leader><CR>",
        run_statement_at_cursor,
        desc = "Run Statement at Cursor",
      },
      {
        "<leader>dx",
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
      local last_project_root = nil

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

      local function refresh_project_connections(force)
        local project_root = find_project_root()
        if not force and project_root == last_project_root then
          return
        end

        last_project_root = project_root
        local dbs, tunnels = load_env_connections(project_root)

        ensure_tunnels(project_root, tunnels)

        if type(dbs) ~= "table" then
          local ok, fallback_dbs = pcall(dofile, connections_file)
          if ok and type(fallback_dbs) == "table" then
            dbs = fallback_dbs
          end
        end

        if type(dbs) == "table" then
          vim.g.dbs = dbs
          for name, _ in pairs(dbs) do
            local safe_name = tostring(name):gsub("[^%w_-]", "_")
            vim.fn.mkdir(scripts_root .. "/" .. safe_name, "p")
          end
        end

        if not next(vim.g.dbs or {}) then
          vim.g.dbs = nil
        end

        if project_root then
          vim.g.db_ui_save_location = project_root .. "/.dbui"
        else
          vim.g.db_ui_save_location = dbs_root .. "/.dbui"
        end
      end

      vim.g.db_ui_use_nerd_fonts = 1
      vim.g.db_ui_execute_on_save = 0
      vim.g.db_ui_disable_mappings_sql = 1

      refresh_project_connections(true)

      local group = vim.api.nvim_create_augroup("DadbodUiAutoCloseDrawer", { clear = true })
      vim.api.nvim_create_autocmd({ "VimEnter", "DirChanged", "BufEnter" }, {
        group = group,
        callback = function()
          refresh_project_connections(false)
        end,
      })

      vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = "DBUIOpened",
        callback = function()
          refresh_project_connections(true)
        end,
      })

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
