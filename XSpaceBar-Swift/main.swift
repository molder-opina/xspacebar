import Cocoa
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    
    var statusBar: NSStatusBar!
    var statusItem: NSStatusItem!
    let scriptDir = "/Users/molder/projects/github-molder/spaces"
    var recordingProcess: Process?
    
    override init() {
        super.init()
        statusBar = NSStatusBar()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        requestNotificationPermission()
        setupStatusBar()
    }
    
    func setupStatusBar() {
        statusItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.title = "🎙️"
        }
        
        setupMenu()
    }
    
    func setupMenu() {
        let menu = NSMenu()
        
        let statusMenuItem = NSMenuItem(title: "⏹️ Sin grabación activa", action: nil, keyEquivalent: "")
        statusMenuItem.tag = 100
        menu.addItem(statusMenuItem)
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(createMenuItem(title: "📋 Grabar Space (Portapapeles)", action: #selector(recordSpace)))
        menu.addItem(createMenuItem(title: "📡 Retransmitir a YouTube", action: #selector(restreamYoutube)))
        menu.addItem(createMenuItem(title: "📝 Grabar + Transcribir", action: #selector(recordTranscribe)))
        menu.addItem(createMenuItem(title: "📺 Modo Completo", action: #selector(fullMode)))
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(createMenuItem(title: "⏹️ Detener Grabación", action: #selector(stopRecording)))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(createMenuItem(title: "⚙️ Configuración", action: #selector(openConfig)))
        menu.addItem(createMenuItem(title: "📂 Abrir Carpeta", action: #selector(openFolder)))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(createMenuItem(title: "❌ Salir", action: #selector(quitApp)))
        
        statusItem.menu = menu
    }
    
    func createMenuItem(title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }
    
    @objc func recordSpace() {
        runCommand(["--record"], title: "Grabando Space...")
    }
    
    @objc func restreamYoutube() {
        let alert = NSAlert()
        alert.messageText = "Clave de YouTube"
        alert.informativeText = "Introduce la clave de stream:"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Iniciar")
        alert.addButton(withTitle: "Cancelar")
        
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        input.placeholderString = "Opcional"
        alert.accessoryView = input
        
        if alert.runModal() == .alertFirstButtonReturn {
            let key = input.stringValue.trimmingCharacters(in: .whitespaces)
            if key.isEmpty {
                runCommand(["--restream"], title: "Retransmitiendo...")
            } else {
                runCommand(["--restream", key], title: "Retransmitiendo...")
            }
        }
    }
    
    @objc func recordTranscribe() {
        runCommand(["--transcribe"], title: "Grabando y transcribiendo...")
    }
    
    @objc func fullMode() {
        runCommand(["--restream", "--transcribe"], title: "Modo completo...")
    }
    
    @objc func stopRecording() {
        recordingProcess?.terminate()
        recordingProcess = nil
        updateStatus("⏹️ Sin grabación activa")
    }
    
    @objc func openConfig() {
        runScript("xspace-config")
    }
    
    @objc func openFolder() {
        NSWorkspace.shared.open(URL(fileURLWithPath: scriptDir))
    }
    
    @objc func quitApp() {
        if recordingProcess != nil {
            let alert = NSAlert()
            alert.messageText = "Grabación en curso"
            alert.informativeText = "¿Detener y salir?"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Detener y Salir")
            alert.addButton(withTitle: "Cancelar")
            
            if alert.runModal() == .alertFirstButtonReturn {
                recordingProcess?.terminate()
            } else {
                return
            }
        }
        NSApplication.shared.terminate(self)
    }
    
    func runCommand(_ args: [String], title: String) {
        updateStatus("🔴 " + title)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: scriptDir + "/xspace-record")
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: scriptDir)
        
        do {
            try process.run()
            recordingProcess = process
            
            process.terminationHandler = { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateStatus("⏹️ Sin grabación activa")
                    self?.recordingProcess = nil
                }
            }
        } catch {
            updateStatus("⏹️ Sin grabación activa")
        }
    }
    
    func runScript(_ script: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: scriptDir + "/" + script)
        process.currentDirectoryURL = URL(fileURLWithPath: scriptDir)
        try? process.run()
    }
    
    func updateStatus(_ text: String) {
        if let menu = statusItem.menu,
           let item = menu.item(withTag: 100) {
            item.title = text
        }
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
