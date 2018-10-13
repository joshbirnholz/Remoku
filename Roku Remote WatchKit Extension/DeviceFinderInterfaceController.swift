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

var previousRokuSerial: String? {
	get {
		return UserDefaults.standard.string(forKey: #function)
	}
	set {
		UserDefaults.standard.set(newValue, forKey: #function)
	}
}

let enabledDevicesURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("enabledDevices.plist")

class DeviceRowController: NSObject {
	
	@IBOutlet var label: WKInterfaceLabel!
	@IBOutlet var modelLabel: WKInterfaceLabel!
}


class DeviceFinderInterfaceController: WKInterfaceController {

	var devices: [RokuDevice] = []
	
	@IBOutlet var devicesTable: WKInterfaceTable!
	
	override func awake(withContext context: Any?) {
		super.awake(withContext: context)
		
		loadEnabledDevices(autoload: true)
	}
	
	override func didAppear() {
		super.didAppear()
		
		WCSession.default.delegate = self
		
		if WCSession.default.activationState == .inactive {
			WCSession.default.activate()
		} else if WCSession.default.activationState == .activated {
			refreshDevices()
		}
		
	}
	
	func configureTable() {
		
		self.devicesTable.setNumberOfRows(devices.count, withRowType: "DeviceRow")
		
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
	
	func handle(message: [String: Any]) {
		if let data = message["data"] as? Data, let devices = try? PropertyListDecoder().decode([RokuDevice].self, from: data) {
			print("Received devices from phone")
			
			if devices != self.devices {
				print("Devices were new")
				self.devices = devices
				
				DispatchQueue.main.async {
					self.configureTable()
				}
				
				do {
					try FileManager.default.removeItem(at: enabledDevicesURL)
					try data.write(to: enabledDevicesURL)
				} catch {
					print("Error writing new devices")
				}
			}
			
		} else if let error = message["error"] as? String {
			print("Received error from iPhone while refreshing devices:", error)
		}
	}
	
	@objc func loadEnabledDevices(autoload: Bool = false) {
		do {
			let data = try Data(contentsOf: enabledDevicesURL)
			
			let decoder = PropertyListDecoder()
			
			self.devices = try decoder.decode([RokuDevice].self, from: data)
			
			if let device = devices.first(where: { $0.serialNumber == previousRokuSerial }), autoload {
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
	}
	
	override func contextForSegue(withIdentifier segueIdentifier: String, in table: WKInterfaceTable, rowIndex: Int) -> Any? {
		return devices[rowIndex]
	}
	
}

extension DeviceFinderInterfaceController: WCSessionDelegate {
	func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
		print(#function)
		refreshDevices()
	}
	
	func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
		if message["command"] as? String == "refresh" {
			handle(message: message)
		}
	}
}
