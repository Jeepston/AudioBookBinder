
import Foundation
import CoreAudioTypes

@objc
protocol AudioBinderDelegate {
    
    @objc(updateStatus:handled:total:)
    func updateStatus(file: AudioFile, handled: UInt64, total: UInt64) -> Void

    @objc(conversionStart:format:formatDescription:length:)
    func conversionStart(file: AudioFile, format: UnsafeMutablePointer<AudioStreamBasicDescription>, formatDescription: String, length: UInt64)
    
    @objc(continueFailedConversion:reason:)
    func continueFailedConversion(file: AudioFile, reason: String) -> Bool

    @objc(conversionFinished:duration:)
    func conversionFinished(file: AudioFile, duration: UInt32) -> Void
    
    @objc(audiobookReady:)
    func audiobookReady(_ seconds: UInt32) -> Void
    
    @objc(volumeFailed:reason:)
    func volumeFailed(filename: String, reason: String) -> Void
    
    @objc(volumeReady:duration:)
    func volumeReady(volumeName: String, duration: UInt32) -> Void
}

