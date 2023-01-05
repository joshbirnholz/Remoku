//
//  AppChooserInterfaceController.swift
//  Roku Remote WatchKit Extension
//
//  Created by Josh Birnholz on 10/9/18.
//  Copyright © 2018 Josh Birnholz. All rights reserved.
//

import WatchKit
import RokuKit_Watch
import Intents

class RowController: NSObject {
	
	@IBOutlet var image: WKInterfaceImage!
	@IBOutlet var label: WKInterfaceLabel!
	
}

class CompactRowController: NSObject {
	
	var apps: [RokuDevice.App] = []
	
	weak var presenter: AppChooserInterfaceController?
	
	@IBOutlet var group0: WKInterfaceGroup!
	@IBOutlet var group1: WKInterfaceGroup!
	
	@IBOutlet var label0: WKInterfaceLabel!
	@IBOutlet var label1: WKInterfaceLabel!
	
	@IBOutlet var label0Group: WKInterfaceGroup!
	@IBOutlet var label1Group: WKInterfaceGroup!
	
	@IBAction func button0Pressed() {
		guard let app = apps[safe: 0] else { return }
		presenter?.launch(app)
	}
	@IBAction func button1Pressed() {
		guard let app = apps[safe: 1] else { return }
		presenter?.launch(app)
	}
	
}

class AppChooserInterfaceController: WKInterfaceController {
	
	enum ViewStyle: String {
		
		case list
		case grid
		
		@Stored(key: "AppChooserViewStyle") static var savedValue: String?
		
		static var saved: ViewStyle {
			get {
				return ViewStyle.savedValue.flatMap(ViewStyle.init) ?? .grid
			}
			set {
				savedValue = newValue.rawValue
			}
		}
		
	}
	
	var device: RokuDevice?
	var filteredApps: [RokuDevice.App] = []
	
	@IBOutlet var appsTable: WKInterfaceTable!
	
	override func awake(withContext context: Any?) {
		device = context as? RokuDevice
		
		if #available(watchOSApplicationExtension 5.1, *) {
			appsTable.curvesAtBottom = true
			appsTable.curvesAtTop = true
		}
		
		switch ViewStyle.saved {
		case .grid: configureCompactTable()
		case .list: configureListTable()
		}
		
//		device?.getActiveApp { [weak self] app in
//			guard let self = self, let app = app, let index = self.filteredApps.firstIndex(of: app) else { return }
//
//			if let row = self.appsTable.rowController(at: index) as? RowController {
//				self.scroll(to: row.label, at: .centeredVertically, animated: true)
//			} else if let row = self.appsTable.rowController(at: index/2) as? CompactRowController {
//				self.scroll(to: row.group0, at: .centeredVertically, animated: true)
//			}
//
//		}
		
	}
	
	@IBAction func gridViewButtonPressed() {
		if ViewStyle.saved != .grid {
			ViewStyle.saved = .grid
			configureCompactTable()
		}
	}
	
	@IBAction func listViewButtonPressed() {
		if ViewStyle.saved != .list {
			ViewStyle.saved = .list
			configureListTable()
		}
	}
	
	override func contextForSegue(withIdentifier segueIdentifier: String) -> Any? {
		return device
	}
	
	func configureListTable() {
		guard let device = device else { return }
		filteredApps = device.apps.filter { $0.type != "menu" }.sorted { $0.name < $1.name }
		appsTable.setNumberOfRows(filteredApps.count, withRowType: "RowController")

		for (index, app) in filteredApps.enumerated() {

			guard let row = appsTable.rowController(at: index) as? RowController else { continue }

			row.label.setText(app.name)

			if let id = app.id {
				device.loadIcon(appID: id) { image in
					DispatchQueue.main.async {
						row.image.setImage(image)
					}
				}
			}

		}
	}
	
	func configureCompactTable() {
		guard let device = device else { return }
		filteredApps = device.apps.filter { $0.type != "menu" }
		
		let appChunks = filteredApps.chunked(by: 2)
		
		appsTable.setNumberOfRows(appChunks.count, withRowType: "CompactRowController")
		
		for (index, chunk) in appChunks.enumerated() {
			guard let row = appsTable.rowController(at: index) as? CompactRowController else { return }
			
			row.apps = chunk
			row.presenter = self
			
			if let id = chunk[safe: 0]?.id {
				device.loadIcon(appID: id) { (image) in
					DispatchQueue.main.async {
						row.group0.setBackgroundImage(image)
					}
				}
			}
			
			if let id = chunk[safe: 1]?.id {
				device.loadIcon(appID: id) { (image) in
					DispatchQueue.main.async {
						row.group1.setBackgroundImage(image)
					}
				}
			}
			
			if let app = chunk[safe:0], app.type == "tvin" {
				row.label0.setText(app.name)
				row.label0Group.setHidden(false)
				row.group0.setBackgroundColor(#colorLiteral(red: 0.07135196775, green: 0.07099718601, blue: 0.07163082808, alpha: 1))
			}
			
			if let app = chunk[safe:1], app.type == "tvin" {
				row.label1.setText(app.name)
				row.label1Group.setHidden(false)
				row.group1.setBackgroundColor(#colorLiteral(red: 0.07135196775, green: 0.07099718601, blue: 0.07163082808, alpha: 1))
			}
		}
	}
	
	override func table(_ table: WKInterfaceTable, didSelectRowAt rowIndex: Int) {
		guard let app = filteredApps[safe: rowIndex] else { return }
		
		launch(app)
	}
	
	func launch(_ app: RokuDevice.App) {
		guard let id = app.id else { return }
		device?.launchApp(id: id)
		dismiss()
		
		
		// Donate an interaction of launching the app.
		if #available(watchOSApplicationExtension 5.0, *) {
			let roku: Roku? = {
				guard let device = device else { return nil }
				let roku = Roku(identifier: device.serialNumber, display: device.friendlyDeviceName)
				if #available(watchOSApplicationExtension 6.0, *) {
					roku.currentLocation = device.currentLocation
				}
				return roku
			}()
			
			
			let intent = LaunchAppIntent()
			intent.device = roku
			
			if let appIconURL = device?.currentLocation.appendingPathComponent("query").appendingPathComponent("icon").appendingPathComponent(id) {
				let image = INImage(url: appIconURL)
				intent.setImage(image, forParameterNamed: \.app)
			}
			
			let interaction = INInteraction(intent: intent, response: nil)
			
			interaction.donate(completion: nil)
		}
		
		
	}
	
}
