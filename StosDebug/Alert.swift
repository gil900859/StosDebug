//
//  Alert.swift
//  SideStore
//
//  Created by Stossy11 on 07/12/2025.
//

import Foundation
import SwiftUI
import UIKit

extension Alert {
    static func topViewController() -> UIViewController? {
        guard let window = UIApplication.shared.windows.filter({ $0.isKeyWindow }).first else {
            return nil
        }
        
        var top = window.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
    
    @discardableResult
    static func showSyncAlert(
        title: String?,
        message: String?,
        actions: [String] = ["OK"],
        hasCancel: Bool = true,
        alertHandler: @escaping (String) -> Void
    ) -> UIAlertController? {
        
        guard let presenter = topViewController() else {
            fatalError("No Top Controller")
        }
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        for actionTitle in actions {
            alert.addAction(UIAlertAction(title: actionTitle, style: .default) { _ in
                alertHandler(actionTitle)
            })
        }
        
        if hasCancel {
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                alertHandler("Cancel")
            })
        }
        
        Task { @MainActor in
            presenter.present(alert, animated: true)
        }
        
        return alert
    }
    
    @MainActor
    static func showTextFieldAlert(
        title: String?,
        message: String?,
        default defaultText: String?,
        action: String = "OK",
    ) async -> String? {
        await withCheckedContinuation { continuation in
            guard let presenter = topViewController() else {
                continuation.resume(returning: "NoPresenter")
                return
            }
            
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addTextField()
            
            alert.textFields![0].text = defaultText
            
            alert.addAction(UIAlertAction(title: action, style: .default) { _ in
                let answer = alert.textFields![0]
                
                continuation.resume(returning: answer.text)
            })
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                continuation.resume(returning: defaultText)
            })
            
            presenter.present(alert, animated: true)
        }
    }
    
    @MainActor
    static func showAlert(
        title: String?,
        message: String?,
        actions: [String] = ["OK"],
        hasCancel: Bool = true
    ) async -> String {
        
        await withCheckedContinuation { continuation in
            guard let presenter = topViewController() else {
                continuation.resume(returning: "NoPresenter")
                return
            }
            
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            
            for actionTitle in actions {
                alert.addAction(UIAlertAction(title: actionTitle, style: .default) { _ in
                    continuation.resume(returning: actionTitle)
                })
            }
            
            if hasCancel {
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                    continuation.resume(returning: "Cancel")
                })
            }
            
            presenter.present(alert, animated: true)
        }
    }
}
