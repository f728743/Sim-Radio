//
//  PlayerCardViewController.swift
//  Sim Radio
//

import AVKit
import MediaPlayer
import UIKit

protocol PlayerCardSourceProtocol: AnyObject {
    var artFrame: CGRect { get }
    func viewSnapshot(withArt: Bool) -> UIImage?
}

class PlayerCardViewController: UIViewController {
    private lazy var routePickerView: AVRoutePickerView = {
        let routePickerView = AVRoutePickerView(frame: .zero)
        routePickerView.isHidden = true
        view.addSubview(routePickerView)
        return routePickerView
    }()

    let maxArtCornerRadius: CGFloat = 10
    let minArtCornerRadius: CGFloat = 3
    let shadowAlphaZommedIn: CGFloat = 0.3
    let shadowAlphaZommedOut: CGFloat = 0.1
    var transitionDuration: TimeInterval = 0.6
    let artZoomTransitionDuration: TimeInterval = 1.5

    @IBOutlet weak var artViewLeadingInset: NSLayoutConstraint!
    @IBOutlet weak var artViewTrailingInset: NSLayoutConstraint!
    @IBOutlet weak var artViewTopInset: NSLayoutConstraint!

    @IBOutlet weak var artImageLeadingInset: NSLayoutConstraint!
    @IBOutlet weak var artImageTrailingInset: NSLayoutConstraint!
    @IBOutlet weak var artImageTopInset: NSLayoutConstraint!
    @IBOutlet weak var artImageBottomInset: NSLayoutConstraint!

    @IBOutlet weak var artImageView: UIImageView!
    @IBOutlet weak var artColorfulShadowImageView: UIImageView!
    @IBOutlet weak var artShadowView: UIView!
    @IBOutlet weak var artBackgroundView: UIView!

    @IBOutlet weak var visualEffectView: UIVisualEffectView!

    @IBOutlet weak var stationTitle: MarqueeLabel!
    @IBOutlet weak var stationInfo: MarqueeLabel!
    @IBOutlet weak var rewindButton: UIButton!
    @IBOutlet weak var playOrPauseButton: UIButton!
    @IBOutlet weak var fastForwardButton: UIButton!
    @IBOutlet weak var volumeSlider: MPVolumeView!  // only works on an actual device, invisible in simulator 🙂

    @IBOutlet weak var miniPlayerImageView: UIImageView!

    @IBOutlet weak var miniPlayerHeight: NSLayoutConstraint!
    @IBOutlet weak var cardCanvasHeight: NSLayoutConstraint!
    weak var sourceView: PlayerCardSourceProtocol!
    var backingImage: UIImage?
    var miniPlayerImage: UIImage?
    weak var radio: Radio!

    var controlsAlpha: CGFloat = 1.0 {
        didSet {
            stationTitle.alpha = controlsAlpha
            stationInfo.alpha = controlsAlpha
            rewindButton.alpha = controlsAlpha
            playOrPauseButton.alpha = controlsAlpha
            fastForwardButton.alpha = controlsAlpha
        }
    }

    var lightStatusBar: Bool = false

    var artImageZoomedIn: Bool = true {
        didSet {
            let inset: CGFloat = artImageZoomedIn ? 0 : 35
            artImageLeadingInset.constant = inset
            artImageTrailingInset.constant = inset
            artImageTopInset.constant = inset
            artImageBottomInset.constant = inset
            view.layoutIfNeeded()
        }
    }

