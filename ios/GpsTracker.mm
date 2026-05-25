#import "GpsTracker.h"
#import <CoreLocation/CoreLocation.h>
#import "GpsTracker-Swift.h"

@implementation GpsTracker

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
    return std::make_shared<facebook::react::NativeGpsTrackerSpecJSI>(params);
}

+ (NSString *)moduleName
{
  return @"GpsTracker";
}

- (void)configure:(NSDictionary *)config
{
  [[GPSManager shared] configureWithConfig:config];
}

- (void)requestPermission
{
  [[GPSManager shared] requestPermission];
}

- (void)startTracking
{
  [[GPSManager shared] startTracking];
}

- (void)stopTracking
{
  [[GPSManager shared] stopTracking];
}

- (void)getCurrentLocation
{
  [[GPSManager shared] getCurrentLocation];
}

@end
