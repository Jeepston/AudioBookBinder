

import Foundation
import CoreServices
import AudioToolbox

@objc
final class AudioBinder: NSObject {
    
    // MARK: - Properties
    
    @objc var channels: UInt32 = 2
    @objc var sampleRate: Float = 44100
    @objc var bitrate: UInt32 = 0
    @objc var volumes = [AudioBookVolume]()
    @objc var delegate: AudioBinderDelegate?
    
    
    // ex-private
    private var outAudioFile: ExtAudioFileRef? = nil
    private var outFileLength: Int64 = 0
    private var outBookLength: Int64 = 0
    
    private var canceled = false
    private var bitrateSet = false
    
    // MARK: - Init
    
    // MARK: - Interface
    
    @objc(openOutFile:)
    func openOutFile(_ outFile: String) -> Bool {
        
        if FileManager.default.fileExists(atPath: outFile) {
            do {
                try FileManager.default.removeItem(atPath: outFile)
            } catch {
                debugPrint("Cannot remove file \(outFile): \(error.localizedDescription)")
                return false
            }
        }
        
        let url = NSURL(fileURLWithPath: outFile)
        
        var outputFormat = AudioStreamBasicDescription()
        outputFormat.mSampleRate = Float64(sampleRate)
        outputFormat.mFormatID = kAudioFormatMPEG4AAC
        outputFormat.mChannelsPerFrame = channels
       
        let status = ExtAudioFileCreateWithURL(
            url as CFURL,
            kAudioFileMPEG4Type,
            &outputFormat,
            nil,
            AudioFileFlags.eraseFile.rawValue,
            &outAudioFile
        )
        
        guard status == noErr, outAudioFile != nil else {
            debugPrint("Can't create output file \(outFile): \(osStatusStringDescription(status))")
            return false
        }
        
        // reset output file length
        outFileLength = 0

        return true
    }
    
    @objc(addVolume:files:)
    func addVolume(_ fileName: String, files: [AudioFile]) {
        let volume = AudioBookVolume(filename: fileName, inputFiles: files)
        volumes.append(volume)
    }
    
    private func setConverterBitrate() -> Bool {
        guard let outAudioFile else {
            return false
        }
        
        var size: UInt32 = UInt32(MemoryLayout<AudioConverterRef>.size)
        var outConverter: AudioConverterRef? = nil
        var status = ExtAudioFileGetProperty(outAudioFile,
                                         kExtAudioFileProperty_AudioConverter,
                                         &size, &outConverter);
        
        if status != noErr {
            return false
        }
        
        guard let outConverter else {
            return false
        }
        
        size = UInt32(MemoryLayout<UInt32>.size)
        status = AudioConverterSetProperty(outConverter, kAudioConverterEncodeBitRate,
                                           size, &bitrate);
        if status != noErr {
            return false
        }
        
        return true
        
    }
    
    @objc
    func convert() -> Bool {
        var failed = false
        var filesConverted = 0
        
        for volume in volumes {
            
            guard !volume.inputFiles.isEmpty else {
                debugPrint("No input files")
                delegate?.volumeFailed(filename: volume.filename, reason: "No input file")
                return false
            }
            
            guard openOutFile(volume.filename) else {
                debugPrint("Can't open output file")
                delegate?.volumeFailed(filename: volume.filename, reason: "Can't create output file")
                return false
            }
            
            for inFile in volume.inputFiles {
                do {
                    try convert(audioFile: inFile)
                    filesConverted += 1
                } catch AudioBookError.conversionError(let errorMessage)  {
                    // We failed
                    if delegate?.continueFailedConversion(file: inFile, reason: errorMessage) == false {
                        failed = false
                        break
                    }
                } catch {
                    continue
                }
                
                if canceled {
                    break
                }
            }
            
            outBookLength += outFileLength
            
            closeOutFile()
            
            if failed || canceled {
                break
            } else {
                delegate?.volumeReady(volumeName: volume.filename, duration: (UInt32)(Float(outFileLength) / sampleRate))
            }
        }
        
        if failed || canceled {
            for volume in volumes {
                try? FileManager.default.removeItem(atPath: volume.filename)
            }
        }
           
        var result = true
        // Did we fail? Were there any files successfully converted?
        if failed || filesConverted == 0 || canceled {
            result = false
        } else {
            delegate?.audiobookReady((UInt32)(Float(outBookLength)/sampleRate))
        }
        
        // Back to non-cacneled state
        canceled = false
        
        return result
    }
    
