--[[
    A simple script that attempts to make it easier to configure
    the `user-data` property using config files.

    The script has two features:
        - user-data properties can be set on startup using config files
        - user-data can be set during runtime using script-opts
    See the README for documentation.

    This file is under the MIT license, see Github for the license file.

    Project available at: https://github.com/CogentRedTester/mpv-user-data-loader
]]

local mp = require 'mp'
local msg = require 'mp.msg'
local utils = require 'mp.utils'

local overrides = {}
local prev_values = {}

local config_path = mp.command_native({'expand-path', '~~/script-opts/user-data.conf'})
local json_config_file = mp.command_native({'expand-path', '~~/script-opts/user-data.json'})

-- tests if two complex values are equal
local function is_equal(a,b)
    return utils.to_string(a) == utils.to_string(b)
end

-- Sets a field of the user-data property.
-- Appends `user-data/` to `key` and passes value through natively.
local function set_value_native(key, ud_value)
    local ud_key = 'user-data/'..key
    local prev_val = mp.get_property_native(ud_key)

    if not is_equal(prev_val, ud_key) then
        msg.verbose('setting', ud_key, utils.to_string(ud_value))
        mp.set_property_native(ud_key, ud_value)
    end

    return true, {
        key = ud_key,
        value = ud_value,
        prev_value = prev_val,
    }
end

-- Sets a field of the user-data property.
-- Appends `user-data/` to `key` and parses `value` as a json string.
local function set_value(key, value)
    local ud_value, err, trail = utils.parse_json(value, true)

    if (err) then
        msg.error(err)
        msg.warn('failed to parse user-data JSON string:', value)
        return false
    end

    local success, vars = set_value_native(key, ud_value)
    if vars then vars.trail = trail end
    return success, vars
end

-- loading the values from user-data.conf
-- uses normal script-opts syntax
local function setup_config()
    local file = io.open(config_path, 'r')
    if not file then
        msg.debug('could not read', config_path)
        return
    end

    msg.debug('reading values from', config_path)

    for line in file:lines() do
        if line ~= '' and string.sub(line, 1, 1) ~= '#' then
            local key, value = string.match(line, '^([^=]+)=(.+)')
            if not key or not value then
                msg.error('invalid line in config file: "'..line..'"')
            else
                set_value(key, value)
            end
        end
    end

    file:close()
end

-- loading values from user-data.json
-- uses JSON syntax
local function setup_json()
    local file = io.open(json_config_file, 'r')
    if not file then
        msg.debug('could not read', json_config_file)
        return
    end

    msg.debug('reading values from', json_config_file)

    local json, err = utils.parse_json(file:read("*a"))
    if err then
        msg.error(err, 'failed to parse JSON file', json_config_file)
        msg.warn('check the syntax!')
    elseif type(json) ~= 'table' then
        msg.warn(json_config_file)
        msg.error('json file must be a an object')
    else
        for key, value in pairs(json) do
            set_value_native(key, value)
        end
    end
end

-- detects changes to the script-opts property that requires `user-data` updates
local function main(_, opts)
    local current_overrides = {}

    -- Finds any user-data value overrides in `script-opts`.
    for key, value in pairs(opts) do
        if string.find(key, '^user%-data/.') then
            local succeeds, vars = set_value(string.match(key, '^user%-data/(.+)') or '', value)

            if succeeds and vars then
                current_overrides[vars.key] = true

                if not overrides[vars.key] then
                    overrides[vars.key] = true
                    prev_values[vars.key] = vars.prev_value
                end
            end
        end
    end

    -- If any values have been removed from script-opts we want to reset them to the original values.
    -- This is to add synergy with conditional auto profiles.
    for key in pairs(overrides) do
        if not current_overrides[key] then
            local prev_value = prev_values[key]
            if prev_value then
                msg.verbose('setting', key, utils.to_string(prev_value))
                mp.set_property_native(key, prev_value)
            else
                msg.verbose('deleting', key)
                mp.del_property(key)
            end
            overrides[key] = nil
            prev_values[key] = nil
        end
    end
end

-- Loading initial user-data values from config files
local function setup()
    msg.debug('reading initial values from config files')
    setup_json()
    setup_config()
end

setup()
mp.observe_property('script-opts', 'native', main)
