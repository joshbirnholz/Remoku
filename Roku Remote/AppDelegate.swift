//
//  AppDelegate.swift
//  Roku Remote
//
//  Created by Josh Birnholz on 10/7/18.
//  Copyright © 2018 Josh Birnholz. All rights reserved.
//

import UIKit
import WatchConnectivity
import Intents
import RokuKit
import Roku_Remote_Intents

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

	var window: UIWindow?

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
		// Override point for customization after application launch.
		
		WCSession.default.delegate = self
		WCSession.default.activate()
		
		let color: UIColor = {
			let fallback = #colorLiteral(red: 0.579785943, green: 0.2620254457, blue: 0.8419471383, alpha: 1)
			if #available(iOS 11.0, *) {
				return UIColor(named: "AppTint") ?? fallback
			} else {
				return fallback
			}
		}()
		
		window?.tintColor = color
		
//		if #available(iOS 12.0, *) {
//			donateButtons()
//		}
		
		return true
	}
	
//	@available(iOS 12.0, *)
//	func donateButtons() {
//		let intent = PressButtonIntent()
//
//		let interaction = INInteraction(intent: intent, response: nil)
//		interaction.donate { (error) in
//			if let error = error {
//				print("Error donating interaction:", error)
//			} else {
//				print("Donated interaction")
//			}
//		}
//	}

	func applicationWillResignActive(_ application: UIApplication) {
		// Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
		// Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
	}

	func applicationDidEnterBackground(_ application: UIApplication) {
		// Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
		// If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
	}

	func applicationWillEnterForeground(_ application: UIApplication) {
		// Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
	}

	func applicationDidBecomeActive(_ application: UIApplication) {
		// Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
	}

	func applicationWillTerminate(_ application: UIApplication) {
		// Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
	}

}

extension AppDelegate: WCSessionDelegate {
	func sessionDidBecomeInactive(_ session: WCSession) {
		NotificationCenter.default.post(name: .WCSessionDidBecomeInactive, object: session, userInfo: nil)
	}
	
	func sessionDidDeactivate(_ session: WCSession) {
		NotificationCenter.default.post(name: .WCSessionDidDeactivate, object: session, userInfo: nil)
	}
	
	func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
		NotificationCenter.default.post(name: .WCSessionActivationDidComplete, object: session, userInfo: ["activationState": activationState, "error": error as Any])
	}
	
	func session(_ session: WCSession, didReceive file: WCSessionFile) {
		NotificationCenter.default.post(name: .WCSessionDidReceiveFile, object: session, userInfo: ["file": file])
	}
	
	func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
		NotificationCenter.default.post(name: .WCSessionDidReceiveMessage, object: session, userInfo: message)
		
		if let command = message["command"] as? String, command == "search" {
			class FinderDelegate: NSObject, RokuDeviceDiscovererDelegate {
				static let encoder = PropertyListEncoder()
				static var instanceIsSearching = false

				func rokuDeviceDiscoverer(_ rokuDeviceDiscoverer: RokuDeviceDiscoverer, didFind device: RokuDevice) {
					print("Request from watch -- Found device")
					do {
						let data = try FinderDelegate.encoder.encode(device)
						WCSession.default.sendMessage(["command": "foundDevice", "device": data], replyHandler: nil, errorHandler: { error in
							print(#function, error)
						})
					} catch {
						print(#function, error)
					}
					
				}

				func rokuDeviceDiscovererDidStopSearching(_ rokuDeviceDiscoverer: RokuDeviceDiscoverer) {
					FinderDelegate.instanceIsSearching = false
				}

				deinit {
					print("Finder delegate deinit")
				}
			}
			
			guard !FinderDelegate.instanceIsSearching else { return }
			let finderDelegate = FinderDelegate()
			let finder = RokuDeviceDiscoverer()
			finder.delegate = finderDelegate
			finder.startSearching(timeout: 25)
			FinderDelegate.instanceIsSearching = true
			
			DispatchQueue.main.asyncAfter(deadline: .now() + 25) {
				finder.stopSearching()
				let _ = finderDelegate // capture it to keep it alive
			}
		}
	}
	
	func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
		NotificationCenter.default.post(name: .WCSessionDidReceiveApplicationContext, object: session, userInfo: applicationContext)
	}
	
	func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
		
		if let command = message["command"] as? String, command == "device" {
			do {
				let devicesData = try Data(contentsOf: preferencesURL)

				replyHandler(["devices": devicesData])

			} catch {
				replyHandler(["error": error.localizedDescription])
			}
		}
	}
	
//	func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
//
//		class FinderDelegate: NSObject, RokuDeviceDiscovererDelegate {
//			var replyHandler: ([String: Any]) -> ()
//			var devices: [RokuDevice] = []
//
//			static let encoder = PropertyListEncoder()
//
//			init(replyHandler: @escaping ([String: Any]) -> ()) {
//				self.replyHandler = replyHandler
//				super.init()
//			}
//
//			func rokuDeviceDiscoverer(_ rokuDeviceDiscoverer: RokuDeviceDiscoverer, didFind device: RokuDevice) {
//				devices.append(device)
//			}
//
//			func rokuDeviceDiscovererDidStopSearching(_ rokuDeviceDiscoverer: RokuDeviceDiscoverer) {
//				do {
//					let data = try FinderDelegate.encoder.encode(devices)
//					replyHandler(["data": data])
//				} catch {
//					replyHandler(["error": error.localizedDescription])
//				}
//			}
//
//
//		}
//
//		let finderDelegate = FinderDelegate(replyHandler: replyHandler)
//		let finder = RokuDeviceDiscoverer()
//		finder.delegate = finderDelegate
//		finder.startSearching(timeout: 10)
//	}
}
