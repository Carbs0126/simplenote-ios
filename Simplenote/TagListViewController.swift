import Foundation

// MARK: - TagListViewController
//
final class TagListViewController: UIViewController {
    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var rightBorderView: UIView!
    @IBOutlet private weak var rightBorderWidthConstraint: NSLayoutConstraint!

    private lazy var tagsHeaderView: SPTagHeaderView = SPTagHeaderView.instantiateFromNib()
    private lazy var fetchedResultsController: NSFetchedResultsController<Tag> = {
        let context = SPAppDelegate.shared().managedObjectContext
        let entity = NSEntityDescription.entity(forEntityName: "Tag", in: context)

        let fetchRequest = NSFetchRequest<Tag>()
        fetchRequest.entity = entity
        fetchRequest.fetchBatchSize = Constants.tagListBatchSize
        fetchRequest.sortDescriptors = sortDescriptors

        return NSFetchedResultsController(fetchRequest: fetchRequest,
                                          managedObjectContext: context,
                                          sectionNameKeyPath: nil,
                                          cacheName: nil)
    }()

    private var renameTag: Tag?
    private var isVisible: Bool = false

    override var shouldAutorotate: Bool {
        return false
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configureTableView()
        configureTableHeaderView()
        configureRightBorderView()
        configureMenuController()
        startListeningToNotifications()

        refreshStyle()

        configureFetchResultsController()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startListeningToKeyboardNotifications()
        reloadDataAsynchronously()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        isVisible = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        setEditing(false)
        stopListeningToKeyboardNotifications()
        isVisible = false
    }
}

// MARK: - Configuration
//
private extension TagListViewController {
    func configureView() {
        view.backgroundColor = .simplenoteBackgroundColor
    }

    func configureTableView() {
        tableView.register(SPTagListViewCell.loadNib(), forCellReuseIdentifier: SPTagListViewCell.reuseIdentifier)

        if #available(iOS 13.0, *) {
            tableView.automaticallyAdjustsScrollIndicatorInsets = false
        }
    }

    func configureTableHeaderView() {
        tagsHeaderView.titleLabel.text = NSLocalizedString("Tags", comment: "")
        tagsHeaderView.titleLabel.font = .preferredFont(for: .title2, weight: .bold)

        let actionButton = tagsHeaderView.actionButton
        actionButton?.setTitle(NSLocalizedString("Edit", comment: "Edit Tags Action: Visible in the Tags List"), for: .normal)
        actionButton?.addTarget(self, action: #selector(editTagsTap), for: .touchUpInside)
    }

    func configureRightBorderView() {
        rightBorderWidthConstraint.constant = UIScreen.main.pointToPixelRatio
    }

    func configureMenuController() {
        let renameSelector = sel_registerName("rename:")
        let renameItem = UIMenuItem(title: NSLocalizedString("Rename", comment: "Rename a tag"), action: renameSelector)

        UIMenuController.shared.menuItems = [renameItem]
        UIMenuController.shared.update()
    }

    func configureFetchResultsController() {
        fetchedResultsController.delegate = self
        performFetch()
    }
}

