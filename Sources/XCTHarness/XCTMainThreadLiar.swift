//
//  XCTMainThreadLiar.swift
//  
//
//  Created by Eric Rabil on 4/17/22.
//

import Foundation

// i wont tell if you wont.
@_silgen_name("dispatch_get_current_queue")
func dispatch_get_current_queue() -> Unmanaged<DispatchQueue>

extension UnsafePointer where Pointee == CChar {
    func starts(with possiblePrefifx: String) -> Bool {
        strncmp(self, possiblePrefifx, possiblePrefifx.count) == 0
    }
    
    func hasSuffix(_ suffix: String) -> Bool {
        let suffixlen = suffix.count
        return strncmp(self.advanced(by: strlen(self) - suffixlen), suffix, suffixlen) == 0
    }
}

public class XCTMainThreadLiar {
    private static let XCTQueue = DispatchQueue(label: "Liar", qos: .utility)
    
    /**
     Wraps `+[NSThread isMainThread]` with a function that unconditionally returns true when running on the liar queue, otherwise returning the original implementation.
     */
    private lazy var swizzleNSThreadOnce: ()? = EXCTSwizzler.SwizzleVoidBoolean(cls: Thread.self, name: "isMainThread", swizzled: swizzledIsMainThread)?.apply()
    
    /**
     The DYLDExpert powering our lies
     
     - Searches for a library starting with `/Applications`, we search for an image path ending in `/XCTestCore`
     - Waits for `XCTestObservationCenter` to become a realized class
     - Wraps `removeTestObserver:` and `addTestObserver:` with `self.swizzledRemove` and `self.swizzledAdd` respectively
     */
    private lazy var expert: DYLDExpert = DYLDExpert(isLibrary: { name in
        name.starts(with: "/Applications") && name.hasSuffix("/XCTestCore")
    }, isReady: NSClassFromString("XCTestObservationCenter") != nil, fire: {
        guard let cls = NSClassFromString("XCTestObservationCenter") else {
            return
        }
        EXCTSwizzler.SwizzleSingleVoid(cls: cls, name: "removeTestObserver:", swizzled: self.swizzledRemove)?.apply()
        EXCTSwizzler.SwizzleSingleVoid(cls: cls, name: "addTestObserver:", swizzled: self.swizzledAdd)?.apply()
    })
    
    /** The ObjC Method corresponding to`+[NSThread isMainThread]` */
    private var isMainThread: Method?
    
    /** The ObjC Method corresponding to `-[XCTestObservationCenter removeTestObserver:]` */
    private var removeTestObserver: Method?
    /** The ObjC Method corresponding to `-[XCTestObservationCenter addTestObserver:]` */
    private var addTestObserver: Method?
    /** The original function corresponding to `+[NSThread isMainThread]`*/
    private var originalIsMainThread: EXCTSwizzler.ZeroArgumentBooleanDispatch = { _,_ in false }
    /** The original function corresponding to `[-[XCTestObservationCenter removeTestObserver:]` */
    private var originalRemove: EXCTSwizzler.SingleArgumentDispatch = { _,_,_ in }
    /** The original function corresponding to `-[XCTestObservationCenter addTestObserver:]`*/
    private var originalAdd: EXCTSwizzler.SingleArgumentDispatch = { _,_,_ in }
    
    /** The liar */
    public static let shared = XCTMainThreadLiar()
    private init() {}
    
    /** The swizzled `isMainThread` that returns true when on the liar queue */
    private let swizzledIsMainThread: EXCTSwizzler.ZeroArgumentBooleanDispatch = { `self`, sel in
        if dispatch_get_current_queue().takeUnretainedValue() == XCTQueue {
            return true
        }
        return XCTMainThreadLiar.shared.originalIsMainThread(self, sel)
    }
    
    /** The swizzled `removeTestObserver:` that invokes the original imp on the liar queue`*/
    private let swizzledRemove: EXCTSwizzler.SingleArgumentDispatch = { _self, sel, arg3 in
        XCTQueue.sync {
            XCTMainThreadLiar.shared.originalRemove(_self, sel, arg3)
        }
    }
    
    /** The swizzled `addTestObserver:` that invokes the original imp on the liar queue*/
    private let swizzledAdd: EXCTSwizzler.SingleArgumentDispatch = { _self, sel, arg3 in
        XCTQueue.sync {
            XCTMainThreadLiar.shared.originalAdd(_self, sel, arg3)
        }
    }
    
    /**
     Performs first-time setup the first time this method is called.
     
     Swizzles NSThread.isMainThread to return true if we are currently on the "liar" queue.
     Swizzles target methods to invoke the original methods within this liar queue.
     
     This is to retarget methods that expect to be on the main thread, while still ensuring synchronized access to the underlying resource.
     */
    public func setup() {
        _ = swizzleNSThreadOnce
        _ = expert
    }
}
