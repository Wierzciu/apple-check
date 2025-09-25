import SwiftUI
import CoreData

struct DetailView: View {
    let kind: OSKind
    @FetchRequest private var records: FetchedResults<ReleaseRecord>

    init(kind: OSKind) {
        self.kind = kind
        let request: NSFetchRequest<ReleaseRecord> = ReleaseRecord.fetchRequest()
        request.predicate = NSPredicate(format: "kindRaw == %@", kind.rawValue)
        request.sortDescriptors = [NSSortDescriptor(key: "publishedAt", ascending: false)]
        request.fetchLimit = 10
        _records = FetchRequest(fetchRequest: request)
    }

    var body: some View {
        List(records) { rec in
            VStack(alignment: .leading, spacing: 4) {
                Text("\(rec.version ?? "?") (\(rec.build ?? "?"))")
                    .font(.headline)
                Text("\(Channel(rawValue: rec.channelRaw)?.displayName ?? "") • \(SourceStatus(rawValue: rec.statusRaw)?.displayName ?? "")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let date = rec.publishedAt {
                    Text(DisplayDateFormatter.dateTime.string(from: date))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(kind.displayName)
    }
}

