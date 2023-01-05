//
//  DeviceFinderInterfaceController.swift
//  Roku Remote WatchKit Extension
//
//  Created by Josh Birnholz on 10/10/18.
//  Copyright © 2018 Josh Birnholz. All rights reserved.
//

import WatchKit
import RokuKit_Watch
import WatchConnectivity

struct Global {
	@Stored(key: "previousRokuSerial") static var previousRokuSerial: String?
}

let enabledDevicesURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("enabledDevices.plist")

class DeviceRowController: NSObject {
	
	@IBOutlet var label: WKInterfaceLabel!
	@IBOutlet var modelLabel: WKInterfaceLabel!
	@IBOutlet var networkLabel: WKInterfaceLabel!
}

class DeviceFinderInterfaceController: WKInterfaceController {

	var networkInfo: Set<NetworkInfo?> = []
	
	var devices: [RokuDevice] = [] {
		didSet {
			networkInfo = Set(devices.map { $0.connectedNetworkInfo })
		}
	}
	
	@IBOutlet var devicesTable: WKInterfaceTable!
	@IBOutlet var searchingLabel: WKInterfaceLabel!
	@IBOutlet var noDevicesLabel: WKInterfaceLabel!
	@IBOutlet var spinnerGroup: WKInterfaceGroup!
	@IBOutlet var searchAgainButton: WKInterfaceButton!
	
	var isSearching: Bool = false {
		didSet {
			spinnerGroup.setHidden(!isSearching)
			
			if isSearching {
				spinnerGroup.startAnimating()
				self.searchAgainButton.setHidden(false)
			} else {
				spinnerGroup.stopAnimating()
				self.searchAgainButton.setHidden(!self.devices.isEmpty)
			}
			self.noDevicesLabel.setHidden(!self.devices.isEmpty)
		}
	}
	
	override func awake(withContext context: Any?) {
		super.awake(withContext: context)
		
		NotificationCenter.default.addObserver(forName: .WCSessionActivationDidComplete, object: nil, queue: nil) { [weak self] _ in
			self?.searchForDevices()
		}
		
		NotificationCenter.default.addObserver(forName: .WCSessionDidReceiveMessage, object: nil, queue: nil) { [weak self] notification in
			guard let message = notification.userInfo as? [String: Any] else { return }
			if let command = message["command"] as? String, command == "refresh" || command == "foundDevice" {
				self?.handle(message: message)
			}
		}
		
		(WKExtension.shared().delegate as? ExtensionDelegate)?.rootInterfaceController = self
		
		loadEnabledDevices(autoload: true)
	}
	
	private var autosearchedOnce = false
	
	override func didAppear() {
		
		if WCSession.default.activationState == .activated && !autosearchedOnce {
			searchForDevices()
		} else {
			WCSession.default.activate()
		}
		autosearchedOnce = true
		
	}
	
	static let deviceRowType = "DeviceRow"
	
	func configureTable(resettingRowCount: Bool = true) {
		
		self.devicesTable.setNumberOfRows(devices.count, withRowType: DeviceFinderInterfaceController.deviceRowType)
		
		for i in 0 ..< devices.count {
			configureRow(at: i)
		}
	}
	
	func refreshDevices() {
		guard WCSession.default.activationState == .activated else { WCSession.default.activate(); return }
		
		WCSession.default.sendMessage(["command": "devices"], replyHandler: { (reply) in
			self.handle(message: reply)
		}) { (error) in
			print("Error refreshing devices")
		}
		
	}
	
	@IBAction func searchForDevices() {
		guard !isSearching else { return }
		
		guard WCSession.default.activationState == .activated else { WCSession.default.activate(); return }
		
		WCSession.default.sendMessage(["command": "search"], replyHandler: nil) { (error) in
			
			print("Error refreshing devices")
			self.isSearching = false
		}
		
		self.isSearching = true
		
		DispatchQueue.main.asyncAfter(deadline: .now() + 25) {
			self.isSearching = false
		}
	}
	
	static let decoder = PropertyListDecoder()
	static let encoder = PropertyListEncoder()
	
	func handle(message: [String: Any]) {
		if let data = message["devices"] as? Data, let devices = try? DeviceFinderInterfaceController.decoder.decode([RokuDevice].self, from: data) {
			print("Received devices from phone")
			
			if devices != self.devices {
				print("Devices were new")
				self.devices = devices
				
				DispatchQueue.main.async {
					self.configureTable()
				}
				
				do {
					try? FileManager.default.removeItem(at: enabledDevicesURL)
					try data.write(to: enabledDevicesURL)
				} catch {
					print("Error writing new devices", error)
				}
			}
			
		} else if let data = message["device"] as? Data, let device = try? DeviceFinderInterfaceController.decoder.decode(RokuDevice.self, from: data) {
			if let index = devices.firstIndex(of: device) {
//				self.devices[index] = device
				self.devices[index].update(withPropertiesOf: device)
				self.configureTable(resettingRowCount: false)
			} else {
				if #available(watchOSApplicationExtension 6, *) {
					let snapshot = self.devices
					self.devices.append(device)
					let difference = self.devices.difference(from: snapshot)
					for change in difference {
						switch change {
						case .insert(let offset, let element, let associatedWith):
							self.devicesTable.insertRows(at: IndexSet(integer: offset), withRowType: DeviceFinderInterfaceController.deviceRowType)
							self.configureRow(at: offset)
						case .remove(let offset, let element, let associatedWith):
							self.devicesTable.removeRows(at: IndexSet(integer: offset))
						}
					}
				} else {
					self.devices.append(device)
					self.configureTable(resettingRowCount: true)
				}
			}
			
			self.searchAgainButton.setHidden(!self.devices.isEmpty)
			self.noDevicesLabel.setHidden(!self.devices.isEmpty)
			
			do {
				let data = try DeviceFinderInterfaceController.encoder.encode(self.devices)
				try? FileManager.default.removeItem(at: enabledDevicesURL)
				try data.write(to: enabledDevicesURL)
			} catch {
				print("Error writing new devices", error)
			}
		}
		
		else if let error = message["error"] as? String {
			print("Received error from iPhone while refreshing devices:", error)
		}
	}
	
	@objc func loadEnabledDevices(autoload: Bool = false) {
		do {
			let data = try Data(contentsOf: enabledDevicesURL)
			
			let decoder = PropertyListDecoder()
			
			self.devices = try decoder.decode([RokuDevice].self, from: data)
			
			if let device = devices.first(where: { $0.serialNumber == Global.previousRokuSerial }), autoload {
				pushController(withName: "MainRemote", context: device)
			} else if devices.count == 1 {
				pushController(withName: "MainRemote", context: devices.first)
			}
			
			configureTable()
			
		} catch {
			print("Error loading locally saved devices", error)
		}
		
	}
	
	func configureRow(at rowIndex: Int) {
		guard let row = devicesTable.rowController(at: rowIndex) as? DeviceRowController else { return }
		
		let device = devices[rowIndex]
		
		row.label.setText(device.friendlyDeviceName)
		row.modelLabel.setText(device.friendlyModelName)
		
		row.networkLabel.setHidden(networkInfo.count < 2)
		row.networkLabel.setText(device.connectedNetworkInfo?.ssid)
	}
	
	override func contextForSegue(withIdentifier segueIdentifier: String, in table: WKInterfaceTable, rowIndex: Int) -> Any? {
		return devices[rowIndex]
	}
	
}
