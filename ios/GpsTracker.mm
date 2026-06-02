#import "GpsTracker.h"
#import <CoreLocation/CoreLocation.h>
#import <React/RCTBridgeModule.h>
#import <objc/message.h>

static id GpsTrackerSharedManager(void)
{
  Class managerClass = NSClassFromString(@"GpsTrackerGPSManager");
  if (managerClass == Nil || ![managerClass respondsToSelector:@selector(shared)]) {
    return nil;
  }

  return ((id (*)(id, SEL))objc_msgSend)(managerClass, @selector(shared));
}

static void GpsTrackerSendVoid(id target, SEL selector)
{
  if (target != nil && [target respondsToSelector:selector]) {
    ((void (*)(id, SEL))objc_msgSend)(target, selector);
  }
}

@implementation GpsTracker

RCT_EXPORT_MODULE()

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
    return std::make_shared<facebook::react::NativeGpsTrackerSpecJSI>(params);
}

- (void)configure:(NSDictionary *)config
{
  id manager = GpsTrackerSharedManager();
  SEL selector = @selector(configureWithConfig:);
  if (manager != nil && [manager respondsToSelector:selector]) {
    ((void (*)(id, SEL, NSDictionary *))objc_msgSend)(manager, selector, config);
  }
}

- (void)requestPermission
{
  GpsTrackerSendVoid(GpsTrackerSharedManager(), @selector(requestPermission));
}

- (void)startTracking
{
  GpsTrackerSendVoid(GpsTrackerSharedManager(), @selector(startTracking));
}

- (void)stopTracking
{
  GpsTrackerSendVoid(GpsTrackerSharedManager(), @selector(stopTracking));
}

- (void)getCurrentLocation
{
  GpsTrackerSendVoid(GpsTrackerSharedManager(), @selector(getCurrentLocation));
}

@end
