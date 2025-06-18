#include "hackatime_doctor.h"
#include "checks.h"

namespace fs = std::filesystem;

CheckResult check_git_installed() {
    int result = system("git --version > /dev/null 2>&1");
    return {result == 0, result == 0 ? "Git is installed" : "Git is not installed or not in PATH", "git_check"};
}

CheckResult check_node_installed() {
    int result = system("node --version > /dev/null 2>&1");
    if (result != 0) {
        return {false, "Node.js is not installed or not in PATH", "nodejs_check"};
    }
    
    FILE* pipe = popen("node --version", "r");
    if (!pipe) return {true, "Node.js is installed (version check failed)"};
    
    char buffer[128];
    std::string version;
    while (!feof(pipe)) {
        if (fgets(buffer, 128, pipe) != NULL)
            version += buffer;
    }
    pclose(pipe);
    
    int major_version = 0;
    if (sscanf(version.c_str(), "v%d", &major_version) == 1) {
        if (major_version >= 16) {
            return {true, "Node.js v" + std::to_string(major_version) + " is installed", "nodejs_check"};
        }
        return {false, "Node.js version too old (v" + std::to_string(major_version) + "), need v16+", "nodejs_check"};
    }
    
    return {true, "Node.js is installed (version check inconclusive)", "nodejs_check"};
}

CheckResult check_folder_structure() {
    const std::vector<std::string> required_files = {
        "README.md",
        "LICENSE",
        ".gitignore"
    };

    bool all_exist = true;
    for (const auto& file : required_files) {
        if (!fs::exists(file) || !fs::is_regular_file(file)) {
            all_exist = false;
            break;
        }
    }

    if (all_exist) {
        return {true, "All required files present", "folder_structure_check"};
    }

    std::string missing;
    for (const auto& file : required_files) {
        if (!fs::exists(file)) {
            if (!missing.empty()) missing += ", ";
            missing += file;
        }
    }

    return {false, "Missing required files: " + missing, "folder_structure_check"};
}

CheckResult check_api_tokens() {
    const char* api_key = std::getenv("HACKATIME_API_KEY");
    const char* api_url = std::getenv("HACKATIME_API_URL");
    
    if (!api_key || !api_url) {
        std::string error = "Missing environment variables:";
        if (!api_key) error += "\n  - HACKATIME_API_KEY";
        if (!api_url) error += "\n  - HACKATIME_API_URL";
        error += "\nGet them from: https://hackatime.hackclub.com/my/wakatime_setup";
        return {false, error, "api_connection_check"};
    }

    std::string full_url = std::string(api_url) + "/users/current/heartbeats";
    
    size_t protocol_end = full_url.find("://");
    if (protocol_end == std::string::npos) {
        return {false, "Invalid API URL format (missing protocol)", "api_connection_check"};
    }

    size_t host_start = protocol_end + 3;
    size_t path_start = full_url.find('/', host_start);
    
    std::string host = full_url.substr(host_start, path_start - host_start);
    std::string path = path_start != std::string::npos ? full_url.substr(path_start) : "/";
    
    int port = full_url.find("https://") == 0 ? 443 : 80;

    SSL_CTX* ctx = nullptr;
    SSL* ssl = nullptr;
    if (port == 443) {
        SSL_library_init();
        SSL_load_error_strings();
        OpenSSL_add_all_algorithms();
        ctx = SSL_CTX_new(TLS_client_method());
        if (!ctx) {
            return {false, "SSL context creation failed", "api_connection_check"};
        }
    }

    int sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock < 0) {
        if (ctx) SSL_CTX_free(ctx);
        return {false, "Socket creation failed", "api_connection_check"};
    }

    hostent* server = gethostbyname(host.c_str());
    if (!server) {
        close(sock);
        if (ctx) SSL_CTX_free(ctx);
        return {false, "Host resolution failed", "api_connection_check"};
    }

    sockaddr_in serv_addr{};
    serv_addr.sin_family = AF_INET;
    serv_addr.sin_port = htons(port);
    memcpy(&serv_addr.sin_addr.s_addr, server->h_addr, server->h_length);

    if (connect(sock, (sockaddr*)&serv_addr, sizeof(serv_addr)) < 0) {
        close(sock);
        if (ctx) SSL_CTX_free(ctx);
        return {false, "Connection failed", "api_connection_check"};
    }

    if (port == 443) {
        ssl = SSL_new(ctx);
        SSL_set_fd(ssl, sock);
        if (SSL_connect(ssl) != 1) {
            SSL_free(ssl);
            close(sock);
            SSL_CTX_free(ctx);
            return {false, "SSL handshake failed" , "api_connection_check"};
        }
    }

    std::time_t now = std::time(nullptr);
    std::string payload = R"([{
        "type": "file",
        "time": )" + std::to_string(now) + R"(,
        "entity": "hackatime-doctor-validate.txt",
        "language": "Text"
    }])";

    std::string request = "POST " + path + " HTTP/1.1\r\n"
                       "Host: " + host + "\r\n"
                       "Authorization: Bearer " + std::string(api_key) + "\r\n"
                       "Content-Type: application/json\r\n"
                       "Content-Length: " + std::to_string(payload.length()) + "\r\n\r\n"
                       + payload;

    int bytes_sent;
    if (port == 443) {
        bytes_sent = SSL_write(ssl, request.c_str(), request.length());
    } else {
        bytes_sent = send(sock, request.c_str(), request.length(), 0);
    }

    if (bytes_sent <= 0) {
        if (ssl) SSL_free(ssl);
        close(sock);
        if (ctx) SSL_CTX_free(ctx);
        return {false, "Failed to send heartbeat", "api_connection_check"};
    }

    char buffer[4096];
    int bytes_received;
    if (port == 443) {
        bytes_received = SSL_read(ssl, buffer, sizeof(buffer)-1);
    } else {
        bytes_received = recv(sock, buffer, sizeof(buffer)-1, 0);
    }
    
    if (bytes_received <= 0) {
        if (ssl) SSL_free(ssl);
        close(sock);
        if (ctx) SSL_CTX_free(ctx);
        return {false, "No response from server", "api_connection_check"};
    }
    buffer[bytes_received] = '\0';

    if (ssl) {
        SSL_shutdown(ssl);
        SSL_free(ssl);
    }
    close(sock);
    if (ctx) SSL_CTX_free(ctx);

    std::string response(buffer);
    if (response.find("HTTP/1.1 20") != std::string::npos) {  
        return {true, "Heartbeat sent successfully, hackatime is working!", "api_connection_check"};
    }
    
    return {false, "API request failed: " + response.substr(0, response.find("\r\n\r\n")), "api_connection_check"};
}
