//
//  Log.swift
//  ARCApp
/

import Foundation
import AppleRawConverter

class RAWConverterLogger: RawConverterLoggerProtocol {
    public init(logLevel: LoggerLevel = .verbose) {self.logLevel = logLevel}
    
    public var logLevel: LoggerLevel
    
    public func error<T>(_ closure: @autoclosure () -> T) {
        Log.error(closure)
    }
    
    public func verbose<T>(_ closure: @autoclosure () -> T) {
        Log.verbose(closure)
    }
    
    public func info<T>(_ closure: @autoclosure () -> T) {
        Log.info(closure)
    }
    
    public func warn<T>(_ closure: @autoclosure () -> T) {
        Log.warn(closure)
    }
    
    public func severe<T>(_ closure: @autoclosure () -> T) {
        Log.severe(closure)
    }
    
    public func debug<T>(_ closure: @autoclosure () -> T) {
        Log.debug(closure)
    }
}

public enum LogError: Error {
    case failedToGetAppleRawParameters(String)
}

// adapted from: https://stackoverflow.com/questions/41680004/redirect-nslog-to-file-in-swift-not-working
func redirectstderrToFile(to dstLog: URL) {
    dstLog.withUnsafeFileSystemRepresentation {
        _ = freopen($0, "a+", stderr)
    }
}

// adapted from: https://stackoverflow.com/questions/44537133/how-to-write-application-logs-to-file-and-get-them
struct TextLog: TextOutputStream {
    
    var logFile: URL = URL(string: "")!
    
    mutating func setLogFile(with file: URL) {
        logFile = file
    }
    
    /// Appends the given string to the stream.
    mutating func write(_ string: String) {
        
        do {
            let handle = try FileHandle(forWritingTo: logFile)
            handle.seekToEndOfFile()
            handle.write(string.data(using: .utf8)!)
            handle.closeFile()
        } catch {
            print(error.localizedDescription)
            do {
                try string.data(using: .utf8)?.write(to: logFile)
            } catch {
                print(error.localizedDescription)
            }
        }
        
    }
    
}

func printTimestamp() -> String {
    let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
    return timestamp
}
