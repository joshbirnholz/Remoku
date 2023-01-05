//
//  RokuDevice.swift
//  RokuKit
//
//  Created by Josh Birnholz on 10/8/18.
//  Copyright © 2018 Josh Birnholz. All rights reserved.
//

import Foundation
#if os(iOS)
import SystemConfiguration.CaptiveNetwork
#endif

public struct NetworkInfo: Codable, Hashable {
	public var ssid: String
	public var bssid: String
	
	public init(ssid: String, bssid: String) {
		self.ssid = ssid
		self.bssid = bssid
	}
	
	#if os(iOS)
	public static var current: NetworkInfo? {
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
	#endif
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
	
	public override var hash: Int {
		var hasher = Hasher()
		hasher.combine(serialNumber)
		return hasher.finalize()
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
	
	public func update(withPropertiesOf device: RokuDevice) {
		guard self.serialNumber == device.serialNumber else { return }
		self.currentLocation = device.currentLocation
		self.friendlyDeviceName = device.friendlyDeviceName
		self.apps = device.apps
		
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
	
	private static let decoder = XMLDecoder()
	
	public enum CreationError: Error {
		case dataError(Error)
		case decodingError(Error, Data)
		
		public var data: Data? {
			switch self {
			case .dataError(_): return nil
			case .decodingError(_, let data): return data
			}
		}
		
		public var error: Error {
			switch self {
			case .dataError(let error): return error
			case .decodingError(let error, _): return error
			}
		}
	}
	
	public static func create(from url: URL, completion: @escaping ((Result<RokuDevice, CreationError>) -> Void)) {
		DispatchQueue.global(qos: .userInitiated).async {
			let deviceInfoURL = url.appendingPathComponent("query").appendingPathComponent("device-info")
			
			call(completion, onQueue: .main) {
				do {
					let data = try Data(contentsOf: deviceInfoURL)
					
					do {
						let deviceInfo = try decoder.decode(RokuDevice.self, from: data)
						#if os(iOS)
						deviceInfo.connectedNetworkInfo = NetworkInfo.current
						#endif
						deviceInfo.currentLocation = url
						return .success(deviceInfo)
					} catch {
						return .failure(.decodingError(error, data))
					}
				} catch {
					return .failure(.dataError(error))
				}
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
	
	public struct SearchQuery: Codable {
		public enum SearchType: String, Codable {
			case movie
			case tvShow = "tv-show"
			case person
			case channel
			case game
		}
		
		/// The content title, channel name, person name, or keyword to be searched. If title is specified, it will be automatically used for the keyword value if keyword is not specified.
		public var keyword: String?
		/// The exact content title, channel name, person name, or keyword to be matched (ASCII case-insensitive).
		public var title: String?
		/// This parameter is recommended as otherwise the search results are unconstrained and may cause the desired item to not be found due to result limits
		public var type: SearchType?
		/// A TMS ID for a movie, TV show, or person. If known, this parameter is recommended to be passed in conjunction with the keyword and type parameters as this should most likely provide the desired search result.
		public var tmsid: String?
		/// A season number for a TV show (series), e.g. 1, 2, 3, ... If specified for a tv-show search, and the TV show is found, the specified season will be picked in the Seasons list to be launched. If not specified or not found, the default (typically most recent) season will be selected.
		public var season: Int?
		/// Allows the general keyword search results to include upcoming movie / tv-shows that are not currently available on Roku.
		public var showUnavailable: Bool?
		/// If there are multiple results matching the query, automatically selects the arbitrary first result. If this is not specified, the search will stop if the results do not indicate a unique result.
		public var matchAny: Bool?
		/// One or more Roku channel IDs specifying the preferred/target provider. If specified, and the search results are available, the first provider available will be selected (and launched if so specified). E.g. `[12, 13]` indicates that Netflix should be used (if available), else Amazon Video (if available).
		public var providerIds: [Int]?
		/// One or more Roku channel titles specifying the preferred/target provider. If specified, and the search results are available, the first provider available will be selected. E.g. `[Amazon Video, VUDU`] indicates that Amazon Video should be used (if available), else VUDU (if available). Provider names are must be a full title match (case-insensitive) against the user's installed channels to be recognized.
		public var providers: [String]?
		/// Specifies that if the search content is found and a specified provider is available, the provider channel should be launched.
		public var launch: Bool?
	
		var queryItems: [URLQueryItem] {
			var items: [URLQueryItem] = []
			
			if let keyword = keyword {
				items.append(URLQueryItem(name: "keyword", value: keyword))
			}
			if let title = title {
				items.append(URLQueryItem(name: "title", value: title))
			}
			if let type = type {
				items.append(URLQueryItem(name: "type", value: type.rawValue))
			}
			if let tmsid = tmsid {
				items.append(URLQueryItem(name: "tmsid", value: tmsid))
			}
			if let season = season {
				items.append(URLQueryItem(name: "season", value: String(season)))
			}
			if let showUnavailable = showUnavailable {
				items.append(URLQueryItem(name: "show-unavailable", value: String(showUnavailable)))
			}
			if let matchAny = matchAny {
				items.append(URLQueryItem(name: "match-any", value: String(matchAny)))
			}
			if let providerIds = providerIds {
				items.append(URLQueryItem(name: "provider-id", value: providerIds.map(String.init).joined(separator: ",")))
			}
			if let providers = providers {
				items.append(URLQueryItem(name: "provider", value: providers.joined(separator: ",")))
			}
			if let launch = launch {
				items.append(URLQueryItem(name: "launch", value: String(launch)))
			}
			
			return items
		}
	}
	
	public func search(query: SearchQuery) {
		func sendTask() {
			print("Searching for \"\(query)\"")
			let location = self.currentLocation.appendingPathComponent("search").appendingPathComponent("browse")
			var components = URLComponents(url: location, resolvingAgainstBaseURL: false)!
			components.queryItems = query.queryItems
			let url = components.url!
			var req = URLRequest(url: url)
			req.httpMethod = "POST"
			URLSession(configuration: .default).dataTask(with: req).resume()
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
	
	public func loadApps(completion: ((Error?) -> Void)?) {
		DispatchQueue.global(qos: .userInteractive).async {
			var appsError: Error?
			let appsData: Data? = {
				let appURL = self.currentLocation.appendingPathComponent("query").appendingPathComponent("apps")
				let req = URLRequest(url: appURL, cachePolicy: .reloadIgnoringLocalCacheData)
				let semaphore = DispatchSemaphore(value: 0)
				var appData: Data?
				URLSession(configuration: .default).dataTask(with: req, completionHandler: { data, response, error in
					appData = data
					appsError = error
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
					completion?(nil)
				} else {
					self.apps = []
					completion?(appsError)
				}
			} catch {
				self.apps = []
				completion?(error)
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
