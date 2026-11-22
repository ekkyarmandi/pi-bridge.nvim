if vim.g.loaded_pi_bridge then return end
vim.g.loaded_pi_bridge = true

vim.api.nvim_create_user_command(
  "PiSend",
  function(cmd) require("pi-bridge").send { cmd.line1, cmd.line2 } end,
  { range = true, desc = "Send lines to an open pi session" }
)
