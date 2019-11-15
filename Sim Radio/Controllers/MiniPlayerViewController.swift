//
//  MiniPlayerViewController.swift
//  Sim Radio
//

import UIKit

protocol MiniPlayerDelegate: class {
    func expand()
}

class MiniPlayerViewController: UIViewController {
    let artCornerRadius: CGFloat = 3

    weak var radio: Radio!
    weak var delegate: MiniPlayerDelegate?

    // MARK: - IBOutlets

    @IBOutlet weak var artImageView: UIImageView!
    @IBOutlet weak var artBackgroundView: UIView!
    @IBOutlet weak var stationTitle: UILabel!
    @IBOutlet weak var playOrPauseButton: UIButton!
    @IBOutlet weak var fastForwardButton: UIButton!

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        radio.addObserver(self)

        artImageView.layer.cornerRadius = artCornerRadius
        artImageView.layer.borderWidth = 0.2
        artImageView.layer.borderColor = UIColor(white: 0, alpha: 0.3).cgColor
        artImageView.clipsToBounds = true

        artBackgroundView.layer.cornerRadius = artCornerRadius
        artBackgroundView.clipsToBounds = true
        artBackgroundView.backgroundColor = UIColor(white: 0.95, alpha: 1)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configure()
    }

    func configure() {
        configureDisplay()
        configureButtons()
    }

    func configureButtons() {
        switch radio.playPauseButtonState {
        case .play:
            playOrPauseButton.setImage(UIImage(named: "Mini Play"), for: .normal)
        case .pause:
            playOrPauseButton.setImage(UIImage(named: "Mini Pause"), for: .normal)
        }
        fastForwardButton.isEnabled = radio.switchStarionEnabled
    }

    func configureDisplay() {
        let display = radio.display
        stationTitle.text = display.title
        artImageView.image = display.logo
    }
}

extension MiniPlayerViewController: RadioObserver {
    func radio(_ raio: Radio, didStartPlaying station: Station) {
        configure()
    }

    func radio(_ raio: Radio, didPausePlaybackOf station: Station) {
        configure()
    }

    func radioDidStop(_ radio: Radio) {
        configure()
    }
}

// MARK: - IBActions

extension MiniPlayerViewController {
    @IBAction func tapGesture(_ sender: Any) {
        delegate?.expand()
    }

    @IBAction func fastForward(_ sender: UIButton) {
        radio.nextStation()
    }

    @IBAction func playOrPause(_ sender: UIButton) {
        radio.togglePausePlay()
    }
}

extension MiniPlayerViewController: PlayerCardSourceProtocol {
    var artFrame: CGRect {
        return artImageView.frame
    }

    func viewSnapshot(withArt: Bool) -> UIImage? {
        if !withArt {
            artImageView.alpha = 0
        }
        let res = view.makeSnapshot()
        artImageView.alpha = 1
        return res
    }
}
