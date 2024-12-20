#pragma once
#include "geommath.hpp"
#include "Ray.hpp"
#include <cmath>
#include <utility>

namespace My {
template <class T, Dimension auto N>
class AaBb {
   public:
    __device__ AaBb() {}
    __device__ AaBb(const Vector<T, N>& a, const Vector<T, N>& b) {
        minimum = a;
        maximum = b;
    }

    __device__ Vector<T, N> min_point() const { return minimum; }
    __device__ Vector<T, N> max_point() const { return maximum; }

    __device__ bool Intersect(const Ray<T>& r, T tmin, T tmax) const {
        for (int a = 0; a < 3; a++) {
            auto invD = 1.0 / r.getDirection()[a];
            auto t0 = (this->min_point()[a] - r.getOrigin()[a]) * invD;
            auto t1 = (this->max_point()[a] - r.getOrigin()[a]) * invD;
            if (invD < 0.0f) {
                auto tmp = t0;
                t0 = t1;
                t1 = tmp;
            }
            tmin = t0 > tmin ? t0 : tmin;
            tmax = t1 < tmax ? t1 : tmax;
            if (tmax <= tmin) {
                return false;
            }
        }

        return true;
    }

   private:
    Vector<T, N> minimum;
    Vector<T, N> maximum;
};

template <class T>
inline void TransformAabb(const Vector3<T>& halfExtents, T margin,
                          const Matrix4X4<T>& trans, AaBb<T, 3>& aabb) {
    Vector3<T> halfExtentsWithMargin = halfExtents + Vector3<T>(margin);
    Vector3<T> center;
    Vector3<T> extent;
    Matrix3X3<T> basis;
    GetOrigin(center, trans);
    Shrink(basis, trans);
    Absolute(basis, basis);
    DotProduct3(extent, halfExtentsWithMargin, basis);
    aabb = AaBb<T, 3>(center - extent, center + extent);
};

template <class T>
__device__ auto SurroundingBox(AaBb<T, 3> box0, AaBb<T, 3> box1) {
    Vector3<T> small_corner ({
        std::fmin(box0.min_point()[0], box1.min_point()[0]),
        std::fmin(box0.min_point()[1], box1.min_point()[1]),
        std::fmin(box0.min_point()[2], box1.min_point()[2])
    });

    Vector3<T> big_corner ({
        std::fmax(box0.max_point()[0], box1.max_point()[0]),
        std::fmax(box0.max_point()[1], box1.max_point()[1]),
        std::fmax(box0.max_point()[2], box1.max_point()[2])
    });

    return AaBb<T, 3>(small_corner, big_corner);
};
}  // namespace My