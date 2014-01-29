-------------------------------------------------------------------------------
-- HTTP Library 
-------------------------------------------------------------------------------

--- Deals with HTTP Requests
-- @shared

local http_lib, _ = SF.Libraries.Register( "http" )

local request_delay = CreateConVar( "starfall_http_delay", 1 )
local request_times = {}

function canRequest( ply )
    local request_time = request_times[ply]
    if not request_time then return true end

    if CurTime() > request_time + request_delay:GetInt() then 
        return true
    end

    return false    
end    

--- Runs a HTTP request
-- @param url The url to request
-- @return Page Body or nil
-- @return Length or nil
-- @return Response code
function http_lib.fetch( url )
    if not canRequest( SF.instance.player ) then return end
    request_times[SF.instance.player] = CurTime()

    http.Fetch( url, function( body, len, headers, code ) -- on success
                        SF.RunScriptHook( "http", body, len, code )
                    end,
                    function( code ) -- on failure
                        SF.RunScriptHook( "http", nil, nil, code )
                    end )
end    

--- Checks if a request can be executed
-- @return can request
function http_lib.canRequest()
    return canRequest( SF.instance.player )
end    