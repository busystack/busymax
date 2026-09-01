BeforeAll {
  $script:tools = Split-Path -Parent $PSScriptRoot
  . (Join-Path $script:tools 'common.ps1')

  function New-BusyMaxRenderedTestManifest {
    $rendered = Get-Content `
      -LiteralPath (Join-Path $script:tools 'AppxManifest.xml.template') -Raw
    $rendered = $rendered.Replace(
      '@@IDENTITY_NAME@@', 'BusyStack.BusyMax.CI')
    $rendered = $rendered.Replace(
      '@@PUBLISHER@@', 'CN=BusyMax CI Package')
    $rendered = $rendered.Replace(
      '@@PUBLISHER_DISPLAY_NAME@@', 'BusyMax CI')
    $rendered = $rendered.Replace('@@PACKAGE_VERSION@@', '1.0.0.0')
    $rendered = $rendered.Replace(
      '@@MAX_TESTED_VERSION@@', '10.0.26100.0')
    return $rendered.Replace(
      '@@RESOURCE_LANGUAGES@@', (Get-BusyMaxResourceXml))
  }
}

Describe 'BusyMax rendered manifest contract' {
  BeforeEach {
    $manifestPath = Join-Path $TestDrive 'AppxManifest.xml'
  }

  It 'accepts toast activation in the base desktop namespace' {
    New-BusyMaxRenderedTestManifest | Set-Content `
      -LiteralPath $manifestPath -Encoding utf8NoBOM
    { & (Join-Path $tools 'validate_manifest.ps1') `
        -ManifestPath $manifestPath } | Should -Not -Throw
  }

  It 'rejects the desktop4 toast activation structure' {
    $rendered = New-BusyMaxRenderedTestManifest
    $desktopNamespace =
      '  xmlns:desktop="http://schemas.microsoft.com/appx/manifest/desktop/windows10"'
    $rendered = $rendered.Replace(
      $desktopNamespace,
      "$desktopNamespace`r`n  xmlns:desktop4=`"http://schemas.microsoft.com/appx/manifest/desktop/windows10/4`"")
    $rendered = $rendered.Replace(
      'IgnorableNamespaces="uap uap10 desktop com rescap"',
      'IgnorableNamespaces="uap uap10 desktop desktop4 com rescap"')
    $rendered = $rendered.Replace(
      '<desktop:Extension Category="windows.toastNotificationActivation">',
      '<desktop4:Extension Category="windows.toastNotificationActivation">')
    $rendered = $rendered.Replace(
      '<desktop:ToastNotificationActivation',
      '<desktop4:ToastNotificationActivation')
    $rendered = [regex]::Replace(
      $rendered,
      '</desktop:Extension>(\s*<com:Extension Category="windows\.comServer">)',
      '</desktop4:Extension>$1')
    $rendered | Set-Content -LiteralPath $manifestPath -Encoding utf8NoBOM
    { & (Join-Path $tools 'validate_manifest.ps1') `
        -ManifestPath $manifestPath } |
      Should -Throw -ExpectedMessage '*desktop namespace, not desktop4*'
  }

  It 'rejects a COM class that differs from the toast activator CLSID' {
    $rendered = (New-BusyMaxRenderedTestManifest).Replace(
      '<com:Class Id="7B854A6D-8B2A-45A5-B998-1F51EC5A81D7" />',
      '<com:Class Id="11111111-1111-1111-1111-111111111111" />')
    $rendered | Set-Content -LiteralPath $manifestPath -Encoding utf8NoBOM
    { & (Join-Path $tools 'validate_manifest.ps1') `
        -ManifestPath $manifestPath } |
      Should -Throw -ExpectedMessage '*Toast COM server*'
  }

  It 'references only concrete unqualified package logo paths' {
    [xml]$manifest = New-BusyMaxRenderedTestManifest
    $namespaces = [System.Xml.XmlNamespaceManager]::new($manifest.NameTable)
    $namespaces.AddNamespace(
      'f', 'http://schemas.microsoft.com/appx/manifest/foundation/windows10')
    $namespaces.AddNamespace(
      'uap', 'http://schemas.microsoft.com/appx/manifest/uap/windows10')
    $visualElements = $manifest.SelectSingleNode(
      '//uap:VisualElements', $namespaces)
    $references = @(
      [string]$manifest.SelectSingleNode(
        '/f:Package/f:Properties/f:Logo', $namespaces).InnerText
      [string]$visualElements.Square44x44Logo
      [string]$visualElements.Square150x150Logo
      [string]$manifest.SelectSingleNode(
        '//uap:FileTypeAssociation/uap:Logo', $namespaces).InnerText
    )
    $references | Should -HaveCount 4
    foreach ($reference in $references) {
      $reference | Should -Not -Match '\.(scale|targetsize)-'
    }
  }
}
