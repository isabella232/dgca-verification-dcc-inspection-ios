//
/*-
 * ---license-start
 * eu-digital-green-certificates / dgca-verifier-app-ios
 * ---
 * Copyright (C) 2021 T-Systems International GmbH and all other contributors
 * ---
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 * ---license-end
 */
//
//  RevocationCoreDataManager.swift
//  DCCRevocation
//
//  Created by Igor Khomiak on 04.01.2022.
//

import Foundation
import CoreData
import DGCCoreLibrary
import SwiftUI

public enum DataBaseError: Error {
    case nodata
    case loading
    case dataBaseError(error: NSError)
}

public typealias LoadingCompletion = ([NSManagedObject]?, DataBaseError?) -> Void

public class RevocationCoreDataManager: NSObject {
        
    public var managedContext: NSManagedObjectContext! = {
        return RevocationCoreDataStorage.shared.persistentContainer.viewContext
    }()

    
    // MARK: - Revocations
    public func clearAllData() {
        let fetchRequest = NSFetchRequest<Revocation>(entityName: "Revocation")
        
        do {
            let revocations = try managedContext.fetch(fetchRequest)
            print("Extracted \(revocations.count) Revocations for deleting")
            for revocationObject in revocations {
                let kidStr = revocationObject.value(forKey: "kid")
                managedContext.delete(revocationObject)
                print("Deleted Revocation \(kidStr ?? "")")
            }
            RevocationCoreDataStorage.shared.saveContext()
            
        } catch let error as NSError {
            print("Could not fetch Revocations for deleting: \(error.localizedDescription)")
            return
        } catch {
            print("Could not fetch Revocations for deleting.")
            return
        }
    }
    
    public func loadRevocation(kid: String) -> Revocation? {
        let fetchRequest = NSFetchRequest<Revocation>(entityName: "Revocation")
        let predicate: NSPredicate = NSPredicate(format: "kid == %@", argumentArray: [kid])
        fetchRequest.predicate = predicate
        
        do {
            var revocations = try managedContext.fetch(fetchRequest)
            print("  Extracted \(revocations.count) revocations for id: \(kid)")
            if revocations.count > 1 {
                while revocations.count > 1 {
                    revocations.removeLast()
                }
            }
            return revocations.first
            
        } catch let error as NSError {
            print("Could not fetch: \(error), \(error.userInfo) for id: \(kid)")
            return nil
        } catch {
            print("Could not fetch for id: \(kid)")
            return nil
        }
    }

    public func removeRevocation(kid: String) {
        let fetchRequest = NSFetchRequest<Revocation>(entityName: "Revocation")
        let predicate:  NSPredicate = NSPredicate(format: "kid == %@", argumentArray: [kid])
        fetchRequest.predicate = predicate
        
        do {
            let revocations = try managedContext.fetch(fetchRequest)
            print("Extracted \(revocations.count) Revocations for deleting")
            for revocationObject in revocations {
                managedContext.delete(revocationObject)
                print("Deleted Revocation \(kid)")
            }
            RevocationCoreDataStorage.shared.saveContext()
            
        } catch let error as NSError {
            print("Could not fetch Revocations for deleting: \(error.localizedDescription)")
            return
        } catch {
            print("Could not fetch Revocations for deleting.")
            return
        }
    }
    
    public func currentRevocations() -> [Revocation] {
        let fetchRequest = NSFetchRequest<Revocation>(entityName: "Revocation")
        do {
            let revocations = try managedContext.fetch(fetchRequest)
            print("== Extracted \(revocations.count) Revocations")
            return revocations
            
        } catch let error as NSError {
            print("Could not fetch Revocations: \(error.localizedDescription)")
            return []
        } catch {
            print("Could not fetch Revocations.")
            return []
        }
    }
    
    public func createAndSaveRevocations(_ models: [RevocationModel]) {
        for model in models {
            let kid = model.kid
             
            let entity = NSEntityDescription.entity(forEntityName: "Revocation", in: managedContext)!
            let revocation = Revocation(entity: entity, insertInto: managedContext)
            
            revocation.setValue(kid, forKey: "kid")
            let hashTypes = model.hashTypes.joined(separator: ",")
            revocation.setValue(hashTypes, forKey: "hashTypes")
            revocation.setValue(model.mode, forKey: "mode")
            
            if let expDate = Date(rfc3339DateTimeString: model.expires) {
                revocation.setValue(expDate, forKey: "expires")
            }
            if let lastUpdated = Date(rfc3339DateTimeString: model.lastUpdated) {
                revocation.setValue(lastUpdated, forKey: "lastUpdated")
            }
            print("-- Added Revocation with KID: \(kid)")
        }
        
        RevocationCoreDataStorage.shared.saveContext()
    }

