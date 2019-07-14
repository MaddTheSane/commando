import Cocoa

class Options: Codable {
	var version: Int = 1
	var command: String = ""
	var options = [OptionController]()
}

class OptionController: Codable {
	var view: NSView!
	var name: String?
	var title: String?
	var value: String?
	var type: String?
	
	private enum CodingKeys: String, CodingKey {
		case name
		case title
		case type
	}
	
	func create(in appDelegate: AppDelegate) {
		switch(type) {
		case "field":
			view = appDelegate.addTextField(title ?? "Label:", value: value ?? "")
		case "filepicker":
			view = appDelegate.addPathField(title ?? "Label:", value: "")
		case "checkbox":
			view = appDelegate.addCheckBox(title ?? "Option")
		default:
			print("error: Unknown type \(type ?? "(nil)").")
		}
	}
}

class AppDelegate: NSObject, NSApplicationDelegate {
	let mainMenu = NSMenu(title: "Main Menu")
	var prevValue: NSView?
	var contentView: NSView!
	var panel: NSPanel!
	var dataRead = ""
	var lastMenu: NSMenu?
	var syntaxDescription = Options()

	override init() {
		app.mainMenu = mainMenu
		
		super.init()

		panel = NSPanel(contentRect: NSRect(x: 100, y: 100, width: 512, height: 342), styleMask: [.titled], backing: .buffered, defer: true)
		contentView = panel.contentView
		contentView.setContentHuggingPriority(NSLayoutConstraint.Priority(750.0), for: .vertical)
		contentView.setContentCompressionResistancePriority(NSLayoutConstraint.Priority(750.0), for: .horizontal)
		contentView.setContentCompressionResistancePriority(NSLayoutConstraint.Priority(750.0), for: .vertical)

		if let jsonPath = UserDefaults.standard.string(forKey: "description") {
			let dataURL = URL(fileURLWithPath: jsonPath)
			let decoder = JSONDecoder()
			syntaxDescription = try! decoder.decode(Options.self, from: Data(contentsOf: dataURL))
			
			syntaxDescription.options.forEach { $0.create(in: self) }
			
			let okButton = addButton("OK")
			okButton.target = NSApplication.shared
			okButton.action = #selector(NSApplication.terminate(_:))
			okButton.keyEquivalent = "\r"

			let cancelButton = addButton("Cancel")
			okButton.target = NSApplication.shared
			okButton.action = #selector(NSApplication.terminate(_:))
			cancelButton.keyEquivalent = "\u{1B}"
		} else {
			FileHandle.standardInput.readabilityHandler = { fh in
				let data = fh.readDataToEndOfFile()
				if data.count > 0, let str = String(data: data, encoding: .utf8) {
					DispatchQueue.main.async {
						self.dataRead.append(str)
						while let lineEnd = self.dataRead.firstIndex(of: "\n") {
							let newLine = self.dataRead[..<lineEnd]
							self.dataRead.removeSubrange(...lineEnd)
							self.processOneLine(String(newLine))
						}
					}
				}
			}
		}

		let appMenu = addMenu("")
		_ = appMenu.addItem(withTitle: "About Commando", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
		_ = appMenu.addItem(NSMenuItem.separator())
		_ = appMenu.addItem(withTitle: "Preferences…", action: nil, keyEquivalent: "")
		_ = appMenu.addItem(NSMenuItem.separator())
		let servicesMenuItem = appMenu.addItem(withTitle: "Services", action: nil, keyEquivalent: "")
		let servicesMenu = NSMenu(title: "Services")
		NSApplication.shared.servicesMenu = servicesMenu
		servicesMenuItem.submenu = servicesMenu
		_ = appMenu.addItem(NSMenuItem.separator())
		_ = appMenu.addItem(withTitle: "Hide Commando", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
		let hideOthersItem = appMenu.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
		hideOthersItem.keyEquivalentModifierMask = [.command, .option]
		_ = appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
		_ = appMenu.addItem(NSMenuItem.separator())
		_ = appMenu.addItem(withTitle: "Quit Commando", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
		
		let fileMenu = addMenu("File")
		_ = fileMenu.addItem(withTitle: "New", action: nil, keyEquivalent: "n")
		_ = fileMenu.addItem(NSMenuItem.separator())
		_ = fileMenu.addItem(withTitle: "Open…", action: nil, keyEquivalent: "o")
		let recentsMenuItem = fileMenu.addItem(withTitle: "Open Recent", action: nil, keyEquivalent: "")
		let recentsMenu = NSMenu(title: "Open Recent")
		_ = recentsMenu.addItem(withTitle: "Clear Menu", action: #selector(NSDocumentController.clearRecentDocuments(_:)), keyEquivalent: "o")
		recentsMenuItem.submenu = recentsMenu
		_ = fileMenu.addItem(NSMenuItem.separator())
		_ = fileMenu.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")

		let editMenu = addMenu("Edit")
		_ = editMenu.addItem(withTitle: "Undo", action: NSSelectorFromString("undo:"), keyEquivalent: "z")
		_ = editMenu.addItem(withTitle: "Redo", action: NSSelectorFromString("redo:"), keyEquivalent: "Z")
		_ = editMenu.addItem(NSMenuItem.separator())
		_ = editMenu.addItem(withTitle: "Cut", action: NSSelectorFromString("cut:"), keyEquivalent: "x")
		_ = editMenu.addItem(withTitle: "Copy", action: NSSelectorFromString("copy:"), keyEquivalent: "c")
		_ = editMenu.addItem(withTitle: "Paste", action: NSSelectorFromString("paste:"), keyEquivalent: "v")
		_ = editMenu.addItem(withTitle: "Clear", action: NSSelectorFromString("delete:"), keyEquivalent: "")
		_ = editMenu.addItem(NSMenuItem.separator())
		_ = editMenu.addItem(withTitle: "Select All", action: NSSelectorFromString("selectAll:"), keyEquivalent: "a")

		var myPSN = ProcessSerialNumber(highLongOfPSN: 0, lowLongOfPSN: UInt32(kCurrentProcess))
		TransformProcessType(&myPSN, ProcessApplicationTransformState(kProcessTransformToForegroundApplication))
	}
	
	func processOneLine(_ cmd: String) {
		let parts = cmd.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
		switch parts.first {
			case "menu":
				lastMenu = addMenu(String(parts[1]))
			case "item":
				if let lastMenu = lastMenu {
					lastMenu.addItem(withTitle: String(parts[1]), action: nil, keyEquivalent: "")
				}
			case "field":
				_ = addTextField(String(parts[1]), value: "")
			case "filepicker":
				_ = addPathField(String(parts[1]), value: "")
			case "button":
				_ = addButton(String(parts[1]))
			case "defaultbutton", "okbutton":
				let okButton = addButton(String(parts[1]))
				okButton.keyEquivalent = "\r"
			case "cancelbutton":
				let cancelButton = addButton(String(parts[1]))
				cancelButton.keyEquivalent = "\u{1B}"
			case "checkbox":
				_ = addCheckBox(String(parts[1]))
			default:
				print("Unknown command \(String(describing: parts.first))")
		}
	}
	
	func applicationDidFinishLaunching(_ notification: Notification) {
		panel.layoutIfNeeded()
		panel.center()
		panel.makeKeyAndOrderFront(self)
		
		NSApplication.shared.activate(ignoringOtherApps: true)
	}
	
	func addMenu(_ title: String) -> NSMenu {
		let owningItem = mainMenu.addItem(withTitle: title, action: nil, keyEquivalent: "")
		let actualMenu = NSMenu(title: title)
		owningItem.submenu = actualMenu
		
		return actualMenu
	}
	
	func addTextField(_ label: String, value: String = "") -> NSTextField {
		let label1 = NSTextField(labelWithString: label)
		label1.alignment = .right
		let editField1 = NSTextField(string: value)
		contentView.pin(label: label1, value: editField1, prevValue: &prevValue, insets: prevValue == nil ? pinToTop : pinToPrevious)
		return editField1
	}
	
	func addPathField(_ label: String, value: String = "") -> NSTextField {
		let label1 = NSTextField(labelWithString: label)
		label1.alignment = .right
		let editField1 = NSTextField(string: value)
		var insets = prevValue == nil ? pinToTop : pinToPrevious
		insets.right = dontPin
		contentView.pin(label: label1, value: editField1, prevValue: &prevValue, insets: insets)
		let chooseButton = NSButton(title: "Choose…", target: nil, action: nil)
		chooseButton.translatesAutoresizingMaskIntoConstraints = false
		contentView.addSubview(chooseButton)
		chooseButton.leadingAnchor.constraint(equalTo: editField1.trailingAnchor, constant: 8.0).isActive = true
		chooseButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20.0).isActive = true
		chooseButton.firstBaselineAnchor.constraint(equalTo: editField1.firstBaselineAnchor).isActive = true
		return editField1
	}
	
	func addCheckBox(_ label: String) -> NSButton {
		let label3 = NSView()
		let checkBox3 = NSButton(checkboxWithTitle: label, target: nil, action: nil)
		checkBox3.setContentHuggingPriority(NSLayoutConstraint.Priority(800), for: .vertical)
		contentView.pin(label: label3, value: checkBox3, prevValue: &prevValue, insets: prevValue == nil ? pinToTop : pinToPrevious)
		return checkBox3
	}
	
	func addButton(_ title: String) -> NSButton {
		let okButton = NSButton(title: title, target: nil, action: nil)
		contentView.pin(button: okButton, prevButton: &prevValue)
		return okButton
	}
}

var app = NSApplication.shared
var appDelegate = AppDelegate()
app.delegate = appDelegate

app.run()
