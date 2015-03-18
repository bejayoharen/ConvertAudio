//
//  AudioConverter.h
//  Convert Audio
//
//  Created by Bjorn Roche on 3/17/15.
//  Copyright (c) 2015 Bjorn Roche. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MPMediaItem;

@protocol AudioConverterDelegate
@required

-(void) setConversionProgress:(float)p;
-(void) conversionComplete;

@end

@interface AudioConverter : NSObject

@property (atomic) int64_t convertedByteCount;
@property (strong,nonatomic) NSURL *outputUrl;
@property (weak,nonatomic) id<AudioConverterDelegate> delegate;


-(AudioConverter *) initWithMediaItem:(MPMediaItem *) mediaItem;

-(BOOL) setup: (NSError **) error;

// Call this only if setup returns YES/TRUE
-(void) run;

@end
