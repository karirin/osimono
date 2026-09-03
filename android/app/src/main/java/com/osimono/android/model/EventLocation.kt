package com.osimono.android.model

data class EventLocation(
    val id: String,
    val title: String,
    val latitude: Double,
    val longitude: Double,
    val imageURL: String? = null,
    val category: String,
    val ratingSum: Int = 0,
    val note: String? = null,
    val createdAt: Double? = null,
    val oshiId: String? = null,
    val locationAddress: String? = null,
)
