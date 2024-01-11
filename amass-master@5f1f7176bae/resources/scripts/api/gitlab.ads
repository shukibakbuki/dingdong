-- Copyright © by Jeff Foley 2017-2023. All rights reserved.
-- Use of this source code is governed by Apache 2 LICENSE that can be found in the LICENSE file.
-- SPDX-License-Identifier: Apache-2.0

local json = require("json")

name = "GitLab"
type = "api"

function start()
    set_rate_limit(1)
end

function check()
    local c
    local cfg = datasrc_config()
    if (cfg ~= nil) then
        c = cfg.credentials
    end

    if (c ~= nil and c.key ~= nil and c.key ~= "") then
        return true
    end
    return false
end

function vertical(ctx, domain)
    local c
    local cfg = datasrc_config()
    if (cfg ~= nil) then
        c = cfg.credentials
    end

    if (c == nil or c.key == nil or c.key == "") then
        return
    end

    local resp, err = request(ctx, {
        ['url']=search_url(domain, scope),
        ['header']={['PRIVATE-TOKEN']=c.key},
    })
    if (err ~= nil and err ~= "") then
        log(ctx, "vertical request to service failed: " .. err)
        return
    elseif (resp.status_code < 200 or resp.status_code >= 400) then
        log(ctx, "vertical request to service returned with status: " .. resp.status)
        return
    end

    local d = json.decode(resp.body)
    if (d == nil) then
        log(ctx, "failed to decode the JSON response")
        return
    end

    for _, item in pairs(d) do
        if (item ~= nil and item.project_id ~= nil and 
            item.path ~= nil and item.ref ~= nil) then
            local ok = scrape(ctx, {
                ['url']=get_file_url(item.project_id, item.path, item.ref),
                ['headers']={['PRIVATE-TOKEN']=c.key},
            })
            if not ok then
                send_names(ctx, item.data)
            end
        end
    end
end

function get_file_url(id, path, ref)
    return "https://gitlab.com/api/v4/projects/" .. id .. "/repository/files/" .. path:gsub("/", "%%2f") .. "/raw?ref=" .. ref
end

function search_url(domain)
    return "https://gitlab.com/api/v4/search?scope=blobs&search=" .. domain
end
