#!/usr/bin/env python3
import sys
import json
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