    public func saveMetadataHashes(sliceHashes: [SliceMetaData]) {
        for dataSliceModel in sliceHashes {
            let kid =  dataSliceModel.kid
            guard let sliceObject = loadSlice(kid: kid, id: dataSliceModel.id,
                cid: dataSliceModel.cid, hashID: dataSliceModel.hashID) else { continue }
             
            let generatedData = dataSliceModel.contentData
            sliceObject.setValue(generatedData, forKey: "hashData")
        }

        RevocationCoreDataStorage.shared.saveContext()
    }

    public func deleteExpiredRevocations(for date: Date) {
        let fetchRequest = NSFetchRequest<Revocation>(entityName: "Revocation")
        let predicate:  NSPredicate = NSPredicate(format: "expires < %@", argumentArray: [date])
        fetchRequest.predicate = predicate
        do {
            let revocations = try managedContext.fetch(fetchRequest)
            revocations.forEach { managedContext.delete($0) }
            print("-- Deleted \(revocations.count) revocations for expiredDate: \(date)")
            
            RevocationCoreDataStorage.shared.saveContext()
 
        } catch let error as NSError {
            print("Could not fetch revocations. Error: \(error.localizedDescription) for expiredDate: \(date)")
            return
        } catch {
            print("Could not fetch revocations for expiredDate: \(date).")
            return
        }
    }

    // MARK: - Partitions

    public func savePartitions(kid: String, models: [PartitionModel]) {
        print("Start saving Partitions for kid: \(kid)")
        let revocation = loadRevocation(kid: kid)
        for model in models {
            let entity = NSEntityDescription.entity(forEntityName: "Partition", in: managedContext)!
            let partition = Partition(entity: entity, insertInto: managedContext)
            partition.setValue(kid, forKey: "kid")
            if let pid = model.id {
                partition.setValue(pid, forKey: "id")
            } else {
                partition.setValue("null", forKey: "id")
            }
            
            if let expDate = Date(rfc3339DateTimeString: model.expired) {
                partition.setValue(expDate, forKey: "expired")
            }
            
            if let updatedDate = Date(rfc3339DateTimeString: model.lastUpdated) {
                partition.setValue(updatedDate, forKey: "lastUpdated")
            }
            
            if let xValue = model.x {
                partition.setValue(xValue, forKey: "x")
            } else {
                partition.setValue("null", forKey: "x")
            }
            
            if let yValue = model.y {
                partition.setValue(yValue, forKey: "y")
            } else {
                partition.setValue("null", forKey: "y")
            }
            
            let chunkParts = createChunks(chunkModels: model.chunks, partition: partition)
            partition.setValue(chunkParts, forKey: "chunks")
            partition.setValue(revocation, forKey: "revocation")
        }
        RevocationCoreDataStorage.shared.saveContext()
    }
    
    public func createAndSaveChunk(kid: String, id: String, cid: String, sliceModel: [String : SliceModel]) {
        let partition = loadPartition(kid: kid, id: id)
        let chunkEntity = NSEntityDescription.entity(forEntityName: "Chunk", in: managedContext)!
        let chunk = Chunk(entity: chunkEntity, insertInto: managedContext)
        
        let slices: NSMutableOrderedSet = []
        for sliceKey in sliceModel.keys {
            let slice: Slice = createSlice(expDate: sliceKey, sliceModel: sliceModel[sliceKey]!)
            slice.setValue(chunk, forKey: "chunk")
            slices.add(slice)
        }
        chunk.setValue(cid, forKey: "cid")
        chunk.setValue(slices, forKey: "slices")
        chunk.setValue(partition, forKey: "partition")
        
        RevocationCoreDataStorage.shared.saveContext()
    }
    
