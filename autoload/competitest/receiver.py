# File: receiver.py
# Author: Mao-Yining <mao.yining@outlook.com>
# Last Modified: 2025-10-03

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
            content_length = int(self.headers["Content-Length"])
            post_data = self.rfile.read(content_length)
            data = json.loads(post_data)

            # Send problem data to Vim in stdout
            print(json.dumps(data), flush=True)

            self.send_response(200)
            self.send_header("Content-type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"status": "ok"}).encode())

        except Exception as e:
            # Output error messages to stderr
            print(
                f"receiver.py: Error processing request: {str(e)}",
                file=sys.stderr,
                flush=True,
            )
            self.send_error(500, str(e))

    def log_message(self, format, *args):
        # Disable default access logging to stderr
        pass


def main(port):
    server = HTTPServer(("localhost", port), CompetitiveHandler)
    server.serve_forever()


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("receiver.py: Port number required", file=sys.stderr, flush=True)
        sys.exit(1)

    try:
        port = int(sys.argv[1])
        main(port)
    except ValueError:
        print("receiver.py: Invalid port number", file=sys.stderr, flush=True)
        sys.exit(1)
    except Exception as e:
        print(
            f"receiver.py: Failed to start receiver: {str(e)}",
            file=sys.stderr,
            flush=True,
        )
        sys.exit(1)
