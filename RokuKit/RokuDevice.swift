//
//  RokuDevice.swift
//  RokuKit
//
//  Created by Josh Birnholz on 10/8/18.
//  Copyright © 2018 Josh Birnholz. All rights reserved.
//

import Foundation

public struct NetworkInfo: Codable {
	var ssid: String
	var bssid: String
	
	public init(ssid: String, bssid: String) {
		self.ssid = ssid
		self.bssid = bssid
	}
}

public class RokuDevice: NSObject, Codable {
	public var currentLocation: URL!
	public var serialNumber: String
	public var modelName: String
	public var friendlyModelName: String
	public var isTV: Bool
	public var isStick: Bool
	public var friendlyDeviceName: String
	public var apps: [App]! = []
	
	public var connectedNetworkInfo: NetworkInfo?
	
	public override func isEqual(_ object: Any?) -> Bool {
		guard let otherDevice = object as? RokuDevice else { return false }
		
		return serialNumber == otherDevice.serialNumber
	}
	
	public weak var delegate: RokuDeviceDelegate?
	
	private init(currentLocation: URL, serialNumber: String, modelName: String, isTV: Bool, isStick: Bool, friendlyDeviceName: String, friendlyModelName: String, apps: [App]) {
		self.currentLocation = currentLocation
		self.serialNumber = serialNumber
		self.modelName = modelName
		self.isTV = isTV
		self.isStick = isStick
		self.friendlyDeviceName = friendlyDeviceName
		self.friendlyModelName = friendlyModelName
		self.apps = apps
	}
	
	public struct App: Codable, Equatable {
		
		public static func ==(lhs: App, rhs: App) -> Bool {
			if let lID = lhs.id, let rID = rhs.id {
				return lID == rID
			} else if (lhs.id == nil) != (rhs.id == nil) {
				return false
			}
			
			return lhs.name == rhs.name && lhs.type == rhs.type && lhs.id == rhs.id
		}
		
		public var name: String
		public var id: String?
		public var type: String?
		
