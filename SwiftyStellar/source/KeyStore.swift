//
//  KeyStore.swift
//  SwiftyStellar
//
//  Created by Avi Shevin on 08/01/2018.
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation
import Sodium

enum KeyStoreErrors: Error {
    case keychainStoreFailed
    case noSalt
    case noSeed
    case keypairGenerationFailed
    case encryptionFailed
}

private let keychainPrefix = "__swifty_stellar_"
private let keychain = KeychainSwift(keyPrefix: keychainPrefix)

public class StellarAccount {
    private(set) fileprivate var keychainKey: String

    public var publicKey: String? {
        guard
            let json = json(),
            let key = json["pkey"] else {
                return nil
        }

        return key
    }

    func secretKey(passphrase: String) -> Data? {
        guard let seed = seed(passphrase: passphrase) else {
            return nil
        }

        guard let keypair = KeyUtils.keyPair(from: seed) else {
            return nil
        }

        return keypair.secretKey
    }

    func secretSeed(passphrase: String) -> String? {
        guard let seed = seed(passphrase: passphrase) else {
            return nil
        }

        return KeyUtils.base32(seed: seed)
    }

    init(keychainKey: String) {
        self.keychainKey = keychainKey
    }

    func json() -> [String: String]? {
        guard
            let data = keychain.getData(keychainKey),
            let jsonOpt = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: String],
            let json = jsonOpt else {
                return nil
        }

        return json
    }

    fileprivate func seed(passphrase: String) -> Data? {
        guard
            let json = json(),
            let eseed = json["seed"],
            let salt = json["salt"],
            let seed = try? KeyUtils.seed(from: passphrase, encryptedSeed: eseed, salt: salt) else {
                return nil
        }

        return seed
    }
}

public struct KeyStore {
    public static func newAccount(passphrase: String) throws -> StellarAccount {
        let sodium = Sodium()

        let keychainKey = nextKeychainKey()

        guard let salt = KeyUtils.salt() else {
            throw KeyStoreErrors.noSalt
        }

        guard let seed = sodium.randomBytes.buf(length: 32) else {
            throw KeyStoreErrors.noSeed
        }

        let skey = try KeyUtils.keyHash(passphrase: passphrase, salt: salt)

        guard let encryptedSeed: Data = sodium.secretBox.seal(message: seed, secretKey: skey) else {
            throw KeyStoreErrors.encryptionFailed
        }

        guard let keypair = KeyUtils.keyPair(from: seed) else {
            throw KeyStoreErrors.keypairGenerationFailed
        }

        let dict = [
            "seed" : encryptedSeed.hexString,
            "salt" : salt,
            "pkey" : KeyUtils.base32(publicKey: keypair.publicKey)
        ]

        let data = try JSONSerialization.data(withJSONObject: dict, options: [])

        guard keychain.set(data, forKey: keychainKey) else {
            throw KeyStoreErrors.keychainStoreFailed
        }

        let account = StellarAccount(keychainKey: keychainKey)

        return account
    }

    public static func account(at index: Int) -> StellarAccount? {
        let keys = self.keys()

        guard index < keys.count else {
            return nil
        }

        guard let indexStr = keys[index].split(separator: "_").last else {
            return nil
        }

        return StellarAccount(keychainKey: String(indexStr))
    }

    @discardableResult
    public static func remove(at index: Int) -> Bool {
        return keychain.delete(String(format: "%06d", index))
    }

    public static func count() -> Int {
        return keys().count
    }

    public static func export(passphrase: String, newPassphrase: String) -> [[String: String]] {
        var output = [[String: String]]()

        for i in 0..<count() {
            if let a = account(at: i), let json = a.json() {
                let reencryptedJSON: [String: String]?
                if passphrase != newPassphrase {
                    reencryptedJSON = reencrypt(a, passphrase: passphrase, newPassphrase: newPassphrase)
                } else {
                    reencryptedJSON = json
                }

                if let json = reencryptedJSON {
                    output.append(json)
                }
            }
        }

        return output
    }

    private static func reencrypt(_ account: StellarAccount,
                                  passphrase: String,
                                  newPassphrase: String) -> [String: String]? {
        guard let seed = account.seed(passphrase: passphrase) else {
            return nil
        }

        guard
            let json = account.json(),
            let salt = json["salt"],
            let pkey = json["pkey"],
            let skey = try? KeyUtils.keyHash(passphrase: passphrase, salt: salt),
            let encryptedSeed: Data = Sodium().secretBox.seal(message: seed, secretKey: skey)
            else {
                return nil
        }

        return [
            "seed": encryptedSeed.hexString,
            "salt": salt,
            "pkey": pkey,
        ]
    }

    private static func nextKeychainKey() -> String {
        let keys = self.keys()

        if keys.count == 0 {
            return String(format: "%06d", 0)
        }
        else {
            if
                let key = keys.last,
                let indexStr = key.split(separator: "_").last,
                let last = Int(indexStr) {
                let index = last + 1

                return String(format: "%06d", index)
            }
            else {
                return ""
            }
        }
    }

    private static func keys() -> [String] {
        let keys = (keychain.getAllKeys() ?? []).filter {
            $0.starts(with: keychainPrefix)
        }

        return keys.sorted()
    }
}
