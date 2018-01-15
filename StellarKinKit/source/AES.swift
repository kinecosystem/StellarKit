//
//  AES.swift
//  StellarKinKit
//
//  Created by Avi Shevin on 14/01/2018.
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation
import CommonCrypto

func AESEncrypt(data: Data, key: Data, iv: Data) -> Data? {
    var err: CCCryptorStatus = Int32(kCCSuccess)
    var result = Data(capacity: data.count + kCCBlockSizeAES128)
    var resultLength = 0

    key.withUnsafeBytes { (keyPtr: UnsafePointer) -> Void in
        data.withUnsafeBytes({ (dataPtr: UnsafePointer<UInt8>) -> Void in
            iv.withUnsafeBytes({ (ivPtr: UnsafePointer<UInt8>) -> Void in
                result.withUnsafeMutableBytes({ (resultPtr: UnsafeMutablePointer<UInt8>) -> Void in
                    err = CCCrypt(UInt32(kCCEncrypt),
                                  UInt32(kCCAlgorithmAES128),
                                  UInt32(kCCOptionPKCS7Padding),
                                  keyPtr,
                                  key.count,
                                  ivPtr,
                                  dataPtr,
                                  data.count,
                                  resultPtr,
                                  result.count,
                                  &resultLength)
                })
            })
        })
    }

    result.count = resultLength

    return err == kCCSuccess ? result : nil
}
