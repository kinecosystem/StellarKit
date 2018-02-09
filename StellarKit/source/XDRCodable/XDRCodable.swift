//
//  XDRCodable.swift
//  StellarKit
//
//  Created by Kin Foundation
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

/*
 Based on: https://github.com/mikeash/BinaryCoder
 */

/// A convenient shortcut for indicating something is both encodable and decodable.
public typealias XDRCodable = XDREncodable & XDRDecodable