    var artImageHasShadow: Bool = true {
        didSet {
            let value = artImageHasShadow ? shadowAlphaZommedIn : shadowAlphaZommedOut
            artShadowView.alpha = value
            artColorfulShadowImageView.alpha = value
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return self.lightStatusBar ? .lightContent : .default
    }

    // MARK: - View Life Cycle

    override func awakeFromNib() {
        super.awakeFromNib()
        modalPresentationCapturesStatusBarAppearance = true
        modalPresentationStyle = .overFullScreen // dont dismiss the presenting view controller when presented
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        radio.addObserver(self)
        modalPresentationCapturesStatusBarAppearance = true
        miniPlayerImageView.image = miniPlayerImage
        configureArtImage()

        miniPlayerHeight.constant = MiniPlayerConstants.fullHeight
        volumeSlider.tintColor = .gray
        volumeSlider.showsRouteButton = false

        let topInsets = UIApplication.shared.statusBarFrame.height + 13 + 32 + (UIScreen.main.bounds.width - 32 * 2)
        let bottomInsets = MiniPlayerConstants.safeAreaBottomInsets + 20
        cardCanvasHeight.constant = UIScreen.main.bounds.height - (topInsets + bottomInsets)
    }

    func configureArtImage() {
        artColorfulShadowImageView.layer.cornerRadius = maxArtCornerRadius
        artColorfulShadowImageView.clipsToBounds = true

        artShadowView.layer.cornerRadius = maxArtCornerRadius
        artShadowView.clipsToBounds = true

        artImageView.layer.cornerRadius = maxArtCornerRadius
        artImageView.layer.borderWidth = 1 / UIScreen.main.scale
        artImageView.layer.borderColor = UIColor(white: 0, alpha: 0.3).cgColor
        artImageView.clipsToBounds = true

        artBackgroundView.layer.cornerRadius = maxArtCornerRadius
        artBackgroundView.clipsToBounds = true
        artBackgroundView.backgroundColor = UIColor(white: 0.95, alpha: 1)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        artImageView.image = radio.display.logo
        artColorfulShadowImageView.image = radio.display.logo
        artImageView.layer.cornerRadius = minArtCornerRadius
        artBackgroundView.layer.cornerRadius = minArtCornerRadius

        miniPlayerImageView.image = sourceView.viewSnapshot(withArt: false)
        configureControls()

        configurePlayerCardInStartPosition()
        view.layoutIfNeeded()
        miniPlayerImageView.alpha = 1
        controlsAlpha = 0

        animatePlayerCardIn()
    }

    override func viewWillDisappear(_ animated: Bool) {
        miniPlayerImageView.image = sourceView.viewSnapshot(withArt: false)
        animatePlayerCardOut()
    }

    func configureControls() {
        let display = radio.display
        stationTitle.text = display.title
        stationInfo.text = ""
        if let genre = display.genre {
            stationInfo.text = genre
            if let dj = display.dj {
                stationInfo.text = "Hosted by \(dj) — \(genre)"
            }
        } else {
            stationInfo.text = " "
        }

        switch radio.playPauseButtonState {
        case .play:
            playOrPauseButton.setImage(UIImage(named: "Play"), for: .normal)
        case .pause:
            playOrPauseButton.setImage(UIImage(named: "Pause"), for: .normal)
        }
        view.layoutIfNeeded()
        fastForwardButton.isEnabled = radio.switchStarionEnabled
        rewindButton.isEnabled = radio.switchStarionEnabled
    }
}

// MARK: - IBActions

extension PlayerCardViewController {
    @IBAction func rewind(_ sender: Any) {
        radio.previousStation()
    }

    @IBAction func playOrPause(_ sender: Any) {
        radio.togglePausePlay()
    }

    @IBAction func fastForward(_ sender: Any) {
        radio.nextStation()
    }

    @IBAction func pickPlaybackRoute(_ sender: Any) {
        let routePickerButton = routePickerView.subviews.first(where: { $0 is UIButton }) as? UIButton
        routePickerButton?.sendActions(for: .touchUpInside)
    }
}

extension PlayerCardViewController: RadioObserver {
    func radio(_ raio: Radio, didStartPlaying station: Station) {
        artImageView.image = station.logo
        artColorfulShadowImageView.image = station.logo
        configureControls()
        animateArtZoomIn()
    }

