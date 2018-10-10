//
//  AppChooserInterfaceController.swift
//  Roku Remote WatchKit Extension
//
//  Created by Josh Birnholz on 10/9/18.
//  Copyright © 2018 Josh Birnholz. All rights reserved.
//

import WatchKit
import RokuKit_Watch

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
	
	@IBAction func button0Pressed() {
		guard let id = apps[safe: 0]?.id else { return }
		presenter?.device?.launchApp(id: id)
		presenter?.pop()
	}
	@IBAction func button1Pressed() {
		guard let id = apps[safe: 1]?.id else { return }
		presenter?.device?.launchApp(id: id)
		presenter?.pop()
	}
	
}

class AppChooserInterfaceController: WKInterfaceController {
	
	enum ViewStyle: String {
		
		case list
		case grid
		
		static var saved: ViewStyle {
			get {
				return UserDefaults.standard.string(forKey: #function).flatMap(ViewStyle.init) ?? .grid
			}
			set {
				UserDefaults.standard.set(newValue.rawValue, forKey: #function)
			}
		}
		
	}
	
	var device: RokuDevice?
	var filteredApps: [RokuDevice.App] = []
	
	@IBOutlet var appsTable: WKInterfaceTable!
	
	override func awake(withContext context: Any?) {
		device = context as? RokuDevice
		filteredApps = device?.apps.filter { $0.type != "menu" } ?? []
		
		switch ViewStyle.saved {
		case .grid: configureCompactTable()
		case .list: configureListTable()
		}
		
	}
	
	@IBAction func changeViewButtonPressed() {
		switch ViewStyle.saved {
		case .grid:
			ViewStyle.saved = .list
			configureListTable()
		case .list:
			ViewStyle.saved = .grid
			configureCompactTable()
		}
	}
	
	func configureListTable() {
		guard let device = device else { return }
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
		let appChunks = filteredApps.chunked(by: 2)
		
		appsTable.setNumberOfRows(appChunks.count, withRowType: "CompactRowController")
		
		for (index, chunk) in appChunks.enumerated() {
			let row = appsTable.rowController(at: index) as! CompactRowController
			
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
				row.label0.setHidden(false)
			}
			
			if let app = chunk[safe:1], app.type == "tvin" {
				row.label1.setText(app.name)
				row.label1.setHidden(false)
			}
		}
	}
	
	override func table(_ table: WKInterfaceTable, didSelectRowAt rowIndex: Int) {
		guard let device = device, let id = filteredApps[rowIndex].id else { return }
		
		device.launchApp(id: id)
		pop()
		
	}
	
}
