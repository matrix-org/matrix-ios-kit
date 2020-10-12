/*
 Copyright 2020 The Matrix.org Foundation C.I.C
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import Foundation
import MatrixSDK

@objcMembers
public class SyncResponseFileStore: NSObject {
    
    private enum SyncResponseFileStoreConstants {
        static let folderNname = "SyncResponse"
        static let fileName = "syncResponse"
        static let fileEncoding: String.Encoding = .utf8
        static let fileOperationQueue: DispatchQueue = .global(qos: .default)
    }
    private var filePath: URL!
    private var credentials: MXCredentials!
    
    private func setupFilePath() {
        guard let userId = credentials.userId else {
            fatalError("Credentials must provide a user identifier")
        }
        var cachePath: URL!
        
        if let appGroupIdentifier = MXSDKOptions.sharedInstance().applicationGroupIdentifier {
            cachePath = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
        } else {
            cachePath = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        }
        
        filePath = cachePath
            .appendingPathComponent(SyncResponseFileStoreConstants.folderNname)
            .appendingPathComponent(userId)
            .appendingPathComponent(SyncResponseFileStoreConstants.fileName)
        
        SyncResponseFileStoreConstants.fileOperationQueue.async {
            try? FileManager.default.createDirectory(at: self.filePath.deletingLastPathComponent(),
                                                withIntermediateDirectories: true,
                                                attributes: nil)
        }
    }
    
    private func readSyncResponse() -> MXSyncResponse? {
        guard let filePath = filePath else {
            return nil
        }
        var fileContents: String?
        
        SyncResponseFileStoreConstants.fileOperationQueue.sync {
            fileContents = try? String(contentsOf: filePath,
                                       encoding: SyncResponseFileStoreConstants.fileEncoding)
        }
        guard let jsonString = fileContents else {
            return nil
        }
        guard let json = MXTools.deserialiseJSONString(jsonString) as? [AnyHashable: Any] else {
            return nil
        }
        return MXSyncResponse(fromJSON: json)
    }
    
    private func saveSyncResponse(_ syncResponse: MXSyncResponse?) {
        guard let filePath = filePath else {
            return
        }
        
        guard let syncResponse = syncResponse else {
            try? FileManager.default.removeItem(at: filePath)
            return
        }
        SyncResponseFileStoreConstants.fileOperationQueue.async {
            try? syncResponse.jsonString()?.write(to: self.filePath,
                                                  atomically: true,
                                                  encoding: SyncResponseFileStoreConstants.fileEncoding)
        }
    }
    
}

extension SyncResponseFileStore: SyncResponseStore {
    
    public func open(withCredentials credentials: MXCredentials) {
        self.credentials = credentials
        self.setupFilePath()
    }
    
    public var syncResponse: MXSyncResponse? {
        return readSyncResponse()
    }
    
    public func update(with response: MXSyncResponse?) {
        guard filePath != nil else {
            return
        }
        
        guard let response = response else {
            //  Return if no new response
            return
        }
        if let syncResponse = syncResponse {
            //  current sync response exists, merge it with the new response
            var dictionary = NSDictionary(dictionary: syncResponse.jsonDictionary())
            dictionary = dictionary + NSDictionary(dictionary: response.jsonDictionary())
            saveSyncResponse(MXSyncResponse(fromJSON: dictionary as? [AnyHashable : Any]))
        } else {
            //  no current sync response, directly save the new one
            saveSyncResponse(response)
        }
    }
    
    public func deleteData() {
        saveSyncResponse(nil)
    }
    
}
