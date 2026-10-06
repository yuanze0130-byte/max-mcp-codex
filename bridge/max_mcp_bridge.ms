/*
   Max MCP Codex bridge.

   The listener is polled by a WinForms timer on Max's main thread. This keeps
   pymxs/MaxScript scene edits on the thread Max owns and works across the
   Python changes between Max 2022-2027. The bridge is localhost-only.
*/

global mcp_listener = undefined
global mcp_timer = undefined
global mcp_client = undefined
global mcp_buffer = ""
global mcp_json = undefined
global mcp_regex = undefined
global mcp_token = ""
global mcp_port = 9766
global mcp_scene_seq = 0
global mcp_timer_handler = undefined

fn mcp_now = ((dotNetClass "System.DateTime").UtcNow.ToString "o")

fn mcp_has_key obj key = (
    try (obj.ContainsKey key) catch (false)
)

fn mcp_get obj key fallback = (
    if obj == undefined then fallback
    else if (mcp_has_key obj key) then obj.Item[key]
    else fallback
)

fn mcp_num obj fallback = (
    if obj == undefined then fallback else (obj as float)
)

fn mcp_text obj fallback = (
    if obj == undefined then fallback else (obj as string)
)

fn mcp_hash = (dotNetObject "System.Collections.Hashtable")

fn mcp_put h key value = (
    if h.ContainsKey key then h.Item[key] = value else h.Add key value
    h
)

fn mcp_ok id result = (
    local h = mcp_hash()
    mcp_put h "jsonrpc" "2.0"
    mcp_put h "id" id
    mcp_put h "result" result
)

fn mcp_error id code message data:undefined = (
    local e = mcp_hash()
    mcp_put e "code" code
    mcp_put e "message" message
    if data != undefined do (mcp_put e "data" data)
    local h = mcp_hash()
    mcp_put h "jsonrpc" "2.0"
    mcp_put h "id" id
    mcp_put h "error" e
)

fn mcp_capabilities = #(
    "host.status", "scene.summary", "scene.verify",
    "object.create_box", "object.create_cylinder", "object.create_mesh",
    "object.transform", "object.delete"
)

fn mcp_status = (
    local h = mcp_hash()
    mcp_put h "ok" true
    mcp_put h "bridge_version" "0.2.0"
    mcp_put h "max_version" ((maxVersion())[1] as string)
    mcp_put h "max_product_version" ((maxVersion())[1] as string)
    mcp_put h "scene_seq" mcp_scene_seq
    mcp_put h "port" mcp_port
    mcp_put h "auth_enabled" (mcp_token != "")
    mcp_put h "capabilities" (mcp_capabilities())
    mcp_put h "current_file" (maxFilePath + maxFileName)
)

fn mcp_scene_summary = (
    local names = #()
    for n in geometry do (if names.count < 200 do append names n.name)
    local selected = #()
    for n in selection do append selected n.name
    local h = mcp_hash()
    mcp_put h "ok" true
    mcp_put h "scene_seq" mcp_scene_seq
    mcp_put h "object_count" objects.count
    mcp_put h "geometry_count" geometry.count
    mcp_put h "helper_count" helpers.count
    mcp_put h "camera_count" cameras.count
    mcp_put h "light_count" lights.count
    mcp_put h "names" names
    mcp_put h "selection" selected
    mcp_put h "current_file" (maxFilePath + maxFileName)
)

fn mcp_verify_scene = (
    local duplicate_names = #()
    local seen = dotNetObject "System.Collections.Hashtable"
    for n in objects do (
        if seen.ContainsKey n.name then append duplicate_names n.name
        else seen.Add n.name true
    )
    local h = mcp_hash()
    mcp_put h "ok" (duplicate_names.count == 0)
    mcp_put h "scene_seq" mcp_scene_seq
    mcp_put h "duplicate_names" duplicate_names
    mcp_put h "object_count" objects.count
)

fn mcp_node_ref n = (
    local h = mcp_hash()
    mcp_put h "name" n.name
    mcp_put h "handle" ((getHandleByAnim n) as string)
    mcp_put h "class" ((classOf n) as string)
    h
)

fn mcp_scene_guard id params = (
    local expected = mcp_get params "expected_scene_seq" undefined
    if expected == undefined then true
    else if ((mcp_num expected -1.0) as integer) == mcp_scene_seq then true
    else (
        false
    )
)

fn mcp_scene_guard_error id params = (
    local expected = mcp_get params "expected_scene_seq" undefined
    local data = mcp_hash()
    mcp_put data "expected_scene_seq" ((mcp_num expected -1.0) as integer)
    mcp_put data "actual_scene_seq" mcp_scene_seq
    mcp_error id "stale_scene" "The scene changed after the request was planned." data:data
)

