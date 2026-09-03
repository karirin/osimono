package com.osimono.android.data

import com.google.firebase.database.DataSnapshot
import com.google.firebase.database.DatabaseError
import com.google.firebase.database.ValueEventListener

class ValueEventListenerBuilder(
    private val onData: (DataSnapshot) -> Unit,
    private val onError: (DatabaseError) -> Unit,
) : ValueEventListener {
    override fun onDataChange(snapshot: DataSnapshot) = onData(snapshot)

    override fun onCancelled(error: DatabaseError) = onError(error)
}