// MARK: - Notifications
//
private extension TagListViewController {
    func startListeningToNotifications() {
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(menuDidChangeVisibility), name: UIMenuController.didShowMenuNotification, object: nil)
        nc.addObserver(self, selector: #selector(menuDidChangeVisibility), name: UIMenuController.didHideMenuNotification, object: nil)
        nc.addObserver(self, selector: #selector(tagsSortOrderWasUpdated), name: NSNotification.Name.SPAlphabeticalTagSortPreferenceChanged, object: nil)
        nc.addObserver(self, selector: #selector(themeDidChange), name: NSNotification.Name.SPSimplenoteThemeChanged, object: nil)
        // TODO: start listening when app becomes active?
        nc.addObserver(self, selector: #selector(stopListeningToKeyboardNotifications), name: UIApplication.willResignActiveNotification, object: nil)
    }

    func startListeningToKeyboardNotifications() {
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        nc.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc
    func stopListeningToKeyboardNotifications() {
        let nc = NotificationCenter.default
        nc.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        nc.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
}

// MARK: - Notifications
//
private extension TagListViewController {
    @objc
    func themeDidChange() {
        refreshStyle()
    }

    @objc
    func menuDidChangeVisibility() {
        tableView.allowsSelection = !UIMenuController.shared.isMenuVisible
    }

    @objc
    func tagsSortOrderWasUpdated() {
        refreshSortDescriptorsAndPerformFetch()
    }
}

// MARK: - Style
//
private extension TagListViewController {
    func refreshStyle() {
        rightBorderView.backgroundColor = .simplenoteDividerColor
        tagsHeaderView.refreshStyle()
        tableView.applySimplenotePlainStyle()
        tableView.reloadData()
    }
}

// MARK: - Button actions
//
private extension TagListViewController {
    @objc
    func editTagsTap() {
        let newState = !isEditing
        if newState {
            SPTracker.trackTagEditorAccessed()
        }

        setEditing(newState)
    }
}

// MARK: - Helper Methods
//
private extension TagListViewController {
    func cell(for tag: Tag) -> SPTagListViewCell? {
        guard let indexPath = indexPath(for: tag) else {
            return nil
        }

        return tableView.cellForRow(at: indexPath) as? SPTagListViewCell
    }

    func indexPath(for tag: Tag) -> IndexPath? {
        guard let indexPath = fetchedResultsController.indexPath(forObject: tag) else {
            return nil
        }

        return IndexPath(row: indexPath.row, section: Section.tags.rawValue)
    }

    func tag(at indexPath: IndexPath) -> Tag? {
        guard indexPath.row < fetchedResultsController.fetchedObjects?.count ?? 0
                && Section(rawValue: indexPath.section) == .tags else {
            return nil
        }

        // Our FRC has just one section!
        let indexPath = IndexPath(row: indexPath.row, section: 0)
        return fetchedResultsController.object(at: indexPath)
    }

    var numberOfTags: Int {
        return fetchedResultsController.sections?.first?.numberOfObjects ?? 0
    }

    func reloadDataAsynchronously() {
        DispatchQueue.main.async { [weak self] in
            self?.tableView.reloadData()
        }
    }
}

// MARK: - Table
//
extension TagListViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if Section(rawValue: section) == .tags {
            return UITableView.automaticDimension
        }

        return CGFloat.leastNormalMagnitude
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if Section(rawValue: section) == .tags {
            return tagsHeaderView
        }

        return nil
    }

    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        let isTagRow = Section(rawValue: indexPath.section) == .tags
        let isSortEnabled = UserDefaults.standard.bool(forKey: SPAlphabeticalTagSortPref)

        return isTagRow && !isSortEnabled
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return numberOfTags == 0 ? 1 : Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else {
            return 0
        }

        switch section {
        case .system:
            return SystemRow.allCases.count
        case .tags:
            return numberOfTags
        case .bottom:
            return 1
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(ofType: SPTagListViewCell.self, for: indexPath)
        configure(cell, at: indexPath)
        return cell
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.isSelected = shouldSelectCell(at: indexPath)
    }

    func tableView(_ tableView: UITableView, shouldShowMenuForRowAt indexPath: IndexPath) -> Bool {
        let isTagRow = Section(rawValue: indexPath.section) == .tags
        if isTagRow {
            SPTracker.trackTagCellPressed()
        }

        return isTagRow
    }

    func tableView(_ tableView: UITableView, canPerformAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        return true
    }

    func tableView(_ tableView: UITableView, performAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) {

    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let section = Section(rawValue: indexPath.section) else {
            return
        }

        switch section {
        case .system:
            didSelectSystemRow(at: indexPath)
        case .tags:
            didSelectTag(at: indexPath)
        case .bottom:
            didSelectBottomRow(at: indexPath)
        }
    }

    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        guard Section(rawValue: sourceIndexPath.section) == .tags
                && Section(rawValue: destinationIndexPath.section) == .tags else {
            return
        }

        SPObjectManager.shared().moveTag(from: sourceIndexPath.row,
                                         to: destinationIndexPath.row)
    }

    func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath, toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {
        guard Section(rawValue: sourceIndexPath.section) == .tags
                && Section(rawValue: proposedDestinationIndexPath.section) == .tags else {
            return sourceIndexPath
        }

        return proposedDestinationIndexPath
    }

    func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        return Section(rawValue: indexPath.section) == .tags
    }

    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        let isTagRow = Section(rawValue: indexPath.section) == .tags
        return isTagRow && tableView.isEditing ? .delete : .none
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else {
            return
        }

        SPTracker.trackTagRowDeleted()
        removeTag(at: indexPath)
    }
}

// MARK: - Cell Setup
//
private extension TagListViewController {
    func configure(_ cell: SPTagListViewCell, at indexPath: IndexPath) {
        guard let section = Section(rawValue: indexPath.section) else {
            return
        }

        switch section {
        case .system:
            configureSystemCell(cell, at: indexPath)
        case .tags:
            configureTagCell(cell, at: indexPath)
        case .bottom:
            configureBottomCell(cell, at: indexPath)
        }
    }

