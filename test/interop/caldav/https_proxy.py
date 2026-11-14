#!/usr/bin/env python3
"""Isolated TLS terminator; upstream Radicale/Baikal remain unmodified."""
import http.client
import http.server
import json
import pathlib
import ssl
import threading

RUNTIME = pathlib.Path('/fixtures/.runtime')


def serve(port, upstream, prefix='', untrusted=False):
    class Handler(http.server.BaseHTTPRequestHandler):
        protocol_version = 'HTTP/1.1'

        def proxy(self):
            length = int(self.headers.get('Content-Length', '0'))
            if length > 20 * 1024 * 1024:
                self.close_connection = True
                self.send_error(413)
                return
            # A redirect must consume this request body before a keep-alive
            # connection can receive the client's redirected PROPFIND.
            payload = self.rfile.read(length)
            if self.path == '/.well-known/caldav' and port == 18448:
                # The origin's proxy owns well-known routing for both released
                # root and configured servlet-subpath deployments.
                settings = dict(line.split('=', 1) for line in
                                (RUNTIME / 'busystack-qa.env').read_text().splitlines() if '=' in line)
                public = settings['BUSYSTACK_PUBLIC_BASE_URL']
                if public not in ('https://localhost:18448', 'https://localhost:18448/calendar'):
                    self.send_error(500)
                    return
                self.send_response(302)
                self.send_header('Location', public + '/dav/')
                self.send_header('Content-Length', '0')
                self.end_headers()
                return
            if self.path == '/.well-known/caldav' and port in (18444, 18447):
                # The HTTPS origin owns well-known routing. The plain HTTP
                # Apache upstream cannot construct the TLS terminator's scheme.
                endpoint = '/dav.php/' if port == 18444 else '/baikal/dav.php/'
                self.send_response(302)
                self.send_header('Location', f'https://localhost:{port}{endpoint}')
                self.send_header('Content-Length', '0')
                self.end_headers()
                return
            if self.path == '/security/cross-origin':
                self.send_response(302)
                destination = 'https://localhost:18444/dav.php/' if port != 18444 else 'https://localhost:18443/'
                self.send_header('Location', destination)
                self.send_header('Content-Length', '0')
                self.end_headers()
                return
            if self.path == '/security/downgrade':
                self.send_response(302)
                self.send_header('Location', 'http://localhost:18532/')
                self.send_header('Content-Length', '0')
                self.end_headers()
                return
            path = self.path
            headers = {key: value for key, value in self.headers.items()
                       if key.lower() not in ('connection', 'host', 'transfer-encoding')}
            headers['Host'] = self.headers.get('Host', 'localhost')
            headers['X-Forwarded-Proto'] = 'https'
            if prefix and path.startswith(prefix + '/'):
                path = path[len(prefix):]
                headers['X-Script-Name'] = prefix
            connection = http.client.HTTPConnection(upstream, timeout=30)
            try:
                connection.request(self.command, path, payload, headers)
                response = connection.getresponse()
                body = response.read()
                self.send_response(response.status)
                for key, value in response.getheaders():
                    if key.lower() not in ('connection', 'transfer-encoding', 'content-length'):
                        self.send_header(key, value)
                self.send_header('Content-Length', str(len(body)))
                self.end_headers()
                self.wfile.write(body)
            finally:
                connection.close()

        do_GET = do_HEAD = do_OPTIONS = do_PROPFIND = do_REPORT = proxy
        do_PUT = do_DELETE = do_MKCALENDAR = do_MKCOL = do_PROPPATCH = do_MOVE = proxy
        do_POST = proxy

        def log_message(self, fmt, *args):
            # No headers, request bodies, URLs or credentials in diagnostics.
            pass

    server = http.server.ThreadingHTTPServer(('0.0.0.0', port), Handler)
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    kind = 'untrusted' if untrusted else 'server'
    context.load_cert_chain(RUNTIME / f'{kind}.pem', RUNTIME / f'{kind}.key')
    server.socket = context.wrap_socket(server.socket, server_side=True)
    server.serve_forever()


if __name__ == '__main__':
    threads = []
    for args in [(18443, 'radicale:5232'), (18444, 'baikal:80'),
                 (18445, 'radicale:5232', '/installation'),
                 (18446, 'radicale:5232', '', True),
                 (18447, 'baikal-path:80')]:
        thread = threading.Thread(target=serve, args=args)
        thread.start()
        threads.append(thread)
    for thread in threads:
        thread.join()
