"""Create missing native platforms in isolation, preserving every app source and save."""
import argparse
from pathlib import Path
import shutil
import subprocess
import tempfile
import plistlib
import re


def setup(flutter: str, root: Path):
    missing = [name for name in ('android', 'ios') if not (root / name).exists()]
    if missing:
        with tempfile.TemporaryDirectory(prefix='.platform-', dir=root) as temporary:
            scaffold = Path(temporary) / 'native'
            subprocess.run([flutter, 'create', '--platforms=' + ','.join(missing),
                            '--project-name=kalimat_sahmiya', '--org=com.jawhar',
                            '--no-pub', str(scaffold)], cwd=root, check=True)
            for platform in missing:
                shutil.copytree(scaffold / platform, root / platform)
            if not (root / '.metadata').exists():
                shutil.copy2(scaffold / '.metadata', root / '.metadata')

    main_manifest = root / 'android/app/src/main/AndroidManifest.xml'
    if main_manifest.exists():
        content = main_manifest.read_text(encoding='utf-8')
        permission = '<uses-permission android:name="android.permission.INTERNET" />'
        if permission not in content:
            start = content.index('>', content.index('<manifest')) + 1
            content = content[:start] + '\n    ' + permission + content[start:]
        content = content.replace('android:label="kalimat_sahmiya"', 'android:label="كلمات سهمية"')
        main_manifest.write_text(content, encoding='utf-8')

    debug_manifest = root / 'android/app/src/debug/AndroidManifest.xml'
    if debug_manifest.parent.exists():
        content = debug_manifest.read_text(encoding='utf-8') if debug_manifest.exists() else (
            '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n</manifest>\n')
        if 'android:usesCleartextTraffic' not in content:
            if '<application' in content:
                content = content.replace('<application', '<application android:usesCleartextTraffic="true"', 1)
            else:
                content = content.replace('</manifest>', '    <application android:usesCleartextTraffic="true" />\n</manifest>')
        debug_manifest.write_text(content, encoding='utf-8')

    info = root / 'ios/Runner/Info.plist'
    if info.exists():
        with info.open('rb') as stream:
            values = plistlib.load(stream)
        values['CFBundleDisplayName'] = 'كلمات سهمية'
        values['CFBundleLocalizations'] = ['ar']
        values['NSLocalNetworkUsageDescription'] = 'لتنزيل مستويات جديدة من خادم اللعبة على الشبكة المحلية.'
        with info.open('wb') as stream:
            plistlib.dump(values, stream, sort_keys=False)
        debug_values = {**values, 'NSAppTransportSecurity': {'NSAllowsArbitraryLoads': True}}
        with info.with_name('Info-Debug.plist').open('wb') as stream:
            plistlib.dump(debug_values, stream, sort_keys=False)
        project = root / 'ios/Runner.xcodeproj/project.pbxproj'
        content = project.read_text(encoding='utf-8')
        # Scope local HTTP to the Runner Debug configuration; release keeps HTTPS.
        content = re.sub(r'(?ms)[A-F0-9]+ /\* Debug \*/ = \{\n.*?\n\t\t\};',
            lambda match: match.group(0).replace('INFOPLIST_FILE = Runner/Info.plist;',
                                               'INFOPLIST_FILE = "Runner/Info-Debug.plist";'), content)
        project.write_text(content, encoding='utf-8')

    subprocess.run([flutter, 'pub', 'get'], cwd=root, check=True)
    print('Setup complete. Run: flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000')


def main():
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--flutter', help='Flutter executable when not on PATH')
    args = parser.parse_args()
    local = root.parent / '.tools/flutter/bin/flutter.bat'
    flutter = args.flutter or shutil.which('flutter') or (str(local) if local.exists() else None)
    if not flutter:
        parser.exit(1, 'Flutter SDK not found. Install Flutter and add its bin directory to PATH.\n')
    setup(flutter, root)


if __name__ == '__main__':
    main()
