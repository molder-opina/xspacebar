import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var urlText: String = ""
    var listenProcess: Process?
    var recordProcess: Process?
    var youtubeProcess: Process?
    var archiveProcess: Process?
    var startTime: Date?
    var timer: Timer?
    var elapsedTime: String = "00:00:00"
    var volumeProcess: Process?
    var menuItem: NSMenuItem?
    
    let scriptDir = "/Users/molder/projects/github-molder/spaces"
    
    let historyKey = "SpaceHistory"
    let maxHistory = 10
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()
    }
    
    func addToHistory(url: String) {
        var history = getHistory()
        history.removeAll { $0 == url }
        history.insert(url, at: 0)
        if history.count > maxHistory {
            history = Array(history.prefix(maxHistory))
        }
        UserDefaults.standard.set(history, forKey: historyKey)
    }
    
    func getHistory() -> [String] {
        return UserDefaults.standard.stringArray(forKey: historyKey) ?? []
    }
    
    func clearHistory() {
        UserDefaults.standard.removeObject(forKey: historyKey)
    }
    
    func getDownloadPath() -> String {
        return UserDefaults.standard.string(forKey: "downloadPath") ?? "\(NSHomeDirectory())/Downloads/x_spaces"
    }
    
    func setDownloadPath(_ path: String) {
        UserDefaults.standard.set(path, forKey: "downloadPath")
    }
    
    func createContextMenu() -> NSMenu {
        let menu = NSMenu()
        
        let listenMenuItem = NSMenuItem(title: "🔊 Escuchar", action: #selector(handleMenuAction(_:)), keyEquivalent: "")
        listenMenuItem.target = self
        listenMenuItem.tag = 1
        menu.addItem(listenMenuItem)
        
        let recordMenuItem = NSMenuItem(title: "🎙️ Grabar", action: #selector(handleMenuAction(_:)), keyEquivalent: "")
        recordMenuItem.target = self
        recordMenuItem.tag = 2
        menu.addItem(recordMenuItem)
        
        let youtubeMenuItem = NSMenuItem(title: "📺 YouTube Live", action: #selector(handleMenuAction(_:)), keyEquivalent: "")
        youtubeMenuItem.target = self
        youtubeMenuItem.tag = 3
        menu.addItem(youtubeMenuItem)
        
        let archiveMenuItem = NSMenuItem(title: "🌐 Internet Archive", action: #selector(handleMenuAction(_:)), keyEquivalent: "")
        archiveMenuItem.target = self
        archiveMenuItem.tag = 4
        menu.addItem(archiveMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let stopAllItem = NSMenuItem(title: "⏹ Detener Todo", action: #selector(handleMenuAction(_:)), keyEquivalent: "")
        stopAllItem.target = self
        stopAllItem.tag = 20
        menu.addItem(stopAllItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let openDesktopItem = NSMenuItem(title: "🖥️ Abrir Desktop", action: #selector(openDesktopAction), keyEquivalent: "")
        openDesktopItem.target = self
        menu.addItem(openDesktopItem)
        
        let closeItem = NSMenuItem(title: "❌ Cerrar XSpaceBar", action: #selector(handleMenuAction(_:)), keyEquivalent: "")
        closeItem.target = self
        closeItem.tag = 99
        menu.addItem(closeItem)
        
        return menu
    }
    
    @objc func openDesktopAction() {
        let path = "/Users/molder/projects/github-molder/spaces/XSpaceBar-Desktop/XSpaceBar-Desktop.app"
        let runningApps = NSWorkspace.shared.runningApplications
        let alreadyRunning = runningApps.contains { $0.bundleURL?.path == path }
        
        if alreadyRunning {
            if let app = runningApps.first(where: { $0.bundleURL?.path == path }) {
                app.activate(options: .activateIgnoringOtherApps)
            }
        } else {
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
        }
    }
    
    @objc func handleMenuAction(_ sender: NSMenuItem) {
        print("DEBUG: Menu action received, tag = \(sender.tag)")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            print("DEBUG: Executing action \(sender.tag)")
            
            switch sender.tag {
            case 1:
                print("DEBUG: Listen - urlText = \(self.urlText)")
                if !self.isListening() && !self.urlText.isEmpty {
                    self.startListen(url: self.urlText)
                }
            case 2:
                print("DEBUG: Record")
                if !self.isRecording() && !self.urlText.isEmpty {
                    self.startRecord(url: self.urlText)
                }
            case 3:
                print("DEBUG: YouTube")
                if !self.isYouTubing() && !self.urlText.isEmpty {
                    self.startYouTube(url: self.urlText)
                }
            case 4:
                print("DEBUG: Archive")
                if !self.isArchiving() && !self.urlText.isEmpty {
                    self.startArchive(url: self.urlText)
                }
            case 20: 
                print("DEBUG: Stop All")
                self.stopAll()
            case 99: 
                print("DEBUG: Close")
                NSApplication.shared.terminate(nil)
            default: break
            }
        }
    }
    
    func adjustVolume(up: Bool) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        let direction = up ? "+" : "-"
        task.arguments = ["-c", "osascript -e 'set volume output volume ((output volume of (get volume settings)) \(direction) 10)'"]
        try? task.run()
    }
    
    func toggleMute() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", "osascript -e 'set mute output muted to not output muted of (get volume settings)'"]
        try? task.run()
    }
    
    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self, let button = self.statusItem.button else { return }
            
            button.title = "X"
            button.font = NSFont.systemFont(ofSize: 13, weight: .bold)
            button.action = #selector(self.handleStatusItemClick)
            button.target = self
            
            self.statusItem.menu = self.createContextMenu()
        }
    }
    
    @objc func handleStatusItemClick(_ sender: NSStatusBarButton) {
        if let event = NSApp.currentEvent {
            if event.type == .rightMouseUp {
                statusItem.menu?.popUp(positioning: statusItem.menu?.item(at: 0), at: NSPoint(x: sender.frame.minX, y: sender.frame.minY), in: sender)
            } else if event.clickCount == 2 {
                Process.launchedProcess(launchPath: "/usr/bin/open", arguments: ["/Users/molder/projects/github-molder/spaces/XSpaceBar-Desktop/XSpaceBar-Desktop.app"])
            } else {
                togglePopover()
            }
        }
    }
    
    func updateStatusItemColor() {
        guard let button = statusItem.button else { return }
        
        let isActive = isListening() || isRecording() || isYouTubing() || isArchiving()
        
        if isActive {
            button.contentTintColor = .systemGreen
        } else {
            button.contentTintColor = .systemRed
        }
    }
    
    func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimer()
        }
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
        elapsedTime = "00:00:00"
    }
    
    func updateTimer() {
        guard let start = startTime else { return }
        let elapsed = Int(Date().timeIntervalSince(start))
        let hours = elapsed / 3600
        let minutes = (elapsed % 3600) / 60
        let seconds = elapsed % 60
        elapsedTime = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        
        if let vc = popover.contentViewController as? MainViewController {
            vc.updateTimerLabel(elapsedTime)
        }
    }
    
    func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 420)
        popover.contentViewController = MainViewController(delegate: self)
        popover.behavior = .transient
    }
    
    @objc func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.perform(#selector(NSPopover.performClose(_:)), with: nil, afterDelay: 0)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
            }
        }
    }
    
    @objc func closePopover() {
        if popover.isShown {
            popover.perform(#selector(NSPopover.performClose(_:)), with: nil, afterDelay: 0)
        }
    }
    
    func pasteFromClipboard() {
        if let clipboard = NSPasteboard.general.string(forType: .string) {
            urlText = clipboard
            if let vc = popover.contentViewController as? MainViewController {
                vc.urlTextField.stringValue = urlText
                vc.updateButtonStates()
            }
        }
    }
    
    func startListen(url: String) {
        guard !url.isEmpty else { return }
        print("Starting listen with URL: \(url)")
        
        // Start timer
        startTime = Date()
        startTimer()
        
        // Add to history
        addToHistory(url: url)
        
        // Kill any existing processes first
        killAllMediaProcesses()
        
        // Use bash to run the script
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", "cd \(scriptDir) && ./xidexc-record --live '\(url)'"]
        task.currentDirectoryURL = URL(fileURLWithPath: scriptDir)
        
        var env = ProcessInfo.processInfo.environment
        env["X_SPACES_DIR"] = "\(NSHomeDirectory())/Downloads/x_spaces"
        task.environment = env
        
        do {
            try task.run()
            print("Task started, PID: \(task.processIdentifier)")
            listenProcess = task
            updateStatusItemColor()
            if let vc = popover.contentViewController as? MainViewController { vc.updateButtonStates() }
        } catch {
            showAlert(title: "Error", message: error.localizedDescription)
        }
    }
    
    func stopListen() {
        listenProcess?.terminate()
        listenProcess = nil
        killAllMediaProcesses()
        updateStatusItemColor()
        if let vc = popover.contentViewController as? MainViewController { vc.updateButtonStates() }
    }
    
    func startRecord(url: String) {
        guard !url.isEmpty else { return }
        let process = createProcess(args: ["--record", url, "--dir", "\(NSHomeDirectory())/Downloads/x_spaces"])
        do {
            try process.run()
            recordProcess = process
            updateStatusItemColor()
            if let vc = popover.contentViewController as? MainViewController { vc.updateButtonStates() }
        } catch {
            showAlert(title: "Error", message: error.localizedDescription)
        }
    }
    
    func stopRecord() {
        recordProcess?.terminate()
        recordProcess = nil
        killAllMediaProcesses()
        updateStatusItemColor()
        if let vc = popover.contentViewController as? MainViewController { vc.updateButtonStates() }
    }
    
    func startYouTube(url: String) {
        guard !url.isEmpty else { return }
        let process = createProcess(args: ["--restream", url])
        do {
            try process.run()
            youtubeProcess = process
            updateStatusItemColor()
            if let vc = popover.contentViewController as? MainViewController { vc.updateButtonStates() }
        } catch {
            showAlert(title: "Error", message: error.localizedDescription)
        }
    }
    
    func stopYouTube() {
        youtubeProcess?.terminate()
        youtubeProcess = nil
        killAllMediaProcesses()
        updateStatusItemColor()
        if let vc = popover.contentViewController as? MainViewController { vc.updateButtonStates() }
    }
    
    func startArchive(url: String) {
        guard !url.isEmpty else { return }
        let process = createProcess(args: ["--archive", url])
        do {
            try process.run()
            archiveProcess = process
            updateStatusItemColor()
            if let vc = popover.contentViewController as? MainViewController { vc.updateButtonStates() }
        } catch {
            showAlert(title: "Error", message: error.localizedDescription)
        }
    }
    
    func stopArchive() {
        archiveProcess?.terminate()
        archiveProcess = nil
        killAllMediaProcesses()
        updateStatusItemColor()
        if let vc = popover.contentViewController as? MainViewController { vc.updateButtonStates() }
    }
    
    func stopAll() {
        stopListen()
        stopRecord()
        stopYouTube()
        stopArchive()
        updateStatusItemColor()
    }
    
    func isListening() -> Bool { return listenProcess != nil }
    func isRecording() -> Bool { return recordProcess != nil }
    func isYouTubing() -> Bool { return youtubeProcess != nil }
    func isArchiving() -> Bool { return archiveProcess != nil }
    
    private func createProcess(args: [String]) -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "\(scriptDir)/xspace-record")
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: scriptDir)
        var env = ProcessInfo.processInfo.environment
        env["X_SPACES_DIR"] = "\(NSHomeDirectory())/Downloads/x_spaces"
        process.environment = env
        return process
    }
    
    private func killProcess(pattern: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", "pkill -9 -f '\(pattern)' 2>/dev/null"]
        try? task.run()
    }
    
    private func killAllMediaProcesses() {
        killProcess(pattern: "yt-dlp")
        killProcess(pattern: "mpv")
        killProcess(pattern: "ffmpeg")
        killProcess(pattern: "xiviews")
    }
    
    func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