    private func convert(audioFile: AudioFile) throws {
        let audioBufferSize: UInt32 = 1 * 1024 * 1024
        var inAudioFile: ExtAudioFileRef?
        let audioBuffer = malloc(Int(audioBufferSize))
            
        do {

            var status = ExtAudioFileOpenURL(audioFile.filePath as CFURL, &inAudioFile)
            guard
                status == noErr,
                let inAudioFile
            else {
                throw AudioBookError.conversionError("ExtAudioFileOpenURL failed: \(osStatusStringDescription(status))")
            }
            
            // Query file type
            var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
            var format = AudioStreamBasicDescription()
            status = ExtAudioFileGetProperty(
                inAudioFile,
                kExtAudioFileProperty_FileDataFormat,
                &size,
                &format
            )
            
            guard
                status == noErr
            else {
                throw AudioBookError.conversionError("AudioFileGetProperty failed: \(osStatusStringDescription(status))")
            }
            
            var specSize = UInt32(MemoryLayout<NSString>.size)
            size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
            var fileFormat: CFString = String() as CFString
            status = AudioFormatGetProperty(
                kAudioFormatProperty_FormatName,
                size,
                &format,
                &specSize,
                &fileFormat
            )
            
            guard
                status == noErr
            else {
                throw AudioBookError.conversionError("AudioFormatGetProperty failed: \(osStatusStringDescription(status))")
            }

            size = UInt32(MemoryLayout<UInt64>.size)
            var framesTotal: UInt64 = 0
            status = ExtAudioFileGetProperty(
                inAudioFile,
                kExtAudioFileProperty_FileLengthFrames,
                &size,
                &framesTotal
            )
            
            guard status == noErr else {
                throw AudioBookError.conversionError("can't get input file length: \(osStatusStringDescription(status))")
            }
            
            delegate?.conversionStart(
                file: audioFile,
                format: &format,
                formatDescription: fileFormat as String,
                length: framesTotal
            )

            // framesTotal was calculated with respect to original format
            // in order to get proper progress dialog we need convert to to client
            // format
            framesTotal = (framesTotal * UInt64(sampleRate)) / UInt64(format.mSampleRate)

            // Setup input format descriptor, preserve mSampleRate
            var pcmFormat = AudioStreamBasicDescription()
            pcmFormat.mSampleRate = Float64(sampleRate)
            pcmFormat.mFormatID = kAudioFormatLinearPCM
            pcmFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger
                | kAudioFormatFlagIsBigEndian
                | kAudioFormatFlagIsPacked

            pcmFormat.mBitsPerChannel = 16
            pcmFormat.mChannelsPerFrame = channels
            pcmFormat.mFramesPerPacket = 1
            pcmFormat.mBytesPerPacket = (pcmFormat.mBitsPerChannel / 8) * pcmFormat.mChannelsPerFrame
            pcmFormat.mBytesPerFrame = pcmFormat.mBytesPerPacket * pcmFormat.mFramesPerPacket

            size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
            status = ExtAudioFileSetProperty(
                inAudioFile,
                kExtAudioFileProperty_ClientDataFormat,
                size,
                &pcmFormat
            )
            
            guard status == noErr else {
                throw AudioBookError.conversionError("ExtAudioFileSetProperty(ClientDataFormat) failed: \(osStatusStringDescription(status))")
            }

            // Get the underlying AudioConverterRef
            var conv: AudioConverterRef?
            size = UInt32(MemoryLayout<AudioConverterRef>.size)
            status = ExtAudioFileGetProperty(
                inAudioFile,
                kExtAudioFileProperty_AudioConverter,
                &size,
                &conv
            )
            
            guard
                status == noErr,
                let conv
            else {
                throw AudioBookError.conversionError("can't get AudioConverter: \(osStatusStringDescription(status))")
            }
            
            // Convert mono files to stereo by duplicating channel
            if format.mChannelsPerFrame == 1 && channels == 2 {
                let channelMap: [Int32] = [0, 0]
                size = 2 * UInt32(MemoryLayout<Int32>.size)
                    
                status = AudioConverterSetProperty(
                    conv,
                    kAudioConverterChannelMap,
                    size,
                    channelMap
                )
                
                guard status == noErr else {
                    throw AudioBookError.conversionError("Can't set ChannelMap: \(osStatusStringDescription(status))")
                }
            }

            guard let outAudioFile else {
                throw AudioBookError.conversionError("Can't set ClientDataFormat: \(osStatusStringDescription(status))")
            }
            
            size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
            status = ExtAudioFileSetProperty(
                outAudioFile,
                kExtAudioFileProperty_ClientDataFormat,
                size,
                &pcmFormat
            )
            
            guard status == noErr else {
                throw AudioBookError.conversionError("Can't set ClientDataFormat: \(osStatusStringDescription(status))")
            }
            
            if bitrate > 0 && !bitrateSet {
                if !setConverterBitrate() {
                    throw AudioBookError.conversionError("can't set output bit rate")
                }
                bitrateSet = true
            }
            
            
            let buffer = AudioBuffer(
                mNumberChannels: pcmFormat.mChannelsPerFrame,
                mDataByteSize: audioBufferSize,
                mData: audioBuffer
            )
            var bufferList = AudioBufferList(mNumberBuffers: 1, mBuffers: buffer)
            
            var framesConverted: UInt64 = 0
            var framesToRead: UInt32 = 0
            
            repeat {
                
                framesToRead = buffer.mDataByteSize / pcmFormat.mBytesPerFrame
                status = ExtAudioFileRead(inAudioFile, &framesToRead, &bufferList)
                
                guard status == noErr else {
                    throw AudioBookError.conversionError("ExtAudioFileRead failed: \(osStatusStringDescription(status))")
                }
                
                if framesToRead > 0 {
                    status = ExtAudioFileWrite(outAudioFile, framesToRead, &bufferList)
                    guard status == noErr else {
                        throw AudioBookError.conversionError("ExtAudioFileWrite failed: \(osStatusStringDescription(status))")
                    }
                }

                framesConverted += UInt64(framesToRead)

                delegate?.updateStatus(file: audioFile, handled: framesConverted, total: framesTotal)

                status = ExtAudioFileTell(outAudioFile, &outFileLength)
                guard status == noErr else {
                    throw AudioBookError.conversionError("ExtAudioFileTell failed: \(osStatusStringDescription(status))")
                }
                
                if canceled {
                    break
                }

            } while framesToRead > 0
                        
            let duration: UInt32 = UInt32(Float(framesConverted * 1000) / sampleRate)
            delegate?.conversionFinished(file: audioFile, duration: duration)
        } catch {
            if let inAudioFile {
                ExtAudioFileDispose(inAudioFile)
            }
            
            if let audioBuffer {
                free(audioBuffer)
            }
            
            throw error
        }
        
        // _needNextVolume = YES;
        
        if let inAudioFile {
            ExtAudioFileDispose(inAudioFile)
        }
        
        if let audioBuffer {
            free(audioBuffer)
        }

    }
    
