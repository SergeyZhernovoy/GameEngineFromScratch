#include <iostream>
#include <limits>
#include <curand_kernel.h>
#include "geommath.hpp"
#include "HitableList.hpp"
#include "Image.hpp"
#include "Ray.hpp"
#include "Sphere.hpp"
#include "RayTracingCamera.hpp"

using ray = My::Ray<float>;
using color = My::Vector3<float>;
using point3 = My::Point<float>;
using vec3 = My::Vector3<float>;
using hit_record = My::Hit<float>;
using hitable = My::Hitable<float>;
using hitable_ptr = hitable *;
using sphere = My::Sphere<float, void *>;
using image = My::Image;

using hitable_list = My::HitableList<float, hitable_ptr, My::SimpleList<hitable_ptr>>;

using camera = My::RayTracingCamera<float>;

// Device Management
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

// Render
__device__ color ray_color(const ray& r, hitable_list **world) {
    hit_record rec;
    if ((*world)->Intersect(r, rec, 0.0, FLT_MAX)) {
        return 0.5f * color({rec.getNormal()[0] + 1.0f, rec.getNormal()[1] + 1.0f, rec.getNormal()[2] + 1.0f});
    } else {
        vec3 unit_direction = r.getDirection();
        float t = 0.5f * (unit_direction[1] + 1.0f);
        return (1.0f - t) * color({1.0, 1.0, 1.0}) + t * color({0.5, 0.7, 1.0});
    }
}

__global__ void render_init(int max_x, int max_y, curandState *rand_state) {
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    int j = threadIdx.y + blockIdx.y * blockDim.y;
    if ((i >= max_x) || (j >= max_y)) return;
    int pixel_index = j * max_x + i;
    // Each thread gets same seed, a different sequence number, no offset
    curand_init(2022, pixel_index, 0, &rand_state[pixel_index]);
}

__global__ void render(vec3 *fb, int max_x, int max_y, int number_of_samples, camera **cam, hitable_list **world, curandState *rand_state) {
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    int j = threadIdx.y + blockIdx.y * blockDim.y;
    if ((i < max_x) && (j < max_y)) {
        int pixel_index = j * max_x + i;
        curandState local_rand_state = rand_state[pixel_index];
        vec3 col({0, 0, 0});
        for (int s = 0; s < number_of_samples; s++) {
            float u = float(i + curand_uniform(&local_rand_state)) / float(max_x);
            float v = float(j + curand_uniform(&local_rand_state)) / float(max_y);
            ray r = (*cam)->get_ray(u, v, &local_rand_state);
            col += ray_color(r, world);
        }
        fb[pixel_index] = col / float(number_of_samples);
    }
}

// Camera
__global__ void create_camera(point3 lookfrom, point3 lookat, vec3 vup,
           float vfov, float aspect_ratio, float aperture, float focus_dist, camera **d_camera) {
    if (threadIdx.x == 0 && blockIdx.x == 0) {
        *d_camera       = new camera(lookfrom, lookat, vup, 20.0f,
                                aspect_ratio, aperture, focus_dist);
    }
}

__global__ void free_camera(camera **d_camera) {
    delete *d_camera; // the destructor will delete hitables 
}

// World
__global__ void create_world(hitable_list **d_world) {
    if (threadIdx.x == 0 && blockIdx.x == 0) {
        *d_world        = new hitable_list;
        (*d_world)->add(hitable_ptr(new sphere(0.5f, point3({0, 0, -1}))));
        (*d_world)->add(hitable_ptr(new sphere(100.0f, point3({0, -100.5, -1}))));
    }
}

__global__ void free_world(hitable_list **d_world) {
    delete *d_world; // the destructor will delete hitables 
}

int main() {
    // Render Settings
    const float aspect_ratio = 16.0 / 9.0;
    const int image_width = 1920;
    const int image_height = static_cast<int>(image_width / aspect_ratio);
    const int samples_per_pixel = 500;
    const int num_pixels = image_width * image_height;

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

    checkCudaErrors(cudaMallocManaged((void **)&img.data, img.data_size));

    // Camera
    point3 lookfrom({0, 0, 5});
    point3 lookat({0, 0, -1});
    vec3 vup({0, 1, 0});
    auto dist_to_focus = 5.0;
    auto aperture = 0.0;

    camera **d_camera;
    checkCudaErrors(cudaMalloc((void **)&d_camera, sizeof(camera *)));

    create_camera<<<1, 1>>>(lookfrom, lookat, vup, 90.0, aspect_ratio, aperture, dist_to_focus, d_camera);
    checkCudaErrors(cudaGetLastError());
    checkCudaErrors(cudaDeviceSynchronize());

    // World
    hitable_list **d_world;
    checkCudaErrors(cudaMalloc((void **)&d_world, sizeof(hitable_list *)));
    create_world<<<1, 1>>>(d_world);

    checkCudaErrors(cudaGetLastError());
    checkCudaErrors(cudaDeviceSynchronize());

    // Pre-rendering
    curandState *d_rand_state;
    checkCudaErrors(cudaMalloc((void **)&d_rand_state, num_pixels * sizeof(curandState)));

    // Rendering
    dim3 blocks(image_width / tile_width + 1, image_height / tile_height + 1);
    dim3 threads(tile_width, tile_height);
    render_init<<<blocks, threads>>>(image_width, image_height, d_rand_state);
    checkCudaErrors(cudaGetLastError());
    checkCudaErrors(cudaDeviceSynchronize());

    render<<<blocks, threads>>>(reinterpret_cast<vec3 *>(img.data), image_width, image_height, samples_per_pixel, d_camera, d_world, d_rand_state);

    checkCudaErrors(cudaGetLastError());
    checkCudaErrors(cudaDeviceSynchronize());

    img.SaveTGA("raytracing_cuda.tga");
    
    free_world<<<1, 1>>>(d_world);
    checkCudaErrors(cudaGetLastError());

    checkCudaErrors(cudaFree(d_camera));
    checkCudaErrors(cudaFree(d_world));
    checkCudaErrors(cudaFree(img.data));
    img.data = nullptr; // to avoid double free

    return 0;
}