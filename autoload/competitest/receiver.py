# File: receiver.py
# Author: mao-yining <mao.yining@outlook.com>
# Last Modified: 2025-08-30

# This Python program implements a lightweight HTTP server that receives
# competitive programming problem data via POST requests and relays it to a Vim
# editor through standardized JSON output, acting as a communication bridge
# between online judges and the editing environment.import sys

import json
import sys
from http.server import HTTPServer, BaseHTTPRequestHandler


class CompetitiveHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        try:
            content_length = int(self.headers["Content-Length"])
            post_data = self.rfile.read(content_length)
            data = json.loads(post_data)

            # 通过 stdout 发送给 Vim
            print(json.dumps({"type": "problem", "data": data}), flush=True)

            self.send_response(200)
            self.send_header("Content-type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"status": "ok"}).encode())

        except Exception as e:
            print(json.dumps({"type": "error", "message": str(e)}), flush=True)
            self.send_error(500, str(e))


def main(port):
    try:
        server = HTTPServer(("localhost", port), CompetitiveHandler)
        print(
            json.dumps(
                {"type": "status", "message": f"Receiver started on port {port}."}
            ),
            flush=True,
        )
        server.serve_forever()
    except Exception as e:
        print(
            json.dumps(
                {"type": "error", "message": f"Failed to start receiver: {str(e)}."}
            ),
            flush=True,
        )
        sys.exit(1)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(
            json.dumps({"type": "error", "message": "Port number required"}), flush=True
        )
        sys.exit(1)

    try:
        # port = int(sys.argv[1])
        port = int(sys.argv[1])
        main(port)
    except ValueError:
        print(
            json.dumps({"type": "error", "message": "Invalid port number"}), flush=True
        )
        sys.exit(1)
