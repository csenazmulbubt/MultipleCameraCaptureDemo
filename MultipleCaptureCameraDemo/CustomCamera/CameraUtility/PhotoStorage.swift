//
//  CIAsset.swift
//  MultipleCaptureCameraDemo
//
//  Created by Nazmul on 15/08/2022.
//

import Foundation
import UIKit

class PhotoStorage {
    private let queue = DispatchQueue(label: "com.matrix.nazmul.disk-cache-writes", attributes: [])
    
    private let baseURL: URL
    private let resizeQueue = DispatchQueue(label: "com.matrix.nazmul.disk-cache-resizes", attributes: .concurrent)
    private let fileManager = FileManager()
    
    init() {
        var cacheURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).last!
        cacheURL = cacheURL.appendingPathComponent("com.matrix.nazmul.disk-cache")
        baseURL = cacheURL.appendingPathComponent(NSUUID().uuidString)
    }
    
    func createAssetFromImageData(_ data: Data, completion: @escaping (URL) -> Void) {
        autoreleasepool {
            queue.async { [weak self] in
                guard let self = self else { return }
                
                var image = UIImage(data: data)
                
                DispatchQueue.main.async {
                    image = image?.fixImageOrientation()
                }
                if let imgData = image?.jpegData(compressionQuality: 1.0){
                    
                    let id = self.generateCurrentTimeStamp()
                    let cacheURL = self.cacheURLForAsset(id)
                    var error: NSError?
                    do {
                        try imgData.write(to: URL(fileURLWithPath: cacheURL.path), options: .atomic)
                    } catch let error1 as NSError {
                        error = error1
                        NSLog("Failed to write image to \(cacheURL): \(String(describing: error))")
                    } catch {
                        fatalError()
                    }
                    DispatchQueue.main.async {
                        completion(cacheURL)
                    }
                }
            }
        }
    }
    
    func deleteAsset(_ asset: URL, completion: @escaping () -> Void) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            let cacheURL = asset
            var error: NSError?
            do {
                try self.fileManager.removeItem(atPath: cacheURL.path)
            } catch let error1 as NSError {
                error = error1
                NSLog("failed failed to remove asset at \(cacheURL): \(String(describing: error))")
            } catch {
                fatalError()
            }
            DispatchQueue.main.async(execute: completion)
        }
    }
    
    private func cacheURLForAsset(_ asset: String) -> URL {
        ensureCacheDirectoryExists()
        return baseURL.appendingPathComponent(asset)
    }
    
    private func ensureCacheDirectoryExists() {
        if !fileManager.fileExists(atPath: baseURL.path) {
            var error: NSError?
            do {
                try fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true, attributes: nil)
            } catch let error1 as NSError {
                error = error1
                NSLog("Failed to create cache directory at \(baseURL): \(String(describing: error))")
            }
        }
    }
    
    private func generateCurrentTimeStamp () -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy_MM_dd_hh_mm_ss"
        return (formatter.string(from: Date()) as NSString) as String
    }
    
}

private extension UIImage{
    //Capture image fix orientation
    func fixImageOrientation() -> UIImage {
        autoreleasepool {
            UIGraphicsBeginImageContext(self.size)
            self.draw(at: .zero)
            let newImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return newImage ?? self
        }
    }
}
