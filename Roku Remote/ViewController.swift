//
//  ViewController.swift
//  Roku Remote
//
//  Created by Josh Birnholz on 10/10/18.
//  Copyright © 2018 Josh Birnholz. All rights reserved.
//

import UIKit
import RokuKit
import CocoaAsyncSocket
import WatchConnectivity
import SystemConfiguration.CaptiveNetwork
import MessageUI

let enabledDevicesURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("enabledDevices.plist")

class ViewController: UITableViewController {

	@IBOutlet var activityIndicator: UIActivityIndicatorView!
	@IBOutlet weak var retryButton: UIBarButtonItem!
	
	var foundDeviceSerialNumbers: Set<String> = []
	
	let encoder = PropertyListEncoder()
	
	var enabledDevices: [RokuDevice] = [] {
		didSet {
			guard oldValue != enabledDevices else { return }
			do {
				let data = try encoder.encode(enabledDevices)
				try data.write(to: enabledDevicesURL)
				print("Wrote enabled devices to local file successfully")
				
				if WCSession.default.activationState == .activated {
					WCSession.default.sendMessage(["command": "refresh", "data": data], replyHandler: nil, errorHandler: nil)
				}
				
			} catch {
				print("Error saving enabled devices to local file:", error)
			}
		}
	}
	
	var discoveredDevices: [RokuDevice] = []
	
	var ssdpSocket: GCDAsyncUdpSocket? {
		didSet {
			oldValue?.close()
		}
	}
	
    override func viewDidLoad() {
        super.viewDidLoad()
		
		navigationItem.rightBarButtonItems = [retryButton, UIBarButtonItem(customView: activityIndicator)]
		
		do {
			self.enabledDevices = try loadEnabledDevices()
		} catch {
			print("Error loading previously enabled devices", error)
		}
		
		beginSearching()
		
		print("Current Network:", currentNetwork ?? "nil")
		
		tableView.isEditing = true

    }
	
	func loadEnabledDevices() throws -> [RokuDevice] {
		
		let data = try Data(contentsOf: enabledDevicesURL)
		
		let decoder = PropertyListDecoder()
		
		return try decoder.decode([RokuDevice].self, from: data)
	}
	
	@IBAction func addButtonPressed(_ sender: Any) {
		
		let alert = UIAlertController(title: "Add Manually", message: "Enter the IP address of your Roku device.", preferredStyle: .alert)
		
		alert.addTextField { (tf) in
			tf.placeholder = "192.168.1.134"
			tf.keyboardType = .decimalPad
		}
		
		let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
		
		let addAction = UIAlertAction(title: "Add", style: .default) { _ in
			func showError(_ message: String? = nil, data: Data? = nil) {
				let errorAlert = UIAlertController(title: "Unable to Add Device", message: message, preferredStyle: .alert)
				let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
				errorAlert.addAction(okAction)
				
				if let data = data, MFMailComposeViewController.canSendMail() {
					let reportAction = UIAlertAction(title: "Send Error Log", style: .default) { _ in
						let composer = MFMailComposeViewController()
						composer.mailComposeDelegate = self
						
						composer.setToRecipients(["josh@birnholz.com"])
						composer.setSubject("Remoku Device Add Error Log")
						composer.addAttachmentData(data, mimeType: "text/xml", fileName: "device-info.xml")
						
						self.present(composer, animated: true, completion: nil)
					}
					
					errorAlert.addAction(reportAction)
				}
				
				self.present(errorAlert, animated: true, completion: nil)
			}
			
			guard let input = alert.textFields?.first?.text, let url = URL(string: "http://\(input):8060/") else { showError("Invalid IP address"); return }
			
			RokuDevice.create(from: url) { device, data in
				guard device != nil else {
					DispatchQueue.main.async {
						showError("A Roku device could not be reached at “\(input)”.", data: data)
					}
					return
				}
				
				self.foundRoku(with: url)
			}
			
		}
		
		alert.addAction(cancelAction)
		alert.addAction(addAction)
		
		self.present(alert, animated: true, completion: nil)
		
	}
	
