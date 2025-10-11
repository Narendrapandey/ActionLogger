//
//  RecordingManager.swift
//  ActionLogger
//
//  Created by Priyanka Pandey on 11/10/25.
//


import SwiftUI
import ZipArchive
import os
import Foundation

public actor RecordingManager {
    
    // MARK: - Singleton
    static let shared = RecordingManager()
    private let logger = Logger(subsystem: "com.ActionLogger.spm", category: "ActionLogger")
    
    // MARK: - Properties
    private let fileManager = FileManager.default
    private let baseURL: URL
    
    private let baseFolderName = "Recording"
    private let subfolders = ["Responses", "View Controllers", "Database Logs", "UITests"]
    
    init() {
        self.baseURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent(baseFolderName)
        Task { await createBaseDirectories() }
    }
    
    private var formatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH:mm:ss.SSS"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }
    
    
    private nonisolated func log(_ message: String, type: OSLogType) {
        logger.log(level: type, "\(message)")
    }
    
    // MARK: - Setup
    private func createBaseDirectories() {
        for folder in subfolders {
            let directory = baseURL.appendingPathComponent(folder)
            if !fileManager.fileExists(atPath: directory.path) {
                try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            }
        }
        log("App Recording Directory: \(baseURL.path)", type: .debug)
    }
    
    // MARK: - Helpers
    private func timestamp() -> String {
        formatter.string(from: Date())
    }
    
    private func write(_ content: String, to folder: String, named filename: String) {
        let fileURL = baseURL.appendingPathComponent("\(folder)/\(filename)")
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            log("Failed to write file: \(error.localizedDescription)", type: .error)
        }
    }
}

// MARK: - API Logging
extension RecordingManager {
    private func ensureFolderExists(_ folder: String) -> URL {
        let directory = baseURL.appendingPathComponent(folder)
        if !FileManager.default.fileExists(atPath: directory.path) {
            do {
                try FileManager.default.createDirectory(
                    at: directory,
                    withIntermediateDirectories: true
                )
                log("Created folder: \(directory.path)", type: .debug)
            } catch {
                log("Failed to create folder \(folder): \(error.localizedDescription)", type: .error)
            }
        }
        return directory
    }
    
    private func safeFilename(_ apiName: String) -> String {
        var safe = apiName
        // Replace any characters that are illegal in filenames
        let illegalChars = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        safe = safe.components(separatedBy: illegalChars).joined(separator: "_")
        return safe
    }
    
    public func logResponse(
        _ apiName: String,
        parameters: [String: Any]?,
        requestTime: Date,
        headers: [String: String]?,
        response: Any?,
        responseDate: Date,
        statusCode: Int
    ) {
        // Ensure Responses folder exists
        let folderURL = ensureFolderExists("Responses")
        let safeApiName = safeFilename(apiName)
        let filename = "\(timestamp())_\(safeApiName).txt"
        let fileURL = folderURL.appendingPathComponent(filename)
        
        // Date formatter for milliseconds precision
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        let requestTimestamp = formatter.string(from: requestTime)
        let responseTimestamp = formatter.string(from: responseDate)
        let duration = responseDate.timeIntervalSince(requestTime)
        
        // Duration in seconds with 3 decimal places
        let durationString = String(format: "%.3f seconds", duration)
        
        // Start composing log
        var content = """
        API: \(apiName)
        Status Code: \(statusCode)
        
        Request Time: \(requestTimestamp)
        Response Time: \(responseTimestamp)
        Duration: \(durationString)
        
        """
        
        // Log headers
        if let headers = headers {
            if let jsonData = try? JSONSerialization.data(withJSONObject: headers, options: .prettyPrinted),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                content += "\nHeaders:\n\(jsonString)\n"
            } else {
                content += "\nHeaders:\n\(headers)\n"
            }
        }
        
        // Mask sensitive parameters
        var sanitizedParams = parameters ?? [:]
        let sensitiveKeys = ["password", "old_password", "new_password"]
        for key in sensitiveKeys where sanitizedParams.keys.contains(key) {
            sanitizedParams[key] = "***"
        }
        
