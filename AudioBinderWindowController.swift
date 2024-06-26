

import Cocoa
import CoreAudioTypes

// TODO: remove unused arguments

extension AudioBinderWindowController: AudioBinderDelegate {
    func updateStatus(file: AudioFile, handled: UInt64, total: UInt64) {
        
        updateProgress(Double(handled), total: Double(total))
        
        if total > 0 {
            currentFileProgress = UInt(UInt64(file.duration) * handled / total)
            recalculateProgress()
        }
    }
    
    func conversionStart(file: AudioFile, format: UnsafeMutablePointer<AudioStreamBasicDescription>, formatDescription: String, length: UInt64) {
        updateProgressString(String(format: NSLocalizedString("Converting %@", comment: ""), file.filePath.path().removingPercentEncoding ?? ""))
        updateProgress(0, total: Double(length))
    }
    
    func continueFailedConversion(file: AudioFile, reason: String) -> Bool {
        let alert = NSAlert()
        alert.addButton(withTitle: "OK")
        alert.messageText = NSLocalizedString("Audiofile conversion failed", comment: "")
        alert.informativeText = reason
        alert.alertStyle = .warning
        DispatchQueue.main.async {
            alert.runModal()
        }
        return false
    }
    
    func conversionFinished(file: AudioFile, duration: UInt32) {
        DispatchQueue.main.async {[weak self] in
            self?.updateProgress(1, total: 1)
        }
        file.valid = true
        file.duration = Int(duration)
        if totalBookDuration > 0 {
            totalBookProgress += UInt(file.duration)
            currentFileProgress = 0
            recalculateProgress()
        }
    }
    
    func audiobookReady(_ seconds: UInt32) {
        // empty
    }
    
    func volumeFailed(filename: String, reason: String) {
        let alert = NSAlert()
        alert.addButton(withTitle: "OK")
        alert.messageText = NSLocalizedString("Audiobook binding failed", comment: "")
        alert.informativeText = reason
        alert.alertStyle = .warning
        DispatchQueue.main.async {
            alert.runModal()
        }
    }
    
    func volumeReady(volumeName: String, duration: UInt32) {
        // empty
    }
}
