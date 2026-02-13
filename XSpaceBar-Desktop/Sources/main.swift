import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var mainWindow: NSWindow!
    var tabButtons: [NSButton] = []
    var tabViews: [NSView] = []
    var currentTab = 0
    
    var inputField: NSTextField!
    var timerLabel: NSTextField!
    var searchField: NSTextField!
    var searchResultsStack: NSStackView!
    var pathField: NSTextField!
    var linksStack: NSStackView!
    var savedLinks: [[String: String]] = []
    var idField: NSTextField!
    var historyStack: NSStackView!
    var history: [[String: String]] = []
    let historyLimit = 100
    
    var listenProcess: Process?
    var recordProcess: Process?
    var downloadProcess: Process?
    var youtubeProcess: Process?
    var archiveProcess: Process?
    var startTime: Date?
    var timer: Timer?
    
    let scriptDir = "/Users/molder/projects/github-molder/spaces"
    let historyKey = "SpaceHistory"
    let pathKey = "SavePath"
    var savePath: String = ""
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        savePath = UserDefaults.standard.string(forKey: pathKey) ?? (NSHomeDirectory() + "/Downloads/x_spaces")
        setupWindow()
    }
    
    func setupWindow() {
        mainWindow = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 440, height: 680), 
                            styleMask: [.titled, .closable, .miniaturizable, .resizable],
                            backing: .buffered, defer: false)
        mainWindow.title = "XSpaceBar"
        mainWindow.backgroundColor = NSColor(hex: "0F1115")
        
        let contentView = mainWindow.contentView!
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor(hex: "0F1115")?.cgColor
        
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
        mainStack.addArrangedSubview(headerStack)
        
        let titleLabel = NSTextField(labelWithString: "XSpaceBar")
        titleLabel.font = NSFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = .white
        headerStack.addArrangedSubview(titleLabel)
        headerStack.addArrangedSubview(NSView())
        
        let statusIndicator = NSView()
        statusIndicator.wantsLayer = true
        statusIndicator.layer?.backgroundColor = NSColor.systemGreen.cgColor
        statusIndicator.layer?.cornerRadius = 6
        statusIndicator.widthAnchor.constraint(equalToConstant: 12).isActive = true
        statusIndicator.heightAnchor.constraint(equalToConstant: 12).isActive = true
        headerStack.addArrangedSubview(statusIndicator)
        
        // Input
        let inputLabel = NSTextField(labelWithString: "Link del Space")
        inputLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        inputLabel.textColor = .gray
        mainStack.addArrangedSubview(inputLabel)
        
        inputField = NSTextField()
        inputField.textColor = NSColor(hex: "1F2937")!
        inputField.backgroundColor = NSColor.white
        inputField.font = NSFont.systemFont(ofSize: 14)
        inputField.placeholderString = "https://x.com/i/spaces/..."
        inputField.bezelStyle = .roundedBezel
        mainStack.addArrangedSubview(inputField)
        
        // Timer
        timerLabel = NSTextField(labelWithString: "00:00:00")
        timerLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 44, weight: .light)
        timerLabel.textColor = .white
        timerLabel.alignment = .center
        mainStack.addArrangedSubview(timerLabel)
        
        // Tabs
        let tabStack = NSStackView()
        tabStack.orientation = .horizontal
        tabStack.spacing = 8
        tabStack.distribution = .fillEqually
        mainStack.addArrangedSubview(tabStack)
        
        let tabs = [
            ("🔊", "Escuchar"),
            ("🎙️", "Grabar"),
            ("📥", "Descargar"),
            ("📺", "YouTube"),
            ("🌐", "Archive"),
            ("🔗", "Links"),
            ("📜", "History"),
            ("🔍", "Buscar"),
            ("⚙️", "Settings")
        ]
        
        for (index, (icon, name)) in tabs.enumerated() {
            let btn = NSButton(title: "\(icon) \(name)", target: self, action: #selector(switchTab(_:)))
            btn.tag = index
            btn.bezelStyle = .rounded
            btn.font = NSFont.systemFont(ofSize: 11, weight: .medium)
            btn.wantsLayer = true
            btn.layer?.cornerRadius = 10
            btn.isBordered = false
            btn.contentTintColor = .white
            
            if index == 1 {
                btn.layer?.backgroundColor = NSColor(hex: "EF4444")!.withAlphaComponent(0.3).cgColor
            } else {
                btn.layer?.backgroundColor = NSColor.clear.cgColor
            }
            
            tabButtons.append(btn)
            tabStack.addArrangedSubview(btn)
        }
        
        // Content Area
        let contentArea = NSView()
        contentArea.wantsLayer = true
        contentArea.layer?.backgroundColor = NSColor(white: 1, alpha: 0.03).cgColor
        contentArea.layer?.cornerRadius = 12
        mainStack.addArrangedSubview(contentArea)
        
        // Tab Views
        let listenView = createListenView()
        let recordView = createRecordView()
        let downloadView = createDownloadView()
        let youtubeView = createYouTubeView()
        let archiveView = createArchiveView()
        let linksView = createLinksView()
        let historyView = createHistoryView()
        let searchView = createSearchView()
        let settingsView = createSettingsView()

        tabViews = [listenView, recordView, downloadView, youtubeView, archiveView, linksView, historyView, searchView, settingsView]
        
        for (index, tabView) in tabViews.enumerated() {
            tabView.isHidden = index != 1
            tabView.frame = contentArea.bounds
            tabView.autoresizingMask = [.width, .height]
            contentArea.addSubview(tabView)
        }
        
        mainWindow.center()
        mainWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func switchTab(_ sender: NSButton) {
        currentTab = sender.tag
        
        for (index, btn) in tabButtons.enumerated() {
            if index == currentTab {
                if index == 1 {
                    btn.layer?.backgroundColor = NSColor(hex: "EF4444")!.withAlphaComponent(0.3).cgColor
                } else {
                    btn.layer?.backgroundColor = NSColor(hex: "3B82F6")!.withAlphaComponent(0.3).cgColor
                }
            } else {
                btn.layer?.backgroundColor = NSColor.clear.cgColor
            }
        }
        
        for (index, tabView) in tabViews.enumerated() {
            tabView.isHidden = index != currentTab
        }
    }
    
    // MARK: - Tab Views
    
    func createListenView() -> NSView {
        let container = NSView()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 16
        stack.alignment = .centerX
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        
        let icon = NSTextField(labelWithString: "🔊")
        icon.font = NSFont.systemFont(ofSize: 48)
        stack.addArrangedSubview(icon)
        
        let title = NSTextField(labelWithString: "Escuchar en Vivo")
        title.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        title.textColor = .white
        stack.addArrangedSubview(title)
        
        let desc = NSTextField(labelWithString: "Escucha el Space sin grabar")
        desc.font = NSFont.systemFont(ofSize: 12)
        desc.textColor = .gray
        stack.addArrangedSubview(desc)
        
        let btn = createActionButton(title: "▶️  ESCUCHAR", color: "22C55E")
        btn.target = self
        btn.action = #selector(startListen)
        stack.addArrangedSubview(btn)
        
        return container
    }

    func createRecordView() -> NSView {
        let container = NSView()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 16
        stack.alignment = .centerX
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        let icon = NSTextField(labelWithString: "🎙️")
        icon.font = NSFont.systemFont(ofSize: 48)
        stack.addArrangedSubview(icon)

        let title = NSTextField(labelWithString: "Grabar Space")
        title.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        title.textColor = .white
        stack.addArrangedSubview(title)

        let desc = NSTextField(labelWithString: "Guarda el audio en vivo")
        desc.font = NSFont.systemFont(ofSize: 11)
        desc.textColor = .gray
        desc.alignment = .center
        stack.addArrangedSubview(desc)

        let buttonStack = NSStackView()
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 12
        stack.addArrangedSubview(buttonStack)

        let playBtn = NSButton(title: "▶️", target: self, action: #selector(startRecord))
        playBtn.bezelStyle = .rounded
        playBtn.font = NSFont.systemFont(ofSize: 20, weight: .bold)
        playBtn.wantsLayer = true
        playBtn.layer?.backgroundColor = NSColor(hex: "22C55E")!.cgColor
        playBtn.setButtonType(.momentaryPushIn)
        playBtn.isBordered = false
        playBtn.layer?.cornerRadius = 30
        playBtn.contentTintColor = .white
        playBtn.widthAnchor.constraint(equalToConstant: 60).isActive = true
        playBtn.heightAnchor.constraint(equalToConstant: 60).isActive = true
        buttonStack.addArrangedSubview(playBtn)

        let pauseBtn = NSButton(title: "⏸️", target: self, action: #selector(pauseRecord))
        pauseBtn.bezelStyle = .rounded
        pauseBtn.font = NSFont.systemFont(ofSize: 20, weight: .bold)
        pauseBtn.wantsLayer = true
        pauseBtn.layer?.backgroundColor = NSColor(hex: "F59E0B")!.cgColor
        pauseBtn.setButtonType(.momentaryPushIn)
        pauseBtn.isBordered = false
        pauseBtn.layer?.cornerRadius = 30
        pauseBtn.contentTintColor = .white
        pauseBtn.widthAnchor.constraint(equalToConstant: 60).isActive = true
        pauseBtn.heightAnchor.constraint(equalToConstant: 60).isActive = true
        buttonStack.addArrangedSubview(pauseBtn)

        let stopBtn = NSButton(title: "⏹️", target: self, action: #selector(stopAll))
        stopBtn.bezelStyle = .rounded
        stopBtn.font = NSFont.systemFont(ofSize: 20, weight: .bold)
        stopBtn.wantsLayer = true
        stopBtn.layer?.backgroundColor = NSColor(hex: "EF4444")!.cgColor
        stopBtn.setButtonType(.momentaryPushIn)
        stopBtn.isBordered = false
        stopBtn.layer?.cornerRadius = 30
        stopBtn.contentTintColor = .white
        stopBtn.widthAnchor.constraint(equalToConstant: 60).isActive = true
        stopBtn.heightAnchor.constraint(equalToConstant: 60).isActive = true
        buttonStack.addArrangedSubview(stopBtn)

        return container
    }

    func createDownloadView() -> NSView {
        let container = NSView()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 16
        stack.alignment = .centerX
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        let icon = NSTextField(labelWithString: "📥")
        icon.font = NSFont.systemFont(ofSize: 48)
        stack.addArrangedSubview(icon)

        let title = NSTextField(labelWithString: "Descargar Space Terminado")
        title.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        title.textColor = .white
        stack.addArrangedSubview(title)

        let desc = NSTextField(labelWithString: "Pega el link de un Space ya terminado")
        desc.font = NSFont.systemFont(ofSize: 12)
        desc.textColor = .gray
        stack.addArrangedSubview(desc)

        let buttonStack = NSStackView()
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 12
        stack.addArrangedSubview(buttonStack)

        let downloadBtn = NSButton(title: "📥  DESCARGAR", target: self, action: #selector(downloadSpace))
        downloadBtn.bezelStyle = .rounded
        downloadBtn.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        downloadBtn.wantsLayer = true
        downloadBtn.layer?.backgroundColor = NSColor(hex: "8B5CF6")!.cgColor
        downloadBtn.setButtonType(.momentaryPushIn)
        downloadBtn.isBordered = false
        downloadBtn.layer?.cornerRadius = 12
        downloadBtn.contentTintColor = .white
        downloadBtn.heightAnchor.constraint(equalToConstant: 44).isActive = true
        buttonStack.addArrangedSubview(downloadBtn)

        let cancelBtn = NSButton(title: "⏹️", target: self, action: #selector(stopDownload))
        cancelBtn.bezelStyle = .rounded
        cancelBtn.font = NSFont.systemFont(ofSize: 16, weight: .bold)
        cancelBtn.wantsLayer = true
        cancelBtn.layer?.backgroundColor = NSColor(hex: "6B7280")!.cgColor
        cancelBtn.setButtonType(.momentaryPushIn)
        cancelBtn.isBordered = false
        cancelBtn.layer?.cornerRadius = 12
        cancelBtn.contentTintColor = .white
        cancelBtn.widthAnchor.constraint(equalToConstant: 60).isActive = true
        buttonStack.addArrangedSubview(cancelBtn)

        return container
    }

    func createYouTubeView() -> NSView {
        let container = NSView()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 16
        stack.alignment = .centerX
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        let icon = NSTextField(labelWithString: "📺")
        icon.font = NSFont.systemFont(ofSize: 48)
        stack.addArrangedSubview(icon)

        let title = NSTextField(labelWithString: "YouTube Live")
        title.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        title.textColor = .white
        stack.addArrangedSubview(title)

        let btn = createActionButton(title: "📡  TRANSMITIR", color: "DC2626")
        btn.target = self
        btn.action = #selector(startYouTube)
        stack.addArrangedSubview(btn)

        return container
    }

    func createArchiveView() -> NSView {
        let container = NSView()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 16
        stack.alignment = .centerX
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        let icon = NSTextField(labelWithString: "🌐")
        icon.font = NSFont.systemFont(ofSize: 48)
        stack.addArrangedSubview(icon)

        let title = NSTextField(labelWithString: "Internet Archive")
        title.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        title.textColor = .white
        stack.addArrangedSubview(title)

        let btn = createActionButton(title: "☁️  SUBIR", color: "3B82F6")
        btn.target = self
        btn.action = #selector(startArchive)
        stack.addArrangedSubview(btn)

        return container
    }

    func createLinksView() -> NSView {
        let container = NSView()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20)
        ])

        let icon = NSTextField(labelWithString: "🔗")
        icon.font = NSFont.systemFont(ofSize: 28)
        stack.addArrangedSubview(icon)

        let title = NSTextField(labelWithString: "Links Guardados")
        title.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        title.textColor = .white
        stack.addArrangedSubview(title)

        let addRow = NSStackView()
        addRow.orientation = .horizontal
        addRow.spacing = 10
        stack.addArrangedSubview(addRow)

        idField = NSTextField()
        idField.textColor = .white
        idField.backgroundColor = NSColor(white: 1, alpha: 0.08)
        idField.font = NSFont.systemFont(ofSize: 12)
        idField.placeholderString = "ID (ej: podcast-lunes)"
        idField.bezelStyle = .roundedBezel
        addRow.addArrangedSubview(idField)

        let addBtn = NSButton(title: "+", target: self, action: #selector(addLink))
        addBtn.bezelStyle = .rounded
        addBtn.font = NSFont.systemFont(ofSize: 14, weight: .bold)
        addBtn.wantsLayer = true
        addBtn.layer?.backgroundColor = NSColor(hex: "22C55E")!.cgColor
        addBtn.setButtonType(.momentaryPushIn)
        addBtn.isBordered = false
        addBtn.layer?.cornerRadius = 8
        addBtn.contentTintColor = .white
        addBtn.widthAnchor.constraint(equalToConstant: 40).isActive = true
        addRow.addArrangedSubview(addBtn)

        let resultsContainer = NSView()
        resultsContainer.wantsLayer = true
        resultsContainer.layer?.backgroundColor = NSColor(white: 1, alpha: 0.05).cgColor
        resultsContainer.layer?.cornerRadius = 8
        stack.addArrangedSubview(resultsContainer)

        let resultsTitle = NSTextField(labelWithString: "Links:")
        resultsTitle.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        resultsTitle.textColor = .gray
        resultsTitle.translatesAutoresizingMaskIntoConstraints = false
        resultsContainer.addSubview(resultsTitle)

        NSLayoutConstraint.activate([
            resultsTitle.topAnchor.constraint(equalTo: resultsContainer.topAnchor, constant: 10),
            resultsTitle.leadingAnchor.constraint(equalTo: resultsContainer.leadingAnchor, constant: 12)
        ])

        linksStack = NSStackView()
        linksStack.orientation = .vertical
        linksStack.spacing = 6
        linksStack.translatesAutoresizingMaskIntoConstraints = false
        resultsContainer.addSubview(linksStack)

        NSLayoutConstraint.activate([
            linksStack.topAnchor.constraint(equalTo: resultsTitle.bottomAnchor, constant: 10),
            linksStack.leadingAnchor.constraint(equalTo: resultsContainer.leadingAnchor, constant: 12),
            linksStack.trailingAnchor.constraint(equalTo: resultsContainer.trailingAnchor, constant: -12),
            linksStack.bottomAnchor.constraint(equalTo: resultsContainer.bottomAnchor, constant: -10)
        ])

        loadSavedLinks()
        updateLinksDisplay()

        return container
    }

    func loadSavedLinks() {
        if let data = UserDefaults.standard.data(forKey: "SavedLinks"),
           let links = try? JSONDecoder().decode([[String: String]].self, from: data) {
            savedLinks = links
        }
    }

    func saveLinks() {
        if let data = try? JSONEncoder().encode(savedLinks) {
            UserDefaults.standard.set(data, forKey: "SavedLinks")
        }
    }

    func updateLinksDisplay() {
        for view in linksStack.arrangedSubviews {
            linksStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        if savedLinks.isEmpty {
            let emptyLabel = NSTextField(labelWithString: "Sin links guardados")
            emptyLabel.font = NSFont.systemFont(ofSize: 12)
            emptyLabel.textColor = .gray
            linksStack.addArrangedSubview(emptyLabel)
            return
        }

        for (index, link) in savedLinks.enumerated() {
            let btn = NSButton(title: "\(link["id"] ?? "?"): \(link["url"] ?? "")", target: self, action: #selector(linkClicked(_:)))
            btn.bezelStyle = .rounded
            btn.font = NSFont.systemFont(ofSize: 11)
            btn.contentTintColor = NSColor(hex: "60A5FA")!
            btn.isBordered = false
            btn.wantsLayer = true
            btn.layer?.backgroundColor = NSColor(white: 1, alpha: 0.08).cgColor
            btn.layer?.cornerRadius = 8
            btn.tag = index
            linksStack.addArrangedSubview(btn)
        }
    }

    @objc func addLink() {
        guard !inputField.stringValue.isEmpty else {
            showAlert(title: "Error", message: "Pega el link del Space primero")
            return
        }
        guard !idField.stringValue.isEmpty else {
            showAlert(title: "Error", message: "Ingresa un ID para el link")
            return
        }

        let id = idField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if !savedLinks.contains(where: { $0["id"] == id }) {
            savedLinks.append(["id": id, "url": url])
            saveLinks()
            updateLinksDisplay()
            print("🔗 [LINKS] Guardado: \(id) -> \(url)")
            showAlert(title: "Guardado", message: "Link '\(id)' guardado")
        } else {
            showAlert(title: "Error", message: "El ID '\(id)' ya existe")
        }
    }

    @objc func linkClicked(_ sender: NSButton) {
        let index = sender.tag
        guard index < savedLinks.count else { return }

        let link = savedLinks[index]
        inputField.stringValue = link["url"] ?? ""

        sender.layer?.backgroundColor = NSColor(hex: "22C55E")!.withAlphaComponent(0.3).cgColor
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            sender.layer?.backgroundColor = NSColor(white: 1, alpha: 0.08).cgColor
        }

        print("🔗 [LINKS] Cargado: \(link["id"] ?? "") -> \(link["url"] ?? "")")
        showAlert(title: "Link Cargado", message: link["url"] ?? "")
    }

    func createSearchView() -> NSView {
        let container = NSView()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20)
        ])
        
        let icon = NSTextField(labelWithString: "🔍")
        icon.font = NSFont.systemFont(ofSize: 28)
        stack.addArrangedSubview(icon)
        
        let title = NSTextField(labelWithString: "Buscar Spaces")
        title.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        title.textColor = .white
        stack.addArrangedSubview(title)
        
        let searchRow = NSStackView()
        searchRow.orientation = .horizontal
        searchRow.spacing = 10
        stack.addArrangedSubview(searchRow)
        
        searchField = NSTextField()
        searchField.textColor = NSColor(hex: "1F2937")!
        searchField.backgroundColor = NSColor.white
        searchField.font = NSFont.systemFont(ofSize: 13)
        searchField.placeholderString = "@cuenta"
        searchField.bezelStyle = .roundedBezel
        searchRow.addArrangedSubview(searchField)
        
        let searchBtn = NSButton(title: "Buscar", target: self, action: #selector(performSearch))
        searchBtn.bezelStyle = .rounded
        searchBtn.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        searchBtn.wantsLayer = true
        searchBtn.layer?.backgroundColor = NSColor(hex: "3B82F6")!.cgColor
        searchBtn.setButtonType(.momentaryPushIn)
        searchBtn.isBordered = false
        searchBtn.layer?.cornerRadius = 8
        searchBtn.contentTintColor = .white
        searchBtn.widthAnchor.constraint(equalToConstant: 80).isActive = true
        searchRow.addArrangedSubview(searchBtn)
        
        let resultsContainer = NSView()
        resultsContainer.wantsLayer = true
        resultsContainer.layer?.backgroundColor = NSColor(white: 1, alpha: 0.05).cgColor
        resultsContainer.layer?.cornerRadius = 8
        stack.addArrangedSubview(resultsContainer)
        
        let resultsTitle = NSTextField(labelWithString: "Resultados:")
        resultsTitle.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        resultsTitle.textColor = .gray
        resultsTitle.translatesAutoresizingMaskIntoConstraints = false
        resultsContainer.addSubview(resultsTitle)
        
        NSLayoutConstraint.activate([
            resultsTitle.topAnchor.constraint(equalTo: resultsContainer.topAnchor, constant: 10),
            resultsTitle.leadingAnchor.constraint(equalTo: resultsContainer.leadingAnchor, constant: 12)
        ])
        
        searchResultsStack = NSStackView()
        searchResultsStack.orientation = .vertical
        searchResultsStack.spacing = 6
        searchResultsStack.translatesAutoresizingMaskIntoConstraints = false
        resultsContainer.addSubview(searchResultsStack)
        
        NSLayoutConstraint.activate([
            searchResultsStack.topAnchor.constraint(equalTo: resultsTitle.bottomAnchor, constant: 10),
            searchResultsStack.leadingAnchor.constraint(equalTo: resultsContainer.leadingAnchor, constant: 12),
            searchResultsStack.trailingAnchor.constraint(equalTo: resultsContainer.trailingAnchor, constant: -12),
            searchResultsStack.bottomAnchor.constraint(equalTo: resultsContainer.bottomAnchor, constant: -10)
        ])
        
        let emptyLabel = NSTextField(labelWithString: "Escribe @cuenta y Busca")
        emptyLabel.font = NSFont.systemFont(ofSize: 12)
        emptyLabel.textColor = .gray
        searchResultsStack.addArrangedSubview(emptyLabel)
        
        return container
    }
    
    func createSettingsView() -> NSView {
        let container = NSView()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20)
        ])
        
        let icon = NSTextField(labelWithString: "⚙️")
        icon.font = NSFont.systemFont(ofSize: 28)
        stack.addArrangedSubview(icon)
        
        let title = NSTextField(labelWithString: "Configuracion")
        title.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        title.textColor = .white
        stack.addArrangedSubview(title)
        
        let pathLabel = NSTextField(labelWithString: "Carpeta de guardado:")
        pathLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        pathLabel.textColor = .gray
        stack.addArrangedSubview(pathLabel)
        
        let pathRow = NSStackView()
        pathRow.orientation = .horizontal
        pathRow.spacing = 10
        stack.addArrangedSubview(pathRow)
        
        pathField = NSTextField()
        pathField.textColor = .white
        pathField.backgroundColor = NSColor(white: 1, alpha: 0.08)
        pathField.font = NSFont.systemFont(ofSize: 12)
        pathField.placeholderString = "Seleccionar carpeta..."
        pathField.stringValue = savePath
        pathField.bezelStyle = .roundedBezel
        pathRow.addArrangedSubview(pathField)
        
        let pathBtn = NSButton(title: "📁", target: self, action: #selector(selectPath))
        pathBtn.bezelStyle = .rounded
        pathBtn.wantsLayer = true
        pathBtn.layer?.backgroundColor = NSColor(hex: "3B82F6")!.cgColor
        pathBtn.setButtonType(.momentaryPushIn)
        pathBtn.isBordered = false
        pathBtn.layer?.cornerRadius = 8
        pathBtn.contentTintColor = .white
        pathBtn.widthAnchor.constraint(equalToConstant: 44).isActive = true
        pathRow.addArrangedSubview(pathBtn)
        
        let saveBtn = NSButton(title: "💾  Guardar", target: self, action: #selector(saveSettings))
        saveBtn.bezelStyle = .rounded
        saveBtn.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        saveBtn.wantsLayer = true
        saveBtn.layer?.backgroundColor = NSColor(hex: "22C55E")!.cgColor
        saveBtn.setButtonType(.momentaryPushIn)
        saveBtn.isBordered = false
        saveBtn.layer?.cornerRadius = 10
        saveBtn.contentTintColor = .white
        saveBtn.heightAnchor.constraint(equalToConstant: 40).isActive = true
        stack.addArrangedSubview(saveBtn)
        
        return container
    }

    func createHistoryView() -> NSView {
        let container = NSView()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20)
        ])

        let icon = NSTextField(labelWithString: "📜")
        icon.font = NSFont.systemFont(ofSize: 28)
        stack.addArrangedSubview(icon)

        let title = NSTextField(labelWithString: "Historial (\(historyLimit) max)")
        title.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        title.textColor = .white
        stack.addArrangedSubview(title)

        let resultsContainer = NSView()
        resultsContainer.wantsLayer = true
        resultsContainer.layer?.backgroundColor = NSColor(white: 1, alpha: 0.05).cgColor
        resultsContainer.layer?.cornerRadius = 8
        stack.addArrangedSubview(resultsContainer)

        let resultsTitle = NSTextField(labelWithString: "Espacios grabados:")
        resultsTitle.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        resultsTitle.textColor = .gray
        resultsTitle.translatesAutoresizingMaskIntoConstraints = false
        resultsContainer.addSubview(resultsTitle)

        NSLayoutConstraint.activate([
            resultsTitle.topAnchor.constraint(equalTo: resultsContainer.topAnchor, constant: 10),
            resultsTitle.leadingAnchor.constraint(equalTo: resultsContainer.leadingAnchor, constant: 12)
        ])

        historyStack = NSStackView()
        historyStack.orientation = .vertical
        historyStack.spacing = 6
        historyStack.translatesAutoresizingMaskIntoConstraints = false
        resultsContainer.addSubview(historyStack)

        NSLayoutConstraint.activate([
            historyStack.topAnchor.constraint(equalTo: resultsTitle.bottomAnchor, constant: 10),
            historyStack.leadingAnchor.constraint(equalTo: resultsContainer.leadingAnchor, constant: 12),
            historyStack.trailingAnchor.constraint(equalTo: resultsContainer.trailingAnchor, constant: -12),
            historyStack.bottomAnchor.constraint(equalTo: resultsContainer.bottomAnchor, constant: -10)
        ])

        loadHistory()
        updateHistoryDisplay()

        return container
    }

    func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: "SpaceHistory"),
           let h = try? JSONDecoder().decode([[String: String]].self, from: data) {
            history = h
        }
    }

    func saveHistory() {
        if history.count > historyLimit {
            history = Array(history.suffix(historyLimit))
        }
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: "SpaceHistory")
        }
    }

    func addToHistory(spaceId: String, action: String) {
        let entry: [String: String] = [
            "id": spaceId,
            "action": action,
            "date": ISO8601DateFormatter().string(from: Date())
        ]
        if !history.contains(where: { $0["id"] == spaceId }) {
            history.insert(entry, at: 0)
            saveHistory()
            print("📜 [HISTORY] Agregado: \(spaceId)")
        }
    }

    func updateHistoryDisplay() {
        for view in historyStack.arrangedSubviews {
            historyStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        if history.isEmpty {
            let emptyLabel = NSTextField(labelWithString: "Sin historial")
            emptyLabel.font = NSFont.systemFont(ofSize: 12)
            emptyLabel.textColor = .gray
            historyStack.addArrangedSubview(emptyLabel)
            return
        }

        for (index, entry) in history.enumerated() {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "HH:mm"
            var dateStr = ""
            if let dateStrVal = entry["date"], let date = ISO8601DateFormatter().date(from: dateStrVal) {
                dateStr = dateFormatter.string(from: date)
            }

            let btn = NSButton(title: "[\(entry["action"] ?? "?") \(dateStr)] \(entry["id"] ?? "")", target: self, action: #selector(historyClicked(_:)))
            btn.bezelStyle = .rounded
            btn.font = NSFont.systemFont(ofSize: 11)
            btn.contentTintColor = NSColor(hex: "60A5FA")!
            btn.isBordered = false
            btn.wantsLayer = true
            btn.layer?.backgroundColor = NSColor(white: 1, alpha: 0.08).cgColor
            btn.layer?.cornerRadius = 8
            btn.tag = index
            historyStack.addArrangedSubview(btn)
        }
    }

    @objc func historyClicked(_ sender: NSButton) {
        let index = sender.tag
        guard index < history.count else { return }

        let entry = history[index]
        if let spaceId = entry["id"] {
            inputField.stringValue = "https://x.com/i/spaces/\(spaceId)"
        }

        sender.layer?.backgroundColor = NSColor(hex: "22C55E")!.withAlphaComponent(0.3).cgColor
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            sender.layer?.backgroundColor = NSColor(white: 1, alpha: 0.08).cgColor
        }

        print("📜 [HISTORY] Cargado: \(entry["id"] ?? "")")
    }

    func createActionButton(title: String, color: String) -> NSButton {
        let btn = NSButton(title: title, target: nil, action: nil)
        btn.bezelStyle = .rounded
        btn.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        btn.wantsLayer = true
        btn.layer?.backgroundColor = NSColor(hex: color)!.cgColor
        btn.setButtonType(.momentaryPushIn)
        btn.isBordered = false
        btn.layer?.cornerRadius = 12
        btn.contentTintColor = .white
        btn.heightAnchor.constraint(equalToConstant: 48).isActive = true
        return btn
    }
    
    // MARK: - Actions
    
    @objc func selectPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "Seleccionar carpeta de guardado"
        
        if panel.runModal() == .OK {
            if let url = panel.url?.path {
                savePath = url
                pathField.stringValue = url
                print("📁 [PATH] \(url)")
            }
        }
    }
    
    @objc func saveSettings() {
        UserDefaults.standard.set(savePath, forKey: pathKey)
        UserDefaults.standard.synchronize()
        print("💾 [SETTINGS] \(savePath)")
        showAlert(title: "Guardado", message: "Configuracion actualizada")
    }
    
    @objc func startListen() {
        guard !inputField.stringValue.isEmpty else {
            showAlert(title: "Error", message: "Pega el link del Space")
            return
        }
        print("🎵 [ESCUCHAR] \(inputField.stringValue)")
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", "cd \(scriptDir) && ./xidexc-record --live '\(inputField.stringValue)' 2>&1 &"]
        try? task.run()
        
        startTimer()
        showAlert(title: "Escuchando", message: "Reproduciendo...")
    }
    
    @objc func startRecord() {
        guard !inputField.stringValue.isEmpty else {
            showAlert(title: "Error", message: "Pega el link del Space")
            return
        }
        
        let mkTask = Process()
        mkTask.executableURL = URL(fileURLWithPath: "/bin/bash")
        mkTask.arguments = ["-c", "mkdir -p '\(savePath)'"]
        try? mkTask.run()
        
        print("🎙️ [GRABAR] \(savePath)")
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", "cd '\(scriptDir)' && ./xidexc-record --record '\(inputField.stringValue)' --dir '\(savePath)' 2>&1 &"]
        try? task.run()
        
        startTimer()
        showAlert(title: "Grabando", message: "Guardando en: \(savePath)")
    }
    
    @objc func pauseRecord() {
        print("⏸️ [PAUSA]")
        showAlert(title: "Pausado", message: "Grabacion pausada")
    }
    
    @objc func downloadSpace() {
        guard !inputField.stringValue.isEmpty else {
            showAlert(title: "Error", message: "Pega el link del Space terminado")
            return
        }
        
        let mkTask = Process()
        mkTask.executableURL = URL(fileURLWithPath: "/bin/bash")
        mkTask.arguments = ["-c", "mkdir -p '\(savePath)'"]
        try? mkTask.run()
        
        print("📥 [DESCARGAR] \(inputField.stringValue)")
        print("📁 [PATH] \(savePath)")
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", "cd '\(scriptDir)' && ./xidexc-record --record '\(inputField.stringValue)' --dir '\(savePath)' 2>&1 &"]
        try? task.run()
        
        showAlert(title: "Descargando", message: "Space guardado en: \(savePath)")
    }
    
    @objc func stopDownload() {
        print("⏹️ [STOP DESCARGAR]")
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", "pkill -9 -f 'xidexc-record|yt-dlp' 2>/dev/null"]
        try? task.run()
        
        stopTimer()
        showAlert(title: "Detenido", message: "Descarga cancelada")
    }
    
    @objc func startYouTube() {
        guard !inputField.stringValue.isEmpty else {
            showAlert(title: "Error", message: "Pega el link del Space")
            return
        }
        print("📺 [YOUTUBE] \(inputField.stringValue)")
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", "cd \(scriptDir) && ./xidexc-record --restream '\(inputField.stringValue)' 2>&1 &"]
        try? task.run()
        
        startTimer()
        showAlert(title: "YouTube", message: "Retransmitiendo...")
    }
    
    @objc func startArchive() {
        guard !inputField.stringValue.isEmpty else {
            showAlert(title: "Error", message: "Pega el link del Space")
            return
        }
        print("🌐 [ARCHIVE] \(inputField.stringValue)")
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", "cd \(scriptDir) && ./xidexc-record --archive '\(inputField.stringValue)' 2>&1 &"]
        try? task.run()
        
        startTimer()
        showAlert(title: "Archive", message: "Subiendo a Internet Archive...")
    }
    
    @objc func stopAll() {
        print("⏹️ [STOP]")
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", "pkill -9 -f 'xidexc-record|yt-dlp|mpv' 2>/dev/null"]
        try? task.run()
        
        stopTimer()
        showAlert(title: "Detenido", message: "Procesos finalizados")
    }
    
    @objc func performSearch() {
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            print("❌ [BUSCAR] Query vacio")
            return
        }
        
        let cleanQuery = query.hasPrefix("@") ? String(query.dropFirst()) : query
        print("🔍 [BUSCAR] @\(cleanQuery)")
        
        for view in searchResultsStack.arrangedSubviews {
            searchResultsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        
        let searching = NSTextField(labelWithString: "Buscando @\(cleanQuery)...")
        searching.font = NSFont.systemFont(ofSize: 12)
        searching.textColor = .gray
        searchResultsStack.addArrangedSubview(searching)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.showSearchResults(for: cleanQuery)
        }
    }
    
    func showSearchResults(for query: String) {
        for view in searchResultsStack.arrangedSubviews {
            searchResultsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        
        let mockSpaces = [
            ("🔴 EN VIVO", "https://x.com/i/spaces/1lDxLlDddDWjM", 150),
            ("Space de @" + query, "https://x.com/i/spaces/1mnGdEqlDAGJv", 89),
            ("Chat @" + query, "https://x.com/i/spaces/1jMKrngLNgZEq", 234),
            ("Debate @" + query, "https://x.com/i/spaces/1AbCdEfGhIjK", 512)
        ]
        
        for (title, url, participants) in mockSpaces {
            let btn = NSButton(title: "\(title) (\(participants) 👤)", target: self, action: #selector(spaceClicked(_:)))
            btn.bezelStyle = .rounded
            btn.font = NSFont.systemFont(ofSize: 12)
            btn.contentTintColor = NSColor(hex: "60A5FA")!
            btn.isBordered = false
            btn.wantsLayer = true
            btn.layer?.backgroundColor = NSColor(white: 1, alpha: 0.08).cgColor
            btn.layer?.cornerRadius = 8
            btn.identifier = NSUserInterfaceItemIdentifier(url)
            searchResultsStack.addArrangedSubview(btn)
        }
        
        print("✅ [RESULTADOS] \(mockSpaces.count) espacios de @\(query)")
    }
    
    @objc func spaceClicked(_ sender: NSButton) {
        guard let url = sender.identifier?.rawValue else { return }
        print("👆 [CLICK] \(url)")
        
        inputField.stringValue = url
        
        sender.layer?.backgroundColor = NSColor(hex: "22C55E")!.withAlphaComponent(0.3).cgColor
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            sender.layer?.backgroundColor = NSColor(white: 1, alpha: 0.08).cgColor
        }
        
        showAlert(title: "Space Seleccionado", message: url)
    }
    
    func startTimer() {
        startTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimer()
        }
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
        startTime = nil
        timerLabel.stringValue = "00:00:00"
    }
    
    func updateTimer() {
        guard let start = startTime else { return }
        let elapsed = Int(Date().timeIntervalSince(start))
        let h = elapsed / 3600
        let m = (elapsed % 3600) / 60
        let s = elapsed % 60
        timerLabel.stringValue = String(format: "%02d:%02d:%02d", h, m, s)
    }
    
    func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
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

let app = NSApplication.shared
app.setActivationPolicy(.regular)

let delegate = AppDelegate()
app.delegate = delegate
app.run()
