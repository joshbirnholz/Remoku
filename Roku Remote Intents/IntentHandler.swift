//
//  IntentHandler.swift
//  Remoku Intents
//
//  Created by Josh Birnholz on 10/26/19.
//  Copyright © 2019 Josh Birnholz. All rights reserved.
//

import Intents
import RokuKit

class IntentHandler: INExtension {
    
    override func handler(for intent: INIntent) -> Any {
        // This is the default implementation.  If you want different objects to handle different intents,
        // you can override this and return the handler you want for that particular intent.
		
		if #available(iOSApplicationExtension 12.0, *) {
			if intent is PressButtonIntent {
				return PressButtonIntentHandler()
			}
			
			if intent is LaunchAppIntent {
				return LaunchAppIntentHandler()
			}
			
			if intent is PlayPauseIntent {
				return PlayPauseIntentHandler()
			}
			
			if intent is PowerOnOffIntent {
				return PowerOnOffIntentHandler()
			}
			
			if intent is TypeTextIntent {
				return TypeTextIntentHandler()
			}
		}
        
        return self
    }
    
}

@available(iOSApplicationExtension 12.0, *)
func keyPress(for button: Button) -> KeyPress? {
	switch button {
	case .home: return .Home
	case .rev: return .Rev
	case .fwd: return .Fwd
	case .play: return .Play
	case .select: return .Select
	case .left: return .Left
	case .right: return .Right
	case .down: return .Down
	case .up: return .Up
	case .back: return .Back
	case .instantReplay: return .InstantReplay
	case .info: return .Info
	case .backspace: return .Backspace
	case .search: return .Search
	case .enter: return .Enter
	case .findRemote: return .FindRemote
	case .volumeUp: return .VolumeUp
	case .volumeMute: return .VolumeMute
	case .volumeDown: return .VolumeDown
	case .powerOff: return .PowerOff
	case .powerOn: return .PowerOn
	case .power: return .Power
	case .channelUp: return .ChannelUp
	case .channelDown: return .ChannelDown
	case .inputTuner: return .InputTuner
	case .inputHDMI1: return .InputHDMI1
	case .inputHDMI2: return .InputHDMI2
	case .inputHDMI3: return .InputHDMI3
	case .inputHDMI4: return .InputHDMI4
	case .inputAV1: return .InputAV1
	case .unknown: return nil
	}
}

func searchForDevicesOnNetwork(timeout: TimeInterval, completion: @escaping ([RokuDevice]) -> Void) {
	class FinderDelegate: NSObject, RokuDeviceDiscovererDelegate {
		private var foundDevices: [RokuDevice] = []
		var didStopSearchingHandler: (([RokuDevice]) -> Void)
		init(didStopSearchingHandler: @escaping ([RokuDevice]) -> Void) {
			self.didStopSearchingHandler = didStopSearchingHandler
		}

		static let encoder = PropertyListEncoder()

		func rokuDeviceDiscoverer(_ rokuDeviceDiscoverer: RokuDeviceDiscoverer, didFind device: RokuDevice) {
			foundDevices.append(device)
		}

		func rokuDeviceDiscovererDidStopSearching(_ rokuDeviceDiscoverer: RokuDeviceDiscoverer) {
			didStopSearchingHandler(foundDevices)
		}
	}
	
	let finder = RokuDeviceDiscoverer()
	let finderDelegate = FinderDelegate() { foundDevices in
		completion(foundDevices)
	}
	finder.delegate = finderDelegate
	
	finder.startSearching(timeout: nil)
	
	DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
		finder.stopSearching()
		_ = finderDelegate
	}
}

