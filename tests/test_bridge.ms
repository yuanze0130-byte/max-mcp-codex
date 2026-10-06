fileIn (((dotNetClass "System.Environment").GetEnvironmentVariable "MAX_MCP_CODEX_ROOT" as string) + "/bridge/max_mcp_bridge.ms")

fn run_smoke = (
local test_dir = ((dotNetClass "System.Environment").GetEnvironmentVariable "MAX_MCP_CODEX_ROOT" as string) + "/tests/"
resetMaxFile #noPrompt
local json = dotNetClass "Newtonsoft.Json.JsonConvert"
local out = createFile (test_dir + "max_mcp_bridge_test.jsonl")
local statusReq = dotNetObject "System.Collections.Hashtable"
statusReq.Add "jsonrpc" "2.0"
statusReq.Add "id" 1
statusReq.Add "method" "host.status"
statusReq.Add "params" (dotNetObject "System.Collections.Hashtable")
format "%\n" (json.SerializeObject (mcp_dispatch statusReq)) to:out
local boxReq = dotNetObject "System.Collections.Hashtable"
boxReq.Add "jsonrpc" "2.0"
boxReq.Add "id" 2
boxReq.Add "method" "object.create_box"
local boxParams = dotNetObject "System.Collections.Hashtable"
boxParams.Add "name" "CodexSmokeBox"
boxParams.Add "width" 20.0
boxParams.Add "length" 30.0
boxParams.Add "height" 40.0
boxParams.Add "position" #(1.0, 2.0, 3.0)
boxParams.Add "dry_run" false
boxReq.Add "params" boxParams
format "%\n" (json.SerializeObject (mcp_dispatch boxReq)) to:out
local meshReq = dotNetObject "System.Collections.Hashtable"
meshReq.Add "jsonrpc" "2.0"
meshReq.Add "id" 7
meshReq.Add "method" "object.create_mesh"
local meshParams = dotNetObject "System.Collections.Hashtable"
meshParams.Add "name" "CodexSmokeMesh"
meshParams.Add "vertices" #(#(-10.0, -10.0, 0.0), #(10.0, -10.0, 0.0), #(10.0, 10.0, 0.0), #(-10.0, 10.0, 0.0), #(0.0, 0.0, 20.0))
meshParams.Add "faces" #(#(1, 2, 5), #(2, 3, 5), #(3, 4, 5), #(4, 1, 5))
meshParams.Add "position" #(100.0, 200.0, 0.0)
meshReq.Add "params" meshParams
format "%\n" (json.SerializeObject (mcp_dispatch meshReq)) to:out
local staleReq = dotNetObject "System.Collections.Hashtable"
staleReq.Add "jsonrpc" "2.0"
staleReq.Add "id" 8
staleReq.Add "method" "object.transform"
local staleParams = dotNetObject "System.Collections.Hashtable"
staleParams.Add "name" "CodexSmokeBox"
staleParams.Add "position" #(99.0, 99.0, 99.0)
staleParams.Add "expected_scene_seq" 0
staleReq.Add "params" staleParams
format "%\n" (json.SerializeObject (mcp_dispatch staleReq)) to:out
local transformReq = dotNetObject "System.Collections.Hashtable"
transformReq.Add "jsonrpc" "2.0"
transformReq.Add "id" 3
transformReq.Add "method" "object.transform"
local transformParams = dotNetObject "System.Collections.Hashtable"
transformParams.Add "name" "CodexSmokeBox"
transformParams.Add "position" #(10.0, 20.0, 30.0)
transformReq.Add "params" transformParams
format "%\n" (json.SerializeObject (mcp_dispatch transformReq)) to:out
local verifyReq = dotNetObject "System.Collections.Hashtable"
verifyReq.Add "jsonrpc" "2.0"
verifyReq.Add "id" 4
verifyReq.Add "method" "scene.verify"
verifyReq.Add "params" (dotNetObject "System.Collections.Hashtable")
format "%\n" (json.SerializeObject (mcp_dispatch verifyReq)) to:out
local cylinderReq = dotNetObject "System.Collections.Hashtable"
cylinderReq.Add "jsonrpc" "2.0"
cylinderReq.Add "id" 5
cylinderReq.Add "method" "object.create_cylinder"
local cylinderParams = dotNetObject "System.Collections.Hashtable"
cylinderParams.Add "name" "CodexSmokeCylinder"
cylinderParams.Add "radius" 10.0
cylinderParams.Add "height" 25.0
cylinderParams.Add "segments" 16
cylinderParams.Add "position" #(0.0, 0.0, 12.5)
cylinderReq.Add "params" cylinderParams
format "%\n" (json.SerializeObject (mcp_dispatch cylinderReq)) to:out
local deleteReq = dotNetObject "System.Collections.Hashtable"
deleteReq.Add "jsonrpc" "2.0"
deleteReq.Add "id" 6
deleteReq.Add "method" "object.delete"
local deleteParams = dotNetObject "System.Collections.Hashtable"
deleteParams.Add "name" "CodexSmokeCylinder"
deleteReq.Add "params" deleteParams
format "%\n" (json.SerializeObject (mcp_dispatch deleteReq)) to:out
format "%\n" (json.SerializeObject (mcp_dispatch verifyReq)) to:out
close out
saveMaxFile (test_dir + "max_mcp_bridge_smoke.max")
quitMax #noPrompt
)
run_smoke()
