package com.osimono.android.data

import com.google.firebase.database.DatabaseReference
import com.google.firebase.database.ValueEventListener
import com.google.firebase.database.ktx.getValue
import com.osimono.android.model.UserProfile
import com.osimono.android.util.currentTimestampSeconds
import com.osimono.android.util.int
import com.osimono.android.util.string
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withTimeout

class UserRepository(
    private val database: DatabaseReference,
) {
    fun observeProfile(uid: String): Flow<UserProfile> = callbackFlow {
        val ref = database.child("users").child(uid)
        val listener = ValueEventListenerBuilder(
            onData = { snapshot ->
                trySend(
                    UserProfile(
                        uid = uid,
                        username = snapshot.string("username"),
                        favoriteOshi = snapshot.string("favoriteOshi"),
                        profileImageUrl = snapshot.string("profileImageUrl"),
                        backgroundImageUrl = snapshot.string("backgroundImageUrl"),
                        bio = snapshot.string("bio"),
                        selectedOshiId = snapshot.string("selectedOshiId"),
                        userFlag = snapshot.int("userFlag"),
                    ),
                )
            },
            onError = { close(it.toException()) },
        )
        ref.addValueEventListener(listener)
        awaitClose { ref.removeEventListener(listener) }
    }

    suspend fun ensureUserProfile(uid: String) {
        val ref = database.child("users").child(uid)
        val snapshot = withTimeout(DATABASE_WRITE_TIMEOUT_MS) { ref.get().await() }
        if (!snapshot.exists()) {
            withTimeout(DATABASE_WRITE_TIMEOUT_MS) {
                ref.setValue(
                    mapOf(
                        "uid" to uid,
                        "createdAt" to currentTimestampSeconds(),
                        "userFlag" to 0,
                    ),
                ).await()
            }
        }
    }

    suspend fun updateSelectedOshiId(uid: String, oshiId: String) {
        withTimeout(DATABASE_WRITE_TIMEOUT_MS) {
            database.child("users").child(uid).child("selectedOshiId").setValue(oshiId).await()
        }
    }

    suspend fun updateProfile(uid: String, username: String, favoriteOshi: String) {
        val updates = mutableMapOf<String, Any>(
            "uid" to uid,
        )
        if (username.isNotBlank()) {
            updates["username"] = username
        }
        if (favoriteOshi.isNotBlank()) {
            updates["favoriteOshi"] = favoriteOshi
        }
        withTimeout(DATABASE_WRITE_TIMEOUT_MS) {
            database.child("users").child(uid).updateChildren(updates).await()
        }
    }

    companion object {
        private const val DATABASE_WRITE_TIMEOUT_MS = 5_000L
    }
}
