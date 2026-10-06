fn writeProbe line = (
    local f = createFile "E:/xwechat_files/haliboteyuanze_4806/msg/file/2026-09/园区楼栋平面图等18个文件/11/max-mcp-codex/tests/probe_runtime.txt"
    format "%\n" line to:f
    close f
)
try (
    local result = #()
    append result ("maxVersion=" + (maxVersion())[1] as string)
    append result ("dotNet=" + (dotNetClass "System.Net.Sockets.TcpListener" as string))
    append result ("json=" + (dotNetClass "Newtonsoft.Json.JsonConvert" as string))
    append result ("serializer=" + (dotNetClass "System.Web.Script.Serialization.JavaScriptSerializer" as string))
    writeProbe (result as string)
) catch (e) (
    writeProbe ("ERROR=" + (e as string))
)
quitMax #noPrompt
