//
//  CommonCrypto.swift
//  StellarKit
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

public extension Data {
    var sha256: Data {
        return hash(data: self)!
    }
}
