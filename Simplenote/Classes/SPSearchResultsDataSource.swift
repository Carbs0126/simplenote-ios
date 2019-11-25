import Foundation
import CoreData


// MARK: - SearchResults DataSource
//
class SPSearchResultsDataSource {

    /// Batch Size for the FRC's Request
    ///
    private let resultsBatchSize = 20

    /// Results Controller: Note Entity
    ///
    private lazy var resultsController: NSFetchedResultsController<Note> = {
        let request = NSFetchRequest<Note>()
        request.entity = NSEntityDescription.entity(forEntityName: Note.classNameWithoutNamespaces, in: mainContext)
        request.fetchBatchSize = resultsBatchSize
        request.sortDescriptors = sortDescriptors()
        return NSFetchedResultsController<Note>(fetchRequest: request, managedObjectContext: mainContext, sectionNameKeyPath: nil, cacheName: nil)
    }()

    /// Main MOC
    ///
    private let mainContext: NSManagedObjectContext

    /// Keyword we should be filtering by
    ///
    var keyword: String? {
        didSet {
            refreshPredicate(keyword: keyword)
        }
    }

    /// Designated Initializer
    ///
    ///  - mainContext: Main Thread's MOC
    ///
    init(mainContext: NSManagedObjectContext) {
        self.mainContext = mainContext
    }
}


// MARK: - Private Methods
//
private extension SPSearchResultsDataSource {

    /// Refreshes the ResultsController's Predicate
    ///
    func refreshPredicate(keyword: String?) {
        resultsController.fetchRequest.predicate = predicate(keyword: keyword)
    }

    /// Returns a NSPredicate which will filter notes by a given keyword.
    ///
    func predicate(keyword: String?) -> NSPredicate {
        var predicates = [
            NSPredicate.predicateForNotesWithStatus(deleted: false)
        ]

        if let keyword = keyword, keyword.count > 0 {
            predicates.append( NSPredicate.predicateForSearchText(searchText: keyword) )
        }

        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }

    /// Returns the Active SortDescriptors
    ///
    func sortDescriptors() -> [NSSortDescriptor] {
        let sortKey: String
        var sortSelector: Selector?
        var ascending = false

        switch Options.shared.listSortMode {
        case .alphabeticallyAscending:
            sortKey         = NSStringFromSelector( #selector(getter: Note.content) )
            sortSelector    = #selector(NSString.caseInsensitiveCompare)
            ascending       = true
        case .alphabeticallyDescending:
            sortKey         = NSStringFromSelector( #selector(getter: Note.content) )
            sortSelector    = #selector(NSString.caseInsensitiveCompare)
            ascending       = false
        case .createdNewest:
            sortKey         = NSStringFromSelector( #selector(getter: Note.creationDate) )
            ascending       = false
        case .createdOldest:
            sortKey         = NSStringFromSelector( #selector(getter: Note.creationDate) )
            ascending       = true
        case .modifiedNewest:
            sortKey         = NSStringFromSelector( #selector(getter: Note.modificationDate) )
            ascending       = false
        case .modifiedOldest:
            sortKey         = NSStringFromSelector( #selector(getter: Note.modificationDate) )
            ascending       = true
        }

        return [
            NSSortDescriptor(key: "pinned", ascending: false),
            NSSortDescriptor(key: sortKey, ascending: ascending, selector: sortSelector)
        ]
    }
}
