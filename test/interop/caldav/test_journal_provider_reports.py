"""Independent regression for the default DTSTAMP-repair oracle."""

from pathlib import Path
import runpy
import unittest


repair = runpy.run_path(str(Path(__file__).with_name('journal-provider-reports.py')))[
    'repaired_journal_stamp'
]


class DtstampRepairTest(unittest.TestCase):
    original = (b'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nBEGIN:VJOURNAL\r\n'
                b'UID:repair\r\nEND:VJOURNAL\r\nEND:VCALENDAR\r\n')
    stamp = b'DTSTAMP:20261126T123000Z\r\n'

    def test_repaired_direct_property_is_required(self):
        repaired = self.original.replace(b'UID:repair\r\n', b'UID:repair\r\n' + self.stamp)
        self.assertEqual(repair(repaired), self.original)
        for candidate in (self.original, b'', repaired.replace(self.stamp, self.stamp * 2),
                          repaired.replace(b'20261126', b'20260231'),
                          self.original.replace(b'VERSION:2.0\r\n', self.stamp + b'VERSION:2.0\r\n'),
                          repaired.replace(self.stamp, b'BEGIN:VSTATUS\r\n' + self.stamp + b'END:VSTATUS\r\n')):
            with self.subTest(candidate=candidate):
                self.assertIsNone(repair(candidate))

    def test_every_stamp_is_counted_before_value_validation(self):
        for extra in (
            b'DTSTAMP:garbage\r\n',
            b'DTSTAMP:20261126T123000\r\n',
            b'dtstamp;X-MARK="a:b":20261126T123000Z\r\n',
            b'legacy.DTSTAMP:20261126T123000Z\r\n',
        ):
            with self.subTest(extra=extra):
                candidate = self.original.replace(b'END:VJOURNAL', self.stamp + extra + b'END:VJOURNAL')
                self.assertIsNone(repair(candidate))

    def test_single_stamp_must_be_utc_and_only_that_line_is_removed(self):
        for invalid in (b'garbage', b'20261126T123000', b'20260231T123000Z'):
            candidate = self.original.replace(b'END:VJOURNAL', b'DTSTAMP:' + invalid + b'\r\nEND:VJOURNAL')
            with self.subTest(invalid=invalid):
                self.assertIsNone(repair(candidate))
        changed = self.original.replace(b'UID:repair', b'UID:changed')
        candidate = changed.replace(b'END:VJOURNAL', self.stamp.replace(b'DTSTAMP', b'dtstamp') + b'END:VJOURNAL')
        self.assertEqual(repair(candidate), changed)
        self.assertNotEqual(repair(candidate), self.original)
