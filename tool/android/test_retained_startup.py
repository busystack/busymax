"""Regression guards for native acceptance evidence classification."""
import unittest
from check_retained_startup import classify_database_failures, logcat_resume_cursor, foreground_test_completed


class DatabaseFailureClassificationTest(unittest.TestCase):
    def event(self, **values):
        return {'failed': True, 'operation': 'read', 'transaction': None,
                'errorType': 'CancellationException', 'cancelled': True,
                **values}

    def test_actual_typed_idle_read_cancellation_is_recorded(self):
        event = self.event()
        self.assertEqual(classify_database_failures([event]), ([], [event]))

    def test_sqlite_error_remains_fatal_even_with_conflicting_flags(self):
        for field in ['sqliteResultCode', 'sqliteExtendedResultCode']:
            for code in [5, 517, 773]:
                with self.subTest(field=field, code=code):
                    event = self.event(**{field: code})
                    self.assertEqual(classify_database_failures([event]), ([event], []))

    def test_write_cancellation_remains_fatal(self):
        for operation in ['insert', 'update', 'delete', 'custom', 'batch', 'begin', 'commit', 'rollback']:
            with self.subTest(operation=operation):
                event = self.event(operation=operation)
                self.assertEqual(classify_database_failures([event]), ([event], []))

    def test_transaction_read_cancellation_remains_fatal(self):
        event = self.event(transaction=1)
        self.assertEqual(classify_database_failures([event]), ([event], []))

    def test_unknown_failure_remains_fatal(self):
        for values in [{'errorType': 'StateError'}, {'cancelled': False}]:
            event = self.event(**values)
            self.assertEqual(classify_database_failures([event]), ([event], []))

    def test_incomplete_failure_metadata_remains_fatal(self):
        for field in ['failed', 'operation', 'transaction', 'errorType', 'cancelled']:
            event = self.event()
            del event[field]
            self.assertEqual(classify_database_failures([event]), ([event], []))

    def test_success_is_not_misreported_as_failure(self):
        self.assertEqual(classify_database_failures([self.event(failed=False)]), ([], []))


class LogCaptureCursorTest(unittest.TestCase):
    def test_epoch_overlap_handles_unordered_buffers_and_eof(self):
        text = ' 1793455615.082 123 123 I flutter: entry\n 1793455614.900 123 124 I Worker: entry\nread: unexpected EOF!\n'
        self.assertEqual(logcat_resume_cursor(text), '1793455614.082')

    def test_missing_cursor_cannot_be_claimed_as_complete_capture(self):
        with self.assertRaises(RuntimeError):
            logcat_resume_cursor('read: unexpected EOF!\n')


class ForegroundCompletionTest(unittest.TestCase):
    receipt = {'utc': '2026-10-31T14:06:55.000Z'}

    def test_receipt_before_cleanup_is_insufficient(self):
        self.assertFalse(foreground_test_completed('', self.receipt))
        self.assertFalse(foreground_test_completed('1793455615.500 1 1 I flutter: Some tests failed!', self.receipt))

    def test_framework_success_must_follow_this_receipt(self):
        self.assertTrue(foreground_test_completed('1793455615.500 1 1 I flutter: All tests passed!', self.receipt))
        self.assertFalse(foreground_test_completed('1793455614.000 1 1 I flutter: All tests passed!', self.receipt))

    def test_missing_receipt_cannot_pass(self):
        self.assertFalse(foreground_test_completed('1793455615.500 1 1 I flutter: All tests passed!', None))


if __name__ == '__main__':
    unittest.main()
