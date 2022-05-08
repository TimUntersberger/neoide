local KeybindingKind = {
	LspHover = "LspHover",
	LspGoToDefinition = "LspGoToDefinition",
	LspGoToReference = "LspGoToReference",
	LspGoToImplementation = "LspGoToImplementation",
	FindFile = "FindFile",
	SearchFiles = "SearchFiles",
	FormatFile = "FormatFile"
}

local M = {
	languages = {},
	project_configurations = {},
	active_project_config = nil,
	packer = {
		git = 'https://github.com/wbthomason/packer.nvim',
		plugins = {
			'wbthomason/packer.nvim',
			"neovim/nvim-lspconfig",
			'williamboman/nvim-lsp-installer',
			'nvim-treesitter/nvim-treesitter',
			'nvim-lua/plenary.nvim',
			'nvim-telescope/telescope.nvim',
			'hrsh7th/nvim-cmp',
			'hrsh7th/cmp-nvim-lsp',
			'L3MON4D3/LuaSnip',
			'saadparwaiz1/cmp_luasnip'
		}
	},
	keybindings = {
		[KeybindingKind.LspHover] = "K",
		[KeybindingKind.LspGoToDefinition] = "<c-]>",
		[KeybindingKind.LspGoToImplementation] = "<c-[>",
		[KeybindingKind.LspGoToReference] = "<c-r>",
		[KeybindingKind.FindFile] = "<c-p>",
	},
	KeybindingKind = KeybindingKind,
	config = {}
}

local function get_active_project_config()
	if M.active_project_config == nil then
		return nil
	end

	for _, pc in ipairs(M.project_configurations) do
		if pc.name == M.active_project_config then
			return pc
		end
	end

	return nil
end


local function detect_active_project_config()
	for _,pc in ipairs(M.project_configurations) do
		if pc.detect() then
			M.active_project_config = pc.name
			break
		end
	end
end

local function install_packer()
	local install_path = vim.fn.stdpath('data') .. '/site/pack/packer/start/packer.nvim'
	if vim.fn.empty(vim.fn.glob(install_path)) > 0 then
		vim.fn.system({'git', 'clone', '--depth', '1', M.packer.git, install_path})
		return true
	end
	return false
end

local function setup_plugins(should_compile)
	if should_compile == nil then
		should_compile = false
	end

	local packer = require 'packer'

	packer.startup(function(use)
		for _,p in ipairs(M.packer.plugins) do
			use(p)
		end

		for _,p in ipairs(M.config.plugins) do
			use(p)
		end

		if should_compile then
			packer.install()
			packer.compile()
		end
	end)
end

function M.register_project_config(pc)
	table.insert(M.project_configurations, pc)
end

function M.register_language(l)
	table.insert(M.languages, l)
end

local KeybindingHandlers = {
	[KeybindingKind.LspHover] = vim.lsp.buf.hover,
	[KeybindingKind.LspGoToDefinition] = require'telescope.builtin'.lsp_definitions,
	[KeybindingKind.LspGoToImplementation] = require'telescope.builtin'.lsp_implementations,
	[KeybindingKind.LspGoToReference] = require'telescope.builtin'.lsp_references,
	[KeybindingKind.SearchFiles] = function()
	end,
	[KeybindingKind.FindFile] = function()
		local find_cmd = { "rg", "-i", "--hidden", "--files", "-g", "!.git" }
		local tb = require 'telescope.builtin'

		tb.find_files {
			find_command = find_cmd,
		}
	end,
	[KeybindingKind.FormatFile] = vim.lsp.buf.formatting,
}

function M.setup(config)
	M.config = config

	install_packer()

	setup_plugins(true)

	detect_active_project_config()

	vim.api.nvim_create_autocmd({"DirChanged"}, {
		pattern = "*",
		callback = detect_active_project_config
	})

	if M.config.colorscheme then
		vim.cmd("colorscheme " .. M.config.colorscheme)
	end

	local lspinstaller = require("nvim-lsp-installer")
	local tsconfig = require('nvim-treesitter.configs')
	local lspconfig = require("lspconfig")
	local capabilities = require('cmp_nvim_lsp').update_capabilities(vim.lsp.protocol.make_client_capabilities())

	local lsp_ensure_installed = {}
	local ts_ensure_installed = {}

	for _,language in ipairs(M.languages) do
		if language.components.lsp then
			table.insert(lsp_ensure_installed, language.components.lsp.server)
		end
		if language.components.treesitter then
			table.insert(ts_ensure_installed, language.components.treesitter.grammar)
		end
	end

	tsconfig.setup {
		ensure_installed = ts_ensure_installed,
	}

	lspinstaller.setup {
		ensure_installed = lsp_ensure_installed
	}

	for _,language in ipairs(M.languages) do
		if language.components.lsp then
			local settings = language.components.lsp.settings
			local server_name = language.components.lsp.server
			local ok, server = lspinstaller.get_server(server_name)

			if ok then
				print("neoide:language:" .. language.name .. " setting up lsp component")
				print("neoide:language:" .. language.name .. ":lsp setting up lspconfig")
				lspconfig[server_name].setup {
					settings = settings,
					capabilities = capabilities
				}
				print("neoide:language:" .. language.name .. " finished setting up lsp component")
			else
				print("neoide:language:" .. language.name .. " server '" .. server_name .. "' not supported")
			end
		end
		if language.components.treesitter then

		end
	end

	local cmp = require'cmp'

	cmp.setup({
		snippet = {
			-- REQUIRED - you must specify a snippet engine
			expand = function(args)
				require('luasnip').lsp_expand(args.body)
			end,
		},
		window = {
			completion = cmp.config.window.bordered(),
			documentation = cmp.config.window.bordered(),
		},
		mapping = cmp.mapping.preset.insert({
			['<C-b>'] = cmp.mapping.scroll_docs(-4),
			['<C-f>'] = cmp.mapping.scroll_docs(4),
			['<C-n>'] = cmp.mapping.complete(),
			['<C-e>'] = cmp.mapping.abort(),
			['<CR>'] = cmp.mapping.confirm({ select = true }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
		}),
		sources = cmp.config.sources({
			{ name = 'nvim_lsp' },
			{ name = 'luasnip' }, -- For luasnip users.
		}, {
			{ name = 'buffer' },
		})
	})

	local keybindings = vim.tbl_extend("force", M.keybindings, M.config.keybindings or {})

	for kind, key in pairs(keybindings) do
		print(string.format("neoide:keybinding binding '%s' to %s", key, kind))
		vim.keymap.set('n', key, KeybindingHandlers[kind])
	end
end

return M
