//
//  ShortcutsableViewController.swift
//  Roku Remote
//
//  Created by Josh Birnholz on 10/26/19.
//  Copyright © 2019 Josh Birnholz. All rights reserved.
//

import UIKit
import RokuKit
import Intents
import Roku_Remote_Intents

@available(iOS 12.0, *)
class ShortcutsTableViewController: UITableViewController {

	let finder = RokuDeviceDiscoverer()
	
	enum IntentModel: Int {
		case powerOn
		case poewrOff
		@available(iOS 13.0, *)
		case openApp
		case playPause
		@available(iOS 13.0, *)
		case typeText
		
		func intent(for device: RokuDevice) -> INIntent {
			let roku = Roku(identifier: device.serialNumber, display: device.friendlyDeviceName)
			if #available(iOS 13.0, *) {
				roku.currentLocation = device.currentLocation
			}
			
			switch self {
			case .powerOn:
				let intent = PowerOnOffIntent()
				intent.device = roku
				intent.powerState = .on
				return intent
			case .poewrOff:
				let intent = PowerOnOffIntent()
				intent.device = roku
				intent.powerState = .off
				return intent
			case .openApp:
				let intent = LaunchAppIntent()
				intent.device = roku
				return intent
			case .playPause:
				let intent = PlayPauseIntent()
				intent.device = roku
				return intent
			case .typeText:
				let intent = TypeTextIntent()
				intent.device = roku
				return intent
			}
		}
	}
	
    override func viewDidLoad() {
        super.viewDidLoad()
		
		finder.delegate = self
		finder.startSearching(timeout: 25)

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
		return Global.foundDevices.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return 1
    }
	
	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		return Global.foundDevices[section].friendlyDeviceName
	}

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DeviceCell", for: indexPath)

		let device = Global.foundDevices[indexPath.section]
		
		cell.textLabel?.text = device.friendlyDeviceName
		cell.detailTextLabel?.text = device.friendlyModelName

        return cell
    }
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		
	}

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}

@available(iOS 12.0, *)
extension ShortcutsTableViewController: RokuDeviceDiscovererDelegate {
	func rokuDeviceDiscoverer(_ rokuDeviceDiscoverer: RokuDeviceDiscoverer, didFind device: RokuDevice) {
		if !Global.foundDevices.contains(device) {
			Global.foundDevices.append(device)
			tableView.reloadData()
		}
	}
	
	func rokuDeviceDiscovererDidStopSearching(_ rokuDeviceDiscoverer: RokuDeviceDiscoverer) {
		
	}
}
