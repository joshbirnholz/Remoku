//
//  ViewController.swift
//  Roku Remote
//
//  Created by Josh Birnholz on 10/7/18.
//  Copyright © 2018 Josh Birnholz. All rights reserved.
//

import UIKit
import CocoaAsyncSocket
import RokuKit
import WatchConnectivity

class ViewController: UITableViewController {
	
	var foundDevices: [RokuDevice] = []
	
	var ssdpSocket: GCDAsyncUdpSocket?
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		WCSession.default.delegate = self
		WCSession.default.activate()
		
	}
	
	override func numberOfSections(in tableView: UITableView) -> Int {
		return 1
	}
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return foundDevices.count
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "DeviceCell", for: indexPath)
		
		let device = foundDevices[indexPath.row]
		
		cell.textLabel?.text = device.friendlyDeviceName
		cell.detailTextLabel?.text = device.modelName
		
		return cell
	}
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableView.deselectRow(at: indexPath, animated: true)
		let device = foundDevices[indexPath.row]
		
		let alert = UIAlertController(title: "“\(device.friendlyDeviceName)”", message: "Send to Apple Watch?", preferredStyle: .alert)
		
		let sendAction = UIAlertAction(title: "Send", style: .default) { _ in
			let session = WCSession.default
			
			do {
				let data = try PropertyListEncoder().encode(device)
				guard let localFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("rokudevice.plist") else {
					throw NSError(domain: "Couldn't create URL", code: -1, userInfo: [:])
				}
				try data.write(to: localFileURL)
				
				if session.isReachable {
					session.transferFile(localFileURL, metadata: nil)
				}
			} catch {
				print(error.localizedDescription)
			}
			
		}
		
		let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
		
		alert.addAction(cancelAction)
		alert.addAction(sendAction)
		
		self.present(alert, animated: true, completion: nil)
		
	}
	
	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		if let socket = ssdpSocket {
			if socket.isClosed() {
				return "Found \(foundDevices.count) device" + (foundDevices.count == 1 ? "" : "s")
			} else {
				return "Searching…"
			}
		}
		return ""
	}
	
	func findRoku() {
		print(#function)
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
			try ssdpSocket!.bind(toPort: ssdpPort)
			ssdpSocket!.send(mSearchData, toHost: ssdpAddress, port: ssdpPort, withTimeout: 1, tag: 0)
			try ssdpSocket!.joinMulticastGroup(ssdpAddress)
			try ssdpSocket!.beginReceiving()
		} catch {
			print(error)
		}
	}
	
	func foundRoku(with url: URL) {
		print(#function)
		RokuDevice.create(from: url) { device in
			guard let device = device else { return }
			DispatchQueue.main.async {
				self.foundDevices.append(device)
				self.tableView.insertRows(at: [IndexPath(row: self.foundDevices.count-1, section: 0)], with: .automatic)
			}
		}
		
	}

	@IBAction func searchButtonPressed(_ sender: Any) {
		ssdpSocket?.close()
		foundDevices.removeAll()
		
		self.tableView.reloadSections(IndexSet(integer: 0), with: .automatic)
		
		WCSession.default.activate()
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
			
			DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
				sock.close()
				self.tableView.reloadSections(IndexSet(integer: 0), with: .automatic)
				print("Closed socket")
			}
		}
	}
	
}

extension ViewController: WCSessionDelegate {
	func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
		if activationState == .activated && session.isPaired && session.isWatchAppInstalled && session.isReachable {
			findRoku()
			DispatchQueue.main.async {
				self.tableView.reloadSections(IndexSet(integer: 0), with: .automatic)
			}
		} else {
			let alert = UIAlertController(title: "Error Connecting to Apple Watch", message: error?.localizedDescription ?? "Open the app on your Apple Watch and try again.", preferredStyle: .alert)
			let okAction = UIAlertAction(title: "OK", style: .cancel, handler: nil)
			alert.addAction(okAction)
			DispatchQueue.main.async {
				self.present(alert, animated: true, completion: nil)
			}
		}
	}
	
	func sessionDidBecomeInactive(_ session: WCSession) {
		
	}
	
	func sessionDidDeactivate(_ session: WCSession) {
		ssdpSocket?.close()
		self.tableView.reloadSections(IndexSet(integer: 0), with: .automatic)
	}
	
}
