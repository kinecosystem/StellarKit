//
//  CommonCrypto.swift
//  StellarKinKit
//
//  Created by Kin Foundation
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation
import libsodium

private func hash(data input: Data) -> Data? {
    var output = Data(count: 32)
    var result = -1

    result = output.withUnsafeMutableBytes { outputPtr in
        input.withUnsafeBytes{ inputPtr in
            Int(crypto_hash_sha256(outputPtr,
                                   inputPtr,
                                   UInt64(input.count)))
        }
    }

    if result != 0 {
        return nil
    }

    return output
}

extension Data {
    var sha256: Data {
        return hash(data: self)!
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
