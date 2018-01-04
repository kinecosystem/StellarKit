import Foundation

struct CryptoKeyType {
    static let KEY_TYPE_ED25519: Int32 = 0
    static let KEY_TYPE_PRE_AUTH_TX: Int32 = 1
    static let KEY_TYPE_HASH_X: Int32 = 2
}

struct PublicKeyType {
    static let PUBLIC_KEY_TYPE_ED25519 = CryptoKeyType.KEY_TYPE_ED25519
}

enum PublicKey: XDREncodable {
    case PUBLIC_KEY_TYPE_ED25519 (FixedLengthDataWrapper)

    func discriminant() -> Int32 {
        switch self {
        case .PUBLIC_KEY_TYPE_ED25519: return PublicKeyType.PUBLIC_KEY_TYPE_ED25519
        }
    }

    func toXDR(count: Int32 = 0) -> Data {
        var xdr = discriminant().toXDR()

        switch self {
        case .PUBLIC_KEY_TYPE_ED25519 (let key):
            xdr.append(key.toXDR())
        }

        return xdr
    }
}

struct AssetType {
    static let ASSET_TYPE_NATIVE: Int32 = 0
    static let ASSET_TYPE_CREDIT_ALPHANUM4: Int32 = 1
    static let ASSET_TYPE_CREDIT_ALPHANUM12: Int32 = 2
}

enum Asset: XDREncodable {
    case ASSET_TYPE_NATIVE
    case ASSET_TYPE_CREDIT_ALPHANUM4 (Alpha4)
    case ASSET_TYPE_CREDIT_ALPHANUM12 (Alpha12)

    struct Alpha4: XDREncodableStruct {
        let assetCode: FixedLengthDataWrapper
        let issuer: PublicKey

        init(assetCode: FixedLengthDataWrapper, issuer: PublicKey) {
            self.assetCode = assetCode
            self.issuer = issuer
        }
    }

    struct Alpha12: XDREncodableStruct {
        let assetCode: FixedLengthDataWrapper
        let issuer: PublicKey
    }

    func discriminant() -> Int32 {
        switch self {
        case .ASSET_TYPE_NATIVE: return AssetType.ASSET_TYPE_NATIVE
        case .ASSET_TYPE_CREDIT_ALPHANUM4: return AssetType.ASSET_TYPE_CREDIT_ALPHANUM4
        case .ASSET_TYPE_CREDIT_ALPHANUM12: return AssetType.ASSET_TYPE_CREDIT_ALPHANUM12
        }
    }

    func toXDR(count: Int32 = 0) -> Data {
        var xdr = discriminant().toXDR()

        switch self {
        case .ASSET_TYPE_NATIVE: break

        case .ASSET_TYPE_CREDIT_ALPHANUM4 (let alpha4):
            xdr.append(alpha4.toXDR())

        case .ASSET_TYPE_CREDIT_ALPHANUM12 (let alpha12):
            xdr.append(alpha12.toXDR())
        }

        return xdr
    }
}

struct CreateAccountOp: XDREncodableStruct {
    let destination: PublicKey
    let balance: Int64
}

struct PaymentOp: XDREncodableStruct {
    let destination: PublicKey
    let asset: Asset
    let amount: Int64
}

struct OperationType {
    static let CREATE_ACCOUNT: Int32 = 0
    static let PAYMENT: Int32 = 1
    static let PATH_PAYMENT: Int32 = 2
    static let MANAGE_OFFER: Int32 = 3
    static let CREATE_PASSIVE_OFFER: Int32 = 4
    static let SET_OPTIONS: Int32 = 5
    static let CHANGE_TRUST: Int32 = 6
    static let ALLOW_TRUST: Int32 = 7
    static let ACCOUNT_MERGE: Int32 = 8
    static let INFLATION: Int32 = 9
    static let MANAGE_DATA: Int32 = 10
}

struct Operation: XDREncodableStruct {
    let sourceAccount: PublicKey?
    let body: Body

