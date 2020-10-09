//
//  MXKPasteboardManager.swift
//  MatrixKitSample
//
//  Created by Ismail on 9.10.2020.
//  Copyright © 2020 matrix.org. All rights reserved.
//

import Foundation
import UIKit

@objcMembers
public class MXKPasteboardManager: NSObject {
    
    public static let shared = MXKPasteboardManager(withPasteboard: .general)
    
    private init(withPasteboard pasteboard: UIPasteboard) {
        self.pasteboard = pasteboard
        super.init()
    }
    
    /// Pasteboard to use on copy operations. Defaults to `UIPasteboard.generalPasteboard`.
    public var pasteboard: UIPasteboard
    
}
