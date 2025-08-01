//
//  JFLocation.m
//  Football
//
//  Created by 崔逢举 on 16/6/7.
//  Copyright © 2016年 zhangzhifeng. All rights reserved.
//

#import "JFLocation.h"

#import <CoreLocation/CoreLocation.h>

@interface JFLocation ()<CLLocationManagerDelegate>

@property (nonatomic, strong) CLLocationManager *locationManager;
@end

@implementation JFLocation

- (instancetype)init {
    if (self = [super init]) {
        [self startPositioningSystem];
    }
    return self;
}

- (void)startPositioningSystem {
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;
    if ([self.locationManager respondsToSelector:@selector(requestAlwaysAuthorization)]) {
        [self.locationManager requestWhenInUseAuthorization];
    }
    self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    self.locationManager.distanceFilter = kCLDistanceFilterNone;
    [self.locationManager startUpdatingLocation];
}

#pragma mark CLLocationManagerDelegate
- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(nonnull NSArray<CLLocation *> *)locations {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(locating)]) {
            [self.delegate locating];
        }
    });
    CLLocation *location = [locations lastObject];
    CLLocationCoordinate2D coordinate = location.coordinate;
    NSMutableDictionary *locationDic = [NSMutableDictionary dictionaryWithCapacity:0];
    if (coordinate.longitude == 0) {
        locationDic = [@{@"currentLat":@(0),
                        @"currentLng":@(0)
                        }mutableCopy];
    }
    else {
        locationDic = [@{@"currentLng":@(coordinate.longitude),
                        @"currentLat":@(coordinate.latitude)
                        } mutableCopy];
    }
    CLGeocoder * geoCoder = [[CLGeocoder alloc] init];
    [geoCoder reverseGeocodeLocation:[locations lastObject] completionHandler:^(NSArray *placemarks, NSError *error) {
        for (CLPlacemark * placemark in placemarks) {
            NSDictionary *location = [placemark addressDictionary];
            [locationDic setValuesForKeysWithDictionary:location];
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                if (self.delegate && [self.delegate respondsToSelector:@selector(currentLocation:)]) {
                    [self.delegate currentLocation:locationDic];
                }
            });
        }
    }];
    [manager stopUpdatingLocation];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error{
    if ([error code] == kCLErrorDenied) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(refuseToUsePositioningSystem:)]) {
            [self.delegate refuseToUsePositioningSystem:@"已拒绝使用定位系统"];
        }
    }
    if ([error code] == kCLErrorLocationUnknown) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            if (self.delegate && [self.delegate respondsToSelector:@selector(locateFailure:)]) {
                [self.delegate locateFailure:@"无法获取位置信息"];
            }
        });
    }
}

@end
