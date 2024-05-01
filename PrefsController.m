//
//  Copyright (c) 2010-2016 Oleksandr Tymoshenko <gonzo@bluezbox.com>
//  All rights reserved.
// 
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions
//  are met:
//  1. Redistributions of source code must retain the above copyright
//     notice unmodified, this list of conditions, and the following
//     disclaimer.
//  2. Redistributions in binary form must reproduce the above copyright
//     notice, this list of conditions and the following disclaimer in the
//     documentation and/or other materials provided with the distribution.
// 
//  THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
//  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
//  FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
//  OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
//  HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
//  LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
//  OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
//  SUCH DAMAGE.
//

#import "PrefsController.h"
#import "ConfigNames.h"

@import AudioToolbox;

#define DESTINATION_FOLDER 0
#define DESTINATION_ITUNES 2

#define KVO_CONTEXT_BITRATES_AFFECTED   @"BitratesChanged"

@interface PrefsController() {
    IBOutlet NSPopUpButton * _folderPopUp;
    // HACK ALERT: dublicate all the changes on "save as" panel too
    IBOutlet NSPopUpButton * _saveAsFolderPopUp;
    IBOutlet NSTextField *updateLabel;
    IBOutlet NSButton *updateButton;
}
@end

@implementation PrefsController

- (void) awakeFromNib
{
    [_folderPopUp selectItemAtIndex:0];
    
    [updateLabel setHidden:YES];
    [updateButton setHidden:YES];

    [self updateValidBitrates];
    
    [[NSUserDefaults standardUserDefaults] addObserver:self
                                            forKeyPath:kConfigChannels
                                               options:0
                                               context:KVO_CONTEXT_BITRATES_AFFECTED];
    
    [[NSUserDefaults standardUserDefaults] addObserver:self
                                            forKeyPath:kConfigSampleRate
                                               options:0
                                               context:KVO_CONTEXT_BITRATES_AFFECTED];
}    

- (void) folderSheetShow: (id) sender
{
    NSOpenPanel * panel = [NSOpenPanel openPanel];
    
    [panel setPrompt: NSLocalizedString(@"Select", "Preferences -> Open panel prompt")];
    [panel setAllowsMultipleSelection: NO];
    [panel setCanChooseFiles: NO];
    [panel setCanChooseDirectories: YES];
    [panel setCanCreateDirectories: YES];
    
    [panel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result) {
        if (result == NSModalResponseOK) {
            NSURL *folderURL = [panel URL];
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
#ifdef APP_STORE_BUILD
            NSData* data = [folderURL bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope
                               includingResourceValuesForKeys:nil
                                                relativeToURL:nil
                                                        error:nil];
            [defaults setObject:data forKey:kConfigDestinationFolderBookmark];
            // Menu item is bound to DestinationFolder key so let AppStore
            // build set it as well
#endif
            NSString * folder = [folderURL path];
            [defaults setObject:folder forKey:kConfigDestinationFolder];
        }
        [self->_folderPopUp selectItemAtIndex:DESTINATION_FOLDER];
        [self->_saveAsFolderPopUp selectItemAtIndex:DESTINATION_FOLDER];
    }];
}


- (void) updateValidBitrates
{
    // setup channels/samplerate
    UInt32 channels = (UInt32)[[NSUserDefaults standardUserDefaults] integerForKey:kConfigChannels];
    float sampleRate = [[NSUserDefaults standardUserDefaults] floatForKey:kConfigSampleRate];
    self.validBitrates = [[NSArray alloc] initWithArray:[self allValidBitratesForSampleRate: sampleRate channels: channels] copyItems:YES];
    [self fixupBitrate];
}

