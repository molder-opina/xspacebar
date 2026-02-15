import AppKit
import UserNotifications

struct Job: Codable {
    var id: String
    var spaceURL: String
    var status: String
    var action: String
    var progress: Double
    var createdAt: Date
}

struct User: Codable, Identifiable {
    var id: String
    var name: String
    var createdAt: Date
}

struct ActivityLog: Codable, Identifiable {
    var id: String
    var userId: String
    var action: String
    var details: String
    var timestamp: Date
    var spaceURL: String?
}

class AppDelegate: NSObject, NSApplicationDelegate, NSTextFieldDelegate, NSTableViewDelegate, NSTableViewDataSource {
    var jobs: [Job] = []
    let jobsKey = "JobsQueue"
    
    var users: [User] = []
    var currentUser: User?
    let usersKey = "UsersList"
    let currentUserKey = "CurrentUserId"
    var activityLogs: [ActivityLog] = []
    let activityKey = "ActivityLogs"

    var mainWindow: NSWindow!
    var menubarStatusItem: NSStatusItem!
    var splitView: NSSplitView!
    var sidebarView: NSVisualEffectView!
    var mainContentView: NSView!

    var inputField: NSTextField!
    var timerLabel: NSTextField!
    var spaceTitleLabel: NSTextField!
    var hostLabel: NSTextField!
    var controlsRow: NSStackView!
    var inputContainer: NSView!
    var playbackView: NSView!
    var micIconView: NSView!
    var contentTitleLabel: NSTextField!
    var centerStack: NSStackView!
    var saveBtn: NSButton!
    var playBtn: NSButton!
    var statusLabel: NSTextField!
    
    var recordContainerView: NSView!
    var recordInputField: NSTextField!
    var recordSaveBtn: NSButton!

    var isRecording = false
    var isPlaying = false
    var isPaused = false
    var isBuffering = false
    var startTime: Date?
    var timer: Timer?
    var menubarTimer: Timer?
    var currentSpaceURL: String = ""
    
