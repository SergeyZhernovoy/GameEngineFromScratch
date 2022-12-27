#include <iostream>
#include "Image.hpp"
#include "geommath.hpp"

using float_precision = float;

using image = My::Image;

#define checkCudaErrors(val) check_cuda((val), #val, __FILE__, __LINE__)
void check_cuda(cudaError_t result, char const *const func,
                const char *const file, int const line) {
    if (result) {
        std::cerr << "CUDA error = " << static_cast<unsigned int>(result)
                  << " at " << file << ":" << line << " '" << func << "' \n";
        cudaDeviceReset();
        exit(99);
    }
}

__global__ void render(float *fb, int max_x, int max_y) {
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    int j = threadIdx.y + blockIdx.y * blockDim.y;
    if ((i < max_x) && (j < max_y)) {
        int pixel_index = j * max_x * 3 + i * 3;
        fb[pixel_index + 0] = float(i) / max_x;
        fb[pixel_index + 1] = float(j) / max_y;
        fb[pixel_index + 2] = 0.2f;
    }
}

int main() {
    // Render Settings
    const float_precision aspect_ratio = 16.0 / 9.0;
    const int image_width = 1920;
    const int image_height = static_cast<int>(image_width / aspect_ratio);

    int tile_width = 8;
    int tile_height = 8;

    // Canvas
    image img;
    img.Width = image_width;
    img.Height = image_height;
    img.bitcount = 96;
    img.bitdepth = 32;
    img.pixel_format = My::PIXEL_FORMAT::RGB32;
    img.pitch = (img.bitcount >> 3) * img.Width;
    img.compressed = false;
    img.compress_format = My::COMPRESSED_FORMAT::NONE;
    img.data_size = img.Width * img.Height * (img.bitcount >> 3);
    img.data = new uint8_t[img.data_size];

    checkCudaErrors(cudaMallocManaged((void **)&img.data, img.data_size));

    dim3 blocks(image_width / tile_width + 1, image_height / tile_height + 1);
    dim3 threads(tile_width, tile_height);
    render<<<blocks, threads>>>(reinterpret_cast<float *>(img.data), image_width, image_height);

    checkCudaErrors(cudaGetLastError());
    checkCudaErrors(cudaDeviceSynchronize());

    img.SaveTGA("raytracing_cuda.tga");
    
    checkCudaErrors(cudaFree(img.data));
    img.data = nullptr; // to avoid double free

    return 0;
}