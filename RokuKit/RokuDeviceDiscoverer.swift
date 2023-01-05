//
//  RokuDeviceDiscoverer.swift
//  Roku Remote
//
//  Created by Josh Birnholz on 10/24/19.
//  Copyright © 2019 Josh Birnholz. All rights reserved.
//

import Foundation
import CocoaAsyncSocket

public protocol RokuDeviceDiscovererDelegate: class {
	func rokuDeviceDiscoverer(_ rokuDeviceDiscoverer: RokuDeviceDiscoverer, didFind device: RokuDevice)
	func rokuDeviceDiscovererDidStopSearching(_ rokuDeviceDiscoverer: RokuDeviceDiscoverer)
}

public class RokuDeviceDiscoverer: NSObject, GCDAsyncUdpSocketDelegate {
	public weak var delegate: RokuDeviceDiscovererDelegate?
	
	private var ssdpSocket: GCDAsyncUdpSocket? {
		didSet {
			oldValue?.close()
		}
	}
	
	public private(set) var isSearching: Bool = false
	
	public func startSearching(timeout: TimeInterval?) {
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
			isSearching = true
			
			if let timeout = timeout {
				DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
					self.stopSearching()
				}
			}
			
		} catch {
			print(error)
			stopSearching()
		}
	}
	
	public func stopSearching() {
		ssdpSocket?.closeAfterSending()
		ssdpSocket = nil
		
		if isSearching {
			
			delegate?.rokuDeviceDiscovererDidStopSearching(self)
		}
		
		isSearching = false
	}
	
	private func foundRoku(with url: URL) {
		RokuDevice.create(from: url) { result in
			guard let device = try? result.get() else { return }
			DispatchQueue.main.async { [weak self] in
				guard let self = self else { return }
				self.delegate?.rokuDeviceDiscoverer(self, didFind: device)
			}
		}
	}
	
	// MARK: GCDAsyncUdpSocketDelegate
	
	public func udpSocket(_ sock: GCDAsyncUdpSocket, didConnectToAddress address: Data) {
		print("Did connect to address")
		print(address)
	}
	
	public func udpSocket(_ sock: GCDAsyncUdpSocket, didReceive data: Data, fromAddress address: Data, withFilterContext filterContext: Any?) {
		print("Did receive data")
		if let str = String(data: data, encoding: .utf8), str.contains("HTTP/1.1 200 OK") {
			let locationString = str.split(separator: "\r\n").first(where: { $0.hasPrefix("LOCATION: ") })?.replacingOccurrences(of: "location: ", with: "", options: [.caseInsensitive])
			if let locationString = locationString, let url = URL(string: locationString) {
				self.foundRoku(with: url)
			}
			
			DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
				self.stopSearching()
			}
		}
	}
}
