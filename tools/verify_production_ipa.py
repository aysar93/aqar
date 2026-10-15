"""Verify an already-signed production candidate on macOS, without uploading it."""
import hashlib
import json
import pathlib
import plistlib
import subprocess
import sys
import tempfile
import zipfile


def verify(ipa):
    with tempfile.TemporaryDirectory(prefix='aqar-verify-') as folder:
        root = pathlib.Path(folder)
        with zipfile.ZipFile(ipa) as archive:
            for item in archive.infolist():
                target = (root / item.filename).resolve()
                if not target.is_relative_to(root.resolve()):
                    raise ValueError('Unsafe archive path')
            archive.extractall(root)
        apps = list((root / 'Payload').glob('*.app'))
        if len(apps) != 1:
            raise ValueError('Expected one application')
        app = apps[0]
        info = plistlib.loads((app / 'Info.plist').read_bytes())
        firebase = plistlib.loads((app / 'GoogleService-Info.plist').read_bytes())
        if info['CFBundleIdentifier'] != 'com.andalus.aqar' or info.get('AqarPushBridgeCandidate') is not True:
            raise ValueError('Wrong production candidate')
        if (firebase['PROJECT_ID'], firebase['GCM_SENDER_ID'], firebase['GOOGLE_APP_ID']) != (
            'aqar-9f3f9', '1031621585901', '1:1031621585901:ios:a8834b5b6455a5224b95e4'):
            raise ValueError('Wrong production Firebase configuration')
        subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True, capture_output=True)
        decoded = subprocess.run(['security', 'cms', '-D', '-i', str(app / 'embedded.mobileprovision')], check=True, capture_output=True).stdout
        profile = plistlib.loads(decoded)
        entitlements = profile['Entitlements']
        if (profile['TeamIdentifier'] != ['H96JUT8PUM'] or
            entitlements.get('application-identifier') != 'H96JUT8PUM.com.andalus.aqar' or
            entitlements.get('aps-environment') != 'production' or
            entitlements.get('get-task-allow') is not False or
            profile.get('ProvisionedDevices') or profile.get('ProvisionsAllDevices')):
            raise ValueError('App Store production signing required')
        cert_path = root / 'signing-cert'
        subprocess.run(['codesign', '--display', '--extract-certificates', str(cert_path), str(app)], check=True, capture_output=True)
        leaf = pathlib.Path(str(cert_path) + '0').read_bytes()
        if leaf not in profile['DeveloperCertificates']:
            raise ValueError('Signer not authorized by profile')
        return {'bundle': info['CFBundleIdentifier'], 'project': firebase['PROJECT_ID'],
                'build': info['CFBundleVersion'], 'signedCandidateFlag': True,
                'codesignStrictVerified': True, 'profileAuthorizesSigner': True,
                'apnsEnvironment': 'production', 'debuggable': False,
                'ipaSha256': hashlib.sha256(pathlib.Path(ipa).read_bytes()).hexdigest(),
                'signingCertificateSha256': hashlib.sha256(leaf).hexdigest(),
                'storeUploadPerformed': False, 'deviceInstallationVerified': False}


if __name__ == '__main__':
    ipa = pathlib.Path(sys.argv[1])
    result = verify(ipa)
    (ipa.parent / 'production-signing-evidence.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result))
