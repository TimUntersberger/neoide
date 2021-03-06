local neoide = dofile '.\\lua\\neoide\\init.lua'

vim.g.vscode_style = "dark"

neoide.register_project_config {
	name = "Visual Studio Soluion",
	detect = function()
		local output = vim.fn.systemlist [[rg --files -g "*.sln" --max-depth 1]]
		return #output ~= 0
	end,
	ignore_list = { "bin", "obj" }
}

neoide.register_language {
	name = "lua",
	components = {
		lsp = {
			server = "sumneko_lua",
			settings = {
				Lua = {
					runtime = {
						version = "LuaJIT",
					},
					diagnostics = {
						globals = { "vim" }
					},
					workspace = {
						library = vim.api.nvim_get_runtime_file("", true)
					},
					telemetry = {
						enable = false
					}
				}
			}
		},
		treesitter = {
			grammar = "lua"
		}
	}
}

local csharp_dap_install_location = vim.fn.stdpath("data") .. "dap/netcoredbg"

neoide.register_language {
	name = "csharp",
	components = {
		lsp = {
			server = "omnisharp"
		},
		treesitter = {
			grammar = "c_sharp"
		},
		dap = {
			install_command = {},
			adapter = {
				name = "coreclr",
				type = "executable",
				command = csharp_dap_install_location,
				args = {"--interpreter=vscode"}
			},
			config = {
				type = "coreclr",
				name = "launch - netcoredbg",
				request = "launch",
				program = function()
					return vim.fn.input('Path to dll', vim.fn.getcwd() .. '/bin/Debug/', 'file')
				end
			}
		}
	}
}

neoide.setup {
	plugins = {
		"Mofiqul/vscode.nvim",
	},
	colorscheme = "vscode"
}

vim.o.number = true
vim.o.relativenumber = true
vim.o.tabstop = 4
vim.o.shiftwidth = 4
