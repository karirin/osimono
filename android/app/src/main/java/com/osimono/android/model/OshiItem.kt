package com.osimono.android.model

data class OshiItem(
    val id: String,
    val title: String? = null,
    val category: String? = null,
    val memo: String? = null,
    val imageUrl: String? = null,
    val price: Int? = null,
    val purchaseDate: Double? = null,
    val eventName: String? = null,
    val favorite: Int? = null,
    val memories: String? = null,
    val tags: List<String>? = null,
    val location: String? = null,
    val itemType: String? = null,
    val locationAddress: String? = null,
    val visitDate: Double? = null,
    val recordDate: Double? = null,
    val details: String? = null,
    val createdAt: Double? = null,
    val oshiId: String? = null,
)