fn mcp_create_box id params = (
    local name = mcp_text (mcp_get params "name" undefined) "MCP_Box"
    local width = mcp_num (mcp_get params "width" undefined) 100.0
    local length = mcp_num (mcp_get params "length" undefined) 100.0
    local height = mcp_num (mcp_get params "height" undefined) 100.0
    local dry_run = (mcp_get params "dry_run" false) == true
    if not (mcp_scene_guard id params) then return (mcp_scene_guard_error id params)
    if width <= 0 or length <= 0 or height <= 0 then
        return mcp_error id "invalid_dimensions" "Box dimensions must be greater than zero."
    local p = mcp_get params "position" #(0.0, 0.0, 0.0)
    local pos = point3 (mcp_num p[1] 0.0) (mcp_num p[2] 0.0) (mcp_num p[3] 0.0)
    if dry_run then (
        local plan = mcp_hash()
        mcp_put plan "ok" true
        mcp_put plan "dry_run" true
        mcp_put plan "operation" "object.create_box"
        mcp_put plan "name" name
        mcp_put plan "dimensions" #(width, length, height)
        mcp_put plan "position" #(pos.x, pos.y, pos.z)
        return mcp_ok id plan
    )
    if (getNodeByName name exact:true) != undefined then
        return mcp_error id "name_conflict" ("An object named '" + name + "' already exists.")
    local node = undefined
    undo "MCP create box" on (
        node = box name:name width:width length:length height:height pos:pos
        mcp_scene_seq += 1
    )
    local result = mcp_hash()
    mcp_put result "ok" true
    mcp_put result "scene_seq" mcp_scene_seq
    mcp_put result "node" (mcp_node_ref node)
    mcp_put result "position" #(node.position.x, node.position.y, node.position.z)
    mcp_put result "dimensions" #(width, length, height)
    mcp_ok id result
)

fn mcp_create_cylinder id params = (
    local name = mcp_text (mcp_get params "name" undefined) "MCP_Cylinder"
    local radius = mcp_num (mcp_get params "radius" undefined) 50.0
    local height = mcp_num (mcp_get params "height" undefined) 100.0
    local segments = (mcp_num (mcp_get params "segments" undefined) 32.0) as integer
    local dry_run = (mcp_get params "dry_run" false) == true
    if not (mcp_scene_guard id params) then return (mcp_scene_guard_error id params)
    if radius <= 0 or height <= 0 or segments < 3 then
        return mcp_error id "invalid_dimensions" "Cylinder radius/height must be positive and segments must be at least 3."
    local p = mcp_get params "position" #(0.0, 0.0, 0.0)
    local pos = point3 (mcp_num p[1] 0.0) (mcp_num p[2] 0.0) (mcp_num p[3] 0.0)
    if dry_run then (
        local plan = mcp_hash()
        mcp_put plan "ok" true
        mcp_put plan "dry_run" true
        mcp_put plan "operation" "object.create_cylinder"
        mcp_put plan "name" name
        mcp_put plan "radius" radius
        mcp_put plan "height" height
        mcp_put plan "segments" segments
        mcp_put plan "position" #(pos.x, pos.y, pos.z)
        return mcp_ok id plan
    )
    if (getNodeByName name exact:true) != undefined then
        return mcp_error id "name_conflict" ("An object named '" + name + "' already exists.")
    local node = undefined
    undo "MCP create cylinder" on (
        node = cylinder name:name radius:radius height:height sides:segments pos:pos
        mcp_scene_seq += 1
    )
    local result = mcp_hash()
    mcp_put result "ok" true
    mcp_put result "scene_seq" mcp_scene_seq
    mcp_put result "node" (mcp_node_ref node)
    mcp_put result "position" #(node.position.x, node.position.y, node.position.z)
    mcp_put result "radius" radius
    mcp_put result "height" height
    mcp_put result "segments" segments
    mcp_ok id result
)

