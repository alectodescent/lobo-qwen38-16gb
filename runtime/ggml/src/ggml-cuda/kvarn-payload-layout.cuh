#pragma once

// The appliance build targets SM120. Keep the literal 128x128 code payload
// and its byte count, but store it as 16x16 tiles so the fixed MMA fragment
// loaders touch adjacent sectors for both K (dimension x token) and V (token
// x dimension). Other CUDA architectures retain the canonical row-major
// payload until they are qualified independently.
static __device__ __forceinline__ int ggml_cuda_kvarn_payload_index(
        const int row,
        const int col) {
#if defined(__CUDA_ARCH__) && __CUDA_ARCH__ == 1200
    constexpr int tile = 16;
    constexpr int tiles_per_axis = 128 / tile;
    const int tile_index = (row / tile) * tiles_per_axis + col / tile;
    return tile_index * tile * tile + (row % tile) * tile + col % tile;
#else
    return row * 128 + col;
#endif
}

static __device__ __forceinline__ int ggml_cuda_kvarn_payload_index_from_linear(
        const int index) {
    return ggml_cuda_kvarn_payload_index(index / 128, index % 128);
}
