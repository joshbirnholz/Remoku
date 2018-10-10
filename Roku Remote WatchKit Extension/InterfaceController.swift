//
//  InterfaceController.swift
//  Roku Remote WatchKit Extension
//
//  Created by Josh Birnholz on 10/7/18.
//  Copyright © 2018 Josh Birnholz. All rights reserved.
//

import Foundation
import WatchKit
import WatchConnectivity
import RokuKit_Watch

class InterfaceController: WKInterfaceController {
	
	var device: RokuDevice? {
		didSet {
			oldValue?.delegate = nil
		}
	}
	
	let volumeThreshold: Double = 0.1
	
	var rotationAmount: Double = 0.0 {
		didSet {
			guard let device = device else { return }
			let times = Int(rotationAmount/volumeThreshold)
			if times > 0 {
				print(Date(), "Volume up \(times)")
				rotationAmount -= Double(times)*volumeThreshold
				
				for _ in (0 ..< times) {
					device.send(keypress: .VolumeUp)
				}
				WKInterfaceDevice.current().play(.click)
				
				
			} else if times < 0 {
				print(Date(), "Volume down \(times)")
				rotationAmount -= Double(times)*volumeThreshold
				
				for _ in (0 ..< times * -1) {
					device.send(keypress: .VolumeDown)
				}
				WKInterfaceDevice.current().play(.click)
			}
		}
	}
	
	
	let localFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("rokudevice.plist")
	
	@IBOutlet weak var currentAppLabel: WKInterfaceLabel!
	@IBOutlet var currentAppButton: WKInterfaceButton!
	
	fileprivate func loadApps() {
		device?.loadApps {
			DispatchQueue.main.async {
				self.currentAppButton.setEnabled(true)
				self.currentAppLabel.setTextColor(.white)
			}
		}
	}
	
	override func awake(withContext context: Any?) {
        super.awake(withContext: context)
		
		WCSession.default.delegate = self
		WCSession.default.activate()
		
		do {
			try loadSavedDevice()
			
			loadApps()
		} catch {
			print(error.localizedDescription)
		}
    }
	
	override func didAppear() {
		configureDevice()
	}
	
	func configureDevice() {
		if let device = device {
			DispatchQueue.main.async {
				self.setTitle(device.friendlyDeviceName)
			}
			device.getActiveApp { app in
				DispatchQueue.main.async {
					self.currentAppLabel.setText(app?.name)
				}
			}
			device.delegate = self
			
			crownSequencer.delegate = self
			crownSequencer.focus()
		} else {
			DispatchQueue.main.async {
				self.setTitle("Roku Remote")
				self.currentAppLabel.setText("Not Connected")
				
				self.presentAlert(withTitle: "Not Connected", message: "Open the app on your iPhone to connect to a Roku device.", preferredStyle: .alert, actions: [WKAlertAction(title: "OK", style: .default, handler: { })])
			}
			crownSequencer.delegate = nil
			crownSequencer.resignFocus()
		}
		
	}
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
	
	@IBAction func rewindButtonPressed() {
		guard let device = device else { return }
		device.send(keypress: .Back)
	}
	
	@IBAction func playButtonPressed() {
		guard let device = device else { return }
		device.send(keypress: .Play)
	}
	
	@IBAction func fastForwardButtonPressed() {
		guard let device = device else { return }
		device.send(keypress: .Fwd)
	}
	@IBAction func instantReplayButtonPressed() {
		guard let device = device else { return }
		device.send(keypress: .InstantReplay)
	}
	@IBAction func muteButtonPressed() {
		guard let device = device else { return }
		device.send(keypress: .VolumeMute)
	}
	@IBAction func powerMenuItemPressed() {
		guard let device = device else { return }
		device.send(keypress: .Power)
	}
	
	@IBAction func micButtonPressed() {
		guard let device = device else { return }
		
		#if targetEnvironment(simulator)
			device.send(litString: "This Is Us")
		#else
		presentTextInputController(withSuggestions: [], allowedInputMode: .plain) { results in
			if let text = (results?.first as? String) {
				device.send(litString: text)
			}
		}
		#endif
	}
	
	@IBAction func appButtonPressed() {
		guard let device = device, let apps = device.apps, !apps.isEmpty else { return }
		self.pushController(withName: "AppChooser", context: device)
		
	}
	
	@IBAction func remoteButtonPressed() {
		guard let device = device else { return }
		presentController(withName: "Remote", context: device)
	}
	
	func loadSavedDevice() throws {
		guard let localFileURL = localFileURL else { return }
		let data = try Data(contentsOf: localFileURL)
		let device = try PropertyListDecoder().decode(RokuDevice.self, from: data)
		
		self.device = device
		configureDevice()
		loadApps()
	}
}

extension InterfaceController: WCSessionDelegate {
	func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
		
	}
	
	func session(_ session: WCSession, didReceive file: WCSessionFile) {
		guard let localFileURL = localFileURL else { return }
		
		do {
			
			try? FileManager.default.removeItem(at: localFileURL)
			
			try FileManager.default.moveItem(at: file.fileURL, to: localFileURL)
			
			try loadSavedDevice()
			
			if let device = device {
				DispatchQueue.main.async {
					self.presentAlert(withTitle: "Connected to ”\(device.friendlyDeviceName)”", message: nil, preferredStyle: .alert, actions: [WKAlertAction(title: "OK", style: .default, handler: {})])
				}
			}
			
		} catch {
			print(error.localizedDescription)
		}
		
	}
	
}

extension InterfaceController: RokuDeviceDelegate {
	func rokuDevice(_ device: RokuDevice, didLaunch app: RokuDevice.App) {
		self.currentAppLabel.setText(app.name)
		DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + 1) {
			device.getActiveApp { app in
				DispatchQueue.main.async {
					self.currentAppLabel.setText(app?.name)
				}
			}
		}
	}
	
}

extension InterfaceController: WKCrownDelegate {
	
	func crownDidRotate(_ crownSequencer: WKCrownSequencer?, rotationalDelta: Double) {
		rotationAmount += rotationalDelta
	}
	
	func crownDidBecomeIdle(_ crownSequencer: WKCrownSequencer?) {
		rotationAmount = 0
	}
	
}
