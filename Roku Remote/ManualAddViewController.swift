//
//  ManualAddViewController.swift
//  Roku Remote
//
//  Created by Josh Birnholz on 10/26/19.
//  Copyright © 2019 Josh Birnholz. All rights reserved.
//

import UIKit
import MessageUI
import RokuKit
import WatchConnectivity

class ManualAddViewController: UIViewController {

	@IBOutlet var activityIndicator: UIActivityIndicatorView!
	@IBOutlet weak var textField: UITextField!
	
	let encoder = PropertyListEncoder()
	@IBOutlet var toolbar: UIToolbar!
	@IBOutlet weak var addButton: UIBarButtonItem!
	
	override func viewDidLoad() {
        super.viewDidLoad()
		
		if #available(iOS 13.0, *) {
			navigationController?.navigationBar.standardAppearance.configureWithTransparentBackground()
		}
		
		textField.inputAccessoryView = toolbar
		textField.becomeFirstResponder()
		
		navigationItem.leftBarButtonItem = UIBarButtonItem(customView: activityIndicator)
//		toolbar.items?.insert(UIBarButtonItem(customView: activityIndicator), at: 0)
		
		if #available(iOS 13.0, *) {
			updateActivityIndicatorColor()
		}
    }
	
	@available(iOS 13.0, *)
	private func updateActivityIndicatorColor() {
		activityIndicator.style = traitCollection.userInterfaceStyle == .dark ? .white : .gray
	}
	
	override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
		super.traitCollectionDidChange(previousTraitCollection)
		
		if #available(iOS 13.0, *) {
			if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
				updateActivityIndicatorColor()
			}
		}
	}
    
	@IBAction func cancelButtonPressed(_ sender: Any) {
		dismiss(animated: true, completion: nil)
	}
	
	@IBAction func addButtonPressed(_ sender: Any) {
		guard let input = textField.text, !input.isEmpty, let url = URL(string: "http://\(input):8060/") else {
			self.showAlert(title: "A device couldn't be reached at that address.", message: nil)
			return
		}
		
		activityIndicator.startAnimating()
		addButton.isEnabled = false
		RokuDevice.create(from: url) { result in
			do {
				let device = try result.get()
				self.sendDevice(device)
				
				if !Global.foundDevices.contains(device) {
					Global.foundDevices.append(device)
				}
				
			} catch let error as RokuDevice.CreationError {
				self.showAlert(title: "A device couldn't be reached at that address.", message: nil, deviceData: error.data)
			} catch {
				self.showAlert(title: "A device couldn't be reached at that address.", message: nil)
			}
		}
	}
	
	func showAlert(title: String?, message: String?, deviceData: Data? = nil) {
		guard Thread.isMainThread else { DispatchQueue.main.sync {
			self.showAlert(title: title, message: message)
			}; return }
		
		let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
		let okAction = UIAlertAction(title: "OK", style: .cancel, handler: nil)
		alert.addAction(okAction)
		
		if let data = deviceData, MFMailComposeViewController.canSendMail() {
			let reportAction = UIAlertAction(title: "Send Error Log", style: .default) { _ in
				let composer = MFMailComposeViewController()
				composer.mailComposeDelegate = self
				
				composer.setToRecipients(["josh@birnholz.com"])
				composer.setSubject("Remoku Add Device Error Log")
				composer.addAttachmentData(data, mimeType: "text/xml", fileName: "device-info.xml")
				
				self.present(composer, animated: true, completion: nil)
			}
			
			alert.addAction(reportAction)
		}
		
		self.present(alert, animated: true)
		activityIndicator.stopAnimating()
		addButton.isEnabled = true
	}
	
	func sendDevice(_ device: RokuDevice) {
		do {
			let data = try encoder.encode(device)
			WCSession.default.sendMessage(["command": "foundDevice", "device": data], replyHandler: nil, errorHandler: { error in
				let error = error as NSError
				print(error)
				
				let message: String? = {
					guard let error = error as? WCError else { return nil }
					switch error.code {
					case .genericError:
						return nil
					case .sessionNotSupported:
						return "This device does not support pairing an Apple Watch."
					case .sessionMissingDelegate:
						return nil
					case .deviceNotPaired:
						return "There is no Apple Watch paired with this device."
					case .watchAppNotInstalled:
						return "Remoku is not installed on your Apple Watch. Open the Watch App on your iPhone to install it."
					case .notReachable, .sessionNotActivated:
						return "Apple Watch is not reachable. Make sure Remoku is open on your watch and try again."
					case .invalidParameter:
						return nil
					case .payloadTooLarge:
						return nil
					case .payloadUnsupportedTypes:
						return nil
					case .messageReplyFailed:
						return nil
					case .messageReplyTimedOut:
						return nil
					case .fileAccessDenied:
						return nil
					case .deliveryFailed:
						return nil
					case .insufficientSpace:
						return "There was not enough free space."
					case .sessionInactive:
						return "Try closing and re-opening Remoku on your phone and on your watch."
					case .transferTimedOut:
						return "The transfer timed out."
					case .companionAppNotInstalled:
						return nil
					case .watchOnlyApp:
						return nil
					@unknown default:
						return nil
					}
				}()
				
				self.showAlert(title: "The device information could not be sent to your Apple Watch.", message: message)
			})
			activityIndicator.stopAnimating()
			addButton.isEnabled = true
		} catch {
			self.showAlert(title: "The device information could not be sent to your Apple Watch.", message: nil)
		}
		
	}
	
//	func displayAddAlert() {
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
//	}
	
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}

extension ManualAddViewController: MFMailComposeViewControllerDelegate {
	func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
		dismiss(animated: true, completion: nil)
	}
}
