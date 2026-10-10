from pathlib import Path
import os
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import validate


class ManifestChecks(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.resource = Path(self.temp.name) / 'Example'
        self.resource.mkdir()
        for name in ('README.md', 'LICENSE.md', 'client.lua'):
            (self.resource / name).write_text('-- fixture\n')
        self.base = "fx_version 'cerulean'\ngame 'gta5'\nversion '1.0.0'\nclient_script 'client.lua'\n"

    def manifest(self, extra=''):
        path = self.resource / 'fxmanifest.lua'
        path.write_text(self.base + extra)
        return path

    def test_valid_literal_manifest(self):
        self.manifest()
        self.assertEqual(validate.validate_resource(self.resource)['version'], ['1.0.0'])

    def test_named_file_entries_fail(self):
        self.manifest("files {source = 'client.lua'}\n")
        with self.assertRaisesRegex(ValueError, 'dense arrays'):
            validate.validate_resource(self.resource)

    def test_missing_script_fails(self):
        self.manifest("server_script 'missing.lua'\n")
        with self.assertRaisesRegex(ValueError, 'references no files'):
            validate.validate_resource(self.resource)

    def test_data_file_is_checked(self):
        self.manifest("data_file 'DLC_ITYP_REQUEST' 'missing.ytyp'\n")
        with self.assertRaisesRegex(ValueError, 'data_file.*references no files'):
            validate.validate_resource(self.resource)

    def wavepack(self):
        waves = self.resource / 'audio/mywaves'
        waves.mkdir(parents=True)
        (waves / 'car.awc').write_bytes(b'fixture')
        return waves

    def test_wavepack_directory_is_supported(self):
        self.wavepack()
        self.manifest("files {'audio/mywaves/*.awc'}\ndata_file 'AUDIO_WAVEPACK' 'audio/mywaves'\n")
        metadata = validate.validate_resource(self.resource)
        self.assertEqual(metadata['data_file:AUDIO_WAVEPACK'], ['audio/mywaves'])

    def test_other_data_file_types_reject_directories(self):
        self.wavepack()
        self.manifest("data_file 'DLC_ITYP_REQUEST' 'audio/mywaves'\n")
        with self.assertRaisesRegex(ValueError, 'references no files'):
            validate.validate_resource(self.resource)

    def test_wavepack_audio_must_be_packaged(self):
        self.wavepack()
        self.manifest("data_file 'AUDIO_WAVEPACK' 'audio/mywaves'\n")
        with self.assertRaisesRegex(ValueError, 'audio is missing from files'):
            validate.validate_resource(self.resource)

    def test_wavepack_must_contain_audio(self):
        waves = self.wavepack()
        (waves / 'car.awc').unlink()
        self.manifest("data_file 'AUDIO_WAVEPACK' 'audio/mywaves'\n")
        with self.assertRaisesRegex(ValueError, 'has no .awc files'):
            validate.validate_resource(self.resource)

    def test_wavepack_cannot_escape_resource(self):
        self.manifest("data_file 'AUDIO_WAVEPACK' '../other'\n")
        with self.assertRaisesRegex(ValueError, 'Unsafe'):
            validate.validate_resource(self.resource)

    def test_empty_script_glob_fails(self):
        self.manifest("server_scripts {'server/*.lua'}\n")
        with self.assertRaisesRegex(ValueError, 'references no files'):
            validate.validate_resource(self.resource)

    def test_parent_path_fails(self):
        self.manifest("files {'../README.md'}\n")
        with self.assertRaisesRegex(ValueError, 'Unsafe'):
            validate.validate_resource(self.resource)

    def test_symlink_escape_fails(self):
        external = Path(self.temp.name) / 'external.lua'
        external.write_text('return true')
        (self.resource / 'link.lua').symlink_to(external)
        self.manifest("client_script 'link.lua'\n")
        with self.assertRaisesRegex(ValueError, 'escapes'):
            validate.validate_resource(self.resource)

    def test_empty_glob_exception_is_scoped(self):
        self.manifest("files {'html/sounds/*.ogg'}\n")
        with self.assertRaisesRegex(ValueError, 'references no files'):
            validate.validate_resource(self.resource)
        renamed = self.resource.with_name('DaveDev_SFX')
        self.resource.rename(renamed)
        self.resource = renamed
        validate.validate_resource(self.resource)
        self.manifest("client_script 'html/sounds/*.ogg'\n")
        with self.assertRaisesRegex(ValueError, 'references no files'):
            validate.validate_resource(self.resource)

    def test_missing_license_fails(self):
        self.manifest()
        (self.resource / 'LICENSE.md').unlink()
        with self.assertRaisesRegex(ValueError, 'Missing package file'):
            validate.validate_resource(self.resource)

    def test_nui_assets_must_be_packaged(self):
        (self.resource / 'index.html').write_text('<script src="app.js"></script>')
        (self.resource / 'app.js').write_text('const value = 1;')
        self.manifest("ui_page 'index.html'\nfiles {'index.html'}\n")
        with self.assertRaisesRegex(ValueError, 'NUI asset is missing from files'):
            validate.validate_resource(self.resource)
        self.manifest("ui_page 'index.html'\nfiles {'index.html', 'app.js'}\n")
        validate.validate_resource(self.resource)

    def test_ui_page_must_be_packaged(self):
        (self.resource / 'index.html').write_text('<html></html>')
        self.manifest("ui_page 'index.html'\n")
        with self.assertRaisesRegex(ValueError, 'ui_page is missing from files'):
            validate.validate_resource(self.resource)

    def test_remote_nui_asset_requires_rule(self):
        (self.resource / 'index.html').write_text('<script src="https://example.com/app.js"></script>')
        self.manifest("ui_page 'index.html'\nfiles {'index.html'}\n")
        with self.assertRaisesRegex(ValueError, 'Remote NUI asset'):
            validate.validate_resource(self.resource)

    def test_manifest_has_no_os_access(self):
        self.manifest("os.execute('echo unsafe')\n")
        with self.assertRaises(ValueError):
            validate.validate_resource(self.resource)

    def test_recursive_glob_shorthand(self):
        nested = self.resource / 'nested'
        nested.mkdir()
        (nested / 'other.lua').write_text('return true')
        self.assertEqual(len(validate.resolve_files(self.resource, '**.lua')), 2)

    def test_external_reference_requires_rule(self):
        with self.assertRaisesRegex(ValueError, 'External resource reference'):
            validate.resolve_files(self.resource, '@other/resource.lua')


class ParserChecks(unittest.TestCase):
    def test_cfxlua_accepts_real_fivem_syntax(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / 'valid.lua'
            path.write_text('local hash = `WEAPON_UNARMED`\nlocal n = 1\nn += 2\nlocal x <const> = 3\n')
            validate.run([os.environ.get('CFXLUAC', 'luac'), '-p', str(path)])

    def test_cfxlua_rejects_broken_syntax(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / 'invalid.lua'
            path.write_text('local x =\n')
            with self.assertRaises(ValueError):
                validate.run([os.environ.get('CFXLUAC', 'luac'), '-p', str(path)])

    def test_node_rejects_broken_syntax(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / 'invalid.js'
            path.write_text('const x = ;\n')
            with self.assertRaises(ValueError):
                validate.run(['node', '--check', str(path)])


if __name__ == '__main__':
    unittest.main()
