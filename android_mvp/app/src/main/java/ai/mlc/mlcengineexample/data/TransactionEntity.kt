package ai.mlc.mlcengineexample.data

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "transactions")
data class TransactionEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val createdAtEpochMs: Long,
    val rawText: String,
    val extractedJson: String,
    val amount: Double?,
    val currency: String?,
    val merchant: String?,
    val category: String?,
    val dateIso: String?,
    val notes: String?,
    val confidence: Double?
)