    func radio(_ radio: Radio, didPausePlaybackOf station: Station) {
        artImageView.image = station.logo
        artColorfulShadowImageView.image = station.logo
        configureControls()
        animateArtZoomOut()
    }
}

// MARK: Player card animation

extension PlayerCardViewController {
    private func configurePlayerCardInStartPosition() {
        let miniPlayerImageFrame = sourceView.artFrame
        artViewLeadingInset.constant = miniPlayerImageFrame.minX
        artViewTopInset.constant = miniPlayerImageFrame.minY
        artViewTrailingInset.constant = view.frame.width - (miniPlayerImageFrame.minX + miniPlayerImageFrame.width)
    }

    func animatePlayerCardIn() {
        UIView.animate(withDuration: transitionDuration / 2.0, delay: transitionDuration / 2.0,
                       options: [.curveEaseIn], animations: {
                        self.controlsAlpha = 1
        })

        UIView.animate(withDuration: transitionDuration / 3.0, delay: 0,
                       usingSpringWithDamping: 1, initialSpringVelocity: 1,
                       options: [.curveEaseIn], animations: {
                        self.miniPlayerImageView.alpha = 0
        })

        UIView.animate(withDuration: transitionDuration, delay: 0,
                       usingSpringWithDamping: 1, initialSpringVelocity: 1,
                       options: [.curveEaseIn], animations: {
                        self.artViewLeadingInset.constant = 32
                        self.artViewTopInset.constant = 32
                        self.artViewTrailingInset.constant = 32
                        self.artImageZoomedIn = self.radio.playPauseButtonState == .pause
                        self.artImageHasShadow = self.radio.playPauseButtonState == .pause
                        self.view.layoutIfNeeded()
        })

        artImageView.addCornerRadiusAnimation(cornerRadius: maxArtCornerRadius, duration: transitionDuration)
        artBackgroundView.addCornerRadiusAnimation(cornerRadius: maxArtCornerRadius, duration: transitionDuration)

        UIView.animate(withDuration: transitionDuration, delay: 0,
                       usingSpringWithDamping: 1, initialSpringVelocity: 1,
                       options: [.curveEaseIn], animations: {
                        self.lightStatusBar = true
                        self.setNeedsStatusBarAppearanceUpdate()
        })
    }

    func animatePlayerCardOut() {
        UIView.animate(withDuration: transitionDuration / 2.0, delay: 0,
                       usingSpringWithDamping: 1, initialSpringVelocity: 1,
                       options: [.curveEaseOut], animations: {
                        self.controlsAlpha = 0
        })

        UIView.animate(withDuration: transitionDuration, delay: 0,
                       options: [.curveEaseOut], animations: {
                        self.miniPlayerImageView.alpha = 1
        })

        UIView.animate(withDuration: transitionDuration, delay: 0,
                       usingSpringWithDamping: 1, initialSpringVelocity: 1,
                       options: [.curveEaseOut], animations: {
                        self.configurePlayerCardInStartPosition()
                        self.artImageZoomedIn = true
                        self.artImageHasShadow = false
        })

        artImageView.addCornerRadiusAnimation(cornerRadius: minArtCornerRadius, duration: transitionDuration)
        artBackgroundView.addCornerRadiusAnimation(cornerRadius: minArtCornerRadius, duration: transitionDuration)

        UIView.animate(withDuration: transitionDuration, delay: 0,
                       usingSpringWithDamping: 1, initialSpringVelocity: 1,
                       options: [.curveEaseOut], animations: {
                        self.lightStatusBar = false
                        self.setNeedsStatusBarAppearanceUpdate()
        })
    }

    func animateArtZoomIn() {
        UIView.animate(withDuration: artZoomTransitionDuration, delay: 0,
                       usingSpringWithDamping: 0.7, initialSpringVelocity: 5,
                       options: [.curveEaseIn], animations: {
                        self.artImageZoomedIn = true
                        self.artImageHasShadow = true
        })
    }

    func animateArtZoomOut() {
        UIView.animate(withDuration: artZoomTransitionDuration, delay: 0,
                       usingSpringWithDamping: 0.7, initialSpringVelocity: 5,
                       options: [.curveEaseOut], animations: {
                        self.artImageZoomedIn = false
                        self.artImageHasShadow = false
        })
    }
}
