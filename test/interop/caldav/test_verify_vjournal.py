"""Check known official apksigner output shapes without weakening comparison."""

from pathlib import Path
import runpy
import unittest


digests = runpy.run_path(str(Path(__file__).with_name('verify-vjournal.py')))[
    'apk_signer_digests'
]


class ApkSigningIdentityTest(unittest.TestCase):
    def test_verified_signer_digest_formats(self):
        expected = '01ab' * 16
        self.assertEqual(digests(f'Signer #1 certificate SHA-256 digest: {expected}'), {expected})
        self.assertEqual(digests(f'V2 Signer: certificate SHA-256 digest: {expected.upper()}'), {expected})
        self.assertEqual(digests(f'Source Stamp Signer certificate SHA-256 digest: {expected}'), set())
        self.assertEqual(digests('V2 Signer: certificate SHA-256 digest: 12345'), set())
