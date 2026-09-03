package com.osimono.android.data

import android.app.Application
import android.net.Uri
import com.google.firebase.database.DatabaseReference
import com.google.firebase.database.ValueEventListener
import com.google.firebase.storage.FirebaseStorage
import com.osimono.android.model.EventLocation
import com.osimono.android.util.currentTimestampSeconds
import com.osimono.android.util.double
import com.osimono.android.util.int
import com.osimono.android.util.string
import java.io.File
import java.io.FileOutputStream
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withTimeout

class LocationRepository(
    private val database: DatabaseReference,
    private val storage: FirebaseStorage,
    private val application: Application,
) {
    fun observeLocations(uid: String, oshiId: String): Flow<List<EventLocation>> = callbackFlow {
        val ref = database.child("locations").child(uid).child(oshiId)
        val listener = ValueEventListenerBuilder(
            onData = { snapshot ->
                val locations = snapshot.children.mapNotNull { child ->
                    val title = child.string("title") ?: return@mapNotNull null
                    val latitude = child.double("latitude") ?: return@mapNotNull null
                    val longitude = child.double("longitude") ?: return@mapNotNull null
                    val category = child.string("category") ?: return@mapNotNull null
                    EventLocation(
                        id = child.key.orEmpty(),
                        title = title,
                        latitude = latitude,
                        longitude = longitude,
                        imageURL = child.string("imageURL"),
                        category = category,
                        ratingSum = child.int("ratingSum") ?: 0,
                        note = child.string("note"),
                        createdAt = child.double("createdAt"),
                        oshiId = child.string("oshiId"),
                        locationAddress = child.string("locationAddress"),
                    )
                }.sortedByDescending { it.createdAt ?: 0.0 }
                trySend(locations)
            },
            onError = { close(it.toException()) },
        )
        ref.addValueEventListener(listener)
        awaitClose { ref.removeEventListener(listener) }
    }

    suspend fun upsertLocation(
        uid: String,
        oshiId: String,
        location: EventLocation,
        imageUri: Uri?,
    ): EventLocation {
        var updated = if (location.createdAt == null) {
            location.copy(createdAt = currentTimestampSeconds(), oshiId = oshiId)
        } else {
            location.copy(oshiId = oshiId)
        }

        if (imageUri != null) {
            updated = updated.copy(
                imageURL = uploadImage("location_images/$uid/$oshiId/${location.id}.jpg", imageUri),
            )
        }

        withTimeout(DATABASE_WRITE_TIMEOUT_MS) {
            database.child("locations").child(uid).child(oshiId).child(updated.id).setValue(updated.toMap()).await()
        }
        return updated
    }

    private suspend fun uploadImage(path: String, uri: Uri): String {
        if (uri.scheme == "file") {
            return persistLocalImage(path, uri)
        }

        return runCatching {
            withTimeout(STORAGE_UPLOAD_TIMEOUT_MS) {
                val ref = storage.reference.child(path)
                ref.putFile(uri).await()
                ref.downloadUrl.await().toString()
            }
        }.getOrElse {
            persistLocalImage(path, uri)
        }
    }

    private fun persistLocalImage(
        path: String,
        uri: Uri,
    ): String {
        val offlineDir = File(application.filesDir, "offline-images").apply { mkdirs() }
        val safeName = path.replace("/", "_")
        val outputFile = File(offlineDir, safeName)
        val inputStream = when (uri.scheme) {
            "file" -> requireNotNull(uri.path).let(::File).inputStream()
            else -> application.contentResolver.openInputStream(uri)
        } ?: error("画像を読み込めませんでした")

        inputStream.use { input ->
            FileOutputStream(outputFile).use { output ->
                input.copyTo(output)
            }
        }
        return Uri.fromFile(outputFile).toString()
    }

    companion object {
        private const val STORAGE_UPLOAD_TIMEOUT_MS = 6_000L
        private const val DATABASE_WRITE_TIMEOUT_MS = 5_000L
    }

    private fun EventLocation.toMap(): Map<String, Any> = buildMap {
        put("id", id)
        put("title", title)
        put("latitude", latitude)
        put("longitude", longitude)
        put("category", category)
        put("ratingSum", ratingSum)
        oshiId?.let { put("oshiId", it) }
        imageURL?.takeIf { it.isNotBlank() }?.let { put("imageURL", it) }
        note?.takeIf { it.isNotBlank() }?.let { put("note", it) }
        createdAt?.let { put("createdAt", it) }
        locationAddress?.takeIf { it.isNotBlank() }?.let { put("locationAddress", it) }
    }
}