@available(iOSApplicationExtension 12.0, *)
func rokuDeviceOnCurrentNetwork(withSerialNumber serialNumber: String, lastKnownLocation: URL?, searchTimeout: TimeInterval = 10, completion: @escaping (RokuDevice?) -> Void) {
	
	func getDeviceFromLastKnownLocation(c: @escaping (RokuDevice?) -> Void) {
		guard let lastKnownLocation = lastKnownLocation else {
			c(nil)
			return
		}
		RokuDevice.create(from: lastKnownLocation) { device in
			guard let device = try? device.get(), device.serialNumber == serialNumber else {
				c(nil)
				return
			}
			c(device)
		}
	}
	
	func searchForDeviceOnNetwork(c: @escaping (RokuDevice?) -> Void) {
		class FinderDelegate: NSObject, RokuDeviceDiscovererDelegate {
			var serialNumber: String
			var foundMatchingDeviceHandler: (RokuDevice) -> Void
			var didStopSearchingHandler: (() -> Void)? = nil
			init(serialNumber: String, foundMatchingDeviceHandler: @escaping (RokuDevice) -> Void) {
				self.serialNumber = serialNumber
				self.foundMatchingDeviceHandler = foundMatchingDeviceHandler
				super.init()
			}
			static let encoder = PropertyListEncoder()

			func rokuDeviceDiscoverer(_ rokuDeviceDiscoverer: RokuDeviceDiscoverer, didFind device: RokuDevice) {
				if device.serialNumber == serialNumber {
					foundMatchingDeviceHandler(device)
				}
			}

			func rokuDeviceDiscovererDidStopSearching(_ rokuDeviceDiscoverer: RokuDeviceDiscoverer) {
				didStopSearchingHandler?()
			}
		}
		
		var foundDevice = false
		
		let finder = RokuDeviceDiscoverer()
		let finderDelegate = FinderDelegate(serialNumber: serialNumber) { device in
			c(device)
			foundDevice = true
			finder.stopSearching()
		}
		finderDelegate.didStopSearchingHandler = {
			if !foundDevice {
				c(nil)
			}
		}
		finder.delegate = finderDelegate
		
		finder.startSearching(timeout: nil)
		
		DispatchQueue.main.asyncAfter(deadline: .now() + searchTimeout) {
			finder.stopSearching()
			_ = finderDelegate
		}
	}
	
	getDeviceFromLastKnownLocation { (device) in
		if let device = device {
			completion(device)
			return
		} else {
			searchForDeviceOnNetwork { (device) in
				if let device = device {
					completion(device)
				} else {
					completion(nil)
				}
			}
		}
	}
	
}

@available(iOSApplicationExtension 12.0, *)
protocol RokuDeviceIntent: INIntent {
	var device: Roku? { get set }
}

@available(iOSApplicationExtension 12.0, *)
extension PressButtonIntent: RokuDeviceIntent { }
@available(iOSApplicationExtension 12.0, *)
extension LaunchAppIntent: RokuDeviceIntent { }
@available(iOSApplicationExtension 12.0, *)
extension PlayPauseIntent: RokuDeviceIntent { }
@available(iOSApplicationExtension 12.0, *)
extension PowerOnOffIntent: RokuDeviceIntent { }
@available(iOSApplicationExtension 12.0, *)
extension TypeTextIntent: RokuDeviceIntent { }

@available(iOS 12.0, iOSApplicationExtension 12.0, *)
public extension RokuDevice {
	var roku: Roku_Remote_Intents.Roku {
		let r = Roku(identifier: serialNumber, display: friendlyDeviceName)
		if #available(iOSApplicationExtension 13.0, *) {
			r.currentLocation = currentLocation
		}
		return r
	}
}

@available(iOSApplicationExtension 13.0, *)
struct RokuDeviceParameterResolution {
	static func resolveDevice<IntentType: RokuDeviceIntent>(for intent: IntentType, with completion: @escaping (RokuResolutionResult) -> Void) {
		guard let roku = intent.device, let serialNumber = roku.identifier else {
			completion(.needsValue())
			return
		}
		
		rokuDeviceOnCurrentNetwork(withSerialNumber: serialNumber, lastKnownLocation: roku.currentLocation) { (device) in
			call(completion) {
				if let device = device {
					roku.currentLocation = device.currentLocation
					return .success(with: roku)
				} else {
					return .unsupported()
				}
			}
		}
	}
	
	static func provideDeviceOptions<IntentType: RokuDeviceIntent>(for intent: IntentType, with completion: @escaping ([Roku]?, Error?) -> Void) {
		let rokus: [Roku] = Global.foundDevices.map { $0.roku }
		
		if rokus.isEmpty {
			searchForDevicesOnNetwork(timeout: 5) { (devices) in
				let rokus = devices.map { $0.roku }
				completion(rokus, nil)
				
				if !devices.isEmpty {
					Global.foundDevices = devices
				}
			}
		} else {
			completion(rokus, nil)
		}
	}
}

@available(iOSApplicationExtension 12.0, *)
class PressButtonIntentHandler: NSObject, PressButtonIntentHandling {
	func handle(intent: PressButtonIntent, completion: @escaping (PressButtonIntentResponse) -> Void) {
		
		guard let roku = intent.device, let serialNumber = roku.identifier, let button = keyPress(for: intent.button) else {
			completion(PressButtonIntentResponse.init(code: .failure, userActivity: nil))
			return
		}
		
		let currentLocation: URL? = {
			if #available(iOSApplicationExtension 13.0, *) {
				return roku.currentLocation
			} else {
				return nil
			}
		}()
		
