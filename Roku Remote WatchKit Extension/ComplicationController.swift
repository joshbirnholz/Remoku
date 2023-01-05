//
//  ComplicationController.swift
//  Roku Remote WatchKit Extension
//
//  Created by Josh Birnholz on 10/7/18.
//  Copyright © 2018 Josh Birnholz. All rights reserved.
//

import ClockKit


class ComplicationController: NSObject, CLKComplicationDataSource {
	
	// MARK: - Timeline Configuration
	
	func getSupportedTimeTravelDirections(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimeTravelDirections) -> Void) {
		handler([])
	}
	
	func getCurrentTimelineEntry(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void) {
		let template = blankTemplate(for: complication.family)
		let entry = template.map { CLKComplicationTimelineEntry(date: Date(), complicationTemplate: $0) }
		handler(entry)
	}

    func getPrivacyBehavior(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationPrivacyBehavior) -> Void) {
        handler(.showOnLockScreen)
    }

    // MARK: - Placeholder Templates

    func getLocalizableSampleTemplate(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTemplate?) -> Void) {
        // This method will be called once per supported complication, and the results will be cached
		handler(blankTemplate(for: complication.family))
    }
	
	func blankTemplate(for complicationFamily: CLKComplicationFamily) -> CLKComplicationTemplate? {
		
		let tintColor = #colorLiteral(red: 0.6118611097, green: 0.3240570724, blue: 0.9100784659, alpha: 1)
		let textProvider = CLKSimpleTextProvider(text: "Remoku")
		let emptyTextProvider = CLKSimpleTextProvider(text: "")
		
		switch complicationFamily {
		case .modularSmall:
			let template = CLKComplicationTemplateModularSmallSimpleImage()
			let image = UIImage(named: "Modular")!
			template.imageProvider = CLKImageProvider(onePieceImage: image)
			return template
		case .modularLarge:
			return nil
		case .utilitarianSmall:
			let template = CLKComplicationTemplateUtilitarianSmallSquare()
			template.imageProvider = CLKImageProvider(onePieceImage: UIImage(named: "Utilitarian Small Square")!)
			return template
		case .utilitarianSmallFlat:
			let template = CLKComplicationTemplateUtilitarianSmallFlat()
			template.textProvider = textProvider
			template.tintColor = tintColor
			return template
		case .utilitarianLarge:
			let template = CLKComplicationTemplateUtilitarianLargeFlat()
			template.textProvider = textProvider
			template.tintColor = tintColor
			return template
		case .circularSmall:
			let template = CLKComplicationTemplateCircularSmallSimpleImage()
			template.imageProvider = CLKImageProvider(onePieceImage: UIImage(named: "Circular Small")!)
			template.tintColor = tintColor
			return template
		case .extraLarge:
			let template = CLKComplicationTemplateExtraLargeSimpleImage()
			template.imageProvider = CLKImageProvider(onePieceImage: UIImage(named: "Extra Large")!)
			template.tintColor = tintColor
			return template
		case .graphicCorner:
			if #available(watchOSApplicationExtension 5.0, *) {
				let template = CLKComplicationTemplateGraphicCornerTextImage()
				template.textProvider = textProvider
				template.imageProvider = CLKFullColorImageProvider(fullColorImage: UIImage(named: "Graphic Corner")!)
				template.tintColor = tintColor
				return template
			} else {
				fatalError("This shouldn't be possible")
			}
		case .graphicBezel:
			if #available(watchOSApplicationExtension 5.0, *) {
				let template = CLKComplicationTemplateGraphicBezelCircularText()
				
				template.textProvider = emptyTextProvider
				template.circularTemplate = blankTemplate(for: .graphicCircular) as! CLKComplicationTemplateGraphicCircular
				
				template.tintColor = tintColor
				return template
			} else {
				return nil
			}
		case .graphicCircular:
			if #available(watchOSApplicationExtension 5.0, *) {
				let template = CLKComplicationTemplateGraphicCircularImage()
				let image = #imageLiteral(resourceName: "Graphic Circular")
				template.imageProvider = CLKFullColorImageProvider(fullColorImage: image)
				
				template.tintColor = tintColor
				return template
			} else {
				return nil
			}
		case .graphicRectangular:
			return nil
		@unknown default:
			return nil
		}
	}
    
}
