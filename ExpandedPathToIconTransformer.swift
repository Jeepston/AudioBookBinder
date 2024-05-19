//

import Cocoa
import UniformTypeIdentifiers


@objc
final class ExpandedPathToIconTransformer: ValueTransformer {
    
    override class func transformedValueClass() -> AnyClass {
        NSImage.self
    }
    
    override class func allowsReverseTransformation() -> Bool {
        false
    }
    
    override func transformedValue(_ value: Any?) -> Any? {
        
        guard value != nil, let string = value as? NSString else {
            return nil
        }
        
        let path = string.expandingTildeInPath as NSString
        let icon: NSImage
        
        //show a folder icon if the folder doesn't exist
        if path.pathExtension.isEmpty && !FileManager.default.fileExists(atPath: path as String) {
            icon = NSWorkspace.shared.icon(for: .folder)
        } else {
            icon = NSWorkspace.shared.icon(forFile: path as String)
        }
        
        icon.size = NSMakeSize(16.0, 16.0)
        
        return icon
    }
}
