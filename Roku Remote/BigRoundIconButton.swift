//
//  BigRoundIconButton.swift
//  Countdowns
//
//  Created by Josh Birnholz on 10/3/19.
//  Copyright © 2019 Joshua Birnholz. All rights reserved.
//

import UIKit

@IBDesignable public class BigRoundIconButton: UIControl {

	private var contentView: UIView!
	@IBOutlet public weak var imageView: UIImageView! {
		didSet {
			updateImage()
		}
	}
	@IBOutlet public weak var label: UILabel!
	@IBOutlet private weak var stackView: UIStackView!
	@IBOutlet weak var imageViewProportionalHeightConstraint: NSLayoutConstraint!
	
	public enum Style {
		case opaque
		case transparent
	}
	
	public var style: Style = .transparent {
		didSet {
			updateTextColor()
			updateBackgroundColor()
		}
	}
	
	/// The image to be shown on the button.
	@IBInspectable public var image: UIImage? {
		get {
			return imageView.image
		}
		set {
			imageView.image = newValue
			invalidateIntrinsicContentSize()
		}
	}
	
	/// The text to be shown on the button.
	@IBInspectable public var text: String? {
		get {
			return label.text
		}
		set {
			label.text = newValue
			invalidateIntrinsicContentSize()
		}
	}
	
	/// If true, the button's tint color will be used as the background color, and the text will appear white. Otherwise, a transparent version of the tint color will be used for the background color, and the text will be the tint color.
	@IBInspectable var hasOpaqueBackground: Bool {
		get {
			return style == .opaque
		}
		set {
			style = newValue ? .opaque : .transparent
		}
	}
	
	/// If true, the button and image will appear centered in the button. Otherwise, they will appear aligned to the leading edge.
	@IBInspectable var isCentered: Bool {
		get {
			return stackView.alignment == .center
		}
		set {
			stackView.alignment = newValue ? .center : .leading
		}
	}
	
	/// If true, the image view will be hidden when its image is nil. If the button's alignment is centered, this will allow the text to be completely centered in the button. Otherwise, the text will be centered horizontally but will be aligned to the bottom of the button vertically.
	@IBInspectable var hidesImageWhenNil: Bool = false {
		didSet {
			updateImage()
		}
	}
	
	/// The point size of the font used for the label. The default value is 16.0.
	@IBInspectable var fontPointSize: CGFloat {
		get {
			return label.font.pointSize
		}
		set {
			let descriptor = label.font.fontDescriptor
			label.font = UIFont(descriptor: descriptor, size: newValue)
			invalidateIntrinsicContentSize()
		}
	}
	
	/// The proportion of the image view's height to the total height of the button. The default value is 0.4.
	@IBInspectable var imageViewHeightProportion: CGFloat {
		get {
			return imageViewProportionalHeightConstraint.multiplier
		}
		set {
			imageViewProportionalHeightConstraint = imageViewProportionalHeightConstraint.setMultiplier(multiplier: newValue)
			invalidateIntrinsicContentSize()
		}
	}
	
	private func updateImage() {
		if hidesImageWhenNil {
			imageView.isHidden = imageView.image == nil
		}
		invalidateIntrinsicContentSize()
	}
	
	override init(frame: CGRect) {
		super.init(frame: frame)
		commonInit()
	}
	
	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
		commonInit()
	}
	
	private func commonInit() {
		let bundle = Bundle(for: type(of: self))
		let nib = UINib(nibName: "BigRoundIconButton", bundle: bundle)
		contentView = nib.instantiate(withOwner: self, options: nil).first as? UIView
		contentView.frame = bounds
		contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		
		contentView.layer.cornerRadius = 10
		contentView.layer.masksToBounds = true
		
		addSubview(contentView)
	}
	
	private func updateBackgroundColor() {
		switch style {
		case .opaque:
			contentView.backgroundColor = tintColor
		case .transparent:
			contentView.backgroundColor = tintColor.withAlphaComponent(0.1)
		}
	}
	
	private func updateTextColor() {
		switch style {
		case .opaque:
			label.textColor = .white
		case .transparent:
			label.textColor = tintColor
		}
	}
	
	override public func tintColorDidChange() {
		super.tintColorDidChange()
		
		updateTextColor()
		updateBackgroundColor()
		imageView.tintColor = tintColor
	}
	
	override public func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
		super.traitCollectionDidChange(previousTraitCollection)
		
		if #available(iOS 13.0, *) {
			if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
				updateBackgroundColor()
			}
		}
	}
	
	public override var intrinsicContentSize: CGSize {
		var size = stackView.intrinsicContentSize
		size.height += 16
		size.width += 16
		return size
	}
	
	override public var isHighlighted: Bool {
		didSet {
			self.alpha = self.isHighlighted ? 0.6 : 1.0
		}
	}
	
	public override var isEnabled: Bool {
		get {
			return isUserInteractionEnabled
		}
		set {
			isUserInteractionEnabled = newValue
			self.alpha = isEnabled ? 1.0 : 0.5
		}
	}
	
	public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
		// set highlighted
		isHighlighted = true
		sendActions(for: .touchDown)
	}
	
	public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
		sendActions(for: .touchDragInside)
	}
	
	public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
		sendActions(for: .touchCancel)
		UIView.animate(withDuration: 0.25) {
			self.isHighlighted = false
		}
	}
	
	public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
		sendActions(for: .touchUpInside)
		UIView.animate(withDuration: 0.25) {
			self.isHighlighted = false
		}
	}
	
	/*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */

}

fileprivate extension NSLayoutConstraint {
    /**
     Change multiplier constraint

     - parameter multiplier: CGFloat
     - returns: NSLayoutConstraint
    */
    func setMultiplier(multiplier:CGFloat) -> NSLayoutConstraint {

        NSLayoutConstraint.deactivate([self])

        let newConstraint = NSLayoutConstraint(
            item: firstItem,
            attribute: firstAttribute,
            relatedBy: relation,
            toItem: secondItem,
            attribute: secondAttribute,
            multiplier: multiplier,
            constant: constant)

        newConstraint.priority = priority
        newConstraint.shouldBeArchived = self.shouldBeArchived
        newConstraint.identifier = self.identifier

        NSLayoutConstraint.activate([newConstraint])
        return newConstraint
    }
}
