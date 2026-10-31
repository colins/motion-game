#include <iostream>
#include <vector>
#include <string>
#include <chrono>
#include <thread>
#include <csignal>
#include <cstring>
#include <fstream>
#include <sstream>
#include <unistd.h>

#include "sl_lidar.h"
#include "sl_lidar_driver.h"

#include "osc_out.hpp"
#include "tracker.hpp"
#include "mock_lidar.hpp"

using namespace sl;
using namespace bridge;

static volatile bool g_running = true;

void signal_handler(int) {
    g_running = false;
}

struct BridgeConfig {
    std::string serial_port = "/dev/ttyUSB0";
    uint32_t baud_rate = 1000000;
    std::string target_ip = "192.168.1.34";
    int osc_port = 9000;
    int raw_port = 7001;
    bool force_mock = false;

    PlayfieldBounds bounds = {-3.0f, 3.0f, 0.0f, 6.0f};
    float cluster_dist = 0.35f;
    int min_cluster_pts = 4;
    float max_match_dist = 0.80f;
    float timeout_sec = 0.45f;
};

// Simple config file parser (key=value or basic JSON)
void load_config(const std::string& path, BridgeConfig& cfg) {
    std::ifstream file(path);
    if (!file.is_open()) return;

    std::string line;
    while (std::getline(file, line)) {
        // Strip comments and spaces
        auto comment_pos = line.find("//");
        if (comment_pos != std::string::npos) line = line.substr(0, comment_pos);

        auto colon = line.find(':');
        if (colon == std::string::npos) colon = line.find('=');
        if (colon == std::string::npos) continue;

        std::string key = line.substr(0, colon);
        std::string val = line.substr(colon + 1);

        auto clean_str = [](std::string& s) {
            // Trim leading/trailing whitespace and quotes
            size_t start = s.find_first_not_of(" \t\r\n\"");
            size_t end = s.find_last_not_of(" \t\r\n\",");
            if (start == std::string::npos) {
                s.clear();
                return;
            }
            s = s.substr(start, (end - start + 1));
            // Remove enclosing quotes if any
            while (!s.empty() && (s.front() == '\"' || s.front() == '\'')) s.erase(s.begin());
            while (!s.empty() && (s.back() == '\"' || s.back() == '\'')) s.pop_back();
        };

        clean_str(key);
        clean_str(val);

        if (key == "serial_port") cfg.serial_port = val;
        else if (key == "baud_rate") cfg.baud_rate = std::stoul(val);
        else if (key == "target_ip") cfg.target_ip = val;
        else if (key == "osc_port") cfg.osc_port = std::stoi(val);
        else if (key == "raw_port") cfg.raw_port = std::stoi(val);
        else if (key == "mock_mode") cfg.force_mock = (val == "true" || val == "1");
        else if (key == "min_x") cfg.bounds.min_x = std::stof(val);
        else if (key == "max_x") cfg.bounds.max_x = std::stof(val);
        else if (key == "min_y") cfg.bounds.min_y = std::stof(val);
        else if (key == "max_y") cfg.bounds.max_y = std::stof(val);
    }
}

// Compact binary point structure for UDP streaming
#pragma pack(push, 1)
struct RawPointBinary {
    float angle_deg;
    float dist_m;
    float x;
    float y;
    uint8_t quality;
};

struct RawPacketHeader {
    uint32_t magic;       // 'LIDR' (0x4C494452)
    uint32_t sequence;    // scan counter
    uint16_t total_points;// total points in this scan
    uint8_t  chunk_index; // 0-based
    uint8_t  chunk_total; // total chunks for this scan
};
#pragma pack(pop)

void send_raw_points(UdpSender& sender, uint32_t scan_seq, const std::vector<Point2D>& points) {
    if (points.empty()) return;

    const size_t max_pts_per_chunk = 120; // keeps UDP packet under MTU (<1400 bytes)
    size_t total_points = points.size();
    uint8_t total_chunks = static_cast<uint8_t>((total_points + max_pts_per_chunk - 1) / max_pts_per_chunk);

    for (uint8_t c = 0; c < total_chunks; ++c) {
        size_t start_idx = c * max_pts_per_chunk;
        size_t count = std::min(max_pts_per_chunk, total_points - start_idx);

        std::vector<uint8_t> buffer(sizeof(RawPacketHeader) + count * sizeof(RawPointBinary));
        RawPacketHeader* hdr = reinterpret_cast<RawPacketHeader*>(buffer.data());
        hdr->magic = 0x4C494452;
        hdr->sequence = scan_seq;
        hdr->total_points = static_cast<uint16_t>(total_points);
        hdr->chunk_index = c;
        hdr->chunk_total = total_chunks;

        RawPointBinary* payload = reinterpret_cast<RawPointBinary*>(buffer.data() + sizeof(RawPacketHeader));
        for (size_t i = 0; i < count; ++i) {
            const auto& pt = points[start_idx + i];
            payload[i].angle_deg = pt.angle_deg;
            payload[i].dist_m = pt.dist_m;
            payload[i].x = pt.x;
            payload[i].y = pt.y;
            payload[i].quality = pt.quality;
        }

        sender.send(buffer);
    }
}

