package dev.rodrigo.spectra.glance.models

import kotlinx.serialization.Serializable

@Serializable
data class Image(
    val height: Int?,
    val width: Int?,
    val path: String,
)