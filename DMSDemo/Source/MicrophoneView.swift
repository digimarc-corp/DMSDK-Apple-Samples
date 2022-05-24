//
//  MicrophoneView.swift
//  DigimarcDiscover
//
//  Created by Cornaby, Colin on 6/28/17.
//

import UIKit

class MicrophoneView: UIView {
    
    let imageView = UIImageView()
    let circleLayer = CAShapeLayer()
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        self.backgroundColor = .clear
        
        self.layer.shadowOpacity = 1.0
        self.layer.shadowRadius = 0.0
        self.layer.shadowColor = UIColor.black.cgColor
        self.layer.shadowOffset = CGSize(width: 1, height: 1)
        
        imageView.image = UIImage(named: "visualizer-mic", in: Bundle.main, compatibleWith: nil)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(imageView)
        self.addConstraints([NSLayoutConstraint(item: imageView, attribute: .centerX, relatedBy: .equal, toItem: self, attribute: .centerX, multiplier: 1.0, constant: 0.0),
                             NSLayoutConstraint(item: imageView, attribute: .centerY, relatedBy: .equal, toItem: self, attribute: .centerY, multiplier: 1.0, constant: 0.0)])
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .clear
        imageView.tintColor = UIColor.white
        
        let path = CGMutablePath()
        path.addEllipse(in: CGRect(x: 10, y: 10, width: 40, height: 40))
        
        circleLayer.path = path
        circleLayer.fillColor = UIColor.clear.cgColor
        circleLayer.strokeColor = UIColor.white.cgColor
        circleLayer.lineWidth = 2.0
        
        circleLayer.frame = self.bounds
        self.layer.addSublayer(self.circleLayer)
    }
    
    override var intrinsicContentSize: CGSize {
        return CGSize(width: 60, height: 60)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.addAnimation()
        self.circleLayer.frame = self.bounds
    }
    
    func addAnimation() {
        circleLayer.removeAllAnimations()
        
        let duration = 3.5
        
        let scaleAnimation = CABasicAnimation()
        scaleAnimation.keyPath = "transform"
        scaleAnimation.fromValue = NSValue(caTransform3D: CATransform3DMakeScale(0.0, 0.0, 1.0))
        scaleAnimation.toValue = NSValue(caTransform3D: CATransform3DMakeScale(1.65, 1.65, 1.0))
        scaleAnimation.duration = duration
        
        let alphaAnimation = CAKeyframeAnimation()
        alphaAnimation.keyPath = "opacity"
        alphaAnimation.values = [
            1.0,
            1.0,
            1.0,
            1.0,
            1.0,
            (1.0/1.5),
            (1.0/3.0),
            0.0,
            0.0
        ]
        alphaAnimation.duration = duration
        
        let animationGroup = CAAnimationGroup()
        animationGroup.animations = [scaleAnimation, alphaAnimation]
        animationGroup.duration = duration
        animationGroup.repeatCount = HUGE
        animationGroup.isRemovedOnCompletion = false
        circleLayer.add(animationGroup, forKey: "audioCircleAnimation")
    }

}
