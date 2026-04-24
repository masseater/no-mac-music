import AppKit
import CoreGraphics
import Foundation

// IOKit/hidsystem/ev_keymap.h constants
private let NX_KEYTYPE_PLAY: Int32 = 16
private let NX_KEYTYPE_NEXT: Int32 = 17
private let NX_KEYTYPE_PREVIOUS: Int32 = 18
private let NX_KEYTYPE_FAST: Int32 = 19
private let NX_KEYTYPE_REWIND: Int32 = 20

private let systemDefinedEventType: CGEventType = CGEventType(rawValue: 14)! // NSEvent.EventType.systemDefined

final class MediaKeyTap {
    typealias Handler = (MediaCommand) -> Void

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var handler: Handler?

    func start(handler: @escaping Handler) throws {
        stop()
        self.handler = handler

        let mask: CGEventMask = 1 << systemDefinedEventType.rawValue

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: MediaKeyTap.callback,
            userInfo: selfPtr
        ) else {
            throw MediaKeyTapError.creationFailed
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.eventTap = tap
        self.runLoopSource = source
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        handler = nil
    }

    private static let callback: CGEventTapCallBack = { _, type, cgEvent, userInfo in
        guard let userInfo else { return Unmanaged.passUnretained(cgEvent) }
        let tap = Unmanaged<MediaKeyTap>.fromOpaque(userInfo).takeUnretainedValue()

        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let port = tap.eventTap {
                CGEvent.tapEnable(tap: port, enable: true)
            }
            return Unmanaged.passUnretained(cgEvent)
        }

        guard type == systemDefinedEventType else {
            return Unmanaged.passUnretained(cgEvent)
        }

        guard let nsEvent = NSEvent(cgEvent: cgEvent) else {
            return Unmanaged.passUnretained(cgEvent)
        }
        guard nsEvent.subtype.rawValue == 8 else {
            return Unmanaged.passUnretained(cgEvent)
        }

        let data1 = nsEvent.data1
        let keyCode = Int32((data1 & 0xFFFF_0000) >> 16)
        let keyFlags = data1 & 0x0000_FFFF
        let keyState = (keyFlags & 0xFF00) >> 8
        let isKeyDown = keyState == 0x0A

        let command: MediaCommand?
        switch keyCode {
        case NX_KEYTYPE_PLAY:
            command = .playPause
        case NX_KEYTYPE_NEXT, NX_KEYTYPE_FAST:
            command = .next
        case NX_KEYTYPE_PREVIOUS, NX_KEYTYPE_REWIND:
            command = .previous
        default:
            command = nil
        }

        guard let command else {
            return Unmanaged.passUnretained(cgEvent)
        }

        if isKeyDown {
            tap.handler?(command)
        }

        // consume the event so Music.app / rcd never receive it
        return nil
    }
}

enum MediaKeyTapError: Error {
    case creationFailed
}
