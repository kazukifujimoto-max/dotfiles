local wezterm = require("wezterm")

-- starship の fuji_dark と既存タブ配色に合わせる
local palette = {
	base = "#001829", -- 夜空
	surface = "#123047",
	accent = "#4C8FA9", -- 山肌にかかる空の青
	snow = "#B7E3E0", -- 山頂の雪
	text = "#8FBFBB",
	muted = "#7A9BAD",
	-- タブ: アクティブは雪明かりの淡い青地に濃紺文字、非アクティブは夜空に沈む
	tab_active_bg = "#4C8FA9",
	tab_active_fg = "#001829",
	tab_inactive_fg = "#7A9BAD",
}

-- タブの見た目: "slant"(◢ ◤ の三角で斜めに区切る) / "underline"(地色なし、アクティブは太字+下線)
local TAB_STYLE = "underline"

local TRI_LEFT = wezterm.nerdfonts.ple_lower_right_triangle -- 
local TRI_RIGHT = wezterm.nerdfonts.ple_upper_left_triangle -- 

local function slant_tab(title, tab, hover)
	local bg, fg = palette.surface, palette.text
	if tab.is_active then
		bg, fg = palette.tab_active_bg, palette.tab_active_fg
	elseif hover then
		bg, fg = "#1F4B66", palette.snow
	end
	local edge = palette.base
	return {
		{ Background = { Color = edge } },
		{ Foreground = { Color = bg } },
		{ Text = TRI_LEFT },
		{ Background = { Color = bg } },
		{ Foreground = { Color = fg } },
		{ Text = " " .. title .. " " },
		{ Background = { Color = edge } },
		{ Foreground = { Color = bg } },
		{ Text = TRI_RIGHT },
	}
end

-- 地色なし(常に base)。配色はダークブルー系で統一
--   アクティブ: 番号=accent_bright / アイコン=blue / タイトル=bright blue(太字+下線)
--   非アクティブ: 沈んだ青。ホバーで blue に浮く
local tab_colors = {
	active = { index = "#5C9BB3", icon = "#84A0C6", title = "#9DB5D6" },
	inactive = { index = "#3E5F80", icon = "#3E5F80", title = "#4F7397" },
	hover = { index = "#5C9BB3", icon = "#84A0C6", title = "#84A0C6" },
}

local function underline_tab(index, parts, tab, hover, max_title)
	local active = tab.is_active
	local bg = palette.base
	local c = active and tab_colors.active or (hover and tab_colors.hover or tab_colors.inactive)
	local title = wezterm.truncate_right(parts.title, max_title)

	local items = {
		{ Background = { Color = bg } },
		{ Foreground = { Color = c.index } },
		{ Attribute = { Intensity = "Bold" } },
		{ Text = " " .. index .. " " },
		{ Attribute = { Intensity = active and "Bold" or "Normal" } },
		{ Attribute = { Underline = active and "Single" or "None" } },
		{ Foreground = { Color = c.icon } },
		{ Text = parts.icon .. " " },
		{ Foreground = { Color = c.title } },
		{ Text = title },
	}
	table.insert(items, { Attribute = { Underline = "None" } })
	table.insert(items, { Attribute = { Intensity = "Normal" } })
	table.insert(items, { Text = " " })
	return items
end

-- タブの描画は自前で行う。
-- WezTerm は値を返すイベント(format-tab-title)では最初に登録されたハンドラしか呼ばないため、
-- bar.wezterm を require するより前にここで登録しておくと、タブだけ自前・ステータスはプラグインという分担になる。
wezterm.on("format-tab-title", function(tab, _, _, conf, hover, _)
	-- 注意: 第6引数 max_width は2回目の呼び出しで「1回目に描いた幅」が渡ってくるため、
	-- それを基準に切り詰めると短いタブが縮んでいく。設定値 tab_max_width を基準にする。
	local max_title = (conf.tab_max_width or 48) - 12
	-- タイトル文字列(alien アイコン + タイトル + ブランチ)は bar/tabs.lua に任せる
	local tabs = require("bar.tabs")
	local index = tab.tab_index + 1
	if TAB_STYLE == "underline" then
		return underline_tab(index, tabs.get_parts(tab), tab, hover, max_title)
	end
	local parts = tabs.get_parts(tab)
	local title = index .. " " .. parts.icon .. " " .. wezterm.truncate_right(parts.title, max_title)
	return slant_tab(title, tab, hover)
end)

