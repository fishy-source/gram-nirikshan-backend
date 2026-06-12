import subprocess
import sys
import time

# We try to import httpx. If it's not installed, we can still print to stderr.
try:
    import httpx
    has_httpx = True
except ImportError:
    has_httpx = False

def report(message):
    print(message, file=sys.stderr)
    if has_httpx:
        try:
            httpx.post("https://ntfy.sh/rakesh_nirikshan_debug_final", content=message, timeout=10)
        except Exception as e:
            print(f"Failed to post to ntfy: {e}", file=sys.stderr)

report("Production wrapper starting...")

# Run the app.main module
res = subprocess.run([sys.executable, "-m", "app.main"], capture_output=True, text=True)

if res.returncode != 0:
    err_report = f"APP CRASHED WITH EXIT CODE {res.returncode}\n\nSTDOUT:\n{res.stdout[-2000:]}\n\nSTDERR:\n{res.stderr[-2000:]}"
    report(err_report)
    # Sleep to keep the container alive on Railway
    time.sleep(3600)
else:
    report("App exited normally with code 0.")