		rokuDeviceOnCurrentNetwork(withSerialNumber: serialNumber, lastKnownLocation: currentLocation) { device in
			if let device = device {
				device.send(keypress: button)
				completion(.init(code: .success, userActivity: nil))
			} else {
				completion(.init(code: .failure, userActivity: nil))
			}
		}
	}
	
	@available(iOSApplicationExtension 13.0, *)
	func resolveButton(for intent: PressButtonIntent, with completion: @escaping (ButtonResolutionResult) -> Void) {
		call(completion) {
			guard keyPress(for: intent.button) != nil else {
				return .needsValue()
			}
			
			return .success(with: intent.button)
		}
	}
	
	@available(iOSApplicationExtension 13.0, *)
	func resolveDevice(for intent: PressButtonIntent, with completion: @escaping (RokuResolutionResult) -> Void) {
		RokuDeviceParameterResolution.resolveDevice(for: intent, with: completion)
	}
	
	@available(iOSApplicationExtension 13.0, *)
	func provideDeviceOptions(for intent: PressButtonIntent, with completion: @escaping ([Roku]?, Error?) -> Void) {
		RokuDeviceParameterResolution.provideDeviceOptions(for: intent, with: completion)
	}
	
}

@available(iOSApplicationExtension 12.0, *)
class LaunchAppIntentHandler: NSObject, LaunchAppIntentHandling {
	func handle(intent: LaunchAppIntent, completion: @escaping (LaunchAppIntentResponse) -> Void) {
		guard let roku = intent.device, let serialNumber = roku.identifier, let appID = intent.app?.identifier else {
			completion(.init(code: .failure, userActivity: nil))
			return
		}
		
		let currentLocation: URL? = {
			if #available(iOSApplicationExtension 13.0, *) {
				return roku.currentLocation
			} else {
				return nil
			}
		}()
		
		rokuDeviceOnCurrentNetwork(withSerialNumber: serialNumber, lastKnownLocation: currentLocation) { device in
			if let device = device {
				device.launchApp(id: appID)
				completion(.init(code: .success, userActivity: nil))
			} else {
				completion(.init(code: .failure, userActivity: nil))
			}
		}
	}
	
	@available(iOSApplicationExtension 13.0, *)
	func resolveApp(for intent: LaunchAppIntent, with completion: @escaping (AppResolutionResult) -> Void) {
		call(completion) {
			guard let app = intent.app else {
				return .needsValue()
			}
			
			if let appID = app.identifier, let device = intent.device, let serialNumber = device.identifier {
				rokuDeviceOnCurrentNetwork(withSerialNumber: serialNumber, lastKnownLocation: device.currentLocation) { device in
					if let appIconURL = device?.currentLocation.appendingPathComponent("query").appendingPathComponent("icon").appendingPathComponent(appID) {
						let image = INImage(url: appIconURL)
						intent.setImage(image, forParameterNamed: \.app)
					}
				}
			}
			
			return .success(with: app)
		}
	}
	
	enum LaunchAppIntentError: Error {
		case couldNotGetListOfApps(RokuDevice?)
		
		var localizedDescription: String {
			switch self {
			case .couldNotGetListOfApps(let device):
				return "Open App on Roku was unable to get the list of apps from “\(device?.friendlyDeviceName ?? "")”."
			}
		}
	}
	
	@available(iOSApplicationExtension 13.0, *)
	func provideAppOptions(for intent: LaunchAppIntent, with completion: @escaping ([App]?, Error?) -> Void) {
		guard let roku = intent.device, let serialNumber = roku.identifier else {
			completion(nil, nil)
			return
		}
		
		rokuDeviceOnCurrentNetwork(withSerialNumber: serialNumber, lastKnownLocation: roku.currentLocation) { device in
			guard let device = device else {
				completion(nil, nil)
				return
			}
			
			device.loadApps() { error in
				if let error = error {
					completion(nil, LaunchAppIntentError.couldNotGetListOfApps(device))
					return
				}
				completion(device.apps.filter { $0.type != "menu" }.map { App(identifier: $0.id, display: $0.name) }, nil)
			}
		}
	}
	
	@available(iOSApplicationExtension 13.0, *)
	func resolveDevice(for intent: LaunchAppIntent, with completion: @escaping (RokuResolutionResult) -> Void) {
		RokuDeviceParameterResolution.resolveDevice(for: intent, with: completion)
	}
	
	@available(iOSApplicationExtension 13.0, *)
	func provideDeviceOptions(for intent: LaunchAppIntent, with completion: @escaping ([Roku]?, Error?) -> Void) {
		RokuDeviceParameterResolution.provideDeviceOptions(for: intent, with: completion)
	}
	
}

@available(iOSApplicationExtension 12.0, *)
class PlayPauseIntentHandler: NSObject, PlayPauseIntentHandling {
	func handle(intent: PlayPauseIntent, completion: @escaping (PlayPauseIntentResponse) -> Void) {
		guard let roku = intent.device, let serialNumber = roku.identifier else {
			completion(.init(code: .failure, userActivity: nil))
			return
		}
		
		let currentLocation: URL? = {
			if #available(iOSApplicationExtension 13.0, *) {
				return roku.currentLocation
			} else {
				return nil
			}
		}()
		
