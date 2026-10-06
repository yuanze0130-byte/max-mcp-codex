try (
    local f = createFile "C:/Temp/max_mcp_probe.txt"
    local j = dotNetClass "Newtonsoft.Json.JsonConvert"
    local payload = j.DeserializeObject "{\"method\":\"host.status\",\"params\":{}}"
    format "maxVersion=%\n" ((maxVersion())[1] as string) to:f
    format "json=%\n" (payload.GetType().FullName as string) to:f
    close f
) catch (e) (
    local f = createFile "C:/Temp/max_mcp_probe.txt"
    format "ERROR=%\n" (e as string) to:f
    close f
)
