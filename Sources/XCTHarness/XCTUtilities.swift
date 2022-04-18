//
//  XCTUtilities.swift
//  
//
//  Created by Eric Rabil on 4/17/22.
//

import Foundation
#if canImport(AppKit)
import AppKit
#endif

public struct XCTHarnessOptions: OptionSet, ExpressibleByIntegerLiteral {
    public var rawValue: UInt
    
    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }
    
    public init(integerLiteral value: RawValue) {
        self.rawValue = value
    }
    
    public init(_ value: RawValue) {
        rawValue = value
    }
}

public extension XCTHarnessOptions {
    static let none = XCTHarnessOptions(0)
    /** Bootstrap XCTest on a utility dispatch queue */
    static let async = XCTHarnessOptions(0 << 1)
    /** Override XCTest to run on another thread so that the main thread can be used for testing main thread logic */
    static let mainThreadLiar = XCTHarnessOptions(1 << 1)
    /** Starts a cocoa application on the current thread while the tests run */
    static let cocoa = XCTHarnessOptions(2 << 1)
}

/**
 Sets up xctest for use in a testing host
 
 - Parameter options
 */
public func XCTHarnessMain(_ options: XCTHarnessOptions = .none) {
    if options.contains(.mainThreadLiar) {
        XCTMainThreadLiar.shared.setup()
    }
    if options.contains(.async) {
        DispatchQueue.global(qos: .utility).async {
            XCTHarness.forceStartTestSession()
        }
    } else {
        XCTHarness.forceStartTestSession()
    }
    if options.contains(.cocoa) {
        #if canImport(AppKit)
        NSApplication.shared.run()
        #endif
    }
}
