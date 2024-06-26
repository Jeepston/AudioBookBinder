

import Cocoa
import ApplicationServices


@objc
final class AudioFileList: NSObject {
    
    @objc var chapterMode = true
    @objc var canPlay = false
    @objc var commonAuthor: String?
    @objc var commonAlbum: String?
    
    @objc var hasFiles: Bool {
        !files.isEmpty
    }
    
    private var files = [AudioFile]()
    
    @objc
    func allFiles() -> [AudioFile] {
        var result = [AudioFile]()
        if chapterMode {
            for chapter in chapters {
                result.append(contentsOf: chapter.files)
            }
        } else {
            result = files
        }
        
        return result
    }
    
    @objc var chapters = [Chapter]()
    private var draggedNodes = [Any]()
    private var sortAscending = true
    private var sortKey: String?
    
    override init() {
        if UserDefaults.standard.object(forKey: Constants.UserDefaults.kConfigChaptersEnabled) != nil {
            self.chapterMode = UserDefaults.standard.bool(forKey: Constants.UserDefaults.kConfigChaptersEnabled)
        }
    }
    
    @objc(addFile:)
    func addFile(_ fileName: String) {
        
        let file = AudioFile(withPath: fileName)
        willChangeValue(for: \.hasFiles)

        if file.valid {
            files.append(file)
            if chapterMode {
                let chapter = Chapter()
                if file.name.isEmpty {
                    chapter.name = file.file
                } else {
                    chapter.name = file.name
                }
                chapters.append(chapter)
                chapter.addFile(file)
            }
        }
        
        didChangeValue(for: \.hasFiles)
    }
    
    @objc(addFilesInDirectory:)
    func addFilesInDirectory(_ dirName: String) {
        do {
            var files = try FileManager.default.contentsOfDirectory(atPath: dirName)
            
            // Should be OK for most cases
            if UserDefaults.standard.bool(forKey: Constants.UserDefaults.kConfigSortAudioFiles) {
                files.sort()
            }
            
            files.forEach {
                addFile((dirName as NSString).appendingPathComponent($0) as String)
            }
        } catch {
            debugPrint("Error getting contents of directory: \(error.localizedDescription)")
        }
    }
    
    @objc
    func switchChapterMode() {
        // this function is called before _chapterMode is changed by binding
        if !chapterMode {
            if hasFiles {
                // put all files in one folder
                let chapter = Chapter()
                chapter.name = Constants.Localization.TEXT_CHAPTER
                chapters.removeAll()
                files.forEach { chapter.addFile($0) }
                chapters.append(chapter)
            }
            
            // change explicitely because we need to update outlineView in new mode
            chapterMode = true

        } else {
            // flatten chapter tree
            files.removeAll()
        
            chapters.forEach { chapter in
                chapter.files.forEach { files.append($0) }
            }

            // change explicitely because we need to update outlineView in new mode
            chapterMode = false
        }
    }
    
    @objc
    func renumberChapters() {
        if chapterMode {
            var idx = 1
            for chapter in chapters {
                chapter.name = String(format: Constants.Localization.TEXT_CHAPTER_N, idx)
                idx += 1
            }
        }
    }
    
    @objc
    func cleanupChapters() {
        chapters = chapters.filter { $0.totalFiles() != 0 }
    }
    
    @objc(orphanFile:)
    func orphanFile(_ file: AudioFile) {
        for chapter in chapters {
            if chapter.containsFile(file: file) {
                chapter.removeFile(file: file)
            }
        }
    }
    
    @objc
    func tryGuessingAuthorAndAlbum() {
        if hasFiles {
            let file = files[0]
            var author: String? = file.artist
            var album: String? = file.album

            for file in files {
                if author != file.artist {
                    author = nil
                    break
                }
            }
            
            for file in files {
                if album != file.album {
                    album = nil
                    break
                }
            }
            
            commonAlbum = album
            commonAuthor = author
        } else {
            commonAlbum = nil
            commonAuthor = nil
        }
    }
    
