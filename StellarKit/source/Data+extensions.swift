//
//  Data+extensions.swift
//  StellarKit
//
//  Created by Kin Foundation
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation

public extension Data {
    var sha256: Data {
        return Data(SHA256([UInt8](self)).digest())
    }
}
