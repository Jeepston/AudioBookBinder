
@objc
final class VolumeLengthTransformer: ValueTransformer {
    override class func transformedValueClass() -> AnyClass {
        NSString.self
    }
    
    override class func allowsReverseTransformation() -> Bool {
        false
    }

    override func transformedValue(_ value: Any?) -> Any? {
        guard value != nil, let intValue = value as? Int else {
            return ""
        }
        
        if intValue >= 25 {
            return "--"
        } else {
            return "\(intValue)"
        }
    }
}
