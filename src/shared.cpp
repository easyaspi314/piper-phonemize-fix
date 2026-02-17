#include "shared.hpp"

std::mutex espeak_lock_impl;

PIPERPHONEMIZE_EXPORT std::mutex &espeak_lock() {
  return espeak_lock_impl;
}