fn mcp_create_mesh id params = (
    local name = mcp_text (mcp_get params "name" undefined) "MCP_Mesh"
    local raw_vertices = mcp_get params "vertices" undefined
    local raw_faces = mcp_get params "faces" undefined
    local dry_run = (mcp_get params "dry_run" false) == true
    if not (mcp_scene_guard id params) then return (mcp_scene_guard_error id params)
    if raw_vertices == undefined or raw_faces == undefined then
        return mcp_error id "invalid_mesh" "vertices and faces are required."
    local vertices = #()
    for item in raw_vertices do (
        if item == undefined or item.count != 3 then
            return mcp_error id "invalid_mesh" "Every vertex must contain three numbers."
        append vertices (point3 (mcp_num item[1] 0.0) (mcp_num item[2] 0.0) (mcp_num item[3] 0.0))
    )
    local faces = #()
    for item in raw_faces do (
        if item == undefined or item.count != 3 then
            return mcp_error id "invalid_mesh" "Only triangular faces are supported."
        local a = (mcp_num item[1] 0.0) as integer
        local b = (mcp_num item[2] 0.0) as integer
        local c = (mcp_num item[3] 0.0) as integer
        if a < 1 or b < 1 or c < 1 or a > vertices.count or b > vertices.count or c > vertices.count then
            return mcp_error id "invalid_mesh" "Face indices must reference a vertex using 1-based indices."
        append faces (point3 a b c)
    )
    if vertices.count < 3 or faces.count < 1 then
        return mcp_error id "invalid_mesh" "A mesh needs at least three vertices and one face."
    if dry_run then (
        local plan = mcp_hash()
        mcp_put plan "ok" true
        mcp_put plan "dry_run" true
        mcp_put plan "operation" "object.create_mesh"
        mcp_put plan "name" name
        mcp_put plan "vertex_count" vertices.count
        mcp_put plan "face_count" faces.count
        return mcp_ok id plan
    )
    if (getNodeByName name exact:true) != undefined then
        return mcp_error id "name_conflict" ("An object named '" + name + "' already exists.")
    local p = mcp_get params "position" #(0.0, 0.0, 0.0)
    local pos = point3 (mcp_num p[1] 0.0) (mcp_num p[2] 0.0) (mcp_num p[3] 0.0)
    local node = undefined
    undo "MCP create mesh" on (
        node = mesh name:name vertices:vertices faces:faces
        node.position = pos
        update node
        mcp_scene_seq += 1
    )
    local result = mcp_hash()
    mcp_put result "ok" true
    mcp_put result "scene_seq" mcp_scene_seq
    mcp_put result "node" (mcp_node_ref node)
    mcp_put result "vertex_count" vertices.count
    mcp_put result "face_count" faces.count
    mcp_put result "position" #(node.position.x, node.position.y, node.position.z)
    mcp_ok id result
)

fn mcp_transform_object id params = (
    local name = mcp_text (mcp_get params "name" undefined) ""
    local node = getNodeByName name exact:true
    if node == undefined then return mcp_error id "not_found" ("Object not found: " + name)
    local dry_run = (mcp_get params "dry_run" false) == true
    local position = mcp_get params "position" undefined
    local rotation = mcp_get params "rotation_degrees" undefined
    if not (mcp_scene_guard id params) then return (mcp_scene_guard_error id params)
    if position == undefined and rotation == undefined then
        return mcp_error id "invalid_transform" "Provide position or rotation_degrees."
    if dry_run then (
        local plan = mcp_hash()
        mcp_put plan "ok" true
        mcp_put plan "dry_run" true
        mcp_put plan "operation" "object.transform"
        mcp_put plan "name" name
        return mcp_ok id plan
    )
    undo "MCP transform object" on (
        if position != undefined do node.position = point3 (mcp_num position[1] node.position.x) (mcp_num position[2] node.position.y) (mcp_num position[3] node.position.z)
        if rotation != undefined do (
            local current = node.rotation as eulerangles
            node.rotation = eulerangles (mcp_num rotation[1] current.x) (mcp_num rotation[2] current.y) (mcp_num rotation[3] current.z)
        )
        mcp_scene_seq += 1
    )
    local result = mcp_hash()
    mcp_put result "ok" true
    mcp_put result "scene_seq" mcp_scene_seq
    mcp_put result "node" (mcp_node_ref node)
    mcp_put result "position" #(node.position.x, node.position.y, node.position.z)
    local current_rotation = node.rotation as eulerangles
    mcp_put result "rotation_degrees" #(current_rotation.x, current_rotation.y, current_rotation.z)
    mcp_ok id result
)

fn mcp_delete_object id params = (
    local name = mcp_text (mcp_get params "name" undefined) ""
    local node = getNodeByName name exact:true
    if node == undefined then return mcp_error id "not_found" ("Object not found: " + name)
    local dry_run = (mcp_get params "dry_run" false) == true
    if not (mcp_scene_guard id params) then return (mcp_scene_guard_error id params)
    if dry_run then (
        local plan = mcp_hash()
        mcp_put plan "ok" true
        mcp_put plan "dry_run" true
        mcp_put plan "operation" "object.delete"
        mcp_put plan "name" name
        return mcp_ok id plan
    )
    undo "MCP delete object" on (
        delete node
        mcp_scene_seq += 1
    )
    local result = mcp_hash()
    mcp_put result "ok" true
    mcp_put result "scene_seq" mcp_scene_seq
    mcp_put result "name" name
    mcp_ok id result
)

