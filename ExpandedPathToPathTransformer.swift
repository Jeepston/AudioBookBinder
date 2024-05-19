//
//  ExpandedPathToPathTransformer.swift
//  AudioBookBinder
//
//  Created by Dmitrij Hojkolov on 18.05.2024.
//  Copyright © 2024 AudioBookBinder. All rights reserved.
//

import Foundation


@objc
final class ExpandedPathToPathTransformer : ValueTransformer {
    override class func transformedValueClass() -> AnyClass {
        NSString.self
    }
    
    override class func allowsReverseTransformation() -> Bool {
        false
    }
    
    override func transformedValue(_ value: Any?) -> Any? {
        guard value != nil, let string = value as? NSString else {
            return nil
        }
        return FileManager.default.displayName(atPath: string as String) as NSString
    }
}
