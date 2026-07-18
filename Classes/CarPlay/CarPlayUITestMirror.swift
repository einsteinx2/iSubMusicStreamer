//
//  CarPlayUITestMirror.swift
//  iSub
//
//  Created by Ben Baron on 7/18/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import UIKit
import CarPlay
import Resolver

// UI-test-only mirror of the CarPlay template stack (-UITEST plus -CARPLAY).
//
// XCUITest cannot drive the real car screen: CarPlay templates are rendered
// out-of-process by the system's CarPlay host, there are no public automation
// APIs for it, and headless CI simulators can't attach the CarPlay display at
// all. What CAN be tested end-to-end is everything up to that boundary — so
// this harness runs the real CarPlayManager against the same interface seam the
// unit tests use, and renders the resulting CPListTemplate/CPListItem objects
// into a native window that XCUITest can read and tap. Row taps invoke the real
// CPListItem handlers, driving the real PlaybackCoordinator, stores, loaders,
// and audio engine inside the UI-test app process.
//
// Dormant in production: everything is gated on the -CARPLAY launch argument in
// UI test mode, exactly like the rest of UITestSupport.
enum UITestCarPlaySupport {
    static var isEnabled: Bool {
        UITestSupport.isEnabled && ProcessInfo.processInfo.arguments.contains("-CARPLAY")
    }

    private static var mirror: CarPlayUITestMirror?

    // Called at the end of the phone scene's willConnectTo (after the main window
    // exists), standing in for a CPTemplateApplicationScene connecting
    static func connectIfEnabled(windowScene: UIWindowScene) {
        guard isEnabled, mirror == nil else { return }
        let mirror = CarPlayUITestMirror(windowScene: windowScene)
        self.mirror = mirror
        mirror.connect()
    }
}

// In-app recording implementation of the interface seam (same shape as the unit
// tests' fake): the manager drives real templates, the mirror renders the stack
final class UITestCarPlayInterface: CarPlayInterfaceControlling {
    private(set) var stack = [CPTemplate]()

    // The manager's prune hook (CarPlayInterfaceControlling requirement)
    var onStackChanged: (() -> Void)?
    // The mirror's re-render hook, fired alongside the manager's
    var mirrorObserver: (() -> Void)?

    var templates: [CPTemplate] { stack }
    var topTemplate: CPTemplate? { stack.last }
    var carTraitCollection: UITraitCollection { UITraitCollection() }

    private func changed() {
        onStackChanged?()
        mirrorObserver?()
    }

    func setRootTemplate(_ template: CPTemplate, animated: Bool) {
        stack = [template]
        changed()
    }

    func pushTemplate(_ template: CPTemplate, animated: Bool) {
        stack.append(template)
        changed()
    }

    func popTemplate(animated: Bool) {
        if stack.count > 1 {
            stack.removeLast()
        }
        changed()
    }

    func popToRootTemplate(animated: Bool) {
        stack = Array(stack.prefix(1))
        changed()
    }
}

// Owns the manager, the fullscreen mirror window, and the floating reopen button
final class CarPlayUITestMirror {
    let interface = UITestCarPlayInterface()
    private(set) var manager: CarPlayManager?

    private let windowScene: UIWindowScene
    private var mirrorWindow: UIWindow?
    private var toggleWindow: UIWindow?
    private weak var viewController: CarPlayMirrorViewController?

    init(windowScene: UIWindowScene) {
        self.windowScene = windowScene
    }

    func connect() {
        let manager = CarPlayManager(interface: interface)
        self.manager = manager
        manager.connect()

        let controller = CarPlayMirrorViewController(mirror: self)
        viewController = controller
        let window = UIWindow(windowScene: windowScene)
        window.frame = windowScene.coordinateSpace.bounds
        window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.alert.rawValue + 100)
        window.rootViewController = controller
        mirrorWindow = window