-(NSArray*) allValidBitratesForSampleRate: (float) sampleRate channels: (UInt32) channels
{
    OSStatus status;
    ExtAudioFileRef tmpAudioFile;
    AudioConverterRef outConverter;
    NSMutableArray *validBitrates = [[NSMutableArray alloc] init];
    UInt32 size;
    
    AudioStreamBasicDescription outputFormat, pcmFormat;
    
    // open out file
    NSString *dir = NSTemporaryDirectory();
    NSString *file = [dir stringByAppendingFormat:@"/%@",
                      [[NSProcessInfo processInfo] globallyUniqueString]];

    
    memset(&outputFormat, 0, sizeof(AudioStreamBasicDescription));
    outputFormat.mSampleRate = sampleRate;
    outputFormat.mFormatID = kAudioFormatMPEG4AAC;
    outputFormat.mChannelsPerFrame = channels;
    
    id url = [NSURL fileURLWithPath:file];
    status = ExtAudioFileCreateWithURL((__bridge CFURLRef)url,
                                   kAudioFileMPEG4Type, &outputFormat,
                                   NULL, kAudioFileFlags_EraseFile, &tmpAudioFile);
    
    if (status != noErr)
        return validBitrates;
    
    // Setup input format descriptor, preserve mSampleRate
    bzero(&pcmFormat, sizeof(pcmFormat));
    pcmFormat.mSampleRate = sampleRate;
    pcmFormat.mFormatID = kAudioFormatLinearPCM;
    pcmFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger
                                | kAudioFormatFlagIsBigEndian
                                | kAudioFormatFlagIsPacked;
    
    pcmFormat.mBitsPerChannel = 16;
    pcmFormat.mChannelsPerFrame = channels;
    pcmFormat.mFramesPerPacket = 1;
    pcmFormat.mBytesPerPacket =
    (pcmFormat.mBitsPerChannel / 8) * pcmFormat.mChannelsPerFrame;
    pcmFormat.mBytesPerFrame =
    pcmFormat.mBytesPerPacket * pcmFormat.mFramesPerPacket;
    
    status = ExtAudioFileSetProperty(tmpAudioFile,
                                     kExtAudioFileProperty_ClientDataFormat,
                                     sizeof(pcmFormat), &pcmFormat);

    if(status != noErr) {
        ExtAudioFileDispose(tmpAudioFile);
        [[NSFileManager defaultManager] removeItemAtPath:file error:nil];
        return validBitrates;
    }
    
    // Get the underlying AudioConverterRef
    size = sizeof(AudioConverterRef);
    status = ExtAudioFileGetProperty(tmpAudioFile,
                                     kExtAudioFileProperty_AudioConverter,
                                     &size, &outConverter);
    
    if(status != noErr) {
        ExtAudioFileDispose(tmpAudioFile);
        [[NSFileManager defaultManager] removeItemAtPath:file error:nil];
        return validBitrates;
    }
    
    size = 0;
    // Get the available bitrates (CBR)
    status = AudioConverterGetPropertyInfo(outConverter,
                                           kAudioConverterApplicableEncodeBitRates,
                                           &size, NULL);
    if(noErr != status) {
        ExtAudioFileDispose(tmpAudioFile);
        [[NSFileManager defaultManager] removeItemAtPath:file error:nil];
        return validBitrates;
    }

    AudioValueRange *bitrates = malloc(size);
    NSCAssert(NULL != bitrates,
              NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
    
    status = AudioConverterGetProperty(outConverter,
                                       kAudioConverterApplicableEncodeBitRates,
                                       &size, bitrates);

    if(noErr == status) {
        int bitrateCount = size / sizeof(AudioValueRange);

        for(int n = 0; n < bitrateCount; ++n) {
            unsigned long minRate = (unsigned long) bitrates[n].mMinimum;
            if(0 != minRate) {
                [validBitrates addObject:[NSNumber numberWithUnsignedLong: minRate]];
            }
        }
    }
    
    free(bitrates);
    
    ExtAudioFileDispose(tmpAudioFile);
    [[NSFileManager defaultManager] removeItemAtPath:file error:nil];

    return validBitrates;
}

- (void) fixupBitrate
{
    NSInteger bitrate = [[NSUserDefaults standardUserDefaults] integerForKey:kConfigBitrate];
    NSInteger newBitrate;
    NSInteger distance = bitrate;
    
    for (NSNumber *n in self.validBitrates) {
        if (labs([n integerValue] - bitrate) < distance) {
            distance = labs([n integerValue] - bitrate);
            newBitrate = [n integerValue];
        }
    }
    
    if (newBitrate != bitrate) {
        [[NSUserDefaults standardUserDefaults] setInteger:newBitrate forKey:kConfigBitrate];
    }
}

//whenever an observed key path changes, this method will be called
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context;
{
    if (context == KVO_CONTEXT_BITRATES_AFFECTED) {
        [self updateValidBitrates];
    }
}

@end

@interface VolumeLengthTransformer : NSValueTransformer
@end

@implementation VolumeLengthTransformer

+ (Class)transformedValueClass {
    return [NSString class];
}

+ (BOOL)allowsReverseTransformation {
    return NO;
}

- (id)transformedValue:(id)value {
	if (value != nil)
	{
        NSInteger len = [value intValue];
        if (len == 25)
            return @"--";
        else
            return [NSString stringWithFormat:@"%ld", (long)len];
	}
	
    return @"";
}

@end
