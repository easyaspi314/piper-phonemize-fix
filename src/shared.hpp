#ifndef SHARED_H_
#define SHARED_H_

#ifdef _WIN32
#define PIPERPHONEMIZE_EXPORT __declspec(dllexport)
#else
#define PIPERPHONEMIZE_EXPORT
#endif

#include <mutex>

extern std::mutex espeak_lock;

#define ESPEAK_LOCK_WRAP(...) ([&]() { \
    std::lock_guard<std::mutex> lock_(espeak_lock); \
    return __VA_ARGS__; \
})()

#endif // SHARED_H_
