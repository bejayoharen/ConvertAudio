//
//  ViewController.m
//  Convert Audio
//
//  Created by Bjorn Roche on 3/17/15.
//  Copyright (c) 2015 Bjorn Roche. All rights reserved.
//

#import "ViewController.h"
#import <MediaPlayer/MediaPlayer.h>
#import "AudioConverter.h"

@interface ViewController () {
    AudioConverter *_converter;
}

@end

@implementation ViewController

- (void) viewDidLoad {
    [super viewDidLoad];
    self.overlayView.hidden = YES;
}

- (IBAction)selectAudioPressed:(id)sender {
    // -- show the media picker to allow the user to select some media
    MPMediaPickerController *pickerController =	[[MPMediaPickerController alloc] initWithMediaTypes: MPMediaTypeAnyAudio];
    [pickerController setPrompt:@"Select a Song"];
    [pickerController setAllowsPickingMultipleItems:NO];
    pickerController.delegate = self;
    
    @try {
        [self presentViewController:pickerController animated:YES completion:nil];
    }
    @catch (NSException *exception) {
        [[[UIAlertView alloc] initWithTitle:@"Oops!"
                                    message:@"The music library is not available."
                                   delegate:nil
                          cancelButtonTitle:@"OK"
                          otherButtonTitles:nil] show];
    }
}

# pragma - mark media picker delegate
- (void)mediaPicker:(MPMediaPickerController *)mediaPicker didPickMediaItems:(MPMediaItemCollection *)mediaItemCollection;
{
    [self dismissViewControllerAnimated:YES completion:nil];
    if( [[mediaItemCollection items] count] != 1 ) {
        NSLog( @"Recieved unexpected number of items from media picker: %lu.", (unsigned long)[[mediaItemCollection items] count] );
        @throw([NSException exceptionWithName:@"MP Failure" reason:@"Wrong number of items returned from media picker." userInfo:nil]);
    }
    MPMediaItem *mi = [[mediaItemCollection items] objectAtIndex:0];
    
    //__weak ViewController *s = self;
    
    self.overlayView.hidden = NO;
    self.progressView.progress = 0;
    
    _converter = [[AudioConverter alloc] initWithMediaItem:mi];
    _converter.delegate = self;
    NSError *error;
    if( [_converter setup:&error] ) {
        [_converter run];
    } else {
        self.overlayView.hidden = YES;
        UIAlertView *message = [[UIAlertView alloc] initWithTitle:@"Oops."
                                                          message:@"I couldn't read that file. :("
                                                         delegate:nil
                                                cancelButtonTitle:@"OK"
                                                otherButtonTitles:nil];
        
        [message show];
        return;
    }
}
- (void)mediaPickerDidCancel:(MPMediaPickerController *)mediaPicker;
{
    NSLog( @"Canceled Media Picking." );
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark AudioConverterDelegate

-(void) setConversionProgress:(float)p;
{
    self.progressView.progress = p;
}
-(void) conversionComplete;
{
    self.overlayView.hidden = YES;
}

@end
