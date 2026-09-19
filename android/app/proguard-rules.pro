# Flutter plugins ship their own consumer rules. Keep only the entrypoints that
# Android or MSAL invokes by class name after shrinking.
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }
-keep class com.microsoft.identity.client.BrowserTabActivity { *; }

# Nimbus exposes optional PEM/Bouncy Castle helpers that MSAL's Android token
# path does not call. Bouncy Castle is intentionally not bundled just to
# satisfy those unused signatures.
-dontwarn org.bouncycastle.asn1.ASN1Encodable
-dontwarn org.bouncycastle.asn1.pkcs.PrivateKeyInfo
-dontwarn org.bouncycastle.asn1.x509.AlgorithmIdentifier
-dontwarn org.bouncycastle.asn1.x509.SubjectPublicKeyInfo
-dontwarn org.bouncycastle.cert.X509CertificateHolder
-dontwarn org.bouncycastle.cert.jcajce.JcaX509CertificateHolder
-dontwarn org.bouncycastle.jce.provider.BouncyCastleProvider
-dontwarn org.bouncycastle.openssl.PEMKeyPair
-dontwarn org.bouncycastle.openssl.PEMParser
-dontwarn org.bouncycastle.openssl.jcajce.JcaPEMKeyConverter
