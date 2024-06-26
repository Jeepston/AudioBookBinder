

import Cocoa

@objc
protocol ExtendedNSOutlineViewDelegate: NSOutlineViewDelegate {
 
    @objc(delKeyDown:)
    func delKeyDown(_ sender: NSOutlineView)
    
    @objc(enterKeyDown:)
    func enterKetDown(_ sender: NSOutlineView)
}
