local M = {}

local function get_config()
  return require("recall.config").opts
end

local function get_storage_dir()
  local dir = get_config().storage.path
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end
  return dir
end

local function get_project_hash(cwd)
  cwd = cwd or vim.fn.getcwd()
  -- Normalize path: absolute path and remove trailing slash
  cwd = vim.fn.fnamemodify(cwd, ":p")
  if #cwd > 1 and cwd:sub(-1):match("[/\\\\]") then
    cwd = cwd:sub(1, -2)
  end

  if vim.fn.has("sha256") == 1 then
    return vim.fn.sha256(cwd)
  else
    return cwd:gsub("[/\\:]", "_")
  end
end

local function get_project_file(cwd)
  return get_storage_dir() .. "/" .. get_project_hash(cwd) .. ".json"
end

function M.save(cwd)
  if not get_config().storage.enabled then
    return
  end

  local utils = require("recall.utils")
  local marks = {}

  utils.for_each_global_mark(function(char, info)
    table.insert(marks, {
      char = char,
      file = vim.fn.fnamemodify(info.file, ":p"),
      pos = info.pos,
    })
  end)

  local file = get_project_file(cwd)
  local f = io.open(file, "w")
  if f then
    f:write(vim.json.encode(marks))
    f:close()
  end
end

local function clear_global_marks()
  -- Try the batch command first
  pcall(vim.cmd, "delmarks A-Z")
  
  -- Extra safety: manually check and delete if any persisted
  local marks = vim.fn.getmarklist()
  for _, m in ipairs(marks) do
    if m.mark:match("'[A-Z]") then
      local char = m.mark:sub(2)
      pcall(vim.cmd, "delmarks " .. char)
    end
  end
end

function M.load(cwd)
  if not get_config().storage.enabled then
    return
  end

  -- ALWAYS clear first to ensure isolation
  clear_global_marks()

  local file = get_project_file(cwd)
  local f = io.open(file, "r")
  if not f then
    -- No state file means this directory should be clean
    require("recall.marking").refresh_signs()
    return
  end

  local content = f:read("*a")
  f:close()

  if not content or content == "" then
    require("recall.marking").refresh_signs()
    return
  end

  local ok, marks = pcall(vim.json.decode, content)
  if not ok or type(marks) ~= "table" then
    require("recall.marking").refresh_signs()
    return
  end

  for _, m in ipairs(marks) do
    if m.char and m.file and m.pos then
      local expanded_file = vim.fn.expand(m.file)
      if vim.fn.filereadable(expanded_file) == 1 then
        local bufnr = vim.fn.bufadd(expanded_file)
        vim.fn.setpos("'" .. m.char, { bufnr, m.pos[2], m.pos[3], 0 })
      end
    end
  end

  -- Final sign refresh
  require("recall.marking").refresh_signs()
end

return M
