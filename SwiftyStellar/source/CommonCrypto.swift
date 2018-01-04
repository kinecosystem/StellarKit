//
//  CommonCrypto.swift
//  SwiftyStellar
//
//  Created by Avi Shevin on 04/01/2018.
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation
import CommonCrypto

extension Data {
    var sha256: Data {
        var hash = [UInt8](repeating: 0,  count: Int(CC_SHA256_DIGEST_LENGTH))
        self.withUnsafeBytes {
            _ = CC_SHA256($0, CC_LONG(self.count), &hash)
        }
        
        return Data(bytes: hash)
    }
}

extension Data {
    var hexString: String {
        var s = ""

        self.withUnsafeBytes { (bp: UnsafePointer<UInt8>) -> Void in
            for i in 0..<count {
                s += String(format: "%02x", bp.advanced(by: i).pointee)
            }
        }

        return s
    }
}
