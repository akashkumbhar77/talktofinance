package ai.mlc.mlcengineexample.mlc

import com.google.gson.annotations.SerializedName

data class ExpenseExtraction(
    @SerializedName("amount") val amount: Double? = null,
    @SerializedName("currency") val currency: String? = null,
    @SerializedName("merchant") val merchant: String? = null,
    @SerializedName("category") val category: String? = null,
    @SerializedName("date") val date: String? = null,
    @SerializedName("notes") val notes: String? = null,
    @SerializedName("confidence") val confidence: Double? = null
)

