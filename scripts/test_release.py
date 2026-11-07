"""Checks release orchestration without signing, networking, or publishing."""
import importlib.util
import io
from pathlib import Path
import plistlib
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('release', Path(__file__).with_name('release.py'))
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.app = self.root / 'NoLogo.app'
        (self.app / 'Contents').mkdir(parents=True)
        with (release.ROOT / 'NoLogo/Info.plist').open('rb') as file:
            self.config = plistlib.load(file)
        info = dict(self.config, CFBundleIdentifier='com.jez020.nologo',
                    CFBundleShortVersionString='1.1', CFBundleVersion='2')
        (self.app / 'Contents/Info.plist').write_bytes(plistlib.dumps(info))
        self.output = self.root / 'output'
        self.output.mkdir()
        self.calls = []

    def command(self, *args, **kwargs):
        args = tuple(map(str, args))
        self.calls.append(args)
        if args[0].endswith('generate_keys'):
            return self.config['SUPublicEDKey']
        if args[0] == 'ditto':
            Path(args[-1]).write_bytes(b'archive')
        if args[0].endswith('generate_appcast'):
            signature = release.base64.b64encode(bytes(64)).decode()
            url = 'https://github.com/jez020/nologo/releases/download/v1.1/NoLogo-1.1.zip'
            (self.output / 'appcast.xml').write_text(
                '<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">'
                '<channel><item><sparkle:version>2</sparkle:version>'
                f'<enclosure url="{url}" length="7" sparkle:edSignature="{signature}"/>'
                '</item></channel></rss>')
        return ''

    def invoke(self, publish=False, feed=b'<rss><channel/></rss>'):
        argv = ['release.py', str(self.app), '--sparkle-bin', str(self.root)]
        if publish:
            argv.append('--publish')
        with patch.object(release.sys, 'argv', argv), \
             patch.object(release, 'run', side_effect=self.command), \
             patch.object(release.tempfile, 'mkdtemp', return_value=str(self.output)), \
             patch.object(release.urllib.request, 'urlopen', return_value=io.BytesIO(feed)):
            release.main()

    def test_prepare_does_not_publish(self):
        self.invoke()
        self.assertFalse(any(c[:2] == ('gh', 'release') for c in self.calls))
        self.assertTrue((self.output / 'appcast.xml').exists())

    def test_upload_finishes_before_publishing(self):
        self.invoke(publish=True)
        writes = [c for c in self.calls if c[:2] == ('gh', 'release')]
        self.assertEqual([c[2] for c in writes], ['create', 'edit'])
        self.assertIn('--draft', writes[0])
        self.assertIn('--draft=false', writes[1])

    def test_rejects_reused_build(self):
        feed = (b'<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">'
                b'<channel><item><sparkle:version>2</sparkle:version></item></channel></rss>')
        with self.assertRaisesRegex(ValueError, 'must be newer'):
            self.invoke(publish=True, feed=feed)
        self.assertFalse(any(c[:2] == ('gh', 'release') for c in self.calls))

    def test_version_order(self):
        self.assertGreater(release.version_tuple('10'), release.version_tuple('2'))
        self.assertEqual(release.version_tuple('2'), release.version_tuple('2.0'))
        with self.assertRaises(ValueError):
            release.version_tuple('1.0-beta')


if __name__ == '__main__':
    unittest.main()
