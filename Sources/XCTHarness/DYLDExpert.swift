//
//  DYLDExpert.swift
//  
//
//  Created by Eric Rabil on 4/17/22.
//

import Foundation

/**
 Scans loaded dyld images for a specific image and subsequent condition before invoking a closure.
 */
public class DYLDExpert {
    private class DYLDBinding {
        static var callbacks: [AnyHashable: (UnsafePointer<mach_header>, intptr_t) -> Void] = [:]
        static let once: () = {
            _dyld_register_func_for_add_image({ header, slide in
                guard let header = header else {
                    return
                }
                for callback in DYLDBinding.callbacks.values {
                    callback(header, slide)
                }
            })
        }()
    }
    
    /**
     Creates an expert that uses the provided arguments to determine when an ObjC image is fully loaded. The last argument, `fire`, is invoked once `isLibrary` has returned true at least once and `isReady` returns true.
     
     A use case is when you want to swizzle an Objective-C method in a lazily loaded image.
     
     - Parameter isLibrary: A closure that returns true if an absolute path represents the image being waited for.
     - Parameter isReady: A closure that returns true if and only if the desired image has been loaded into Objective-C.
     - Parameter fire: A closure that is invoked once (and only once), after `isLibrary` and `isReady` have returned true.
     */
    public init(isLibrary: @escaping (UnsafePointer<CChar>) -> Bool, isReady: @escaping @autoclosure () -> Bool, fire: @escaping () -> ()) {
        self.isLibrary = isLibrary
        self.isReady = isReady
        self.fire = fire
        DYLDBinding.callbacks[ObjectIdentifier(self)] = { [weak self] header, ptr in
            guard let self = self, !self.fired else {
                return
            }
            let count = _dyld_image_count()
            while !self.sawLibrary && self.position < count {
                defer { self.position += 1 }
                guard let name = _dyld_get_image_name(self.position) else {
                    continue
                }
                if self.isLibrary(name) {
                    self.sawLibrary = true
                }
            }
            if self.sawLibrary && !self.fired && self.isReady() {
                DYLDBinding.callbacks.removeValue(forKey: ObjectIdentifier(self))
                self.fire()
                self.fired = true
                self.unwound = true
            }
        }
        _ = DYLDBinding.once
    }
    
    private var unwound = false
    deinit {
        if !unwound {
            DYLDBinding.callbacks.removeValue(forKey: ObjectIdentifier(self))
        }
    }
    
    /**
     Determines whether the given image path is the image we are waiting for
     */
    public var isLibrary: (UnsafePointer<CChar>) -> Bool
    
    /**
     Determines whether the given image has been loaded into Objective-C.
     
     ```
     NSClassFromString("SomeClass") != nil
     ```
     */
    public var isReady: () -> Bool
    
    /**
     A callback to be invoked once `isLibrary` and `isReady` have returned true.
     */
    public var fire: () -> ()
    
    /**
     Whether `isLibrary` has returned true at least once
     */
    public private(set) var sawLibrary = false
    
    /**
     Whether `isReady` has returned true and `fire` was subsequently invoked.
     */
    public private(set) var fired = false
    
    /**
     The most recent image position, used when scanning
     */
    private var position: UInt32 = 0
}