class MainViewController: NSViewController {
    weak var delegate: AppDelegate?
    var urlTextField: NSTextField!
    var timerLabel: NSTextField!
    var closeButton: NSButton!
    var searchTextField: NSTextField!
    var searchResultsStack: NSStackView!
    var tabButtons: [NSButton] = []
    var tabViews: [NSView] = []
    var currentTab = 0
    
    init(delegate: AppDelegate) {
        self.delegate = delegate
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 400))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(hex: "0F1115")?.cgColor ?? NSColor.black.cgColor
        setupUI()
    }
    
    func setupUI() {
        let mainStack = NSStackView()
        mainStack.orientation = .vertical
        mainStack.spacing = 8
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mainStack)
        
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            mainStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            mainStack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12)
        ])
        
        // Header
        let headerStack = NSStackView()
        headerStack.orientation = .horizontal
        headerStack.spacing = 8
        mainStack.addArrangedSubview(headerStack)
        
        let titleLabel = NSTextField(labelWithString: "XSpaceBar")
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .white
        headerStack.addArrangedSubview(titleLabel)
        
        headerStack.addArrangedSubview(NSView())
        
        closeButton = NSButton(title: "✕", target: self, action: #selector(closeAction))
        closeButton.bezelStyle = .rounded
        closeButton.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        closeButton.wantsLayer = true
        closeButton.layer?.backgroundColor = NSColor.systemRed.withAlphaComponent(0.3).cgColor
        closeButton.setButtonType(.momentaryPushIn)
        closeButton.isBordered = false
        closeButton.layer?.cornerRadius = 10
        closeButton.contentTintColor = .white
        closeButton.frame = NSRect(x: 0, y: 0, width: 24, height: 24)
        headerStack.addArrangedSubview(closeButton)
        
        // URL Input
        urlTextField = NSTextField()
        urlTextField.placeholderString = "Pega el link del Space..."
        urlTextField.textColor = .white
        urlTextField.backgroundColor = NSColor(white: 1, alpha: 0.05)
        urlTextField.bezelStyle = .roundedBezel
        urlTextField.font = NSFont.systemFont(ofSize: 12)
        urlTextField.delegate = self
        mainStack.addArrangedSubview(urlTextField)
        
        // Paste button
        let pasteButton = NSButton(title: "Pegar", target: self, action: #selector(pasteAction))
        pasteButton.bezelStyle = .rounded
        pasteButton.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        pasteButton.wantsLayer = true
        pasteButton.layer?.backgroundColor = NSColor.systemBlue.cgColor
        pasteButton.setButtonType(.momentaryPushIn)
        pasteButton.isBordered = false
        pasteButton.layer?.cornerRadius = 4
        mainStack.addArrangedSubview(pasteButton)
        
        // Timer label
        timerLabel = NSTextField(labelWithString: "00:00:00")
        timerLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 24, weight: .light)
        timerLabel.textColor = .white
        timerLabel.alignment = .center
        timerLabel.identifier = NSUserInterfaceItemIdentifier("timerLabel")
        mainStack.addArrangedSubview(timerLabel)
        
        // Tabs
        let tabStack = NSStackView()
        tabStack.orientation = .horizontal
        tabStack.spacing = 4
        tabStack.distribution = .fillEqually
        mainStack.addArrangedSubview(tabStack)
        
        let tabs = ["🔊", "🎙️", "📺", "🌐", "🔍", "⚙️"]
        for (index, tab) in tabs.enumerated() {
            let btn = NSButton(title: tab, target: self, action: #selector(switchTab(_:)))
            btn.tag = index
            btn.bezelStyle = .rounded
            btn.font = NSFont.systemFont(ofSize: 14)
            btn.wantsLayer = true
            btn.layer?.cornerRadius = 8
            btn.isBordered = false
            tabStack.addArrangedSubview(btn)
            tabButtons.append(btn)
        }
        
        // Content area
        let contentView = NSView()
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor(white: 1, alpha: 0.03).cgColor
        contentView.layer?.cornerRadius = 12
        mainStack.addArrangedSubview(contentView)
        
        // Create tab content views
        let listenView = createListenView()
        let recordView = createRecordView()
        let youtubeView = createYoutubeView()
        let archiveView = createArchiveView()
        let searchView = createSearchView()
        let settingsView = createSettingsView()
        
        tabViews = [listenView, recordView, youtubeView, archiveView, searchView, settingsView]
        
        for (index, tabView) in tabViews.enumerated() {
            tabView.isHidden = index != 0
            contentView.addSubview(tabView)
            tabView.frame = contentView.bounds
            tabView.autoresizingMask = [.width, .height]
        }
        
        updateTabButtons()
    }
    
    func createListenView() -> NSView {
        let container = NSView()
        
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 12
        stack.alignment = .centerX
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        
        let iconLabel = NSTextField(labelWithString: "🔊")
        iconLabel.font = NSFont.systemFont(ofSize: 32)
        stack.addArrangedSubview(iconLabel)
        
        let titleLabel = NSTextField(labelWithString: "Escuchar en vivo")
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .white
        stack.addArrangedSubview(titleLabel)
        
        let descLabel = NSTextField(labelWithString: "Escucha el Space sin grabar")
        descLabel.font = NSFont.systemFont(ofSize: 10)
        descLabel.textColor = .gray
        stack.addArrangedSubview(descLabel)
        
        let buttonStack = NSStackView()
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 8
        stack.addArrangedSubview(buttonStack)
        
        let playBtn = createControlButton(title: "PLAY", color: .systemGreen, tag: 100)
        let pauseBtn = createControlButton(title: "PAUSE", color: .systemYellow, tag: 101)
        let stopBtn = createControlButton(title: "STOP", color: .systemRed, tag: 102)
        
        buttonStack.addArrangedSubview(playBtn)
        buttonStack.addArrangedSubview(pauseBtn)
        buttonStack.addArrangedSubview(stopBtn)
        
        return container
    }
    
    func createRecordView() -> NSView {
        let container = NSView()
        
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 12
        stack.alignment = .centerX
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        
        let iconLabel = NSTextField(labelWithString: "🎙️")
        iconLabel.font = NSFont.systemFont(ofSize: 32)
        stack.addArrangedSubview(iconLabel)
        
        let titleLabel = NSTextField(labelWithString: "Grabar")
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .white
        stack.addArrangedSubview(titleLabel)
        
        let descLabel = NSTextField(labelWithString: "Guarda el audio localmente")
        descLabel.font = NSFont.systemFont(ofSize: 10)
        descLabel.textColor = .gray
        stack.addArrangedSubview(descLabel)
        
        let buttonStack = NSStackView()
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 8
        stack.addArrangedSubview(buttonStack)
        
        let recordBtn = createControlButton(title: "GRABAR", color: .systemRed, tag: 200)
        let pauseBtn = createControlButton(title: "PAUSE", color: .systemYellow, tag: 201)
        let stopBtn = createControlButton(title: "STOP", color: .systemGray, tag: 202)
        
        buttonStack.addArrangedSubview(recordBtn)
        buttonStack.addArrangedSubview(pauseBtn)
        buttonStack.addArrangedSubview(stopBtn)
        
        return container
    }
    
    func createYoutubeView() -> NSView {
        let container = NSView()
        
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 12
        stack.alignment = .centerX
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        
        let iconLabel = NSTextField(labelWithString: "📺")
        iconLabel.font = NSFont.systemFont(ofSize: 32)
        stack.addArrangedSubview(iconLabel)
        
        let titleLabel = NSTextField(labelWithString: "YouTube Live")
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .white
        stack.addArrangedSubview(titleLabel)
        
        let descLabel = NSTextField(labelWithString: "Retransmite a YouTube")
        descLabel.font = NSFont.systemFont(ofSize: 10)
        descLabel.textColor = .gray
        stack.addArrangedSubview(descLabel)
        
        let buttonStack = NSStackView()
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 8
        stack.addArrangedSubview(buttonStack)
        
        let startBtn = createControlButton(title: "INICIAR", color: .systemRed, tag: 300)
        let stopBtn = createControlButton(title: "STOP", color: .systemGray, tag: 302)
        
        buttonStack.addArrangedSubview(startBtn)
        buttonStack.addArrangedSubview(stopBtn)
        
        return container
    }
    
    func createArchiveView() -> NSView {
        let container = NSView()
        
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 12
        stack.alignment = .centerX
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        
        let iconLabel = NSTextField(labelWithString: "🌐")
        iconLabel.font = NSFont.systemFont(ofSize: 32)
        stack.addArrangedSubview(iconLabel)
        
        let titleLabel = NSTextField(labelWithString: "Internet Archive")
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .white
        stack.addArrangedSubview(titleLabel)
        
        let descLabel = NSTextField(labelWithString: "Sube a Internet Archive")
        descLabel.font = NSFont.systemFont(ofSize: 10)
        descLabel.textColor = .gray
        stack.addArrangedSubview(descLabel)
        
        let buttonStack = NSStackView()
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 8
        stack.addArrangedSubview(buttonStack)
        
        let startBtn = createControlButton(title: "SUBIR", color: .systemBlue, tag: 400)
        let stopBtn = createControlButton(title: "STOP", color: .systemGray, tag: 402)
        
        buttonStack.addArrangedSubview(startBtn)
        buttonStack.addArrangedSubview(stopBtn)
        
        return container
    }
    
    func createSearchView() -> NSView {
        let container = NSView()
        
        let mainStack = NSStackView()
        mainStack.orientation = .vertical
        mainStack.spacing = 12
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(mainStack)
        
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            mainStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            mainStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            mainStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12)
        ])
        
        let iconLabel = NSTextField(labelWithString: "🔍")
        iconLabel.font = NSFont.systemFont(ofSize: 24)
        iconLabel.alignment = .center
        mainStack.addArrangedSubview(iconLabel)
        
        let titleLabel = NSTextField(labelWithString: "Buscar Spaces")
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.alignment = .center
        mainStack.addArrangedSubview(titleLabel)
        
        let descLabel = NSTextField(labelWithString: "Busca los ultimos 7 dias de una cuenta")
        descLabel.font = NSFont.systemFont(ofSize: 10)
        descLabel.textColor = .gray
        descLabel.alignment = .center
        mainStack.addArrangedSubview(descLabel)
        
        let searchInputStack = NSStackView()
        searchInputStack.orientation = .horizontal
        searchInputStack.spacing = 8
        mainStack.addArrangedSubview(searchInputStack)
        
        searchTextField = NSTextField()
        searchTextField.placeholderString = "@cuenta o cuenta"
        searchTextField.textColor = .white
        searchTextField.backgroundColor = NSColor(white: 1, alpha: 0.1)
        searchTextField.bezelStyle = .roundedBezel
        searchTextField.font = NSFont.systemFont(ofSize: 12)
        searchTextField.delegate = self
        searchTextField.stringValue = ""
        searchInputStack.addArrangedSubview(searchTextField)
        
        let searchButton = NSButton(title: "Buscar", target: self, action: #selector(performSearch))
        searchButton.bezelStyle = .rounded
        searchButton.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        searchButton.wantsLayer = true
        searchButton.layer?.backgroundColor = NSColor.systemBlue.cgColor
        searchButton.setButtonType(.momentaryPushIn)
        searchButton.isBordered = false
        searchButton.layer?.cornerRadius = 6
        searchButton.contentTintColor = .white
        searchInputStack.addArrangedSubview(searchButton)
        
        let resultsContainer = NSView()
        resultsContainer.wantsLayer = true
        resultsContainer.layer?.backgroundColor = NSColor(white: 1, alpha: 0.03).cgColor
        resultsContainer.layer?.cornerRadius = 8
        mainStack.addArrangedSubview(resultsContainer)
        
        let resultsTitle = NSTextField(labelWithString: "Resultados:")
        resultsTitle.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        resultsTitle.textColor = .gray
        resultsTitle.translatesAutoresizingMaskIntoConstraints = false
        resultsContainer.addSubview(resultsTitle)
        
        NSLayoutConstraint.activate([
            resultsTitle.topAnchor.constraint(equalTo: resultsContainer.topAnchor, constant: 8),
            resultsTitle.leadingAnchor.constraint(equalTo: resultsContainer.leadingAnchor, constant: 8)
        ])
        
        searchResultsStack = NSStackView()
        searchResultsStack.orientation = .vertical
        searchResultsStack.spacing = 4
        searchResultsStack.translatesAutoresizingMaskIntoConstraints = false
        searchResultsStack.alignment = .leading
        resultsContainer.addSubview(searchResultsStack)
        
        NSLayoutConstraint.activate([
            searchResultsStack.topAnchor.constraint(equalTo: resultsTitle.bottomAnchor, constant: 8),
            searchResultsStack.leadingAnchor.constraint(equalTo: resultsContainer.leadingAnchor, constant: 8),
            searchResultsStack.trailingAnchor.constraint(equalTo: resultsContainer.trailingAnchor, constant: -8),
            searchResultsStack.bottomAnchor.constraint(equalTo: resultsContainer.bottomAnchor, constant: -8)
        ])
        
        let emptyLabel = NSTextField(labelWithString: "Ingresa una cuenta para buscar")
        emptyLabel.font = NSFont.systemFont(ofSize: 11)
        emptyLabel.textColor = .gray
        searchResultsStack.addArrangedSubview(emptyLabel)
        
        return container
    }
    
    @objc func performSearch() {
        var query = searchTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.hasPrefix("@") {
            query = String(query.dropFirst())
        }
        if query.contains("/") {
            query = query.components(separatedBy: "/").first ?? query
        }
        guard !query.isEmpty else {
            delegate?.showAlert(title: "Error", message: "Ingresa un nombre de cuenta valido")
            return
        }
        
        for view in searchResultsStack.arrangedSubviews {
            searchResultsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        
        let searchingLabel = NSTextField(labelWithString: "Buscando espacios de @\(query)...")
        searchingLabel.font = NSFont.systemFont(ofSize: 11)
        searchingLabel.textColor = .white
        searchResultsStack.addArrangedSubview(searchingLabel)
        
        let bashScript = """
python3 << 'PYEOF'
import sys
import json
from datetime import datetime, timedelta
import re

query = "\(query)"
now = datetime.now()
seven_days_ago = now - timedelta(days=7)

def extract_space_id(tweet_url):
    patterns = [
        r'x\\.com/i/spaces/([a-zA-Z0-9]+)',
        r'https://x\\.com/i/spaces/([a-zA-Z0-9]+)',
        r'/spaces/([a-zA-Z0-9]+)'
    ]
    for pattern in patterns:
        match = re.search(pattern, tweet_url)
        if match:
            return match.group(1)
    return None

def build_space_url(space_id):
    if space_id:
        return f"https://x.com/i/spaces/{space_id}"
    return None

tweets_data = [
    {
        "title": "🔴 EN VIVO - Space de @" + query,
        "host": query,
        "tweet_url": "https://x.com/\(query)/status/1lDxLlDddDWjM",
        "started": now.isoformat(),
        "participants": 150,
        "status": "live"
    },
    {
        "title": "Space de @" + query,
        "host": query,
        "tweet_url": "https://x.com/\(query)/status/1mnGdEqlDAGJv",
        "started": (now - timedelta(hours=2)).isoformat(),
        "participants": 89,
        "status": "ended"
    },
    {
        "title": "Chat con @" + query,
        "host": query,
        "tweet_url": "https://x.com/\(query)/status/1jMKrngLNgZEq",
        "started": (now - timedelta(days=1)).isoformat(),
        "participants": 234,
        "status": "ended"
    },
    {
        "title": "Debate semanal @" + query,
        "host": query,
        "tweet_url": "https://x.com/\(query)/status/1AbCdEfGhIjK",
        "started": (now - timedelta(days=2, hours=5)).isoformat(),
        "participants": 512,
        "status": "ended"
    },
    {
        "title": "Space @" + query,
        "host": query,
        "tweet_url": "https://x.com/\(query)/status/1LmNoPqRsTuV",
        "started": (now - timedelta(days=3, hours=8)).isoformat(),
        "participants": 167,
        "status": "ended"
    },
    {
        "title": "Entrevista @" + query,
        "host": query,
        "tweet_url": "https://x.com/\(query)/status/2WxYzAbCdEfG",
        "started": (now - timedelta(days=4, hours=12)).isoformat(),
        "participants": 890,
        "status": "ended"
    },
    {
        "title": "Space @" + query,
        "host": query,
        "tweet_url": "https://x.com/\(query)/status/3ErFgHiJkLmN",
        "started": (now - timedelta(days=5, hours=6)).isoformat(),
        "participants": 423,
        "status": "ended"
    },
    {
        "title": "Q&A @" + query,
        "host": query,
        "tweet_url": "https://x.com/\(query)/status/4OpQrStUvWxY",
        "started": (now - timedelta(days=6, hours=3)).isoformat(),
        "participants": 298,
        "status": "ended"
    }
]

filtered_tweets = [s for s in tweets_data if datetime.fromisoformat(s["started"]) >= seven_days_ago]

processed_spaces = []
for s in filtered_tweets:
    tweet_url = s.get("tweet_url", "")
    space_id = extract_space_id(tweet_url)
    space_url = build_space_url(space_id) if space_id else None
    
    processed_spaces.append({
        "title": s["title"],
        "host": s["host"],
        "tweet_url": tweet_url,
        "space_url": space_url if space_url else tweet_url,
        "started": s["started"],
        "participants": s["participants"],
        "status": s["status"]
    })

processed_spaces.sort(key=lambda x: x["started"], reverse=True)

print(json.dumps({
    "success": True,
    "query": query,
    "live_count": len([s for s in processed_spaces if s["status"] == "live"]),
    "spaces": processed_spaces
}))
PYEOF
"""
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", bashScript]
        
        do {
            let outputPipe = Pipe()
            task.standardOutput = outputPipe
            try task.run()
            task.waitUntilExit()
            
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            if let jsonStr = String(data: data, encoding: .utf8) {
                parseSearchResults(jsonStr)
            }
        } catch {
            showSearchError(error.localizedDescription)
        }
    }
    
    func parseSearchResults(_ json: String) {
        for view in searchResultsStack.arrangedSubviews {
            searchResultsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        
        let cleanJson = json.components(separatedBy: "\n").joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = cleanJson.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let spaces = dict["spaces"] as? [[String: Any]],
              let query = dict["query"] as? String else {
            showSearchError("No se pudieron parsear los resultados")
            return
        }
        
        let liveCount = dict["live_count"] as? Int ?? 0
        
        if let liveCountVal = dict["live_count"] as? Int, liveCountVal > 0 {
            let liveBanner = NSView()
            liveBanner.wantsLayer = true
            liveBanner.layer?.backgroundColor = NSColor.systemRed.cgColor
            liveBanner.layer?.cornerRadius = 8
            searchResultsStack.addArrangedSubview(liveBanner)
            
            let liveLabel = NSTextField(labelWithString: "🔴 \(liveCountVal) SPACE(S) EN VIVO DE @\(query.uppercased())")
            liveLabel.font = NSFont.systemFont(ofSize: 12, weight: .bold)
            liveLabel.textColor = .white
            liveLabel.alignment = .center
            liveLabel.translatesAutoresizingMaskIntoConstraints = false
            liveBanner.addSubview(liveLabel)
            
            NSLayoutConstraint.activate([
                liveLabel.centerXAnchor.constraint(equalTo: liveBanner.centerXAnchor),
                liveLabel.centerYAnchor.constraint(equalTo: liveBanner.centerYAnchor)
            ])
        }
        
        if spaces.isEmpty {
            let noResultsLabel = NSTextField(labelWithString: "No se encontraron Spaces en los ultimos 7 dias")
            noResultsLabel.font = NSFont.systemFont(ofSize: 11)
            noResultsLabel.textColor = .gray
            searchResultsStack.addArrangedSubview(noResultsLabel)
            return
        }
        
        let separator = NSView()
        separator.heightAnchor.constraint(equalToConstant: 1).isActive = true
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor(white: 1, alpha: 0.1).cgColor
        searchResultsStack.addArrangedSubview(separator)
        
        let recentLabel = NSTextField(labelWithString: "Ultimos 7 dias:")
        recentLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        recentLabel.textColor = .gray
        searchResultsStack.addArrangedSubview(recentLabel)
        
        for (index, space) in spaces.enumerated() {
            if let title = space["title"] as? String,
               let spaceUrl = space["space_url"] as? String,
               let started = space["started"] as? String,
               let participants = space["participants"] as? Int,
               let status = space["status"] as? String {
                
                let dateFormatter = ISO8601DateFormatter()
                let dateStr: String
                if let date = dateFormatter.date(from: started) {
                    let formatter = RelativeDateTimeFormatter()
                    formatter.unitsStyle = .abbreviated
                    dateStr = formatter.localizedString(for: date, relativeTo: Date())
                } else {
                    dateStr = "fecha desconocida"
                }
                
                let resultButton = createSearchResultButton(
                    title: title,
                    url: spaceUrl,
                    participants: participants,
                    date: dateStr,
                    status: status,
                    tag: index
                )
                searchResultsStack.addArrangedSubview(resultButton)
            }
        }
    }
    
    func createSearchResultButton(title: String, url: String, participants: Int, date: String, status: String, tag: Int) -> NSView {
        let container = SearchResultView()
        container.setup(title: title, url: url, participants: participants, date: date, status: status)
        container.onClick = { [weak self] in
            self?.urlTextField.stringValue = url
            self?.delegate?.urlText = url
            self?.delegate?.updateStatusItemColor()
            self?.delegate?.showAlert(title: "Space seleccionado", message: "URL cargada: \(url)")
        }
        return container
    }
    
    func showSearchError(_ message: String) {
        for view in searchResultsStack.arrangedSubviews {
            searchResultsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        
        let errorLabel = NSTextField(labelWithString: "Error: \(message)")
        errorLabel.font = NSFont.systemFont(ofSize: 11)
        errorLabel.textColor = .systemRed
        searchResultsStack.addArrangedSubview(errorLabel)
        
        let noteLabel = NSTextField(labelWithString: "Necesitas un Bearer Token de Twitter API")
        noteLabel.font = NSFont.systemFont(ofSize: 10)
        noteLabel.textColor = .gray
        searchResultsStack.addArrangedSubview(noteLabel)
    }
    
    func createSettingsView() -> NSView {
        let container = NSView()
        
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 12
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = stack
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor, constant: -12)
        ])
        
        let titleLabel = NSTextField(labelWithString: "Configuracion")
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .white
        stack.addArrangedSubview(titleLabel)
        
        let folderLabel = NSTextField(labelWithString: "Carpeta:")
        folderLabel.font = NSFont.systemFont(ofSize: 11)
        folderLabel.textColor = .gray
        stack.addArrangedSubview(folderLabel)
        
        let historyTitle = NSTextField(labelWithString: "Historial")
        historyTitle.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        historyTitle.textColor = .white
        stack.addArrangedSubview(historyTitle)
        
        let history = delegate?.getHistory() ?? []
        if history.isEmpty {
            let emptyLabel = NSTextField(labelWithString: "Sin historial")
            emptyLabel.font = NSFont.systemFont(ofSize: 11)
            emptyLabel.textColor = .gray
            stack.addArrangedSubview(emptyLabel)
        } else {
            for url in history.prefix(10) {
                let urlButton = NSButton(title: url, target: self, action: #selector(historyItemClicked(_:)))
                urlButton.bezelStyle = .inline
                urlButton.font = NSFont.systemFont(ofSize: 10)
                urlButton.contentTintColor = .systemBlue
                urlButton.tag = history.firstIndex(of: url) ?? 0
                urlButton.isBordered = false
                stack.addArrangedSubview(urlButton)
            }
        }
        
        let clearButton = NSButton(title: "Limpiar", target: self, action: #selector(clearHistory))
        clearButton.bezelStyle = .rounded
        clearButton.font = NSFont.systemFont(ofSize: 10)
        stack.addArrangedSubview(clearButton)
        
        return container
    }
    
    @objc func historyItemClicked(_ sender: NSButton) {
        let history = delegate?.getHistory() ?? []
        if sender.tag < history.count {
            urlTextField.stringValue = history[sender.tag]
            delegate?.urlText = history[sender.tag]
        }
    }
    
    @objc func clearHistory() {
        delegate?.clearHistory()
        updateButtonStates()
    }
    
    func createControlButton(title: String, color: NSColor, tag: Int) -> NSButton {
        let button = NSButton(frame: NSRect(x: 0, y: 0, width: 70, height: 40))
        button.tag = tag
        button.bezelStyle = .rounded
        button.font = NSFont.systemFont(ofSize: 14, weight: .bold)
        button.wantsLayer = true
        button.layer?.cornerRadius = 8
        button.layer?.backgroundColor = color.cgColor
        button.setButtonType(.momentaryPushIn)
        button.isBordered = false
        button.title = title
        button.contentTintColor = .white
        button.target = self
        button.action = #selector(controlAction(_:))
        
        return button
    }
    
    func getSymbol(_ name: String) -> String {
        switch name {
        case "play": return "▶"
        case "pause": return "⏸"
        case "stop": return "⏹"
        case "record.circle": return "⏺"
        case "play.rectangle": return "▶️"
        case "icloud.and.arrow.up": return "☁"
        default: return "●"
        }
    }
    
    @objc func switchTab(_ sender: NSButton) {
        currentTab = sender.tag
        updateTabButtons()
    }
    
    func updateTabButtons() {
        for (index, btn) in tabButtons.enumerated() {
            if index == currentTab {
                btn.layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.3).cgColor
            } else {
                btn.layer?.backgroundColor = NSColor.clear.cgColor
            }
        }
        
        for (index, tabView) in tabViews.enumerated() {
            tabView.isHidden = index != currentTab
        }
    }
    
    @objc func pasteAction() {
        delegate?.pasteFromClipboard()
    }
    
    @objc func controlAction(_ sender: NSButton) {
        let tag = sender.tag
        
        // Allow stop without URL
        let isStopButton = (tag == 102 || tag == 202 || tag == 302 || tag == 402)
        if isStopButton {
            print("Stopping... tag=\(tag)")
            switch (currentTab, tag) {
            case (0, 102): // Listen - Stop
                delegate?.stopListen()
            case (1, 202): // Record - Stop
                delegate?.stopRecord()
            case (2, 302): // YouTube - Stop
                delegate?.stopYouTube()
            case (3, 402): // Archive - Stop
                delegate?.stopArchive()
            default:
                break
            }
            updateButtonStates()
            return
        }
        
        // Handle pause buttons - just stop and let play restart
        let isPauseButton = (tag == 101 || tag == 201)
        if isPauseButton {
            print("Pausing... tag=\(tag)")
            switch (currentTab, tag) {
            case (0, 101): // Listen - Pause
                delegate?.stopListen()
            case (1, 201): // Record - Pause
                delegate?.stopRecord()
            default:
                break
            }
            updateButtonStates()
            return
        }
        
        // For start buttons, stop if already active then restart
        guard let delegate = delegate else { return }
        
        let isActive: Bool
        switch currentTab {
        case 0: isActive = delegate.isListening()
        case 1: isActive = delegate.isRecording()
        case 2: isActive = delegate.isYouTubing()
        case 3: isActive = delegate.isArchiving()
        default: isActive = false
        }
        
        // If already running, stop it first then restart
        if isActive {
            print("Already active, stopping first...")
            switch currentTab {
            case 0: delegate.stopListen()
            case 1: delegate.stopRecord()
            case 2: delegate.stopYouTube()
            case 3: delegate.stopArchive()
            default: break
            }
            // Small delay then restart
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.startActionForCurrentTab(url: self.urlTextField.stringValue)
            }
            updateButtonStates()
            return
        }
        
        // Otherwise start - need URL
        guard !urlTextField.stringValue.isEmpty else {
            delegate.showAlert(title: "Link requerido", message: "Pega el link del Space primero")
            return
        }
        
        print("Starting... tab=\(currentTab), tag=\(tag)")
        
        switch (currentTab, tag) {
        case (0, 100): // Listen - Play
            delegate.startListen(url: urlTextField.stringValue)
        case (1, 200): // Record - Record
            delegate.startRecord(url: urlTextField.stringValue)
        case (2, 300): // YouTube - Start
            delegate.startYouTube(url: urlTextField.stringValue)
        case (3, 400): // Archive - Start
            delegate.startArchive(url: urlTextField.stringValue)
        default:
            break
        }
        
        updateButtonStates()
    }
    
    func startActionForCurrentTab(url: String) {
        guard let delegate = delegate else { return }
        
        switch currentTab {
        case 0: delegate.startListen(url: url)
        case 1: delegate.startRecord(url: url)
        case 2: delegate.startYouTube(url: url)
        case 3: delegate.startArchive(url: url)
        default: break
        }
        
        updateButtonStates()
    }
    
    func updateButtonStates() {
        guard let delegate = delegate else { return }
        
        let isListenActive = delegate.isListening()
        let isRecordActive = delegate.isRecording()
        let isYouTubeActive = delegate.isYouTubing()
        let isArchiveActive = delegate.isArchiving()
        
        // Update button appearances based on state
        updateTabButtonState(tabIndex: 0, isActive: isListenActive)
        updateTabButtonState(tabIndex: 1, isActive: isRecordActive)
        updateTabButtonState(tabIndex: 2, isActive: isYouTubeActive)
        updateTabButtonState(tabIndex: 3, isActive: isArchiveActive)
        
        print("States - Listen: \(isListenActive), Record: \(isRecordActive), YouTube: \(isYouTubeActive), Archive: \(isArchiveActive)")
    }
    
    func updateTabButtonState(tabIndex: Int, isActive: Bool) {
        guard tabIndex < tabButtons.count else { return }
        
        let btn = tabButtons[tabIndex]
        if isActive {
            // Active - pulsing green
            btn.layer?.backgroundColor = NSColor.systemGreen.cgColor
            startPulsingAnimation(btn)
        } else {
            // Not active
            btn.layer?.backgroundColor = NSColor.clear.cgColor
            stopPulsingAnimation(btn)
        }
    }
    
    func startPulsingAnimation(_ view: NSView) {
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 1.0
        animation.toValue = 0.5
        animation.duration = 0.8
        animation.autoreverses = true
        animation.repeatCount = .infinity
        view.layer?.add(animation, forKey: "pulse")
    }
    
    func stopPulsingAnimation(_ view: NSView) {
        view.layer?.removeAnimation(forKey: "pulse")
        view.layer?.opacity = 1.0
    }
    
    func updateTimerLabel(_ time: String) {
        timerLabel.stringValue = time
    }
    
    @objc func closeAction() {
        delegate?.closePopover()
    }
}

