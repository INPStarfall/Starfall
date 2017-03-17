if SERVER then
    local P = SF.Permissions

    P.useMysqloo = false
    P.host = "127.0.0.1"
    P.port = 3306
    P.user = "starfall"
    P.pass = "password"
    P.dbName = "starfall"
    P.table = "sf_permissions"
end