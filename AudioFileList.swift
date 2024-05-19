//
//  AudioFileList.swift
//  AudioBookBinder
//
//  Created by Dmitrij Hojkolov on 19.05.2024.
//  Copyright © 2024 AudioBookBinder. All rights reserved.
//

import Foundation


extension AudioFileList: ExtendedNSOutlineViewDelegate {
    
    func delKeyDown(_ sender: NSOutlineView) {
        deleteSelected(sender)
    }
}
