#ifndef NSEW_RECTANGLE_OPTIMISER_HPP
#define NSEW_RECTANGLE_OPTIMISER_HPP

#include <cstdint>
#include <vector>

namespace nsew {

// left must be greater than right and bottom must be greater that top.
//
// -      x +
//   .-------->
//   |
// y |
// + |
//   v

struct rectangle {
    std::int32_t left;
    std::int32_t top;
    std::int32_t right;
    std::int32_t bottom;

    bool operator==(rectangle const&) const = default;
};

constexpr bool has_area(rectangle r) {
    return (
        r.left < r.right &&
        r.top < r.bottom
    );
}

constexpr std::int32_t area(rectangle r) {
    return (r.right - r.left) * (r.bottom - r.top);
}

enum class edge_side : char {
    left, right
};

struct edge {
    edge_side side;
    std::int32_t position;
    std::int32_t start;
    std::int32_t stop;

    bool operator==(edge const&) const = default;
};

struct segment {
    std::int32_t position;
    std::int32_t start;
    std::int32_t stop;

    bool operator==(segment const&) const = default;
};

struct range {
    std::int32_t start;
    std::int32_t stop;

    bool operator==(range const&) const = default;
};

struct sweep_alg {
    std::vector<segment> segments;
    std::vector<rectangle> output;

    void reset()
    {
        segments.clear();
        output.clear();
    }

    void next(const std::vector<range>& ranges, int position);
};

struct rectangle_optimiser {
    std::vector<rectangle> rectangles;
    std::vector<edge> edges;
    std::vector<segment> active_segments;
    std::vector<range> active_ranges;
    sweep_alg alg;

    void reset()
    {
        alg.reset();
        rectangles.clear();
        edges.clear();
        active_segments.clear();
        active_ranges.clear();
    }

    void submit(rectangle rect) {
        if (!has_area(rect))
            return;

        rectangles.push_back(rect);
    }

    std::vector<rectangle> scan();
};

}

#endif // header guard
