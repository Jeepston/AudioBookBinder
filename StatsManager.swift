
import Foundation
import AppKit


@objc
final class StatsManager: NSObject {
    
    @objc static let shared = StatsManager()
    
    private var converters = [AudioBinderWindowController]()
    private let lock = NSLock()
    private var appIcon = NSImage(named: "NSApplicationIcon")!
    
    
    private let kProgressBarHeight: CGFloat = 4.0 / 32.0
    private let kProgressBarHeightInIcon: CGFloat = 5.0 / 32
    
    private let progressGradient = NSImage(contentsOfFile: Bundle.main.path(forResource: "MiniProgressGradient", ofType: "png")!)!
    
    
    
    @objc(updateConverter:)
    func updateConverter(_ converter: AudioBinderWindowController) {
        lock.lock()
        if !converters.contains(converter) {
            converters.append(converter)
        }
        updateProgress()
        lock.unlock()
    }

    @objc(removeConverter:)
    func removeConverter(_ converter: AudioBinderWindowController) {
        lock.lock()
        if let index = converters.firstIndex(where: { $0 == converter }) {
            converters.remove(at: index)
            updateProgress()
        }
        lock.unlock()
    }
    
    
    private func updateProgress() {
        if converters.isEmpty {
            DispatchQueue.main.async { [weak self] in
                NSApp.applicationIconImage = self?.appIcon
            }
            
            return
        }

        let dockIcon = NSImage(size: appIcon.size, flipped: false) { [weak self] rect in
            guard let self else {
                return false
            }
            
            appIcon.draw(in: rect)
            
            var yoff: CGFloat = 0
            let bars = min(5, self.converters.count)
            for i in (0..<bars).reversed() {
                
                let bar = NSMakeRect(
                    0,
                    yoff + self.appIcon.size.height * (self.kProgressBarHeightInIcon - self.kProgressBarHeight / 2),
                    self.appIcon.size.width - 1,
                    self.appIcon.size.height * self.kProgressBarHeight
                )
                yoff += self.appIcon.size.height * self.kProgressBarHeight + 5
                
                NSColor.white.set()
                NSBezierPath.fill(bar)
                
                var done = bar
                let converter = self.converters[i]
                done.size.width = done.size.width * CGFloat(converter.currentProgress) / 100
                
                var gradRect = NSZeroRect
                gradRect.size = self.progressGradient.size
                self.progressGradient.draw(in: done, from: gradRect, operation: .copy, fraction: 1.0)

                NSColor.black.set()
                NSBezierPath.stroke(bar)
            }
            
            return true
        }
        
        DispatchQueue.main.async {
            NSApp.applicationIconImage = dockIcon
        }
    }
}
