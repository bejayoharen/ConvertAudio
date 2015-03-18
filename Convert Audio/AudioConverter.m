//
//  AudioConverter.m
//  Convert Audio
//
//  Created by Bjorn Roche on 3/17/15.
//  Copyright (c) 2015 Bjorn Roche. All rights reserved.
//

#import "AudioConverter.h"
#import <AVFoundation/AVAudioSettings.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>

#define OUT_AUDIO_FILENAME (@"converted.wav")

@interface AudioConverter ()

@property (atomic)              MPMediaItem         *mediaItem;
@property (atomic)              AVAssetWriter       *assetWriter;
@property (atomic)              AVAssetReader       *assetReader;
@property (atomic)              AVURLAsset          *songAsset;
@property (atomic)              AVAssetWriterInput  *assetWriterInput;
@property (atomic)              AVAssetReaderOutput *assetReaderOutput;
@property (atomic)              UInt64              totalByteCount;
@property (atomic)              double              expectedDurationInSec;
@property (atomic)              BOOL                running;

@property (strong, nonatomic, readwrite) NSString    *songTitle;
@property (strong, nonatomic, readwrite) NSString    *songArtist;
@property (strong, nonatomic, readwrite) UIImage     *songImage;

@end

NSError *CreateError( int code, NSString *description, NSString *failureReason, NSString *suggestion ) {
    NSDictionary *userInfo = @{
                               NSLocalizedDescriptionKey: NSLocalizedString(description, nil),
                               NSLocalizedFailureReasonErrorKey: NSLocalizedString(failureReason, nil),
                               NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(suggestion, nil)
                               };
    NSError *error = [NSError errorWithDomain:@"com.bjornroche.AudioConverter"
                                         code:code
                                     userInfo:userInfo];
    return error;
}


@implementation AudioConverter

+(NSURL *) outAudioUrl {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *path = [documentsDirectory stringByAppendingPathComponent:OUT_AUDIO_FILENAME];
    return [NSURL fileURLWithPath:path];
}

+(void) clean {
    NSString *tmp;
    tmp = [[AudioConverter outAudioUrl] path];
    if ([[NSFileManager defaultManager] fileExistsAtPath:tmp]) {
        [[NSFileManager defaultManager] removeItemAtPath:tmp error:nil];
    }
}

-(AudioConverter *) initWithMediaItem:(MPMediaItem *) mediaItem
{
    self = [super init];
    if( self ) {
        self.mediaItem = mediaItem;
        self.running = YES;
    }
    return self;
}

-(BOOL) setup: (NSError **) error
{
    //get the URL
    NSURL *assetURL = [self.mediaItem valueForProperty:MPMediaItemPropertyAssetURL];
    if (!assetURL) {
        NSString *reason = [NSString stringWithFormat:@"Could not get URL from asset %@", [self.mediaItem valueForProperty:MPMediaItemPropertyTitle]];
        *error = CreateError( 0, reason, nil, @"Try another song" );
        return NO;
    }
    self.songAsset = [AVURLAsset URLAssetWithURL:assetURL options:@{}];
    if (!self.songAsset) {
        NSString *reason = [NSString stringWithFormat:@"Could not build asset from URL %@", assetURL];
        *error = CreateError( 0, reason, nil, @"Try another song" );
        return NO;
    }
    
    //determine the length, and other properties
    self.expectedDurationInSec = [(NSNumber *)[self.mediaItem valueForProperty:MPMediaItemPropertyPlaybackDuration] doubleValue];
    self.songArtist = [self.mediaItem valueForProperty:MPMediaItemPropertyArtist];
    self.songTitle = [self.mediaItem valueForProperty:MPMediaItemPropertyTitle];
    CGSize size;
    size.width = 100;
    size.height = 100;
    self.songImage = [[self.mediaItem valueForProperty:MPMediaItemPropertyArtwork] imageWithSize:size];
    
    // asset reader
    self.assetReader = [AVAssetReader assetReaderWithAsset:self.songAsset error:error];
    if (!self.assetReader) {
        NSLog( @"Error building asset reader: %@", *error );
        return NO;
    }
    
    // conversion settings:
    AudioChannelLayout channelLayout;
    memset(&channelLayout, 0, sizeof(AudioChannelLayout));
    channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo;
    NSDictionary *outputSettings = [NSDictionary dictionaryWithObjectsAndKeys: [NSNumber numberWithInt:kAudioFormatLinearPCM], AVFormatIDKey,
                                    [NSNumber numberWithFloat:44100.0], AVSampleRateKey,
                                    [NSNumber numberWithInt:2], AVNumberOfChannelsKey,
                                    [NSData dataWithBytes:&channelLayout length:sizeof(AudioChannelLayout)],
                                    AVChannelLayoutKey,
                                    [NSNumber numberWithInt:16], AVLinearPCMBitDepthKey,
                                    [NSNumber numberWithBool:NO], AVLinearPCMIsNonInterleaved,
                                    [NSNumber numberWithBool:NO], AVLinearPCMIsFloatKey,
                                    [NSNumber numberWithBool:NO], AVLinearPCMIsBigEndianKey,
                                    nil];
    
    // asset reader output
    self.assetReaderOutput = [AVAssetReaderAudioMixOutput assetReaderAudioMixOutputWithAudioTracks:self.songAsset.tracks audioSettings: outputSettings];
    if (! [self.assetReader canAddOutput: self.assetReaderOutput]) {
        return NO;
    }
    [self.assetReader addOutput: self.assetReaderOutput];
    
    // create a tmp import file
    [AudioConverter clean];
    self.outputUrl = [AudioConverter outAudioUrl];
    
    // asset writer:
    self.assetWriter = [AVAssetWriter assetWriterWithURL:self.outputUrl fileType:AVFileTypeWAVE error:error];
    if (!self.assetWriter) {
        NSLog( @"Error building asset writer: %@", *error );
        return NO;
    }
    
    //AVAssetWriterInput
    self.assetWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:outputSettings];
    if ([self.assetWriter canAddInput:self.assetWriterInput]) {
        [self.assetWriter addInput:self.assetWriterInput];
    } else {
        *error = CreateError( 0, @"Could not add input to asset writer.", @"This is an internal error.", nil );
        return NO;
    }
    self.assetWriterInput.expectsMediaDataInRealTime = NO;
    
    return YES;
}

