import Foundation

public protocol XDREncodable {
    func toXDR(count: Int32) -> Data
}

public protocol XDRDecodable {
    init(xdrData: inout Data, count: Int32)
}

public protocol XDRCodable: XDREncodable, XDRDecodable { }

extension Int32: XDRCodable {
    public func toXDR(count: Int32 = 0) -> Data {
        var n = UInt32(bitPattern: self)
        var a = [UInt8]()

        let divisor = UInt32(UInt8.max) + 1
        for _ in 0..<(self.bitWidth / UInt8.bitWidth) {
            a.append(UInt8(n % divisor))
            n /= divisor
        }

        return Data(bytes: a.reversed())
    }

    public init(xdrData: inout Data, count: Int32 = 0) {
        var n: UInt32 = 0

        let count = UInt32.bitWidth / UInt8.bitWidth

        xdrData.withUnsafeBytes { (bp: UnsafePointer<UInt8>) -> Void in
            for i in 0..<count {
                n *= 256
                n += UInt32(bp.advanced(by: i).pointee)
            }
        }

        (0..<count).forEach { _ in xdrData.remove(at: 0) }

        self = Int32(bitPattern: n)
    }
}

extension UInt32: XDRCodable {
    public func toXDR(count: Int32 = 0) -> Data {
        var n = self
        var a = [UInt8]()

        let divisor = UInt32(UInt8.max) + 1
        for _ in 0..<(self.bitWidth / UInt8.bitWidth) {
            a.append(UInt8(n % divisor))
            n /= divisor
        }

        return Data(bytes: a.reversed())
    }

    public init(xdrData: inout Data, count: Int32 = 0) {
        var n: UInt32 = 0

        let count = UInt32.bitWidth / UInt8.bitWidth

        xdrData.withUnsafeBytes { (bp: UnsafePointer<UInt8>) -> Void in
            for i in 0..<count {
                n *= 256
                n += UInt32(bp.advanced(by: i).pointee)
            }
        }

        (0..<count).forEach { _ in xdrData.remove(at: 0) }

        self = n
    }
}

extension Int64: XDRCodable {
    public func toXDR(count: Int32 = 0) -> Data {
        var n = self
        var a = [UInt8]()

        let divisor = Int64(UInt8.max) + 1
        for _ in 0..<(self.bitWidth / UInt8.bitWidth) {
            a.append(UInt8(n % divisor))
            n /= divisor
        }

        return Data(bytes: a.reversed())
    }

     public init(xdrData: inout Data, count: Int32 = 0) {
        var n: UInt64 = 0

        let count = UInt64.bitWidth / UInt8.bitWidth

        xdrData.withUnsafeBytes { (bp: UnsafePointer<UInt8>) -> Void in
            for i in 0..<count {
                n *= 256
                n += UInt64(bp.advanced(by: i).pointee)
            }
        }

        (0..<count).forEach { _ in xdrData.remove(at: 0) }

        self = Int64(bitPattern: n)
    }
}

extension UInt64: XDRCodable {
    public func toXDR(count: Int32 = 0) -> Data {
        var n = self
        var a = [UInt8]()

        let divisor = UInt64(UInt8.max) + 1
        for _ in 0..<(self.bitWidth / UInt8.bitWidth) {
            a.append(UInt8(n % divisor))
            n /= divisor
        }

        return Data(bytes: a.reversed())
    }

    public init(xdrData: inout Data, count: Int32 = 0) {
        var n: UInt64 = 0

        let count = UInt64.bitWidth / UInt8.bitWidth

        xdrData.withUnsafeBytes { (bp: UnsafePointer<UInt8>) -> Void in
            for i in 0..<count {
                n *= 256
                n += UInt64(bp.advanced(by: i).pointee)
            }
        }

        (0..<count).forEach { _ in xdrData.remove(at: 0) }

        self = n
    }
}

extension Bool: XDRCodable {
    public func toXDR(count: Int32 = 0) -> Data {
        return Int32(self ? 1 : 0).toXDR()
    }

    public init(xdrData: inout Data, count: Int32 = 0) {
        let b = Int32(xdrData: &xdrData)
        self = b != 0
    }
}

