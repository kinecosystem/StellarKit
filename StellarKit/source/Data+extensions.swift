//
//  CommonCrypto.swift
//  StellarKit
//
//  Created by Kin Foundation
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation
import CCommonCrypto

private func hash(data input: Data) -> Data? {
    var output = Data(count: Int(CC_SHA256_DIGEST_LENGTH))

    let result = output.withUnsafeMutableBytes { outputPtr in
        input.withUnsafeBytes{ inputPtr in
            CC_SHA256(inputPtr, CC_LONG(input.count), outputPtr);
        }
    }

    if result == nil {
        return nil
    }

    return output
}

public extension Data {
    var sha256: Data {
        return hash(data: self)!
    }
}