-(void) run
{
    [self.assetWriter startWriting];
    [self.assetReader startReading];
    AVAssetTrack *soundTrack = [self.songAsset.tracks objectAtIndex:0];
    CMTime startTime = CMTimeMake (0, soundTrack.naturalTimeScale);
    [self.assetWriter startSessionAtSourceTime: startTime];
    
    dispatch_queue_t mediaInputQueue = dispatch_queue_create("mediaInputQueue", NULL);
    AudioConverter __weak *s = self;
    [self.assetWriterInput requestMediaDataWhenReadyOnQueue:mediaInputQueue usingBlock: ^ { [s processBlock];  } ];
}

-(void) processBlock
{
    while (self.assetWriterInput.readyForMoreMediaData) {
        CMSampleBufferRef nextBuffer = [self.assetReaderOutput copyNextSampleBuffer];
        
        if (nextBuffer && [self running]) {
            // process raw audio
            CMBlockBufferRef sbuf = CMSampleBufferGetDataBuffer(nextBuffer);
            const size_t length = CMBlockBufferGetDataLength(sbuf);
            size_t start = 0;
            while( start < length ) {
                size_t lengthAtOffset;
                size_t totalLength;
                int16_t *data;
                OSStatus err = CMBlockBufferGetDataPointer(sbuf, start, &lengthAtOffset, &totalLength, (char **)&data);
                // checks:
                if( err != kCMBlockBufferNoErr ) {
                    NSLog( @"Error processing data." );
                    break;
                }
                if( totalLength != length ) {
                    NSLog( @"Buffer appears to change size!" );
                    break;
                }
                // here's how you could do some processing if you wanted:
                size_t numsamples = lengthAtOffset / 2;
                for( size_t i=0; i<numsamples; ) {
                    int16_t li = CFSwapInt16LittleToHost( data[i] );
                    ++i;
                    int16_t ri = CFSwapInt16LittleToHost( data[i] );
                    ++i;
                }
                
                //increment:
                start += lengthAtOffset;
            }
            
            // append buffer
            [self.assetWriterInput appendSampleBuffer: nextBuffer];
            // update ui
            self.convertedByteCount += CMSampleBufferGetTotalSampleSize (nextBuffer);
            NSNumber *convertedByteCountNumber = [NSNumber numberWithUnsignedLongLong:self.convertedByteCount];
            [self performSelectorOnMainThread:@selector(updateSize:)
                                   withObject:convertedByteCountNumber
                                waitUntilDone:NO];
        } else {
            // done!
            [self.assetWriterInput markAsFinished];
            AudioConverter __weak *s = self;
            [self.assetWriter finishWritingWithCompletionHandler:^{
                [s writingComplete];
            }];
            break;
        }
    }
}

-(void) writingComplete {
    [self.assetReader cancelReading];
    NSDictionary *outputFileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[self.outputUrl path] error:nil];
    
    NSLog (@"done. file size is %lld", [outputFileAttributes fileSize]);
    NSNumber *doneFileSize = [NSNumber numberWithLong:[outputFileAttributes fileSize]];
    [self performSelectorOnMainThread:@selector(updateCompletedSize:)
                           withObject:doneFileSize
                        waitUntilDone:NO];
    if( !self.running )
        [AudioConverter clean];
}

-(void) updateSize:(NSNumber *) converted
{
    UInt64 c = [converted unsignedLongLongValue];
    //convert from bytes to samples:
    c /= ( 2 * 2 );
    //convert from samples to sec:
    double s = c/44100. ;
    //calculate percentage:
    float p = s/self.expectedDurationInSec;
    [[self delegate] setConversionProgress:p];
}

-(void) updateCompletedSize:(NSNumber *) totalSize
{
    [[self delegate] conversionComplete];
}

-(void) cancel
{
    if( self.running == NO )
        [AudioConverter clean];
    else
        self.running = NO;
}

@end
