BeforeAll {
  . (Join-Path (Split-Path -Parent $PSScriptRoot) 'common.ps1')

  function New-ValidConfig {
    param([bool]$Production = $true)
    return [pscustomobject]@{
      production = $Production
      identityName = 'BusyStack.BusyMax.Owner'
      publisher = 'CN=BusyMax Owner'
      publisherDisplayName = 'BusyMax Owner'
      msixVersion = '1.2.3.0'
      previousMsixVersion = '1.2.2.0'
      privacyPolicyUrl = 'https://busystack.org/privacy'
      supportUrl = 'https://busystack.org/support'
      homepageUrl = 'https://busystack.org'
      googleOAuthClientId = 'google-owner-client-id'
      googleOAuthClientSecret = ''
      microsoftOAuthClientId = 'microsoft-owner-client-id'
      microsoftOAuthAuthorityTenant = 'common'
      fakeData = $false
      developmentBackend = $false
    }
  }

  function New-CiConfig {
    $config = New-ValidConfig -Production $false
    $config.identityName = 'BusyStack.BusyMax.CI'
    $config.publisher = 'CN=BusyMax CI Package'
    $config.publisherDisplayName = 'BusyMax CI'
    $config.msixVersion = '1.0.0.0'
    $config.previousMsixVersion = ''
    $config.googleOAuthClientId = 'busymax-ci-google-client-id'
    $config.microsoftOAuthClientId = 'busymax-ci-microsoft-client-id'
    return $config
  }
}

Describe 'BusyMax Store configuration validation modes' {
  It 'accepts a production Store configuration only in ProductionStore mode' {
    $config = New-ValidConfig
    { Assert-BusyMaxStoreConfig -Config $config -Mode ProductionStore } |
      Should -Not -Throw
    { Assert-BusyMaxStoreConfig -Config $config -Mode CiNonProduction } |
      Should -Throw
  }

  It 'accepts the exact committed CI identity only in CiNonProduction mode' {
    $config = New-CiConfig
    { Assert-BusyMaxStoreConfig -Config $config -Mode CiNonProduction } |
      Should -Not -Throw
    { Assert-BusyMaxStoreConfig -Config $config -Mode ProductionStore } |
      Should -Throw
    { Assert-BusyMaxStoreConfig -Config $config -Mode LocalTestSigning } |
      Should -Throw
    $config.identityName = 'BusyStack.BusyMax.NotTheCommittedCiIdentity'
    { Assert-BusyMaxStoreConfig -Config $config -Mode CiNonProduction } |
      Should -Throw
  }

  It 'accepts owner production identity in LocalTestSigning mode' {
    { Assert-BusyMaxStoreConfig -Config (New-ValidConfig) `
        -Mode LocalTestSigning } | Should -Not -Throw
  }

  It 'rejects placeholders in every mode' {
    $production = New-ValidConfig
    $production.identityName = 'REPLACE_WITH_IDENTITY'
    { Assert-BusyMaxStoreConfig -Config $production -Mode ProductionStore } |
      Should -Throw
    $local = New-ValidConfig
    $local.identityName = 'REPLACE_WITH_IDENTITY'
    { Assert-BusyMaxStoreConfig -Config $local -Mode LocalTestSigning } |
      Should -Throw
    $ci = New-CiConfig
    $ci.supportUrl = 'https://example.com/support'
    { Assert-BusyMaxStoreConfig -Config $ci -Mode CiNonProduction } |
      Should -Throw
  }

  It 'rejects malformed and prohibited MSIX versions' {
    foreach ($invalid in @('1.2.3', '0.2.3.0', '1.2.3.4')) {
      $config = New-ValidConfig
      $config.msixVersion = $invalid
      $config.previousMsixVersion = ''
      { Assert-BusyMaxStoreConfig -Config $config -Mode ProductionStore } |
        Should -Throw -ExpectedMessage "*msixVersion*ProductionStore*"
    }
  }

  It 'rejects non-HTTPS production links' {
    $config = New-ValidConfig
    $config.supportUrl = 'http://busystack.org/support'
    { Assert-BusyMaxStoreConfig -Config $config -Mode ProductionStore } |
      Should -Throw -ExpectedMessage "*supportUrl*ProductionStore*"
  }

  It 'rejects fake data and development backends' {
    $fake = New-ValidConfig
    $fake.fakeData = $true
    { Assert-BusyMaxStoreConfig -Config $fake -Mode ProductionStore } |
      Should -Throw
    $development = New-ValidConfig
    $development.developmentBackend = $true
    { Assert-BusyMaxStoreConfig -Config $development -Mode ProductionStore } |
      Should -Throw
  }

  It 'rejects a mismatched certificate publisher' {
    { Assert-BusyMaxCertificatePublisher -CertificateSubject 'CN=Other' `
        -ManifestPublisher 'CN=BusyMax Owner' } | Should -Throw
    { Assert-BusyMaxCertificatePublisher -CertificateSubject 'CN=BusyMax Owner' `
        -ManifestPublisher 'CN=BusyMax Owner' } | Should -Not -Throw
  }
}