    public func createAndSaveSlice(kid: String, id: String, cid: String, sliceKey: String, sliceModel: SliceModel) {
        let chunk = loadChunk(kid: kid, id: id, cid: cid)
        let slice: Slice = createSlice(expDate: sliceKey, sliceModel: sliceModel)
        let slices = chunk?.value(forKey: "slices") as? NSMutableOrderedSet
        slices?.add(slice)
        chunk?.setValue(slices, forKey: "slices")
        
        RevocationCoreDataStorage.shared.saveContext()
    }

    
    public func deleteExpiredPartitions(for date: Date) {
        let fetchRequest = NSFetchRequest<Partition>(entityName: "Partition")
        let predicate:  NSPredicate = NSPredicate(format: "expires < %@", argumentArray: [date])
        fetchRequest.predicate = predicate
        do {
            let partitions = try managedContext.fetch(fetchRequest)
            partitions.forEach { managedContext.delete($0) }
            print("  Deleted \(partitions.count) partitions for expiredDate: \(date)")
            
            RevocationCoreDataStorage.shared.saveContext()
            
        } catch let error as NSError {
            print("Could not fetch revocations. Error: \(error.localizedDescription) for expiredDate: \(date)")
            return
        } catch {
            print("Could not fetch revocations for expiredDate: \(date).")
            return
        }
    }
    
    public func deletePartition(kid: String, id: String) {
        let fetchRequest = NSFetchRequest<Partition>(entityName: "Partition")
        let predicate: NSPredicate = NSPredicate(format: "kid == %@ AND id == %@", argumentArray: [kid, id])
        fetchRequest.predicate = predicate
        do {
            let partitions = try managedContext.fetch(fetchRequest)
            partitions.forEach { managedContext.delete($0) }
            print("  Deleted \(partitions.count) partitions for id: \(id)")
            
            RevocationCoreDataStorage.shared.saveContext()
            
        } catch let error as NSError {
            print("Could not fetch revocations. Error: \(error.localizedDescription) for expiredDate: \(id)")
            return
        } catch {
            print("Could not fetch revocations for expiredDate: \(id)")
            return
        }
    }
  
    public func deleteChunk(_ chunk: Chunk) {
        managedContext.delete(chunk)
        RevocationCoreDataStorage.shared.saveContext()
    }

    public func deleteSlice(_ slice: Slice) {
        managedContext.delete(slice)
        RevocationCoreDataStorage.shared.saveContext()
    }

    public func deleteSlice(kid: String, id: String, cid: String, hashID: String) {
        let fetchRequest = NSFetchRequest<Slice>(entityName: "Slice")
        let predicate = NSPredicate(format: "chunk.partition.kid == %@ AND chunk.partition.id == %@ AND chunk.id == %@ AND hashID == %@",
            argumentArray: [kid, id, cid, hashID])
        fetchRequest.predicate = predicate
        do {
            let slices = try managedContext.fetch(fetchRequest)
            slices.forEach { managedContext.delete($0) }
            print("-- Deleted \(slices.count) slices for id: \(hashID)")
            
            RevocationCoreDataStorage.shared.saveContext()
            
        } catch let error as NSError {
            print("Could not fetch slices. Error: \(error.localizedDescription) for expiredDate: \(id)")
            return
        } catch {
            print("Could not fetch slices for expiredDate: \(id)")
            return
        }
    }

    
    public func loadAllPartitions(for kid: String) -> [Partition]? {
        let fetchRequest = NSFetchRequest<Partition>(entityName: "Partition")
        let predicate: NSPredicate = NSPredicate(format: "kid == %@", argumentArray: [kid])
        fetchRequest.predicate = predicate
        
        do {
            let partitions = try managedContext.fetch(fetchRequest)
            print("  Extracted \(partitions.count) partitions for id: \(kid)")
            return partitions
        } catch let error as NSError {
            print("Could not fetch Partitions: \(error), \(error.userInfo) for id: \(kid)")
            return nil
        } catch {
            print("Could not fetch Partitions for id: \(kid)")
            return nil
        }
    }
    
    public func loadPartition(kid: String, id: String) -> Partition? {
        let fetchRequest = NSFetchRequest<Partition>(entityName: "Partition")
        let predicate: NSPredicate = NSPredicate(format: "kid == %@ AND id == %@", argumentArray: [kid, id])
        fetchRequest.predicate = predicate
        
        do {
            let partitions = try managedContext.fetch(fetchRequest)
            print("  Extracted \(partitions.count) partitions for kid: \(kid), id: \(id)")
            return partitions.first
            
        } catch let error as NSError {
            print("Could not fetch Partitions: \(error), \(error.userInfo) for kid: \(kid), id: \(id)")
            return nil
        } catch {
            print("Could not fetch Partitions for kid: \(kid), id: \(id)")
            return nil
        }
    }