	@IBAction func beginSearching() {
		print(#function)
		
		retryButton.isEnabled = false
		activityIndicator.isHidden = false
		activityIndicator.startAnimating()
		
		let ssdpAddress = "239.255.255.250"
		let ssdpPort: UInt16 = 1900
		
		ssdpSocket = GCDAsyncUdpSocket(delegate: self, delegateQueue: .main)
		
		let mSearchData = """
		M-SEARCH * HTTP/1.1
		Host: 239.255.255.250:1900
		Man: "ssdp:discover"
		ST: roku:ecp
		
		""".data(using: .utf8)!
		
		//send M-Search
		
		//bind for responses
		do {
			try ssdpSocket!.enableReusePort(true)
			try ssdpSocket!.bind(toPort: ssdpPort)
			ssdpSocket!.send(mSearchData, toHost: ssdpAddress, port: ssdpPort, withTimeout: 1, tag: 0)
			try ssdpSocket!.joinMulticastGroup(ssdpAddress)
			try ssdpSocket!.beginReceiving()
			
			let timeout: TimeInterval = 60
			DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
				if self.discoveredDevices.isEmpty {
					self.finishSearching()
				}
			}
			
		} catch {
			print(error)
			finishSearching()
		}
	}
	
	func finishSearching() {
		ssdpSocket?.closeAfterSending()
		ssdpSocket = nil
		
		retryButton.isEnabled = true
		activityIndicator.stopAnimating()
		
		if foundDeviceSerialNumbers.isEmpty && !enabledDevices.isEmpty {
			let okAction = UIAlertAction(title: "OK", style: .cancel, handler: nil)
			let retryAction = UIAlertAction(title: "Retry", style: .default) { _ in
				self.beginSearching()
			}
			
			let alert = UIAlertController(title: "Couldn't Find Any Roku Devices", message: "Ensure your Roku device and your iPhone are connected to the same Wi-Fi network.", preferredStyle: .alert)
			
			alert.addAction(okAction)
			alert.addAction(retryAction)
			
			DispatchQueue.main.async {
				self.present(alert, animated: true, completion: nil)
			}
		}
		
	}
	
	func foundRoku(with url: URL) {
		print(#function)
		RokuDevice.create(from: url) { device, _ in
			guard let device = device else { return }
			self.foundDeviceSerialNumbers.insert(device.serialNumber)
			device.connectedNetworkInfo = self.currentNetwork
			DispatchQueue.main.async {
				if let updateEnabledIndex = self.enabledDevices.firstIndex(of: device) {
					// Found device that was already enabled. Update it in the enabled list.
					
					self.enabledDevices[updateEnabledIndex] = device
					self.tableView.reloadRows(at: [IndexPath(row: updateEnabledIndex, section: 0)], with: .fade)
				} else if let updateIndex = self.discoveredDevices.firstIndex(of: device) {
					// Device with same serial number was already in list, may have changed IPs or something. Update it
					self.discoveredDevices[updateIndex] = device
					self.tableView.reloadRows(at: [IndexPath(row: updateIndex, section: 1)], with: .fade)
				} else if let removalIndex = self.discoveredDevices.firstIndex(where: { $0.currentLocation == url }) {
					// There was somehow already another device with the same location. Remove the old one and add the new one
					self.discoveredDevices.remove(at: removalIndex)
					self.tableView.deleteRows(at: [IndexPath(row: removalIndex, section: 1)], with: .automatic)
					
					let newIndex = self.discoveredDevices.count
					self.discoveredDevices.append(device)
					self.tableView.insertRows(at: [IndexPath(row: newIndex, section: 1)], with: .automatic)
				} else {
					// Found new device. Add it
					let newIndex = self.discoveredDevices.count
					self.discoveredDevices.append(device)
					self.tableView.insertRows(at: [IndexPath(row: newIndex, section: 1)], with: .automatic)
				}
			}
		}
	}
	
	var currentNetwork: NetworkInfo? {
		var currentSSID: String? = nil
		var currentBSSID: String? = nil
		if let interfaces = CNCopySupportedInterfaces() {
			for i in 0 ..< CFArrayGetCount(interfaces) {
				let interfaceName: UnsafeRawPointer = CFArrayGetValueAtIndex(interfaces, i)
				let rec = unsafeBitCast(interfaceName, to: AnyObject.self)
				let unsafeInterfaceData = CNCopyCurrentNetworkInfo("\(rec)" as CFString)
				if let interfaceData = unsafeInterfaceData as? [String: Any] {
					currentSSID = interfaceData["SSID"] as? String
					currentBSSID = interfaceData["BSSID"] as? String
				}
			}
		}
		if let ssid = currentSSID, let bssid = currentBSSID {
			return NetworkInfo(ssid: ssid, bssid: bssid)
		} else {
			return nil
		}
	}
	
	// MARK: UITableViewDataSource
	
	override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
		switch indexPath.section {
		case 0:
			return .delete
		case 1:
			return .insert
		default:
			return .none
		}
	}
	
