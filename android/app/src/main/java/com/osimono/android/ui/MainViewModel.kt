package com.osimono.android.ui

import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.osimono.android.data.AppContainer
import com.osimono.android.model.EventLocation
import com.osimono.android.model.Oshi
import com.osimono.android.model.OshiItem
import com.osimono.android.model.UserProfile
import com.osimono.android.util.currentTimestampSeconds
import java.util.UUID
import kotlinx.coroutines.Job
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

const val NEW_ENTRY_ID = "new"

val OshiLanguageOptions = listOf("auto", "ja", "en")
val OshiItemTypeOptions = listOf("グッズ", "聖地巡礼", "ライブ記録", "SNS投稿", "その他")
val LocationCategoryOptions = listOf("聖地巡礼", "ライブ会場", "カフェ・飲食店", "グッズショップ", "撮影スポット", "その他")

data class MainUiState(
    val isInitializing: Boolean = true,
    val isWorking: Boolean = false,
    val userId: String? = null,
    val initializationError: String? = null,
    val userProfile: UserProfile = UserProfile(),
    val oshis: List<Oshi> = emptyList(),
    val items: List<OshiItem> = emptyList(),
    val locations: List<EventLocation> = emptyList(),
    val transientMessage: String? = null,
) {
    val selectedOshi: Oshi?
        get() = userProfile.selectedOshiId?.let { selectedId ->
            oshis.firstOrNull { it.id == selectedId }
        }
}

data class OshiDraft(
    val id: String? = null,
    val name: String = "",
    val memo: String = "",
    val personality: String = "",
    val speakingStyle: String = "",
    val birthday: String = "",
    val height: String = "",
    val hometown: String = "",
    val favoriteColor: String = "",
    val favoriteFood: String = "",
    val dislikedFood: String = "",
    val interestsText: String = "",
    val userNickname: String = "",
    val relationshipStatus: String = "",
    val relationshipDetail: String = "",
    val sharedMemory: String = "",
    val signaturePhrase: String = "",
    val conversationTopicsText: String = "",
    val forbiddenTopicsText: String = "",
    val gender: String = "",
    val preferredLanguage: String = "auto",
)

data class OshiItemDraft(
    val id: String? = null,
    val title: String = "",
    val itemType: String = OshiItemTypeOptions.first(),
    val category: String = "",
    val memo: String = "",
    val price: String = "",
    val eventName: String = "",
    val location: String = "",
    val locationAddress: String = "",
    val details: String = "",
    val tags: String = "",
    val favorite: Int = 0,
    val dateTimestamp: Double? = null,
)

data class EventLocationDraft(
    val id: String? = null,
    val title: String = "",
    val category: String = LocationCategoryOptions.first(),
    val note: String = "",
    val latitude: String = "",
    val longitude: String = "",
    val locationAddress: String = "",
)