    @objc(removeAllFiles:)
    func removeAllFiles(_ outlineView: NSOutlineView) {
        willChangeValue(for: \.hasFiles)
        files.removeAll()
        chapters.removeAll()
        
        outlineView.deselectAll(self)
        outlineView.reloadData()
        
        if chapterMode {
            outlineView.expandItem(nil)
        }
        
        didChangeValue(for: \.hasFiles)
    }
    
    @objc(deleteSelected:)
    func deleteSelected(_ outlineView: NSOutlineView) {
        // Go ahead and move things.
        willChangeValue(for: \.hasFiles)
        
        for item in outlineView.selectedItems() {
            if let chapter = item as? Chapter {
                chapter.files.forEach { file in
                    if let index = files.firstIndex(of: file) {
                        files.remove(at: index)
                    }
                }
                if let index = chapters.firstIndex(of: chapter) {
                    chapters.remove(at: index)
                }
            } else if let file = item as? AudioFile {
                // Remove the node from its old location
                if let oldIndex = files.firstIndex(of: file) {
                    files.remove(at: oldIndex)
                }
                
                for chapter in chapters {
                    if chapter.containsFile(file: file) {
                        chapter.removeFile(file: file)
                    }
                }
            }
        }
        
        cleanupChapters()
        didChangeValue(for: \.hasFiles)
        outlineView.deselectAll(self)
        outlineView.reloadData()
    }

    @objc(joinSelectedFiles:)
    func joinSelectedFiles(_ outlineView: NSOutlineView) {
        if !chapterMode {
            return
        }
        
        if outlineView.selectedItems().isEmpty {
            return
        }
        
        let newChapter = Chapter()
        var chapterIndex = 0
        

        let item = outlineView.selectedItems().first
        
        if let chapter = item as? Chapter {
            chapterIndex = chapters.firstIndex(of: chapter) ?? 0
            newChapter.name = chapter.name
        } else if let file = item as? AudioFile {
            
            if file.name.isEmpty {
                newChapter.name = file.file
            } else {
                newChapter.name = file.name
            }

            for chapter in chapters {
                if chapter.containsFile(file: file) {
                    chapterIndex = chapters.firstIndex(of: chapter) ?? 0
                    break
                }
            }
        }
        
        for item in outlineView.selectedItems() {
            if let chapter = item as? Chapter {
                // copy all files
                for f in chapter.files {
                    if !newChapter.containsFile(file: f) {
                        newChapter.addFile(f)
                    }
                }
                if let index = chapters.firstIndex(of: chapter) {
                    chapters.remove(at: index)
                }
            } else if let file = item as? AudioFile {
                if !newChapter.containsFile(file: file) {
                    orphanFile(file)
                    newChapter.addFile(file)
                }
            }
        }
        
        chapters.insert(newChapter, at: chapterIndex)
        cleanupChapters()
        outlineView.deselectAll(self)
        outlineView.reloadData()
        outlineView.setSelectedItem(newChapter)
        outlineView.expandItem(newChapter)
    }

    @objc(splitSelectedFiles:)
    func splitSelectedFiles(_ outlineView: NSOutlineView) {
        if !chapterMode {
            return
        }
        
        if outlineView.selectedItems().isEmpty {
            return
        }
        var newChapters = [Chapter]()
        
        for case let chapter as Chapter in outlineView.selectedItems() {
            var chapterIndex = chapters.firstIndex(of: chapter) ?? 0 + 1
            
            for file in chapter.files {
                let newChapter = Chapter()
                
                if file.name.isEmpty {
                    newChapter.name = file.file
                } else {
                    newChapter.name = file.name
                }
                newChapter.addFile(file)
                chapters.insert(contentsOf: newChapters, at: chapterIndex)
                
                chapterIndex += 1
                newChapters.append(newChapter)
            }
            if let index = chapters.firstIndex(of: chapter) {
                chapters.remove(at: index)
            }
        }
        cleanupChapters()
        outlineView.deselectAll(self)
        outlineView.reloadData()
        newChapters.forEach { outlineView.expandItem($0) }
        if let newChapter = newChapters.first {
            outlineView.setSelectedItem(newChapter)
        }
    }
}


