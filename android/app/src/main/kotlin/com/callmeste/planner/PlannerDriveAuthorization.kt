package com.callmeste.planner

import android.accounts.Account
import android.app.Activity
import android.content.Intent
import com.google.android.gms.auth.api.identity.AuthorizationRequest
import com.google.android.gms.auth.api.identity.AuthorizationResult
import com.google.android.gms.auth.api.identity.Identity
import com.google.android.gms.auth.api.identity.RevokeAccessRequest
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.common.api.ApiException
import com.google.android.gms.common.api.Scope
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

class PlannerDriveAuthorization(private val activity: Activity) {
    private val requestCode = 5048
    private val scope = Scope("https://www.googleapis.com/auth/drive.appdata")
    private var pending: MethodChannel.Result? = null

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, "planner/drive_auth").setMethodCallHandler { call, reply ->
            val email = call.argument<String>("email")
            when (call.method) {
                "authorize" -> authorize(email, call.argument<Boolean>("interactive") == true, reply)
                "revoke" -> {
                    if (email == null) {
                        reply.success(null)
                    } else {
                        val request = RevokeAccessRequest.builder()
                            .setAccount(Account(email, "com.google"))
                            .setScopes(listOf(scope)).build()
                        Identity.getAuthorizationClient(activity).revokeAccess(request)
                            .addOnSuccessListener { reply.success(null) }
                            .addOnFailureListener { failure(reply, it) }
                    }
                }
                else -> reply.notImplemented()
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun authorize(email: String?, interactive: Boolean, reply: MethodChannel.Result) {
        if (pending != null) {
            reply.error("busy", "Autorizzazione Google già in corso.", null)
            return
        }
        if (GoogleApiAvailability.getInstance().isGooglePlayServicesAvailable(activity)
            != ConnectionResult.SUCCESS) {
            reply.error("play_services", "Servono Google Play Services aggiornati.", null)
            return
        }
        val builder = AuthorizationRequest.builder().setRequestedScopes(listOf(scope))
        if (email != null) builder.setAccount(Account(email, "com.google"))
        pending = reply
        Identity.getAuthorizationClient(activity).authorize(builder.build())
            .addOnSuccessListener { result ->
                val resolution = result.pendingIntent
                if (resolution == null) {
                    finish(result)
                } else if (!interactive) {
                    pending = null
                    reply.error("consent_required", "Apri Sincronizzazione e ricollega Google Drive.", null)
                } else {
                    try {
                        activity.startIntentSenderForResult(resolution.intentSender, requestCode, null, 0, 0, 0)
                    } catch (error: Exception) {
                        pending = null
                        failure(reply, error)
                    }
                }
            }
            .addOnFailureListener {
                pending = null
                failure(reply, it)
            }
    }

    fun complete(code: Int, resultCode: Int, data: Intent?) {
        if (code != requestCode) return
        val reply = pending ?: return
        if (resultCode != Activity.RESULT_OK || data == null) {
            pending = null
            reply.error("cancelled", "Collegamento a Google Drive annullato.", null)
            return
        }
        try {
            finish(Identity.getAuthorizationClient(activity).getAuthorizationResultFromIntent(data))
        } catch (error: ApiException) {
            pending = null
            failure(reply, error)
        }
    }

    private fun finish(result: AuthorizationResult) {
        val reply = pending ?: return
        pending = null
        val token = result.accessToken
        if (token.isNullOrEmpty() || !result.grantedScopes.contains(scope.scopeUri)) {
            reply.error("scope", "Consenti a Planner l’accesso alla sua cartella su Drive.", null)
        } else {
            reply.success(token)
        }
    }

    private fun failure(reply: MethodChannel.Result, error: Exception) {
        val status = (error as? ApiException)?.statusCode
        val detail = if (status != null) " (Google $status)" else ""
        reply.error("google_auth", "Autorizzazione Google Drive non riuscita$detail.", null)
    }
}
