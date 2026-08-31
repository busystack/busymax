param([Parameter(Mandatory)][string]$ManifestPath)

if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
  throw "Manifest not found: $ManifestPath"
}
[xml]$manifest = Get-Content -LiteralPath $ManifestPath -Raw
$manager = [System.Xml.XmlNamespaceManager]::new($manifest.NameTable)
$manager.AddNamespace('f', 'http://schemas.microsoft.com/appx/manifest/foundation/windows10')
$manager.AddNamespace('uap', 'http://schemas.microsoft.com/appx/manifest/uap/windows10')
$manager.AddNamespace('uap10', 'http://schemas.microsoft.com/appx/manifest/uap/windows10/10')
$manager.AddNamespace('desktop', 'http://schemas.microsoft.com/appx/manifest/desktop/windows10')
$manager.AddNamespace('desktop4', 'http://schemas.microsoft.com/appx/manifest/desktop/windows10/4')
$manager.AddNamespace('com', 'http://schemas.microsoft.com/appx/manifest/com/windows10')
$manager.AddNamespace('rescap', 'http://schemas.microsoft.com/appx/manifest/foundation/windows10/restrictedcapabilities')

$identity = $manifest.SelectSingleNode('/f:Package/f:Identity', $manager)
if ($null -eq $identity -or [string]::IsNullOrWhiteSpace($identity.Name) -or
    [string]::IsNullOrWhiteSpace($identity.Publisher) -or
    [string]::IsNullOrWhiteSpace($identity.Version)) {
  throw 'MSIX identity values are incomplete.'
}
if ($identity.ProcessorArchitecture -ne 'x64') { throw 'MSIX architecture must be x64.' }
$target = $manifest.SelectSingleNode('/f:Package/f:Dependencies/f:TargetDeviceFamily', $manager)
if ($target.Name -ne 'Windows.Desktop' -or $target.MinVersion -ne '10.0.26100.0') {
  throw 'MSIX must target Windows.Desktop 10.0.26100.0 or newer.'
}
if ([version]$target.MaxVersionTested -lt [version]$target.MinVersion) {
  throw 'MaxVersionTested must be at least the minimum Windows version.'
}
$applications = @($manifest.SelectNodes('/f:Package/f:Applications/f:Application', $manager))
if ($applications.Count -ne 1) { throw 'MSIX must declare exactly one application.' }
$application = $applications[0]
if ($application.Id -cne 'BusyMax' -or $application.Executable -cne 'busymax.exe' -or
    $application.EntryPoint -cne 'Windows.FullTrustApplication') {
  throw 'The packaged application identity or executable is not the stable BusyMax value.'
}
$visualElements = $manifest.SelectSingleNode(
  '/f:Package/f:Applications/f:Application/uap:VisualElements', $manager)
if ($null -eq $visualElements -or
    $visualElements.Square44x44Logo -cne 'Assets\Square44x44Logo.png' -or
    $visualElements.Square150x150Logo -cne 'Assets\Square150x150Logo.png') {
  throw 'BusyMax package visual elements are incomplete.'
}
$fileType = $manifest.SelectSingleNode('//uap:FileType[text()=".ics"]', $manager)
$protocol = $manifest.SelectSingleNode('//uap:Protocol[@Name="webcal"]', $manager)
$startup = $manifest.SelectSingleNode('//desktop:StartupTask[@TaskId="BusyMaxStartupTask"]', $manager)
$toast = $manifest.SelectSingleNode('//desktop4:ToastNotificationActivation', $manager)
$toastServer = $manifest.SelectSingleNode('//com:ExeServer/com:Class', $manager)
if ($null -eq $fileType -or $null -eq $protocol -or $null -eq $startup -or
    $null -eq $toast -or $null -eq $toastServer) {
  throw 'Manifest activation declarations are incomplete.'
}
$extensions = @($manifest.SelectNodes(
  '/f:Package/f:Applications/f:Application/f:Extensions/*', $manager))
$extensionCategories = @($extensions | ForEach-Object { $_.Category })
$expectedExtensionCategories = @(
  'windows.fileTypeAssociation', 'windows.protocol', 'windows.startupTask',
  'windows.toastNotificationActivation', 'windows.comServer'
)
if ($extensions.Count -ne $expectedExtensionCategories.Count -or
    @($extensionCategories | Where-Object {
      $_ -notin $expectedExtensionCategories
    }).Count -ne 0 -or
    @($expectedExtensionCategories | Where-Object {
      $_ -notin $extensionCategories
    }).Count -ne 0) {
  throw "Manifest extensions differ from the BusyMax allowlist: $($extensionCategories -join ', ')"
}
$registeredFileTypes = @($manifest.SelectNodes('//uap:SupportedFileTypes/uap:FileType', $manager))
$registeredProtocols = @($manifest.SelectNodes('//uap:Protocol', $manager))
if ($registeredFileTypes.Count -ne 1 -or $registeredFileTypes[0].InnerText -cne '.ics' -or
    $registeredProtocols.Count -ne 1 -or $registeredProtocols[0].Name -cne 'webcal') {
  throw 'BusyMax may register only the .ics file type and webcal protocol.'
}
$startupExtension = $startup.ParentNode
$startupArguments = $startupExtension.GetAttribute(
  'Parameters', 'http://schemas.microsoft.com/appx/manifest/uap/windows10/10')
if ($startup.Enabled -ne 'false' -or $startupArguments -ne '--start-minimized') {
  throw 'StartupTask must be disabled by default and start minimized.'
}
if ($toast.ToastActivatorCLSID -ne '{7B854A6D-8B2A-45A5-B998-1F51EC5A81D7}') {
  throw 'Toast activator CLSID does not match the committed notification backend.'
}
if ($toastServer.Id -ne $toast.ToastActivatorCLSID -or
    $toastServer.ParentNode.Arguments -ne '----AppNotificationActivationServer') {
  throw 'Toast COM server does not match the activation declaration.'
}
$capabilities = @($manifest.SelectNodes('/f:Package/f:Capabilities/*', $manager) |
  ForEach-Object { $_.Name })
if (@($capabilities | Where-Object { $_ -notin @('internetClient', 'runFullTrust') }).Count -ne 0) {
  throw "Manifest contains an unexpected capability: $($capabilities -join ', ')"
}
foreach ($required in @('internetClient', 'runFullTrust')) {
  if ($required -notin $capabilities) { throw "Missing capability: $required" }
}
if ($manifest.InnerText -match '@@[A-Z_]+@@') { throw 'Manifest placeholders remain.' }
Write-Host "Validated manifest: $ManifestPath"