		init?(dictionary: [String: Any]) {
			guard let name = dictionary["text"] as? String else {
					return nil
			}
			
			self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
			self.id = (dictionary["id"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
			self.type = (dictionary["type"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
		}
		
	}
	
	public static func create(from url: URL, completion: @escaping ((RokuDevice?, Data?) -> Void)) {
		DispatchQueue.global(qos: .userInitiated).async {
			let deviceInfoURL = url.appendingPathComponent("query").appendingPathComponent("device-info")
			
			guard let data = try? Data(contentsOf: deviceInfoURL) else {
				completion(nil, nil)
				return
				
			}
			
			guard let deviceInfo = try? XMLDecoder().decode(RokuDevice.self, from: data) else {
				completion(nil, data)
				return
			}
			
			deviceInfo.currentLocation = url
			
			DispatchQueue.main.async {
				completion(deviceInfo, data)
			}
		}
	}
	
	public func launchApp(id: String) {
		DispatchQueue.global(qos: .userInteractive).async {
			print("Launching app with id", id)
			let url = self.currentLocation.appendingPathComponent("launch").appendingPathComponent(id)
			var req = URLRequest(url: url)
			req.httpMethod = "POST"
			URLSession(configuration: .default).dataTask(with: req).resume()
			
			if let app = self.apps?.first(where: { $0.id == id }) {
				DispatchQueue.main.async {
					self.delegate?.rokuDevice(self, didLaunch: app)
				}
			}
			
		}
	}
	
	public func send(keypress: KeyPress, sync: Bool = false) {
		func sendTask() {
			let semaphore = DispatchSemaphore(value: 0)
			
			print("Sending keypress", keypress.rawValue)
			let url = self.currentLocation.appendingPathComponent("keypress").appendingPathComponent(keypress.rawValue)
			var req = URLRequest(url: url)
			req.httpMethod = "POST"
			URLSession(configuration: .default).dataTask(with: req) { data, response, error in
				semaphore.signal()
			}.resume()
			
			semaphore.wait()
		}
		
		if sync {
			sendTask()
		} else {
			DispatchQueue.global(qos: .userInteractive).async {
				print("Sending keypress", keypress.rawValue)
				let url = self.currentLocation.appendingPathComponent("keypress").appendingPathComponent(keypress.rawValue)
				var req = URLRequest(url: url)
				req.httpMethod = "POST"
				URLSession(configuration: .default).dataTask(with: req).resume()
			}
		}
	}
	
	public func loadIcon(appID: String, completion: @escaping ((UIImage?) -> Void)) {
		
		DispatchQueue.global(qos: .userInteractive).async {
			let cachedFileURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent("\(appID).png")
			
			if let image = UIImage(contentsOfFile: cachedFileURL.path) {
				completion(image)
				return
			}
			
			let iconURL = self.currentLocation.appendingPathComponent("query").appendingPathComponent("icon").appendingPathComponent(appID)
			let req = URLRequest(url: iconURL)
			URLSession(configuration: .default).dataTask(with: req, completionHandler: { data, response, error in
				
				if let error = error {
					completion(nil)
					print("Error loading icon for app with id", appID, error.localizedDescription)
					return
				}
				
				print("Got icon for app with id", appID)
				
				let icon = data.flatMap(UIImage.init)
				completion(icon)
				
				DispatchQueue.global(qos: .utility).async {
					try? data?.write(to: cachedFileURL)
				}
			}).resume()
			
		}
	}
	
	public func send(litString: String) {
		for character in litString {
			send(keypress: .Lit(character), sync: true)
		}
	}
	
	enum CodingKeys: String, CodingKey {
		case serialNumber = "serial-number"
		case modelName = "model-name"
		case friendlyModelName = "friendly-model-name"
		case isTV = "is-tv"
		case isStick = "is-stick"
		case friendlyDeviceName = "friendly-device-name"
		case apps
		case currentLocation
	}
	
	public func getActiveApp(completion: @escaping ((App?) -> Void)) {
		DispatchQueue.global(qos: .userInteractive).async {
			guard let appData: Data = {
				let appURL = self.currentLocation.appendingPathComponent("query").appendingPathComponent("active-app")
				let req = URLRequest(url: appURL, cachePolicy: .reloadIgnoringLocalCacheData)
				let semaphore = DispatchSemaphore(value: 0)
				var appData: Data?
				URLSession(configuration: .default).dataTask(with: req, completionHandler: { data, response, error in
					appData = data
					print("Got active app data")
					semaphore.signal()
				}).resume()
				semaphore.wait()
				return appData
				}() else {
					completion(nil)
					return
			}
			
			do {
				if let xmlDict = try XMLReader.dictionary(forXMLData: appData)["active-app"] as? [String: Any], let appDict = xmlDict["app"] as? [String: Any], let app = App(dictionary: appDict) {
					completion(app)
				} else {
					completion(nil)
				}
			} catch {
				completion(nil)
			}
		}
		
	}
	
	public func loadApps(completion: (() -> Void)?) {
		DispatchQueue.global(qos: .userInteractive).async {
			let appsData: Data? = {
				let appURL = self.currentLocation.appendingPathComponent("query").appendingPathComponent("apps")
				let req = URLRequest(url: appURL, cachePolicy: .reloadIgnoringLocalCacheData)
				let semaphore = DispatchSemaphore(value: 0)
				var appData: Data?
				URLSession(configuration: .default).dataTask(with: req, completionHandler: { data, response, error in
					appData = data
					print("Got apps")
					semaphore.signal()
				}).resume()
				semaphore.wait()
				return appData
			}()
			
			do {
				if let appsData = appsData, let xmlDict = try XMLReader.dictionary(forXMLData: appsData)["apps"] as? [String: Any],
					let appsDict = xmlDict["app"] as? [[String: Any]] {
					let apps = appsDict.compactMap(App.init)
					self.apps = apps
					completion?()
				} else {
					self.apps = []
					completion?()
				}
			} catch {
				self.apps = []
				completion?()
				print(error.localizedDescription)
			}
		}
		
	}
	
	public override var debugDescription: String {
		return "\(friendlyDeviceName) (SN: \(serialNumber)"
	}
}

public protocol RokuDeviceDelegate: class {
	
	func rokuDevice(_ device: RokuDevice, didLaunch app: RokuDevice.App)
	
}