class MainViewModel(
    private val container: AppContainer,
) : ViewModel() {
    private val _uiState = MutableStateFlow(MainUiState())
    val uiState: StateFlow<MainUiState> = _uiState.asStateFlow()

    private var userJob: Job? = null
    private var oshiJob: Job? = null
    private var itemsJob: Job? = null
    private var locationsJob: Job? = null
    private var bootstrapJob: Job? = null
    private var observedSelectedOshiId: String? = null

    init {
        bootstrap()
    }

    fun consumeTransientMessage() {
        _uiState.update { it.copy(transientMessage = null) }
    }

    fun retryInitialization() {
        bootstrap()
    }

    fun selectOshi(oshiId: String) {
        val uid = _uiState.value.userId ?: return
        setLocalSelectedOshiId(oshiId)
        viewModelScope.launch {
            runCatching {
                container.userRepository.updateSelectedOshiId(uid, oshiId)
            }.onFailure {
                showMessage(userFacingErrorMessage(it, "推しの選択の同期に時間がかかっています。端末内では切り替え済みです"))
            }
        }
    }

    fun saveProfile(username: String, favoriteOshi: String) {
        val uid = _uiState.value.userId ?: return
        executeOperation("プロフィールを保存しました") {
            container.userRepository.updateProfile(uid, username, favoriteOshi)
        }
    }

    fun saveOshi(
        draft: OshiDraft,
        profileImageUri: Uri?,
        backgroundImageUri: Uri?,
        onComplete: () -> Unit,
    ) {
        val uid = _uiState.value.userId ?: return
        if (draft.name.isBlank()) {
            showMessage("推しの名前を入力してください")
            return
        }
        executeOperation("推しを保存しました") {
            val existing = _uiState.value.oshis.firstOrNull { it.id == draft.id }
            val oshi = Oshi(
                id = draft.id ?: UUID.randomUUID().toString(),
                name = draft.name.trim(),
                imageUrl = existing?.imageUrl,
                backgroundImageUrl = existing?.backgroundImageUrl,
                memo = draft.memo.trim().ifBlank { null },
                createdAt = existing?.createdAt ?: currentTimestampSeconds(),
                personality = draft.personality.trim().ifBlank { null },
                interests = parseListText(draft.interestsText),
                speakingStyle = draft.speakingStyle.trim().ifBlank { null },
                birthday = draft.birthday.trim().ifBlank { null },
                height = draft.height.trim().toIntOrNull(),
                favoriteColor = draft.favoriteColor.trim().ifBlank { null },
                favoriteFood = draft.favoriteFood.trim().ifBlank { null },
                dislikedFood = draft.dislikedFood.trim().ifBlank { null },
                hometown = draft.hometown.trim().ifBlank { null },
                gender = draft.gender.trim().ifBlank { null },
                userNickname = draft.userNickname.trim().ifBlank { null },
                relationshipStatus = draft.relationshipStatus.trim().ifBlank { null },
                relationshipDetail = draft.relationshipDetail.trim().ifBlank { null },
                sharedMemory = draft.sharedMemory.trim().ifBlank { null },
                signaturePhrase = draft.signaturePhrase.trim().ifBlank { null },
                conversationTopics = parseListText(draft.conversationTopicsText),
                forbiddenTopics = parseListText(draft.forbiddenTopicsText),
                preferredLanguage = draft.preferredLanguage,
            )

            val saved = container.oshiRepository.upsertOshi(uid, oshi, profileImageUri, backgroundImageUri)
            upsertLocalOshi(saved)
            val selectedId = _uiState.value.userProfile.selectedOshiId
            if (selectedId.isNullOrBlank()) {
                setLocalSelectedOshiId(saved.id)
                runCatching {
                    container.userRepository.updateSelectedOshiId(uid, saved.id)
                }
            }
            onComplete()
        }
    }

    fun saveItem(
        draft: OshiItemDraft,
        imageUri: Uri?,
        onComplete: () -> Unit,
    ) {
        val uid = _uiState.value.userId ?: return
        if (draft.title.isBlank()) {
            showMessage("投稿タイトルを入力してください")
            return
        }
        val selectedOshi = _uiState.value.selectedOshi ?: run {
            showMessage("先に推しを追加または選択してください")
            return
        }
        executeOperation("投稿を保存しました") {
            val existing = _uiState.value.items.firstOrNull { it.id == draft.id }
            val now = currentTimestampSeconds()
            val itemType = draft.itemType
            val timestamp = draft.dateTimestamp ?: existing?.createdAt ?: now
            val parsedTags = draft.tags
                .split(",", "、", "\n")
                .map { it.trim().removePrefix("#") }
                .filter { it.isNotBlank() }
                .distinct()
            val item = OshiItem(
                id = draft.id ?: UUID.randomUUID().toString(),
                title = draft.title.trim().ifBlank { null },
                category = draft.category.trim().ifBlank { null },
                memo = draft.memo.trim().ifBlank { null },
                imageUrl = existing?.imageUrl,
                price = draft.price.toIntOrNull(),
                purchaseDate = when (itemType) {
                    "グッズ", "ライブ記録" -> timestamp
                    else -> null
                },
                eventName = draft.eventName.trim().ifBlank { null },
                favorite = draft.favorite.takeIf { it > 0 },
                memories = draft.memo.trim().ifBlank { null },
                tags = parsedTags.takeIf { it.isNotEmpty() },
                location = draft.location.trim().ifBlank { null },
                itemType = itemType,
                locationAddress = draft.locationAddress.trim().ifBlank { null },
                visitDate = if (itemType == "聖地巡礼") timestamp else null,
                recordDate = if (itemType == "その他" || itemType == "SNS投稿") timestamp else null,
                details = draft.details.trim().ifBlank { null },
                createdAt = existing?.createdAt ?: now,
                oshiId = selectedOshi.id,
            )

            val saved = container.oshiItemRepository.upsertItem(uid, selectedOshi.id, item, imageUri)
            upsertLocalItem(saved)
            onComplete()
        }
    }

    fun deleteItem(
        itemId: String,
        onComplete: () -> Unit,
    ) {
        val uid = _uiState.value.userId ?: return
        val selectedOshi = _uiState.value.selectedOshi ?: return
        val existing = _uiState.value.items.firstOrNull { it.id == itemId } ?: return
        executeOperation("投稿を削除しました") {
            container.oshiItemRepository.deleteItem(uid, selectedOshi.id, existing)
            removeLocalItem(itemId)
            onComplete()
        }
    }

    fun saveLocation(
        draft: EventLocationDraft,
        imageUri: Uri?,
        onComplete: () -> Unit,
    ) {
        val uid = _uiState.value.userId ?: return
        if (draft.title.isBlank()) {
            showMessage("場所タイトルを入力してください")
            return
        }
        val selectedOshi = _uiState.value.selectedOshi ?: run {
            showMessage("先に推しを追加または選択してください")
            return
        }

        val latitude = draft.latitude.toDoubleOrNull()
        val longitude = draft.longitude.toDoubleOrNull()
        if (latitude == null || longitude == null) {
            showMessage("緯度と経度を正しく入力してください")
            return
        }

        executeOperation("場所を保存しました") {
            val existing = _uiState.value.locations.firstOrNull { it.id == draft.id }
            val location = EventLocation(
                id = draft.id ?: UUID.randomUUID().toString(),
                title = draft.title.trim(),
                latitude = latitude,
                longitude = longitude,
                imageURL = existing?.imageURL,
                category = draft.category,
                ratingSum = existing?.ratingSum ?: 0,
                note = draft.note.trim().ifBlank { null },
                createdAt = existing?.createdAt ?: currentTimestampSeconds(),
                oshiId = selectedOshi.id,
                locationAddress = draft.locationAddress.trim().ifBlank { null },
            )
            container.locationRepository.upsertLocation(uid, selectedOshi.id, location, imageUri)
            onComplete()
        }
    }

    private fun bootstrap() {
        bootstrapJob?.cancel()
        bootstrapJob = viewModelScope.launch {
            _uiState.update {
                it.copy(
                    isInitializing = true,
                    initializationError = null,
                    transientMessage = null,
                )
            }
            runCatching {
                val uid = kotlinx.coroutines.withTimeout(12_000) {
                    container.authRepository.ensureAnonymousUser()
                }
                _uiState.update { it.copy(userId = uid) }
                observeUser(uid)
                observeOshis(uid)
                launch {
                    runCatching {
                        kotlinx.coroutines.withTimeout(8_000) {
                            container.userRepository.ensureUserProfile(uid)
                        }
                    }.onFailure {
                        showMessage(it.message ?: "ユーザープロフィールの初期化に時間がかかっています")
                    }
                }
            }.onFailure {
                val message = when (it) {
                    is kotlinx.coroutines.TimeoutCancellationException -> "初期化がタイムアウトしました。通信状況を確認して再試行してください"
                    else -> it.message ?: "初期化に失敗しました"
                }
                _uiState.update { state ->
                    state.copy(
                        initializationError = message,
                    )
                }
                showMessage(message)
            }
            _uiState.update { it.copy(isInitializing = false) }
        }
    }

    private fun observeUser(uid: String) {
        userJob?.cancel()
        userJob = viewModelScope.launch {
            container.userRepository.observeProfile(uid).collect { profile ->
                _uiState.update { it.copy(userProfile = profile) }
                refreshSelectedStreams()
            }
        }
    }

    private fun observeOshis(uid: String) {
        oshiJob?.cancel()
        oshiJob = viewModelScope.launch {
            container.oshiRepository.observeOshis(uid).collect { oshis ->
                _uiState.update { it.copy(oshis = oshis) }
                ensureValidSelectedOshi(uid, oshis)
            }
        }
    }

    private fun ensureValidSelectedOshi(uid: String, oshis: List<Oshi>) {
        val selectedOshiId = _uiState.value.userProfile.selectedOshiId
        if (oshis.isEmpty()) {
            observedSelectedOshiId = null
            itemsJob?.cancel()
            locationsJob?.cancel()
            _uiState.update { it.copy(items = emptyList(), locations = emptyList()) }
            return
        }

        if (selectedOshiId.isNullOrBlank() || oshis.none { it.id == selectedOshiId }) {
            setLocalSelectedOshiId(oshis.first().id)
            viewModelScope.launch {
                runCatching {
                    container.userRepository.updateSelectedOshiId(uid, oshis.first().id)
                }.onFailure {
                    showMessage(userFacingErrorMessage(it, "推しの初期選択の同期に時間がかかっています"))
                }
            }
            return
        }

        refreshSelectedStreams()
    }

    private fun refreshSelectedStreams() {
        val uid = _uiState.value.userId ?: return
        val selectedOshiId = _uiState.value.userProfile.selectedOshiId
        if (selectedOshiId == observedSelectedOshiId) return

        observedSelectedOshiId = selectedOshiId
        itemsJob?.cancel()
        locationsJob?.cancel()

        if (selectedOshiId.isNullOrBlank()) {
            _uiState.update { it.copy(items = emptyList(), locations = emptyList()) }
            return
        }

        itemsJob = viewModelScope.launch {
            container.oshiItemRepository.observeItems(uid, selectedOshiId).collect { items ->
                _uiState.update { it.copy(items = items) }
            }
        }

        locationsJob = viewModelScope.launch {
            container.locationRepository.observeLocations(uid, selectedOshiId).collect { locations ->
                _uiState.update { it.copy(locations = locations) }
            }
        }
    }

    private fun executeOperation(
        successMessage: String,
        block: suspend () -> Unit,
    ) {
        viewModelScope.launch {
            _uiState.update { it.copy(isWorking = true) }
            runCatching {
                block()
            }.onSuccess {
                showMessage(successMessage)
            }.onFailure {
                showMessage(userFacingErrorMessage(it))
            }
            _uiState.update { it.copy(isWorking = false) }
        }
    }

    private fun upsertLocalOshi(oshi: Oshi) {
        _uiState.update { state ->
            val updatedOshis = state.oshis
                .filterNot { it.id == oshi.id }
                .plus(oshi)
                .sortedByDescending { it.createdAt ?: 0.0 }
            state.copy(oshis = updatedOshis)
        }
    }

    private fun setLocalSelectedOshiId(oshiId: String) {
        _uiState.update { state ->
            state.copy(
                userProfile = state.userProfile.copy(selectedOshiId = oshiId),
            )
        }
    }

    private fun upsertLocalItem(item: OshiItem) {
        _uiState.update { state ->
            val updatedItems = state.items
                .filterNot { it.id == item.id }
                .plus(item)
                .sortedByDescending { it.createdAt ?: 0.0 }
            state.copy(items = updatedItems)
        }
    }

    private fun removeLocalItem(itemId: String) {
        _uiState.update { state ->
            state.copy(items = state.items.filterNot { it.id == itemId })
        }
    }

    private fun userFacingErrorMessage(
        throwable: Throwable,
        timeoutMessage: String = "保存に時間がかかっています。通信状況を確認してもう一度お試しください",
    ): String = when (throwable) {
        is TimeoutCancellationException -> timeoutMessage
        else -> throwable.message ?: "処理に失敗しました"
    }

    private fun showMessage(message: String) {
        _uiState.update { it.copy(transientMessage = message) }
    }

    private fun parseListText(text: String): List<String>? =
        text.split(",", "、", "\n")
            .map { it.trim() }
            .filter { it.isNotBlank() }
            .distinct()
            .takeIf { it.isNotEmpty() }

    class Factory(
        private val container: AppContainer,
    ) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T {
            return MainViewModel(container) as T
        }
    }
}