// MARK: - ExtendedNSOutlineViewDelegate

extension AudioFileList: ExtendedNSOutlineViewDelegate {
    
    func delKeyDown(_ sender: NSOutlineView) {
        deleteSelected(sender)
    }
    
    func enterKetDown(_ sender: NSOutlineView) {
        joinSelectedFiles(sender)
    }
    
    public func outlineView(_ outlineView: NSOutlineView, didClick tableColumn: NSTableColumn) {
        if let sortKey {
            outlineView.tableColumns.forEach { outlineView.setIndicatorImage(nil, in: $0) }
            
            if sortKey == tableColumn.identifier.rawValue {
                sortAscending = !sortAscending
            } else {
                sortAscending = true
            }
        }
        
        let sortDescriptor = NSSortDescriptor(key: tableColumn.identifier.rawValue, ascending: sortAscending)
        if chapterMode {
            chapters.forEach { $0.sortUsingDecriptor(descriptor: sortDescriptor) }
        } else {
            files = (files as NSArray).sortedArray(using: [sortDescriptor]) as? [AudioFile] ?? []
        }
        let image = NSImage(named: sortAscending ? "NSAscendingSortIndicator" : "NSDescendingSortIndicator")
        outlineView.setIndicatorImage(image, in: tableColumn)
        outlineView.reloadData()
    }
    
    public func outlineViewSelectionDidChange(_ notification: Notification) {
        var playable = false
        guard let view = notification.object as? NSOutlineView else {
            return
        }
        if view.selectedItems().count == 1,
           let _ = view.selectedItems().first as? AudioFile {
            playable = true
        }
        
        canPlay = playable
    }
    
    // To get the "group row" look, we implement this method.
    public func outlineView(_ outlineView: NSOutlineView, isGroupItem item: Any) -> Bool {
        item is Chapter
    }
    
    public func outlineView(_ outlineView: NSOutlineView, shouldExpandItem item: Any) -> Bool {
        item is Chapter
    }
        
    public func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        true
    }
    
    //
    // optional methods for content editing
    //

    public func outlineView(
        _ outlineView: NSOutlineView,
        shouldEdit tableColumn: NSTableColumn?,
        item: Any
    ) -> Bool {
        if item is Chapter, tableColumn?.identifier.rawValue == Constants.ColumnId.name {
            return true
        }
        return false
    }
    
    // We can return a different cell for each row, if we want
    public func outlineView(
        _ outlineView: NSOutlineView,
        dataCellFor tableColumn: NSTableColumn?,
        item: Any
    ) -> NSCell? {
        // If we return a cell for the 'nil' tableColumn, it will be used
        // as a "full width" cell and span all the columns
        tableColumn?.dataCell as? NSCell
    }
}


// MARK: - NSOutlineViewDataSource

extension AudioFileList: NSOutlineViewDataSource {
    
    // not used?
    func childrenForItem(_ item: Any?) -> [Any]? {
        if item == nil {
            if chapterMode {
                if let items = (chapters as NSArray?) as? [Any] {
                    return items
                }
            } else {
                if let items = (files as NSArray?) as? [Any] {
                    return items
                }
            }
        }
        else if let chapter = item as? Chapter {
            return chapter.files
        }
        
        return nil
    }
    
