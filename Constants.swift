

import Foundation
import ApplicationServices


enum Constants {
    enum UserDefaults {
        static let kConfigDestinationFolderBookmark    = "DestinationFolderBookmark"
        static let kConfigDestinationFolder            = "DestinationFolder"
        static let kConfigChannels                     = "Channels"
        static let kConfigSampleRate                   = "SampleRate"
        static let kConfigBitrate                      = "Bitrate"
        static let kConfigAddToITunes                  = "AddToiTunes"
        static let kConfigMaxVolumeSize                = "MaxVolumeSize"
        static let kConfigSortAudioFiles               = "SortAudioFiles"
        static let kConfigChaptersEnabled              = "ChaptersEnabled"
    }
    
    enum Localization {
        static let TEXT_CHAPTER = NSLocalizedString("Chapter", comment: "")
        static let TEXT_CHAPTER_N = NSLocalizedString("Chapter %d", comment: "")
    }
    
    enum ColumnId {
        static let name = "name"
        static let file = "file"
        static let author = "artist"
        static let album = "album"
        static let time = "duration"
    }
    
    enum PasteBoardType {
        static let SimplePasteBoardType: NSPasteboard.PasteboardType = .init(rawValue: "MyCustomOutlineViewPboardType")
        static let TextUrlPromise: NSPasteboard.PasteboardType = .init(rawValue: kPasteboardTypeFileURLPromise)
        
        
    }
}


@objc
final class LegacyConstants: NSObject {
    private override init() {}
    
    // UserDefaults
    @objc class func kConfigDestinationFolderBookmark() -> String { Constants.UserDefaults.kConfigDestinationFolderBookmark }
    @objc class func kConfigDestinationFolder() -> String { Constants.UserDefaults.kConfigDestinationFolder }
    @objc class func kConfigChannels() -> String { Constants.UserDefaults.kConfigChannels }
    @objc class func kConfigSampleRate() -> String { Constants.UserDefaults.kConfigSampleRate }
    @objc class func kConfigBitrate() -> String { Constants.UserDefaults.kConfigBitrate }
    @objc class func kConfigAddToITunes() -> String { Constants.UserDefaults.kConfigAddToITunes }
    @objc class func kConfigMaxVolumeSize() -> String { Constants.UserDefaults.kConfigMaxVolumeSize }
    @objc class func kConfigSortAudioFiles() -> String { Constants.UserDefaults.kConfigSortAudioFiles }
    @objc class func kConfigChaptersEnabled() -> String { Constants.UserDefaults.kConfigChaptersEnabled }
}

@objc
final class ColumnIdConstants: NSObject {
    private override init() {}
    
    @objc class func name() -> String { Constants.ColumnId.name }
    @objc class func file() -> String { Constants.ColumnId.file }
    @objc class func author() -> String { Constants.ColumnId.author }
    @objc class func album() -> String { Constants.ColumnId.album }
    @objc class func time() -> String { Constants.ColumnId.time }
}
