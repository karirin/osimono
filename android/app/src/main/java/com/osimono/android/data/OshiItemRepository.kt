package com.osimono.android.data

import android.app.Application
import android.net.Uri
import com.google.firebase.database.DatabaseReference
import com.google.firebase.database.ValueEventListener
import com.google.firebase.storage.FirebaseStorage
import com.osimono.android.model.OshiItem
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

class OshiItemRepository(
    private val database: DatabaseReference,
    private val storage: FirebaseStorage,
    private val application: Application,
) {
    private val localItemCache = MutableStateFlow<Map<String, List<OshiItem>>>(emptyMap())

    fun observeItems(uid: String, oshiId: String): Flow<List<OshiItem>> = callbackFlow {
        val cacheKey = cacheKey(uid, oshiId)
        var remoteItems: List<OshiItem> = emptyList()
        val cachedItems = loadCachedItems(uid, oshiId)
        localItemCache.value = localItemCache.value + (cacheKey to cachedItems)
        trySend(cachedItems)

        val localJob: Job = launch {
            localItemCache.collect { cache ->
                trySend(mergeItems(remoteItems, cache[cacheKey].orEmpty()))
            }
        }

        val ref = database.child("oshiItems").child(uid).child(oshiId)
        val listener = ValueEventListenerBuilder(
            onData = { snapshot ->
                remoteItems = snapshot.children.map { child ->
                    OshiItem(
                        id = child.key.orEmpty(),
                        title = child.string("title"),
                        category = child.string("category"),
                        memo = child.string("memo"),
                        imageUrl = child.string("imageUrl"),
                        price = child.int("price"),
                        purchaseDate = child.double("purchaseDate"),
                        eventName = child.string("eventName"),
                        favorite = child.int("favorite"),
                        memories = child.string("memories"),
                        tags = child.stringList("tags"),
                        location = child.string("location"),
                        itemType = child.string("itemType"),
                        locationAddress = child.string("locationAddress"),
                        visitDate = child.double("visitDate"),
                        recordDate = child.double("recordDate"),
                        details = child.string("details"),
                        createdAt = child.double("createdAt"),
                        oshiId = child.string("oshiId"),
                    )
                }.sortedByDescending { it.createdAt ?: 0.0 }
                val merged = mergeItems(remoteItems, localItemCache.value[cacheKey].orEmpty())
                persistCachedItems(uid, oshiId, merged)
                localItemCache.value = localItemCache.value + (cacheKey to merged)
            },
            onError = { close(it.toException()) },
        )
        ref.addValueEventListener(listener)
        awaitClose {
            localJob.cancel()
            ref.removeEventListener(listener)
        }
    }

    suspend fun upsertItem(
        uid: String,
        oshiId: String,
        item: OshiItem,
        imageUri: Uri?,
    ): OshiItem {
        var updated = if (item.createdAt == null) {
            item.copy(createdAt = currentTimestampSeconds(), oshiId = oshiId)
        } else {
            item.copy(oshiId = oshiId)
        }

        if (imageUri != null) {
            updated = updated.copy(
                imageUrl = uploadImage("oshiItems/$uid/$oshiId/${item.id}.jpg", imageUri),
            )
        }

        cacheItem(uid, oshiId, updated)
        runCatching {
            withTimeout(DATABASE_WRITE_TIMEOUT_MS) {
                database.child("oshiItems").child(uid).child(oshiId).child(updated.id).setValue(updated.toMap()).await()
            }
        }
        return updated
    }

    suspend fun deleteItem(
        uid: String,
        oshiId: String,
        item: OshiItem,
    ) {
        item.imageUrl
            ?.takeIf { it.isNotBlank() }
            ?.let { imageUrl ->
                runCatching {
                    storage.getReferenceFromUrl(imageUrl).delete().await()
                }
            }

        removeCachedItem(uid, oshiId, item.id)
        runCatching {
            withTimeout(DATABASE_WRITE_TIMEOUT_MS) {
                database.child("oshiItems").child(uid).child(oshiId).child(item.id).removeValue().await()
            }
        }
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

    private fun cacheItem(
        uid: String,
        oshiId: String,
        item: OshiItem,
    ) {
        val key = cacheKey(uid, oshiId)
        val current = localItemCache.value[key] ?: loadCachedItems(uid, oshiId)
        val merged = current
            .filterNot { it.id == item.id }
            .plus(item)
            .sortedByDescending { it.createdAt ?: 0.0 }
        persistCachedItems(uid, oshiId, merged)
        localItemCache.value = localItemCache.value + (key to merged)
    }

    private fun removeCachedItem(
        uid: String,
        oshiId: String,
        itemId: String,
    ) {
        val key = cacheKey(uid, oshiId)
        val current = localItemCache.value[key] ?: loadCachedItems(uid, oshiId)
        val updated = current.filterNot { it.id == itemId }
        persistCachedItems(uid, oshiId, updated)
        localItemCache.value = localItemCache.value + (key to updated)
    }

    private fun mergeItems(
        remoteItems: List<OshiItem>,
        localItems: List<OshiItem>,
    ): List<OshiItem> {
        val merged = linkedMapOf<String, OshiItem>()
        remoteItems.forEach { merged[it.id] = it }
        localItems.forEach { merged[it.id] = it }
        return merged.values.sortedByDescending { it.createdAt ?: 0.0 }
    }

    private fun loadCachedItems(
        uid: String,
        oshiId: String,
    ): List<OshiItem> {
        val file = cachedItemsFile(uid, oshiId)
        if (!file.exists()) return emptyList()
        return runCatching {
            val json = JSONArray(file.readText())
            buildList {
                for (index in 0 until json.length()) {
                    val objectJson = json.optJSONObject(index) ?: continue
                    add(objectJson.toOshiItem())
                }
            }
        }.getOrDefault(emptyList())
    }

    private fun persistCachedItems(
        uid: String,
        oshiId: String,
        items: List<OshiItem>,
    ) {
        val file = cachedItemsFile(uid, oshiId)
        file.parentFile?.mkdirs()
        val json = JSONArray()
        items.forEach { json.put(it.toJson()) }
        file.writeText(json.toString())
    }

    private fun cachedItemsFile(
        uid: String,
        oshiId: String,
    ): File = File(application.filesDir, "offline-cache/items_${uid}_$oshiId.json")

    private fun cacheKey(
        uid: String,
        oshiId: String,
    ): String = "$uid:$oshiId"

    companion object {
        private const val STORAGE_UPLOAD_TIMEOUT_MS = 6_000L
        private const val DATABASE_WRITE_TIMEOUT_MS = 5_000L
    }

    private fun OshiItem.toMap(): Map<String, Any> = buildMap {
        put("id", id)
        oshiId?.let { put("oshiId", it) }
        title?.takeIf { it.isNotBlank() }?.let { put("title", it) }
        category?.takeIf { it.isNotBlank() }?.let { put("category", it) }
        memo?.takeIf { it.isNotBlank() }?.let { put("memo", it) }
        imageUrl?.takeIf { it.isNotBlank() }?.let { put("imageUrl", it) }
        price?.let { put("price", it) }
        purchaseDate?.let { put("purchaseDate", it) }
        eventName?.takeIf { it.isNotBlank() }?.let { put("eventName", it) }
        favorite?.let { put("favorite", it) }
        memories?.takeIf { it.isNotBlank() }?.let { put("memories", it) }
        tags?.takeIf { it.isNotEmpty() }?.let { put("tags", it) }
        location?.takeIf { it.isNotBlank() }?.let { put("location", it) }
        itemType?.takeIf { it.isNotBlank() }?.let { put("itemType", it) }
        locationAddress?.takeIf { it.isNotBlank() }?.let { put("locationAddress", it) }
        visitDate?.let { put("visitDate", it) }
        recordDate?.let { put("recordDate", it) }
        details?.takeIf { it.isNotBlank() }?.let { put("details", it) }
        createdAt?.let { put("createdAt", it) }
    }

    private fun OshiItem.toJson(): JSONObject = JSONObject().apply {
        put("id", id)
        putOpt("title", title)
        putOpt("category", category)
        putOpt("memo", memo)
        putOpt("imageUrl", imageUrl)
        putOpt("price", price)
        putOpt("purchaseDate", purchaseDate)
        putOpt("eventName", eventName)
        putOpt("favorite", favorite)
        putOpt("memories", memories)
        val tagsArray = JSONArray()
        tags.orEmpty().forEach(tagsArray::put)
        put("tags", tagsArray)
        putOpt("location", location)
        putOpt("itemType", itemType)
        putOpt("locationAddress", locationAddress)
        putOpt("visitDate", visitDate)
        putOpt("recordDate", recordDate)
        putOpt("details", details)
        putOpt("createdAt", createdAt)
        putOpt("oshiId", oshiId)
    }

    private fun JSONObject.toOshiItem(): OshiItem = OshiItem(
        id = optString("id"),
        title = optString("title").ifBlank { null },
        category = optString("category").ifBlank { null },
        memo = optString("memo").ifBlank { null },
        imageUrl = optString("imageUrl").ifBlank { null },
        price = optInt("price").takeUnless { it == 0 && !has("price") },
        purchaseDate = optDouble("purchaseDate").takeUnless { it.isNaN() },
        eventName = optString("eventName").ifBlank { null },
        favorite = optInt("favorite").takeUnless { it == 0 && !has("favorite") },
        memories = optString("memories").ifBlank { null },
        tags = optJSONArray("tags")
            ?.let { array ->
                buildList {
                    for (index in 0 until array.length()) {
                        array.optString(index)?.takeIf { it.isNotBlank() }?.let(::add)
                    }
                }.takeIf { it.isNotEmpty() }
            },
        location = optString("location").ifBlank { null },
        itemType = optString("itemType").ifBlank { null },
        locationAddress = optString("locationAddress").ifBlank { null },
        visitDate = optDouble("visitDate").takeUnless { it.isNaN() },
        recordDate = optDouble("recordDate").takeUnless { it.isNaN() },
        details = optString("details").ifBlank { null },
        createdAt = optDouble("createdAt").takeUnless { it.isNaN() },
        oshiId = optString("oshiId").ifBlank { null },
    )
}
