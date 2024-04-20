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
