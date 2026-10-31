#pragma once

#include <vector>
#include <cmath>
#include <chrono>
#include <algorithm>
#include <unordered_map>
#include <iostream>
#include "osc_out.hpp"

namespace bridge {

struct Point2D {
    float x{0.0f};       // meters (Cartesian)
    float y{0.0f};       // meters (Cartesian)
    float angle_deg{0.0f};
    float dist_m{0.0f};
    uint8_t quality{0};
};

struct Cluster {
    float cx{0.0f};      // centroid X
    float cy{0.0f};      // centroid Y
    int count{0};        // number of points in cluster
    float radius{0.0f};  // approximate size
};

struct TrackedPlayer {
    int id{0};
    float x{0.0f};       // world coordinates (meters)
    float y{0.0f};
    float norm_x{0.0f};  // normalized [0.0, 1.0]
    float norm_y{0.0f};
    std::chrono::steady_clock::time_point last_seen;
    bool active{true};
};

struct PlayfieldBounds {
    float min_x{-3.0f};
    float max_x{3.0f};
    float min_y{0.0f};
    float max_y{6.0f};
};

class LidarTracker {
public:
    LidarTracker() 
        : next_id_(0),
          cluster_dist_thresh_(0.35f),
          min_cluster_points_(4),
          max_cluster_radius_(0.45f),
          max_match_dist_(0.80f),
          timeout_sec_(0.45f) {}

    void setBounds(const PlayfieldBounds& bounds) {
        bounds_ = bounds;
    }

    void setParams(float clusterDist, int minPts, float maxMatchDist, float timeoutSec) {
        cluster_dist_thresh_ = clusterDist;
        min_cluster_points_ = minPts;
        max_match_dist_ = maxMatchDist;
        timeout_sec_ = timeoutSec;
    }

    // Process a full 360-degree scan and dispatch OSC messages
    void processScan(const std::vector<Point2D>& points, UdpSender& oscSender) {
        auto now = std::chrono::steady_clock::now();

        // 1. Filter points inside playfield bounds
        std::vector<Point2D> filtered;
        filtered.reserve(points.size());
        for (const auto& pt : points) {
            if (pt.dist_m <= 0.05f) continue;
            if (pt.x >= bounds_.min_x && pt.x <= bounds_.max_x &&
                pt.y >= bounds_.min_y && pt.y <= bounds_.max_y) {
                filtered.push_back(pt);
            }
        }

        // 2. Segment points into contiguous clusters
        std::vector<Cluster> clusters = clusterPoints(filtered);

        // 3. Match clusters to existing tracks
        std::vector<bool> cluster_matched(clusters.size(), false);
        std::vector<int> tracks_to_remove;

        for (auto& pair : tracks_) {
            auto& trk = pair.second;
            int best_idx = -1;
            float best_dist = max_match_dist_;

            for (size_t i = 0; i < clusters.size(); ++i) {
                if (cluster_matched[i]) continue;
                float dx = clusters[i].cx - trk.x;
                float dy = clusters[i].cy - trk.y;
                float d = std::sqrt(dx * dx + dy * dy);
                if (d < best_dist) {
                    best_dist = d;
                    best_idx = static_cast<int>(i);
                }
            }

            if (best_idx >= 0) {
                // Smooth movement (alpha filter)
                const float alpha = 0.65f;
                trk.x = alpha * clusters[best_idx].cx + (1.0f - alpha) * trk.x;
                trk.y = alpha * clusters[best_idx].cy + (1.0f - alpha) * trk.y;
                trk.norm_x = normalize(trk.x, bounds_.min_x, bounds_.max_x);
                trk.norm_y = normalize(trk.y, bounds_.min_y, bounds_.max_y);
                trk.last_seen = now;
                cluster_matched[best_idx] = true;

                // Send update
                sendPlayerUpdate(oscSender, trk);
            } else {
                // Check timeout
                std::chrono::duration<float> elapsed = now - trk.last_seen;
                if (elapsed.count() > timeout_sec_) {
                    tracks_to_remove.push_back(trk.id);
                }
            }
        }

        // 4. Create new tracks for unmatched clusters
        for (size_t i = 0; i < clusters.size(); ++i) {
            if (!cluster_matched[i]) {
                TrackedPlayer new_trk;
                new_trk.id = next_id_++;
                // Keep IDs in a reasonable cycling range (0..31)
                if (next_id_ > 1000) next_id_ = 0;

                new_trk.x = clusters[i].cx;
                new_trk.y = clusters[i].cy;
                new_trk.norm_x = normalize(new_trk.x, bounds_.min_x, bounds_.max_x);
                new_trk.norm_y = normalize(new_trk.y, bounds_.min_y, bounds_.max_y);
                new_trk.last_seen = now;
                new_trk.active = true;

                tracks_[new_trk.id] = new_trk;
                sendPlayerUpdate(oscSender, new_trk);
            }
        }

        // 5. Remove timed-out tracks and broadcast removal
        for (int id : tracks_to_remove) {
            tracks_.erase(id);
            sendPlayerRemove(oscSender, id);
        }
    }