fn mcp_dispatch request = (
    local id = mcp_get request "id" undefined
    local method = mcp_text (mcp_get request "method" undefined) ""
    local params = mcp_get request "params" (mcp_hash())
    try (
        case method of (
            "host.status": mcp_ok id (mcp_status())
            "scene.summary": mcp_ok id (mcp_scene_summary())
            "scene.verify": mcp_ok id (mcp_verify_scene())
            "object.create_box": mcp_create_box id params
            "object.create_cylinder": mcp_create_cylinder id params
            "object.create_mesh": mcp_create_mesh id params
            "object.transform": mcp_transform_object id params
            "object.delete": mcp_delete_object id params
            default: mcp_error id "method_not_found" ("Unknown method: " + method)
        )
    ) catch (
        mcp_error id "maxscript_error" (getCurrentException() as string)
    )
)

fn mcp_response_bytes response = (
    local text = mcp_json.SerializeObject response
    local encoding = dotNetClass "System.Text.Encoding"
    encoding.UTF8.GetBytes text
)

fn mcp_header_value headers key = (
    local regex = dotNetObject "System.Text.RegularExpressions.Regex" (key + ": *([^\\r\\n]+)") ((dotNetClass "System.Text.RegularExpressions.RegexOptions").IgnoreCase)
    local match = regex.Match headers
    if match.Success then match.Groups.Item[1].Value else ""
)

fn mcp_send client response = (
    local stream = client.GetStream()
    local bytes = mcp_response_bytes response
    local header = "HTTP/1.1 200 OK\r\nContent-Type: application/json; charset=utf-8\r\nContent-Length: " + (bytes.Length as string) + "\r\nConnection: close\r\n\r\n"
    local encoding = dotNetClass "System.Text.Encoding"
    local headerBytes = encoding.ASCII.GetBytes header
    stream.Write headerBytes 0 headerBytes.Length
    stream.Write bytes 0 bytes.Length
    stream.Flush()
    stream.Close()
    client.Close()
)

fn mcp_process_client = (
    if mcp_client == undefined then (
        if mcp_listener.Pending() do (
            mcp_client = mcp_listener.AcceptTcpClient()
            mcp_buffer = ""
        )
    )
    if mcp_client == undefined then return false
    local stream = mcp_client.GetStream()
    if not stream.DataAvailable then return false
    local buffer = dotNetObject "System.Byte[]" 16384
    local count = stream.Read buffer 0 buffer.Length
    if count <= 0 then return false
    local encoding = dotNetClass "System.Text.Encoding"
    mcp_buffer += encoding.UTF8.GetString buffer 0 count
    local headerEnd = findString mcp_buffer "\r\n\r\n"
    if headerEnd == undefined then return false
    local headers = substring mcp_buffer 1 (headerEnd - 1)
    local lengthText = mcp_header_value headers "Content-Length"
    local length = if lengthText == "" then 0 else (lengthText as integer)
    local bodyStart = headerEnd + 4
    if mcp_buffer.count < (bodyStart - 1 + length) then return false
    local body = if length > 0 then substring mcp_buffer bodyStart length else "{}"
    local request = mcp_json.DeserializeObject body
    local auth = mcp_header_value headers "X-MCP-Token"
    local response = if mcp_token != "" and auth != mcp_token then mcp_error undefined "unauthorized" "Invalid X-MCP-Token." else mcp_dispatch request
    mcp_send mcp_client response
    mcp_client = undefined
    mcp_buffer = ""
    true
)

fn mcp_tick sender args = (
    try (mcp_process_client()) catch (
        if mcp_client != undefined do (try (mcp_client.Close()) catch())
        mcp_client = undefined
        mcp_buffer = ""
    )
)

fn mcp_start port:9766 = (
    if mcp_timer != undefined do mcp_stop()
    mcp_json = dotNetClass "Newtonsoft.Json.JsonConvert"
    mcp_token = (dotNetClass "System.Environment").GetEnvironmentVariable "MAX_MCP_TOKEN"
    if mcp_token == undefined then mcp_token = ""
    mcp_port = port
    local ip = (dotNetClass "System.Net.IPAddress").Parse "127.0.0.1"
    mcp_listener = dotNetObject "System.Net.Sockets.TcpListener" ip port
    mcp_listener.Start()
    mcp_timer = dotNetObject "System.Windows.Forms.Timer"
    mcp_timer.Interval = 50
    mcp_timer_handler = dotNet.addEventHandler mcp_timer "Tick" mcp_tick
    mcp_timer.Start()
    mcp_status()
)

fn mcp_stop = (
    if mcp_timer != undefined do (try (mcp_timer.Stop()) catch())
    if mcp_timer_handler != undefined do (try (dotNet.removeEventHandler mcp_timer "Tick" mcp_timer_handler) catch())
    if mcp_client != undefined do (try (mcp_client.Close()) catch())
    if mcp_listener != undefined do (try (mcp_listener.Stop()) catch())
    mcp_timer = undefined
    mcp_timer_handler = undefined
    mcp_client = undefined
    mcp_listener = undefined
    mcp_buffer = ""
    true
)