    var emptyStateView: NSView!
    var playbackControls: NSStackView!

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            togglePlay()
            return true
        }
        if commandSelector == #selector(NSText.paste(_:)) {
            if let tf = control as? NSTextField {
                tf.stringValue = NSPasteboard.general.string(forType: .string) ?? tf.stringValue
            }
            return true
        }
        return false
    }
    
    let pathKey = "SavePath"
    var savePath: String = ""

    var followingAccounts: [[String: String]] = []
    var favoritesSpaces: [[String: String]] = []
    let followingKey = "FollowingAccounts"
    let favoritesKey = "FavoritesSpaces"
    
    var mpvProcess: Process?
    var recordProcess: Process?
    var isDownloading = false
    var currentDownloadFilename = ""
    var recordStatusLabel: NSTextField!
    var recordProgressIndicator: NSProgressIndicator!
    var downloadedFiles: [String] = []
    var downloadsTableView: NSTableView!
    var downloadQueue: [[String: String]] = []
    var queueTableView: NSTableView!
    var activosContainerView: NSView!
    var activeStatusLabel: NSTextField!
    var activeProgressIndicator: NSProgressIndicator!
    var completadosContainerView: NSView!
    var completadosTableView: NSTableView!
    var permissions: [String: Bool] = [:]
    
    func checkPermissions() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "permissionsChecked") == nil {
            defaults.set(true, forKey: "permissionsChecked")
            // Temporarily disabled - uncomment to enable
            // showPermissionsWindow()
        } else {
            loadPermissions()
        }
    }
    
    func loadPermissions() {
        if let data = UserDefaults.standard.data(forKey: "appPermissions"),
           let perms = try? JSONDecoder().decode([String: Bool].self, from: data) {
            permissions = perms
        }
    }
    
    func savePermissions() {
        if let data = try? JSONEncoder().encode(permissions) {
            UserDefaults.standard.set(data, forKey: "appPermissions")
        }
    }
    
    func showPermissionsWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 450),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Permisos"
        window.center()
        
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 450))
        
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 16
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 30),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 30),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -30)
        ])
        
        let title = NSTextField(labelWithString: "Configura los permisos de la app")
        title.font = NSFont.systemFont(ofSize: 18, weight: .bold)
        stack.addArrangedSubview(title)
        
        let desc = NSTextField(labelWithString: "Haz clic en cada botón para granting el permiso necesario:")
        desc.font = NSFont.systemFont(ofSize: 13)
        desc.textColor = .secondaryLabelColor
        stack.addArrangedSubview(desc)
        
        let permissionsList = [
            ("notif", "🔔 Notificaciones", "Notificar cuando termine una descarga", "requestNotification"),
            ("mic", "🎙️ Microphone", "Para capturar audio del sistema", "requestMicrophone"),
            ("screen", "🖥️ Screen Recording", "Para grabar la pantalla", "requestScreen"),
            ("files", "📁 Acceso a Archivos", "Para guardar grabaciones", "openFiles")
        ]
        
        for (key, title, desc, action) in permissionsList {
            let row = NSStackView()
            row.orientation = .horizontal
            row.spacing = 12
            
            let btn = NSButton(title: "Grant", target: self, action: NSSelectorFromString(action + "()"))
            btn.bezelStyle = .rounded
            btn.identifier = NSUserInterfaceItemIdentifier(key)
            row.addArrangedSubview(btn)
            
            let textStack = NSStackView()
            textStack.orientation = .vertical
            textStack.spacing = 2
            textStack.alignment = .leading
            
            let label = NSTextField(labelWithString: title)
            label.font = NSFont.systemFont(ofSize: 14, weight: .medium)
            textStack.addArrangedSubview(label)
            
            let sublabel = NSTextField(labelWithString: desc)
            sublabel.font = NSFont.systemFont(ofSize: 11)
            sublabel.textColor = .secondaryLabelColor
            textStack.addArrangedSubview(sublabel)
            
            row.addArrangedSubview(textStack)
            stack.addArrangedSubview(row)
        }
        
        let doneBtn = NSButton(title: "Listo", target: self, action: #selector(permissionsDone))
        doneBtn.bezelStyle = .rounded
        doneBtn.keyEquivalent = "\r"
        stack.addArrangedSubview(doneBtn)
        
        window.contentView = contentView
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func requestNotification() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            DispatchQueue.main.async {
                self.permissions["notif"] = granted
                self.savePermissions()
            }
        }
        let alert = NSAlert()
        alert.messageText = "Permiso de Notificaciones"
        alert.informativeText = "Se solicitó el permiso de notificaciones"
        alert.runModal()
    }
    
    func requestMicrophone() {
        let alert = NSAlert()
        alert.messageText = "Permiso de Microphone"
        alert.informativeText = "Ve a System Settings > Privacy & Security > Microphone y habilita XSpaceRecorder"
        alert.addButton(withTitle: "Abrir Configuración")
        alert.addButton(withTitle: "Cancelar")
        
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
        }
    }
    
    func requestScreen() {
        let alert = NSAlert()
        alert.messageText = "Permiso de Screen Recording"
        alert.informativeText = "Ve a System Settings > Privacy & Security > Screen Recording y habilita XSpaceRecorder"
        alert.addButton(withTitle: "Abrir Configuración")
        alert.addButton(withTitle: "Cancelar")
        
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
        }
    }
    
    func openFiles() {
        let alert = NSAlert()
        alert.messageText = "Permiso de Archivos"
        alert.informativeText = "Ve a System Settings > Privacy & Security > Files and Folders y otorga acceso a la carpeta de descargas"
        alert.addButton(withTitle: "Abrir Configuración")
        alert.addButton(withTitle: "Cancelar")
        
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
        }
    }
    
    @objc func permissionsDone() {
        if let win = NSApp.mainWindow {
            win.close()
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        killAllProcesses()
    }
    
    func killAllProcesses() {
        mpvProcess?.terminate()
        recordProcess?.terminate()
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", "pkill -9 -f 'mpv|xspace-record' 2>/dev/null"]
        try? task.run()
        
        isPlaying = false
        isRecording = false
        isPaused = false
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        checkPermissions()
        
        savePath = UserDefaults.standard.string(forKey: pathKey) ?? (NSHomeDirectory() + "/Downloads")
        
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: savePath) {
            try? fileManager.createDirectory(atPath: savePath, withIntermediateDirectories: true)
        }
        
        loadData()
        loadJobs()
        setupMenubar()
        setupWindow()
        
        if users.isEmpty {
            showUserCreation()
        }
    }

    func loadData() {
        if let data = UserDefaults.standard.data(forKey: followingKey),
           let accounts = try? JSONDecoder().decode([[String: String]].self, from: data) {
            followingAccounts = accounts
        }
        if let data = UserDefaults.standard.data(forKey: favoritesKey),
           let spaces = try? JSONDecoder().decode([[String: String]].self, from: data) {
            favoritesSpaces = spaces
        }
        loadUsers()
        loadActivity()
    }
    
    func loadUsers() {
        if let data = UserDefaults.standard.data(forKey: usersKey),
           let loaded = try? JSONDecoder().decode([User].self, from: data) {
            users = loaded
        }
    }
    
    func loadActivity() {
        if let data = UserDefaults.standard.data(forKey: activityKey),
           let loaded = try? JSONDecoder().decode([ActivityLog].self, from: data) {
            activityLogs = loaded
        }
    }
    
    func logActivity(action: String, details: String, spaceURL: String? = nil) {
        let log = ActivityLog(id: UUID().uuidString, userId: currentUser?.id ?? "anonymous", action: action, details: details, timestamp: Date(), spaceURL: spaceURL)
        activityLogs.insert(log, at: 0)
        if activityLogs.count > 1000 { activityLogs.removeLast() }
        if let data = try? JSONEncoder().encode(activityLogs) {
            UserDefaults.standard.set(data, forKey: activityKey)
        }
    }

    func showUserCreation() {
        let alert = NSAlert()
        alert.messageText = "Bienvenido a XSpaceRecorder"
        alert.informativeText = "Crea un usuario"
        alert.addButton(withTitle: "Crear")
        alert.addButton(withTitle: "Anónimo")
        
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        input.placeholderString = "Tu nombre"
        alert.accessoryView = input
        
        if alert.runModal() == .alertFirstButtonReturn && !input.stringValue.isEmpty {
            let user = User(id: UUID().uuidString, name: input.stringValue, createdAt: Date())
            users.append(user)
            currentUser = user
            UserDefaults.standard.set(user.id, forKey: currentUserKey)
            if let data = try? JSONEncoder().encode(users) {
                UserDefaults.standard.set(data, forKey: usersKey)
            }
            logActivity(action: "user_created", details: "Usuario: \(input.stringValue)")
        } else {
            logActivity(action: "anonymous", details: "Inicio anónimo")
        }
    }

    func setupMenubar() {
        menubarStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateMenubarIcon()

        let menu = NSMenu()
        let statusItem = NSMenuItem(title: "Status: IDLE", action: nil, keyEquivalent: "")
        statusItem.tag = 100
        menu.addItem(statusItem)
        menu.addItem(NSMenuItem.separator())
        
        let timerItem = NSMenuItem(title: "00:00:00", action: nil, keyEquivalent: "")
        timerItem.tag = 101
        menu.addItem(timerItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let testItem = NSMenuItem(title: "🧪 Test Download", action: #selector(testDownload), keyEquivalent: "t")
        menu.addItem(testItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "❌ Salir", action: #selector(quitApp), keyEquivalent: "q"))
        
        menubarStatusItem.menu = menu
    }
    
    @objc func testDownload() {
        NSApp.activate(ignoringOtherApps: true)
        
        showContent("grabar")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.recordInputField?.stringValue = "https://x.com/i/spaces/1vOGwddeYEWJB"
            self.startRecordDownload()
        }
    }

    func updateMenubarIcon() {
        guard let button = menubarStatusItem.button else { return }
        if isRecording {
            button.image = NSImage(systemSymbolName: "waveform.circle.fill", accessibilityDescription: "Grabando")
            button.contentTintColor = .systemRed
        } else if isPlaying {
            button.image = NSImage(systemSymbolName: "waveform.circle.fill", accessibilityDescription: "Reproduciendo")
            button.contentTintColor = .systemGreen
        } else {
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "XSpaceRecorder")
            button.contentTintColor = nil
        }
    }

    func updateMenubarMenu() {
        updateMenubarIcon()
        guard let menu = menubarStatusItem.menu else { return }
        
        var statusText = "Status: IDLE"
        if isRecording { statusText = "🔴 GRABANDO" }
        else if isPlaying { statusText = "🔊 ESCUCHANDO" }

        if let statusItem = menu.item(withTag: 100) { statusItem.title = statusText }
        if let timerItem = menu.item(withTag: 101) { timerItem.title = timerLabel?.stringValue ?? "00:00:00" }
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }

    func setupWindow() {
        mainWindow = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 1100, height: 700), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        mainWindow.title = ""
        mainWindow.titlebarAppearsTransparent = true
        mainWindow.titleVisibility = .hidden
        mainWindow.minSize = NSSize(width: 980, height: 640)

        let contentView = mainWindow.contentView!

        splitView = NSSplitView()
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(splitView)

        NSLayoutConstraint.activate([
            splitView.topAnchor.constraint(equalTo: contentView.topAnchor),
            splitView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            splitView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        sidebarView = NSVisualEffectView()
        sidebarView.material = .sidebar
        sidebarView.blendingMode = .behindWindow
        sidebarView.translatesAutoresizingMaskIntoConstraints = false
        sidebarView.widthAnchor.constraint(equalToConstant: 240).isActive = true
        splitView.addArrangedSubview(sidebarView)

        createSidebar()

        let contentWrapper = NSView()
        contentWrapper.translatesAutoresizingMaskIntoConstraints = false

        mainContentView = NSView()
        mainContentView.translatesAutoresizingMaskIntoConstraints = false
        contentWrapper.addSubview(mainContentView)
        
        NSLayoutConstraint.activate([
            mainContentView.topAnchor.constraint(equalTo: contentWrapper.topAnchor),
            mainContentView.leadingAnchor.constraint(equalTo: contentWrapper.leadingAnchor),
            mainContentView.trailingAnchor.constraint(equalTo: contentWrapper.trailingAnchor),
            mainContentView.bottomAnchor.constraint(equalTo: contentWrapper.bottomAnchor)
        ])

        splitView.addArrangedSubview(contentWrapper)
        
        recordContainerView = NSView()
        recordContainerView.translatesAutoresizingMaskIntoConstraints = false
        mainContentView.addSubview(recordContainerView)
        
        NSLayoutConstraint.activate([
            recordContainerView.topAnchor.constraint(equalTo: mainContentView.topAnchor),
            recordContainerView.leadingAnchor.constraint(equalTo: mainContentView.leadingAnchor),
            recordContainerView.trailingAnchor.constraint(equalTo: mainContentView.trailingAnchor),
            recordContainerView.bottomAnchor.constraint(equalTo: mainContentView.bottomAnchor)
        ])
        
        createRecordArea()
        
        createContentArea()
        createContentViews()
        showInputState()

        mainWindow.center()
        mainWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func createSidebar() {
        let navStack = NSStackView()
        navStack.orientation = .vertical
        navStack.spacing = 4
        navStack.translatesAutoresizingMaskIntoConstraints = false
        sidebarView.addSubview(navStack)

        let footerView = NSView()
        footerView.wantsLayer = true
        footerView.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.5).cgColor
        footerView.layer?.cornerRadius = 12
        footerView.translatesAutoresizingMaskIntoConstraints = false
        sidebarView.addSubview(footerView)

        NSLayoutConstraint.activate([
            navStack.topAnchor.constraint(equalTo: sidebarView.topAnchor, constant: 12),
            navStack.leadingAnchor.constraint(equalTo: sidebarView.leadingAnchor, constant: 8),
            navStack.trailingAnchor.constraint(equalTo: sidebarView.trailingAnchor, constant: -8),
            navStack.bottomAnchor.constraint(equalTo: footerView.topAnchor, constant: -12),
            
            footerView.leadingAnchor.constraint(equalTo: sidebarView.leadingAnchor, constant: 12),
            footerView.trailingAnchor.constraint(equalTo: sidebarView.trailingAnchor, constant: -12),
            footerView.bottomAnchor.constraint(equalTo: sidebarView.bottomAnchor, constant: -12),
            footerView.heightAnchor.constraint(equalToConstant: 56)
        ])

        let sections: [(String, [(String, String)])] = [
            ("PRINCIPAL", [("🎧", "Escuchar"), ("🔴", "Grabar"), ("⬇", "Descargas")]),
            ("JOBS", [("📋", "Cola"), ("⚡", "Activos")]),
            ("BIBLIOTECA", [("⭐", "Favoritos"), ("👥", "Following")]),
            ("SISTEMA", [("⚙", "Settings")])
        ]
        
        for (title, items) in sections {
            let header = NSTextField(labelWithString: title)
            header.font = NSFont.systemFont(ofSize: 11, weight: .medium)
            header.textColor = .secondaryLabelColor
            navStack.addArrangedSubview(header)

            for (icon, name) in items {
                let btn = NSButton(title: "  \(icon)  \(name)", target: self, action: #selector(sidebarAction(_:)))
                btn.bezelStyle = .rounded
                btn.font = NSFont.systemFont(ofSize: 13)
                btn.wantsLayer = true
                btn.isBordered = false
                btn.layer?.cornerRadius = 6
                btn.heightAnchor.constraint(equalToConstant: 28).isActive = true
                btn.alignment = .left
                navStack.addArrangedSubview(btn)
            }
        }

        navStack.addArrangedSubview(NSView())

        let profileBtn = NSButton(title: "", target: self, action: #selector(showProfile))
        profileBtn.wantsLayer = true
        profileBtn.layer?.backgroundColor = NSColor.clear.cgColor
        profileBtn.layer?.cornerRadius = 10
        profileBtn.isBordered = false
        profileBtn.translatesAutoresizingMaskIntoConstraints = false
        footerView.addSubview(profileBtn)

        NSLayoutConstraint.activate([
            profileBtn.topAnchor.constraint(equalTo: footerView.topAnchor, constant: 8),
            profileBtn.leadingAnchor.constraint(equalTo: footerView.leadingAnchor, constant: 8),
            profileBtn.trailingAnchor.constraint(equalTo: footerView.trailingAnchor, constant: -8),
            profileBtn.bottomAnchor.constraint(equalTo: footerView.bottomAnchor, constant: -8)
        ])

        let avatarView = NSView()
        avatarView.wantsLayer = true
        avatarView.layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.2).cgColor
        avatarView.layer?.cornerRadius = 17
        avatarView.translatesAutoresizingMaskIntoConstraints = false
        profileBtn.addSubview(avatarView)

        let avatarIcon = NSTextField(labelWithString: "👤")
        avatarIcon.font = NSFont.systemFont(ofSize: 18)
        avatarIcon.translatesAutoresizingMaskIntoConstraints = false
        avatarView.addSubview(avatarIcon)

        let nameLabel = NSTextField(labelWithString: currentUser?.name ?? "Invitado")
        nameLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        profileBtn.addSubview(nameLabel)

        NSLayoutConstraint.activate([
            avatarView.leadingAnchor.constraint(equalTo: profileBtn.leadingAnchor),
            avatarView.centerYAnchor.constraint(equalTo: profileBtn.centerYAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: 34),
            avatarView.heightAnchor.constraint(equalToConstant: 34),
            avatarIcon.centerXAnchor.constraint(equalTo: avatarView.centerXAnchor),
            avatarIcon.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),
            nameLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 10),
            nameLabel.centerYAnchor.constraint(equalTo: profileBtn.centerYAnchor)
        ])
    }

    var currentMenu = "escuchar"
    var contentViews: [String: NSView] = [:]
    var actionButtonsView: NSView!
    var downloadsContainerView: NSView!
    
    @objc func sidebarAction(_ sender: NSButton) {
        let title = sender.title
        if title.contains("Escuchar") { showContent("escuchar") }
        else if title.contains("Grabar") { showContent("grabar") }
        else if title.contains("Descargas") { showContent("descargas") }
        else if title.contains("Cola") { showContent("cola") }
        else if title.contains("Activos") { showContent("activos") }
        else if title.contains("Favoritos") { showContent("favoritos") }
        else if title.contains("Following") { showContent("following") }
        else if title.contains("Settings") { showContent("settings") }
    }
    
    func showContent(_ menu: String) {
        currentMenu = menu
        
        switch menu {
        case "escuchar":
            contentTitleLabel.stringValue = "🎧 Escuchar Spaces"
            centerStack.isHidden = false
            inputContainer.isHidden = false
            playbackView.isHidden = true
            recordContainerView.isHidden = true
        case "grabar":
            contentTitleLabel.stringValue = "🔴 Grabar Spaces"
            centerStack.isHidden = true
            inputContainer.isHidden = true
            playbackView.isHidden = true
            for (_, view) in contentViews { view.isHidden = true }
            mainContentView.addSubview(recordContainerView)
            recordContainerView.isHidden = false
        case "descargas":
            contentTitleLabel.stringValue = "⬇ Descargas"
            centerStack.isHidden = true
            inputContainer.isHidden = true
            playbackView.isHidden = true
            recordContainerView.isHidden = true
        case "cola":
            contentTitleLabel.stringValue = "📋 Cola de Jobs"
            centerStack.isHidden = true
            inputContainer.isHidden = true
            playbackView.isHidden = true
            recordContainerView.isHidden = true
        case "activos":
            contentTitleLabel.stringValue = "⚡ Jobs Activos"
            centerStack.isHidden = true
            inputContainer.isHidden = true
            playbackView.isHidden = true
            recordContainerView.isHidden = true
            activosContainerView.isHidden = false
            updateActivosView()
        case "favoritos":
            contentTitleLabel.stringValue = "⭐ Favoritos"
            centerStack.isHidden = true
            inputContainer.isHidden = true
            playbackView.isHidden = true
            recordContainerView.isHidden = true
        case "following":
            contentTitleLabel.stringValue = "👥 Following"
            centerStack.isHidden = true
            inputContainer.isHidden = true
            playbackView.isHidden = true
            recordContainerView.isHidden = true
        case "settings":
            contentTitleLabel.stringValue = "⚙ Settings"
            centerStack.isHidden = true
            inputContainer.isHidden = true
            playbackView.isHidden = true
            recordContainerView.isHidden = true
        default:
            break
        }
        
        for (key, view) in contentViews {
            view.isHidden = key != menu
        }
        
        if menu == "descargas" {
            refreshDownloads()
        }
    }
    
    func refreshDownloads() {
        let fileManager = FileManager.default
        do {
            let files = try fileManager.contentsOfDirectory(atPath: savePath)
            downloadedFiles = files.filter { $0.hasSuffix(".m4a") || $0.hasSuffix(".mp3") || $0.hasSuffix(".wav") }
            downloadedFiles.sort { f1, f2 in
                let d1 = (try? fileManager.attributesOfItem(atPath: savePath + "/" + f1)[.modificationDate] as? Date) ?? Date.distantPast
                let d2 = (try? fileManager.attributesOfItem(atPath: savePath + "/" + f2)[.modificationDate] as? Date) ?? Date.distantPast
                return d1 > d2
            }
        } catch {
            downloadedFiles = []
        }
        downloadsTableView?.reloadData()
    }
    
    func createDownloadsView() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.autohidesScrollers = true
        container.addSubview(scrollView)
        
        downloadsTableView = NSTableView()
        downloadsTableView.delegate = self
        downloadsTableView.dataSource = self
        downloadsTableView.headerView = nil
        downloadsTableView.rowHeight = 50
        downloadsTableView.backgroundColor = .clear
        downloadsTableView.usesAlternatingRowBackgroundColors = true
        
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.width = 400
        downloadsTableView.addTableColumn(nameColumn)
        
        let actionsColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("actions"))
        actionsColumn.width = 100
        downloadsTableView.addTableColumn(actionsColumn)
        
        scrollView.documentView = downloadsTableView
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: container.topAnchor, constant: 60),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20)
        ])
        
        return container
    }
    
    func createActivosView() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let headerStack = NSStackView()
        headerStack.orientation = .horizontal
        headerStack.spacing = 12
        headerStack.alignment = .centerY
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(headerStack)
        
        let titleLabel = NSTextField(labelWithString: "⚡ Activos")
        titleLabel.font = NSFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = .labelColor
        headerStack.addArrangedSubview(titleLabel)
        
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        headerStack.addArrangedSubview(spacer)
        
        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            headerStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            headerStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            headerStack.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        let contentStack = NSStackView()
        contentStack.orientation = .vertical
        contentStack.spacing = 16
        contentStack.alignment = .centerX
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(contentStack)
        
        NSLayoutConstraint.activate([
            contentStack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            contentStack.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        
        activeStatusLabel = NSTextField(labelWithString: "No hay descargas activas")
        activeStatusLabel.font = NSFont.systemFont(ofSize: 16)
        activeStatusLabel.textColor = .secondaryLabelColor
        activeStatusLabel.alignment = .center
        contentStack.addArrangedSubview(activeStatusLabel)
        
        activeProgressIndicator = NSProgressIndicator()
        activeProgressIndicator.style = .bar
        activeProgressIndicator.isIndeterminate = false
        activeProgressIndicator.minValue = 0
        activeProgressIndicator.maxValue = 100
        activeProgressIndicator.isHidden = true
        activeProgressIndicator.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(activeProgressIndicator)
        
        NSLayoutConstraint.activate([
            activeProgressIndicator.widthAnchor.constraint(equalToConstant: 400)
        ])
        
        return container
    }
    
    func createCompletadosView() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let headerStack = NSStackView()
        headerStack.orientation = .horizontal
        headerStack.spacing = 12
        headerStack.alignment = .centerY
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(headerStack)
        
        let titleLabel = NSTextField(labelWithString: "✅ Completados")
        titleLabel.font = NSFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = .labelColor
        headerStack.addArrangedSubview(titleLabel)
        
        let countLabel = NSTextField(labelWithString: "(\(downloadedFiles.count) archivos)")
        countLabel.font = NSFont.systemFont(ofSize: 14)
        countLabel.textColor = .secondaryLabelColor
        headerStack.addArrangedSubview(countLabel)
        
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        headerStack.addArrangedSubview(spacer)
        
        let refreshBtn = NSButton(title: "🔄", target: self, action: #selector(refreshDownloadsList))
        refreshBtn.bezelStyle = .circular
        headerStack.addArrangedSubview(refreshBtn)
        
        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            headerStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            headerStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            headerStack.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.autohidesScrollers = true
        container.addSubview(scrollView)
        
        completadosTableView = NSTableView()
        completadosTableView.delegate = self
        completadosTableView.dataSource = self
        completadosTableView.rowHeight = 60
        completadosTableView.backgroundColor = .clear
        completadosTableView.usesAlternatingRowBackgroundColors = true
        completadosTableView.style = .inset
        
        let fileColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("compfile"))
        fileColumn.title = "Archivo"
        fileColumn.width = 350
        completadosTableView.addTableColumn(fileColumn)
        
        let dateColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("compdate"))
        dateColumn.title = "Fecha"
        dateColumn.width = 150
        completadosTableView.addTableColumn(dateColumn)
        
        let actionsColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("compactions"))
        actionsColumn.title = "Acciones"
        actionsColumn.width = 120
        completadosTableView.addTableColumn(actionsColumn)
        
        scrollView.documentView = completadosTableView
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20)
        ])
        
        return container
    }
    
    @objc func refreshDownloadsList() {
        refreshDownloads()
    }
    
    func updateActivosView() {
        if isDownloading {
            activeStatusLabel?.stringValue = "Descargando: \(currentDownloadFilename)"
            activeProgressIndicator?.isHidden = false
            activeProgressIndicator?.doubleValue = recordProgressIndicator?.doubleValue ?? 0
        } else {
            activeStatusLabel?.stringValue = "No hay descargas activas"
            activeProgressIndicator?.isHidden = true
        }
    }
    
    func createContentViews() {
        let escucharView = NSView()
        escucharView.translatesAutoresizingMaskIntoConstraints = false
        mainContentView.addSubview(escucharView)
        contentViews["escuchar"] = escucharView
        
        let emptyGrabarView = NSView()
        emptyGrabarView.isHidden = true
        mainContentView.addSubview(emptyGrabarView)
        contentViews["grabar"] = emptyGrabarView
        
        let descargasView = createDescargasView()
        descargasView.isHidden = true
        mainContentView.addSubview(descargasView)
        contentViews["descargas"] = descargasView
        
        let colaView = createJobsView(status: "pending")
        colaView.isHidden = true
        mainContentView.addSubview(colaView)
        contentViews["cola"] = colaView
        
        activosContainerView = createActivosView()
        activosContainerView.isHidden = true
        mainContentView.addSubview(activosContainerView)
        contentViews["activos"] = activosContainerView
        
        completadosContainerView = createCompletadosView()
        completadosContainerView.isHidden = true
        mainContentView.addSubview(completadosContainerView)
        contentViews["completados"] = completadosContainerView
        
        let favoritosView = createFavoritesView()
        favoritosView.isHidden = true
        mainContentView.addSubview(favoritosView)
        contentViews["favoritos"] = favoritosView
        
        let followingView = createFollowingView()
        followingView.isHidden = true
        mainContentView.addSubview(followingView)
        contentViews["following"] = followingView
        
        let settingsView = createSettingsView()
        settingsView.isHidden = true
        mainContentView.addSubview(settingsView)
        contentViews["settings"] = settingsView
        
        for (_, view) in contentViews {
            view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                view.topAnchor.constraint(equalTo: mainContentView.topAnchor),
                view.leadingAnchor.constraint(equalTo: mainContentView.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: mainContentView.trailingAnchor),
                view.bottomAnchor.constraint(equalTo: mainContentView.bottomAnchor)
            ])
        }
    }
    
    func createDescargasView() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let headerStack = NSStackView()
        headerStack.orientation = .horizontal
        headerStack.spacing = 12
        headerStack.alignment = .centerY
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(headerStack)
        
        let titleLabel = NSTextField(labelWithString: "⬇ Descargas")
        titleLabel.font = NSFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = .labelColor
        headerStack.addArrangedSubview(titleLabel)
        
        let countLabel = NSTextField(labelWithString: "(\(downloadedFiles.count) archivos)")
        countLabel.font = NSFont.systemFont(ofSize: 14)
        countLabel.textColor = .secondaryLabelColor
        countLabel.tag = 400
        headerStack.addArrangedSubview(countLabel)
        
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        headerStack.addArrangedSubview(spacer)
        
        let refreshBtn = NSButton(title: "🔄", target: self, action: #selector(refreshDownloadsList))
        refreshBtn.bezelStyle = .circular
        headerStack.addArrangedSubview(refreshBtn)
        
        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            headerStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            headerStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            headerStack.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.autohidesScrollers = true
        container.addSubview(scrollView)
        
        let tableView = NSTableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = 60
        tableView.backgroundColor = .clear
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.style = .inset
        
        downloadsTableView = tableView
        
        let fileColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("downfile"))
        fileColumn.title = "Archivo"
        fileColumn.width = 350
        tableView.addTableColumn(fileColumn)
        
        let dateColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("downdate"))
        dateColumn.title = "Fecha"
        dateColumn.width = 150
        tableView.addTableColumn(dateColumn)
        
        let actionsColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("downactions"))
        actionsColumn.title = "Acciones"
        actionsColumn.width = 120
        tableView.addTableColumn(actionsColumn)
        
        scrollView.documentView = tableView
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20)
        ])
        
        return container
    }
    
    func createEscucharView() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        mainContentView.addSubview(container)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: mainContentView.topAnchor),
            container.leadingAnchor.constraint(equalTo: mainContentView.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: mainContentView.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: mainContentView.bottomAnchor)
        ])
        
        let centerStack = NSStackView()
        centerStack.orientation = .vertical
        centerStack.spacing = 24
        centerStack.alignment = .centerX
        centerStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(centerStack)
        
        NSLayoutConstraint.activate([
            centerStack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            centerStack.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        
        inputContainer = NSView()
        inputContainer.wantsLayer = true
        inputContainer.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        inputContainer.layer?.cornerRadius = 12
        inputContainer.layer?.borderColor = NSColor.separatorColor.cgColor
        inputContainer.layer?.borderWidth = 1
        inputContainer.translatesAutoresizingMaskIntoConstraints = false
        centerStack.addArrangedSubview(inputContainer)
        
        NSLayoutConstraint.activate([
            inputContainer.widthAnchor.constraint(equalToConstant: 600),
            inputContainer.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        let inputStack = NSStackView()
        inputStack.orientation = .horizontal
        inputStack.spacing = 10
        inputStack.alignment = .centerY
        inputStack.translatesAutoresizingMaskIntoConstraints = false
        inputContainer.addSubview(inputStack)
        
        NSLayoutConstraint.activate([
            inputStack.topAnchor.constraint(equalTo: inputContainer.topAnchor, constant: 8),
            inputStack.leadingAnchor.constraint(equalTo: inputContainer.leadingAnchor, constant: 16),
            inputStack.trailingAnchor.constraint(equalTo: inputContainer.trailingAnchor, constant: -16),
            inputStack.bottomAnchor.constraint(equalTo: inputContainer.bottomAnchor, constant: -8)
        ])
        
        let linkIcon = NSTextField(labelWithString: "🔗")
        linkIcon.font = NSFont.systemFont(ofSize: 16)
        linkIcon.textColor = .secondaryLabelColor
        inputStack.addArrangedSubview(linkIcon)
        
        inputField = NSTextField()
        inputField.textColor = .labelColor
        inputField.backgroundColor = .clear
        inputField.font = NSFont.systemFont(ofSize: 15)
        inputField.placeholderString = "Pega enlace del Space de X..."
        inputField.isBordered = false
        inputField.isEditable = true
        inputField.focusRingType = .none
        inputField.usesSingleLineMode = true
        inputField.translatesAutoresizingMaskIntoConstraints = false
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        menu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        menu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        menu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        inputField.menu = menu
        
        inputStack.addArrangedSubview(inputField)
        
        NSLayoutConstraint.activate([inputField.widthAnchor.constraint(greaterThanOrEqualToConstant: 450)])
        
        return container
    }
    
    func createGenericView(title: String, desc: String) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
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
        
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 24, weight: .bold)
        stack.addArrangedSubview(titleLabel)
        
        let descLabel = NSTextField(labelWithString: desc)
        descLabel.font = NSFont.systemFont(ofSize: 14)
        descLabel.textColor = .secondaryLabelColor
        stack.addArrangedSubview(descLabel)
        
        return container
    }
    
    func createJobsView(status: String) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let headerStack = NSStackView()
        headerStack.orientation = .horizontal
        headerStack.spacing = 12
        headerStack.alignment = .centerY
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(headerStack)
        
        let titleLabel = NSTextField(labelWithString: status == "pending" ? "📋 Cola" : "⚡ Activos")
        titleLabel.font = NSFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = .labelColor
        headerStack.addArrangedSubview(titleLabel)
        
        let countLabel = NSTextField(labelWithString: "(\(jobs.filter { $0.status == status }.count) items)")
        countLabel.font = NSFont.systemFont(ofSize: 14)
        countLabel.textColor = .secondaryLabelColor
        headerStack.addArrangedSubview(countLabel)
        
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        headerStack.addArrangedSubview(spacer)
        
        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            headerStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            headerStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            headerStack.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.autohidesScrollers = true
        container.addSubview(scrollView)
        
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        let clipView = NSClipView()
        clipView.documentView = stack
        scrollView.contentView = clipView
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: clipView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: clipView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: clipView.trailingAnchor)
        ])
        
        let filteredJobs = jobs.filter { $0.status == status }
        
        if filteredJobs.isEmpty {
            let empty = NSTextField(labelWithString: "No hay jobs en cola")
            empty.font = NSFont.systemFont(ofSize: 14)
            empty.textColor = .tertiaryLabelColor
            empty.alignment = .center
            stack.addArrangedSubview(empty)
        } else {
            for job in filteredJobs.prefix(20) {
                let jobCard = createJobCard(job: job)
                stack.addArrangedSubview(jobCard)
            }
        }
        
        return container
    }
    
    func createJobCard(job: Job) -> NSView {
        let card = NSView()
        card.wantsLayer = true
        card.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        card.layer?.cornerRadius = 10
        card.translatesAutoresizingMaskIntoConstraints = false
        
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 4
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        
        let actionLabel = NSTextField(labelWithString: job.action == "record" ? "🔴 Grabar" : "⬇ Descargar")
        actionLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        actionLabel.textColor = .labelColor
        stack.addArrangedSubview(actionLabel)
        
        let urlLabel = NSTextField(labelWithString: job.spaceURL)
        urlLabel.font = NSFont.systemFont(ofSize: 12)
        urlLabel.textColor = .secondaryLabelColor
        urlLabel.lineBreakMode = .byTruncatingMiddle
        stack.addArrangedSubview(urlLabel)
        
        let statusLabel = NSTextField(labelWithString: job.status == "pending" ? "⏳ Pendiente" : "⚡ En progreso")
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.textColor = job.status == "pending" ? .tertiaryLabelColor : .systemGreen
        stack.addArrangedSubview(statusLabel)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
            card.widthAnchor.constraint(greaterThanOrEqualToConstant: 300)
        ])
        
        return card
    }
    
    func createFavoritesView() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20)
        ])
        
        let header = NSTextField(labelWithString: "⭐ Favoritos")
        header.font = NSFont.systemFont(ofSize: 18, weight: .bold)
        stack.addArrangedSubview(header)
        
        if favoritesSpaces.isEmpty {
            let empty = NSTextField(labelWithString: "No hay favoritos")
            empty.font = NSFont.systemFont(ofSize: 13)
            empty.textColor = .tertiaryLabelColor
            stack.addArrangedSubview(empty)
        }
        
        return container
    }
    
    func createFollowingView() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20)
        ])
        
        let header = NSTextField(labelWithString: "👥 Following")
        header.font = NSFont.systemFont(ofSize: 18, weight: .bold)
        stack.addArrangedSubview(header)
        
        let addBtn = NSButton(title: "+ Agregar cuenta", target: self, action: #selector(addFollowing))
        addBtn.bezelStyle = .rounded
        stack.addArrangedSubview(addBtn)
        
        return container
    }
    
    func createSettingsView() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20)
        ])
        
        let header = NSTextField(labelWithString: "⚙ Settings")
        header.font = NSFont.systemFont(ofSize: 18, weight: .bold)
        stack.addArrangedSubview(header)
        
        let bufferLabel = NSTextField(labelWithString: "Tiempo de buffer:")
        bufferLabel.font = NSFont.systemFont(ofSize: 12)
        stack.addArrangedSubview(bufferLabel)
        
        let currentBuffer = UserDefaults.standard.integer(forKey: "bufferTime")
        let bufferValue = currentBuffer > 0 ? currentBuffer : 15
        
        let bufferSlider = NSSlider(value: Double(bufferValue), minValue: 5, maxValue: 60, target: self, action: #selector(bufferTimeChanged(_:)))
        bufferSlider.numberOfTickMarks = 12
        bufferSlider.allowsTickMarkValuesOnly = true
        stack.addArrangedSubview(bufferSlider)
        
        let bufferValueLabel = NSTextField(labelWithString: "\(bufferValue) segundos")
        bufferValueLabel.font = NSFont.systemFont(ofSize: 11)
        bufferValueLabel.textColor = .secondaryLabelColor
        bufferValueLabel.tag = 300
        stack.addArrangedSubview(bufferValueLabel)
        
        let bufferRecordLabel = NSTextField(labelWithString: "Buffer para grabar desde inicio:")
        bufferRecordLabel.font = NSFont.systemFont(ofSize: 12)
        stack.addArrangedSubview(bufferRecordLabel)
        
        let currentRecordBuffer = UserDefaults.standard.integer(forKey: "recordBufferTime")
        let recordBufferValue = currentRecordBuffer > 0 ? currentRecordBuffer : 30
        
        let recordBufferSlider = NSSlider(value: Double(recordBufferValue), minValue: 10, maxValue: 120, target: self, action: #selector(recordBufferTimeChanged(_:)))
        recordBufferSlider.numberOfTickMarks = 12
        recordBufferSlider.allowsTickMarkValuesOnly = true
        stack.addArrangedSubview(recordBufferSlider)
        
        let recordBufferValueLabel = NSTextField(labelWithString: "\(recordBufferValue) segundos")
        recordBufferValueLabel.font = NSFont.systemFont(ofSize: 11)
        recordBufferValueLabel.textColor = .secondaryLabelColor
        recordBufferValueLabel.tag = 301
        stack.addArrangedSubview(recordBufferValueLabel)
        
        let pathLabel = NSTextField(labelWithString: "Carpeta: \(savePath)")
        pathLabel.font = NSFont.systemFont(ofSize: 12)
        pathLabel.textColor = .secondaryLabelColor
        pathLabel.lineBreakMode = .byTruncatingMiddle
        stack.addArrangedSubview(pathLabel)
        
        let changeBtn = NSButton(title: "Cambiar carpeta", target: self, action: #selector(changePath))
        changeBtn.bezelStyle = .rounded
        stack.addArrangedSubview(changeBtn)
        
        return container
    }
    
    @objc func bufferTimeChanged(_ sender: NSSlider) {
        let value = Int(sender.intValue)
        UserDefaults.standard.set(value, forKey: "bufferTime")
        if let menu = menubarStatusItem.menu,
           let label = menu.item(withTag: 300) {
            label.title = "\(value) segundos"
        }
    }
    
    @objc func recordBufferTimeChanged(_ sender: NSSlider) {
        let value = Int(sender.intValue)
        UserDefaults.standard.set(value, forKey: "recordBufferTime")
    }
    
    @objc func addFollowing() {
        let alert = NSAlert()
        alert.messageText = "Agregar cuenta"
        alert.informativeText = "Ingresa @username"
        alert.addButton(withTitle: "Agregar")
        alert.addButton(withTitle: "Cancelar")
        
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        input.placeholderString = "@cuenta"
        alert.accessoryView = input
        
        if alert.runModal() == .alertFirstButtonReturn && !input.stringValue.isEmpty {
            var username = input.stringValue
            if username.hasPrefix("@") { username = String(username.dropFirst()) }
            followingAccounts.append(["username": username])
            if let data = try? JSONEncoder().encode(followingAccounts) {
                UserDefaults.standard.set(data, forKey: followingKey)
            }
        }
    }
    
    @objc func changePath() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        if panel.runModal() == .OK, let path = panel.url?.path {
            savePath = path
            UserDefaults.standard.set(path, forKey: pathKey)
        }
    }
    
    @objc func showProfile() {
        let alert = NSAlert()
        alert.messageText = "👤 \(currentUser?.name ?? "Invitado")"
        alert.informativeText = "Sesiones: \(activityLogs.count)\nJobs: \(jobs.count)"
        alert.addButton(withTitle: "Cerrar")
        alert.runModal()
    }
    
    func showDownloads() {
        showAlert(title: "⬇ Descargas", message: "Archivos descargados se guardan en:\n\(savePath)")
    }
    
    func showJobsQueue() {
        let pendingJobs = jobs.filter { $0.status == "pending" }
        if pendingJobs.isEmpty {
            showAlert(title: "📋 Cola de Jobs", message: "No hay jobs pendientes")
        } else {
            let jobList = pendingJobs.map { "• \($0.action): \($0.spaceURL)" }.joined(separator: "\n")
            showAlert(title: "📋 Cola de Jobs (\(pendingJobs.count))", message: jobList)
        }
    }
    
    func showActiveJobs() {
        let runningJobs = jobs.filter { $0.status == "running" }
        if runningJobs.isEmpty {
            showAlert(title: "⚡ Jobs Activos", message: "No hay jobs activos")
        } else {
            let jobList = runningJobs.map { "• \($0.action): \($0.spaceURL)" }.joined(separator: "\n")
            showAlert(title: "⚡ Jobs Activos (\(runningJobs.count))", message: jobList)
        }
    }
    
    func showCompletedJobs() {
        let completedJobs = jobs.filter { $0.status == "completed" }
        if completedJobs.isEmpty {
            showAlert(title: "✅ Jobs Completados", message: "No hay jobs completados")
        } else {
            let jobList = completedJobs.prefix(10).map { "• \($0.action): \($0.spaceURL)" }.joined(separator: "\n")
            showAlert(title: "✅ Jobs Completados (\(completedJobs.count))", message: jobList)
        }
    }
    
    func showFollowing() {
        if followingAccounts.isEmpty {
            showAlert(title: "👥 Following", message: "No hay cuentas seguidas\n\nAgrega cuentas para recibir notificaciones cuando estén en vivo")
        } else {
            let accountList = followingAccounts.map { "• @\($0["username"] ?? "")" }.joined(separator: "\n")
            showAlert(title: "👥 Following (\(followingAccounts.count))", message: accountList)
        }
    }

    func createRecordArea() {
        recordContainerView.wantsLayer = true
        recordContainerView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        let centerStack = NSStackView()
        centerStack.orientation = .vertical
        centerStack.spacing = 24
        centerStack.alignment = .centerX
        centerStack.translatesAutoresizingMaskIntoConstraints = false
        recordContainerView.addSubview(centerStack)
        
        NSLayoutConstraint.activate([
            centerStack.centerXAnchor.constraint(equalTo: recordContainerView.centerXAnchor),
            centerStack.centerYAnchor.constraint(equalTo: recordContainerView.centerYAnchor),
            centerStack.topAnchor.constraint(greaterThanOrEqualTo: recordContainerView.topAnchor, constant: 40)
        ])
        
        let titleLabel = NSTextField(labelWithString: "🔴 Grabar Space")
        titleLabel.font = NSFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = .labelColor
        centerStack.addArrangedSubview(titleLabel)
        
        let descLabel = NSTextField(labelWithString: "Descarga un Space desde el inicio hasta el momento actual")
        descLabel.font = NSFont.systemFont(ofSize: 13)
        descLabel.textColor = .secondaryLabelColor
        centerStack.addArrangedSubview(descLabel)
        
        let inputContainer = NSView()
        inputContainer.wantsLayer = true
        inputContainer.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        inputContainer.layer?.cornerRadius = 12
        inputContainer.layer?.borderColor = NSColor.separatorColor.cgColor
        inputContainer.layer?.borderWidth = 1
        inputContainer.translatesAutoresizingMaskIntoConstraints = false
        centerStack.addArrangedSubview(inputContainer)
        
        NSLayoutConstraint.activate([
            inputContainer.widthAnchor.constraint(equalToConstant: 600),
            inputContainer.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        let inputStack = NSStackView()
        inputStack.orientation = .horizontal
        inputStack.spacing = 10
        inputStack.alignment = .centerY
        inputStack.translatesAutoresizingMaskIntoConstraints = false
        inputContainer.addSubview(inputStack)
        
        NSLayoutConstraint.activate([
            inputStack.topAnchor.constraint(equalTo: inputContainer.topAnchor, constant: 8),
            inputStack.leadingAnchor.constraint(equalTo: inputContainer.leadingAnchor, constant: 16),
            inputStack.trailingAnchor.constraint(equalTo: inputContainer.trailingAnchor, constant: -16),
            inputStack.bottomAnchor.constraint(equalTo: inputContainer.bottomAnchor, constant: -8)
        ])
        
        let linkIcon = NSTextField(labelWithString: "🔗")
        linkIcon.font = NSFont.systemFont(ofSize: 16)
        linkIcon.textColor = .secondaryLabelColor
        inputStack.addArrangedSubview(linkIcon)
        
        recordInputField = NSTextField()
        recordInputField.textColor = .labelColor
        recordInputField.backgroundColor = .clear
        recordInputField.font = NSFont.systemFont(ofSize: 15)
        recordInputField.placeholderString = "Pega enlace del Space de X..."
        recordInputField.isBordered = false
        recordInputField.isEditable = true
        recordInputField.isSelectable = true
        recordInputField.focusRingType = .none
        recordInputField.delegate = self
        recordInputField.translatesAutoresizingMaskIntoConstraints = false
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        menu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        menu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        menu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        recordInputField.menu = menu
        
        inputStack.addArrangedSubview(recordInputField)
        
        NSLayoutConstraint.activate([recordInputField.widthAnchor.constraint(greaterThanOrEqualToConstant: 450)])
        
        recordSaveBtn = NSButton(title: "🔴 Iniciar", target: self, action: #selector(startRecordDownload))
        recordSaveBtn.bezelStyle = .rounded
        recordSaveBtn.wantsLayer = true
        recordSaveBtn.layer?.backgroundColor = NSColor.systemRed.cgColor
        recordSaveBtn.contentTintColor = .white
        recordSaveBtn.layer?.cornerRadius = 8
        recordSaveBtn.heightAnchor.constraint(equalToConstant: 28).isActive = true
        recordSaveBtn.widthAnchor.constraint(equalToConstant: 100).isActive = true
        inputStack.addArrangedSubview(recordSaveBtn)
        
        recordProgressIndicator = NSProgressIndicator()
        recordProgressIndicator.style = .bar
        recordProgressIndicator.isIndeterminate = false
        recordProgressIndicator.minValue = 0
        recordProgressIndicator.maxValue = 100
        recordProgressIndicator.doubleValue = 0
        recordProgressIndicator.translatesAutoresizingMaskIntoConstraints = false
        recordProgressIndicator.isHidden = true
        centerStack.addArrangedSubview(recordProgressIndicator)
        
        NSLayoutConstraint.activate([
            recordProgressIndicator.widthAnchor.constraint(equalToConstant: 400)
        ])
        
        recordStatusLabel = NSTextField(labelWithString: "")
        recordStatusLabel.font = NSFont.systemFont(ofSize: 13)
        recordStatusLabel.textColor = .secondaryLabelColor
        recordStatusLabel.alignment = .center
        centerStack.addArrangedSubview(recordStatusLabel)
        
        recordContainerView.isHidden = true
    }

    func createContentArea() {
        mainContentView.wantsLayer = true
        mainContentView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        centerStack = NSStackView()
        centerStack.orientation = .vertical
        centerStack.spacing = 24
        centerStack.alignment = .centerX
        centerStack.translatesAutoresizingMaskIntoConstraints = false
        mainContentView.addSubview(centerStack)

        NSLayoutConstraint.activate([
            centerStack.centerXAnchor.constraint(equalTo: mainContentView.centerXAnchor),
            centerStack.centerYAnchor.constraint(equalTo: mainContentView.centerYAnchor),
            centerStack.topAnchor.constraint(greaterThanOrEqualTo: mainContentView.topAnchor, constant: 40)
        ])

        contentTitleLabel = NSTextField(labelWithString: "🎧 Escuchar Spaces")
        contentTitleLabel.font = NSFont.systemFont(ofSize: 24, weight: .bold)
        contentTitleLabel.textColor = .labelColor
        centerStack.addArrangedSubview(contentTitleLabel)

        statusLabel = NSTextField(labelWithString: "")
        statusLabel.font = NSFont.systemFont(ofSize: 13)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.alignment = .center
        centerStack.addArrangedSubview(statusLabel)

        inputContainer = NSView()
        inputContainer.wantsLayer = true
        inputContainer.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        inputContainer.layer?.cornerRadius = 12
        inputContainer.layer?.borderColor = NSColor.separatorColor.cgColor
        inputContainer.layer?.borderWidth = 1
        inputContainer.translatesAutoresizingMaskIntoConstraints = false
        centerStack.addArrangedSubview(inputContainer)

        NSLayoutConstraint.activate([
            inputContainer.widthAnchor.constraint(equalToConstant: 600),
            inputContainer.heightAnchor.constraint(equalToConstant: 44)
        ])

        let inputStack = NSStackView()
        inputStack.orientation = .horizontal
        inputStack.spacing = 10
        inputStack.alignment = .centerY
        inputStack.translatesAutoresizingMaskIntoConstraints = false
        inputContainer.addSubview(inputStack)

        NSLayoutConstraint.activate([
            inputStack.topAnchor.constraint(equalTo: inputContainer.topAnchor, constant: 8),
            inputStack.leadingAnchor.constraint(equalTo: inputContainer.leadingAnchor, constant: 16),
            inputStack.trailingAnchor.constraint(equalTo: inputContainer.trailingAnchor, constant: -16),
            inputStack.bottomAnchor.constraint(equalTo: inputContainer.bottomAnchor, constant: -8)
        ])

        let linkIcon = NSTextField(labelWithString: "🔗")
        linkIcon.font = NSFont.systemFont(ofSize: 16)
        linkIcon.textColor = .secondaryLabelColor
        inputStack.addArrangedSubview(linkIcon)

        inputField = NSTextField()
        inputField.textColor = .labelColor
        inputField.backgroundColor = .clear
        inputField.font = NSFont.systemFont(ofSize: 15)
        inputField.placeholderString = "Pega enlace del Space de X..."
        inputField.isBordered = false
        inputField.isEditable = true
        inputField.isSelectable = true
        inputField.focusRingType = .none
        inputField.translatesAutoresizingMaskIntoConstraints = false
        inputField.delegate = self
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        menu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        menu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        menu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        inputField.menu = menu
        
        inputStack.addArrangedSubview(inputField)
        
        NSLayoutConstraint.activate([inputField.widthAnchor.constraint(greaterThanOrEqualToConstant: 450)])
        
        let playBtn = NSButton(title: "▶️ Escuchar", target: self, action: #selector(togglePlay))
        playBtn.bezelStyle = .rounded
        playBtn.wantsLayer = true
        playBtn.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        playBtn.contentTintColor = .white
        playBtn.layer?.cornerRadius = 8
        playBtn.heightAnchor.constraint(equalToConstant: 28).isActive = true
        playBtn.widthAnchor.constraint(equalToConstant: 100).isActive = true
        inputStack.addArrangedSubview(playBtn)
        
        createPlaybackView(in: centerStack)
    }
    
    func createPlaybackView(in parentStack: NSStackView) {
        playbackView = NSView()
        playbackView.wantsLayer = true
        playbackView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        playbackView.layer?.cornerRadius = 16
        playbackView.isHidden = true
        playbackView.translatesAutoresizingMaskIntoConstraints = false
        parentStack.addArrangedSubview(playbackView)
        
        NSLayoutConstraint.activate([
            playbackView.widthAnchor.constraint(equalToConstant: 600),
            playbackView.heightAnchor.constraint(equalToConstant: 200)
        ])
        
        let mainStack = NSStackView()
        mainStack.orientation = .vertical
        mainStack.spacing = 16
        mainStack.alignment = .centerX
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        playbackView.addSubview(mainStack)
        
        NSLayoutConstraint.activate([
            mainStack.centerXAnchor.constraint(equalTo: playbackView.centerXAnchor),
            mainStack.centerYAnchor.constraint(equalTo: playbackView.centerYAnchor)
        ])
        
        timerLabel = NSTextField(labelWithString: "00:00:00")
        timerLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 36, weight: .light)
        timerLabel.textColor = .labelColor
        mainStack.addArrangedSubview(timerLabel)
        
        let headerRow = NSStackView()
        headerRow.orientation = .horizontal
        headerRow.spacing = 16
        headerRow.alignment = .centerY
        mainStack.addArrangedSubview(headerRow)
        
        micIconView = NSView()
        micIconView.wantsLayer = true
        micIconView.layer?.backgroundColor = NSColor.systemRed.withAlphaComponent(0.2).cgColor
        micIconView.layer?.cornerRadius = 30
        micIconView.translatesAutoresizingMaskIntoConstraints = false
        headerRow.addArrangedSubview(micIconView)
        
        NSLayoutConstraint.activate([
            micIconView.widthAnchor.constraint(equalToConstant: 60),
            micIconView.heightAnchor.constraint(equalToConstant: 60)
        ])
        
        let micLabel = NSTextField(labelWithString: "🎙")
        micLabel.font = NSFont.systemFont(ofSize: 32)
        micLabel.translatesAutoresizingMaskIntoConstraints = false
        micIconView.addSubview(micLabel)
        
        NSLayoutConstraint.activate([
            micLabel.centerXAnchor.constraint(equalTo: micIconView.centerXAnchor),
            micLabel.centerYAnchor.constraint(equalTo: micIconView.centerYAnchor)
        ])
        
        let infoStack = NSStackView()
        infoStack.orientation = .vertical
        infoStack.spacing = 4
        infoStack.alignment = .leading
        headerRow.addArrangedSubview(infoStack)
        
        spaceTitleLabel = NSTextField(labelWithString: "Cargando...")
        spaceTitleLabel.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        spaceTitleLabel.textColor = .labelColor
        spaceTitleLabel.lineBreakMode = .byTruncatingTail
        infoStack.addArrangedSubview(spaceTitleLabel)
        
        hostLabel = NSTextField(labelWithString: "EN VIVO")
        hostLabel.font = NSFont.systemFont(ofSize: 13)
        hostLabel.textColor = .secondaryLabelColor
        infoStack.addArrangedSubview(hostLabel)
        
        controlsRow = NSStackView()
        controlsRow.orientation = .horizontal
        controlsRow.spacing = 12
        mainStack.addArrangedSubview(controlsRow)

        playBtn = NSButton(title: "▶️ Play", target: self, action: #selector(togglePlay))
        playBtn.bezelStyle = .rounded
        playBtn.wantsLayer = true
        playBtn.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        playBtn.contentTintColor = .white
        playBtn.layer?.cornerRadius = 8
        playBtn.heightAnchor.constraint(equalToConstant: 36).isActive = true
        playBtn.widthAnchor.constraint(equalToConstant: 100).isActive = true
        controlsRow.addArrangedSubview(playBtn)

        let recordBtn = NSButton(title: "🔴 Guardar", target: self, action: #selector(toggleRecord))
        recordBtn.bezelStyle = .rounded
        recordBtn.wantsLayer = true
        recordBtn.layer?.backgroundColor = NSColor.systemRed.cgColor
        recordBtn.contentTintColor = .white
        recordBtn.layer?.cornerRadius = 8
        recordBtn.heightAnchor.constraint(equalToConstant: 36).isActive = true
        recordBtn.widthAnchor.constraint(equalToConstant: 100).isActive = true
        recordBtn.tag = 200
        controlsRow.addArrangedSubview(recordBtn)
        
        saveBtn = recordBtn
        
        let stopRecordBtn = NSButton(title: "⏹ Stop Rec", target: self, action: #selector(stopSave))
        stopRecordBtn.bezelStyle = .rounded
        stopRecordBtn.wantsLayer = true
        stopRecordBtn.layer?.backgroundColor = NSColor.systemOrange.cgColor
        stopRecordBtn.layer?.cornerRadius = 8
        stopRecordBtn.heightAnchor.constraint(equalToConstant: 36).isActive = true
        stopRecordBtn.widthAnchor.constraint(equalToConstant: 80).isActive = true
        controlsRow.addArrangedSubview(stopRecordBtn)
        
        let separator = NSView()
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor.separatorColor.cgColor
        separator.translatesAutoresizingMaskIntoConstraints = false
        controlsRow.addArrangedSubview(separator)
        separator.widthAnchor.constraint(equalToConstant: 1).isActive = true
        separator.heightAnchor.constraint(equalToConstant: 30).isActive = true
        
        let stopBtn = NSButton(title: "⏹ Stop", target: self, action: #selector(stopAll))
        stopBtn.bezelStyle = .rounded
        stopBtn.wantsLayer = true
        stopBtn.layer?.backgroundColor = NSColor.tertiaryLabelColor.cgColor
        stopBtn.layer?.cornerRadius = 8
        stopBtn.heightAnchor.constraint(equalToConstant: 36).isActive = true
        stopBtn.widthAnchor.constraint(equalToConstant: 80).isActive = true
        controlsRow.addArrangedSubview(stopBtn)
    }

    func showInputState() {
        inputContainer.isHidden = false
        playbackView.isHidden = true
    }

    func showPlaybackState() {
        inputContainer.isHidden = true
        playbackView.isHidden = false
    }

    @objc func togglePlay() {
        if isPaused {
            isPaused = false
            isPlaying = true
            resumePlayback()
            playBtn.title = "⏸ Pausar"
        } else if isPlaying {
            isPlaying = false
            isPaused = true
            pausePlayback()
            playBtn.title = "▶️ Play"
        } else {
            loadSpace()
        }
    }
    
    @objc func togglePause() {
        isPaused.toggle()
        if isPaused { pausePlayback() } else { resumePlayback() }
    }

    @objc func toggleRecord() {
        if isRecording {
            isRecording = false
            isPaused = true
            updateSaveButton()
            pauseRecording()
        } else if isPaused {
            isRecording = true
            isPaused = false
            updateSaveButton()
            resumeRecording()
        } else {
            startRecording()
        }
    }
    
    @objc func stopSave() {
        isRecording = false
        isPaused = false
        stopRecording()
        updateSaveButton()
        showStatus("⏹ Grabación detenida")
    }
    
    @objc func startRecordDownload() {
        recordSaveBtn?.title = "Clicked!"
        showRecordStatus("Button was clicked!")
        
        if isDownloading {
            recordProcess?.terminate()
            recordProcess = nil
            isDownloading = false
            recordSaveBtn?.title = "🔴 Iniciar"
            recordProgressIndicator?.isHidden = true
            showRecordStatus("✅ Guardado en: \(savePath)/\(currentDownloadFilename)")
            return
        }
        
        let url = recordInputField?.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        print("DEBUG: URL = \(url)")
        
        guard !url.isEmpty else { showRecordStatus("❌ Ingresa una URL"); return }
        
        guard isValidXSpaceURL(url) else {
            showRecordStatus("❌ URL inválida")
            return
        }
        
        if isDownloading {
            downloadQueue.append(["url": url, "status": "pending"])
            showRecordStatus("📋 Agregado a cola: \(downloadQueue.count)")
            queueTableView?.reloadData()
            return
        }
        
        recordSaveBtn?.title = "⏹ Detener"
        isDownloading = true
        recordProgressIndicator?.isHidden = false
        recordProgressIndicator?.doubleValue = 0
        
        recordProcess = Process()
        recordProcess?.executableURL = URL(fileURLWithPath: "/bin/bash")
        recordProcess?.currentDirectoryURL = URL(fileURLWithPath: "/Users/molder/projects/github-molder/spaces")
        
        let outputPipe = Pipe()
        recordProcess?.standardOutput = outputPipe
        recordProcess?.standardError = outputPipe
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        currentDownloadFilename = "space_\(dateFormatter.string(from: Date())).m4a"
        
        let checkProcess = Process()
        checkProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
        checkProcess.arguments = ["-c", "curl -sI '\(url)' 2>/dev/null | grep -i 'location' | grep -oE 'state=[a-z]+' | head -1"]
        
        let checkPipe = Pipe()
        checkProcess.standardOutput = checkPipe
        try? checkProcess.run()
        checkProcess.waitUntilExit()
        
        let checkData = checkPipe.fileHandleForReading.readDataToEndOfFile()
        let checkOutput = String(data: checkData, encoding: .utf8)?.lowercased() ?? ""
        
        if checkOutput.contains("ended") {
            showRecordStatus("⬇ Descargando Space completado...")
            currentDownloadFilename = "space_%(title)s_%(timestamp)s.m4a"
            let command = "yt-dlp -x --audio-format m4a '\(url)' -o '\(savePath)/%(title)s_%(timestamp)s.%(ext)s' --progress"
            recordProcess?.arguments = ["-c", command]
        } else {
            let bufferTime = UserDefaults.standard.integer(forKey: "recordBufferTime")
            let bufferSeconds = bufferTime > 0 ? bufferTime : 30
            showRecordStatus("⏳ Espacio en vivo - esperando buffer \(bufferSeconds)s...")
            let command = "sleep \(bufferSeconds) && ./xargspace-record '\(url)' --dir '\(savePath)' 2>&1"
            recordProcess?.arguments = ["-c", command]
        }
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            do {
                try self?.recordProcess?.run()
                
                let outputHandle = outputPipe.fileHandleForReading
                outputHandle.waitForDataInBackgroundAndNotify()
                
                NotificationCenter.default.addObserver(forName: NSNotification.Name.NSFileHandleDataAvailable, object: outputHandle, queue: .main) { notification in
                    let data = outputHandle.availableData
                    if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
                        self?.updateProgress(output: output)
                    }
                }
                
                self?.recordProcess?.waitUntilExit()
                DispatchQueue.main.async {
                    self?.isDownloading = false
                    self?.recordSaveBtn?.title = "🔴 Iniciar"
                    self?.recordProgressIndicator?.isHidden = true
                    self?.showRecordStatus("✅ Completado - Guardado en: \(self?.savePath ?? "")")
                    self?.sendNotification(title: "Space guardado", body: "Se guardó en: \(self?.savePath ?? "")")
                    self?.refreshDownloads()
                }
            } catch {
                DispatchQueue.main.async {
                    self?.showRecordStatus("❌ Error: \(error.localizedDescription)")
                    self?.isDownloading = false
                    self?.recordSaveBtn?.title = "🔴 Iniciar"
                    self?.recordProgressIndicator?.isHidden = true
                }
            }
        }
        
        showRecordStatus(checkOutput.contains("ended") ? "⬇ Descargando..." : "🔴 Grabando desde inicio...")
    }
    
    func sendNotification(title: String, body: String) {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = body
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView == downloadsTableView {
            return downloadedFiles.count
        }
        return downloadQueue.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableView == completadosTableView {
            let file = downloadedFiles[row]
            let filePath = savePath + "/" + file
            let fileManager = FileManager.default
            let fileDate = (try? fileManager.attributesOfItem(atPath: filePath)[.modificationDate] as? Date) ?? Date()
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            
            if tableColumn?.identifier.rawValue == "compfile" {
                let stack = NSStackView()
                stack.orientation = .vertical
                stack.alignment = .leading
                stack.spacing = 4
                
                let nameLabel = NSTextField(labelWithString: file)
                nameLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
                nameLabel.lineBreakMode = .byTruncatingMiddle
                stack.addArrangedSubview(nameLabel)
                
                let sizeLabel = NSTextField(labelWithString: "")
                if let attrs = try? fileManager.attributesOfItem(atPath: filePath),
                   let size = attrs[.size] as? Int64 {
                    sizeLabel.stringValue = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
                }
                sizeLabel.font = NSFont.systemFont(ofSize: 11)
                sizeLabel.textColor = .secondaryLabelColor
                stack.addArrangedSubview(sizeLabel)
                
                return stack
            } else if tableColumn?.identifier.rawValue == "compdate" {
                let cell = NSTextField(labelWithString: dateFormatter.string(from: fileDate))
                cell.font = NSFont.systemFont(ofSize: 12)
                cell.textColor = .secondaryLabelColor
                return cell
            } else if tableColumn?.identifier.rawValue == "compactions" {
                let stack = NSStackView()
                stack.orientation = .horizontal
                stack.spacing = 8
                
                let playBtn = NSButton(image: NSImage(systemSymbolName: "play.circle.fill", accessibilityDescription: "Play")!, target: self, action: #selector(playDownloadedFile(_:)))
                playBtn.bezelStyle = .inline
                playBtn.tag = row
                playBtn.contentTintColor = NSColor.controlAccentColor
                stack.addArrangedSubview(playBtn)
                
                let folderBtn = NSButton(image: NSImage(systemSymbolName: "folder.circle.fill", accessibilityDescription: "Open Folder")!, target: self, action: #selector(openDownloadFolder(_:)))
                folderBtn.bezelStyle = .inline
                folderBtn.contentTintColor = NSColor.secondaryLabelColor
                stack.addArrangedSubview(folderBtn)
                
                let trashBtn = NSButton(image: NSImage(systemSymbolName: "trash.circle.fill", accessibilityDescription: "Delete")!, target: self, action: #selector(deleteDownloadedFile(_:)))
                trashBtn.bezelStyle = .inline
                trashBtn.tag = row
                trashBtn.contentTintColor = NSColor.systemRed
                stack.addArrangedSubview(trashBtn)
                
                return stack
            }
        } else if tableView == downloadsTableView {
            let file = downloadedFiles[row]
            let filePath = savePath + "/" + file
            let fileManager = FileManager.default
            let fileDate = (try? fileManager.attributesOfItem(atPath: filePath)[.modificationDate] as? Date) ?? Date()
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            
            if tableColumn?.identifier.rawValue == "downfile" || tableColumn?.identifier.rawValue == "name" {
                let stack = NSStackView()
                stack.orientation = .vertical
                stack.alignment = .leading
                stack.spacing = 4
                
                let nameLabel = NSTextField(labelWithString: file)
                nameLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
                nameLabel.lineBreakMode = .byTruncatingMiddle
                stack.addArrangedSubview(nameLabel)
                
                let sizeLabel = NSTextField(labelWithString: "")
                if let attrs = try? fileManager.attributesOfItem(atPath: filePath),
                   let size = attrs[.size] as? Int64 {
                    sizeLabel.stringValue = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
                }
                sizeLabel.font = NSFont.systemFont(ofSize: 11)
                sizeLabel.textColor = .secondaryLabelColor
                stack.addArrangedSubview(sizeLabel)
                
                return stack
            } else if tableColumn?.identifier.rawValue == "downdate" {
                let cell = NSTextField(labelWithString: dateFormatter.string(from: fileDate))
                cell.font = NSFont.systemFont(ofSize: 12)
                cell.textColor = .secondaryLabelColor
                return cell
            } else if tableColumn?.identifier.rawValue == "downactions" || tableColumn?.identifier.rawValue == "actions" {
                let stack = NSStackView()
                stack.orientation = .horizontal
                stack.spacing = 8
                
                let playBtn = NSButton(image: NSImage(systemSymbolName: "play.circle.fill", accessibilityDescription: "Play")!, target: self, action: #selector(playDownloadedFile(_:)))
                playBtn.bezelStyle = .inline
                playBtn.tag = row
                playBtn.contentTintColor = NSColor.controlAccentColor
                stack.addArrangedSubview(playBtn)
                
                let folderBtn = NSButton(image: NSImage(systemSymbolName: "folder.circle.fill", accessibilityDescription: "Open Folder")!, target: self, action: #selector(openDownloadFolder(_:)))
                folderBtn.bezelStyle = .inline
                folderBtn.contentTintColor = NSColor.secondaryLabelColor
                stack.addArrangedSubview(folderBtn)
                
                let trashBtn = NSButton(image: NSImage(systemSymbolName: "trash.circle.fill", accessibilityDescription: "Delete")!, target: self, action: #selector(deleteDownloadedFile(_:)))
                trashBtn.bezelStyle = .inline
                trashBtn.tag = row
                trashBtn.contentTintColor = NSColor.systemRed
                stack.addArrangedSubview(trashBtn)
                
                return stack
            }
        } else {
            let item = downloadQueue[row]
            
            if tableColumn?.identifier.rawValue == "queue" {
                let cell = NSTextField(labelWithString: "\(row + 1)")
                cell.font = NSFont.systemFont(ofSize: 13, weight: .bold)
                return cell
            } else if tableColumn?.identifier.rawValue == "qname" {
                let cell = NSTextField(labelWithString: item["url"] ?? "")
                cell.font = NSFont.systemFont(ofSize: 12)
                return cell
            } else if tableColumn?.identifier.rawValue == "qstatus" {
                let status = item["status"] ?? "pending"
                let cell = NSTextField(labelWithString: status)
                if status == "downloading" {
                    cell.textColor = NSColor.systemGreen
                } else if status == "completed" {
                    cell.textColor = NSColor.systemBlue
                } else {
                    cell.textColor = NSColor.secondaryLabelColor
                }
                cell.font = NSFont.systemFont(ofSize: 12)
                return cell
            } else if tableColumn?.identifier.rawValue == "qactions" {
                let stack = NSStackView()
                stack.orientation = .horizontal
                stack.spacing = 4
                
                if item["status"] == "pending" {
                    let deleteBtn = NSButton(image: NSImage(systemSymbolName: "trash", accessibilityDescription: "Delete")!, target: self, action: #selector(deleteFromQueue(_:)))
                    deleteBtn.bezelStyle = .inline
                    deleteBtn.tag = row
                    stack.addArrangedSubview(deleteBtn)
                }
                
                return stack
            }
        }
        return nil
    }
    
    @objc func playDownloadedFile(_ sender: NSButton) {
        let file = downloadedFiles[sender.tag]
        let path = savePath + "/" + file
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }
    
    @objc func openDownloadFolder(_ sender: NSButton) {
        NSWorkspace.shared.open(URL(fileURLWithPath: savePath))
    }
    
    @objc func deleteDownloadedFile(_ sender: NSButton) {
        let file = downloadedFiles[sender.tag]
        let path = savePath + "/" + file
        try? FileManager.default.removeItem(atPath: path)
        refreshDownloads()
    }
    
    @objc func deleteFromQueue(_ sender: NSButton) {
        downloadQueue.remove(at: sender.tag)
        queueTableView?.reloadData()
    }
    
    func showRecordStatus(_ message: String) {
        recordStatusLabel?.stringValue = message
        updateActivosView()
    }
    
    func updateProgress(output: String) {
        if output.contains("%") {
            if let range = output.range(of: "\\d+\\.?\\d*%", options: .regularExpression) {
                let percentStr = output[range].replacingOccurrences(of: "%", with: "")
                if let percent = Double(percentStr) {
                    DispatchQueue.main.async {
                        self.recordProgressIndicator?.doubleValue = percent
                    }
                }
            }
        }
    }
    
    func updateSaveButton() {
        if isRecording {
            saveBtn?.title = "⏸ Pausar"
            if let menu = menubarStatusItem.menu,
               let saveItem = menu.item(withTag: 200) {
                saveItem.title = "⏸ Pausar"
            }
        } else if isPaused {
            saveBtn?.title = "▶️ Continuar"
            if let menu = menubarStatusItem.menu,
               let saveItem = menu.item(withTag: 200) {
                saveItem.title = "▶️ Continuar"
            }
        } else {
            saveBtn?.title = "🔴 Guardar"
            if let menu = menubarStatusItem.menu,
               let saveItem = menu.item(withTag: 200) {
                saveItem.title = "🔴 Guardar"
            }
        }
    }
    
    func loadSpace() {
        let url = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else { showAlert(title: "❌ Error", message: "Ingresa una URL"); return }
        
        guard isValidXSpaceURL(url) else {
            showAlert(title: "❌ URL inválida", message: "La URL debe ser de X/Twitter Spaces")
            return
        }
        
        currentSpaceURL = url
        isBuffering = true
        isPlaying = false
        isRecording = false
        isPaused = false
        
        showPlaybackState()
        spaceTitleLabel?.stringValue = currentSpaceURL
        hostLabel?.stringValue = "🔴 EN VIVO"
        timerLabel?.stringValue = "00:00:00"
        
        startTimer()
        let bufferTime = UserDefaults.standard.integer(forKey: "bufferTime")
        let bufferSeconds = bufferTime > 0 ? bufferTime : 15
        showStatus("⏳ Cargando buffer... \(bufferSeconds)s")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(bufferSeconds)) { [weak self] in
            self?.isBuffering = false
            self?.isPlaying = true
            self?.startPlayback()
            self?.showStatus("▶️ Reproduciendo Space en vivo")
        }
        
        logActivity(action: "load", details: "Cargó Space", spaceURL: currentSpaceURL)
    }
    
    func isValidXSpaceURL(_ url: String) -> Bool {
        let lower = url.lowercased()
        return lower.contains("x.com/i/spaces/") || lower.contains("twitter.com/i/spaces/")
    }
    
    func startPlayback() {
        mpvProcess = Process()
        mpvProcess?.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/mpv")
        mpvProcess?.arguments = [currentSpaceURL, "--no-video", "--idle=no"]
        mpvProcess?.currentDirectoryURL = URL(fileURLWithPath: "/tmp")
        try? mpvProcess?.run()
    }
    
    func pausePlayback() {
        mpvProcess?.suspend()
    }
    
    func resumePlayback() {
        mpvProcess?.resume()
    }
    
    func startRecording() {
        isRecording = true
        animateMicRecording()
        updateSaveButton()
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let filename = "space_\(dateFormatter.string(from: Date())).m4a"
        
        recordProcess = Process()
        recordProcess?.executableURL = URL(fileURLWithPath: "/bin/bash")
        recordProcess?.currentDirectoryURL = URL(fileURLWithPath: "/Users/molder/projects/github-molder/spaces")
        recordProcess?.arguments = ["./xspace-record", currentSpaceURL, "-o", "\(savePath)/\(filename)"]
        try? recordProcess?.run()
        
        showStatus("🔴 Grabando: \(filename)")
        logActivity(action: "record_start", details: "Inició grabación", spaceURL: currentSpaceURL)
    }
    
    func stopRecording() {
        isRecording = false
        isPaused = false
        micIconView?.layer?.backgroundColor = NSColor.systemRed.withAlphaComponent(0.2).cgColor
        
        recordProcess?.terminate()
        recordProcess = nil
        
        addJob(spaceURL: currentSpaceURL, action: "save_local")
        showStatus("✅ Grabación guardada")
        logActivity(action: "record_stop", details: "Detuvo grabación", spaceURL: currentSpaceURL)
    }
    
    func pauseRecording() {
        recordProcess?.suspend()
        showStatus("⏸ Grabación pausada")
    }
    
    func resumeRecording() {
        recordProcess?.resume()
        showStatus("▶️ Grabación continuada")
    }
    
    func animateMicRecording() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] t in
            guard let self = self, self.isRecording else {
                t.invalidate()
                return
            }
            let isRed = self.micIconView?.layer?.backgroundColor == NSColor.systemRed.cgColor
            self.micIconView?.layer?.backgroundColor = isRed ? NSColor.systemRed.withAlphaComponent(0.2).cgColor : NSColor.systemRed.cgColor
        }
    }

    @objc func stopAll() {
        isRecording = false
        isPlaying = false
        isPaused = false
        isBuffering = false
        stopTimer()
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", "pkill -9 -f 'mpv|xspace-record' 2>/dev/null"]
        try? task.run()
        
        showInputState()
        updateMenubarMenu()
        logActivity(action: "stop", details: "Detuvo reproducción", spaceURL: currentSpaceURL)
    }

    func startTimer() {
        startTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in self?.updateTimer() }
        menubarTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in self?.updateMenubarMenu() }
    }

    func stopTimer() {
        timer?.invalidate(); timer = nil
        menubarTimer?.invalidate(); menubarTimer = nil
        startTime = nil
        timerLabel?.stringValue = "00:00:00"
    }

    func updateTimer() {
        guard let start = startTime else { return }
        let elapsed = Int(Date().timeIntervalSince(start))
        let h = elapsed / 3600
        let m = (elapsed % 3600) / 60
        let s = elapsed % 60
        timerLabel?.stringValue = String(format: "%02d:%02d:%02d", h, m, s)
    }

    func addJob(spaceURL: String, action: String) {
        let job = Job(id: UUID().uuidString, spaceURL: spaceURL, status: "completed", action: action, progress: 1.0, createdAt: Date())
        jobs.insert(job, at: 0)
        if jobs.count > 100 { jobs.removeLast() }
        if let data = try? JSONEncoder().encode(jobs) {
            UserDefaults.standard.set(data, forKey: jobsKey)
        }
    }
    
    func loadJobs() {
        if let data = UserDefaults.standard.data(forKey: jobsKey),
           let loaded = try? JSONDecoder().decode([Job].self, from: data) {
            jobs = loaded
        }
    }

    func showStatus(_ message: String) {
        statusLabel?.stringValue = message
        recordStatusLabel?.stringValue = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.statusLabel?.stringValue = ""
            self?.recordStatusLabel?.stringValue = ""
        }
    }
    
    func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    func showFavorites() {
        showAlert(title: "⭐ Favoritos", message: "\(favoritesSpaces.count) espacios guardados")
    }
    
    func showSettings() {
        let alert = NSAlert()
        alert.messageText = "⚙ Settings"
        alert.informativeText = "Carpeta: \(savePath)"
        alert.addButton(withTitle: "Cambiar")
        alert.addButton(withTitle: "Cerrar")
        
        if alert.runModal() == .alertFirstButtonReturn {
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true
            if panel.runModal() == .OK, let path = panel.url?.path {
                savePath = path
                UserDefaults.standard.set(path, forKey: pathKey)
            }
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)

let mainMenu = NSMenu()
let appMenuItem = NSMenuItem()
mainMenu.addItem(appMenuItem)

let appMenu = NSMenu()
appMenuItem.submenu = appMenu

let testItem = NSMenuItem(title: "🧪 Test Download", action: #selector(AppDelegate.testDownload), keyEquivalent: "t")
appMenu.addItem(testItem)

let quitItem = NSMenuItem(title: "Quit XSpaceRecorder", action: #selector(AppDelegate.quitApp), keyEquivalent: "q")
appMenu.addItem(quitItem)

app.mainMenu = mainMenu

let delegate = AppDelegate()
app.delegate = delegate
app.run()
