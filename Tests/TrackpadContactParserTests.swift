import CoreGraphics
import Foundation

@main
struct TrackpadContactParserTests {
    static func main() {
        let contacts = UnsafeMutableRawPointer.allocate(
            byteCount: 96 * 2,
            alignment: 8
        )
        defer { contacts.deallocate() }
        contacts.initializeMemory(as: UInt8.self, repeating: 0, count: 96 * 2)

        contacts.storeBytes(of: Float(0.2), toByteOffset: 32, as: Float.self)
        contacts.storeBytes(of: Float(0.4), toByteOffset: 36, as: Float.self)
        contacts.storeBytes(of: Float(0.8), toByteOffset: 96 + 32, as: Float.self)
        contacts.storeBytes(of: Float(0.6), toByteOffset: 96 + 36, as: Float.self)

        let frame = TrackpadContactParser.frame(contacts: contacts, count: 2)
        expect(frame.extendedFingerCount == 2)
        expect(abs((frame.palmCenter?.x ?? 0) - 0.5) < 0.0001)
        expect(abs((frame.palmCenter?.y ?? 0) - 0.5) < 0.0001)

        let empty = TrackpadContactParser.frame(contacts: nil, count: 0)
        expect(empty.extendedFingerCount == 0)
        expect(empty.palmCenter == nil)

        print("TrackpadContactParserTests: all checks passed")
    }

    private static func expect(
        _ condition: @autoclosure () -> Bool,
        _ message: String = "unexpected result"
    ) {
        guard condition() else { fatalError(message) }
    }
}
