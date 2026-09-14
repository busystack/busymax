package io.busystack.busymax_android_platform

import android.accounts.Account
import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import android.provider.Settings
import android.text.format.DateFormat
import androidx.core.content.ContextCompat
import com.google.android.gms.auth.GoogleAuthUtil
import com.google.android.gms.auth.api.identity.AuthorizationRequest
import com.google.android.gms.auth.api.identity.AuthorizationResult
import com.google.android.gms.auth.api.identity.ClearTokenRequest
import com.google.android.gms.auth.api.identity.Identity
import com.google.android.gms.auth.api.identity.RevokeAccessRequest
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.common.api.Scope
import com.microsoft.identity.client.AcquireTokenParameters
import com.microsoft.identity.client.AcquireTokenSilentParameters
import com.microsoft.identity.client.AuthenticationCallback
import com.microsoft.identity.client.IAuthenticationResult
import com.microsoft.identity.client.IMultipleAccountPublicClientApplication
import com.microsoft.identity.client.Prompt
import com.microsoft.identity.client.PublicClientApplication
import com.microsoft.identity.client.exception.MsalException
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.util.TimeZone
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.Semaphore
import java.util.concurrent.TimeUnit

/** BusyMax-owned Android integration. Provider refresh tokens never enter Dart. */
class BusymaxAndroidPlatformPlugin : FlutterPlugin,
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler,
    ActivityAware,
    PluginRegistry.ActivityResultListener,
    PluginRegistry.NewIntentListener,
    PluginRegistry.RequestPermissionsResultListener {

    private lateinit var context: Context
    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var eventSink: EventChannel.EventSink? = null
    private val main by lazy { Handler(Looper.getMainLooper()) }
    private val executor = Executors.newCachedThreadPool()
    private var pendingInteractive: PendingInteractive? = null
    private var pendingDocument: PendingDocument? = null
    private var pendingPermission: MethodChannel.Result? = null
    @Volatile private var msal: IMultipleAccountPublicClientApplication? = null
    private var initialActivation: Map<String, Any?>? = null

    private val settingsReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            eventSink?.success(mapOf("kind" to "systemSettingsChanged"))
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL)
        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL)
        channel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
        activePlugins.add(this)
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_TIME_CHANGED)
            addAction(Intent.ACTION_TIMEZONE_CHANGED)
            addAction(Intent.ACTION_LOCALE_CHANGED)
        }
        ContextCompat.registerReceiver(context, settingsReceiver, filter, ContextCompat.RECEIVER_NOT_EXPORTED)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        activePlugins.remove(this)
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        try { context.unregisterReceiver(settingsReceiver) } catch (_: Exception) {}
        executor.shutdown()
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { eventSink = events }
    override fun onCancel(arguments: Any?) { eventSink = null }
    override fun onAttachedToActivity(binding: ActivityPluginBinding) = attachActivity(binding)
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = attachActivity(binding)

    private fun attachActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        activity = binding.activity
        binding.addActivityResultListener(this)
        binding.addOnNewIntentListener(this)
        binding.addRequestPermissionsResultListener(this)
        captureActivation(binding.activity.intent)
    }

    override fun onDetachedFromActivityForConfigChanges() = detachActivity()
    override fun onDetachedFromActivity() = detachActivity()

    private fun detachActivity() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding?.removeOnNewIntentListener(this)
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "currentTimeZoneId" -> result.success(TimeZone.getDefault().id)
            "uses24HourFormat" -> result.success(DateFormat.is24HourFormat(context))
            "googleAuthorizationAvailable" -> result.success(GoogleApiAvailability.getInstance().isGooglePlayServicesAvailable(context) == 0)
            "microsoftAuthorizationAvailable" -> result.success(
                context.resources.getIdentifier("busymax_msal_config", "raw", context.packageName) != 0,
            )
            "authorizeGoogleInteractive" -> authorizeGoogle(call, result, true)
            "authorizeGoogleSilent" -> authorizeGoogle(call, result, false)
            "authorizeMicrosoftInteractive" -> authorizeMicrosoft(call, result, true)
            "authorizeMicrosoftSilent" -> authorizeMicrosoft(call, result, false)
            "bindAuthorization" -> bindAuthorization(call, result)
            "clearRejectedGoogleToken" -> clearGoogleToken(call, result)
            "removeAuthorization" -> removeAuthorization(call, result)
            "cancelInteractiveAuthorization" -> cancelInteractive(result)
            "openDocument" -> openDocument(call, result)
            "readDocumentUri" -> readDocumentUri(call, result)
            "createDocument" -> createDocument(call, result)
            "exportDocumentTree" -> exportDocumentTree(call, result)
            "launchExternalUri" -> launchExternalUri(call, result)
            "hasLocalNetworkAccess" -> result.success(hasLocalNetworkAccess())
            "requestLocalNetworkAccess" -> requestLocalNetworkAccess(result)
            "openNotificationSettings" -> {
                val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                    putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(intent)
                result.success(null)
            }
            "acquireAccountGate" -> acquireAccountGate(call, result)
            "releaseAccountGate" -> releaseAccountGate(call, result)
            "notifyDataChanged" -> {
                activePlugins.forEach { plugin ->
                    plugin.eventSink?.success(mapOf("kind" to "dataChanged"))
                }
                result.success(null)
            }
            "takeInitialActivation" -> {
                val activation = initialActivation
                initialActivation = null
                result.success(activation)
            }
            else -> result.notImplemented()
        }
    }

    private fun authorizeGoogle(call: MethodCall, result: MethodChannel.Result, interactive: Boolean) {
        val scopes = stringList(call.argument<List<*>>("scopes"))
        if (scopes.isEmpty()) return result.error("android/invalid-arguments", "Scopes are required.", null)
        if (interactive && !reserveInteractive("google", result)) return
        val builder = AuthorizationRequest.builder()
            .setRequestedScopes(scopes.map(::Scope))
            .setPrompt(if (interactive) AuthorizationRequest.Prompt.SELECT_ACCOUNT else AuthorizationRequest.Prompt.NOT_SET)
        if (!interactive) {
            val binding = readBinding("google", call.argument<String>("accountId").orEmpty())
            val username = binding?.optString("username")?.takeIf { it.isNotBlank() }
            if (username == null) return result.error("android/auth-interaction-required", "Google authorization must be reconnected.", null)
            builder.setAccount(Account(username, GoogleAuthUtil.GOOGLE_ACCOUNT_TYPE))
        }
        Identity.getAuthorizationClient(context).authorize(builder.build())
            .addOnSuccessListener { authorization ->
                if (authorization.hasResolution()) {
                    val host = activity
                    if (!interactive || host == null) {
                        if (interactive) clearPendingInteractive()
                        result.error("android/auth-interaction-required", "Authorization requires user interaction.", null)
                        return@addOnSuccessListener
                    }
                    try {
                        host.startIntentSenderForResult(authorization.pendingIntent!!.intentSender, GOOGLE_AUTH_REQUEST, null, 0, 0, 0)
                    } catch (error: Exception) {
                        clearPendingInteractive()
                        result.error("android/auth-launch-failed", "Google authorization could not be opened.", safeError(error))
                    }
                } else {
                    if (interactive) clearPendingInteractive()
                    completeGoogleAuthorization(authorization, result)
                }
            }
            .addOnFailureListener { error ->
                if (interactive) clearPendingInteractive()
                result.error("android/google-authorization-failed", "Google authorization failed.", safeError(error))
            }
    }

    private fun completeGoogleAuthorization(authorization: AuthorizationResult, result: MethodChannel.Result) {
        val token = authorization.accessToken.orEmpty()
        val account = authorization.toGoogleSignInAccount()
        val nativeId = account?.id ?: account?.email
        if (token.isBlank() || nativeId.isNullOrBlank()) {
            result.error("android/google-result-invalid", "Google returned an incomplete authorization result.", null)
            return
        }
        result.success(mapOf("accessToken" to token, "scopes" to authorization.grantedScopes, "nativeAccountId" to nativeId, "username" to account?.email))
    }

    private fun authorizeMicrosoft(call: MethodCall, result: MethodChannel.Result, interactive: Boolean) {
        val scopes = stringList(call.argument<List<*>>("scopes"))
        if (scopes.isEmpty()) return result.error("android/invalid-arguments", "Scopes are required.", null)
        if (interactive && !reserveInteractive("microsoft", result)) return
        ensureMsal(
            onSuccess = { application ->
                if (interactive) {
                    val host = activity
                    if (host == null) {
                        clearPendingInteractive()
                        result.error("android/activity-unavailable", "Microsoft sign-in requires a visible Activity.", null)
                        return@ensureMsal
                    }
                    val parameters = AcquireTokenParameters.Builder()
                        .startAuthorizationFromActivity(host)
                        .withScopes(scopes)
                        .withPrompt(Prompt.SELECT_ACCOUNT)
                        .withCallback(object : AuthenticationCallback {
                            override fun onSuccess(authenticationResult: IAuthenticationResult) {
                                if (takePendingInteractive("microsoft") == null) return
                                result.success(msalResult(authenticationResult))
                            }
                            override fun onError(exception: MsalException) {
                                if (takePendingInteractive("microsoft") == null) return
                                result.error("android/microsoft-authorization-failed", "Microsoft authorization failed.", safeError(exception))
                            }
                            override fun onCancel() {
                                if (takePendingInteractive("microsoft") == null) return
                                result.error("android/auth-cancelled", "Microsoft sign-in was cancelled.", null)
                            }
                        }).build()
                    application.acquireToken(parameters)
                } else {
                    val binding = readBinding("microsoft", call.argument<String>("accountId").orEmpty())
                    val nativeId = binding?.optString("nativeAccountId").orEmpty()
                    executor.execute {
                        try {
                            val account = application.accounts.firstOrNull { it.id == nativeId }
                                ?: throw IllegalStateException("Microsoft account is not in the MSAL cache.")
                            val parameters = AcquireTokenSilentParameters.Builder()
                                .withScopes(scopes).forAccount(account).fromAuthority(account.authority).build()
                            postSuccess(result, msalResult(application.acquireTokenSilent(parameters)))
                        } catch (error: Exception) {
                            postError(result, "android/auth-interaction-required", "Microsoft authorization must be reconnected.", error)
                        }
                    }
                }
            },
            onError = { error ->
                if (interactive) clearPendingInteractive()
                result.error("android/microsoft-not-configured", "Microsoft sign-in is not configured for this build.", safeError(error))
            },
        )
    }

    private fun ensureMsal(onSuccess: (IMultipleAccountPublicClientApplication) -> Unit, onError: (Throwable) -> Unit) {
        msal?.let { return onSuccess(it) }
        val resourceId = context.resources.getIdentifier("busymax_msal_config", "raw", context.packageName)
        if (resourceId == 0) return onError(IllegalStateException("Missing generated MSAL configuration."))
        executor.execute {
            try {
                val created = PublicClientApplication.createMultipleAccountPublicClientApplication(context, resourceId)
                msal = created
                main.post { onSuccess(created) }
            } catch (error: Throwable) { main.post { onError(error) } }
        }
    }

    private fun msalResult(token: IAuthenticationResult): Map<String, Any?> = mapOf(
        "accessToken" to token.accessToken,
        "scopes" to token.scope.toList(),
        "nativeAccountId" to token.account.id,
        "username" to token.account.username,
        "authority" to token.account.authority,
        "expiresAtEpochMillis" to token.expiresOn.time,
    )

    private fun bindAuthorization(call: MethodCall, result: MethodChannel.Result) {
        val provider = call.argument<String>("provider").orEmpty()
        val accountId = call.argument<String>("accountId").orEmpty()
        val nativeId = call.argument<String>("nativeAccountId").orEmpty()
        if (provider !in setOf("google", "microsoft") || accountId.isBlank() || nativeId.isBlank()) {
            result.error("android/invalid-arguments", "Authorization binding is incomplete.", null)
            return
        }
        val value = JSONObject().put("provider", provider).put("accountId", accountId)
            .put("nativeAccountId", nativeId).put("username", call.argument<String>("username"))
            .put("authority", call.argument<String>("authority"))
        bindingPreferences().edit().putString(bindingKey(provider, accountId), value.toString()).apply()
        result.success(null)
    }

    private fun clearGoogleToken(call: MethodCall, result: MethodChannel.Result) {
        val token = call.argument<String>("token").orEmpty()
        if (token.isBlank()) return result.success(null)
        Identity.getAuthorizationClient(context).clearToken(ClearTokenRequest.builder().setToken(token).build())
            .addOnSuccessListener { result.success(null) }
            .addOnFailureListener { result.error("android/google-clear-failed", "Rejected Google token could not be cleared.", safeError(it)) }
    }

    private fun removeAuthorization(call: MethodCall, result: MethodChannel.Result) {
        val provider = call.argument<String>("provider").orEmpty()
        val accountId = call.argument<String>("accountId").orEmpty()
        val binding = readBinding(provider, accountId)
        fun removeBinding() { bindingPreferences().edit().remove(bindingKey(provider, accountId)).apply() }
        if (provider == "google" && call.argument<Boolean>("revoke") == true) {
            val username = binding?.optString("username").orEmpty()
            if (username.isBlank()) { removeBinding(); return result.success(null) }
            Identity.getAuthorizationClient(context).revokeAccess(
                RevokeAccessRequest.builder().setAccount(Account(username, GoogleAuthUtil.GOOGLE_ACCOUNT_TYPE)).build(),
            ).addOnSuccessListener { removeBinding(); result.success(null) }
                .addOnFailureListener { result.error("android/google-revoke-failed", "Google access could not be revoked.", safeError(it)) }
            return
        }
        if (provider == "microsoft" && binding != null) {
            val nativeId = binding.optString("nativeAccountId")
            ensureMsal(onSuccess = { application -> executor.execute {
                try {
                    application.accounts.firstOrNull { it.id == nativeId }?.let(application::removeAccount)
                    removeBinding(); postSuccess(result, null)
                } catch (error: Exception) { postError(result, "android/microsoft-remove-failed", "Microsoft account could not be removed.", error) }
            } }, onError = { result.error("android/microsoft-not-configured", "Microsoft sign-in is not configured.", safeError(it)) })
            return
        }
        removeBinding(); result.success(null)
    }

    private fun reserveInteractive(provider: String, result: MethodChannel.Result): Boolean {
        if (activity == null) { result.error("android/activity-unavailable", "Sign-in requires a visible Activity.", null); return false }
        if (pendingInteractive != null) { result.error("android/auth-in-progress", "Another sign-in is already in progress.", null); return false }
        pendingInteractive = PendingInteractive(provider, result)
        return true
    }

    private fun takePendingInteractive(provider: String): PendingInteractive? {
        val pending = pendingInteractive
        if (pending?.provider != provider) return null
        pendingInteractive = null
        return pending
    }

    private fun clearPendingInteractive() { pendingInteractive = null }
    private fun cancelInteractive(result: MethodChannel.Result) {
        val pending = pendingInteractive
        pendingInteractive = null
        pending?.result?.error("android/auth-cancelled", "Sign-in was cancelled.", null)
        result.success(null)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == GOOGLE_AUTH_REQUEST) {
            val pending = takePendingInteractive("google") ?: return true
            if (resultCode != Activity.RESULT_OK || data == null) {
                pending.result.error("android/auth-cancelled", "Google sign-in was cancelled.", null)
                return true
            }
            try { completeGoogleAuthorization(Identity.getAuthorizationClient(context).getAuthorizationResultFromIntent(data), pending.result) }
            catch (error: Exception) { pending.result.error("android/google-authorization-failed", "Google authorization failed.", safeError(error)) }
            return true
        }
        val pending = pendingDocument ?: return false
        if (requestCode != pending.requestCode) return false
        pendingDocument = null
        if (resultCode != Activity.RESULT_OK || data?.data == null) { pending.result.success(null); return true }
        val uri = data.data!!
        try {
            when (pending) {
                is PendingDocument.Open -> finishOpenDocument(uri, pending)
                is PendingDocument.Create -> finishCreateDocument(uri, pending)
                is PendingDocument.Tree -> finishTreeExport(uri, pending)
            }
        } catch (error: Exception) { pending.result.error("android/document-failed", "The selected document could not be processed.", safeError(error)) }
        return true
    }

    private fun openDocument(call: MethodCall, result: MethodChannel.Result) {
        val host = requireDocumentActivity(result) ?: return
        if (pendingDocument != null) return result.error("android/document-in-progress", "A document picker is already open.", null)
        val types = stringList(call.argument<List<*>>("mimeTypes")).ifEmpty { listOf("text/calendar") }
        val max = (call.argument<Number>("maximumBytes")?.toLong() ?: MAX_IMPORT_BYTES).coerceIn(1, MAX_IMPORT_BYTES)
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE); type = if (types.size == 1) types.first() else "*/*"
            if (types.size > 1) putExtra(Intent.EXTRA_MIME_TYPES, types.toTypedArray())
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
        }
        pendingDocument = PendingDocument.Open(result, max)
        host.startActivityForResult(intent, OPEN_DOCUMENT_REQUEST)
    }

    private fun finishOpenDocument(uri: Uri, pending: PendingDocument.Open) {
        tryPersistPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        pending.result.success(readDocument(uri, pending.maximumBytes))
    }

    private fun readDocumentUri(call: MethodCall, result: MethodChannel.Result) {
        val uri = Uri.parse(call.argument<String>("uri").orEmpty())
        if (uri.scheme != "content") return result.error("android/invalid-document-uri", "Only content document URIs are supported.", null)
        val max = (call.argument<Number>("maximumBytes")?.toLong() ?: MAX_IMPORT_BYTES).coerceIn(1, MAX_IMPORT_BYTES)
        try { result.success(readDocument(uri, max)) }
        catch (error: Exception) { result.error("android/document-failed", "The shared document could not be read.", safeError(error)) }
    }

    private fun readDocument(uri: Uri, maximumBytes: Long): Map<String, Any?> {
        val bytes = context.contentResolver.openInputStream(uri)?.use { input ->
            val output = ByteArrayOutputStream(); val buffer = ByteArray(16 * 1024); var total = 0L
            while (true) { val count = input.read(buffer); if (count < 0) break; total += count
                if (total > maximumBytes) throw IllegalArgumentException("Document exceeds the import size limit.")
                output.write(buffer, 0, count) }
            output.toByteArray()
        } ?: throw IllegalArgumentException("Document could not be opened.")
        return mapOf("uri" to uri.toString(), "bytes" to bytes, "name" to displayName(uri), "mimeType" to context.contentResolver.getType(uri))
    }

    private fun createDocument(call: MethodCall, result: MethodChannel.Result) {
        val host = requireDocumentActivity(result) ?: return
        if (pendingDocument != null) return result.error("android/document-in-progress", "A document picker is already open.", null)
        val bytes = call.argument<ByteArray>("bytes") ?: return result.error("android/invalid-arguments", "Export bytes are required.", null)
        if (bytes.size > MAX_EXPORT_BYTES) return result.error("android/export-too-large", "Export exceeds the size limit.", null)
        pendingDocument = PendingDocument.Create(result, bytes)
        host.startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE); type = call.argument<String>("mimeType")?.takeIf { it.isNotBlank() } ?: "text/calendar"
            putExtra(Intent.EXTRA_TITLE, safeFileName(call.argument<String>("suggestedName").orEmpty(), "busymax.ics"))
            addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
        }, CREATE_DOCUMENT_REQUEST)
    }

    private fun finishCreateDocument(uri: Uri, pending: PendingDocument.Create) {
        tryPersistPermission(uri, Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
        context.contentResolver.openOutputStream(uri, "wt")?.use { it.write(pending.bytes) }
            ?: throw IllegalArgumentException("Document could not be created.")
        pending.result.success(uri.toString())
    }

    private fun exportDocumentTree(call: MethodCall, result: MethodChannel.Result) {
        val host = requireDocumentActivity(result) ?: return
        if (pendingDocument != null) return result.error("android/document-in-progress", "A document picker is already open.", null)
        val raw = call.argument<List<*>>("resources") ?: emptyList<Any>()
        if (raw.size > MAX_EXPORT_RESOURCES) return result.error("android/export-too-large", "Export contains too many resources.", null)
        var total = 0L
        val resources = raw.mapIndexed { index, value ->
            val map = value as? Map<*, *> ?: throw IllegalArgumentException("Invalid export resource.")
            val bytes = map["bytes"] as? ByteArray ?: throw IllegalArgumentException("Missing export bytes.")
            total += bytes.size
            ExportResource(safeFileName(map["name"]?.toString().orEmpty(), "resource-${index + 1}.ics"), bytes)
        }
        if (total > MAX_TREE_EXPORT_BYTES) return result.error("android/export-too-large", "Export exceeds the size limit.", null)
        pendingDocument = PendingDocument.Tree(result, safeFileName(call.argument<String>("folderName").orEmpty(), "BusyMax export"), resources)
        host.startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
        }, OPEN_TREE_REQUEST)
    }

    private fun finishTreeExport(uri: Uri, pending: PendingDocument.Tree) {
        tryPersistPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
        val resolver = context.contentResolver
        val root = DocumentsContract.buildDocumentUriUsingTree(uri, DocumentsContract.getTreeDocumentId(uri))
        val folder = DocumentsContract.createDocument(resolver, root, DocumentsContract.Document.MIME_TYPE_DIR, pending.folderName)
            ?: throw IllegalStateException("Could not create the export folder.")
        for (resource in pending.resources) {
            val output = DocumentsContract.createDocument(resolver, folder, "text/calendar", resource.name)
                ?: throw IllegalStateException("Could not create ${resource.name}.")
            resolver.openOutputStream(output, "wt")?.use { it.write(resource.bytes) }
                ?: throw IllegalStateException("Could not write ${resource.name}.")
        }
        pending.result.success(folder.toString())
    }

    private fun launchExternalUri(call: MethodCall, result: MethodChannel.Result) {
        val uri = Uri.parse(call.argument<String>("uri").orEmpty())
        if (uri.scheme?.lowercase() !in setOf("https", "http", "geo", "mailto")) return result.error("android/uri-not-allowed", "This link type is not allowed.", null)
        val intent = Intent(Intent.ACTION_VIEW, uri).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (intent.resolveActivity(context.packageManager) == null) return result.success(false)
        context.startActivity(intent); result.success(true)
    }

    private fun hasLocalNetworkAccess() = Build.VERSION.SDK_INT < 37 || ContextCompat.checkSelfPermission(context, ACCESS_LOCAL_NETWORK) == PackageManager.PERMISSION_GRANTED
    private fun requestLocalNetworkAccess(result: MethodChannel.Result) {
        if (hasLocalNetworkAccess()) return result.success(true)
        val host = activity ?: return result.error("android/activity-unavailable", "Local network permission requires a visible Activity.", null)
        if (pendingPermission != null) return result.error("android/permission-in-progress", "Another permission request is active.", null)
        pendingPermission = result
        host.requestPermissions(arrayOf(ACCESS_LOCAL_NETWORK), LOCAL_NETWORK_REQUEST)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray): Boolean {
        if (requestCode != LOCAL_NETWORK_REQUEST) return false
        val result = pendingPermission ?: return true
        pendingPermission = null; result.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED); return true
    }

    private fun acquireAccountGate(call: MethodCall, result: MethodChannel.Result) {
        val accountId = call.argument<String>("accountId").orEmpty()
        val timeout = (call.argument<Number>("timeoutMillis")?.toLong() ?: 30_000L).coerceIn(1_000L, 120_000L)
        if (accountId.isBlank()) return result.error("android/invalid-arguments", "Account id is required.", null)
        executor.execute {
            val semaphore = accountGates.computeIfAbsent(accountId) { Semaphore(1, true) }
            try {
                if (!semaphore.tryAcquire(timeout, TimeUnit.MILLISECONDS)) return@execute postError(result, "android/account-busy", "This account is already synchronizing.", null)
                val lease = UUID.randomUUID().toString(); leases[lease] = semaphore; postSuccess(result, lease)
            } catch (error: InterruptedException) {
                Thread.currentThread().interrupt(); postError(result, "android/account-gate-interrupted", "Account synchronization was interrupted.", error)
            }
        }
    }

    private fun releaseAccountGate(call: MethodCall, result: MethodChannel.Result) { leases.remove(call.argument<String>("leaseId"))?.release(); result.success(null) }
    override fun onNewIntent(intent: Intent): Boolean = captureActivation(intent)
    private fun captureActivation(intent: Intent?): Boolean {
        if (intent == null) return false
        val activation = when (intent.action) {
            Intent.ACTION_VIEW -> intent.data?.let { mapOf("kind" to "document", "uri" to it.toString(), "mimeType" to intent.type) }
            Intent.ACTION_SEND -> sharedStreamUri(intent)?.let { mapOf("kind" to "document", "uri" to it.toString(), "mimeType" to intent.type) }
            else -> null
        } ?: return false
        intent.action = null
        initialActivation = activation; eventSink?.success(activation); return true
    }

    private fun sharedStreamUri(intent: Intent): Uri? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
    } else {
        @Suppress("DEPRECATION")
        intent.getParcelableExtra(Intent.EXTRA_STREAM)
    }

    private fun requireDocumentActivity(result: MethodChannel.Result): Activity? = activity.also {
        if (it == null) result.error("android/activity-unavailable", "A document picker requires a visible Activity.", null)
    }
    private fun bindingPreferences() = context.getSharedPreferences("busymax_android_authorization", Context.MODE_PRIVATE)
    private fun bindingKey(provider: String, accountId: String) = "$provider|$accountId"
    private fun readBinding(provider: String, accountId: String): JSONObject? = bindingPreferences().getString(bindingKey(provider, accountId), null)?.let {
        try { JSONObject(it) } catch (_: Exception) { null }
    }
    private fun tryPersistPermission(uri: Uri, flags: Int) { try { context.contentResolver.takePersistableUriPermission(uri, flags) } catch (_: Exception) {} }
    private fun displayName(uri: Uri): String? {
        var cursor: Cursor? = null
        return try { cursor = context.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null); if (cursor != null && cursor.moveToFirst()) cursor.getString(0) else null }
        finally { cursor?.close() }
    }
    private fun safeFileName(value: String, fallback: String): String = value.trim().replace(Regex("[\\\\/:*?\"<>|\\p{Cntrl}]"), "_").take(120).ifBlank { fallback }
    private fun stringList(values: List<*>?) = values.orEmpty().mapNotNull { it?.toString()?.trim()?.takeIf(String::isNotEmpty) }.distinct()
    private fun safeError(error: Throwable) = error.javaClass.simpleName
    private fun postSuccess(result: MethodChannel.Result, value: Any?) { main.post { result.success(value) } }
    private fun postError(result: MethodChannel.Result, code: String, message: String, error: Throwable?) { main.post { result.error(code, message, error?.let(::safeError)) } }

    private data class PendingInteractive(val provider: String, val result: MethodChannel.Result)
    private data class ExportResource(val name: String, val bytes: ByteArray)
    private sealed class PendingDocument(val result: MethodChannel.Result, val requestCode: Int) {
        class Open(result: MethodChannel.Result, val maximumBytes: Long) : PendingDocument(result, OPEN_DOCUMENT_REQUEST)
        class Create(result: MethodChannel.Result, val bytes: ByteArray) : PendingDocument(result, CREATE_DOCUMENT_REQUEST)
        class Tree(result: MethodChannel.Result, val folderName: String, val resources: List<ExportResource>) : PendingDocument(result, OPEN_TREE_REQUEST)
    }

    companion object {
        private const val METHOD_CHANNEL = "io.busystack.busymax/android"
        private const val EVENT_CHANNEL = "io.busystack.busymax/events"
        private const val GOOGLE_AUTH_REQUEST = 7101
        private const val OPEN_DOCUMENT_REQUEST = 7102
        private const val CREATE_DOCUMENT_REQUEST = 7103
        private const val OPEN_TREE_REQUEST = 7104
        private const val LOCAL_NETWORK_REQUEST = 7105
        private const val ACCESS_LOCAL_NETWORK = "android.permission.ACCESS_LOCAL_NETWORK"
        private const val MAX_IMPORT_BYTES = 16L * 1024L * 1024L
        private const val MAX_EXPORT_BYTES = 32 * 1024 * 1024
        private const val MAX_TREE_EXPORT_BYTES = 64L * 1024L * 1024L
        private const val MAX_EXPORT_RESOURCES = 512
        private val accountGates = ConcurrentHashMap<String, Semaphore>()
        private val leases = ConcurrentHashMap<String, Semaphore>()
        private val activePlugins = ConcurrentHashMap.newKeySet<BusymaxAndroidPlatformPlugin>()
    }
}
