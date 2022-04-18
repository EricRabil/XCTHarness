import Foundation

/**
 Bootstraps the XCTest runtime for use in a test host whose testing environment does not align with Cupertino.
 */
public class XCTHarness {
    private typealias XCTestMainType = @convention(c) (_ something: AnyObject?) -> ()

    private static func dlsymcast<T>(_ handle: UnsafeMutableRawPointer!, _ symbol: UnsafePointer<CChar>) -> T! {
        dlsym(handle, symbol).map {
            if T.self is AnyObject.Type {
                return $0 as! T
            } else {
                return unsafeBitCast($0, to: T.self)
            }
        }
    }
    
    /** sanity check for troubleshooting, if this is missing we are most likely being invoked manually and whoever invoked us forgot something */
    private static let isTestSession = ProcessInfo.processInfo.environment.keys.contains("XCTestSessionIdentifier")
    
    /**
     The absolute search path to use when weak-linking against Xcode-native frameworks
     
     The `LD_LIBRARY_PATH` environment variable is normally passed by Xcode so that tooling can use the frameworks corresponding to the host Xcode version.
     */
    private static let libraryPath = ProcessInfo.processInfo.environment["LD_LIBRARY_PATH"].map(URL.init(fileURLWithPath:))

    /**
     The resolved path to XCTestCore.framework, using the `libraryPath` as the base
     
     ```
     /Applications/Xcode-13.3.1.app/Contents/Developer/../SharedFrameworks/XCTestCore.framework/Versions/Current/XCTestCore
     ```
     */
    private static let XCTestCorePath = libraryPath?.appendingPathComponent("XCTestCore.framework/Versions/Current/XCTestCore").path
    
    /**
     The return value of `dlopen(XCTestCorePath, RTLD_LAZY)`
     */
    private static let XCTestCore = XCTestCorePath.flatMap { dlopen($0, RTLD_LAZY) }
    
    /**
     The resolved path to XCTest.framework, using the `libraryPath` as the base
     
     ```
     /Applications/Xcode-13.3.1.app/Contents/Developer/../SharedFrameworks/XCTest.framework/Versions/Current/XCTest
     ```
     */
    private static let XCTestPath = libraryPath?.appendingPathComponent("XCTest.framework/Versions/Current/XCTest").path
    
    /**
     The return value of `dlopen(XCTestPath, RTLD_LAZY)`
     */
    private static let XCTest = XCTestPath.flatMap { dlopen($0, RTLD_NOW) }
    
    /**
     A weak link to the `_XCTestMain` function responsible for bootstraping XCTest
     */
    private static let XCTestMain = XCTestCore.flatMap { dlsymcast($0, "_XCTestMain") as XCTestMainType? }
    
    /**
     A path relative to the main bundle path pointing to the `.xctest` bundle to be loaded.
     
     The `XCTestBundlePath` environment variable is normally passed by Xcode when running a test with a test host.
     */
    private static let XCTestBundlePath = ProcessInfo.processInfo.environment["XCTestBundlePath"]
    
    /**
     The bundle corresponding to the `.xctest` bundle to be loaded.
     */
    private static let XCTestBundle = XCTestBundlePath.flatMap { Bundle(url: Bundle.main.bundleURL.appendingPathComponent($0)) }
    
    /**
     Bootstraps the XCTest runtime for use in a test host whose testing environment does not align with Cupertino.
     */
    public static func forceStartTestSession() {
        if !XCTHarness.isTestSession {
            print("Missing XCTestSessionIdentifier, things might not work. I don't think I'm where I'm supposed to be.")
        }
        guard let _ = XCTHarness.XCTest else {
            guard let XCTestPath = XCTHarness.XCTestPath else {
                fatalError("Missing LD_LIBRARY_PATH! Xcode inserts this automatically when running a test host, are you Xcode? What's up buddy?")
            }
            fatalError("Couldn't find XCTest.framework, expected it at \(XCTestPath)")
        }
        guard let XCTestBundle = XCTHarness.XCTestBundle else {
            guard let XCTestBundlePath = XCTHarness.XCTestBundlePath else {
                fatalError("Missing XCTestBundlePath! Xcode inserts this automatically when running a test host, are you Xcode? What's up buddy?")
            }
            fatalError("Couldn't find XCTestBundle, expected it at \(XCTestBundlePath)")
        }
        guard XCTestBundle.load() else {
            fatalError("Can't load xctest bundle at \(XCTHarness.XCTestBundlePath!)")
        }
        guard let XCTestMain = XCTHarness.XCTestMain else {
            fatalError("Can't find _XCTestMain inside \(XCTestCorePath!), I fear DVT has bamboozled us.")
        }
        XCTestMain(nil)
    }
}
