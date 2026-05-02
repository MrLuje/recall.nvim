local M = {}

M.opts = {
  sign = "",
  sign_highlight = "@comment.note",

  telescope = {
    autoload = true,
    mappings = {
      unmark_selected_entry = {
        normal = "dd",
        insert = "<M-d>",
      },
    },
  },

  snacks = {
    mappings = {
      unmark_selected_entry = {
        normal = "dd",
        insert = "<M-d>",
      },
    },
  },

  -- https://github.com/neovim/neovim/issues/4295
  -- https://github.com/neovim/neovim/pull/24936 (0.10-only)
  wshada = vim.fn.has("nvim-0.10") == 0,

  storage = {
    enabled = true,
    path = vim.fn.stdpath("state") .. "/recall",
  },
}

function M.setup(opts)
  M.opts = vim.tbl_deep_extend("force", M.opts, opts or {})

  vim.fn.sign_define("RecallSign", { text = M.opts.sign, texthl = M.opts.sign_highlight })

  local augroup = vim.api.nvim_create_augroup("RecallRefreshSigns", { clear = true })

  vim.api.nvim_create_autocmd("BufEnter", {
    group = augroup,
    pattern = "*",
    callback = function()
      require("recall.marking").refresh_signs()
    end,
  })

  if M.opts.storage.enabled then
    -- Handle lazy-loading: if setup is called after VimEnter, load immediately
    if vim.v.vim_did_enter == 1 then
      vim.schedule(function()
        require("recall.storage").load()
      end)
    end

    vim.api.nvim_create_autocmd({ "VimEnter", "SessionLoadPost" }, {
      group = augroup,
      callback = function()
        vim.schedule(function()
          require("recall.storage").load()
        end)
      end,
    })

    vim.api.nvim_create_autocmd("VimLeavePre", {
      group = augroup,
      callback = function()
        require("recall.storage").save()
      end,
    })

    vim.api.nvim_create_autocmd("DirChanged", {
      group = augroup,
      callback = function(ev)
        local new_dir = (ev.data and ev.data.cwd) or vim.fn.getcwd()
        vim.schedule(function()
          require("recall.storage").load(new_dir)
        end)
      end,
    })
  end

  if M.opts.telescope.autoload then
    vim.schedule(function()
      require("recall.telescope").autoload()
    end)
  end
end

return M