        let toggleController = CarPlayMirrorToggleViewController(mirror: self)
        let bounds = windowScene.coordinateSpace.bounds
        let toggle = UIWindow(windowScene: windowScene)
        toggle.frame = CGRect(x: bounds.maxX - 84, y: bounds.maxY - 240, width: 64, height: 64)
        toggle.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.alert.rawValue + 101)
        toggle.rootViewController = toggleController
        toggleWindow = toggle

        interface.mirrorObserver = { [weak self] in
            self?.viewController?.scheduleReload()
        }

        showMirror()
    }

    func showMirror() {
        mirrorWindow?.isHidden = false
        toggleWindow?.isHidden = true
        viewController?.scheduleReload()
    }

    func hideMirror() {
        mirrorWindow?.isHidden = true
        toggleWindow?.isHidden = false
    }
}

// The floating "CarPlay" button shown while the mirror is hidden, so tests can
// switch between phone flows and car flows in one launch
private final class CarPlayMirrorToggleViewController: UIViewController {
    private let mirror: CarPlayUITestMirror

    init(mirror: CarPlayUITestMirror) {
        self.mirror = mirror
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        let button = UIButton(type: .system)
        button.setTitle("Car", for: .normal)
        button.accessibilityIdentifier = AccessibilityId.carPlayToggle
        button.backgroundColor = .systemGreen
        button.tintColor = .white
        button.layer.cornerRadius = 12
        button.addTarget(self, action: #selector(showMirror), for: .touchUpInside)
        button.frame = view.bounds
        button.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(button)
    }

    @objc private func showMirror() {
        mirror.showMirror()
    }
}

// Renders the current top template: a tab strip for the root CPTabBarTemplate, a
// table for CPListTemplate sections/items, a panel for CPNowPlayingTemplate, and
// the list's empty-state variants when there are no rows
private final class CarPlayMirrorViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let mirror: CarPlayUITestMirror

    private let titleLabel = UILabel()
    private let backButton = UIButton(type: .system)
    private let phoneButton = UIButton(type: .system)
    private let tabStack = UIStackView()
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let emptyTitleLabel = UILabel()
    private let emptySubtitleLabel = UILabel()
    private let nowPlayingPanel = UIStackView()
    private let nowPlayingTitleLabel = UILabel()

    private var selectedTabIndex = 0
    private var refreshTimer: Timer?
    // Snapshot rebuilt on every reload so table callbacks and taps agree
    private var displayedSections = [CPListSection]()
    // Content signature of the last render: the poll timer only touches the view
    // hierarchy when something actually changed, otherwise the constant
    // reloadData() churn destroys cells mid-tap and XCUITest interactions fail
    // with "activation point invalid"
    private var lastRenderSignature = ""

    private var playQueue: PlayQueue { Resolver.resolve() }

    init(mirror: CarPlayUITestMirror) {
        self.mirror = mirror
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        refreshTimer?.invalidate()
    }

    // MARK: Template resolution

    private var tabTemplates: [CPListTemplate] {
        guard let tabBar = mirror.interface.templates.first as? CPTabBarTemplate else { return [] }
        return tabBar.templates.compactMap { $0 as? CPListTemplate }
    }

