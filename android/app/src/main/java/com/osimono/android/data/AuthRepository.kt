package com.osimono.android.data

import com.google.firebase.auth.FirebaseAuth
import kotlinx.coroutines.tasks.await

class AuthRepository(
    private val auth: FirebaseAuth,
) {
    suspend fun ensureAnonymousUser(): String {
        auth.currentUser?.uid?.let { return it }
        val result = auth.signInAnonymously().await()
        return checkNotNull(result.user?.uid) { "Anonymous sign-in failed." }
    }

    fun currentUserId(): String? = auth.currentUser?.uid
}
