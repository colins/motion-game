#pragma once

#include <vector>
#include <cmath>
#include <random>
#include <chrono>
#include "tracker.hpp"

namespace bridge {

class MockLidar {
public:
    MockLidar(float roomWidth = 8.0f, float roomDepth = 8.0f)
        : room_w_(roomWidth), room_d_(roomDepth), gen_(42), noise_dist_(0.0f, 0.008f) {
        
        // Initialize 2 simulated players
        sim_players_.push_back({0.0f, 2.5f, 0.7f, 0.4f, 0.18f}); // x, y, vx, vy, radius
        sim_players_.push_back({-1.2f, 4.0f, -0.5f, -0.3f, 0.18f});
    }

    // Generate a single 360-degree simulated scan sweep
    std::vector<Point2D> generateScan(float dt) {
        // Update simulated player positions
        updatePlayers(dt);

        std::vector<Point2D> points;
        const int num_rays = 1200; // ~1200 rays per scan (~15 Hz = 18,000 samples/sec)
        points.reserve(num_rays);

        for (int i = 0; i < num_rays; ++i) {
            float angle_deg = (360.0f * i) / num_rays;
            float angle_rad = angle_deg * (M_PI / 180.0f);
            float dir_x = std::cos(angle_rad);
            float dir_y = std::sin(angle_rad);

            // Ray origin is at (0, 0)
            float hit_dist = 100.0f;
            uint8_t hit_quality = 47; // standard S2 quality

            // 1. Intersect with room bounding walls
            // Room coordinates: x in [-room_w_/2, room_w_/2], y in [0.0, room_d_]
            float min_x = -room_w_ / 2.0f;
            float max_x = room_w_ / 2.0f;
            float min_y = -0.5f;
            float max_y = room_d_;

            if (dir_x > 0.0001f) {
                float d = (max_x) / dir_x;
                float y = d * dir_y;
                if (d > 0 && y >= min_y && y <= max_y) hit_dist = std::min(hit_dist, d);
            } else if (dir_x < -0.0001f) {
                float d = (min_x) / dir_x;
                float y = d * dir_y;
                if (d > 0 && y >= min_y && y <= max_y) hit_dist = std::min(hit_dist, d);
            }

            if (dir_y > 0.0001f) {
                float d = (max_y) / dir_y;
                float x = d * dir_x;
                if (d > 0 && x >= min_x && x <= max_x) hit_dist = std::min(hit_dist, d);
            } else if (dir_y < -0.0001f) {
                float d = (min_y) / dir_y;
                float x = d * dir_x;
                if (d > 0 && x >= min_x && x <= max_x) hit_dist = std::min(hit_dist, d);
            }

            // 2. Intersect with moving simulated kids (circles)
            for (const auto& sp : sim_players_) {
                float d_circle = rayCircleIntersect(0.0f, 0.0f, dir_x, dir_y, sp.x, sp.y, sp.radius);
                if (d_circle > 0.0f && d_circle < hit_dist) {
                    hit_dist = d_circle;
                    hit_quality = 60; // stronger reflection
                }
            }

            // Add slight sensor noise
            hit_dist += noise_dist_(gen_);
            if (hit_dist < 0.10f) hit_dist = 0.0f;

            Point2D pt;
            pt.angle_deg = angle_deg;
            pt.dist_m = hit_dist;
            pt.x = hit_dist * dir_x;
            pt.y = hit_dist * dir_y;
            pt.quality = hit_quality;
            points.push_back(pt);
        }

        return points;
    }

private:
    struct SimPlayer {
        float x, y;
        float vx, vy;
        float radius;
    };

    void updatePlayers(float dt) {
        float min_x = -room_w_ / 2.0f + 0.5f;
        float max_x = room_w_ / 2.0f - 0.5f;
        float min_y = 0.5f;
        float max_y = room_d_ - 0.5f;

        for (auto& p : sim_players_) {
            p.x += p.vx * dt;
            p.y += p.vy * dt;

            // Bounce off boundaries
            if (p.x < min_x) { p.x = min_x; p.vx = std::abs(p.vx); }
            if (p.x > max_x) { p.x = max_x; p.vx = -std::abs(p.vx); }
            if (p.y < min_y) { p.y = min_y; p.vy = std::abs(p.vy); }
            if (p.y > max_y) { p.y = max_y; p.vy = -std::abs(p.vy); }
        }
    }

    // Ray-circle intersection test
    float rayCircleIntersect(float ox, float oy, float dx, float dy, float cx, float cy, float r) {
        float fx = ox - cx;
        float fy = oy - cy;

        float a = dx * dx + dy * dy;
        float b = 2.0f * (fx * dx + fy * dy);
        float c = (fx * fx + fy * fy) - r * r;

        float discriminant = b * b - 4.0f * a * c;
        if (discriminant < 0.0f) {
            return -1.0f;
        }

        discriminant = std::sqrt(discriminant);
        float t1 = (-b - discriminant) / (2.0f * a);
        if (t1 >= 0.0f) return t1;

        float t2 = (-b + discriminant) / (2.0f * a);
        if (t2 >= 0.0f) return t2;

        return -1.0f;
    }

    float room_w_;
    float room_d_;
    std::vector<SimPlayer> sim_players_;
    std::mt19937 gen_;
    std::normal_distribution<float> noise_dist_;
};

} // namespace bridge
