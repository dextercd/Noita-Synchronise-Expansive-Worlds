#include <iostream>
#include <random>
#include <stdexcept>
#include <algorithm>

#include <nsew/rectangle_optimiser.hpp>

std::mt19937 random_gen;

std::ostream& operator<<(std::ostream& os, nsew::rectangle rect)
{
    return os
        << "{" << rect.left << "," << rect.top << ","
        << rect.right << "," << rect.bottom << "}";
}

class test_error : public std::runtime_error {
public:
    using std::runtime_error::runtime_error;
};

void check(bool res, char const* message = "")
{
    if (!res)
        throw test_error{message};
}

auto constexpr position_limit = 5000;
auto constexpr extent_limit = 5000;

template<class Generator>
nsew::rectangle random_rectangle(Generator& g, int pos=position_limit, int ext=extent_limit)
{
    auto position_dist = std::uniform_int_distribution(-pos, pos);

    // Generate rectangles with at least 1 unit of width and height
    auto extent_dist = std::uniform_int_distribution(1, ext);

    auto x = position_dist(g);
    auto y = position_dist(g);
    auto width = extent_dist(g);
    auto height = extent_dist(g);

    return {
        x,
        y,
        x + width,
        y + height
    };
}

void zero_extent_is_empty()
{
    std::bernoulli_distribution bool_dist;
    for (int i = 0; i != 10000; ++i) {
        auto rectopt = nsew::rectangle_optimiser{};
        auto rect = random_rectangle(random_gen);
        if (bool_dist(random_gen)) {
            rect.right = rect.left;
        } else {
            rect.top = rect.bottom;
        }

        rectopt.submit(rect);
        auto results = rectopt.scan();
        check(results.empty(), "results not empty");
    }
}

void single_rect_is_noop()
{
    for (int i = 0; i != 10000; ++i) {
        auto rectopt = nsew::rectangle_optimiser{};
        auto rect = random_rectangle(random_gen);

        rectopt.submit(rect);
        auto results = rectopt.scan();
        check(results.size() == 1, "results size is not 1");
        check(results[0] == rect, "got a different rectangle back");
    }
}

std::int64_t total_area(std::vector<nsew::rectangle> const& rects)
{
    std::int64_t total{};
    for (auto r : rects)
        total += nsew::area(r);

    return total;
}

void area_is_less_or_equal()
{
    auto const multiplier = 5;
    auto rect_count_dist = std::uniform_int_distribution(50 * multiplier, 200 * multiplier);
    std::vector<nsew::rectangle> rects;
    auto rectopt = nsew::rectangle_optimiser{};
    for (int i = 0; i != 220000; ++i) {
        rectopt.reset();
        rects.resize(rect_count_dist(random_gen));
        std::generate(std::begin(rects), std::end(rects),
            []() { return random_rectangle(random_gen, 1072, 67); });
        for (auto rect : rects)
            rectopt.submit(rect);

        auto optimised = rectopt.scan();

        check(total_area(optimised) <= total_area(rects));
    }
}

int main()
{
    zero_extent_is_empty();
    single_rect_is_noop();
    area_is_less_or_equal();

    nsew::rectangle_optimiser rectopt;

    auto r = nsew::rectangle{-2, 5, 7, 9};
    auto r2 = nsew::rectangle{2, 2, 9, 6};
    auto r3 = nsew::rectangle{0, 0, 7, 3};
    rectopt.submit(r);
    rectopt.submit(r2);
    rectopt.submit(r3);

    auto x = rectopt.scan();

    std::cout << x.size() << " rects:\n";
    for (auto rect : x)
        std::cout << rect << '\n';

    return 0;

    if (x.size() != 1) {
        std::cout << "wrong size";
        return 1;
    }

    if (x[0] != r) {
        std::cout << "wrong rect";
        return 1;
    }

    return 0;
}
