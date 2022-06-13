#include <algorithm>
#include <vector>
#include <cstdint>
#include <cassert>
#include <unordered_map>

#include <nsew/rectangle_optimiser.hpp>

namespace nsew {

std::vector<range>::iterator optimise_ranges(std::vector<range>& ranges)
{
    if (ranges.empty())
        return ranges.end();

    auto current_range = ranges.front();
    auto replace_point = ranges.begin();
    for (auto it = ranges.begin() + 1; it != std::end(ranges); ++it) {
        auto next_range = *it;
        if (next_range.start <= current_range.stop) {
            current_range.stop = std::max(current_range.stop, next_range.stop);
        } else {
            *replace_point = current_range;
            ++replace_point;
            current_range = next_range;
        }
    }

    *replace_point = current_range;
    return replace_point + 1;
}

bool edge_position_order(edge a, edge b)
{
    if (auto p = a.position <=> b.position; p != 0)
        return p < 0;

    return a.side == edge_side::left && b.side == edge_side::right;
}

void sweep_alg::next(const std::vector<range>& ranges, int position)
{
    auto keep_end = std::stable_partition(
        std::begin(segments), std::end(segments),
        [&] (auto segment) {
            auto r = range{segment.start, segment.stop};
            return std::find(std::begin(ranges), std::end(ranges), r) != std::end(ranges);
        }
    );

    std::for_each(keep_end, std::end(segments), [&](auto seg) {
        output.push_back({seg.position, seg.stop, position, seg.start});
    });

    segments.erase(keep_end, std::end(segments));
    auto survivors = segments.size();
    for (auto range : ranges) {
        auto end = std::begin(segments) + survivors;
        auto found = std::find_if(
            std::begin(segments), end,
            [&] (auto s) { return s.start == range.start && s.stop == range.stop; }
        ) != end;

        if (!found)
            segments.push_back({position, range.start, range.stop});
    }
}

std::vector<rectangle> rectangle_optimiser::scan()
{
    edges.clear();
    for (auto rect : rectangles) {
        edges.push_back({edge_side::left, rect.left, rect.bottom, rect.top});
        edges.push_back({edge_side::right, rect.right, rect.bottom, rect.top});
    }
    std::sort(std::begin(edges), std::end(edges),
        [](edge a, edge b) { return edge_position_order(a, b); });

    active_segments.clear();
    active_ranges.clear();

    for (auto it = std::begin(edges); it != std::end(edges);) {
        auto current_position = it->position;
        for (; it != std::end(edges) && it->position == current_position; ++it) {
            auto edge = *it;
            if (edge.side == edge_side::left) {
                auto edge_segment = segment{edge.position, edge.start, edge.stop};
                active_segments.push_back(edge_segment);
            } else {
                auto remove = std::find_if(
                    std::begin(active_segments), std::end(active_segments),
                    [&] (auto seg) { return seg.start == edge.start && seg.stop == edge.stop; });
                active_segments.erase(remove);
            }
        }

        active_ranges.resize(std::size(active_segments));
        std::transform(
            std::begin(active_segments), std::end(active_segments),
            std::begin(active_ranges),
            [](auto edge) { return range{edge.start, edge.stop}; });

        std::sort(std::begin(active_ranges), std::end(active_ranges),
            [](auto a, auto b) { return a.start < b.start; });

        auto ranges_end = optimise_ranges(active_ranges);
        active_ranges.erase(ranges_end, std::end(active_ranges));

        alg.next(active_ranges, current_position);
    }

    return alg.output;
}

}
