"""Verify the isolated Ad Hoc IPA on macOS; never emit device IDs or client keys."""
import datetime
import hashlib
import json
import pathlib
import plistlib
import subprocess
import tempfile
import zipfile

EXPECTED = 'local.aqar.fullMediaTest'
PROFILE = 'AQAR Media Test AdHoc 20261019'
OUT = pathlib.Path('build/ios-signing-evidence')
OUT.mkdir(parents=True, exist_ok=True)


def run(*args):
    return subprocess.check_output(args, stderr=subprocess.PIPE)


ipa, = pathlib.Path('build/ios/ipa').glob('*.ipa')
with tempfile.TemporaryDirectory() as temporary:
    root = pathlib.Path(temporary)
    with zipfile.ZipFile(ipa) as archive:
        assert all(not n.startswith('/') and '..' not in pathlib.PurePosixPath(n).parts
                   for n in archive.namelist()), 'Unsafe archive paths'
        archive.extractall(root)
    app, = root.glob('Payload/*.app')
    info = plistlib.loads((app / 'Info.plist').read_bytes())
    assert info['CFBundleIdentifier'] == EXPECTED
    config = plistlib.loads((app / 'GoogleService-Info.plist').read_bytes())
    assert config['PROJECT_ID'] == 'aqar-media-test-20261018'
    assert config['BUNDLE_ID'] == EXPECTED
    assert config['STORAGE_BUCKET'] == 'aqar-media-test-20261018-media'
    profile = plistlib.loads(run('security', 'cms', '-D', '-i',
                                 str(app / 'embedded.mobileprovision')))
    ent = profile['Entitlements']
    team, = profile['TeamIdentifier']
    assert profile['Name'] == PROFILE
    assert ent['application-identifier'] == team + '.' + EXPECTED
    assert profile['ExpirationDate'] > datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None)
    assert len(profile.get('ProvisionedDevices', [])) == 1
    assert not profile.get('ProvisionsAllDevices', False)
    assert not ent.get('get-task-allow', False)
    assert 'aps-environment' not in ent
    run('codesign', '--verify', '--deep', '--strict', str(app))
    actual = plistlib.loads(run('codesign', '-d', '--entitlements', ':-', str(app)))
    assert actual['application-identifier'] == team + '.' + EXPECTED
    assert not actual.get('get-task-allow', False)
    assert 'aps-environment' not in actual
    prefix = str(root / 'leaf')
    run('codesign', '-d', '--extract-certificates=' + prefix, str(app))
    leaf = pathlib.Path(prefix + '0').read_bytes()
    assert leaf in profile['DeveloperCertificates'], 'Signing certificate not allowed by profile'
    result = {
        'ipa': ipa.name, 'bytes': ipa.stat().st_size,
        'sha256': hashlib.file_digest(ipa.open('rb'), 'sha256').hexdigest(),
        'bundle': EXPECTED, 'profileName': profile['Name'],
        'profileExpires': profile['ExpirationDate'].isoformat(),
        'profileUUIDSHA256': hashlib.sha256(profile['UUID'].encode()).hexdigest(),
        'allowedDeviceSHA256': [hashlib.sha256(x.upper().encode()).hexdigest()
                                for x in profile['ProvisionedDevices']],
        'signingCertificateSHA256': hashlib.sha256(leaf).hexdigest(),
        'codesignStrict': True, 'certificateInProfile': True,
        'adHocSingleDevice': True, 'productionBundle': False,
        'pushEntitlement': False, 'firebaseTestOnly': True,
        'physicalInstallation': 'NOT RUN', 'physicalMediaTests': 'NOT RUN',
    }
(OUT / 'signed-ipa-verification.json').write_text(json.dumps(result, indent=2))
print('Isolated Ad Hoc IPA verification PASS; physical device tests NOT RUN')
