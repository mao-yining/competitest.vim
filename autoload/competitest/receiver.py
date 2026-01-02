# File: receiver.py
# Author: Mao-Yining <mao.yining@outlook.com>
# Last Modified: 2026-01-02

# This Python program implements a lightweight HTTP server that receives
# competitive programming problem data via POST requests and relays it to a Vim
# editor through standardized JSON output, acting as a communication bridge
# between online judges and the editing environment.

import json
import sys
from http.server import HTTPServer, BaseHTTPRequestHandler


class CompetitiveHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        try:
            post_data = self.rfile.read(int(self.headers["Content-Length"]))

            json.loads(post_data)  # check data

            sys.stdout.buffer.write(post_data)
            sys.stdout.buffer.write(b"\n")
            sys.stdout.flush()

            self.send_response(200)
            self.send_header("Content-type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"status":"ok"}')

        except Exception as e:
            print(f"Error: {e}", file=sys.stderr)
            self.send_error(500, str(e))

    def log_message(self, format, *args):
        pass  # Disable default access logging to stderr


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python receiver.py <port>", file=sys.stderr)
        sys.exit(1)

    try:
        port = int(sys.argv[1])
    except ValueError:
        print("Error: Port must be a number", file=sys.stderr)
        sys.exit(1)

    try:
        server = HTTPServer(("localhost", port), CompetitiveHandler)
        server.serve_forever()
    except PermissionError:
        print(f"Error: Permission denied for port {port}", file=sys.stderr)
        sys.exit(1)
    except OSError as e:
        print(f"Error: Cannot start server - {e}", file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        print("\nServer shutting down...", file=sys.stderr)
        sys.exit(0)
    except Exception as e:
        print(f"Unexpected error: {e}", file=sys.stderr)
        sys.exit(1)