    func configureSystemCell(_ cell: SPTagListViewCell, at indexPath: IndexPath) {
        guard let row = SystemRow(rawValue: indexPath.row) else {
            return
        }

        switch row {
        case .allNotes:
            cell.textField.text = NSLocalizedString("All Notes", comment: "")
            cell.iconImage = .image(name: .allNotes)
            cell.accessibilityIdentifier = "all-notes"
        case .trash:
            cell.textField.text = NSLocalizedString("Trash-noun", comment: "")
            cell.iconImage = .image(name: .trash)
        case .settings:
            cell.textField.text = NSLocalizedString("Settings", comment: "")
            cell.iconImage = .image(name: .settings)
            cell.accessibilityIdentifier = "settings"
        }
    }

    func configureTagCell(_ cell: SPTagListViewCell, at indexPath: IndexPath) {
        let tagName = tag(at: indexPath)?.name

        cell.textField.text = tagName
        cell.iconImage = nil
        cell.delegate = self
    }

    func configureBottomCell(_ cell: SPTagListViewCell, at indexPath: IndexPath) {
        cell.textField.text = NSLocalizedString("Untagged Notes", comment: "Allows selecting notes with no tags")
        cell.iconImage = .image(name: .untagged)
    }

    func shouldSelectCell(at indexPath: IndexPath) -> Bool {
        guard let section = Section(rawValue: indexPath.section) else {
            return false
        }

        let selectedTag = SPAppDelegate.shared().selectedTag

        switch section {
        case .system:
            guard let row = SystemRow(rawValue: indexPath.row) else {
                return false
            }
            switch row {
            case .allNotes:
                return selectedTag == nil
            case .trash:
                return selectedTag == kSimplenoteTrashKey
            case .settings:
                return false
            }

        case .tags:
            return selectedTag == tag(at: indexPath)?.name
        case .bottom:
            return selectedTag == kSimplenoteUntaggedKey
        }
    }
}

// MARK: - Row Press Handlers
//
private extension TagListViewController {
    func didSelectSystemRow(at indexPath: IndexPath) {
        guard let row = SystemRow(rawValue: indexPath.row) else {
            return
        }

        switch row {
        case .allNotes:
            allNotesWasPressed()
        case .trash:
            trashWasPressed()
        case .settings:
            tableView.deselectRow(at: indexPath, animated: true)
            settingsWasPressed()
        }
    }

    func didSelectTag(at indexPath: IndexPath) {
        guard let tag = tag(at: indexPath) else {
            return
        }

        if isEditing {
            SPTracker.trackTagRowRenamed()
            renameTag(tag)
        } else {
            SPTracker.trackListTagViewed()
            openNoteListForTagName(tag.name)
        }
    }

    func didSelectBottomRow(at indexPath: IndexPath) {
        SPTracker.trackListUntaggedViewed()
        openNoteListForTagName(kSimplenoteUntaggedKey)
    }

    func allNotesWasPressed() {
        openNoteListForTagName(nil)
    }

    func trashWasPressed() {
        SPTracker.trackTrashViewed()
        openNoteListForTagName(kSimplenoteTrashKey)
    }

    func settingsWasPressed() {
        SPAppDelegate.shared().presentSettingsViewController()
    }
}

// MARK: - SPTagListViewCellDelegate
//
extension TagListViewController: SPTagListViewCellDelegate {
    func tagListViewCellShouldRenameTag(_ cell: SPTagListViewCell!) {
        SPTracker.trackTagMenuRenamed()

        guard let indexPath = tableView.indexPath(for: cell),
              let tag = tag(at: indexPath) else {
            return
        }

        renameTag(tag)
    }

    func tagListViewCellShouldDeleteTag(_ cell: SPTagListViewCell!) {
        SPTracker.trackTagMenuDeleted()

        guard let indexPath = tableView.indexPath(for: cell) else {
            return
        }

        removeTag(at: indexPath)
    }
}

// MARK: -
//
private extension TagListViewController {
    func setEditing(_ editing: Bool) {
        // Note: Neither super.setEditing nor tableView.setEditing will resign the first responder.
        if !editing {
            view.endEditing(true)
        }

        super.setEditing(editing, animated: true)
        tableView.setEditing(editing, animated: true)
        refreshEditTagsButton(isEditing: editing)
    }

    func refreshEditTagsButton(isEditing: Bool) {
        let title = isEditing ? NSLocalizedString("Done", comment: "") : NSLocalizedString("Edit", comment: "")
        tagsHeaderView.actionButton.setTitle(title, for: .normal)
    }

    func openNoteListForTagName(_ tagName: String?) {
        let appDelegate = SPAppDelegate.shared()
        // Only perform a fetch if the view has actually changed
        let fetchNeeded = appDelegate.selectedTag != tagName

        appDelegate.selectedTag = tagName
        // TODO: Move to AppDelegate::setSelectedTag ?
        if fetchNeeded {
            appDelegate.noteListViewController.update()
        }

        appDelegate.sidebarViewController.hideSidebar(withAnimation: true)
    }
}

// MARK: - UIGestureRecognizerDelegate
extension TagListViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