	override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
		
		switch indexPath.section {
		case 0:
			// Disabling device
			
			let device = enabledDevices[indexPath.row]
			
			let alert = UIAlertController(title: "Remove Device", message: "Are you sure you want to remove “\(device.friendlyDeviceName)” from your Apple Watch?", preferredStyle: .alert)
			
			let removeAction = UIAlertAction(title: "Remove", style: .destructive) { _ in
				self.enabledDevices.remove(at: indexPath.row)
				
				if self.foundDeviceSerialNumbers.contains(device.serialNumber) {
					// Put back in discovered section
					self.discoveredDevices.append(device)
					
					let newIndexPath = IndexPath(row: self.discoveredDevices.count-1, section: 1)
					tableView.moveRow(at: indexPath, to: newIndexPath)
				} else {
					// Remove completely
					tableView.deleteRows(at: [indexPath], with: .automatic)
				}
			}
			
			let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
			
			alert.addAction(removeAction)
			alert.addAction(cancelAction)
			
			self.present(alert, animated: true, completion: nil)
			
		case 1:
			// Enabling discovered device
			
			let device = discoveredDevices.remove(at: indexPath.row)
			enabledDevices.append(device)
			
			let newIndexPath = IndexPath(row: enabledDevices.count-1, section: 0)
			
			tableView.moveRow(at: indexPath, to: newIndexPath)
			
		default:
			break
		}
		
	}
	
	override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
		return indexPath.section == 0
	}
	
	override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
		
		let device = enabledDevices.remove(at: sourceIndexPath.row)
		enabledDevices.insert(device, at: destinationIndexPath.row)
		
	}
	
	override func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath, toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {
		if proposedDestinationIndexPath.section == 1 {
			return IndexPath(row: enabledDevices.count-1, section: 0)
		} else {
			return proposedDestinationIndexPath
		}
	}
	
	override func numberOfSections(in tableView: UITableView) -> Int {
		return 2
	}
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		switch section {
		case 0:
			return enabledDevices.count
		case 1:
			return discoveredDevices.count
		default:
			return 0
		}
	}
	
	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		switch section {
		case 0:
			return "On Your Watch"
		case 1:
			return "Discovered Devices"
		default:
			return nil
		}
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		
		let cell = tableView.dequeueReusableCell(withIdentifier: "DeviceCell", for: indexPath)
		
		let device: RokuDevice
		
		switch indexPath.section {
		case 0:
			device = enabledDevices[indexPath.row]
			cell.selectionStyle = .none
		case 1:
			device = discoveredDevices[indexPath.row]
			cell.selectionStyle = .default
		default:
			return cell
		}
		
		cell.textLabel?.text = device.friendlyDeviceName
		cell.detailTextLabel?.text = device.friendlyModelName
		
		return cell
		
	}
	
}

extension ViewController: GCDAsyncUdpSocketDelegate {
	
	func udpSocket(_ sock: GCDAsyncUdpSocket, didConnectToAddress address: Data) {
		print("Did connect to address")
		print(address)
	}
	
	func udpSocket(_ sock: GCDAsyncUdpSocket, didReceive data: Data, fromAddress address: Data, withFilterContext filterContext: Any?) {
		print("Did receive data")
		if let str = String(data: data, encoding: .utf8), str.contains("HTTP/1.1 200 OK") {
			let locationString = str.split(separator: "\r\n").first(where: { $0.hasPrefix("LOCATION: ") })?.replacingOccurrences(of: "location: ", with: "", options: [.caseInsensitive])
			if let locationString = locationString, let url = URL(string: locationString) {
				self.foundRoku(with: url)
			}
			
			DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
				self.finishSearching()
			}
		}
	}
	
}

extension ViewController: MFMailComposeViewControllerDelegate {
	func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
		dismiss(animated: true, completion: nil)
	}
}
