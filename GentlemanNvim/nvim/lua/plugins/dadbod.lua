return {
  {
    "tpope/vim-dadbod",
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
      { "<leader>D", "<cmd>DBUIToggle<cr>", desc = "Dadbod UI" },
    },
    dependencies = {
      {
        "kristijanhusak/vim-dadbod-ui",
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
              "  -- main = \"postgres://user:pass@127.0.0.1:5432/app\",",
              "  -- analytics = \"mysql://user:pass@127.0.0.1:3306/analytics\",",
              "  -- notes = \"sqlite:/data/data/com.termux/files/home/storage/shared/notes.db\",",
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
        end,
      },
      {
        "kristijanhusak/vim-dadbod-completion",
        ft = { "sql", "mysql", "plsql" },
      },
    },
  },
}
