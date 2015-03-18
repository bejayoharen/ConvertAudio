//
//  ViewController.h
//  Convert Audio
//
//  Created by Bjorn Roche on 3/17/15.
//  Copyright (c) 2015 Bjorn Roche. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import "AudioConverter.h"

@interface ViewController : UIViewController <MPMediaPickerControllerDelegate,AudioConverterDelegate>

- (IBAction)selectAudioPressed:(id)sender;
@property (weak, nonatomic) IBOutlet UIView *overlayView;
@property (weak, nonatomic) IBOutlet UIProgressView *progressView;

@end