    const std::unordered_map<int, TrackedPlayer>& getTracks() const {
        return tracks_;
    }

private:
    float normalize(float val, float min_val, float max_val) {
        if (std::abs(max_val - min_val) < 0.0001f) return 0.5f;
        float norm = (val - min_val) / (max_val - min_val);
        return std::clamp(norm, 0.0f, 1.0f);
    }

    std::vector<Cluster> clusterPoints(const std::vector<Point2D>& pts) {
        std::vector<Cluster> clusters;
        if (pts.empty()) return clusters;

        std::vector<Point2D> current_group;
        current_group.push_back(pts[0]);

        for (size_t i = 1; i < pts.size(); ++i) {
            float dx = pts[i].x - pts[i - 1].x;
            float dy = pts[i].y - pts[i - 1].y;
            float dist = std::sqrt(dx * dx + dy * dy);

            if (dist <= cluster_dist_thresh_) {
                current_group.push_back(pts[i]);
            } else {
                if (static_cast<int>(current_group.size()) >= min_cluster_points_) {
                    Cluster c = computeCluster(current_group);
                    if (c.radius <= max_cluster_radius_) {
                        clusters.push_back(c);
                    }
                }
                current_group.clear();
                current_group.push_back(pts[i]);
            }
        }

        if (static_cast<int>(current_group.size()) >= min_cluster_points_) {
            Cluster c = computeCluster(current_group);
            if (c.radius <= max_cluster_radius_) {
                clusters.push_back(c);
            }
        }

        return clusters;
    }

    Cluster computeCluster(const std::vector<Point2D>& group) {
        Cluster c;
        c.count = static_cast<int>(group.size());
        float sum_x = 0.0f, sum_y = 0.0f;
        for (const auto& p : group) {
            sum_x += p.x;
            sum_y += p.y;
        }
        c.cx = sum_x / c.count;
        c.cy = sum_y / c.count;

        float max_r2 = 0.0f;
        for (const auto& p : group) {
            float dx = p.x - c.cx;
            float dy = p.y - c.cy;
            max_r2 = std::max(max_r2, dx * dx + dy * dy);
        }
        c.radius = std::sqrt(max_r2);
        return c;
    }

    void sendPlayerUpdate(UdpSender& sender, const TrackedPlayer& p) {
        // 1. Send /player/update [id, x, y] (Godot and universal receiver format)
        OscPacket pkt1("/player/update");
        pkt1.addInt(p.id);
        pkt1.addFloat(p.norm_x);
        pkt1.addFloat(p.norm_y);
        sender.send(pkt1.finalize());

        // 2. Send /player/<id> [x, y] (Compact channel format)
        std::string chanAddr = "/player/" + std::to_string(p.id);
        OscPacket pkt2(chanAddr);
        pkt2.addFloat(p.norm_x);
        pkt2.addFloat(p.norm_y);
        sender.send(pkt2.finalize());
    }

    void sendPlayerRemove(UdpSender& sender, int id) {
        OscPacket pkt("/player/remove");
        pkt.addInt(id);
        sender.send(pkt.finalize());
    }

    PlayfieldBounds bounds_;
    int next_id_;
    float cluster_dist_thresh_;
    int min_cluster_points_;
    float max_cluster_radius_;
    float max_match_dist_;
    float timeout_sec_;
    std::unordered_map<int, TrackedPlayer> tracks_;
};

} // namespace bridge
