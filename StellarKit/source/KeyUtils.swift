//
//  KeyUtils.swift
//  StellarKit
//
//  Created by Kin Foundation
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation

public struct KeyUtils {
    public static func base32(publicKey: Data) -> String {
        return publicKeyToBase32(publicKey)
    }

    public static func base32(seed: Data) -> String {
        return seedToBase32(seed)
    }

    public static func key(base32: String) -> Data {
        return base32KeyToData(key: base32)
    }
}
