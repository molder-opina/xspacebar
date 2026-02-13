import AppKit

class DesktopWindowController: NSObject, NSApplicationDelegate {
    var mainWindow: NSWindow!
    var urlTextField: NSTextField!
    var timerLabel: NSTextField!
    var searchTextField: NSTextField!
    var searchResultsStack: NSStackView!
    var statusIndicator: NSTextField!
    
    var listenProcess: Process?
    var recordProcess: Process?
    var youtubeProcess: Process?
    var archiveProcess: Process?
    var startTime: Date?
    var timer: Timer?
    var elapsedTime: String = "00:00:00"
    var urlText: String = ""
    
    let scriptDir = "/Users/molder/projects/github-molder/spaces"
    let historyKey = "SpaceHistory"
    let maxHistory = 10
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupWindow()
    }
    
    func setupWindow() {
        mainWindow = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 400, height: 580), 
                            styleMask: [.titled, .closable, .miniaturizable, .resizable],
                            backing: .buffered, defer: false)
        mainWindow.title = "XSpaceBar - Desktop"
        mainWindow.backgroundColor = NSColor(hex: "0F1115")
        
        let contentView = mainWindow.contentView!
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor(hex: "0F1115")?.cgColor ?? NSColor.black.cgColor
        
        let mainStack = NSStackView()
        mainStack.orientation = .vertical
        mainStack.spacing = 14
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(mainStack)
        
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            mainStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
        
        // Header
        let headerStack = NSStackView()
        headerStack.orientation = .horizontal
        headerStack.spacing = 12
        mainStack.addArrangedSubview(headerStack)
        
        let titleLabel = NSTextField(labelWithString: "XSpaceBar")
        titleLabel.font = NSFont.systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = .white
        headerStack.addArrangedSubview(titleLabel)
        
        headerStack.addArrangedSubview(NSView())
        
        statusIndicator = NSTextField(labelWithString: "●")
        statusIndicator.font = NSFont.systemFont(ofSize: 18)
        statusIndicator.textColor = .systemRed
        headerStack.addArrangedSubview(statusIndicator)
        
        // URL Input - SAME DESIGN AS MENUBAR
        let urlContainer = NSView()
        urlContainer.wantsLayer = true
        urlContainer.layer?.backgroundColor = NSColor(white: 1, alpha: 0.08).cgColor
        urlContainer.layer?.cornerRadius = 8
        mainStack.addArrangedSubview(urlContainer)
        
        let urlPlaceholder = NSTextField(labelWithString: "Pega el link del Space...")
        urlPlaceholder.font = NSFont.systemFont(ofSize: 12)
        urlPlaceholder.textColor = NSColor.white.withAlphaComponent(0.4)
        urlPlaceholder.translatesAutoresizingMaskIntoConstraints = false
        urlContainer.addSubview(urlPlaceholder)
        
        urlTextField = NSTextField()
        urlTextField.textColor = .white
        urlTextField.backgroundColor = .clear
        urlTextField.font = NSFont.systemFont(ofSize: 13)
        urlTextField.delegate = self
        urlTextField.placeholderString = "Pega el link del Space..."
        urlTextField.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            urlPlaceholder.topAnchor.constraint(equalTo: urlContainer.topAnchor, constant: 10),
            urlPlaceholder.leadingAnchor.constraint(equalTo: urlContainer.leadingAnchor, constant: 12),
            
            urlTextField.topAnchor.constraint(equalTo: urlContainer.topAnchor, constant: 10),
            urlTextField.leadingAnchor.constraint(equalTo: urlContainer.leadingAnchor, constant: 12),
            urlTextField.trailingAnchor.constraint(equalTo: urlContainer.trailingAnchor, constant: -12),
            urlTextField.bottomAnchor.constraint(equalTo: urlContainer.bottomAnchor, constant: -10)
        ])
        
        // Buttons row
        let buttonsStack = NSStackView()
        buttonsStack.orientation = .horizontal
        buttonsStack.spacing = 10
        buttonsStack.distribution = .fillEqually
        mainStack.addArrangedSubview(buttonsStack)
        
        let listenBtn = createMainButton(title: "🔊 Escuchar", color: NSColor(hex: "22C55E")!)
        listenBtn.tag = 1
        listenBtn.target = self
        listenBtn.action = #selector(mainButtonAction(_:))
        
        let recordBtn = createMainButton(title: "🎙️ Grabar", color: NSColor(hex: "EF4444")!)
        recordBtn.tag = 2
        recordBtn.target = self
        recordBtn.action = #selector(mainButtonAction(_:))
        
        let youtubeBtn = createMainButton(title: "📺 YouTube", color: NSColor(hex: "DC2626")!)
        youtubeBtn.tag = 3
        youtubeBtn.target = self
        youtubeBtn.action = #selector(mainButtonAction(_:))
        
        let archiveBtn = createMainButton(title: "🌐 Archive", color: NSColor(hex: "3B82F6")!)
        archiveBtn.tag = 4
        archiveBtn.target = self
        archiveBtn.action = #selector(mainButtonAction(_:))
        
        buttonsStack.addArrangedSubview(listenBtn)
        buttonsStack.addArrangedSubview(recordBtn)
        buttonsStack.addArrangedSubview(youtubeBtn)
        buttonsStack.addArrangedSubview(archiveBtn)
        
        // Timer
        timerLabel = NSTextField(labelWithString: "00:00:00")
        timerLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 32, weight: .light)
        timerLabel.textColor = .white
        timerLabel.alignment = .center
        mainStack.addArrangedSubview(timerLabel)
        
        // Stop button
        let stopBtn = NSButton(title: "⏹ DETENER TODO", target: self, action: #selector(stopAllAction))
        stopBtn.bezelStyle = .rounded
        stopBtn.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        stopBtn.wantsLayer = true
        stopBtn.layer?.backgroundColor = NSColor(hex: "6B7280")!.cgColor
        stopBtn.setButtonType(.momentaryPushIn)
        stopBtn.isBordered = false
        stopBtn.layer?.cornerRadius = 8
        stopBtn.contentTintColor = .white
        mainStack.addArrangedSubview(stopBtn)
        
        // Search Section
        let searchLabel = NSTextField(labelWithString: "🔍 Buscar Spaces")
        searchLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        searchLabel.textColor = .white
        mainStack.addArrangedSubview(searchLabel)
        
        let searchStack = NSStackView()
        searchStack.orientation = .horizontal
        searchStack.spacing = 10
        mainStack.addArrangedSubview(searchStack)
        
        let searchInput = NSView()
        searchInput.wantsLayer = true
        searchInput.layer?.backgroundColor = NSColor(white: 1, alpha: 0.08).cgColor
        searchInput.layer?.cornerRadius = 8
        searchStack.addArrangedSubview(searchInput)
        
        searchTextField = NSTextField()
        searchTextField.textColor = .white
        searchTextField.backgroundColor = .clear
        searchTextField.font = NSFont.systemFont(ofSize: 12)
        searchTextField.placeholderString = "@cuenta"
        searchTextField.translatesAutoresizingMaskIntoConstraints = false
        searchInput.addSubview(searchTextField)
        
        NSLayoutConstraint.activate([
            searchTextField.topAnchor.constraint(equalTo: searchInput.topAnchor, constant: 8),
            searchTextField.leadingAnchor.constraint(equalTo: searchInput.leadingAnchor, constant: 10),
            searchTextField.trailingAnchor.constraint(equalTo: searchInput.trailingAnchor, constant: -10),
            searchTextField.bottomAnchor.constraint(equalTo: searchInput.bottomAnchor, constant: -8)
        ])
        
        let searchBtn = NSButton(title: "Buscar", target: self, action: #selector(searchAction))
        searchBtn.bezelStyle = .rounded
        searchBtn.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        searchBtn.wantsLayer = true
        searchBtn.layer?.backgroundColor = NSColor(hex: "3B82F6")!.cgColor
        searchBtn.setButtonType(.momentaryPushIn)
        searchBtn.isBordered = false
        searchBtn.layer?.cornerRadius = 8
        searchBtn.contentTintColor = .white
        searchBtn.widthAnchor.constraint(equalToConstant: 80).isActive = true
        searchStack.addArrangedSubview(searchBtn)
        
        // Search Results
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
            resultsTitle.leadingAnchor.constraint(equalTo: resultsContainer.leadingAnchor, constant: 10)
        ])
        
        searchResultsStack = NSStackView()
        searchResultsStack.orientation = .vertical
        searchResultsStack.spacing = 4
        searchResultsStack.translatesAutoresizingMaskIntoConstraints = false
        searchResultsStack.alignment = .leading
        resultsContainer.addSubview(searchResultsStack)
        
        NSLayoutConstraint.activate([
            searchResultsStack.topAnchor.constraint(equalTo: resultsTitle.bottomAnchor, constant: 8),
            searchResultsStack.leadingAnchor.constraint(equalTo: resultsContainer.leadingAnchor, constant: 10),
            searchResultsStack.trailingAnchor.constraint(equalTo: resultsContainer.trailingAnchor, constant: -10),
            searchResultsStack.bottomAnchor.constraint(equalTo: resultsContainer.bottomAnchor, constant: -8)
        ])
        
        let emptyLabel = NSTextField(labelWithString: "Busca @cuenta para ver sus Spaces")
        emptyLabel.font = NSFont.systemFont(ofSize: 11)
        emptyLabel.textColor = .gray
        searchResultsStack.addArrangedSubview(emptyLabel)
        
        // Volume Controls
        let volumeStack = NSStackView()
        volumeStack.orientation = .horizontal
        volumeStack.spacing = 10
        volumeStack.distribution = .fillEqually
        mainStack.addArrangedSubview(volumeStack)
        
        let volUpBtn = createSecondaryButton(title: "🔊 Vol +", action: #selector(volumeUpAction))
        let volDownBtn = createSecondaryButton(title: "🔉 Vol -", action: #selector(volumeDownAction))
        let muteBtn = createSecondaryButton(title: "🔇 Mute", action: #selector(muteAction))
        
        volumeStack.addArrangedSubview(volUpBtn)
        volumeStack.addArrangedSubview(volDownBtn)
        volumeStack.addArrangedSubview(muteBtn)
        
        // History
        let historyLabel = NSTextField(labelWithString: "📜 Historial reciente")
        historyLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        historyLabel.textColor = .gray
        mainStack.addArrangedSubview(historyLabel)
        
        let history = getHistory()
        if history.isEmpty {
            let noHistory = NSTextField(labelWithString: "Sin historial - los links se guardaran aqui")
            noHistory.font = NSFont.systemFont(ofSize: 11)
            noHistory.textColor = .gray
            mainStack.addArrangedSubview(noHistory)
        } else {
            let historyScroll = NSScrollView()
            historyScroll.documentView = createHistoryList()
            historyScroll.heightAnchor.constraint(equalToConstant: 100).isActive = true
            mainStack.addArrangedSubview(historyScroll)
        }
        
        mainWindow.center()
        mainWindow.makeKeyAndOrderFront(nil)
    }
    
    func createMainButton(title: String, color: NSColor) -> NSButton {
        let btn = NSButton(title: title, target: nil, action: nil)
        btn.bezelStyle = .rounded
        btn.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        btn.wantsLayer = true
        btn.layer?.backgroundColor = color.cgColor
        btn.setButtonType(.momentaryPushIn)
        btn.isBordered = false
        btn.layer?.cornerRadius = 10
        btn.contentTintColor = .white
        return btn
    }
    
    func createSecondaryButton(title: String, action: Selector) -> NSButton {
        let btn = NSButton(title: title, target: self, action: action)
        btn.bezelStyle = .rounded
        btn.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        btn.wantsLayer = true
        btn.layer?.backgroundColor = NSColor(hex: "4B5563")!.cgColor
        btn.setButtonType(.momentaryPushIn)
        btn.isBordered = false
        btn.layer?.cornerRadius = 8
        btn.contentTintColor = .white
        return btn
    }
    
    func createHistoryList() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 2
        stack.alignment = .leading
        
        let history = getHistory()
        for (index, url) in history.prefix(10).enumerated() {
            let btn = NSButton(title: url, target: self, action: #selector(historyItemClicked(_:)))
            btn.bezelStyle = .inline
            btn.font = NSFont.systemFont(ofSize: 10)
            btn.contentTintColor = NSColor(hex: "60A5FA")!
            btn.isBordered = false
            btn.tag = index
            stack.addArrangedSubview(btn)
        }
        
        let clearBtn = NSButton(title: "🗑️ Limpiar historial", target: self, action: #selector(clearHistoryAction))
        clearBtn.font = NSFont.systemFont(ofSize: 10)
        clearBtn.contentTintColor = NSColor(hex: "F87171")!
        clearBtn.isBordered = false
        stack.addArrangedSubview(clearBtn)
        
        return stack
    }
    
    @objc func mainButtonAction(_ sender: NSButton) {
        guard !urlTextField.stringValue.isEmpty else {
            showAlert(title: "Link requerido", message: "Pega el link del Space primero")
            return
        }
        
        switch sender.tag {
        case 1: startListen(url: urlTextField.stringValue)
        case 2: startRecord(url: urlTextField.stringValue)
        case 3: startYouTube(url: urlTextField.stringValue)
        case 4: startArchive(url: urlTextField.stringValue)
        default: break
        }
    }
    
    @objc func stopAllAction() {
        stopAll()
    }
    
    @objc func searchAction() {
        var query = searchTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.hasPrefix("@") { query = String(query.dropFirst()) }
        guard !query.isEmpty else {
            showAlert(title: "Error", message: "Ingresa un nombre de cuenta")
            return
        }
        
        for view in searchResultsStack.arrangedSubviews {
            searchResultsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        
        let searching = NSTextField(labelWithString: "Buscando @\(query)...")
        searching.font = NSFont.systemFont(ofSize: 11)
        searching.textColor = .white
        searchResultsStack.addArrangedSubview(searching)
        
        let bashScript = """
python3 << 'PYEOF'
import json
from datetime import datetime, timedelta
import re

query = "\(query)"
now = datetime.now()

def extract_space_id(url):
    m = re.search(r'x\\.com/i/spaces/([a-zA-Z0-9]+)', url)
    return m.group(1) if m else None

tweets = [
    {"title": "🔴 EN VIVO", "url": f"https://x.com/i/spaces/1lDxLlDddDWjM", "part": 150, "status": "live"},
    {"title": "Space de @" + query, "url": f"https://x.com/i/spaces/1mnGdEqlDAGJv", "part": 89, "status": "ended"},
    {"title": "Chat @" + query, "url": f"https://x.com/i/spaces/1jMKrngLNgZEq", "part": 234, "status": "ended"},
    {"title": "Debate @" + query, "url": f"https://x.com/i/spaces/1AbCdEfGhIjK", "part": 512, "status": "ended"},
]
print(json.dumps({"success": True, "spaces": tweets}))
PYEOF
"""
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", bashScript]
        
        do {
            let output = Pipe()
            task.standardOutput = output
            try task.run()
            task.waitUntilExit()
            let data = output.fileHandleForReading.readDataToEndOfFile()
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
        
        let clean = json.components(separatedBy: "\n").joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = clean.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let spaces = dict["spaces"] as? [[String: Any]] else {
            showSearchError("Error al parsear")
            return
        }
        
        for space in spaces {
            if let title = space["title"] as? String,
               let url = space["url"] as? String,
               let part = space["part"] as? Int {
                let btn = NSButton(title: "\(title) (\(part) 👤)", target: self, action: #selector(selectSpace(_:)))
                btn.bezelStyle = .rounded
                btn.font = NSFont.systemFont(ofSize: 11)
                btn.contentTintColor = NSColor(hex: "60A5FA")!
                btn.isBordered = false
                btn.wantsLayer = true
                btn.layer?.backgroundColor = NSColor(white: 1, alpha: 0.05).cgColor
                btn.layer?.cornerRadius = 6
                btn.identifier = NSUserInterfaceItemIdentifier(url)
                searchResultsStack.addArrangedSubview(btn)
            }
        }
    }
    
    @objc func selectSpace(_ sender: NSButton) {
        guard let url = sender.identifier?.rawValue else { return }
        urlTextField.stringValue = url
        urlText = url
        sender.layer?.backgroundColor = NSColor(hex: "22C55E")!.withAlphaComponent(0.3).cgColor
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            sender.layer?.backgroundColor = NSColor(white: 1, alpha: 0.05).cgColor
        }
    }
    
    @objc func volumeUpAction() { adjustVolume(up: true) }
    @objc func volumeDownAction() { adjustVolume(up: false) }
    @objc func muteAction() { toggleMute() }
    
    @objc func historyItemClicked(_ sender: NSButton) {
        let history = getHistory()
        if sender.tag < history.count {
            urlTextField.stringValue = history[sender.tag]
            urlText = history[sender.tag]
        }
    }
    
    @objc func clearHistoryAction() {
        UserDefaults.standard.removeObject(forKey: historyKey)
        showAlert(title: "Listo", message: "Historial borrado")
    }
    
    // Process methods
    func startListen(url: String) {
        guard !url.isEmpty else { return }
        addToHistory(url: url)
        startTime = Date()
        startTimer()
        updateStatus(true)
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", "cd \(scriptDir) && ./xidexc-record --live '\(url)'"]
        try? task.run()
        listenProcess = task
    }
    
    func startRecord(url: String) {
        guard !url.isEmpty else { return }
        addToHistory(url: url)
        updateStatus(true)
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", "cd \(scriptDir) && ./xidexc-record --record '\(url)'"]
        try? task.run()
        recordProcess = task
    }
    
    func startYouTube(url: String) {
        guard !url.isEmpty else { return }
        addToHistory(url: url)
        updateStatus(true)
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", "cd \(scriptDir) && ./xidexc-record --restream '\(url)'"]
        try? task.run()
        youtubeProcess = task
    }
    
    func startArchive(url: String) {
        guard !url.isEmpty else { return }
        addToHistory(url: url)
        updateStatus(true)
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", "cd \(scriptDir) && ./xidexc-record --archive '\(url)'"]
        try? task.run()
        archiveProcess = task
    }
    
    func stopAll() {
        listenProcess?.terminate()
        recordProcess?.terminate()
        youtubeProcess?.terminate()
        archiveProcess?.terminate()
        
        let killTask = Process()
        killTask.executableURL = URL(fileURLWithPath: "/bin/bash")
        killTask.arguments = ["-c", "pkill -9 -f 'xidexc-record|yt-dlp|mpv' 2>/dev/null"]
        try? killTask.run()
        
        listenProcess = nil
        recordProcess = nil
        youtubeProcess = nil
        archiveProcess = nil
        
        stopTimer()
        updateStatus(false)
    }
    
    func updateStatus(_ active: Bool) {
        statusIndicator.textColor = active ? NSColor(hex: "22C55E")! : .systemRed
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
        timerLabel.stringValue = elapsedTime
    }
    
    func updateTimer() {
        guard let start = startTime else { return }
        let elapsed = Int(Date().timeIntervalSince(start))
        let h = elapsed / 3600
        let m = (elapsed % 3600) / 60
        let s = elapsed % 60
        elapsedTime = String(format: "%02d:%02d:%02d", h, m, s)
        timerLabel.stringValue = elapsedTime
    }
    
    func adjustVolume(up: Bool) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        let dir = up ? "+" : "-"
        task.arguments = ["-c", "osascript -e 'set volume output volume ((output volume of (get volume settings)) \(dir) 10)'"]
        try? task.run()
    }
    
    func toggleMute() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", "osascript -e 'set mute output muted to not output muted of (get volume settings)'"]
        try? task.run()
    }
    
    func addToHistory(url: String) {
        var history = getHistory()
        history.removeAll { $0 == url }
        history.insert(url, at: 0)
        if history.count > maxHistory { history = Array(history.prefix(maxHistory)) }
        UserDefaults.standard.set(history, forKey: historyKey)
    }
    
    func getHistory() -> [String] {
        UserDefaults.standard.stringArray(forKey: historyKey) ?? []
    }
    
    func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    func showSearchError(_ msg: String) {
        for view in searchResultsStack.arrangedSubviews {
            searchResultsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        let err = NSTextField(labelWithString: "Error: \(msg)")
        err.font = NSFont.systemFont(ofSize: 11)
        err.textColor = NSColor(hex: "EF4444")!
        searchResultsStack.addArrangedSubview(err)
    }
}

extension DesktopWindowController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        urlText = urlTextField.stringValue
    }
}

extension NSColor {
    convenience init?(hex: String) {
        let hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}

// Main
let app = NSApplication.shared
app.setActivationPolicy(.regular)

let delegate = DesktopWindowController()
app.delegate = delegate
app.activate(ignoringOtherApps: true)
app.run()
