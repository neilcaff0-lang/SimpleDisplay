// Standalone, time-bounded probe; never modifies an existing display.
#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>
#import "VirtualDisplayBridge.h"
#include <stdatomic.h>
#import <QuartzCore/QuartzCore.h>
#include <unistd.h>
#include <math.h>
static _Atomic unsigned long ticks = 0;
static CVReturn onFrame(CVDisplayLinkRef l, const CVTimeStamp *n, const CVTimeStamp *o,
 CVOptionFlags f, CVOptionFlags *out, void *ctx) {
    atomic_fetch_add(&ticks, 1); return kCVReturnSuccess;
}
int main(int argc, const char *argv[]) { @autoreleasepool {
    NSUInteger w = argc > 1 ? strtoul(argv[1], NULL, 10) : 1512;
    NSUInteger h = argc > 2 ? strtoul(argv[2], NULL, 10) : 982;
    BOOL retina = argc > 3 ? atoi(argv[3]) != 0 : YES;
    double hz = argc > 4 ? atof(argv[4]) : 120;
    double duration = argc > 5 ? atof(argv[5]) : 12;
    if (duration < 1 || duration > 600) return 2;
    if (w < 100 || w > 3840 || h < 100 || h > 2160 || hz < 60 || hz > 120) return 2;
    CGDirectDisplayID originalMain = CGMainDisplayID();
    NSUInteger pw = retina ? w * 2 : w, ph = retina ? h * 2 : h;
    VirtualDisplayWrapper *display = [VirtualDisplayWrapper createWithName:@"Neil120HzProbe"
        vendorID:0x4e45 productID:0x120 serialNumber:(uint32_t)getpid()
        sizeInMillimeters:CGSizeMake(320, 208) maxPixelsWide:pw maxPixelsHigh:ph
        terminationQueue:dispatch_get_main_queue() terminationHandler:^{}];
    if (!display || ![display applyWidth:w height:h refreshRate:hz hiDPI:retina]) {
        fprintf(stderr, "create/apply failed\n"); return 3;
    }
    CGDirectDisplayID did = display.displayID;
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:3]];
    CFArrayRef modes = CGDisplayCopyAllDisplayModes(did, (__bridge CFDictionaryRef)@{(__bridge NSString *)kCGDisplayShowDuplicateLowResolutionModes:@YES});
    BOOL found = NO;
    for (id obj in (__bridge NSArray *)modes) {
        CGDisplayModeRef mode = (__bridge CGDisplayModeRef)obj;
        printf("offered logical=%zux%zu pixels=%zux%zu hz=%.3f\n", CGDisplayModeGetWidth(mode), CGDisplayModeGetHeight(mode), CGDisplayModeGetPixelWidth(mode), CGDisplayModeGetPixelHeight(mode), CGDisplayModeGetRefreshRate(mode));
        if (CGDisplayModeGetWidth(mode) == w && CGDisplayModeGetHeight(mode) == h &&
            CGDisplayModeGetPixelWidth(mode) == pw && CGDisplayModeGetPixelHeight(mode) == ph &&
            fabs(CGDisplayModeGetRefreshRate(mode) - hz) < 1) {
            CGError err = CGDisplaySetDisplayMode(did, mode, NULL);
            printf("set_own_mode_error=%d\n", err); found = err == kCGErrorSuccess; break;
        }
    }
    if (modes) CFRelease(modes);
    if (!found || CGMainDisplayID() != originalMain) {
        fprintf(stderr, "desired mode unavailable or main display changed; probe aborted\n");
        [display invalidate]; return 4;
    }
    CGDisplayModeRef current = CGDisplayCopyDisplayMode(did);
    printf("id=%u main=%u logical=%zux%zu pixels=%zux%zu nominal_hz=%.3f\n", did, CGMainDisplayID(),
        CGDisplayModeGetWidth(current),CGDisplayModeGetHeight(current),
        CGDisplayModeGetPixelWidth(current),CGDisplayModeGetPixelHeight(current),CGDisplayModeGetRefreshRate(current));
    CGDisplayModeRelease(current); fflush(stdout);
    CVDisplayLinkRef link = NULL;
    CVReturn rc = CVDisplayLinkCreateWithCGDisplay(did, &link);
    if (rc != kCVReturnSuccess) { [display invalidate]; return 5; }
    CVDisplayLinkSetOutputCallback(link, onFrame, NULL);
    CFTimeInterval start = CACurrentMediaTime();
    CVDisplayLinkStart(link);
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:duration]];
    CVDisplayLinkStop(link);
    CFTimeInterval elapsed = CACurrentMediaTime() - start;
    printf("callbacks=%lu elapsed=%.6f callbacks_per_second=%.3f original_main_unchanged=%d\n",
       atomic_load(&ticks), elapsed, atomic_load(&ticks)/elapsed, CGMainDisplayID()==originalMain);
    CVDisplayLinkRelease(link); [display invalidate];
    printf("Probe removed its own display. No existing display was reconfigured.\n");
    return 0;
}}
