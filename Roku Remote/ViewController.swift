////
////  ViewController.swift
////  Roku Remote
////
////  Created by Josh Birnholz on 10/10/18.
////  Copyright © 2018 Josh Birnholz. All rights reserved.
////
//
//import UIKit
//import RokuKit
//import WatchConnectivity
//import MessageUI
//
//class ViewController: UITableViewController {
//
//	@IBOutlet var activityIndicator: UIActivityIndicatorView!
//	@IBOutlet weak var retryButton: UIBarButtonItem!
//	
//	let deviceDiscoverer = RokuDeviceDiscoverer()
//	
//	let encoder = PropertyListEncoder()
//	
////	var enabledDevices = Storable<[RokuDevice]>(key: "enabledDevices", store: PropertyListFileObjectStore(fileURL: preferencesURL), defaultValue: [])
//	
////	var enabledDevices: [RokuDevice] = [] {
////		didSet {
////			guard oldValue != enabledDevices else { return }
////			do {
////				let data = try encoder.encode(enabledDevices)
////				try data.write(to: preferencesURL)
////				print("Wrote enabled devices to local file successfully")
////
////				if WCSession.default.activationState == .activated {
////					WCSession.default.sendMessage(["command": "refresh", "data": data], replyHandler: nil, errorHandler: nil)
////				}
////
////			} catch {
////				print("Error saving enabled devices to local file:", error)
////			}
////		}
////	}
//	
//	var discoveredDevices: [RokuDevice] = []
//	
//    override func viewDidLoad() {
//        super.viewDidLoad()
//		
//		navigationItem.rightBarButtonItems = [retryButton, UIBarButtonItem(customView: activityIndicator)]
//		
//		deviceDiscoverer.delegate = self
//		
////		beginSearching()
//		
//		if #available(iOS 13.0, *) {
//			updateActivityIndicatorColor()
//		}
//		
//		tableView.isEditing = true
//
//    }
//	
//	@available(iOS 13.0, *)
//	private func updateActivityIndicatorColor() {
//		activityIndicator.style = traitCollection.userInterfaceStyle == .dark ? .white : .gray
//	}
//	
//	override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
//		super.traitCollectionDidChange(previousTraitCollection)
//		
//		if #available(iOS 13.0, *) {
//			if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
//				updateActivityIndicatorColor()
//			}
//		}
//	}
//	
//	@IBAction func addButtonPressed(_ sender: Any) {
//		
//		let alert = UIAlertController(title: "Add Manually", message: "If your device doesn't appear in the list automatically, you can add it manually by entering its IP address.", preferredStyle: .alert)
//		
//		alert.addTextField { (tf) in
//			tf.placeholder = "192.168.1.134"
//			tf.keyboardType = .decimalPad
//		}
//		
//		let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
//		
//		let addAction = UIAlertAction(title: "Add", style: .default) { _ in
//			func showError(_ message: String? = nil, data: Data? = nil) {
//				let errorAlert = UIAlertController(title: "Unable to Add Device", message: message, preferredStyle: .alert)
//				let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
//				errorAlert.addAction(okAction)
//				
//				if let data = data, MFMailComposeViewController.canSendMail() {
//					let reportAction = UIAlertAction(title: "Send Error Log", style: .default) { _ in
//						let composer = MFMailComposeViewController()
//						composer.mailComposeDelegate = self
//						
//						composer.setToRecipients(["josh@birnholz.com"])
//						composer.setSubject("Remoku Device Add Error Log")
//						composer.addAttachmentData(data, mimeType: "text/xml", fileName: "device-info.xml")
//						
//						self.present(composer, animated: true, completion: nil)
//					}
//					
//					errorAlert.addAction(reportAction)
//				}
//				
//				self.present(errorAlert, animated: true, completion: nil)
//			}
//			
//			guard let input = alert.textFields?.first?.text, let url = URL(string: "http://\(input):8060/") else { showError("Invalid IP address"); return }
//			
//			RokuDevice.create(from: url) { result in
//				do {
//					let device = try result.get()
//					self.found(device)
//				} catch {
//					let data = (error as? RokuDevice.CreationError)?.data
//					showError("A Roku device could not be reached at “\(input)”.", data: data)
//				}
//				
//			}
//			
//		}
//		
//		alert.addAction(cancelAction)
//		alert.addAction(addAction)
//		
//		self.present(alert, animated: true, completion: nil)
//		
//	}
//	
//	@IBAction func beginSearching() {
//		print(#function)
//		
//		retryButton.isEnabled = false
//		activityIndicator.isHidden = false
//		activityIndicator.startAnimating()
//		
//		deviceDiscoverer.startSearching(timeout: 60)
//	}
//	
//	func finishSearching() {
//		deviceDiscoverer.stopSearching()
//	}
//	
//	func found(_ device: RokuDevice) {
//		self.foundDeviceSerialNumbers.insert(device.serialNumber)
//		
//		if let updateEnabledIndex = self.enabledDevices.firstIndex(of: device) {
//			// Found device that was already enabled. Update it in the enabled list.
//			
//			self.enabledDevices[updateEnabledIndex] = device
//			self.tableView.reloadRows(at: [IndexPath(row: updateEnabledIndex, section: 0)], with: .fade)
//		} else if let updateIndex = self.discoveredDevices.firstIndex(of: device) {
//			// Device with same serial number was already in list, may have changed IPs or something. Update it
//			self.discoveredDevices[updateIndex] = device
//			self.tableView.reloadRows(at: [IndexPath(row: updateIndex, section: 1)], with: .fade)
//		} else if let removalIndex = self.discoveredDevices.firstIndex(where: { $0.currentLocation == device.currentLocation }) {
//			// There was somehow already another device with the same location. Remove the old one and add the new one
//			self.discoveredDevices.remove(at: removalIndex)
//			self.tableView.deleteRows(at: [IndexPath(row: removalIndex, section: 1)], with: .automatic)
//			
//			let newIndex = self.discoveredDevices.count
//			self.discoveredDevices.append(device)
//			self.tableView.insertRows(at: [IndexPath(row: newIndex, section: 1)], with: .automatic)
//		} else {
//			// Found new device. Add it
//			let newIndex = self.discoveredDevices.count
//			self.discoveredDevices.append(device)
//			self.tableView.insertRows(at: [IndexPath(row: newIndex, section: 1)], with: .automatic)
//		}
//	}
//	
//	// MARK: UITableViewDataSource
//	
//	override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
//		switch indexPath.section {
//		case 0:
//			return .delete
//		case 1:
//			return .insert
//		default:
//			return .none
//		}
//	}
//	
//	override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
//		
//		switch indexPath.section {
//		case 0:
//			// Disabling device
//			
//			let device = enabledDevices[indexPath.row]
//			
//			let alert = UIAlertController(title: "Remove Device", message: "Are you sure you want to remove “\(device.friendlyDeviceName)” from your Apple Watch?", preferredStyle: .alert)
//			
//			let removeAction = UIAlertAction(title: "Remove", style: .destructive) { _ in
//				self.enabledDevices.remove(at: indexPath.row)
//				
//				if self.foundDeviceSerialNumbers.contains(device.serialNumber) {
//					// Put back in discovered section
//					self.discoveredDevices.append(device)
//					
//					let newIndexPath = IndexPath(row: self.discoveredDevices.count-1, section: 1)
//					tableView.moveRow(at: indexPath, to: newIndexPath)
//				} else {
//					// Remove completely
//					tableView.deleteRows(at: [indexPath], with: .automatic)
//				}
//			}
//			
//			let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
//			
//			alert.addAction(removeAction)
//			alert.addAction(cancelAction)
//			
//			self.present(alert, animated: true, completion: nil)
//			
//		case 1:
//			// Enabling discovered device
//			
//			let device = discoveredDevices.remove(at: indexPath.row)
//			enabledDevices.append(device)
//			
//			let newIndexPath = IndexPath(row: enabledDevices.count-1, section: 0)
//			
//			tableView.moveRow(at: indexPath, to: newIndexPath)
//			
//		default:
//			break
//		}
//		
//	}
//	
//	override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
//		return indexPath.section == 0
//	}
//	
//	override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
//		
//		let device = enabledDevices.remove(at: sourceIndexPath.row)
//		enabledDevices.insert(device, at: destinationIndexPath.row)
//		
//	}
//	
//	override func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath, toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {
//		if proposedDestinationIndexPath.section != 0 {
//			return IndexPath(row: enabledDevices.count-1, section: 0)
//		} else {
//			return proposedDestinationIndexPath
//		}
//	}
//	
//	override func numberOfSections(in tableView: UITableView) -> Int {
//		return 2
//	}
//	
//	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
//		switch section {
//		case 0:
//			return enabledDevices.count
//		case 1:
//			return discoveredDevices.count
//		default:
//			return 0
//		}
//	}
//	
//	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
//		switch section {
//		case 0:
//			return "On Your Watch"
//		case 1:
//			return "Discovered Devices"
//		default:
//			return nil
//		}
//	}
//	
//	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {		
//		let cell = tableView.dequeueReusableCell(withIdentifier: "DeviceCell", for: indexPath)
//		
//		let device: RokuDevice
//		
//		switch indexPath.section {
//		case 0:
//			device = enabledDevices[indexPath.row]
//			cell.selectionStyle = .none
//		case 1:
//			device = discoveredDevices[indexPath.row]
//			cell.selectionStyle = .default
//		default:
//			return cell
//		}
//		
//		cell.textLabel?.text = device.friendlyDeviceName
//		cell.detailTextLabel?.text = device.friendlyModelName
//		
//		return cell
//		
//	}
//	
//}
//
//extension ViewController: RokuDeviceDiscovererDelegate {
//	func rokuDeviceDiscoverer(_ rokuDeviceDiscoverer: RokuDeviceDiscoverer, didFind device: RokuDevice) {
//		self.found(device)
//	}
//	
//	func rokuDeviceDiscovererDidStopSearching(_ rokuDeviceDiscoverer: RokuDeviceDiscoverer) {
//		retryButton.isEnabled = true
//		activityIndicator.stopAnimating()
//		
//		if foundDeviceSerialNumbers.isEmpty && !enabledDevices.isEmpty {
//			let okAction = UIAlertAction(title: "OK", style: .cancel, handler: nil)
//			let retryAction = UIAlertAction(title: "Retry", style: .default) { _ in
//				self.beginSearching()
//			}
//			
//			let alert = UIAlertController(title: "No Devices Found", message: "Make sure your this device and your Roku are connected to the same network.", preferredStyle: .alert)
//			
//			alert.addAction(okAction)
//			alert.addAction(retryAction)
//			
//			DispatchQueue.main.async {
//				self.present(alert, animated: true, completion: nil)
//			}
//		}
//	}
//}
//
//extension ViewController: MFMailComposeViewControllerDelegate {
//	func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
//		dismiss(animated: true, completion: nil)
//	}
//}
