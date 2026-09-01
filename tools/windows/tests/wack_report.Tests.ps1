BeforeAll {
  . (Join-Path (Split-Path -Parent $PSScriptRoot) 'wack_report.ps1')
}

Describe 'BusyMax WACK report parsing' {
  BeforeEach {
    $caseId = [guid]::NewGuid().ToString('N')
    $report = Join-Path $TestDrive "$caseId-report.xml"
    $dispositions = Join-Path $TestDrive "$caseId-dispositions.json"
  }

  It 'accepts result elements and attribute-based test results' {
    @'
<REPORT OVERALL_RESULT="PASS">
  <TEST NAME="Launch"><RESULT>PASS</RESULT></TEST>
  <TEST NAME="Manifest" RESULT="PASSED" />
</REPORT>
'@ | Set-Content -LiteralPath $report -Encoding utf8NoBOM
    $parsed = Read-BusyMaxWackReport -ReportPath $report
    $parsed.OverallResult | Should -Be 'PASS'
    $parsed.ResultCount | Should -Be 2
    @($parsed.FailureNames).Count | Should -Be 0
  }

  It 'rejects every failed test even when the report overall value passes' {
    @'
<REPORT OVERALL_RESULT="PASS">
  <TEST NAME="Launch" STATUS="FAILED" />
</REPORT>
'@ | Set-Content -LiteralPath $report -Encoding utf8NoBOM
    $parsed = Read-BusyMaxWackReport -ReportPath $report
    $parsed.FailureNames | Should -Contain 'Launch'
  }

  It 'requires a non-placeholder disposition for every warning' {
    @'
<REPORT OVERALL_RESULT="PASS WITH WARNINGS">
  <TEST NAME="Optional API"><RESULT>WARNING</RESULT></TEST>
</REPORT>
'@ | Set-Content -LiteralPath $report -Encoding utf8NoBOM
    $parsed = Read-BusyMaxWackReport -ReportPath $report
    { Assert-BusyMaxWackWarningDispositions -Warnings $parsed.Warnings } |
      Should -Throw
    '{"Optional API":"TODO"}' | Set-Content -LiteralPath $dispositions `
      -Encoding utf8NoBOM
    { Assert-BusyMaxWackWarningDispositions -Warnings $parsed.Warnings `
        -WarningDispositionPath $dispositions } | Should -Throw
    '{"Optional API":"Reviewed; the optional API is not called by BusyMax."}' |
      Set-Content -LiteralPath $dispositions -Encoding utf8NoBOM
    { Assert-BusyMaxWackWarningDispositions -Warnings $parsed.Warnings `
        -WarningDispositionPath $dispositions } | Should -Not -Throw
  }

  It 'rejects missing, empty, malformed, and result-free reports' {
    { Read-BusyMaxWackReport -ReportPath $report } | Should -Throw
    '' | Set-Content -LiteralPath $report -NoNewline
    { Read-BusyMaxWackReport -ReportPath $report } | Should -Throw
    '<REPORT' | Set-Content -LiteralPath $report
    { Read-BusyMaxWackReport -ReportPath $report } | Should -Throw
    '<REPORT OVERALL_RESULT="PASS" />' | Set-Content -LiteralPath $report
    { Read-BusyMaxWackReport -ReportPath $report } | Should -Throw
  }
}