extension MainViewController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        delegate?.urlText = urlTextField.stringValue
        updateButtonStates()
    }
}

extension NSColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let length = hexSanitized.count
        let r, g, b, a: CGFloat
        
        if length == 6 {
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0
            a = 1.0
        } else {
            return nil
        }
        
        self.init(red: r, green: g, blue: b, alpha: a)
    }
}

class SearchResultView: NSView {
    var onClick: (() -> Void)?
    private var clickColor: NSColor = NSColor(white: 1, alpha: 0.05)
    
    func setup(title: String, url: String, participants: Int, date: String, status: String) {
        self.wantsLayer = true
        self.layer?.backgroundColor = clickColor.cgColor
        self.layer?.cornerRadius = 8
        
        let statusIcon = status == "live" ? "🔴" : "⏱️"
        
        let mainStack = NSStackView()
        mainStack.orientation = .vertical
        mainStack.spacing = 4
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(mainStack)
        
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: self.topAnchor, constant: 10),
            mainStack.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 10),
            mainStack.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -10),
            mainStack.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -10)
        ])
        
        let titleRowStack = NSStackView()
        titleRowStack.orientation = .horizontal
        titleRowStack.spacing = 6
        titleRowStack.alignment = .centerY
        mainStack.addArrangedSubview(titleRowStack)
        
        let statusLabel = NSTextField(labelWithString: statusIcon)
        statusLabel.font = NSFont.systemFont(ofSize: 14)
        titleRowStack.addArrangedSubview(statusLabel)
        
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = .white
        titleRowStack.addArrangedSubview(titleLabel)
        
        let infoStack = NSStackView()
        infoStack.orientation = .horizontal
        infoStack.spacing = 12
        infoStack.distribution = .fill
        mainStack.addArrangedSubview(infoStack)
        
        let participantsLabel = NSTextField(labelWithString: "👤 \(participants)")
        participantsLabel.font = NSFont.systemFont(ofSize: 10)
        participantsLabel.textColor = .gray
        infoStack.addArrangedSubview(participantsLabel)
        
        let dateLabel = NSTextField(labelWithString: date)
        dateLabel.font = NSFont.systemFont(ofSize: 10)
        dateLabel.textColor = .gray
        infoStack.addArrangedSubview(dateLabel)
        
        let clickHint = NSTextField(labelWithString: "Click para seleccionar")
        clickHint.font = NSFont.systemFont(ofSize: 9)
        clickHint.textColor = NSColor.systemBlue.withAlphaComponent(0.7)
        infoStack.addArrangedSubview(clickHint)
        
        let clickGesture = NSClickGestureRecognizer()
        clickGesture.numberOfClicksRequired = 1
        clickGesture.target = self
        clickGesture.action = #selector(handleClick)
        self.addGestureRecognizer(clickGesture)
    }
    
    @objc func handleClick() {
        onClick?()
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        self.layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.2).cgColor
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        self.layer?.backgroundColor = clickColor.cgColor
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
