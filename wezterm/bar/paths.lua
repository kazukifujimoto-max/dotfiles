-- bar.wezterm の bar.paths を差し替え、cwd モジュールに git 情報(ブランチ・ahead/behind・変更数)を付ける。
-- 設定ディレクトリが package.path の先頭にあるため、同梱の bar/paths.lua より優先される。
-- get_cwd(pane, search_git_root_instead) のインターフェースは元のまま。
local wezterm = require("wezterm")
local utilities = require("bar.utilities")

local M = {}

local THROTTLE = 5 -- 秒。同じディレクトリでは git を叩く間隔を空ける
local cache = {} -- path -> { time = os.time(), text = "..." }

---@param directory string
---@return string|nil
local function find_git_root(directory)
	directory = directory:gsub("^~", utilities.home)
	while directory and directory ~= "" do
		local handle = io.open(directory .. "/.git/HEAD", "r")
		if handle then
			handle:close()
			return directory
		end
		if directory == "/" then
			break
		end
		directory = directory:match("(.+)/[^/]*") or ""
	end
	return nil
end

-- starship の git_status と同じ記号で組み立てる
---@param root string
---@return string
local function git_info(root)
	local entry = cache[root]
	if entry and os.time() - entry.time < THROTTLE then
		return entry.text
	end

	local ok, out = wezterm.run_child_process({ "git", "-C", root, "status", "--porcelain=v2", "-b" })
	local text = ""
	if ok and out then
		local branch = out:match("# branch%.head (%S+)") or "HEAD"
		local ahead, behind = out:match("# branch%.ab %+(%d+) %-(%d+)")
		local staged, modified, untracked, conflicted = 0, 0, 0, 0
		for line in out:gmatch("[^\n]+") do
			local kind = line:sub(1, 1)
			if kind == "1" or kind == "2" then
				local xy = line:sub(3, 4)
				if xy:sub(1, 1) ~= "." then
					staged = staged + 1
				end
				if xy:sub(2, 2) ~= "." then
					modified = modified + 1
				end
			elseif kind == "u" then
				conflicted = conflicted + 1
			elseif kind == "?" then
				untracked = untracked + 1
			end
		end

		local parts = { wezterm.nerdfonts.pl_branch .. " " .. branch }
		local status = {}
		if conflicted > 0 then
			table.insert(status, "=" .. conflicted)
		end
		ahead, behind = tonumber(ahead) or 0, tonumber(behind) or 0
		if ahead > 0 and behind > 0 then
			table.insert(status, "⇕⇡" .. ahead .. "⇣" .. behind)
		elseif ahead > 0 then
			table.insert(status, "⇡" .. ahead)
		elseif behind > 0 then
			table.insert(status, "⇣" .. behind)
		end
		if untracked > 0 then
			table.insert(status, "?" .. untracked)
		end
		if modified > 0 then
			table.insert(status, "!" .. modified)
		end
		if staged > 0 then
			table.insert(status, "+" .. staged)
		end
		if #status > 0 then
			table.insert(parts, table.concat(status, ""))
		end
		text = table.concat(parts, " ")
	end

	cache[root] = { time = os.time(), text = text }
	return text
end

---@param pane table
---@param search_git_root_instead boolean
---@return string
M.get_cwd = function(pane, search_git_root_instead)
	local cwd = ""
	local cwd_uri = pane:get_current_working_dir()
	if not cwd_uri then
		return cwd
	end
	if type(cwd_uri) == "string" then
		-- 古い wezterm は "file://host/path" の文字列を返す
		cwd = cwd_uri:sub(8):match("/.*") or ""
	else
		cwd = cwd_uri.file_path or ""
	end
	cwd = cwd:gsub(utilities.home .. "(.-)$", "~%1")

	local root = find_git_root(cwd)
	if search_git_root_instead and root then
		cwd = root:match("([^/]+)$") or cwd
	end

	if root then
		local info = git_info(root)
		if info ~= "" then
			cwd = cwd .. "  " .. info
		end
	end
	return cwd
end

return M
