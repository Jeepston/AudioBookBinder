import Foundation


@objc
final class AudioBookVolume: NSObject {
    @objc let filename: String
    @objc let inputFiles: [AudioFile]
    
    @objc
    init(filename: String, inputFiles: [AudioFile]) {
        self.filename = filename
        self.inputFiles = inputFiles
    }
}