    enum Body: XDREncodable {
        case CREATE_ACCOUNT (CreateAccountOp)
        case PAYMENT (PaymentOp)

        func discriminant() -> Int32 {
            switch self {
            case .CREATE_ACCOUNT: return OperationType.CREATE_ACCOUNT
            case .PAYMENT: return OperationType.PAYMENT
            }
        }

        func toXDR(count: Int32 = 0) -> Data {
            var xdr = discriminant().toXDR()

            switch self {
            case .CREATE_ACCOUNT (let op):
                xdr.append(op.toXDR())

            case .PAYMENT (let op):
                xdr.append(op.toXDR())
            }

            return xdr
        }
    }
}

struct MemoType {
    static let MEMO_NONE: Int32 = 0
    static let MEMO_TEXT: Int32 = 1
    static let MEMO_ID: Int32 = 2
    static let MEMO_HASH: Int32 = 3
    static let MEMO_RETURN: Int32 = 4
}

enum Memo: XDREncodable {
    case MEMO_NONE
    case MEMO_TEXT (String)
    case MEMO_ID (UInt64)
    case MEMO_HASH (FixedLengthDataWrapper)
    case MEMO_RETURN (FixedLengthDataWrapper)

    func discriminant() -> Int32 {
        switch self {
        case .MEMO_NONE: return MemoType.MEMO_NONE
        case .MEMO_TEXT: return MemoType.MEMO_TEXT
        case .MEMO_ID: return MemoType.MEMO_ID
        case .MEMO_HASH: return MemoType.MEMO_HASH
        case .MEMO_RETURN: return MemoType.MEMO_RETURN
        }
    }

    func toXDR(count: Int32 = 0) -> Data {
        var xdr = discriminant().toXDR()

        switch self {
        case .MEMO_NONE: break
        case .MEMO_TEXT (let text): xdr.append(text.toXDR())
        case .MEMO_ID (let id): xdr.append(id.toXDR())
        case .MEMO_HASH (let hash): xdr.append(hash.toXDR())
        case .MEMO_RETURN (let hash): xdr.append(hash.toXDR())
        }

        return xdr
    }
}

struct TimeBounds: XDREncodableStruct {
    let minTime: UInt64
    let maxTime: UInt64
}

struct Transaction: XDREncodableStruct {
    let sourceAccount: PublicKey
    let fee: UInt32
    let seqNum: UInt64
    let timeBounds: TimeBounds?
    let memo: Memo
    let operations: [Operation]
    let reserved: Int32 = 0

    init(sourceAccount: PublicKey, seqNum: UInt64, timeBounds: TimeBounds?, memo: Memo, operations: [Operation]) {
        self.sourceAccount = sourceAccount
        self.seqNum = seqNum
        self.timeBounds = timeBounds
        self.memo = memo
        self.operations = operations

        self.fee = UInt32(100 * operations.count)
    }
}

struct EnvelopeType {
    static let ENVELOPE_TYPE_SCP: Int32 = 1
    static let ENVELOPE_TYPE_TX: Int32 = 2
    static let ENVELOPE_TYPE_AUTH: Int32 = 3
}

struct TransactionSignaturePayload: XDREncodableStruct {
    let networkId: FixedLengthDataWrapper
    let taggedTransaction: TaggedTransaction

    enum TaggedTransaction: XDREncodable {
        case ENVELOPE_TYPE_TX (Transaction)

        func discriminant() -> Int32 {
            switch self {
            case .ENVELOPE_TYPE_TX: return EnvelopeType.ENVELOPE_TYPE_TX
            }
        }

        func toXDR(count: Int32 = 0) -> Data {
            var xdr = discriminant().toXDR()

            switch self {
            case .ENVELOPE_TYPE_TX (let tx): xdr.append(tx.toXDR())
            }

            return xdr
        }
    }
}

struct DecoratedSignature: XDREncodableStruct {
    let hint: FixedLengthDataWrapper;
    let signature: Data
}

struct TransactionEnvelope: XDREncodableStruct {
    let tx: Transaction
    let signatures: [DecoratedSignature]
}
