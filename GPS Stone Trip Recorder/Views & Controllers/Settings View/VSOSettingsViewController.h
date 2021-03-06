/*
 * VSOSettingsViewController.h
 * GPS Stone Trip Recorder
 *
 * Created by François on 7/10/09.
 * Copyright VSO-Software 2009. All rights reserved.
 */



@protocol VSOSettingsViewControllerDelegate;

@interface VSOSettingsViewController : UITableViewController {
	IBOutlet UISegmentedControl *segmentedCtrlMapType;
	IBOutlet UITextField *textFieldMinDist;
	IBOutlet UITextField *textFieldMinTime;
}

@property (nonatomic, weak) id <VSOSettingsViewControllerDelegate> delegate;

- (IBAction)done;

- (IBAction)mapTypeChanged:(id)sender;

- (IBAction)minDistChanged:(id)sender;
- (IBAction)minTimeChanged:(id)sender;

@end


@protocol VSOSettingsViewControllerDelegate

- (void)settingsViewControllerDidFinish:(VSOSettingsViewController *)controller;

@end
