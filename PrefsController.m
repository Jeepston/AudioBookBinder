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
#import "AudioBookBinder-Swift.h"

@import AudioToolbox;

#define DESTINATION_FOLDER 0
#define DESTINATION_ITUNES 2

#define KVO_CONTEXT_BITRATES_AFFECTED   @"BitratesChanged"

@interface PrefsController() {
    IBOutlet NSPopUpButton * _folderPopUp;
}
@end

@implementation PrefsController

- (void) awakeFromNib
{
    [_folderPopUp selectItemAtIndex:0];

    [self updateValidBitrates];
    
    [[NSUserDefaults standardUserDefaults] addObserver:self
                                            forKeyPath: LegacyConstants.kConfigChannels
                                               options:0
                                               context:KVO_CONTEXT_BITRATES_AFFECTED];
    
    [[NSUserDefaults standardUserDefaults] addObserver:self
                                            forKeyPath:LegacyConstants.kConfigSampleRate
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
            [defaults setObject:folder forKey:LegacyConstants.kConfigDestinationFolder];
        }
        [self->_folderPopUp selectItemAtIndex:DESTINATION_FOLDER];
    }];
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
