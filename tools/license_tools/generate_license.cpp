#include <iomanip>
#include <iostream>
#include <sstream>
#include <string>

#include <openssl/sha.h>

static std::string to_hex(const unsigned char *data, size_t len) {
    std::ostringstream oss;
    for (size_t i = 0; i < len; ++i) {
        oss << std::hex << std::setw(2) << std::setfill('0') << (int)data[i];
    }
    return oss.str();
}

static std::string sha256_hex(const std::string &input) {
    unsigned char hash[SHA256_DIGEST_LENGTH];
    SHA256(reinterpret_cast<const unsigned char *>(input.c_str()), input.size(), hash);
    return to_hex(hash, SHA256_DIGEST_LENGTH);
}

static std::string base64_encode(const std::string &in) {
    static const char *tbl =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    std::string out;
    int val = 0, valb = -6;
    for (unsigned char c : in) {
        val = (val << 8) + c;
        valb += 8;
        while (valb >= 0) {
            out.push_back(tbl[(val >> valb) & 0x3F]);
            valb -= 6;
        }
    }
    if (valb > -6) out.push_back(tbl[((val << 8) >> (valb + 8)) & 0x3F]);
    while (out.size() % 4) out.push_back('=');
    return out;
}

static std::string get_arg(int argc, char **argv, const std::string &key) {
    for (int i = 1; i < argc; ++i) {
        if (key == argv[i] && i + 1 < argc) {
            return argv[i + 1];
        }
    }
    return "";
}

int main(int argc, char **argv) {
    const std::string secret = get_arg(argc, argv, "--secret");
    const std::string account = get_arg(argc, argv, "--account");
    const std::string expiration = get_arg(argc, argv, "--expiration");
    const std::string symbols = get_arg(argc, argv, "--symbols");
    const std::string timeframes = get_arg(argc, argv, "--timeframes");
    const std::string max_lot = get_arg(argc, argv, "--max-lot");
    const std::string strategies = get_arg(argc, argv, "--strategies");
    const bool demo = (get_arg(argc, argv, "--demo") == "1");

    if (secret.empty() || account.empty() || expiration.empty() || symbols.empty() ||
        timeframes.empty() || max_lot.empty() || strategies.empty()) {
        std::cerr << "Usage: generate_license --secret S --account A --expiration YYYY-MM-DD "
                     "--symbols CSV --timeframes CSV --max-lot N --strategies CSV [--demo 1]\n";
        return 1;
    }

    std::ostringstream payload;
    payload << "a=" << account
            << "|e=" << expiration
            << "|s=" << symbols
            << "|t=" << timeframes
            << "|l=" << max_lot
            << "|g=" << strategies
            << "|d=" << (demo ? "1" : "0");

    const std::string payload_str = payload.str();
    const std::string full_hash_hex = sha256_hex(secret + payload_str);

    unsigned char full_hash[SHA256_DIGEST_LENGTH];
    SHA256(reinterpret_cast<const unsigned char *>( (secret + payload_str).c_str() ),
           (secret + payload_str).size(), full_hash);

    std::string short_hash(reinterpret_cast<const char *>(full_hash), 16);
    std::string signature = base64_encode(short_hash);
    while (!signature.empty() && signature.back() == '=') signature.pop_back();
    for (char &c : signature) {
        if (c == '+') c = '-';
        if (c == '/') c = '_';
    }

    std::string payload_b64 = base64_encode(payload_str);
    while (!payload_b64.empty() && payload_b64.back() == '=') payload_b64.pop_back();
    for (char &c : payload_b64) {
        if (c == '+') c = '-';
        if (c == '/') c = '_';
    }

    const std::string key = payload_b64 + "." + signature;

    std::cout << "payload: " << payload_str << "\n";
    std::cout << "signature: " << signature << "\n";
    std::cout << "key: " << key << "\n";
    return 0;
}