    public func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if let chapter = item as? Chapter {
            return chapter.totalFiles()
        } else {
            if chapterMode {
                return chapters.count
            } else {
                return files.count
            }
        }
    }
    
    
    public func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        item is Chapter
    }
    
    public func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
            if item == nil {
                if chapterMode {
                    return chapters[index]
                } else {
                    return files[index]
                }
            }
            
        if let chapter = item as? Chapter {
            return chapter.fileAtIndex(index: index) as Any
        }
            
        return item as Any
    }
    
    public func outlineView(
        _ outlineView: NSOutlineView,
        objectValueFor tableColumn: NSTableColumn?,
        byItem item: Any?
    ) -> Any? {
        
        guard let item else {
            return nil
        }
        
        if let file = item as? AudioFile {
            switch tableColumn?.identifier.rawValue {
            case Constants.ColumnId.file:
                return file.file
            case Constants.ColumnId.name:
                return file.name.isEmpty ? file.file : file.name
            case Constants.ColumnId.author:
                return file.artist
            case Constants.ColumnId.album:
                return file.album
            case Constants.ColumnId.time:
                let duration = file.duration / 1000
                let hours = duration / 3600
                let minutes = (duration - (hours * 3600)) / 60
                let seconds = duration % 60
                
                if hours > 0 {
                    return String(format: "%d:%02d:%02d", hours, minutes, seconds)
                } else {
                    return String(format: "%d:%02d", minutes, seconds)
                }
            default:
                return ""
            }
        } else if let chapter = item as? Chapter {
            if tableColumn?.identifier.rawValue == Constants.ColumnId.name {
                return chapter.name
            } else if tableColumn?.identifier.rawValue == Constants.ColumnId.time {
                let duration = chapter.totalDuration() / 1000

                let hours = duration / 3600
                let minutes = (duration - (hours * 3600)) / 60
                let seconds = duration % 60
                
                if hours > 0 {
                    return String(format: "%d:%02d:%02d", hours, minutes, seconds)
                } else {
                    return String(format: "%d:%02d", minutes, seconds)
                }
            }
            
            return ""
        }
        
        return nil
    }
    
    public func outlineView(
        _ outlineView: NSOutlineView,
        setObjectValue object: Any?,
        for tableColumn: NSTableColumn?,
        byItem item: Any?
    ) {
        if let chapter = item as? Chapter,
           let chapterName = object as? String,
           tableColumn?.identifier.rawValue == Constants.ColumnId.name {
            chapter.name = chapterName
        }
    }
    
    public func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> (any NSPasteboardWriting)? {
        
        // we have stale _draggedNodes, release them
        if !draggedNodes.isEmpty {
            draggedNodes = []
        }
        
        draggedNodes = [item]
        let pBoard = NSPasteboardItem()

        // the actual data doesn't matter since SIMPLE_BPOARD_TYPE drags aren't recognized by anyone but us!.
        pBoard.setData(Data(), forType: Constants.PasteBoardType.SimplePasteBoardType)
        
        // Put string data on the pboard... notice you can drag into TextEdit!
        if let file = item as? AudioFile {
            pBoard.setString(file.name.isEmpty ? file.file : file.name, forType: .string)
        } else if let chapter = item as? Chapter {
            pBoard.setString(chapter.name, forType: .string)
        }
        
        // Put the promised type we handle on the pasteboard.
        pBoard.setPropertyList(["txt"], forType: Constants.PasteBoardType.TextUrlPromise)

        return pBoard
    }
    
    public func outlineView(
        _ outlineView: NSOutlineView,
        validateDrop info: any NSDraggingInfo,
        proposedItem item: Any?,
        proposedChildIndex index: Int
    ) -> NSDragOperation {
        
        var result = NSDragOperation.generic
        
        if index == NSOutlineViewDropOnItemIndex {
            result = NSDragOperation()
        }
        
        if info.draggingSource as AnyObject === outlineView {
            if chapterMode {
                var draggingChapters = true
                for audioItem in draggedNodes {
                    if audioItem is AudioFile {
                        draggingChapters = false
                        break
                    }
                }
                
                if item == nil && !draggingChapters {
                    result = NSDragOperation()
                } else {
                    for audioItem in draggedNodes {
                        if let chapter = audioItem as? Chapter,
                           let draggedChapter = item as? Chapter,
                           chapter === draggedChapter {
                            result = NSDragOperation()
                            break
                        }
                    }
                }
            }
        } else if !draggedNodes.isEmpty {
            draggedNodes = []
        }
        
        return result
        
    }
    
    public func outlineView(
        _ outlineView: NSOutlineView,
        acceptDrop info: any NSDraggingInfo,
        item: Any?,
        childIndex index: Int
    ) -> Bool {
        
        var newSelectedItems = [Any]()
        
        var childIndex = index
        
        if info.draggingSource as AnyObject === outlineView {
            if chapterMode {
                if let dropChapter = item as? Chapter {
                    for audioItem in draggedNodes {
                        if let chapter = audioItem as? Chapter {
                            for file in chapter.files {
                                chapter.insertFile(file: file, atIndex: childIndex)
                                childIndex += 1
                            }
                            if let index = chapters.firstIndex(of: chapter) {
                                chapters.remove(at: index)
                            }
                        } else if let file = audioItem as? AudioFile {
                            if dropChapter.containsFile(file: file) {
                                let idx = dropChapter.indexOfFile(file: file)
                                if idx <= childIndex {
                                    childIndex -= 1
                                }
                            }
                            orphanFile(file)
                            dropChapter.insertFile(file: file, atIndex: childIndex)
                            childIndex += 1
                        }
                    }
                } else {
                    // reorder chapters, validateDrop will ensure there are
                    // only Chapter nodes are dropped
                    for ch in draggedNodes {
                        if let chapter = ch as? Chapter {
                            if let index = chapters.firstIndex(of: chapter) {
                                chapters.remove(at: index)
                            }
                            chapters.insert(chapter, at: childIndex)
                            childIndex += 1
                        }
                    }
                }
                
                cleanupChapters()
            } else {
                // Go ahead and move things.
                for file in draggedNodes {
                    if let audioFile = file as? AudioFile {
                        // Remove the node from its old location
                        var newIndex = childIndex
                        if let oldIndex = files.firstIndex(of: audioFile) {
                            files.remove(at: oldIndex)
                            if childIndex > oldIndex {
                                newIndex -= 1 // account for the remove
                            }
                        }
                        files.insert(audioFile, at: newIndex)
                        newIndex += 1
                        newSelectedItems.append(audioFile)
                    }
                }
            }
            
            if !draggedNodes.isEmpty {
                draggedNodes = []
            }
        } else {
            // drop from external source
            //gets the dragging-specific pasteboard from the sender
            guard let paste = info.draggingSource as? NSPasteboard else {
                return false
            }
            
            //a list of types that we can accept
            guard let desiredType = paste.availableType(from: [NSPasteboard.PasteboardType.fileURL]) else {
                return false
            }
            
            guard paste.data(forType: desiredType) != nil else {
                return false
            }
            
            if desiredType == .fileURL {
                //we have a list of file names in an NSData object
                let sortFiles = UserDefaults.standard.bool(forKey: Constants.UserDefaults.kConfigSortAudioFiles)
                var files: [String] = paste.propertyList(forType: .init("NSFilenamesPboardType")) as? [String] ?? []
                
                if sortFiles {
                    files.sort()
                }
                
                for path in files {
                    var isDir: ObjCBool = false
                    if FileManager.default.fileExists(atPath: path, isDirectory: &isDir) {
                        
                        if isDir.boolValue {
                            // add file recursively
                            addFilesInDirectory(path)
                        } else {
                            addFile(path)
                        }
                    }
                }
                
                tryGuessingAuthorAndAlbum()
            }
        }
        
        outlineView.reloadData()
        
        // Reselect old items.
        outlineView.setSelectedItems(newSelectedItems)
        
        return true
    }
    
}
