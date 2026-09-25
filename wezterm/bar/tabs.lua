-- bar.wezterm の bar.tabs を差し替え、タブに alien アイコンを付け、cwd が git 管理下ならブランチ名も付ける。
-- 設定ディレクトリが package.path の先頭にあるため、同梱の bar/tabs.lua より優先される。
-- get_title(tab_info) のインターフェースは元のまま。
local wezterm = require("wezterm")
local utilities = require("bar.utilities")

local M = {}

-- タブのアイコン。普段は Zellij の中にいてフォアグラウンドプロセスが常に zellij になるため、
-- プロセス別に出し分けても意味がない。全タブ共通で alien にする
local TAB_ICON = wezterm.nerdfonts.weather_alien or "👽"

local function read_file(path)
	local f = io.open(path, "r")
	if not f then
		return nil
	end
	local s = f:read("*a")
	f:close()
	return s
end

-- .git/HEAD を直接読んでブランチ名を返す(プロセス起動なし)
-- worktree / submodule の ".git" ファイル(gitdir: ...)にも対応
---@param directory string
---@return string|nil
local function git_branch(directory)
	while directory and directory ~= "" do
		local dotgit = directory .. "/.git"
		local head = read_file(dotgit .. "/HEAD")
		if not head then
			local gitfile = read_file(dotgit)
			local gitdir = gitfile and gitfile:match("^gitdir:%s*(.-)%s*$")
			if gitdir then
				if gitdir:sub(1, 1) ~= "/" then
					gitdir = directory .. "/" .. gitdir
				end
				head = read_file(gitdir .. "/HEAD")
			end
		end
		if head then
			local ref = head:match("^ref:%s*refs/heads/(.-)%s*$")
			if ref then
				return ref
			end
			return head:sub(1, 7) -- detached HEAD は短い SHA
		end
		if directory == "/" then
			break
		end
		directory = directory:match("(.+)/[^/]*") or ""
	end
	return nil
end

---タブ表示の部品(番号は呼び出し側で付ける)
---@param tab_info table
---@return { icon: string, title: string, branch: string|nil }
M.get_parts = function(tab_info)
	local title = tab_info.tab_title
	if not title or #title == 0 then
		-- 元の実装と同じく、アクティブペインのタイトルから拡張子を落としたもの
		title = utilities._basename(tab_info.active_pane.title) or ""
	end

	local pane = tab_info.active_pane
	local cwd_uri = pane and pane.current_working_dir
	local cwd = cwd_uri and (type(cwd_uri) == "string" and cwd_uri:sub(8):match("/.*") or cwd_uri.file_path)
	local branch = cwd and git_branch(cwd) or nil

	return { icon = TAB_ICON, title = title, branch = branch }
end

---@param tab_info table
---@return string?
M.get_title = function(tab_info)
	local parts = M.get_parts(tab_info)
	local title = parts.icon .. " " .. parts.title
	if parts.branch then
		title = title .. " " .. wezterm.nerdfonts.pl_branch .. " " .. parts.branch
	end
	return title
end

return M
