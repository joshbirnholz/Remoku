//
//  RokuFinder.swift
//  Roku Remote
//
//  Created by Josh Birnholz on 10/7/18.
//  Copyright © 2018 Josh Birnholz. All rights reserved.
//

import Foundation
import CocoaAsyncSocket

public class RokuFinder: NSObject {
	
	weak var delegate: RokuFinderDelegate?
	
	init(delegate: RokuFinderDelegate?) {
		self.delegate = delegate
		super.init()
		
	}
	
	public func beginSearching() {
		let ssdpAddress = "239.255.255.250"
		let ssdpPort: UInt16 = 1900
		let ssdpSocket = GCDAsyncUdpSocket(delegate: self, delegateQueue: .main)
		
		let mSearchData = """
		M-SEARCH * HTTP/1.1
		Host: 239.255.255.250:1900
		Man: "ssdp:discover"
		ST: roku:ecp
		
		""".data(using: .utf8)!
		
		//send M-Search
		
		
		//bind for responses
		do {
			try ssdpSocket.bind(toPort: ssdpPort)
			ssdpSocket.send(mSearchData, toHost: ssdpAddress, port: ssdpPort, withTimeout: 1, tag: 0)
			try ssdpSocket.joinMulticastGroup(ssdpAddress)
			try ssdpSocket.beginReceiving()
		} catch {
			print(error)
		}
	}
	
//	public func endSearching() {
//		ssdpSocket.closeAfterSending()
//	}
	
}

extension RokuFinder: GCDAsyncUdpSocketDelegate {
	
	private func udpSocket(_ sock: GCDAsyncUdpSocket, didConnectToAddress address: Data) {
		print("Did connect to address")
		print(address)
	}
	
	private func udpSocket(_ sock: GCDAsyncUdpSocket, didReceive data: Data, fromAddress address: Data, withFilterContext filterContext: Any?) {
		print("Did receive data")
		if let str = String(data: data, encoding: .utf8), str.contains("HTTP/1.1 200 OK") {
			let locationString = str.split(separator: "\r\n").first(where: { $0.hasPrefix("LOCATION: ") })?.replacingOccurrences(of: "location: ", with: "", options: [.caseInsensitive])
			if let locationString = locationString, let url = URL(string: locationString) {
				self.delegate?.didFindRoku(with: url)
			}
		}
	}
	
}


protocol RokuFinderDelegate: class {
	
	func didFindRoku(with url: URL)
	
}
