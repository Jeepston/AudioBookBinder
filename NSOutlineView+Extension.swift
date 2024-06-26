

import Cocoa

@objc
extension NSOutlineView {
    
    func selectedItems() -> [Any] {
        var items = [Any]()
        
        for index in selectedRowIndexes {
            if let item = item(atRow: index) {
                items.append(item)
            }
        }
        
        return items
    }
    
    @objc(setSelectedItem:)
    func setSelectedItem(_ item: Any) {
        let row = row(forItem: item)
        
        if row >= 0 {
            selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        }
    }
    
    @objc(setSelectedItems:)
    func setSelectedItems(_ items: [Any]) {
        
        var newSelection = [Int]()
        
        for item in items {
            let row = row(forItem: item)
            
            if row >= 0 {
                newSelection.append(row)
            }
        }
        
        selectRowIndexes(IndexSet(newSelection), byExtendingSelection: false)
    }
    
    open override func keyDown(with event: NSEvent) {
        debugPrint("KEYDOWN")
        guard
            let firstChar = event.characters?.first,
            let uniScalar = firstChar.unicodeScalars.first
        else {
            return
        }
        
        let char = Int(uniScalar.value)
        
        
        switch char {
        case NSDeleteFunctionKey, NSDeleteCharFunctionKey, NSDeleteCharacter:
            if let delKeyDelegate = self.delegate as? ExtendedNSOutlineViewDelegate {
                delKeyDelegate.delKeyDown(self)
            }
        case NSEnterCharacter:
            if let delKeyDelegate = self.delegate as? ExtendedNSOutlineViewDelegate {
                delKeyDelegate.enterKetDown(self)
            }
        case NSLeftArrowFunctionKey:
            doCollapse()
        case NSRightArrowFunctionKey:
            doExpand()
        default:
            super.keyDown(with: event)
        }
    }
    
    func doExpand() {
        guard !selectedRowIndexes.isEmpty else {
            return
        }

        var items = [Any]()
        for row in selectedRowIndexes {
            guard let item = item(atRow: row) else {
                continue
            }
            if isExpandable(item) {
                items.append(item)
            }
        }

        items.forEach { expandItem($0) }
    }
    
    func doCollapse() {
        guard !selectedRowIndexes.isEmpty else {
            return
        }
        
        if selectedRowIndexes.count == 1 {
            guard 
                let row = selectedRowIndexes.first,
                let item = item(atRow: row)
            else {
                return
            }
            
            // select chapter row if it's a file and if it's a chapter - collapse
            if isExpandable(item) {
                    collapseItem(item)
            } else {
                if let parent = parent(forItem: item) {
                    setSelectedItem(parent)
                }
            }
        }
        else {
            // multiple selection rules:
            //    - if only !expandable items - ignore
            //    - collapse and select all expandable items
            var items = [Any]()
            for row in selectedRowIndexes {
                guard let item = item(atRow: row), isExpandable(item) else {
                    continue
                }
                items.append(item)
            }
            
            if !items.isEmpty {
                items.forEach { collapseItem($0) }
                setSelectedItems(items)
            }
        }
    }
}