extension Data: XDRCodable {
    public func toXDR(count: Int32 = 0) -> Data {
        var xdr = Int32(self.count).toXDR()
        xdr.append(self)

        return xdr
    }

    public init(xdrData: inout Data, count: Int32 = 0) {
        let length = count > 0 ? UInt32(count) : UInt32(xdrData: &xdrData)

        var d = Data()
        for _ in 0..<length {
            d.append(xdrData.remove(at: 0))
        }

        self = d
    }
}

extension String: XDRCodable {
    public func toXDR(count: Int32 = 0) -> Data {
        let length = Int32(self.lengthOfBytes(using: .utf8))

        var xdr = length.toXDR()
        xdr.append(self.data(using: .utf8)!)

        let extraBytes = length % 4
        if extraBytes > 0 {
            for _ in 0..<(4 - extraBytes) {
                xdr.append(contentsOf: [0])
            }
        }

        return xdr
    }

    public init(xdrData: inout Data, count: Int32 = 0) {
        let length = Int32(xdrData: &xdrData)

        let d = xdrData[0..<length]

        self = String(bytes: d, encoding: .utf8)!

        let mod = length % 4
        let extraBytes = mod == 0 ? 0 : 4 - mod

        (0..<(length + extraBytes)).forEach { _ in xdrData.remove(at: 0) }
    }
}

extension Array: XDREncodable {
    public func toXDR(count: Int32 = 0) -> Data {
        let length = UInt32(self.count)

        var xdr = count == 0 ? length.toXDR() : Data()

        forEach {
            if let e = $0 as? XDREncodable {
                xdr.append(e.toXDR(count: 0))
            }
        }

        return xdr
    }
}

extension Array where Element: XDRDecodable {
    public init(xdrData: inout Data, count: Int32 = 0) {
        let length = count > 0 ? UInt32(count) : UInt32(xdrData: &xdrData)

        var a = [Element]()

        (0..<length).forEach { _ in a.append(Element.init(xdrData: &xdrData, count: 0)) }

        self = a
    }
}

extension Optional: XDREncodable {
    public func toXDR(count: Int32 = 0) -> Data {
        var xdr = Data()

        switch self {
        case .some(let a):
            if let encodable = a as? XDREncodable {
                xdr += Int32(1).toXDR() + encodable.toXDR(count: 0)
            }
        case nil:
            xdr += Int32(0).toXDR()
        }

        return xdr
    }
}

public struct FixedLengthArrayWrapper<T: XDREncodable>: Sequence {
    public private(set) var wrapped: Array<T>

    public init() {
        wrapped = [T]()
    }

    public init(_ array: [T]) {
        wrapped = array
    }

    public subscript(_ index: Int) -> T {
        return wrapped[index]
    }

    public func makeIterator() -> AnyIterator<T> {
        var index = 0

        return AnyIterator {
            let element = index < self.wrapped.count ? self[index] : nil

            index += 1

            return element
        }
    }
}

extension FixedLengthArrayWrapper: CustomDebugStringConvertible {
    public var debugDescription: String {
        return wrapped.debugDescription
    }
}

extension FixedLengthArrayWrapper: XDREncodable {
    public func toXDR(count: Int32 = 0) -> Data {
        return wrapped.toXDR(count: Int32(wrapped.count))
    }
}

public struct FixedLengthDataWrapper: Equatable {
    public private(set) var wrapped: Data

    public init() {
        wrapped = Data()
    }

    public init(_ data: Data) {
        wrapped = data
    }

    public static func ==(lhs: FixedLengthDataWrapper, rhs: FixedLengthDataWrapper) -> Bool {
        return lhs.wrapped == rhs.wrapped
    }
}

extension FixedLengthDataWrapper: CustomDebugStringConvertible {
    public var debugDescription: String {
        return wrapped.debugDescription
    }
}

extension FixedLengthDataWrapper: XDREncodable {
    public func toXDR(count: Int32 = 0) -> Data {
        return wrapped
    }
}

public protocol XDREncodableStruct: XDREncodable {
}

extension XDREncodableStruct {
    public func toXDR(count: Int32 = 0) -> Data {
        var xdr = Data()

        for (_, value) in Mirror(reflecting: self).children {
            if let value = value as? XDREncodable {
                xdr.append(value.toXDR(count: 0))
            }
        }

        return xdr
    }
}
