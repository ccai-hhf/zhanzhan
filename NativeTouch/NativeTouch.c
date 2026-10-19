#include "NativeTouch.h"
#include <dlfcn.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <stddef.h>
// ABI declarations adapted from OpenMultitouchSupport (MIT, Takuto Nakamura).
// https://github.com/Kyome22/OpenMultitouchSupport @ 15c6bb0
// This is a private macOS API; resolve every required symbol and fail closed.
typedef struct { float x, y; } MTPoint;
typedef struct { MTPoint position, velocity; } MTVector;
typedef struct {
    int frame; double timestamp; int identifier, state, fingerId, handId;
    MTVector normalizedPosition; float total, pressure, angle, majorAxis, minorAxis;
    MTVector absolutePosition; int field14, field15; float density;
} MTTouch;
typedef void (*FrameCallback)(void *, MTTouch *, int, double, int);
static void *library, *device;
static bool (*available)(void);
static void *(*createDefault)(void);
static int (*startDevice)(void *, int), (*stopDevice)(void *);
static void (*releaseDevice)(void *);
static void (*registerFrame)(void *, FrameCallback), (*unregisterFrame)(void *, FrameCallback);
static _Atomic(ZZTouchCallback) receiver;

static void frameReceived(void *sender, MTTouch *touches, int count, double time, int frame) {
    ZZTouchCallback callback = atomic_load(&receiver);
    if (!callback || count < 0 || count > 32) return;
    ZZFinger fingers[32]; int active = 0;
    for (int i = 0; i < count; i++) {
        if (touches[i].state != 3 && touches[i].state != 4) continue;
        fingers[active++] = (ZZFinger){touches[i].identifier,
            touches[i].normalizedPosition.position.x, touches[i].normalizedPosition.position.y};
    }
    callback(fingers, active, time);
}
int32_t ZZTouchStart(ZZTouchCallback callback) {
    ZZTouchStop();
    if (!library) library = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_LAZY | RTLD_LOCAL);
    if (!library) return -1;
    available = dlsym(library, "MTDeviceIsAvailable");
    createDefault = dlsym(library, "MTDeviceCreateDefault");
    startDevice = dlsym(library, "MTDeviceStart");
    stopDevice = dlsym(library, "MTDeviceStop");
    releaseDevice = dlsym(library, "MTDeviceRelease");
    registerFrame = dlsym(library, "MTRegisterContactFrameCallback");
    unregisterFrame = dlsym(library, "MTUnregisterContactFrameCallback");
    if (!available || !createDefault || !startDevice || !stopDevice || !releaseDevice || !registerFrame || !unregisterFrame) return -1;
    if (!available() || !(device = createDefault())) return -2;
    atomic_store(&receiver, callback);
    registerFrame(device, frameReceived);
    if (startDevice(device, 0) != 0) { ZZTouchStop(); return -3; }
    return 0;
}
void ZZTouchStop(void) {
    atomic_store(&receiver, NULL);
    if (!device) return;
    unregisterFrame(device, frameReceived);
    stopDevice(device);
    releaseDevice(device);
    device = NULL;
}
