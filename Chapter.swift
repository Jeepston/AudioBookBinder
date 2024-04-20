//

import Foundation

@objc
final class Chapter: NSObject {
    @objc var name = ""
    @objc var files = [AudioFile]()
    
    @objc
    func copyChapter() -> Chapter {
        let c = Chapter()
        c.name = name
        c.files.append(contentsOf: files)
        return c
    }

    @objc (addFile:)
    func addFile(file: AudioFile) {
        files.append(file)
    }

    @objc
    func addFiles(newFiles: [AudioFile]) {
        files.append(contentsOf: newFiles)
    }

    @objc (containsFile:)
    func containsFile(file: AudioFile) -> Bool {
        files.contains(file)
    }

    @objc (indexOfFile:)
    func indexOfFile(file: AudioFile) -> Int {
        files.firstIndex(of: file) ?? 0
    }

    @objc
    func totalFiles() -> Int {
        files.count
    }

    @objc (fileAtIndex:)
    func fileAtIndex(index: Int) -> AudioFile? {
        files[index]
    }

    @objc (removeFile:)
    func removeFile(file: AudioFile) {
        if let index = files.firstIndex(of: file) {
          files.remove(at: index)
        }
    }

    @objc (insertFile:atIndex:)
    func insertFile(file: AudioFile, atIndex: Int) {
        files.insert(file, at: atIndex)
    }

    @objc
    func totalDuration() -> Int {
        let r = files.reduce(into: 0) {
            $0 += $1.duration
        }
        return r
    }

    // splits chapter into two. All files prior to given file
    // remain in this chapter, the rest goes to newly-created
    // chapter
    @objc (splitAtFile:)
    func splitAtFile(file: AudioFile) -> Chapter? {

        guard let idx = files.firstIndex(of: file) else {
            return nil
        }
        let c = Chapter()
        c.name = name
        while (idx < files.count) {
            let f = files[idx]
            c.addFile(file: f)
            files.remove(at: idx)
        }
        
        return c
    }

    @objc (sortUsingDecriptor:)
    func sortUsingDecriptor(descriptor: NSSortDescriptor) {
        files = (files as NSArray).sortedArray(using: [descriptor]) as! [AudioFile]
    }
}
