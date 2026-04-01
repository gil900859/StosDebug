//
//  DeviceInfo.swift
//  StosDebug
//
//  Created by Stossy11 on 29/3/2026.
//

import Foundation
import UIKit

typealias MGCopyAns = @convention(c) (CFString?) -> Unmanaged<CFPropertyList>?

let kMGPhysicalHardwareNameString = "PhysicalHardwareNameString" as CFString

fileprivate let mgCopyAnswer: MGCopyAns? = {
    let mobileGestalt = dlopen("/usr/lib/libMobileGestalt.dylib", RTLD_LAZY)
    
    let mgCopyAnser = dlsym(mobileGestalt, "MGCopyAnswer")
    
    return unsafeBitCast(mgCopyAnser, to: MGCopyAns.self)
}()


public extension UIDevice {
    static let modelName: String = {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }

        return mgCopyAnswer?(kMGPhysicalHardwareNameString)?.takeUnretainedValue() as? String ?? identifier
    }()
}


