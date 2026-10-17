"""Reject mixed production/test signing inputs before an IPA is built."""
import datetime
import json
import plistlib
import sys

TEAM = 'H96JUT8PUM'
BUNDLE = 'com.andalus.aqar.staging'


def validate(profile, now=None):
    now = now or datetime.datetime.now(datetime.timezone.utc)
    expiry = profile.get('ExpirationDate')
    if not isinstance(expiry, datetime.datetime):
        raise ValueError('Missing provisioning expiry')
    if expiry.tzinfo is None:
        expiry = expiry.replace(tzinfo=datetime.timezone.utc)
    entitlements = profile.get('Entitlements', {})
    checks = {
        'team': profile.get('TeamIdentifier') == [TEAM],
        'bundle': entitlements.get('application-identifier') == f'{TEAM}.{BUNDLE}',
        'APNs distribution environment': entitlements.get('aps-environment') == 'production',
        'release signing': entitlements.get('get-task-allow') is False,
        'registered test devices': bool(profile.get('ProvisionedDevices')),
        'unexpired profile': expiry > now,
        'profile UUID': bool(profile.get('UUID')),
        'profile name': bool(profile.get('Name')),
    }
    for label, passed in checks.items():
        if not passed:
            raise ValueError(f'Invalid isolated Ad Hoc profile: {label}')
    return {'team': TEAM, 'bundle': BUNDLE, 'deviceCount': len(profile['ProvisionedDevices']),
            'profileName': profile['Name'], 'uuid': profile['UUID'],
            'expiresUtc': expiry.isoformat(), 'apnsEnvironment': 'production'}


if __name__ == '__main__':
    with open(sys.argv[1], 'rb') as stream:
        result = validate(plistlib.load(stream))
    with open(sys.argv[2], 'w', encoding='utf-8') as stream:
        json.dump(result, stream, indent=2)
    # Device identifiers and certificate bytes are never logged.
    print('Validated isolated Ad Hoc profile:', result['bundle'], 'devices:', result['deviceCount'])
