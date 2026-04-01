//
//  JITSupport.swift
//  StosDebug
//
//  Created by Stossy11 on 28/3/2026.
//

import Foundation
import JavaScriptCore

func handleJSContextSendDebugCommand(
    context: JSContext,
    commandStr: String,
    debugProxy: DebugProxyHandle?
) -> String? {
    
    guard let cString = commandStr.cString(using: .utf8) else { return nil }
    
    let command = debugserver_command_new(cString, nil, 0)
    
    var attachResponse: UnsafeMutablePointer<CChar>? = nil
    let err = debug_proxy_send_command(debugProxy, command, &attachResponse)
    
    debugserver_command_free(command)
    
    if let err = err {
        let message = String(cString: err.pointee.message)
        context.exception = JSValue(
            object: "error code \(err.pointee.code), msg \(message)",
            in: context
        )
        idevice_error_free(err)
        return nil
    }
    
    var commandResponse: String? = nil
    if let response = attachResponse {
        commandResponse = String(cString: response)
    }
    
    idevice_string_free(attachResponse)
    return commandResponse
}

// 0 <= val <= 15
func u8toHexChar(_ val: UInt8) -> CChar {
    if val < 10 {
        return CChar(val + 48) // '0' = 48
    } else {
        return CChar(val + 87) // 'a' - 10
    }
}

func calcAndWriteCheckSum(_ commandStart: UnsafeMutablePointer<CChar>) {
    var sum: UInt8 = 0
    var cur = commandStart

    while cur.pointee != 35 { // '#' = 35
        sum &+= UInt8(bitPattern: cur.pointee)
        cur = cur.advanced(by: 1)
    }

    cur.advanced(by: 1).pointee = u8toHexChar((sum & 0xf0) >> 4)
    cur.advanced(by: 2).pointee = u8toHexChar(sum & 0x0f)
}

// support up to 9 digit
func writeAddress(_ writeStart: UnsafeMutablePointer<CChar>, _ addr: UInt64) {
    writeStart[0] = u8toHexChar(UInt8((addr & 0xf00000000) >> 32))
    writeStart[1] = u8toHexChar(UInt8((addr & 0xf0000000) >> 28))
    writeStart[2] = u8toHexChar(UInt8((addr & 0xf000000) >> 24))
    writeStart[3] = u8toHexChar(UInt8((addr & 0xf00000) >> 20))
    writeStart[4] = u8toHexChar(UInt8((addr & 0xf0000) >> 16))
    writeStart[5] = u8toHexChar(UInt8((addr & 0xf000) >> 12))
    writeStart[6] = u8toHexChar(UInt8((addr & 0xf00) >> 8))
    writeStart[7] = u8toHexChar(UInt8((addr & 0xf0) >> 4))
    writeStart[8] = u8toHexChar(UInt8(addr & 0xf))
}

// you need to free generated buffer
func getBulkMemWriteCommand(
    startAddr: UInt64,
    JITPagesSize: UInt64,
    commandCountOut: UnsafeMutablePointer<UInt32>,
    bufferLengthOut: UnsafeMutablePointer<UInt32>
) -> UnsafeMutablePointer<CChar>? {

    let commandCount = UInt32(JITPagesSize >> 14)
    let commandBufferSize = commandCount * 19

    commandCountOut.pointee = commandCount
    bufferLengthOut.pointee = commandBufferSize

    guard let buffer = malloc(Int(commandBufferSize + 1))?.assumingMemoryBound(to: CChar.self) else {
        return nil
    }

    let bufferEnd = buffer.advanced(by: Int(commandBufferSize))
    buffer[Int(commandBufferSize)] = 0

    var curAddr = startAddr
    var curPtr = buffer

    while curPtr < bufferEnd {
        curPtr[0]  = 36  // '$'
        curPtr[1]  = 77  // 'M'
        curPtr[11] = 44  // ','
        curPtr[12] = 49  // '1'
        curPtr[13] = 58  // ':'
        curPtr[14] = 54  // '6'
        curPtr[15] = 57  // '9'
        curPtr[16] = 35  // '#'

        writeAddress(curPtr.advanced(by: 2), curAddr)
        calcAndWriteCheckSum(curPtr.advanced(by: 1))

        curAddr += 16384
        curPtr = curPtr.advanced(by: 19)
    }

    return buffer
}

func handleJITPageWrite(
    context: JSContext,
    startAddr: UInt64,
    JITPagesSize: UInt64,
    debugProxy: DebugProxyHandle?
) -> String? {
    
    var bufferLength: UInt32 = 0
    var commandCount: UInt32 = 0
    
    guard let commandBuffer = getBulkMemWriteCommand(
        startAddr: startAddr,
        JITPagesSize: JITPagesSize,
        commandCountOut: &commandCount,
        bufferLengthOut: &bufferLength
    ) else {
        return nil
    }
    
    defer { free(commandBuffer) }
    
    var curCommand: UInt32 = 0
    
    while curCommand < commandCount {
        let remaining = commandCount - curCommand
        let commandsToSend = remaining > 1024 ? 1024 : remaining
        
        let err = debug_proxy_send_raw(
            debugProxy,
            UnsafePointer<UInt8>(OpaquePointer(commandBuffer.advanced(by: Int(curCommand * 19)))),
            UInt(commandsToSend) * 19
        )
        
        if let err = err {
            let message = String(cString: err.pointee.message)
            context.exception = JSValue(
                object: "error code \(err.pointee.code), msg \(message)",
                in: context
            )
            idevice_error_free(err)
            return nil
        }
        
        for _ in 0..<commandsToSend {
            var response: UnsafeMutablePointer<CChar>? = nil
            let err = debug_proxy_read_response(debugProxy, &response)
            
            if let response = response {
                idevice_string_free(response)
            }
            
            if let err = err {
                let message = String(cString: err.pointee.message)
                context.exception = JSValue(
                    object: "error code \(err.pointee.code), msg \(message)",
                    in: context
                )
                idevice_error_free(err)
                return nil
            }
        }
        
        curCommand += commandsToSend
    }
    
    return "OK"
}