// MARK: - Tag Actions
//
private extension TagListViewController {
    func removeTag(at indexPath: IndexPath) {
        guard let tag = tag(at: indexPath) else {
            return
        }

        let appDelegate = SPAppDelegate.shared()
        if appDelegate.selectedTag == tag.name {
            appDelegate.selectedTag = nil
            appDelegate.noteListViewController.update()
        }

        SPObjectManager.shared().removeTag(tag)
    }

    func renameTag(_ tag: Tag) {
        if let renameTag = renameTag {
            cell(for: renameTag)?.textField.endEditing(true)
        }

        renameTag = tag

        guard let tagCell = cell(for: tag) else {
            return
        }

        tagCell.textField.isEnabled = true
        tagCell.textField.delegate = self
        tagCell.textField.becomeFirstResponder()
    }
}

// MARK: - UITextFieldDelegate
//
extension TagListViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // Scenario #A: Space was pressed
        if string.hasPrefix(" ") {
            textField.endEditing(true)
            return false
        }

        // Scenario #B: New String was either typed or pasted
        let filteredString = (string as NSString).substringUpToFirstSpace
        let updatedString = ((textField.text ?? "") as NSString).replacingCharacters(in: range, with: filteredString)
        let editContainsSpaces = filteredString.count < string.count

        if updatedString.isValidTagName {
            textField.text = updatedString
        }

        if editContainsSpaces {
            textField.endEditing(true)
        }

        return false
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        guard let renameTag = renameTag else {
            return
        }

        self.renameTag = nil

        let tagCell = cell(for: renameTag)
        if isEditing {
            tagCell?.setSelected(false, animated: true)
        }

        textField.isEnabled = false
        textField.delegate = nil

        let originalTagName = renameTag.name
        let newTagName = textField.text ?? ""

        // see if tag already exists, if not rename. If it does, revert back to original name
        let shouldRenameTag = !SPObjectManager.shared().tagExists(newTagName)

        if shouldRenameTag {
            SPObjectManager.shared().editTag(renameTag, title: newTagName)

            let appDelegate = SPAppDelegate.shared()
            if appDelegate.selectedTag == originalTagName {
                appDelegate.selectedTag = newTagName
                appDelegate.noteListViewController.update()
            }
        } else {
            textField.text = originalTagName
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

// MARK: - Fetched results controller
//
private extension TagListViewController {
    var sortDescriptors: [NSSortDescriptor] {
        let isAlphaSort = UserDefaults.standard.bool(forKey: SPAlphabeticalTagSortPref)
        let sortDescriptor: NSSortDescriptor
        if isAlphaSort {
            sortDescriptor = NSSortDescriptor(
                key: "name",
                ascending: true,
                selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
        } else {
            sortDescriptor = NSSortDescriptor(key: "index", ascending: true)
        }

        return [sortDescriptor]
    }

    func performFetch() {
        do {
            try fetchedResultsController.performFetch()
            tableView.reloadData()
        } catch {
            fatalError("Unresolved error \(error)")
        }
    }

    func refreshSortDescriptorsAndPerformFetch() {
        fetchedResultsController.fetchRequest.sortDescriptors = sortDescriptors
        performFetch()
    }
}

// MARK: - NSFetchedResultsControllerDelegate
//
extension TagListViewController: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        if isVisible {
            tableView.reloadData()
        }
    }
}

// MARK: - KeyboardNotifications
//
private extension TagListViewController {
    @objc
    func keyboardWillShow(_ notification: NSNotification) {
        let keyboardFrame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue ?? .zero

        let duration = (notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0

        var contentInsets = tableView.contentInset
        var scrollInsets = tableView.scrollIndicatorInsets
        let keyboardHeight = min(keyboardFrame.size.height, keyboardFrame.size.width)

        contentInsets.bottom = keyboardHeight
        scrollInsets.bottom = keyboardHeight

        UIView.animate(withDuration: TimeInterval(duration), animations: {
            self.tableView.contentInset = contentInsets
            self.tableView.scrollIndicatorInsets = scrollInsets
        })
    }

    @objc
    func keyboardWillHide(_ notification: NSNotification) {
        var contentInsets = tableView.contentInset
        contentInsets.bottom = view.safeAreaInsets.bottom

        let duration = (notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0

        UIView.animate(withDuration: TimeInterval(duration), animations: {
            self.tableView.contentInset = contentInsets
            self.tableView.scrollIndicatorInsets = .zero
        })
    }
}

// MARK: - Section enum
//
private enum Section: Int, CaseIterable {
    case system
    case tags
    case bottom
}

// MARK: - System Row enum
//
private enum SystemRow: Int, CaseIterable {
    case allNotes
    case trash
    case settings
}

// MARK: - Constants
//
private struct Constants {
    static let tagListBatchSize = 20
}
