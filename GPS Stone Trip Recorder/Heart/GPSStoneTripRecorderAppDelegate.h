/*
 * GPSRecorderAppDelegate.h
 * GPS Stone Trip Recorder
 *
 * Created by François on 7/10/09.
 * Copyright VSO-Software 2009. All rights reserved.
 */

#import "GPXgpxType.h"



@class MainViewController;

@interface GPSStoneTripRecorderAppDelegate : NSObject <UIApplicationDelegate> {
	MainViewController *rootViewController;
	GPXgpxType *gpxElement;
}

@end
