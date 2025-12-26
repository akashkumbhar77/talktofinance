package ai.mlc.mlcengineexample.mlc

import com.google.gson.annotations.SerializedName

data class MlcChatConfig(
    @SerializedName("model_lib") val modelLib: String?
)

