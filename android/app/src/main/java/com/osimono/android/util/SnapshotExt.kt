package com.osimono.android.util

import com.google.firebase.database.DataSnapshot

fun DataSnapshot.string(key: String): String? = child(key).getValue(String::class.java)

fun DataSnapshot.double(key: String): Double? {
    val value = child(key).value ?: return null
    return when (value) {
        is Double -> value
        is Float -> value.toDouble()
        is Long -> value.toDouble()
        is Int -> value.toDouble()
        is String -> value.toDoubleOrNull()
        else -> null
    }
}

fun DataSnapshot.int(key: String): Int? {
    val value = child(key).value ?: return null
    return when (value) {
        is Int -> value
        is Long -> value.toInt()
        is Double -> value.toInt()
        is Float -> value.toInt()
        is String -> value.toIntOrNull()
        else -> null
    }
}

fun DataSnapshot.stringList(key: String): List<String>? {
    val values = child(key).children.mapNotNull { it.getValue(String::class.java) }
    return values.takeIf { it.isNotEmpty() }
}
