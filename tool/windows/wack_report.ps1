Set-StrictMode -Version Latest

function Get-BusyMaxWackAttribute {
  param(
    [Parameter(Mandatory)][System.Xml.XmlNode]$Node,
    [Parameter(Mandatory)][string[]]$Names
  )
  foreach ($name in $Names) {
    $attribute = $Node.Attributes[$name]
    if ($null -ne $attribute -and
        -not [string]::IsNullOrWhiteSpace([string]$attribute.Value)) {
      return ([string]$attribute.Value).Trim()
    }
  }
  return ''
}

function Get-BusyMaxWackNodeName {
  param(
    [Parameter(Mandatory)][System.Xml.XmlNode]$Node,
    [Parameter(Mandatory)][string]$Fallback
  )
  $named = $Node.SelectSingleNode('ancestor-or-self::*[@NAME or @Name or @TITLE or @Title][1]')
  if ($null -eq $named) { return $Fallback }
  $name = Get-BusyMaxWackAttribute -Node $named `
    -Names @('NAME', 'Name', 'TITLE', 'Title')
  if ([string]::IsNullOrWhiteSpace($name)) { return $Fallback }
  return $name
}

function Read-BusyMaxWackReport {
  param([Parameter(Mandatory)][string]$ReportPath)
  if (-not (Test-Path -LiteralPath $ReportPath -PathType Leaf)) {
    throw 'WACK did not emit an XML report.'
  }
  if ((Get-Item -LiteralPath $ReportPath).Length -eq 0) {
    throw 'WACK emitted an empty XML report.'
  }
  try {
    [xml]$report = Get-Content -LiteralPath $ReportPath -Raw
  } catch {
    throw "WACK emitted malformed XML: $($_.Exception.Message)"
  }
  $root = $report.DocumentElement
  if ($null -eq $root -or $root.LocalName -cne 'REPORT') {
    throw 'WACK XML does not contain the expected REPORT root.'
  }
  $overall = Get-BusyMaxWackAttribute -Node $root `
    -Names @('OVERALL_RESULT', 'OverallResult', 'RESULT', 'Result')
  $overall = $overall.ToUpperInvariant()
  if ([string]::IsNullOrWhiteSpace($overall)) {
    throw 'WACK XML does not contain OVERALL_RESULT.'
  }

  $recognizedValues = @('PASS', 'PASSED', 'FAIL', 'FAILED', 'ERROR', 'WARNING', 'WARN')
  $records = @()
  foreach ($node in @($report.SelectNodes('//*'))) {
    if ($node -eq $root) { continue }
    $value = ''
    if ($node.LocalName -ceq 'RESULT') {
      $value = ([string]$node.InnerText).Trim()
    }
    if ([string]::IsNullOrWhiteSpace($value)) {
      $value = Get-BusyMaxWackAttribute -Node $node `
        -Names @('RESULT', 'Result', 'STATUS', 'Status', 'OUTCOME', 'Outcome', 'OVERALL_RESULT', 'OverallResult')
    }
    $value = $value.ToUpperInvariant()
    if ($value -in $recognizedValues) {
      $records += [pscustomobject]@{ Node = $node; Value = $value }
    }
  }
  if ($records.Count -eq 0) {
    throw 'WACK XML contains no recognized per-test results.'
  }

  $failureNames = @($records | Where-Object {
      $_.Value -in @('FAIL', 'FAILED', 'ERROR')
    } | ForEach-Object {
      Get-BusyMaxWackNodeName -Node $_.Node -Fallback $_.Value
    } | Sort-Object -Unique)

  $warningNames = @($records | Where-Object {
      $_.Value -in @('WARNING', 'WARN')
    } | ForEach-Object {
      Get-BusyMaxWackNodeName -Node $_.Node -Fallback 'WACK warning'
    })
  foreach ($node in @($report.SelectNodes('//*'))) {
    $severity = Get-BusyMaxWackAttribute -Node $node `
      -Names @('TYPE', 'Type', 'SEVERITY', 'Severity', 'MESSAGE_TYPE', 'MessageType')
    if ($node.LocalName.ToUpperInvariant() -in @('WARNING', 'WARN') -or
        $severity.ToUpperInvariant() -in @('WARNING', 'WARN')) {
      $warningNames += Get-BusyMaxWackNodeName -Node $node `
        -Fallback 'WACK warning'
    }
  }
  $warningNames = @($warningNames | Sort-Object -Unique)

  return [pscustomobject]@{
    OverallResult = $overall
    ResultCount = $records.Count
    FailureNames = $failureNames
    Warnings = $warningNames
  }
}

function Assert-BusyMaxWackWarningDispositions {
  param(
    [Parameter(Mandatory)][string[]]$Warnings,
    [string]$WarningDispositionPath = ''
  )
  if ($Warnings.Count -gt 0) {
    if ([string]::IsNullOrWhiteSpace($WarningDispositionPath) -or
        -not (Test-Path -LiteralPath $WarningDispositionPath -PathType Leaf)) {
      throw 'WACK reported warnings. Supply -WarningDispositionPath with a JSON object containing a written disposition for every warning name.'
    }
    try {
      $dispositions = Get-Content -LiteralPath $WarningDispositionPath -Raw |
        ConvertFrom-Json
    } catch {
      throw "WACK warning dispositions are malformed JSON: $($_.Exception.Message)"
    }
    foreach ($warningName in $Warnings) {
      $property = $dispositions.PSObject.Properties[$warningName]
      if ($null -eq $property -or
          [string]::IsNullOrWhiteSpace([string]$property.Value) -or
          [string]$property.Value -match '(?i)(todo|placeholder|replace_with)') {
        throw "WACK warning '$warningName' has no explicit written disposition."
      }
    }
  }
}
