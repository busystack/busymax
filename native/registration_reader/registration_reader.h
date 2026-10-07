#pragma once
#include <cstddef>
#include <cstdint>
#ifdef _WIN32
#define BUSYMAX_READER_EXPORT __declspec(dllexport)
#else
#define BUSYMAX_READER_EXPORT __attribute__((visibility("default")))
#endif
extern "C" {
// The caller and worker each own one reference. Cancellation never frees a
// handle while an in-flight worker is using it.
BUSYMAX_READER_EXPORT void* busymax_reader_create(const char*, size_t, int64_t);
BUSYMAX_READER_EXPORT void busymax_reader_cancel(void*);
BUSYMAX_READER_EXPORT void busymax_reader_release(void*);
BUSYMAX_READER_EXPORT int busymax_reader_run(void*);
BUSYMAX_READER_EXPORT const uint8_t* busymax_reader_bytes(void*);
BUSYMAX_READER_EXPORT size_t busymax_reader_size(void*);
BUSYMAX_READER_EXPORT void* busymax_reader_allocate(size_t);
BUSYMAX_READER_EXPORT void busymax_reader_free(void*);
}
#ifdef BUSYMAX_READER_TESTING
void busymax_reader_test_hook(void (*hook)(int));
#endif
