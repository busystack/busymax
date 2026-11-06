"""Authenticated local Radicale health check; never prints credentials."""
import base64
import json
import pathlib
import urllib.request

password = json.loads(pathlib.Path('/fixtures/.runtime/credentials.json').read_text())['alice']
request = urllib.request.Request('http://127.0.0.1:5232/', method='PROPFIND',
    data=b'<d:propfind xmlns:d="DAV:"><d:prop><d:current-user-principal/></d:prop></d:propfind>',
    headers={'Depth': '0', 'Authorization': 'Basic ' + base64.b64encode(('alice:' + password).encode()).decode()})
with urllib.request.urlopen(request, timeout=5) as response:
    assert response.status == 207 and b'current-user-principal' in response.read()