    public func loadChunk(kid: String, id: String, cid: String) -> Chunk? {
        let fetchRequest = NSFetchRequest<Chunk>(entityName: "Chunk")
        let predicate: NSPredicate = NSPredicate(format: "partition.kid == %@ AND partition.id == %@ AND cid == %@",
            argumentArray: [kid, id, cid])
        fetchRequest.predicate = predicate
        
        do {
            let chunks = try managedContext.fetch(fetchRequest)
            print("== Extracted \(chunks.count) chunk(s) for kid: \(kid), pid: \(id), cid: \(cid)")
            return chunks.first
        } catch let error as NSError {
            print("Could not fetch chunks: \(error), \(error.userInfo) for kid: \(kid), id: \(id), cid: \(cid)")
            return nil
        } catch {
            print("Could not fetch chunks for kid: \(kid), id: \(id), cid: \(cid)")
            return nil
        }
    }

    public func loadSlice(kid: String, id: String, cid: String, hashID: String) -> Slice? {
        let fetchRequest = NSFetchRequest<Slice>(entityName: "Slice")
        let predicate: NSPredicate = NSPredicate(format: "chunk.partition.kid == %@ AND chunk.partition.id == %@ AND chunk.cid == %@ AND hashID == %@",
            argumentArray: [kid, id, cid, hashID])
        fetchRequest.predicate = predicate
        
        do {
            let slices = try managedContext.fetch(fetchRequest)
            print("== Extracted \(slices.count) slice(s) for kid: \(kid), pid: \(id), cid: \(cid), sid: \(hashID)")
            return slices.first
        } catch let error as NSError {
            print("Could not fetch slices: \(error), \(error.userInfo) for kid: \(kid), id: \(id)")
            return nil
        } catch {
            print("Could not fetch slices for kid: \(kid), id: \(id)")
            return nil
        }
    }
    
    // MARK: - Chunks & Slices
    public func loadSlices(kid: String, x: String, y: String, section cid: String) -> [Slice]? {
        let fetchRequest = NSFetchRequest<Slice>(entityName: "Slice")
        let predicate = NSPredicate(format: "chunk.partition.kid == %@ AND chunk.partition.x == %@ AND chunk.partition.y == %@ AND chunk.cid == %@",
            argumentArray: [kid, x, y, cid])
        
        fetchRequest.predicate = predicate
        
        do {
            let slices = try managedContext.fetch(fetchRequest)
            print("== Extracted \(slices.count) slices for kid: \(kid), x: \(x), y: \(y)")
            
            return slices
            
        } catch let error as NSError {
          print("Could not fetch slices: \(error), \(error.userInfo)")
        
        } catch {
            print("Could not fetch slices.")
        }
        return nil
    }
    
    private func createSlice(expDate: String, sliceModel: SliceModel) -> Slice {
        let sliceEntity = NSEntityDescription.entity(forEntityName: "Slice", in: managedContext)!
        let slice = Slice(entity: sliceEntity, insertInto: managedContext)
        if let expDate = Date(rfc3339DateTimeString: expDate) {
            slice.setValue(expDate, forKey: "expiredDate")
        }
        slice.setValue(sliceModel.version, forKey: "version")
        slice.setValue(sliceModel.type, forKey: "type")
        slice.setValue(sliceModel.hash, forKey: "hashID")
        slice.setValue(nil, forKey: "hashData")
        return slice
    }

    private func createChunks(chunkModels: [String : SliceDict], partition: Partition) -> NSOrderedSet {
        let chunkSet: NSMutableOrderedSet = []
        for key in chunkModels.keys  {
            let chunkEntity = NSEntityDescription.entity(forEntityName: "Chunk", in: managedContext)!
            let chunk = Chunk(entity: chunkEntity, insertInto: managedContext)
            guard let sliceDict = chunkModels[key] else { return chunkSet }
            let slices: NSMutableOrderedSet = []
            for sliceKey in sliceDict.keys {
                let slice: Slice = createSlice(expDate: sliceKey, sliceModel: sliceDict[sliceKey]!)
                slice.setValue(chunk, forKey: "chunk")
                slices.add(slice)
            }
            chunk.setValue(key, forKey: "cid")
            chunk.setValue(slices, forKey: "slices")
            chunk.setValue(partition, forKey: "partition")
            chunkSet.add(chunk)
        }
        return chunkSet
    }
}