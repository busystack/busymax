#!/usr/bin/env python3
"""Change only disposable fixture user data; never modify upstream software."""
import argparse
import hashlib
import json
import pathlib
import secrets
import subprocess

ROOT = pathlib.Path(__file__).resolve().parent
RUNTIME = ROOT / '.runtime'
COMPOSE = ['docker', 'compose', '-f', str(ROOT / 'compose.yaml')]


def password(server, value):
    if server == 'radicale':
        credentials = json.loads((RUNTIME / 'credentials.json').read_text())
        credentials['alice'] = value
        hashes = {user: subprocess.run(['openssl', 'passwd', '-5', '-stdin'],
                  input=secret + '\n', text=True, check=True, capture_output=True).stdout.strip()
                  for user, secret in credentials.items()}
        (RUNTIME / 'users').write_text(''.join(f'{user}:{digest}\n' for user, digest in hashes.items()))
        subprocess.run(COMPOSE + ['restart', 'radicale'], check=True, capture_output=True)
    else:
        digest = hashlib.md5(f'alice:BaikalDAV:{value}'.encode()).hexdigest()
        code = ("$v=json_decode(stream_get_contents(STDIN),true,512,JSON_THROW_ON_ERROR);"
                "$d=new PDO('sqlite:/var/www/baikal/Specific/db/db.sqlite');"
                "$d->setAttribute(PDO::ATTR_ERRMODE,PDO::ERRMODE_EXCEPTION);"
                "$s=$d->prepare('UPDATE users SET digesta1=? WHERE username=?');"
                "$s->execute([$v['digest'],'alice']);if($s->rowCount()!==1){exit(2);}")
        subprocess.run(COMPOSE + ['exec', '-T', 'baikal', 'php', '-r', code],
                       input=json.dumps({'digest': digest}), text=True, check=True, capture_output=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['rotate', 'restore', 'restart'])
    parser.add_argument('server', choices=['radicale', 'baikal', 'busystack'])
    args = parser.parse_args()
    if args.server == 'busystack':
        runner = ['python3', str(ROOT / 'busystack-fixture.py')]
        if args.action == 'restart':
            subprocess.run(runner + ['restart'], check=True, capture_output=True)
            return
        if args.action == 'restore':
            raise SystemExit('A revoked DAV credential must never be restored; use the newly issued credential.')
        state_path = RUNTIME / 'busystack-credential-label.json'
        current = json.loads((RUNTIME / 'busystack-credentials.json').read_text())['alice']
        if not state_path.exists():
            raise SystemExit('Issue a dedicated QA credential first; current label identity is unavailable.')
        state = json.loads(state_path.read_text())
        if not state.get('label') or state.get('credentialId') != current.split('.')[0]:
            raise SystemExit('QA credential label does not match the held credential; issue a fresh named QA credential.')
        old_label = state['label']
        label = 'BusyMax QA replacement ' + secrets.token_hex(8)
        subprocess.run(runner + ['issue', 'alice', label], check=True, capture_output=True)
        subprocess.run(runner + ['revoke', 'alice', old_label], check=True, capture_output=True)
        value = json.loads((RUNTIME / 'busystack-credentials.json').read_text())['alice']
        for path, data in [(state_path, {'label': label, 'credentialId': value.split('.')[0]}), (RUNTIME / 'rotation-busystack.json', {'password': value})]:
            path.write_text(json.dumps(data))
            path.chmod(0o600)
        print('Disposable named DAV credential reissued and predecessor revoked through MFA (not printed).')
        return
    if args.action == 'restart':
        subprocess.run(COMPOSE + ['restart', args.server], check=True, capture_output=True)
        return
    if args.action == 'rotate':
        value = secrets.token_urlsafe(32)
        path = RUNTIME / f'rotation-{args.server}.json'
        path.write_text(json.dumps({'password': value}))
        path.chmod(0o600)
    else:
        value = json.loads((RUNTIME / 'credentials.json').read_text())['alice']
    password(args.server, value)
    print('Disposable fixture credentials changed (not printed).')


if __name__ == '__main__':
    main()
