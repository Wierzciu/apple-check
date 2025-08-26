import Foundation
import CoreData

final class PersistenceController {
    static let shared = PersistenceController()
    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        let model = Self.makeModel()
        container = NSPersistentContainer(name: "AppleCheck", managedObjectModel: model)
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { _, error in
            if let error = error { fatalError("Unresolved error: \(error)") }
        }
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    private static func makeModel() -> NSManagedObjectModel {
        // Programowy model Core Data: ReleaseRecord
        let model = NSManagedObjectModel()
        let entity = NSEntityDescription()
        entity.name = "ReleaseRecord"
        entity.managedObjectClassName = NSStringFromClass(ReleaseRecord.self)

        var props: [NSAttributeDescription] = []
        func attr(_ name: String, _ type: NSAttributeType, optional: Bool = true) -> NSAttributeDescription {
            let a = NSAttributeDescription()
            a.name = name
            a.attributeType = type
            a.isOptional = optional
            return a
        }
        props.append(attr("id", .stringAttributeType, optional: false))
        props.append(attr("kindRaw", .stringAttributeType, optional: false))
        props.append(attr("version", .stringAttributeType))
        props.append(attr("build", .stringAttributeType))
        props.append(attr("channelRaw", .stringAttributeType, optional: false))
        props.append(attr("statusRaw", .stringAttributeType, optional: false))
        props.append(attr("publishedAt", .dateAttributeType))
        props.append(attr("deviceIdentifier", .stringAttributeType))
        props.append(attr("betaNumber", .integer64AttributeType))

        entity.properties = props
        entity.uniquenessConstraints = [["id"]]
        model.entities = [entity]
        return model
    }
}

@objc(ReleaseRecord)
final class ReleaseRecord: NSManagedObject, Identifiable {
    @NSManaged var id: String
    @NSManaged var kindRaw: String
    @NSManaged var version: String?
    @NSManaged var build: String?
    @NSManaged var channelRaw: String
    @NSManaged var statusRaw: String
    @NSManaged var publishedAt: Date?
    @NSManaged var deviceIdentifier: String?
    @NSManaged var betaNumber: NSNumber?
}

extension ReleaseRecord {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ReleaseRecord> {
        return NSFetchRequest<ReleaseRecord>(entityName: "ReleaseRecord")
    }

    static func upsert(from item: ReleaseItem, in context: NSManagedObjectContext) {
        let fetch = NSFetchRequest<ReleaseRecord>(entityName: "ReleaseRecord")
        fetch.predicate = NSPredicate(format: "id == %@", item.id)
        fetch.fetchLimit = 1
        if let found = try? context.fetch(fetch).first { apply(item, to: found) }
        else {
            let obj = ReleaseRecord(context: context)
            apply(item, to: obj)
        }
    }

    private static func apply(_ item: ReleaseItem, to obj: ReleaseRecord) {
        obj.id = item.id
        obj.kindRaw = item.kind.rawValue
        obj.version = item.version
        obj.build = item.build
        obj.channelRaw = item.channel.rawValue
        obj.statusRaw = item.status.rawValue
        obj.publishedAt = item.publishedAt
        obj.deviceIdentifier = item.deviceIdentifier
        if let b = item.betaNumber { obj.betaNumber = NSNumber(value: b) } else { obj.betaNumber = nil }
    }
}