-- ステータスバーも自前で描く。
-- update-status は登録順に全ハンドラが呼ばれるが、false を返すと後続が呼ばれなくなる。
-- ここで false を返してプラグイン側の描画を止め、左右の内容をこちらで決める。
--   左: workspace(Leader中はロケット) / zoom / フォアグラウンドプロセス / ディレクトリ + git
--   右: CPU / RAM / バッテリー / 日時
local status_colors = {
	workspace = "#84A0C6", -- blue
	leader = "#CC7A8B", -- red
	zoom = "#C8B482", -- yellow
	process = "#89B8C2", -- cyan
	cwd = "#8BBF9F", -- green
	sysinfo = "#8FBFBB", -- text
	clock = "#A093C7", -- purple
	separator = "#3E5F80",
}

local function add_module(cells, color, icon, text)
	table.insert(cells, { Foreground = { Color = color } })
	table.insert(cells, { Text = " " .. icon .. " " .. text .. " " })
end

local function add_separator(cells)
	table.insert(cells, { Foreground = { Color = status_colors.separator } })
	table.insert(cells, { Text = "│" })
end

wezterm.on("update-status", function(window, pane)
	local nf = wezterm.nerdfonts
	local utilities = require("bar.utilities")

	-- 左
	local left = { { Background = { Color = palette.base } } }
	local workspace = window:active_workspace()
	if window:leader_is_active() then
		add_module(left, status_colors.leader, nf.oct_rocket, workspace)
	else
		add_module(left, status_colors.workspace, nf.md_weather_night, workspace)
	end
	local ok, tab = pcall(pane.tab, pane)
	if ok and tab then
		for _, p in ipairs(tab:panes_with_info()) do
			if p.is_active and p.is_zoomed then
				add_module(left, status_colors.zoom, nf.md_fullscreen, "zoom")
			end
		end
	end
	local process = pane:get_foreground_process_name()
	if process then
		add_module(left, status_colors.process, nf.cod_multiple_windows, utilities._basename(process) or "")
	end
	local cwd = require("bar.paths").get_cwd(pane, true) -- "dir  branch ?1!2" の形
	if cwd ~= "" then
		add_module(left, status_colors.cwd, nf.oct_file_directory, cwd)
	end
	window:set_left_status(wezterm.format(left))

	-- 右
	local right = { { Background = { Color = palette.base } } }
	local sysinfo = require("bar.spotify").get_currently_playing(nil, 5) -- CPU / RAM / バッテリー
	if sysinfo ~= "" then
		add_module(right, status_colors.sysinfo, nf.md_desktop_classic, sysinfo)
		add_separator(right)
	end
	add_module(right, status_colors.clock, nf.md_calendar_clock, wezterm.time.now():format("%m/%d(%a) %H:%M"))
	window:set_right_status(wezterm.format(right))

	return false -- プラグインの update-status を呼ばせない
end)

-- https://github.com/adriankarlen/bar.wezterm
local bar = wezterm.plugin.require("https://github.com/adriankarlen/bar.wezterm")

local M = {}

function M.apply_to_config(config)
	-- タブの色は HEX 指定できるのでここで設定する
	-- (bar.wezterm は color_scheme 未設定のとき tab_bar の色を触らない)
	config.colors = config.colors or {}
	-- 端末の ANSI 16色を starship の fuji_dark に揃える。
	-- bar.wezterm のモジュール色はここの番号(1=black … 8=white)で指定する
	config.colors.ansi = {
		"#123047", -- 1 black   (surface)
		"#CC7A8B", -- 2 red     (error)
		"#8BBF9F", -- 3 green   (success)
		"#C8B482", -- 4 yellow  (fuji に無いので同系統の落ち着いた砂色)
		"#84A0C6", -- 5 blue
		"#A093C7", -- 6 magenta (purple)
		"#89B8C2", -- 7 cyan
		"#8FBFBB", -- 8 white   (text)
	}
	config.colors.brights = {
		"#7A9BAD", -- 9  bright black (muted)
		"#D98FA0", -- 10 bright red
		"#9FD1B2", -- 11 bright green
		"#DBC898", -- 12 bright yellow
		"#9DB5D6", -- 13 bright blue
		"#B5A9D8", -- 14 bright magenta
		"#9FCBD4", -- 15 bright cyan
		"#B7E3E0", -- 16 bright white
	}
	config.colors.tab_bar = config.colors.tab_bar or {}
	config.colors.tab_bar.background = palette.base
	config.colors.tab_bar.active_tab = { bg_color = palette.tab_active_bg, fg_color = palette.tab_active_fg }
	config.colors.tab_bar.inactive_tab = { bg_color = palette.base, fg_color = palette.tab_inactive_fg }
	config.colors.tab_bar.inactive_tab_hover = { bg_color = palette.surface, fg_color = palette.snow }
	config.colors.tab_bar.new_tab = { bg_color = palette.base, fg_color = palette.text }

	-- タブとステータスは上の format-tab-title / update-status で自前描画するため、
	-- プラグインには基本設定(位置・幅・retro タブバー化)だけ任せる
	bar.apply_to_config(config, {
		position = "bottom",
		max_width = 48,
	})
end

return M
