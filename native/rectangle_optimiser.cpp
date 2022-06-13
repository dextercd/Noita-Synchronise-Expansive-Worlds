#include <algorithm>
#include <cassert>
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
    auto unconsidered_range = ranges.begin();

    for (auto segment_it = segments.begin(); segment_it != std::end(segments);) {
        auto this_segment = *segment_it;

        // First range where the end is >= this segment's start
        auto first_potential_intersect =
            std::partition_point(
                std::begin(ranges),
                std::end(ranges),
                [&](auto r) { return r.stop < this_segment.start; }
            );

        // Any ranges we skipped we must add as a new segment
        bool iterator_invalidated = false;
        for (; unconsidered_range != first_potential_intersect; ++unconsidered_range) {
            iterator_invalidated = true;
            auto range = *unconsidered_range;
            segments.insert({position, range.start, range.stop});
        }

        if (first_potential_intersect != std::end(ranges)) {
            unconsidered_range = std::next(first_potential_intersect);
        }

        // Iterators invalidated by previous insert
        if (iterator_invalidated)
            segment_it = segments.find(this_segment);

        // There's no range that intersects. Create a rectangle from this segment.
        if (first_potential_intersect == std::end(ranges)) {
            output.push_back({
                this_segment.position,
                this_segment.start,
                position,
                this_segment.stop,
            });

            segment_it = segments.erase(segment_it);
            continue;
        }

        auto range = *first_potential_intersect;

        // Perfect match, just keep this segment and continue.
        if (this_segment.start == range.start && this_segment.stop == range.stop) {
            ++segment_it;
            continue;
        }

        // Imperfect match, remove this segment and all other segments that
        // intersect with this range.
        auto erase_end = segment_it;
        for (; erase_end != std::end(segments); ++erase_end) {
            if (erase_end->start > range.stop)
                break;

            auto segment = *erase_end;
            output.push_back({
                segment.position,
                segment.start,
                position,
                segment.stop,
            });
        }

        segments.erase(segment_it, erase_end);

        // Add this range as a new segment
        auto [new_it, inserted] = segments.insert({position, range.start, range.stop});
        assert(inserted);

        segment_it = ++new_it;
    }

    // Any ranges we skipped we must add as a new segment
    for (; unconsidered_range != std::end(ranges); ++unconsidered_range) {
        auto range = *unconsidered_range;
        segments.insert({position, range.start, range.stop});
    }
}

std::vector<rectangle> rectangle_optimiser::scan()
{
    edges.clear();
    for (auto rect : rectangles) {
        edges.push_back({edge_side::left, rect.left, rect.top, rect.bottom});
        edges.push_back({edge_side::right, rect.right, rect.top, rect.bottom});
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
