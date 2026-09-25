-- bar.wezterm の "spotify" モジュールを差し替えてシステム情報を表示する。
-- プラグインは package.path の先頭にある設定ディレクトリを先に探すため、
-- ここに bar/spotify.lua を置くとプラグイン同梱の bar/spotify.lua より優先される。
-- インターフェースは元モジュールと同じ get_currently_playing(max_width, throttle)。
local wezterm = require("wezterm")

local M = {}

local last_update = 0
local last_text = ""

local function run(args)
	local ok, out = wezterm.run_child_process(args)
	if ok then
		return out
	end
	return nil
end

-- 使用中メモリ(GB): アクティビティモニタの「使用済みメモリ」と同じ計算
local function ram_gb()
	local out = run({ "vm_stat" })
	if not out then
		return nil
	end
	local page = tonumber(out:match("page size of (%d+) bytes")) or 4096
	local anon = tonumber(out:match("Anonymous pages:%s+(%d+)")) or 0
	local purgeable = tonumber(out:match("Pages purgeable:%s+(%d+)")) or 0
	local wired = tonumber(out:match("Pages wired down:%s+(%d+)")) or 0
	local compressed = tonumber(out:match("Pages occupied by compressor:%s+(%d+)")) or 0
	return (anon - purgeable + wired + compressed) * page / 1024 / 1024 / 1024
end

-- CPU使用率(%): 全プロセスの %cpu 合計をコア数で割る
local ncpu
local function cpu_pct()
	ncpu = ncpu or tonumber(run({ "sysctl", "-n", "hw.ncpu" })) or 1
	local out = run({ "sh", "-c", "ps -A -o %cpu | awk '{s+=$1} END {print s}'" })
	local total = tonumber(out)
	if not total then
		return nil
	end
	return total / ncpu
end

local function battery()
	local parts = {}
	for _, b in ipairs(wezterm.battery_info()) do
		local pct = b.state_of_charge * 100
		local icon = wezterm.nerdfonts.md_battery
		if b.state == "Charging" then
			icon = wezterm.nerdfonts.md_battery_charging
		elseif pct <= 20 then
			icon = wezterm.nerdfonts.md_battery_20
		elseif pct <= 50 then
			icon = wezterm.nerdfonts.md_battery_50
		elseif pct <= 80 then
			icon = wezterm.nerdfonts.md_battery_80
		end
		table.insert(parts, string.format("%s %.0f%%", icon, pct))
	end
	return table.concat(parts, " ")
end

function M.get_currently_playing(_, throttle)
	if os.time() - last_update < (throttle or 5) then
		return last_text
	end

	local parts = {}
	local cpu = cpu_pct()
	if cpu then
		table.insert(parts, string.format("%s %d%%", wezterm.nerdfonts.oct_cpu, math.floor(cpu + 0.5)))
	end
	local ram = ram_gb()
	if ram then
		table.insert(parts, string.format("%s %.1fG", wezterm.nerdfonts.md_memory, ram))
	end
	local bat = battery()
	if bat ~= "" then
		table.insert(parts, bat)
	end

	last_text = table.concat(parts, "  ")
	last_update = os.time()
	return last_text
end

return M
