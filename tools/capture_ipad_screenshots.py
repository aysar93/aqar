"""Run only on a Codemagic Mac with Xcode and Flutter installed."""
import json
from pathlib import Path
import subprocess
import zipfile


def run(*args):
    return subprocess.check_output(args, text=True).strip()


def main():
    devices = json.loads(run('xcrun', 'simctl', 'list', 'devices', 'available', '-j'))
    candidates = [
        device
        for runtime, entries in devices['devices'].items()
        if 'iOS' in runtime
        for device in entries
        if 'iPad Pro' in device['name'] and '13-inch' in device['name']
    ]
    if not candidates:
        raise RuntimeError('No 13-inch iPad simulator installed. Check Xcode runtimes.')
    device = candidates[-1]
    udid = device['udid']
    print('Capturing on ' + device['name'], flush=True)
    if device['state'] != 'Booted':
        run('xcrun', 'simctl', 'boot', udid)
    run('xcrun', 'simctl', 'bootstatus', udid, '-b')
    run('xcrun', 'simctl', 'status_bar', udid, 'override', '--time', '9:41',
        '--batteryState', 'charged', '--batteryLevel', '100')
    subprocess.run([
        'flutter', 'drive', '--driver=test_driver/screenshots.dart',
        '--target=integration_test/ipad_screenshots_test.dart', '-d', udid,
    ], check=True)
    screenshots = sorted(Path('build/ipad-screenshots').glob('*.png'))
    if len(screenshots) != 3:
        raise RuntimeError('Expected three screenshots; inspect the Flutter test log.')
    for screenshot in screenshots:
        dimensions = run('sips', '-g', 'pixelWidth', '-g', 'pixelHeight', str(screenshot))
        print(dimensions, flush=True)
        if '2064' not in dimensions or '2752' not in dimensions:
            raise RuntimeError('Unexpected iPad resolution; do not upload these images yet.')
    with zipfile.ZipFile('build/ipad-screenshots.zip', 'w') as archive:
        for screenshot in screenshots:
            archive.write(screenshot, screenshot.name)


if __name__ == '__main__':
    main()
