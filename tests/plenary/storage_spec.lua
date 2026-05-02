local luv = require("luv")
local recall = require("recall")
local storage = require("recall.storage")

local function set_lines(buffer, count)
  local lines = {}
  for i = 1, count do
    table.insert(lines, i .. " Lorem ipsum dolor sit amet")
  end
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)
end

describe("Recall Storage", function()
  local temp_dir
  local temp_paths = {}
  local cwd = vim.fn.getcwd()

  local function create_temp_buffer(name)
    local _bufnr = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_set_current_buf(_bufnr)
    set_lines(_bufnr, 10)
    local temp_path = temp_dir .. "/" .. (name or ("test-" .. luv.hrtime() .. ".txt"))
    table.insert(temp_paths, temp_path)
    vim.api.nvim_buf_set_name(_bufnr, temp_path)
    vim.cmd("w")
    return _bufnr
  end

  before_each(function()
    temp_dir = luv.os_tmpdir() .. "/nvim-recall-storage-test-" .. luv.hrtime()
    vim.fn.mkdir(temp_dir, "p")
    
    recall.setup({
      storage = {
        enabled = true,
        path = temp_dir .. "/storage",
      }
    })
  end)

  after_each(function()
    vim.cmd("bufdo! bdelete")
    vim.cmd("delmarks A-Z")
    vim.api.nvim_set_current_dir(cwd)
    -- Cleanup temp dir
    vim.fn.delete(temp_dir, "rf")
    temp_paths = {}
  end)

  it("persists marks to a file and loads them back", function()
    local project1 = temp_dir .. "/project1"
    vim.fn.mkdir(project1, "p")
    vim.api.nvim_set_current_dir(project1)

    create_temp_buffer("file1.txt")
    vim.api.nvim_win_set_cursor(0, { 5, 0 })
    recall.mark()

    -- Check if storage file exists
    local storage_files = vim.fn.glob(temp_dir .. "/storage/*.json", true, true)
    assert.are.equal(#storage_files, 1)

    -- Clear marks manually
    vim.cmd("delmarks A-Z")
    assert.are.equal(#vim.fn.getmarklist(), 0)

    -- Load marks back
    storage.load()
    local marks = vim.fn.getmarklist()
    -- Filter global marks A-Z
    local global_marks = {}
    for _, m in ipairs(marks) do
      if m.mark:match("'[A-Z]") then
        table.insert(global_marks, m)
      end
    end
    assert.are.equal(#global_marks, 1)
    assert.are.equal(global_marks[1].mark, "'A")
    assert.are.equal(global_marks[1].pos[2], 5)
  end)

  it("isolates marks between projects", function()
    local project1 = temp_dir .. "/project1"
    local project2 = temp_dir .. "/project2"
    vim.fn.mkdir(project1, "p")
    vim.fn.mkdir(project2, "p")

    -- Project 1
    vim.api.nvim_set_current_dir(project1)
    create_temp_buffer("p1_file.txt")
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    recall.mark()

    -- Project 2
    vim.api.nvim_set_current_dir(project2)
    -- Note: In a real scenario, DirChanged would trigger storage.load()
    -- But since we are calling it manually in tests or relying on setup, 
    -- let's simulate the switch.
    storage.load() 
    
    local global_marks = {}
    for _, m in ipairs(vim.fn.getmarklist()) do
      if m.mark:match("'[A-Z]") then table.insert(global_marks, m) end
    end
    assert.are.equal(#global_marks, 0, "Project 2 should have no marks initially")

    create_temp_buffer("p2_file.txt")
    vim.api.nvim_win_set_cursor(0, { 8, 0 })
    recall.mark()
    
    global_marks = {}
    for _, m in ipairs(vim.fn.getmarklist()) do
      if m.mark:match("'[A-Z]") then table.insert(global_marks, m) end
    end
    assert.are.equal(#global_marks, 1)
    assert.are.equal(global_marks[1].pos[2], 8)

    -- Switch back to Project 1
    vim.api.nvim_set_current_dir(project1)
    storage.load()
    
    global_marks = {}
    for _, m in ipairs(vim.fn.getmarklist()) do
      if m.mark:match("'[A-Z]") then table.insert(global_marks, m) end
    end
    assert.are.equal(#global_marks, 1)
    assert.are.equal(global_marks[1].pos[2], 2)
  end)
end)