    // The template the car screen would be showing: the pushed stack top when
    // anything is pushed, else the selected tab's root list
    private var topTemplate: CPTemplate? {
        let stack = mirror.interface.templates
        if stack.count > 1 {
            return stack.last
        }
        let tabs = tabTemplates
        guard selectedTabIndex < tabs.count else { return tabs.first }
        return tabs[selectedTabIndex]
    }

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        backButton.setTitle("Back", for: .normal)
        backButton.accessibilityIdentifier = AccessibilityId.carPlayBack
        backButton.addTarget(self, action: #selector(goBack), for: .touchUpInside)

        titleLabel.accessibilityIdentifier = AccessibilityId.carPlayTitle
        titleLabel.font = .boldSystemFont(ofSize: 17)
        titleLabel.textAlignment = .center

        phoneButton.setTitle("Phone", for: .normal)
        phoneButton.accessibilityIdentifier = AccessibilityId.carPlayPhone
        phoneButton.addTarget(self, action: #selector(showPhone), for: .touchUpInside)

        let topBar = UIStackView(arrangedSubviews: [backButton, titleLabel, phoneButton])
        topBar.axis = .horizontal
        topBar.distribution = .fillProportionally
        topBar.spacing = 8

        tabStack.axis = .horizontal
        tabStack.distribution = .fillEqually
        tabStack.spacing = 4

        tableView.accessibilityIdentifier = AccessibilityId.carPlayList
        tableView.dataSource = self
        tableView.delegate = self

        emptyTitleLabel.accessibilityIdentifier = AccessibilityId.carPlayEmptyTitle
        emptyTitleLabel.font = .boldSystemFont(ofSize: 16)
        emptyTitleLabel.textAlignment = .center
        emptySubtitleLabel.font = .systemFont(ofSize: 13)
        emptySubtitleLabel.textAlignment = .center
        emptySubtitleLabel.numberOfLines = 0

        nowPlayingTitleLabel.accessibilityIdentifier = AccessibilityId.carPlayNowPlayingTitle
        nowPlayingTitleLabel.font = .boldSystemFont(ofSize: 18)
        nowPlayingTitleLabel.textAlignment = .center
        nowPlayingTitleLabel.numberOfLines = 0
        let upNextButton = UIButton(type: .system)
        upNextButton.setTitle("Up Next", for: .normal)
        upNextButton.accessibilityIdentifier = AccessibilityId.carPlayNowPlayingUpNext
        upNextButton.addTarget(self, action: #selector(showUpNext), for: .touchUpInside)
        nowPlayingPanel.axis = .vertical
        nowPlayingPanel.spacing = 16
        nowPlayingPanel.addArrangedSubview(nowPlayingTitleLabel)
        nowPlayingPanel.addArrangedSubview(upNextButton)

        let content = UIStackView(arrangedSubviews: [topBar, tabStack, emptyTitleLabel, emptySubtitleLabel, nowPlayingPanel, tableView])
        content.axis = .vertical
        content.spacing = 8
        content.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            content.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8),
            content.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -8),
            content.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])

        // Section-content updates (async loader refreshes) don't fire the stack
        // observer, so poll — the UI tests poll for content anyway
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.reloadNow()
        }

        reloadNow()
    }

    // MARK: Reload

    func scheduleReload() {
        DispatchQueue.main.async { [weak self] in
            self?.reloadNow()
        }
    }

    private func reloadNow() {
        guard isViewLoaded, view.window != nil else { return }
        let signature = renderSignature()
        guard signature != lastRenderSignature else { return }
        lastRenderSignature = signature

        rebuildTabButtons()

        let stack = mirror.interface.templates
        backButton.isHidden = stack.count <= 1

        let top = topTemplate
        if top === CPNowPlayingTemplate.shared {
            titleLabel.text = "Now Playing"
            nowPlayingPanel.isHidden = false
            nowPlayingTitleLabel.text = playQueue.currentSong?.title ?? "Nothing Playing"
            tableView.isHidden = true
            emptyTitleLabel.isHidden = true
            emptySubtitleLabel.isHidden = true
            displayedSections = []
            return
        }

        nowPlayingPanel.isHidden = true
        guard let listTemplate = top as? CPListTemplate else {
            titleLabel.text = "CarPlay"
            displayedSections = []
            tableView.isHidden = true
            emptyTitleLabel.isHidden = true
            emptySubtitleLabel.isHidden = true
            return
        }

        titleLabel.text = listTemplate.title ?? listTemplate.tabTitle
        displayedSections = listTemplate.sections
        let itemCount = displayedSections.reduce(0) { $0 + $1.items.count }
        let isEmpty = itemCount == 0
        tableView.isHidden = isEmpty
        emptyTitleLabel.isHidden = !isEmpty
        emptySubtitleLabel.isHidden = !isEmpty
        if isEmpty {
            emptyTitleLabel.text = listTemplate.emptyViewTitleVariants.first ?? ""
            emptySubtitleLabel.text = listTemplate.emptyViewSubtitleVariants.first ?? ""
        }
        tableView.reloadData()
    }

    // Everything user-visible that reloadNow renders, cheap to compute. Images are
    // deliberately excluded: async art arriving must not churn the table.
    private func renderSignature() -> String {
        var parts = [String]()
        parts.append("tabs:\(tabTemplates.map { $0.tabTitle ?? $0.title ?? "" }.joined(separator: ","))")
        parts.append("selected:\(selectedTabIndex)")
        parts.append("depth:\(mirror.interface.templates.count)")

        let top = topTemplate
        if top === CPNowPlayingTemplate.shared {
            parts.append("nowPlaying:\(playQueue.currentSong?.title ?? "")")
        } else if let listTemplate = top as? CPListTemplate {
            parts.append("list:\(ObjectIdentifier(listTemplate).hashValue):\(listTemplate.title ?? "")")
            parts.append("empty:\(listTemplate.emptyViewTitleVariants.first ?? "")")
            for section in listTemplate.sections {
                parts.append("s:\(section.header ?? "")")
                for case let item as CPListItem in section.items {
                    parts.append("i:\(item.text ?? "")|\(item.detailText ?? "")|\(item.isEnabled)|\(item.isPlaying)")
                }
            }
        }
        return parts.joined(separator: "\n")
    }

    private func rebuildTabButtons() {
        let titles = tabTemplates.map { $0.tabTitle ?? $0.title ?? "" }
        // Rebuild only when the set/order changes (offline reorder, server switch)
        let existing = tabStack.arrangedSubviews.compactMap { ($0 as? UIButton)?.title(for: .normal) }
        if existing != titles {
            tabStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            for (index, title) in titles.enumerated() {
                let button = UIButton(type: .system)
                button.setTitle(title, for: .normal)
                button.accessibilityIdentifier = AccessibilityId.carPlayTab(title)
                button.tag = index
                button.addTarget(self, action: #selector(selectTab(_:)), for: .touchUpInside)
                tabStack.addArrangedSubview(button)
            }
            selectedTabIndex = 0
        }
        for case let button as UIButton in tabStack.arrangedSubviews {
            button.titleLabel?.font = button.tag == selectedTabIndex ? .boldSystemFont(ofSize: 15) : .systemFont(ofSize: 15)
        }
    }

    // MARK: Actions

    @objc private func selectTab(_ sender: UIButton) {
        // Switching tabs on the real car screen implies nothing is pushed
        if mirror.interface.templates.count > 1 {
            mirror.interface.popToRootTemplate(animated: false)
        }
        selectedTabIndex = sender.tag
        reloadNow()
    }

    @objc private func goBack() {
        mirror.interface.popTemplate(animated: false)
        reloadNow()
    }

    @objc private func showPhone() {
        mirror.hideMirror()
    }

    @objc private func showUpNext() {
        mirror.manager?.nowPlayingTemplateUpNextButtonTapped(CPNowPlayingTemplate.shared)
        reloadNow()
    }

    // MARK: Table

    func numberOfSections(in tableView: UITableView) -> Int {
        displayedSections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        displayedSections[section].items.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        displayedSections[section].header
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "carplay.cell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "carplay.cell")
        guard let item = listItem(at: indexPath) else { return cell }
        cell.textLabel?.text = item.text
        cell.detailTextLabel?.text = item.detailText
        cell.accessoryType = item.accessoryType == .disclosureIndicator ? .disclosureIndicator : .none
        cell.textLabel?.textColor = item.isEnabled ? .label : .tertiaryLabel
        // XCUIElement.isEnabled and .value read these
        cell.isUserInteractionEnabled = item.isEnabled
        if item.isEnabled {
            cell.accessibilityTraits.remove(.notEnabled)
        } else {
            cell.accessibilityTraits.insert(.notEnabled)
        }
        cell.accessibilityValue = item.isPlaying ? "playing" : nil
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        guard let item = listItem(at: indexPath), item.isEnabled else { return }
        // The real tap path: whatever handler the CarPlayItemFactory installed
        item.handler?(item, { })
        scheduleReload()
    }

    private func listItem(at indexPath: IndexPath) -> CPListItem? {
        guard indexPath.section < displayedSections.count else { return nil }
        let items = displayedSections[indexPath.section].items
        guard indexPath.row < items.count else { return nil }
        return items[indexPath.row] as? CPListItem
    }
}
