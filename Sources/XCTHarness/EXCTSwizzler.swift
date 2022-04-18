//
//  File.swift
//  
//
//  Created by Eric Rabil on 4/17/22.
//

import Foundation

public struct EXCTSwizzler {
    public typealias SingleArgumentDispatch = @convention(c) (NSObjectProtocol, Selector, NSObjectProtocol) -> Void
    public typealias ZeroArgumentBooleanDispatch = @convention(c) (NSObjectProtocol, Selector) -> NSNumber

    /** Only use this with a `@convention(c)` function or else */
    public struct _SwizzleStorage<P> {
        var method: Method?
        var original: P?
        var swizzled: P?
        
        init?(cls: AnyClass, name: String, swizzled: P) {
            guard let method = class_getInstanceMethod(cls, Selector(name)) else {
                return nil
            }
            self.method = method
            self.original = unsafeBitCast(method_getImplementation(method), to: P.self)
            self.swizzled = swizzled
            method_setImplementation(method, unsafeBitCast(swizzled, to: IMP.self))
        }
        
        func apply() {
            if let method = method, let swizzled = swizzled {
                method_setImplementation(method, unsafeBitCast(swizzled, to: IMP.self))
            }
        }
    }

    public typealias SwizzleSingleVoid = _SwizzleStorage<SingleArgumentDispatch>
    public typealias SwizzleVoidBoolean = _SwizzleStorage<ZeroArgumentBooleanDispatch>
}
