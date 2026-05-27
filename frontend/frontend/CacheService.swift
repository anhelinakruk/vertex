//
//  CacheService.swift
//  Vertex
//

import CoreData
import Foundation

class CacheService {
    static let shared = CacheService()

    private let ttl: TimeInterval = 300 // 5 minutes

    private lazy var container: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "VertexCache", managedObjectModel: Self.makeModel())
        container.loadPersistentStores { _, error in
            if let error = error {
                print("Core Data failed to load: \(error)")
            }
        }
        return container
    }()

    private var context: NSManagedObjectContext {
        container.viewContext
    }

    private static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        let entity = NSEntityDescription()
        entity.name = "WalletCache"
        entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)

        let addressAttr = NSAttributeDescription()
        addressAttr.name = "address"
        addressAttr.attributeType = .stringAttributeType
        addressAttr.isOptional = true

        let balanceAttr = NSAttributeDescription()
        balanceAttr.name = "balance"
        balanceAttr.attributeType = .stringAttributeType
        balanceAttr.isOptional = true

        let txDataAttr = NSAttributeDescription()
        txDataAttr.name = "transactionsData"
        txDataAttr.attributeType = .binaryDataAttributeType
        txDataAttr.isOptional = true

        let lastFetchedAttr = NSAttributeDescription()
        lastFetchedAttr.name = "lastFetched"
        lastFetchedAttr.attributeType = .dateAttributeType
        lastFetchedAttr.isOptional = true

        entity.properties = [addressAttr, balanceAttr, txDataAttr, lastFetchedAttr]
        model.entities = [entity]
        return model
    }

    func save(address: String, balance: String, transactions: [Transaction]) {
        let object = fetchOrCreate(address: address)
        object.setValue(address, forKey: "address")
        object.setValue(balance, forKey: "balance")
        object.setValue(Date(), forKey: "lastFetched")
        if let data = try? JSONEncoder().encode(transactions) {
            object.setValue(data, forKey: "transactionsData")
        }
        try? context.save()
    }

    func load(for address: String) -> (balance: String, transactions: [Transaction])? {
        let request = NSFetchRequest<NSManagedObject>(entityName: "WalletCache")
        request.predicate = NSPredicate(format: "address == %@", address)

        guard
            let object = try? context.fetch(request).first,
            let lastFetched = object.value(forKey: "lastFetched") as? Date,
            Date().timeIntervalSince(lastFetched) < ttl,
            let balance = object.value(forKey: "balance") as? String,
            let data = object.value(forKey: "transactionsData") as? Data,
            let transactions = try? JSONDecoder().decode([Transaction].self, from: data)
        else { return nil }

        return (balance, transactions)
    }

    private func fetchOrCreate(address: String) -> NSManagedObject {
        let request = NSFetchRequest<NSManagedObject>(entityName: "WalletCache")
        request.predicate = NSPredicate(format: "address == %@", address)
        if let existing = try? context.fetch(request).first {
            return existing
        }
        let entity = container.managedObjectModel.entitiesByName["WalletCache"]!
        return NSManagedObject(entity: entity, insertInto: context)
    }
}
