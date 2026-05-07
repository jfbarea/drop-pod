return {
  {
    "williamboman/mason.nvim",
    cmd = "Mason",
    build = ":MasonUpdate",
    config = function()
      require("mason").setup()
    end,
  },
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "mason.nvim" },
    config = function()
      require("mason-lspconfig").setup({
        ensure_installed = { "ts_ls", "pyright", "lua_ls" },
      })
    end,
  },
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "mason-lspconfig.nvim",
      "hrsh7th/cmp-nvim-lsp",
    },
    config = function()
      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      -- Apply capabilities to all servers
      vim.lsp.config("*", { capabilities = capabilities })

      -- Enable servers
      vim.lsp.enable({ "ts_ls", "pyright", "lua_ls" })

      -- LSP keymaps attach when a server connects to a buffer
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local opts = { buffer = args.buf }
          local map = vim.keymap.set
          map("n", "gd",         vim.lsp.buf.definition,   opts)
          map("n", "gr",         vim.lsp.buf.references,   opts)
          map("n", "K",          vim.lsp.buf.hover,        opts)
          map("n", "<leader>rn", vim.lsp.buf.rename,       opts)
          map("n", "<leader>ca", vim.lsp.buf.code_action,  opts)
          map("n", "[d",         vim.diagnostic.goto_prev, opts)
          map("n", "]d",         vim.diagnostic.goto_next, opts)
        end,
      })
    end,
  },
}
