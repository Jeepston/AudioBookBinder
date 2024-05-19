//
//  ExtendedNSOutlineViewDelegate.swift
//  AudioBookBinder
//
//  Created by Dmitrij Hojkolov on 19.05.2024.
//  Copyright © 2024 AudioBookBinder. All rights reserved.
//

import Cocoa

@objc
protocol ExtendedNSOutlineViewDelegate: NSOutlineViewDelegate {
 
    @objc(delKeyDown:)
    func delKeyDown(_ sender: NSOutlineView)
}
