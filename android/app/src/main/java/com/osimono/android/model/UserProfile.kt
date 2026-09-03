package com.osimono.android.model

data class UserProfile(
    val uid: String = "",
    val username: String? = null,
    val favoriteOshi: String? = null,
    val profileImageUrl: String? = null,
    val backgroundImageUrl: String? = null,
    val bio: String? = null,
    val selectedOshiId: String? = null,
    val userFlag: Int? = null,
)
