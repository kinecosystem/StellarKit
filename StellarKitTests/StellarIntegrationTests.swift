//
//  StellarIntegrationTests.swift
//  StellarKitTests
//
//  Created by Kin Foundation
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import XCTest
@testable import StellarKit

class StellarIntegrationTests: StellarBaseTests {
    override var endpoint: String { return "http://localhost:8000" }
    override var networkId: NetworkId { return .custom("private testnet") }
}
