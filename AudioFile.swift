

import AudioToolbox
import Foundation

@objc
final class AudioFile: NSObject {
    @objc let filePath: URL
    @objc let file: String
    @objc var duration: Int
    @objc var valid: Bool
    @objc private(set) var artist: String
    @objc private(set) var name: String
    @objc private(set) var album: String
    
    @objc
    init(withPath path: String) {
        self.filePath = URL(filePath: path)
        self.file = self.filePath.lastPathComponent
        self.duration = -1
        self.valid = false
        self.artist = ""
        self.name = ""
        self.album = ""
        super.init()
        updateInfo()
    }
    
    private func updateInfo() {
        var audioFile: AudioFileID?
        var status = AudioFileOpenURL(filePath as CFURL, .readPermission, 0, &audioFile)
        guard let audioFile, status == noErr else {
            return
        }
        
        var dataFormatSize: UInt32 = UInt32(MemoryLayout<TimeInterval>.size)
        
        
        var duration: TimeInterval = -1
        status = AudioFileGetProperty(audioFile, kAudioFilePropertyEstimatedDuration, &dataFormatSize, &duration)
        if status == noErr, duration >= 0 {
            self.duration = Int(duration) * 1000
        }
        
        var size: UInt32 = 0
        status = AudioFileGetPropertyInfo(audioFile, kAudioFilePropertyInfoDictionary, &size, nil)
        
        if status == noErr {
            var audioFileInfoCFDict: Unmanaged<CFDictionary>? = nil
            status = AudioFileGetProperty(audioFile, kAudioFilePropertyInfoDictionary, &size, &audioFileInfoCFDict)
            let properties: NSDictionary? = audioFileInfoCFDict?.takeRetainedValue()
            if status == noErr, let properties {
                if let artist = properties["artist"] as? String {
                    self.artist = artist
                } else {
                    self.artist = ""
                }
                
                if let title = properties["title"] as? String {
                    self.name = title
                } else {
                    self.name = ""
                }
                
                if let album = properties["album"] as? String {
                    self.album = album
                } else {
                    self.album = ""
                }
            }
        }
        self.valid = true
        AudioFileClose(audioFile)
    }
}
