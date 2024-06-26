

import Cocoa
import AudioToolbox


extension PrefsController {
    
    @objc
    func updateValidBitrates() {
        // setup channels/samplerate
        let channels = UserDefaults.standard.integer(forKey: Constants.UserDefaults.kConfigChannels)
        let sampleRate = UserDefaults.standard.double(forKey: Constants.UserDefaults.kConfigSampleRate)
        
        validBitrates = allValidBitrates(for: sampleRate, channels: channels)
        fixupBitrate()
    }
    
    
    @objc
    func fixupBitrate() {
        let bitrate = UserDefaults.standard.integer(forKey: Constants.UserDefaults.kConfigBitrate)
        
        var newBitrate = 0
        var distance = bitrate
        
        for n in validBitrates {
            if labs(n.intValue - bitrate) < distance {
                distance = labs(n.intValue - bitrate)
                newBitrate = n.intValue
            }
        }
        
        if newBitrate != bitrate {
            UserDefaults.standard.setValue(newBitrate, forKey: Constants.UserDefaults.kConfigBitrate)
        }
    }
    
    
    func allValidBitrates(for sampleRate: Double, channels: Int) -> [NSNumber] {
        
        var tmpAudioFile: ExtAudioFileRef? = nil
        var outConverter: AudioConverterRef? = nil
        var validBitrates = [NSNumber]()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        
        
        // open out file
        let file = NSTemporaryDirectory() + "/\(ProcessInfo.processInfo.globallyUniqueString)"
        
        
        var outputFormat = AudioStreamBasicDescription()
        outputFormat.mSampleRate = sampleRate
        outputFormat.mFormatID = kAudioFormatMPEG4AAC;
        outputFormat.mChannelsPerFrame = UInt32(channels)
        
        let url = NSURL(fileURLWithPath: file)
        
        var status = ExtAudioFileCreateWithURL(
            url as CFURL,
            kAudioFileMPEG4Type,
            &outputFormat,
            nil,
            AudioFileFlags.eraseFile.rawValue,
            &tmpAudioFile
        )
        guard status == noErr, let tmpAudioFile else {
            return validBitrates
        }
        
        // Setup input format descriptor, preserve mSampleRate
        var pcmFormat = AudioStreamBasicDescription()
        pcmFormat.mSampleRate = sampleRate
        pcmFormat.mFormatID = kAudioFormatLinearPCM
        pcmFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger
        | kAudioFormatFlagIsBigEndian
        | kAudioFormatFlagIsPacked
        
        pcmFormat.mBitsPerChannel = 16
        pcmFormat.mChannelsPerFrame = UInt32(channels)
        pcmFormat.mFramesPerPacket = 1
        pcmFormat.mBytesPerPacket = (pcmFormat.mBitsPerChannel / 8) * pcmFormat.mChannelsPerFrame
        pcmFormat.mBytesPerFrame = pcmFormat.mBytesPerPacket * pcmFormat.mFramesPerPacket
        
        status = ExtAudioFileSetProperty(
            tmpAudioFile,
            kExtAudioFileProperty_ClientDataFormat,
            size,
            &pcmFormat
        )
        
        guard status == noErr else {
            ExtAudioFileDispose(tmpAudioFile)
            try? FileManager.default.removeItem(atPath: file)
            return validBitrates
        }
        
        // Get the underlying AudioConverterRef
        size = UInt32(MemoryLayout<AudioConverterRef>.size)
        status = ExtAudioFileGetProperty(
            tmpAudioFile,
            kExtAudioFileProperty_AudioConverter,
            &size,
            &outConverter
        )
        
        guard status == noErr, let outConverter else {
            ExtAudioFileDispose(tmpAudioFile)
            try? FileManager.default.removeItem(atPath: file)
            return validBitrates
        }
        
        size = 0
        
        // Get the available bitrates (CBR)
        status = AudioConverterGetPropertyInfo(
            outConverter,
            kAudioConverterApplicableEncodeBitRates,
            &size,
            nil
        )
        
        guard status == noErr else {
            ExtAudioFileDispose(tmpAudioFile)
            try? FileManager.default.removeItem(atPath: file)
            return validBitrates
        }
        
        let bitratesPointer = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioValueRange>.alignment)
        let elementSize = UInt32(MemoryLayout<AudioValueRange>.size)
        let count = size / elementSize
        bitratesPointer.initializeMemory(as: AudioValueRange.self, repeating: AudioValueRange(), count: Int(count))
        
        status = AudioConverterGetProperty(
            outConverter,
            kAudioConverterApplicableEncodeBitRates,
            &size,
            bitratesPointer
        )
        
        let float4Ptr = bitratesPointer.bindMemory(to: AudioValueRange.self, capacity: Int(count))
        let float4Buffer = UnsafeBufferPointer(start: float4Ptr, count: Int(count))
        let bitrates = Array(float4Buffer)
        
        if status == noErr {
            validBitrates = bitrates.compactMap {
                $0.mMinimum == 0 ? nil : NSNumber(value: $0.mMinimum)
            }
        }
        
        bitratesPointer.deallocate()
        ExtAudioFileDispose(tmpAudioFile)
        try? FileManager.default.removeItem(atPath: file)
        
        return validBitrates
    }
}
