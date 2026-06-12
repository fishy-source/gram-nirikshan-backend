import subprocess
import sys
import os
import time

# Create uploads directory if it doesn't exist
os.makedirs("uploads", exist_ok=True)

print("Starting production app wrapper...", flush=True)

# Run the main app module
res = subprocess.run([sys.executable, "-m", "app.main"], capture_output=True, text=True)

if res.returncode != 0:
    err_report = f"APP CRASHED WITH EXIT CODE {res.returncode}\n\nSTDOUT:\n{res.stdout}\n\nSTDERR:\n{res.stderr}"
    
    # Write the error report to static uploads folder
    with open("uploads/startup_error.txt", "w", encoding="utf-8") as f:
        f.write(err_report)
    
    port = int(os.getenv("PORT", 8000))
    print(f"Wrapper: App crashed. Starting dummy server on port {port} to serve traceback...", file=sys.stderr)
    
    import http.server
    import socketserver
    
    class FallbackHandler(http.server.SimpleHTTPRequestHandler):
        def do_GET(self):
            # Respond to any request with the error report
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.end_headers()
            with open("uploads/startup_error.txt", "rb") as f:
                self.wfile.write(f.read())
                
    socketserver.TCPServer.allow_reuse_address = True
    try:
        with socketserver.TCPServer(("", port), FallbackHandler) as httpd:
            httpd.serve_forever()
    except Exception as e:
        print(f"Failed to start fallback server: {e}", file=sys.stderr)
        time.sleep(3600)
else:
    print("App exited normally with code 0.", flush=True)
