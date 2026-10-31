#pragma once

#include <string>
#include <vector>
#include <sstream>
#include <cstdint>
#include <cstring>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <unistd.h>

namespace bridge {

// Zero-dependency, low-latency OSC (Open Sound Control) packet builder
class OscPacket {
public:
    OscPacket(const std::string& address) {
        appendString(address);
        tagsPos_ = buffer_.size();
        // Placeholder for type tags; filled in finalize()
    }

    void addFloat(float value) {
        types_.push_back('f');
        uint32_t val;
        std::memcpy(&val, &value, sizeof(float));
        uint32_t be = htonl(val);
        const uint8_t* p = reinterpret_cast<const uint8_t*>(&be);
        data_.insert(data_.end(), p, p + 4);
    }

    void addInt(int32_t value) {
        types_.push_back('i');
        uint32_t be = htonl(static_cast<uint32_t>(value));
        const uint8_t* p = reinterpret_cast<const uint8_t*>(&be);
        data_.insert(data_.end(), p, p + 4);
    }

    void addString(const std::string& str) {
        types_.push_back('s');
        appendPaddedString(data_, str);
    }

    const std::vector<uint8_t>& finalize() {
        std::string tagStr = "," + types_;
        appendPaddedString(buffer_, tagStr);
        buffer_.insert(buffer_.end(), data_.begin(), data_.end());
        return buffer_;
    }

private:
    void appendString(const std::string& str) {
        appendPaddedString(buffer_, str);
    }

    static void appendPaddedString(std::vector<uint8_t>& buf, const std::string& str) {
        for (char c : str) {
            buf.push_back(static_cast<uint8_t>(c));
        }
        buf.push_back(0); // null terminator
        while (buf.size() % 4 != 0) {
            buf.push_back(0); // 4-byte alignment
        }
    }

    std::vector<uint8_t> buffer_;
    std::string types_;
    std::vector<uint8_t> data_;
    size_t tagsPos_{0};
};

// UDP Socket wrapper for sending OSC or raw packets (supports multiple comma-separated target IPs)
class UdpSender {
public:
    UdpSender() : sock_(-1) {}

    ~UdpSender() {
        closeSocket();
    }

    bool init(const std::string& targetIps, int targetPort) {
        closeSocket();
        targetIp_ = targetIps;
        targetPort_ = targetPort;
        endpoints_.clear();

        sock_ = socket(AF_INET, SOCK_DGRAM, 0);
        if (sock_ < 0) {
            return false;
        }

        // Enable broadcast just in case target IP is x.x.x.255
        int broadcastEnable = 1;
        setsockopt(sock_, SOL_SOCKET, SO_BROADCAST, &broadcastEnable, sizeof(broadcastEnable));

        // Parse comma-separated IPs (e.g. "127.0.0.1, 192.168.1.34")
        std::stringstream ss(targetIps);
        std::string ip;
        while (std::getline(ss, ip, ',')) {
            size_t first = ip.find_first_not_of(" \t\r\n");
            size_t last = ip.find_last_not_of(" \t\r\n");
            if (first == std::string::npos) continue;
            std::string clean_ip = ip.substr(first, (last - first + 1));

            struct sockaddr_in addr;
            std::memset(&addr, 0, sizeof(addr));
            addr.sin_family = AF_INET;
            addr.sin_port = htons(targetPort);
            if (inet_pton(AF_INET, clean_ip.c_str(), &addr.sin_addr) > 0) {
                endpoints_.push_back(addr);
            }
        }

        return !endpoints_.empty();
    }

    bool send(const uint8_t* data, size_t size) {
        if (sock_ < 0 || endpoints_.empty()) return false;
        bool all_ok = true;
        for (const auto& addr : endpoints_) {
            ssize_t sent = sendto(sock_, data, size, 0, (struct sockaddr*)&addr, sizeof(addr));
            if (sent != static_cast<ssize_t>(size)) {
                all_ok = false;
            }
        }
        return all_ok;
    }

    bool send(const std::vector<uint8_t>& data) {
        return send(data.data(), data.size());
    }

    void closeSocket() {
        if (sock_ >= 0) {
            ::close(sock_);
            sock_ = -1;
        }
        endpoints_.clear();
    }

    const std::string& getTargetIp() const { return targetIp_; }
    int getTargetPort() const { return targetPort_; }
    size_t getTargetCount() const { return endpoints_.size(); }

private:
    int sock_;
    std::vector<struct sockaddr_in> endpoints_;
    std::string targetIp_;
    int targetPort_{0};
};

} // namespace bridge
