package com.osimono.android.data

import android.app.Application
import android.net.Uri
import com.google.firebase.database.DatabaseReference
import com.google.firebase.database.ValueEventListener
import com.google.firebase.storage.FirebaseStorage
import com.osimono.android.model.Oshi
import com.osimono.android.util.currentTimestampSeconds
import com.osimono.android.util.double
import com.osimono.android.util.int
import com.osimono.android.util.string
import com.osimono.android.util.stringList
import java.io.File
import java.io.FileOutputStream
import kotlinx.coroutines.Job
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeout
import org.json.JSONArray
import org.json.JSONObject

class OshiRepository(
    private val database: DatabaseReference,
    private val storage: FirebaseStorage,
    private val application: Application,
) {
    private val localOshiCache = MutableStateFlow<Map<String, List<Oshi>>>(emptyMap())

    fun observeOshis(uid: String): Flow<List<Oshi>> = callbackFlow {
        var remoteOshis: List<Oshi> = emptyList()
        val cachedOshis = loadCachedOshis(uid)
        localOshiCache.value = localOshiCache.value + (uid to cachedOshis)
        trySend(cachedOshis)

        val localJob: Job = launch {
            localOshiCache.collect { cache ->
                trySend(mergeOshis(remoteOshis, cache[uid].orEmpty()))
            }
        }

        val ref = database.child("oshis").child(uid)
        val listener = ValueEventListenerBuilder(
            onData = { snapshot ->
                remoteOshis = snapshot.children.map { child ->
                    Oshi(
                        id = child.key.orEmpty(),
                        name = child.string("name").orEmpty(),
                        imageUrl = child.string("imageUrl"),
                        backgroundImageUrl = child.string("backgroundImageUrl"),
                        memo = child.string("memo"),
                        createdAt = child.double("createdAt"),
                        personality = child.string("personality"),
                        interests = child.stringList("interests"),
                        speakingStyle = child.string("speaking_style"),
                        birthday = child.string("birthday"),
                        height = child.int("height"),
                        favoriteColor = child.string("favorite_color"),
                        favoriteFood = child.string("favorite_food"),
                        dislikedFood = child.string("disliked_food"),
                        hometown = child.string("hometown"),
                        gender = child.string("gender"),
                        userNickname = child.string("user_nickname"),
                        relationshipStatus = child.string("relationship_status"),
                        relationshipDetail = child.string("relationship_detail"),
                        sharedMemory = child.string("shared_memory"),
                        signaturePhrase = child.string("signature_phrase"),
                        conversationTopics = child.stringList("conversation_topics"),
                        forbiddenTopics = child.stringList("forbidden_topics"),
                        preferredLanguage = child.string("preferred_language"),
                    )
                }.sortedByDescending { it.createdAt ?: 0.0 }
                val merged = mergeOshis(remoteOshis, localOshiCache.value[uid].orEmpty())
                persistCachedOshis(uid, merged)
                localOshiCache.value = localOshiCache.value + (uid to merged)
            },
            onError = { close(it.toException()) },
        )
        ref.addValueEventListener(listener)
        awaitClose {
            localJob.cancel()
            ref.removeEventListener(listener)
        }
    }

    suspend fun upsertOshi(
        uid: String,
        oshi: Oshi,
        profileImageUri: Uri?,
        backgroundImageUri: Uri?,
    ): Oshi {
        var updated = if (oshi.createdAt == null) {
            oshi.copy(createdAt = currentTimestampSeconds())
        } else {
            oshi
        }

        if (profileImageUri != null) {
            updated = updated.copy(
                imageUrl = uploadImage("oshis/$uid/${oshi.id}/profile.jpg", profileImageUri),
            )
        }

        if (backgroundImageUri != null) {
            updated = updated.copy(
                backgroundImageUrl = uploadImage("oshis/$uid/${oshi.id}/background.jpg", backgroundImageUri),
            )
        }

        cacheOshi(uid, updated)
        runCatching {
            withTimeout(DATABASE_WRITE_TIMEOUT_MS) {
                database.child("oshis").child(uid).child(updated.id).setValue(updated.toMap()).await()
            }
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

    private fun cacheOshi(uid: String, oshi: Oshi) {
        val current = localOshiCache.value[uid] ?: loadCachedOshis(uid)
        val merged = current
            .filterNot { it.id == oshi.id }
            .plus(oshi)
            .sortedByDescending { it.createdAt ?: 0.0 }
        persistCachedOshis(uid, merged)
        localOshiCache.value = localOshiCache.value + (uid to merged)
    }

    private fun mergeOshis(
        remoteOshis: List<Oshi>,
        localOshis: List<Oshi>,
    ): List<Oshi> {
        val merged = linkedMapOf<String, Oshi>()
        remoteOshis.forEach { merged[it.id] = it }
        localOshis.forEach { merged[it.id] = it }
        return merged.values.sortedByDescending { it.createdAt ?: 0.0 }
    }

    private fun loadCachedOshis(uid: String): List<Oshi> {
        val file = cachedOshisFile(uid)
        if (!file.exists()) return emptyList()
        return runCatching {
            val json = JSONArray(file.readText())
            buildList {
                for (index in 0 until json.length()) {
                    val objectJson = json.optJSONObject(index) ?: continue
                    add(objectJson.toOshi())
                }
            }
        }.getOrDefault(emptyList())
    }

    private fun persistCachedOshis(
        uid: String,
        oshis: List<Oshi>,
    ) {
        val file = cachedOshisFile(uid)
        file.parentFile?.mkdirs()
        val json = JSONArray()
        oshis.forEach { json.put(it.toJson()) }
        file.writeText(json.toString())
    }

    private fun cachedOshisFile(uid: String): File = File(application.filesDir, "offline-cache/oshis_$uid.json")

    companion object {
        private const val STORAGE_UPLOAD_TIMEOUT_MS = 6_000L
        private const val DATABASE_WRITE_TIMEOUT_MS = 5_000L
    }

    private fun Oshi.toMap(): Map<String, Any> = buildMap {
        put("id", id)
        put("name", name)
        createdAt?.let { put("createdAt", it) }
        imageUrl?.takeIf { it.isNotBlank() }?.let { put("imageUrl", it) }
        backgroundImageUrl?.takeIf { it.isNotBlank() }?.let { put("backgroundImageUrl", it) }
        memo?.takeIf { it.isNotBlank() }?.let { put("memo", it) }
        personality?.takeIf { it.isNotBlank() }?.let { put("personality", it) }
        interests?.takeIf { it.isNotEmpty() }?.let { put("interests", it) }
        speakingStyle?.takeIf { it.isNotBlank() }?.let { put("speaking_style", it) }
        birthday?.takeIf { it.isNotBlank() }?.let { put("birthday", it) }
        height?.let { put("height", it) }
        favoriteColor?.takeIf { it.isNotBlank() }?.let { put("favorite_color", it) }
        favoriteFood?.takeIf { it.isNotBlank() }?.let { put("favorite_food", it) }
        dislikedFood?.takeIf { it.isNotBlank() }?.let { put("disliked_food", it) }
        hometown?.takeIf { it.isNotBlank() }?.let { put("hometown", it) }
        gender?.takeIf { it.isNotBlank() }?.let { put("gender", it) }
        userNickname?.takeIf { it.isNotBlank() }?.let { put("user_nickname", it) }
        relationshipStatus?.takeIf { it.isNotBlank() }?.let { put("relationship_status", it) }
        relationshipDetail?.takeIf { it.isNotBlank() }?.let { put("relationship_detail", it) }
        sharedMemory?.takeIf { it.isNotBlank() }?.let { put("shared_memory", it) }
        signaturePhrase?.takeIf { it.isNotBlank() }?.let { put("signature_phrase", it) }
        conversationTopics?.takeIf { it.isNotEmpty() }?.let { put("conversation_topics", it) }
        forbiddenTopics?.takeIf { it.isNotEmpty() }?.let { put("forbidden_topics", it) }
        preferredLanguage?.takeIf { it.isNotBlank() }?.let { put("preferred_language", it) }
    }

    private fun Oshi.toJson(): JSONObject = JSONObject().apply {
        put("id", id)
        put("name", name)
        putOpt("imageUrl", imageUrl)
        putOpt("backgroundImageUrl", backgroundImageUrl)
        putOpt("memo", memo)
        putOpt("createdAt", createdAt)
        putOpt("personality", personality)
        putOpt("speakingStyle", speakingStyle)
        putOpt("birthday", birthday)
        putOpt("height", height)
        putOpt("favoriteColor", favoriteColor)
        putOpt("favoriteFood", favoriteFood)
        putOpt("dislikedFood", dislikedFood)
        putOpt("hometown", hometown)
        putOpt("gender", gender)
        putOpt("userNickname", userNickname)
        putOpt("relationshipStatus", relationshipStatus)
        putOpt("relationshipDetail", relationshipDetail)
        putOpt("sharedMemory", sharedMemory)
        putOpt("signaturePhrase", signaturePhrase)
        putOpt("preferredLanguage", preferredLanguage)
        val interestsArray = JSONArray()
        interests.orEmpty().forEach(interestsArray::put)
        put("interests", interestsArray)
        val conversationTopicsArray = JSONArray()
        conversationTopics.orEmpty().forEach(conversationTopicsArray::put)
        put("conversationTopics", conversationTopicsArray)
        val forbiddenTopicsArray = JSONArray()
        forbiddenTopics.orEmpty().forEach(forbiddenTopicsArray::put)
        put("forbiddenTopics", forbiddenTopicsArray)
    }

    private fun JSONObject.toOshi(): Oshi = Oshi(
        id = optString("id"),
        name = optString("name"),
        imageUrl = optString("imageUrl").ifBlank { null },
        backgroundImageUrl = optString("backgroundImageUrl").ifBlank { null },
        memo = optString("memo").ifBlank { null },
        createdAt = optDouble("createdAt").takeUnless { it.isNaN() },
        personality = optString("personality").ifBlank { null },
        interests = optJSONArray("interests")
            ?.let { array ->
                buildList {
                    for (index in 0 until array.length()) {
                        array.optString(index)?.takeIf { it.isNotBlank() }?.let(::add)
                    }
                }.takeIf { it.isNotEmpty() }
            },
        speakingStyle = optString("speakingStyle").ifBlank { null },
        birthday = optString("birthday").ifBlank { null },
        height = optInt("height").takeUnless { it == 0 && !has("height") },
        favoriteColor = optString("favoriteColor").ifBlank { null },
        favoriteFood = optString("favoriteFood").ifBlank { null },
        dislikedFood = optString("dislikedFood").ifBlank { null },
        hometown = optString("hometown").ifBlank { null },
        gender = optString("gender").ifBlank { null },
        userNickname = optString("userNickname").ifBlank { null },
        relationshipStatus = optString("relationshipStatus").ifBlank { null },
        relationshipDetail = optString("relationshipDetail").ifBlank { null },
        sharedMemory = optString("sharedMemory").ifBlank { null },
        signaturePhrase = optString("signaturePhrase").ifBlank { null },
        conversationTopics = optJSONArray("conversationTopics")
            ?.let { array ->
                buildList {
                    for (index in 0 until array.length()) {
                        array.optString(index)?.takeIf { it.isNotBlank() }?.let(::add)
                    }
                }.takeIf { it.isNotEmpty() }
            },
        forbiddenTopics = optJSONArray("forbiddenTopics")
            ?.let { array ->
                buildList {
                    for (index in 0 until array.length()) {
                        array.optString(index)?.takeIf { it.isNotBlank() }?.let(::add)
                    }
                }.takeIf { it.isNotEmpty() }
            },
        preferredLanguage = optString("preferredLanguage").ifBlank { null },
    )
}
