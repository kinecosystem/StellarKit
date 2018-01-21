//
//  Conversion.swift
//  StellarKinKit
//
//  Created by Kin Foundation
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation

func base32KeyToData(key: String) -> Data {
    // Stellar represents a key in base32 using a leading type identifier and a trailing 2-byte
    // checksum, for a total of 35 bytes.  The actual key is stored in bytes 2-33.

    let binary = base32ToBinary(base32: key)

    let keyData = binary[8..<264]

    var d = Data()

    for i in stride(from: 0, to: keyData.count, by: 8) {
        d.append(UInt8(binaryString: keyData[i..<(i + 8)]))
    }

    return d
}

func publicKeyToBase32(_ key: Data) -> String {
    var d = Data([VersionBytes.ed25519PublicKey])

    d.append(key)
    d.append(contentsOf: d.crc16)

    return dataToBase32(d)
}

func seedToBase32(_ seed: Data) -> String {
    var d = Data([VersionBytes.ed25519SecretSeed])

    d.append(seed)
    d.append(contentsOf: d.crc16)

    return dataToBase32(d)
}

private let fromTable: [String: String] = [
    "A": "00000", "B": "00001", "C": "00010", "D": "00011", "E": "00100", "F": "00101",
    "G": "00110", "H": "00111", "I": "01000", "J": "01001", "K": "01010", "L": "01011",
    "M": "01100", "N": "01101", "O": "01110", "P": "01111", "Q": "10000", "R": "10001",
    "S": "10010", "T": "10011", "U": "10100", "V": "10101", "W": "10110", "X": "10111",
    "Y": "11000", "Z": "11001", "2": "11010", "3": "11011", "4": "11100", "5": "11101",
    "6": "11110", "7": "11111",
]

private let toTable: [String: String] = {
    var t = [String: String]()

    for (k, v) in fromTable { t[v] = k }

    return t
}()

private func base32ToBinary(base32: String) -> String {
    var s = ""
    for c in base32 {
        if c != "=" {
            s += fromTable[String(c)]!
        }
    }

    return s
}

private struct VersionBytes {
    static let ed25519PublicKey: UInt8 = 6 << 3         // G
    static let ed25519SecretSeed: UInt8 = 18 << 3       // S
    static let preAuthTx: UInt8 = 19 << 3               // T
    static let sha256Hash: UInt8 =  23 << 3             // X
}

private func dataToBase32(_ data: Data) -> String {
    guard (data.count * UInt8.bitWidth) % 5 == 0 else {
        fatalError("Number of bits not a multiple of 5.  This method intended for encoding Stellar public keys.")
    }

    let binary = data.binaryString
    var s = ""

    for i in stride(from: 0, to: binary.count, by: 5) {
        s += toTable[binary[i..<(i + 5)]]!
    }

    return s
}

public extension UInt8 {
    init(binaryString: String) {
        var byte: UInt8 = 0

        for i in 0..<8 {
            let digit = UInt8(binaryString[i])
            byte *= 2
            byte += digit!
        }

        self = byte
    }
}

public extension String {
    var urlEncoded: String? {
        var allowedQueryParamAndKey = NSMutableCharacterSet.urlQueryAllowed
        allowedQueryParamAndKey.remove(charactersIn: ";/?:@&=+$, ")

        return self.addingPercentEncoding(withAllowedCharacters: allowedQueryParamAndKey)
    }
}

public extension String {
    var length: Int {
        return self.count
    }

    subscript (i: Int) -> String {
        return self[i ..< i + 1]
    }

    func substring(fromIndex: Int) -> String {
        return self[min(fromIndex, length) ..< length]
    }

    func substring(toIndex: Int) -> String {
        return self[0 ..< max(0, toIndex)]
    }

    subscript (r: Range<Int>) -> String {
        let range = Range(uncheckedBounds: (lower: max(0, min(length, r.lowerBound)),
                                            upper: min(length, max(0, r.upperBound))))
        let start = index(startIndex, offsetBy: range.lowerBound)
        let end = index(start, offsetBy: range.upperBound - range.lowerBound)
        return String(self[start ..< end])
    }
}
