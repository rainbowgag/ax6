module("luci.controller.wizard", package.seeall)

local http = require "luci.http"

function index()
    -- 直接改写 admin 根节点的调度目标
    local admin = node("admin")
    if admin then
        admin.target = call("landing_page")
    end
end

local function check_wifi(uci)
    local has_wifi = false
    pcall(function()
        uci:foreach("wireless", "wifi-device", function(s)
            has_wifi = true
            return false -- 检测到任意 wifi-device 即终止遍历
        end)
    end)
    return has_wifi
end

local function is_running(proc)
    return luci.sys.call(string.format("pgrep %s >/dev/null", proc)) == 0
end

function landing_page()
	luci.http.redirect(luci.dispatcher.build_url("admin", "status", "overview"))
end
