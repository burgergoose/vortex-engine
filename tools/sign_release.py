"""Vortex Engine release signing (pure Python 3, no extra packages).

    python tools/sign_release.py keygen <folder-outside-the-repo>
        Makes an RSA-2048 key pair: <folder>/vortex_release_private_key.json (KEEP SECRET, never commit or ship it)
        and <folder>/vortex_release_public_key.txt (goes into source/backend/BuildVerifier.hx -> PUBLIC_KEY_N).

    python tools/sign_release.py sign <bin folder> <private key json> [--commit <git hash>]
        Writes <bin folder>/vortex_manifest.json (SHA-256 of every program / asset file) and vortex_manifest.sig
        (RSA PKCS#1 v1.5 + SHA-256 signature of the manifest, hex). Run it on the folder you are about to zip,
        after removing logs / test mods. The version comes from assets/shared/data/vortexConfig.json in that folder.

    python tools/sign_release.py verify <bin folder> <public key txt>
        Checks a signed folder the same way the game does (signature + every file).

Files that are NOT covered (players change them): mods/, crash/, backups/, vortex_compat/, vortex_converted/,
logs (vortex_*.txt), modsList.txt, UNOFFICIAL_BUILD_README.txt and the manifest / signature themselves.
"""
import datetime, hashlib, json, os, secrets, sys

E = 65537
DIGEST_INFO = bytes.fromhex('3031300d060960864801650304020105000420')
SKIP_DIRS = {'mods', 'crash', 'backups', 'vortex_compat', 'vortex_converted'}
SKIP_FILES = {'modsList.txt', 'UNOFFICIAL_BUILD_README.txt', 'vortex_manifest.json', 'vortex_manifest.sig'}


def is_probable_prime(n, rounds=40):
    if n < 2:
        return False
    for p in (2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37):
        if n % p == 0:
            return n == p
    d, r = n - 1, 0
    while d % 2 == 0:
        d //= 2
        r += 1
    for _ in range(rounds):
        a = secrets.randbelow(n - 3) + 2
        x = pow(a, d, n)
        if x in (1, n - 1):
            continue
        for _ in range(r - 1):
            x = pow(x, 2, n)
            if x == n - 1:
                break
        else:
            return False
    return True


def random_prime(bits):
    while True:
        c = secrets.randbits(bits) | (1 << (bits - 1)) | (1 << (bits - 2)) | 1
        if c % E != 1 and is_probable_prime(c):
            return c


def keygen(folder):
    if os.path.abspath(folder).lower().startswith(os.path.abspath('.').lower()):
        sys.exit('Refusing: put the private key OUTSIDE the repository folder.')
    os.makedirs(folder, exist_ok=True)
    priv_path = os.path.join(folder, 'vortex_release_private_key.json')
    if os.path.exists(priv_path):
        sys.exit(priv_path + ' already exists; not overwriting it.')
    while True:
        p, q = random_prime(1024), random_prime(1024)
        n = p * q
        if p != q and n.bit_length() == 2048:
            break
    d = pow(E, -1, (p - 1) * (q - 1))
    with open(priv_path, 'w') as f:
        json.dump({'n': format(n, 'x'), 'e': E, 'd': format(d, 'x'), 'note': 'Vortex Engine release signing key. Keep secret.'}, f)
    with open(os.path.join(folder, 'vortex_release_public_key.txt'), 'w') as f:
        f.write(format(n, 'x'))
    print('keys written to', folder)
    print('public key (PUBLIC_KEY_N):', format(n, 'x'))


def covered_files(root):
    out = []
    for dirpath, dirnames, filenames in os.walk(root):
        rel_dir = os.path.relpath(dirpath, root).replace('\\', '/')
        if rel_dir == '.':
            dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
            rel_dir = ''
        for name in filenames:
            rel = (rel_dir + '/' + name) if rel_dir else name
            if not rel_dir and (name in SKIP_FILES or (name.startswith('vortex_') and name.endswith('.txt'))):
                continue
            out.append(rel)
    return sorted(out)


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def encode(message, k):
    t = DIGEST_INFO + hashlib.sha256(message).digest()
    return b'\x00\x01' + b'\xff' * (k - len(t) - 3) + b'\x00' + t


def sign(root, key_path, commit):
    key = json.load(open(key_path))
    n, d = int(key['n'], 16), int(key['d'], 16)
    k = (n.bit_length() + 7) // 8
    cfg = json.load(open(os.path.join(root, 'assets/shared/data/vortexConfig.json'), encoding='utf-8'))
    files = {rel: sha256_file(os.path.join(root, rel)) for rel in covered_files(root)}
    manifest = {'format': 1, 'engine': 'Vortex Engine', 'version': cfg.get('engineVersion'), 'commit': commit,
                'built': datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%d %H:%M UTC'), 'files': files}
    data = json.dumps(manifest, indent='\t', sort_keys=True).encode('utf-8')
    with open(os.path.join(root, 'vortex_manifest.json'), 'wb') as f:
        f.write(data)
    s = pow(int.from_bytes(encode(data, k), 'big'), d, n)
    with open(os.path.join(root, 'vortex_manifest.sig'), 'w') as f:
        f.write(format(s, 'x').zfill(k * 2))
    print('signed %d files, version %s' % (len(files), manifest['version']))


def verify(root, pub_path):
    n = int(open(pub_path).read().strip(), 16)
    k = (n.bit_length() + 7) // 8
    data = open(os.path.join(root, 'vortex_manifest.json'), 'rb').read()
    s = int(open(os.path.join(root, 'vortex_manifest.sig')).read().strip(), 16)
    if pow(s, E, n) != int.from_bytes(encode(data, k), 'big'):
        sys.exit('SIGNATURE DOES NOT MATCH')
    manifest = json.loads(data)
    bad = [rel for rel, h in manifest['files'].items() if not os.path.exists(os.path.join(root, rel)) or sha256_file(os.path.join(root, rel)) != h]
    print('signature OK; %d files, %d differ%s' % (len(manifest['files']), len(bad), (': ' + ', '.join(bad[:10])) if bad else ''))


if __name__ == '__main__':
    a = sys.argv[1:]
    if len(a) >= 2 and a[0] == 'keygen':
        keygen(a[1])
    elif len(a) >= 3 and a[0] == 'sign':
        commit = a[a.index('--commit') + 1] if '--commit' in a else 'unknown'
        sign(a[1], a[2], commit)
    elif len(a) >= 3 and a[0] == 'verify':
        verify(a[1], a[2])
    else:
        print(__doc__)
