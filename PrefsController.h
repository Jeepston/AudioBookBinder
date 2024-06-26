

@import Cocoa;

@interface PrefsController : NSWindowController

@property NSArray<NSNumber *> *validBitrates;

- (void) folderSheetShow: (id) sender;

@end
