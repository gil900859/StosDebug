//
//  DeviceError.swift
//  StosDebug
//
//  Created by Stossy11 on 31/3/2026.
//

import Foundation

enum DeviceError: LocalizedError, Equatable {
    case success
    case loading
    case none
    case notMounted
    case failure(issue: String)
    
    var isFailure: Bool {
        switch self {
        case .failure:
            return true
        default:
            return false
        }
    }
    
    var failureReason: String? {
        switch self {
        case .failure(issue: let issue):
            return issue
        default:
            return nil
        }
    }
}
