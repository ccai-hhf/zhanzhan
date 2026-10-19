#ifndef ZHANZHAN_NATIVE_TOUCH_H
#define ZHANZHAN_NATIVE_TOUCH_H
#include <stdint.h>
typedef struct { int32_t id; double x; double y; } ZZFinger;
typedef void (*ZZTouchCallback)(const ZZFinger *, int32_t count, double timestamp);
// Main-thread lifecycle. Returns 0 on success, -1 API unavailable, -2 no device, -3 start failed.
int32_t ZZTouchStart(ZZTouchCallback callback);
void ZZTouchStop(void);
#endif
