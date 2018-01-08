//
//  KeyUtils.swift
//  SwiftyStellar
//
//  Created by Avi Shevin on 08/01/2018.
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation
import Sodium

/*
 Create:
 1. hash password using hashed(string: String)
 2. generate salt using salt()

 Save:
 1. save file containing password hash and salt

 Load:
 1. obtain password
 2. obtain password hash
 3. obtain salt
 4. generate key-pair using keyPair(from password: String, hash: String, salt: String)
*/


enum KeyUtilsError: Error {
    case encodingFailed (String)
    case hashingFailed
    case passwordIncorrect
    case unknownError
}

struct KeyUtils {
    static func keyPair() -> Sign.KeyPair? {
        return Sodium().sign.keyPair()
    }

    static func keyPair(from seed: Data) -> Sign.KeyPair? {
        return Sodium().sign.keyPair(seed: seed)
    }

    static func keyPair(from seed: String) -> Sign.KeyPair? {
        return Sodium().sign.keyPair(seed: base32KeyToData(key: seed))
    }

    static func keyPair(from password: String, hash: String, salt: String) throws -> Sign.KeyPair? {
        guard try verifyPassword(password: password, hash: hash) else {
            throw KeyUtilsError.passwordIncorrect
        }

        guard let passwordData = password.data(using: .utf8) else {
            throw KeyUtilsError.encodingFailed(password)
        }

        guard let saltData = salt.data(using: .utf8) else {
            throw KeyUtilsError.encodingFailed(salt)
        }

        let sodium = Sodium()

        guard let seed = sodium.pwHash.hash(outputLength: 32,
                                            passwd: passwordData,
                                            salt: saltData,
                                            opsLimit: sodium.pwHash.OpsLimitInteractive,
                                            memLimit: sodium.pwHash.MemLimitInteractive) else {
                                                throw KeyUtilsError.hashingFailed
        }

        return keyPair(from: seed)
    }

    static func base32(publicKey: Data) -> String {
        return publicKeyToBase32(publicKey)
    }

    static func base32(seed: Data) -> String {
        return seedToBase32(seed)
    }

    static func key(base32: String) -> Data {
        return base32KeyToData(key: base32)
    }

    static func seed() -> Data? {
        return Sodium().randomBytes.buf(length: 32)
    }

    static func hashed(string: String) throws -> String {
        guard let stringData = string.data(using: .utf8) else {
            throw KeyUtilsError.encodingFailed(string)
        }

        let sodium = Sodium()

        guard let hash = sodium.pwHash.str(passwd: stringData,
                                           opsLimit: sodium.pwHash.OpsLimitInteractive,
                                           memLimit: sodium.pwHash.MemLimitInteractive) else {
                                            throw KeyUtilsError.hashingFailed
        }

        return hash
    }

    static func verifyPassword(password: String, hash: String) throws -> Bool {
        guard let passwordData = password.data(using: .utf8) else {
            throw KeyUtilsError.encodingFailed(password)
        }

        let sodium = Sodium()

        return sodium.pwHash.strVerify(hash: hash, passwd: passwordData)
    }

    static func salt() -> String? {
        return Sodium().randomBytes.buf(length: 16)?.hexString
    }
}
