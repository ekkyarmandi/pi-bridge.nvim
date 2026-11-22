-- Send the visual selection to an open pi session (via pi-intercom) as context

local M = {}

---@class PiBridgeConfig
---@field cli string path to the pi-intercom CLI script
local defaults = {
  cli = vim.fn.expand "~/.pi/agent/npm/node_modules/pi-intercom/cli.mjs",
}

---@type PiBridgeConfig
M.config = vim.deepcopy(defaults)

---@param opts? PiBridgeConfig
function M.setup(opts) M.config = vim.tbl_deep_extend("force", defaults, opts or {}) end

local function intercom(args, on_done)
  vim.system(vim.list_extend({ "node", M.config.cli }, args), { text = true }, function(res)
    vim.schedule(function() on_done(res) end)
  end)
end

local function pick_session(cb)
  intercom({ "list", "--json" }, function(res)
    local ok, data = pcall(vim.json.decode, res.stdout or "")
    if not ok or not data.ok then
      return vim.notify("pi-intercom: " .. (res.stderr or "list failed"), vim.log.levels.ERROR)
    end
    local cwd = vim.fn.getcwd()
    local sessions = vim.tbl_filter(function(s) return s.cwd == cwd and s.name ~= "pi-intercom-cli" end, data.sessions)
    if #sessions == 0 then return vim.notify("No pi session in " .. cwd, vim.log.levels.WARN) end
    if #sessions == 1 then return cb(sessions[1]) end
    vim.ui.select(sessions, {
      prompt = "Pi session",
      format_item = function(s) return ("%s (%s, %s)"):format(s.name, s.model, s.status) end,
    }, function(s)
      if s then cb(s) end
    end)
  end)
end

---@param range? integer[] { line1, line2 }; defaults to the current visual selection
function M.send(range)
  local lines, l1, l2
  if range then
    l1, l2 = range[1], range[2]
    lines = vim.api.nvim_buf_get_lines(0, l1 - 1, l2, false)
  else
    local start_pos, end_pos = vim.fn.getpos "v", vim.fn.getpos "."
    lines = vim.fn.getregion(start_pos, end_pos, { type = vim.fn.mode() })
    l1, l2 = math.min(start_pos[2], end_pos[2]), math.max(start_pos[2], end_pos[2])
    vim.api.nvim_feedkeys(vim.keycode "<Esc>", "nx", false)
  end
  local file = vim.fn.expand "%:."
  local ft = vim.bo.filetype

  vim.ui.input({ prompt = "Pi (optional note): " }, function(note)
    if note == nil then return end
    local msg = table.concat({
      ("Context from %s:%d-%d"):format(file, l1, l2),
      "```" .. ft,
      table.concat(lines, "\n"),
      "```",
    }, "\n")
    if note ~= "" then msg = note .. "\n\n" .. msg end
    pick_session(function(s)
      intercom({ "send", "--to", s.id, "--text", msg }, function(res)
        if res.code == 0 then
          vim.notify("Sent to " .. s.name)
        else
          vim.notify("pi-intercom: " .. res.stderr, vim.log.levels.ERROR)
        end
      end)
    end)
  end)
end

return M
