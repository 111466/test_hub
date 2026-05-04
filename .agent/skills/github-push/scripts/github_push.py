#!/usr/bin/env python3
"""GitHub Push - Create repo if needed and push code."""
import argparse, json, subprocess, sys, urllib.request, urllib.error, os

def api(method, path, token, data=None, proxy=None):
    url = 'https://api.github.com' + path
    headers = {'Authorization': 'token ' + token, 'Accept': 'application/vnd.github.v3+json'}
    if data is not None:
        headers['Content-Type'] = 'application/json'
        data = json.dumps(data).encode()
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    if proxy:
        handler = urllib.request.ProxyHandler({'https': proxy, 'http': proxy})
        opener = urllib.request.build_opener(handler)
    else:
        opener = urllib.request.build_opener()
    try:
        resp = opener.open(req)
        return json.loads(resp.read().decode()), resp.status
    except urllib.error.HTTPError as e:
        body = e.read().decode() if e.fp else ''
        try:
            return json.loads(body), e.code
        except Exception:
            return {'message': body}, e.code

def run(cmd, check=True):
    r = subprocess.run(cmd, capture_output=True, text=True)
    if check and r.returncode != 0:
        print('ERROR: ' + ' '.join(cmd), file=sys.stderr)
        if r.stderr:
            print(r.stderr, file=sys.stderr)
        sys.exit(1)
    return r

def main():
    p = argparse.ArgumentParser(description='GitHub Push')
    p.add_argument('--token', required=True)
    p.add_argument('--repo', required=True)
    p.add_argument('--user', default='')
    p.add_argument('--private', action='store_true')
    p.add_argument('--description', default='')
    p.add_argument('--branch', default='main')
    p.add_argument('--proxy', default='')
    args = p.parse_args()

    proxy = args.proxy or None

    # Setup git proxy
    if proxy:
        os.environ['http_proxy'] = proxy
        os.environ['https_proxy'] = proxy
        run(['git', 'config', '--global', 'http.proxy', proxy], check=False)
        run(['git', 'config', '--global', 'https.proxy', proxy], check=False)

    # Auto-detect username
    user = args.user
    if not user:
        data, code = api('GET', '/user', args.token, proxy=proxy)
        user = data.get('login', '')
        if not user:
            print('ERROR: Failed to detect GitHub username.')
            sys.exit(1)
        print('Detected GitHub user: ' + user)

    # Check if repo exists
    _, code = api('GET', '/repos/' + user + '/' + args.repo, args.token, proxy=proxy)

    if code == 200:
        print('Repository ' + user + '/' + args.repo + ' already exists.')
    else:
        print('Creating repository ' + user + '/' + args.repo + ' ...')
        payload = {'name': args.repo, 'private': args.private}
        if args.description:
            payload['description'] = args.description
        data, code = api('POST', '/user/repos', args.token, data=payload, proxy=proxy)
        html_url = data.get('html_url', '')
        if not html_url:
            print('ERROR: Failed to create repository: ' + data.get('message', 'Unknown error'))
            sys.exit(1)
        print('Repository created: ' + html_url)

    # Init git if needed
    if not os.path.isdir('.git'):
        run(['git', 'init'])
        print('Git initialized.')

    # Configure git user
    r = run(['git', 'config', 'user.email'], check=False)
    if r.returncode != 0:
        run(['git', 'config', 'user.email', user + '@users.noreply.github.com'])
    r = run(['git', 'config', 'user.name'], check=False)
    if r.returncode != 0:
        run(['git', 'config', 'user.name', user])

    # Set remote
    remote_url = 'https://' + user + ':' + args.token + '@github.com/' + user + '/' + args.repo + '.git'
    r = run(['git', 'remote', 'get-url', 'origin'], check=False)
    if r.returncode == 0:
        run(['git', 'remote', 'set-url', 'origin', remote_url])
    else:
        run(['git', 'remote', 'add', 'origin', remote_url])

    # Stage and commit
    r = run(['git', 'status', '--porcelain'], check=False)
    if r.stdout.strip():
        run(['git', 'add', '-A'])
        run(['git', 'commit', '-m', 'Initial commit'])
        print('Changes committed.')

    # Push
    run(['git', 'branch', '-M', args.branch])
    result = subprocess.run(['git', 'push', '-u', 'origin', args.branch],
                            capture_output=True, text=True)
    if result.stdout:
        print(result.stdout)
    if result.stderr:
        print(result.stderr)
    if result.returncode != 0:
        print('ERROR: Push failed.')
        sys.exit(1)

    # Clean token from URL
    clean_url = 'https://github.com/' + user + '/' + args.repo + '.git'
    run(['git', 'remote', 'set-url', 'origin', clean_url])

    print('')
    print('SUCCESS: Code pushed to https://github.com/' + user + '/' + args.repo)

if __name__ == '__main__':
    main()
