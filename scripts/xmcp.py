import json, os, socket, subprocess, sys, tempfile, threading

SOCK = os.environ.get("XMCP_SOCK", "/tmp/xmcp-%d.sock" % os.getuid())
OUT_DIR = os.environ.get("XMCP_OUT", tempfile.gettempdir())


def serve():
    proc = subprocess.Popen(["xcrun", "mcpbridge"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, bufsize=1)
    lock = threading.Lock()
    counter = [100]

    def rpc(method, params, notify=False):
        message = {"jsonrpc": "2.0", "method": method, "params": params}
        if not notify:
            counter[0] += 1
            message["id"] = counter[0]
        proc.stdin.write(json.dumps(message) + "\n")
        proc.stdin.flush()
        if notify:
            return None
        while True:
            line = proc.stdout.readline()
            if not line:
                return {"error": "bridge closed"}
            try:
                reply = json.loads(line)
            except ValueError:
                continue
            if reply.get("id") == message["id"]:
                return reply

    rpc("initialize", {"protocolVersion": "2025-06-18", "capabilities": {}, "clientInfo": {"name": "claude-xmcp", "version": "1"}})
    rpc("notifications/initialized", {}, notify=True)
    if os.path.exists(SOCK):
        os.remove(SOCK)
    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.bind(SOCK)
    server.listen(1)
    while True:
        conn, _ = server.accept()
        data = b""
        while not data.endswith(b"\n"):
            chunk = conn.recv(65536)
            if not chunk:
                break
            data += chunk
        request = json.loads(data.decode())
        with lock:
            if request.get("method") == "list":
                reply = rpc("tools/list", {})
            else:
                reply = rpc("tools/call", {"name": request["name"], "arguments": request.get("arguments", {})})
        try:
            conn.sendall((json.dumps(reply) + "\n").encode())
        except OSError:
            pass
        conn.close()


def call(name, arguments):
    client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    client.connect(SOCK)
    client.sendall((json.dumps({"name": name, "arguments": arguments}) + "\n").encode())
    data = b""
    while True:
        chunk = client.recv(1 << 20)
        if not chunk:
            break
        data += chunk
    reply = json.loads(data.decode())
    result = reply.get("result", reply)
    for item in result.get("content", []) if isinstance(result, dict) else []:
        if item.get("type") == "text":
            print(item["text"])
        elif item.get("type") == "image":
            import base64
            out = os.path.join(OUT_DIR, "xmcp-last.png")
            open(out, "wb").write(base64.b64decode(item["data"]))
            print("IMAGE saved", out)
        else:
            print(json.dumps(item)[:2000])
    if isinstance(result, dict) and "structuredContent" in result:
        print(json.dumps(result["structuredContent"])[:6000])
    if "error" in reply:
        print("ERROR", reply["error"])


def tools():
    client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    client.connect(SOCK)
    client.sendall((json.dumps({"method": "list"}) + "\n").encode())
    data = b""
    while True:
        chunk = client.recv(1 << 20)
        if not chunk:
            break
        data += chunk
    for tool in json.loads(data.decode())["result"]["tools"]:
        print(tool["name"])


def schema(name):
    client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    client.connect(SOCK)
    client.sendall((json.dumps({"method": "list"}) + "\n").encode())
    data = b""
    while True:
        chunk = client.recv(1 << 20)
        if not chunk:
            break
        data += chunk
    for tool in json.loads(data.decode())["result"]["tools"]:
        if tool["name"] == name:
            print(tool["description"])
            print(json.dumps(tool["inputSchema"], indent=1))


if __name__ == "__main__":
    if sys.argv[1] == "serve":
        serve()
    elif sys.argv[1] == "tools":
        tools()
    elif sys.argv[1] == "schema":
        schema(sys.argv[2])
    else:
        arguments = json.loads(sys.argv[2]) if len(sys.argv) > 2 else {}
        call(sys.argv[1], arguments)