		rokuDeviceOnCurrentNetwork(withSerialNumber: serialNumber, lastKnownLocation: currentLocation) { device in
			if let device = device {
				device.send(keypress: .Play)
				completion(.init(code: .success, userActivity: nil))
			} else {
				completion(.init(code: .failure, userActivity: nil))
			}
		}
	}
	
	@available(iOSApplicationExtension 13.0, *)
	func resolveDevice(for intent: PlayPauseIntent, with completion: @escaping (RokuResolutionResult) -> Void) {
		RokuDeviceParameterResolution.resolveDevice(for: intent, with: completion)
	}
	
	@available(iOSApplicationExtension 13.0, *)
	func provideDeviceOptions(for intent: PlayPauseIntent, with completion: @escaping ([Roku]?, Error?) -> Void) {
		RokuDeviceParameterResolution.provideDeviceOptions(for: intent, with: completion)
	}
	
}

@available(iOSApplicationExtension 12.0, *)
class PowerOnOffIntentHandler: NSObject, PowerOnOffIntentHandling {
	func handle(intent: PowerOnOffIntent, completion: @escaping (PowerOnOffIntentResponse) -> Void) {
		guard let roku = intent.device, let serialNumber = roku.identifier, intent.powerState != .unknown else {
			completion(.init(code: .failure, userActivity: nil))
			return
		}
		
		let currentLocation: URL? = {
			if #available(iOSApplicationExtension 13.0, *) {
				return roku.currentLocation
			} else {
				return nil
			}
		}()
		
		rokuDeviceOnCurrentNetwork(withSerialNumber: serialNumber, lastKnownLocation: currentLocation) { device in
			if let device = device {
				
				guard device.isTV else {
					completion(.init(code: .failureNotTV, userActivity: nil))
					return
				}
				
				switch intent.powerState {
				case .on:
					device.send(keypress: .PowerOn)
				case .off:
					device.send(keypress: .PowerOff)
				case .toggle:
					device.send(keypress: .Power)
				case .unknown:
					completion(.init(code: .failure, userActivity: nil))
					return
				}
				
				completion(.init(code: .success, userActivity: nil))
			} else {
				completion(.init(code: .failure, userActivity: nil))
			}
		}
	}
	
	@available(iOSApplicationExtension 13.0, *)
	func resolvePowerState(for intent: PowerOnOffIntent, with completion: @escaping (PowerStateResolutionResult) -> Void) {
		call(completion) {
			guard intent.powerState != .unknown else {
				return .needsValue()
			}
			
			return .success(with: intent.powerState)
		}
	}
	
	@available(iOSApplicationExtension 13.0, *)
	func resolveDevice(for intent: PowerOnOffIntent, with completion: @escaping (RokuResolutionResult) -> Void) {
		RokuDeviceParameterResolution.resolveDevice(for: intent, with: completion)
	}
	
	@available(iOSApplicationExtension 13.0, *)
	func provideDeviceOptions(for intent: PowerOnOffIntent, with completion: @escaping ([Roku]?, Error?) -> Void) {
		RokuDeviceParameterResolution.provideDeviceOptions(for: intent, with: completion)
	}
	
	
}

@available(iOSApplicationExtension 12.0, *)
class TypeTextIntentHandler: NSObject, TypeTextIntentHandling {
		
	func handle(intent: TypeTextIntent, completion: @escaping (TypeTextIntentResponse) -> Void) {
		guard let roku = intent.device, let serialNumber = roku.identifier, let text = intent.text else {
			completion(.init(code: .failure, userActivity: nil))
			return
		}
		
		let currentLocation: URL? = {
			if #available(iOSApplicationExtension 13.0, *) {
				return roku.currentLocation
			} else {
				return nil
			}
		}()
		
		rokuDeviceOnCurrentNetwork(withSerialNumber: serialNumber, lastKnownLocation: currentLocation) { device in
			if let device = device {
				device.send(litString: text)
				completion(.init(code: .success, userActivity: nil))
			} else {
				completion(.init(code: .failure, userActivity: nil))
			}
		}
	}
	
	func resolveText(for intent: TypeTextIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
		call(completion) {
			guard let text = intent.text else {
				return .needsValue()
			}
			
			return .success(with: text)
		}
	}
	
	@available(iOSApplicationExtension 13.0, *)
	func resolveDevice(for intent: TypeTextIntent, with completion: @escaping (RokuResolutionResult) -> Void) {
		RokuDeviceParameterResolution.resolveDevice(for: intent, with: completion)
	}
	
	@available(iOSApplicationExtension 13.0, *)
	func provideDeviceOptions(for intent: TypeTextIntent, with completion: @escaping ([Roku]?, Error?) -> Void) {
		RokuDeviceParameterResolution.provideDeviceOptions(for: intent, with: completion)
	}
	
	
}
