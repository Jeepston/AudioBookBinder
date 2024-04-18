//
//  Copyright (c) 2009-2016 Oleksandr Tymoshenko <gonzo@bluezbox.com>
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

#import "ConsoleDelegate.h"
#import "ABBLog.h"

@interface ConsoleDelegate() {
    BOOL _verbose;
    BOOL _istty;
    BOOL _quiet;
    BOOL _skipErrors;
}

@end

@implementation ConsoleDelegate

-(instancetype) init
{
    [super init];

    _verbose = NO;
    _quiet = NO;
    _istty = isatty(fileno(stdout));
    _skipErrors = NO;
    return self;
}

-(void) setVerbose: (BOOL)verbose
{
    _verbose = verbose;
}


-(void) setQuiet: (BOOL)quiet
{
    _quiet = quiet;
}

-(void) setSkipErrors: (BOOL)skip
{
    _skipErrors = skip;
}

-(void)updateStatus: (AudioFile *)file handled:(UInt64)handledFrames total:(UInt64)totalFrames
{
    if (!_quiet && _istty) {
        UInt64 percent = handledFrames * 100 / totalFrames;
        // got to the beginning of the line
        printf("\r");
        printf("%s: [%3d%%] %lld/%lld", 
               [file.filePath cStringUsingEncoding:NSUTF8StringEncoding], percent,
               handledFrames, totalFrames);
        fflush(stdout);
    }
}

-(void) conversionStart: (AudioFile*)file 
                 format: (AudioStreamBasicDescription*)asbd
      formatDescription: (NSString*)description
                 length: (UInt64)frames;
{
    if (!_quiet) {
        if (_verbose)
        {
            printf("Stream info for %s:\n",
               [file.filePath cStringUsingEncoding:NSUTF8StringEncoding]);
            printf("\tFormatID: %s, FormatFlags: %08x\n", (char*)&asbd->mFormatID, asbd->mFormatFlags);
            printf("\tBytesPerPacket: %d, FramesPerPacker: %d, BytesPerFrame: %d\n",
                  asbd->mBytesPerPacket, asbd->mFramesPerPacket, asbd->mBytesPerFrame);
            printf("\tChannerlsPerFrame: %d, BitsPerChannel: %d\n", asbd->mChannelsPerFrame, asbd->mBitsPerChannel);
            
            printf("\tFormat description: %s\n", 
                  [description cStringUsingEncoding:NSUTF8StringEncoding]);
            printf("\tTotal frames: %lld\n", frames);

        }

        printf("%s: ", [file.filePath cStringUsingEncoding:NSUTF8StringEncoding]);
        fflush(stdout);
    }
}

-(BOOL)continueFailedConversion:(AudioFile*)file reason:(NSString*)reason
{
    if (!_quiet) {
        printf("failed, %s", [reason cStringUsingEncoding:NSUTF8StringEncoding]);
        if (_skipErrors)
            printf(", skipping...");
        printf("\n");
    }
    file.duration = [[NSNumber alloc] initWithInt:0];
    file.valid = NO;
    return _skipErrors;
}

-(void) conversionFinished: (AudioFile*)file duration:(UInt32)duration
{
    if (!_quiet) {
        if (_istty) {
            // got to the beginning of the line
            printf("\r");
            printf("%s: [100%%]                              \n",
                   [file.filePath cStringUsingEncoding:NSUTF8StringEncoding]);
        }
        else {
            printf("done\n");
        }
    }
    
    // set actual duration and mark as valid
    file.duration = [[NSNumber alloc] initWithInt:duration];
    file.valid = YES;    
}

-(void) volumeReady: (NSString*)filename duration: (UInt32)seconds
{
    unsigned int h = seconds / 3600;
    unsigned int m = (seconds % 3600) / 60;
    unsigned int s = (seconds % 60);
    if (!_quiet) {
        printf("Finished: %s (", 
               [filename cStringUsingEncoding:NSUTF8StringEncoding]);
        if (h)
            printf("%dh ", h);

        printf("%dm %ds)\n", m, s);
    }
}

-(void) audiobookReady:(UInt32)seconds
{
    unsigned int h = seconds / 3600;
    unsigned int m = (seconds % 3600) / 60;
    unsigned int s = (seconds % 60);
    if (!_quiet) {
        printf("Total: "); 

        if (h)
            printf("%dh ", h);
        
        printf("%dm %ds\n", m, s);
    }
}

-(void) volumeFailed: (NSString*)filename reason: (NSString*)reason
{
}

@end
