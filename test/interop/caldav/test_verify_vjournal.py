"""Check the qualifier's provider and package identity assertions."""

from pathlib import Path
import runpy
import unittest


runner = runpy.run_path(str(Path(__file__).with_name('verify-vjournal.py')))
digests = runner['apk_signer_digests']
classify = runner['classify_nextcloud_admission']


class ApkSigningIdentityTest(unittest.TestCase):
    def test_verified_signer_digest_formats(self):
        expected = '01ab' * 16
        self.assertEqual(digests(f'Signer #1 certificate SHA-256 digest: {expected}'), {expected})
        self.assertEqual(digests(f'V2 Signer: certificate SHA-256 digest: {expected.upper()}'), {expected})
        self.assertEqual(digests(f'Source Stamp Signer certificate SHA-256 digest: {expected}'), set())
        self.assertEqual(digests('V2 Signer: certificate SHA-256 digest: 12345'), set())


class NextcloudAdmissionTest(unittest.TestCase):
    blocked = {'J12-link-uid', 'J12-link-xml', 'J12-related-uid',
               'J15-start-end', 'J15-start-duration'}
    fixtures = sorted(blocked | {'J01-undated'})
    corpus = {'version': 1, 'cases': [{'id': case} for case in fixtures]}
    identity = {'nextcloud': '35.0.3.2', 'image': runner['NEXTCLOUD_35_0_3']}

    def rows(self, blocked):
        result = [{'fixture_version': 1, 'fixture_sha256': 'corpus-digest'}]
        for case in self.fixtures:
            for operation, success in [('create', 201), ('update', 204)]:
                rejected = case in blocked
                result.append(dict(
                    case=case, operation=operation, put=500 if rejected else success,
                    get=404 if rejected and operation == 'create' else 200,
                    issue='admission rejected; original state unchanged' if rejected else None,
                ))
        total = len(self.fixtures) * 2
        return result + [dict(executed=total, passed=total - len(blocked) * 2,
                              failed=len(blocked) * 2)]

    def result(self, rows, code=1, identity=None):
        return classify(rows, self.corpus, 'corpus-digest', identity or self.identity, code)

    def test_all_operations_and_intact_state_are_required(self):
        result = self.rows(self.blocked)
        self.assertEqual(self.result(result), 'upstream-blocked')
        self.assertEqual(self.result(self.rows(set()), 0), 'pass')
        self.assertEqual(self.result(result[:-2] + result[-1:]), 'fail')
        self.assertEqual(self.result(result, identity={**self.identity, 'nextcloud': '35.0.4.0'}), 'fail')
        self.assertEqual(self.result(self.rows(self.blocked - {'J12-link-uid'})), 'fail')
        result[-2]['issue'] = 'admission rejected; original state changed'
        self.assertEqual(self.result(result), 'fail')