    private func closeOutFile() {
        if let outAudioFile {
            ExtAudioFileDispose(outAudioFile)
        }
        outAudioFile = nil
    }
    
    @objc
    func cancel() {
        canceled = true
    }
    
    @objc
    func reset() {
        volumes.removeAll()
        outAudioFile = nil
        outFileLength = 0
        delegate = nil
        canceled = false
        sampleRate = 44100
        channels = 2
        bitrate = 0
        bitrateSet = false
    }
    
    
    // MARK: - Helpers
    // TODO: move to OSStatus extension
    private func osStatusStringDescription(_ err: OSStatus) -> String {
        var descString = ""
        var isOSType = true
        var osTypeRepr: Array<CChar> = Array(repeating: 32, count: 5)
        var errStr: String?
    
        
        // Check if err is OSType and convert it to 4 chars representation
        osTypeRepr[4] = 0
        for i in 0..<4 {
            let c: CUnsignedChar = CUnsignedChar((Int(err) >> 8*i) & 0xff)
            if (isprint(Int32(c)) != 0) {
                osTypeRepr[3-i] = CChar(c)
            } else {
                isOSType = false
                break
            }
        }
        
        switch err {
            case 0x7479703f:
                errStr = "Unsupported file type"
            case 0x666d743f:
                errStr = "Unsupported data format"
            case 0x7074793f:
                errStr = "Unsupported property"
            case 0x2173697a:
                errStr = "Bad property size"
            case 0x70726d3f:
                errStr = "Permission denied"
            case 0x6f70746d:
                errStr = "Not optimized"
            case 0x63686b3f:
                errStr = "Invalid chunk"
            case 0x6f66663f:
                errStr = "Does not allow 64bit data size"
            case 0x70636b3f:
                errStr = "Invalid packet offset"
            case 0x6474613f:
                errStr = "Invalid file"
            default:
                errStr = nil
        }

        let error = NSError(domain: NSOSStatusErrorDomain, code: Int(err), userInfo: nil)
        
        let isOSTypeDescription = if let errStr {
            errStr
        } else {
            osTypeRepr.compactMap { String($0) }.joined()
        }
        
        let errDescr: String = isOSType ? isOSTypeDescription : error.description
        
        if !errDescr.isEmpty {
            descString = "err#\(err) (\(errDescr))"
        } else {
            descString = "err#\(err)"
        }
        
        return descString
    }
}