void print_help(const char* prog) {
    std::cout << "Usage: " << prog << " [options]\n"
              << "Options:\n"
              << "  --port <device>     Serial port (default: /dev/ttyUSB0)\n"
              << "  --baud <rate>       Baud rate (default: 1000000)\n"
              << "  --target <ip>       Destination IP (default: 192.168.1.34)\n"
              << "  --osc-port <port>   OSC destination port (default: 9000)\n"
              << "  --raw-port <port>   Raw point UDP port (default: 7001)\n"
              << "  --mock              Force mock/simulation mode\n"
              << "  --config <file>     Path to config file\n"
              << "  --help              Show this help message\n";
}

int main(int argc, char* argv[]) {
    std::signal(SIGINT, signal_handler);
    std::signal(SIGTERM, signal_handler);

    BridgeConfig cfg;

    // Look for default config.json
    load_config("config.json", cfg);
    load_config("/home/colin/lidar-bridge/config.json", cfg);

    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        if (arg == "--port" && i + 1 < argc) cfg.serial_port = argv[++i];
        else if (arg == "--baud" && i + 1 < argc) cfg.baud_rate = std::stoul(argv[++i]);
        else if (arg == "--target" && i + 1 < argc) cfg.target_ip = argv[++i];
        else if (arg == "--osc-port" && i + 1 < argc) cfg.osc_port = std::stoi(argv[++i]);
        else if (arg == "--raw-port" && i + 1 < argc) cfg.raw_port = std::stoi(argv[++i]);
        else if (arg == "--mock") cfg.force_mock = true;
        else if (arg == "--config" && i + 1 < argc) load_config(argv[++i], cfg);
        else if (arg == "--help") { print_help(argv[0]); return 0; }
    }

    std::cout << "====================================================\n";
    std::cout << " Slamtec RPLIDAR S2L -> Godot 4 Native Bridge\n";
    std::cout << "====================================================\n";
    std::cout << "[Config] Target IP:       " << cfg.target_ip << "\n";
    std::cout << "[Config] OSC Port:        " << cfg.osc_port << " (Players / Events)\n";
    std::cout << "[Config] Raw Point Port:  " << cfg.raw_port << " (Point Cloud / Visualizer)\n";
    std::cout << "[Config] Playfield:       X[" << cfg.bounds.min_x << "m to " << cfg.bounds.max_x
              << "m] Y[" << cfg.bounds.min_y << "m to " << cfg.bounds.max_y << "m]\n";

    UdpSender oscSender;
    if (!oscSender.init(cfg.target_ip, cfg.osc_port)) {
        std::cerr << "[Error] Failed to initialize OSC UDP socket\n";
        return 1;
    }

    UdpSender rawSender;
    if (!rawSender.init(cfg.target_ip, cfg.raw_port)) {
        std::cerr << "[Error] Failed to initialize Raw UDP socket\n";
        return 1;
    }

    LidarTracker tracker;
    tracker.setBounds(cfg.bounds);
    tracker.setParams(cfg.cluster_dist, cfg.min_cluster_pts, cfg.max_match_dist, cfg.timeout_sec);

    bool use_mock = cfg.force_mock;
    ILidarDriver* drv = nullptr;
    IChannel* channel = nullptr;

    if (!use_mock) {
        if (access(cfg.serial_port.c_str(), F_OK) != 0) {
            std::cout << "[Notice] Device " << cfg.serial_port << " not found (LiDAR not plugged in yet).\n"
                      << "[Notice] Running in MOCK SIMULATOR mode automatically.\n"
                      << "[Notice] Streaming simulated room & players to " << cfg.target_ip << "!\n";
            use_mock = true;
        } else {
            std::cout << "[Bridge] Attempting to connect to hardware on " << cfg.serial_port 
                      << " at " << cfg.baud_rate << " baud...\n";
            
            auto drv_res = createLidarDriver();
            if (!drv_res || !*drv_res) {
                std::cerr << "[Warning] Failed to instantiate Slamtec driver. Switching to Mock mode.\n";
                use_mock = true;
            } else {
                drv = *drv_res;
                auto chan_res = createSerialPortChannel(cfg.serial_port, cfg.baud_rate);
                if (!chan_res || !*chan_res) {
                    std::cerr << "[Warning] Failed to open serial channel. Switching to Mock mode.\n";
                    delete drv;
                    drv = nullptr;
                    use_mock = true;
                } else {
                    channel = *chan_res;
                    if (SL_IS_FAIL(drv->connect(channel))) {
                        std::cout << "[Notice] Connection failed on " << cfg.serial_port << ".\n"
                                  << "[Notice] Running in MOCK SIMULATOR mode.\n";
                        delete drv;
                        delete channel;
                        drv = nullptr;
                        channel = nullptr;
                        use_mock = true;
                    } else {
                        sl_lidar_response_device_info_t devinfo;
                        if (SL_IS_OK(drv->getDeviceInfo(devinfo))) {
                            printf("[Hardware] S/N: ");
                            for (int p = 0; p < 16; ++p) printf("%02X", devinfo.serialnum[p]);
                            printf(" | FW: %d.%02d | HW: %d\n", devinfo.firmware_version >> 8, devinfo.firmware_version & 0xFF, (int)devinfo.hardware_version);
                        }

                        // Start motor & scan
                        drv->setMotorSpeed();
                        // 0 = default scan mode (Dense mode for S2)
                        drv->startScan(0, 1);
                        std::cout << "[Hardware] Scan started in High-Speed mode.\n";
                    }
                }
            }
        }
    }

    uint32_t scan_seq = 0;

    if (use_mock) {
        std::cout << "[Mock] Simulator active. Broadcasting 15 Hz 360-deg scans...\n";
        MockLidar mock(cfg.bounds.max_x - cfg.bounds.min_x, cfg.bounds.max_y - cfg.bounds.min_y);

        auto last_time = std::chrono::steady_clock::now();
        while (g_running) {
            auto now = std::chrono::steady_clock::now();
            float dt = std::chrono::duration<float>(now - last_time).count();
            last_time = now;

            std::vector<Point2D> scan_points = mock.generateScan(dt);
            send_raw_points(rawSender, scan_seq++, scan_points);
            tracker.processScan(scan_points, oscSender);

            // Log tracks occasionally
            if (scan_seq % 30 == 0) {
                const auto& tracks = tracker.getTracks();
                std::cout << "[Status] Scan #" << scan_seq << " | Active players tracked: " << tracks.size() << "\r" << std::flush;
            }

            // Target 15 Hz = ~66 ms
            std::this_thread::sleep_for(std::chrono::milliseconds(66));
        }
    } else {
        sl_lidar_response_measurement_node_hq_t nodes[8192];

        while (g_running) {
            size_t count = sizeof(nodes) / sizeof(nodes[0]);
            sl_result res = drv->grabScanDataHq(nodes, count);

            if (SL_IS_OK(res)) {
                drv->ascendScanData(nodes, count);

                std::vector<Point2D> points;
                points.reserve(count);

                for (size_t i = 0; i < count; ++i) {
                    float dist_m = (nodes[i].dist_mm_q2 / 4.0f) / 1000.0f;
                    if (dist_m <= 0.05f) continue;

                    float angle_deg = (nodes[i].angle_z_q14 * 90.0f) / 16384.0f;
                    float angle_rad = angle_deg * (static_cast<float>(M_PI) / 180.0f);

                    Point2D pt;
                    pt.angle_deg = angle_deg;
                    pt.dist_m = dist_m;
                    pt.x = dist_m * std::cos(angle_rad);
                    pt.y = dist_m * std::sin(angle_rad);
                    pt.quality = nodes[i].quality >> SL_LIDAR_RESP_MEASUREMENT_QUALITY_SHIFT;
                    points.push_back(pt);
                }

                send_raw_points(rawSender, scan_seq++, points);
                tracker.processScan(points, oscSender);

                if (scan_seq % 30 == 0) {
                    const auto& tracks = tracker.getTracks();
                    std::cout << "[Hardware] Scan #" << scan_seq << " | Raw pts: " << points.size() 
                              << " | Tracked: " << tracks.size() << "\r" << std::flush;
                }
            } else {
                std::this_thread::sleep_for(std::chrono::milliseconds(5));
            }
        }

        std::cout << "\n[Bridge] Stopping hardware motor...\n";
        drv->stop();
        drv->setMotorSpeed(0);
        delete drv;
    }

    std::cout << "\n[Bridge] Shutdown complete.\n";
    return 0;
}