        // Log parameters
        if !sanitizedParams.isEmpty {
            if let jsonData = try? JSONSerialization.data(withJSONObject: sanitizedParams, options: .prettyPrinted),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                content += "\nParameters:\n\(jsonString)\n"
            } else {
                content += "\nParameters:\n\(sanitizedParams)\n"
            }
        }
        
        // Log response
        if let response = response {
            content += "\nResponse:\n"
            if JSONSerialization.isValidJSONObject(response) {
                if let jsonData = try? JSONSerialization.data(withJSONObject: response, options: .prettyPrinted),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    content += "\(jsonString)\n"
                } else {
                    content += "\(response)\n"
                }
            } else {
                content += "\(response)\n"
            }
        }
        
        // Write to file
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            log("Response logged at: \(fileURL.path)", type: .debug)
            
        } catch {
            log("Failed to log response: \(error.localizedDescription)", type: .error)
        }
    }
    
    public func logDatabaseResponse(dbName: String, predicate: NSPredicate?, limit: Int?, count: Int, response: Any?) {
        let folderURL = ensureFolderExists("Database Logs")
        let safeDbName = safeFilename(dbName)
        let filename = "\(timestamp())_\(safeDbName).txt"
        let fileURL = folderURL.appendingPathComponent(filename)
        
        var content = "Timestamp: \(Date())\nDatabase: \(dbName)\n"
        content += "Records Found: \(count)\n"
        
        if let limit = limit {
            content += "Limit: \(limit)\n"
        }
        
        content += "Predicate: \(predicate?.predicateFormat ?? "None")\n\n"
        
        if let response = response {
            if let jsonString = encodeToJSONString(response) {
                content += "Response (JSON):\n\(jsonString)\n\n"
            } else {
                content += "Response:\n\(response)\n\n"
            }
        }
        
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            log("Database log saved at: \(fileURL.path)", type: .debug)
        } catch {
            log("Failed to log database response: \(error.localizedDescription)", type: .error)
        }
    }
    
    private func encodeToJSONString(_ object: Any) -> String? {
        // Try to encode only if the object is Encodable
        if let encodable = object as? Encodable {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            do {
                let data = try encoder.encode(AnyEncodable(encodable))
                return String(data: data, encoding: .utf8)
            } catch {
                log("JSON Encoding failed: \(error.localizedDescription)", type: .error)
                return nil
            }
        }
        return nil
    }
}

struct AnyEncodable: Encodable {
    private let encodeClosure: (Encoder) throws -> Void
    
    init<T: Encodable>(_ wrapped: T) {
        encodeClosure = wrapped.encode
    }
    
    func encode(to encoder: Encoder) throws {
        try encodeClosure(encoder)
    }
}



// MARK: - App Actions
public extension RecordingManager {
    func logNavigation(_ description: String, title: String) {
        
        let content = """
        
        Timestamp: \(Date())
        Title: \(title)
        Action: \(description)
        -------------------------
        """
        
        writeAppend(content, to: "View Controllers", named: "ViewControllerLogs.txt")
    }
    
    
    func logUITestAction(viewType: ViewType, identifier: String, into: String? = nil) {
        let content = getCommandContent(for: viewType, identifier: identifier, into: into)
        writeAppend(content, to: "UITests", named: "UITestsLogs.txt")
    }
    
    private func writeAppend(_ content: String, to folder: String, named filename: String) {
        let folderURL = ensureFolderExists(folder)
        let fileURL = folderURL.appendingPathComponent(filename)
        
        // If file exists → append, else → create
        if FileManager.default.fileExists(atPath: fileURL.path) {
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                handle.seekToEndOfFile()
                if let data = content.data(using: .utf8) {
                    handle.write(data)
                    handle.closeFile()
                }
            }
        } else {
            try? content.write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }
}

// MARK: - Export as ZIP
public extension RecordingManager {
    
    func exportAllRecordings(from viewController: UIViewController, password: String? = nil) async {
        let zipURL = baseURL.appendingPathExtension("zip")
        
        // Remove old zip if it exists
        try? fileManager.removeItem(at: zipURL)
        
        let success: Bool
        if let password = password {
            // Create password-protected ZIP
            success = SSZipArchive.createZipFile(
                atPath: zipURL.path,
                withContentsOfDirectory: baseURL.path,
                withPassword: password
            )
        } else {
            // Create normal ZIP
            success = SSZipArchive.createZipFile(
                atPath: zipURL.path,
                withContentsOfDirectory: baseURL.path
            )
        }
        
        await MainActor.run {
            if success {
                let activityVC = UIActivityViewController(activityItems: [zipURL], applicationActivities: nil)
                viewController.present(activityVC, animated: true)
            } else {
                log("Failed to create ZIP file", type: .error)
            }
        }
        
    }
}


public extension RecordingManager {
    
    enum ViewType: String, CaseIterable {
        case Shape
        case DatePicker
        case Checkbox
        case Picker
        case Button
        case TextEditor
        case TextField
        case secureTextField
        case Image
        case Slider
        case Stepper
        case Toggle
        case Text
        case Menu
    }
    
    private func getCommandContent(for viewType: ViewType, identifier: String, into: String? = nil) -> String {
        
        switch viewType {
            
        case .Button, .Image, .Text, .Menu, .Shape, .Stepper:
            return "app.tap(\"\(identifier)\")\n"
            
        case .Slider:
            return "app.adjustSlider()\n"
            
        case .Toggle:
            return "app.toggle(\"\(identifier)\")\n"
            
        case .TextField, .TextEditor, .secureTextField:
            return "app.type(\"\(into ?? "")\", text: \"\(identifier)\")\n"
            
        default:
            return "app.tap(\"\(identifier)\")\n"
        }
    }
}
