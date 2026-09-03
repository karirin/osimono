package com.osimono.android.data

import android.app.Application
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.database.FirebaseDatabase
import com.google.firebase.storage.FirebaseStorage

class AppContainer(application: Application) {
    private val auth: FirebaseAuth = FirebaseAuth.getInstance()
    private val database = FirebaseDatabase.getInstance().reference
    private val storage = FirebaseStorage.getInstance()

    val authRepository = AuthRepository(auth)
    val userRepository = UserRepository(database)
    val oshiRepository = OshiRepository(database, storage, application)
    val oshiItemRepository = OshiItemRepository(database, storage, application)
    val locationRepository = LocationRepository(database, storage, application)
}
