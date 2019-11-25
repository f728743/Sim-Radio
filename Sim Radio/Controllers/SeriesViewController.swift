//
//  SeriesViewController.swift
//  Sim Radio
//

import UIKit

class SeriesViewController: UIViewController, SeriesCollectionViewDelegate {
    weak var radio: Radio!
    private var seriesCollectionView = SeriesCollectionView()

    override func viewDidLoad() {
        super.viewDidLoad()
        radio.library.addObserver(seriesCollectionView)
        view.addSubview(seriesCollectionView)

        seriesCollectionView.library = radio.library
        seriesCollectionView.libraryDelegate = self

        seriesCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        seriesCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        seriesCollectionView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        seriesCollectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showStations" {
            if let vc = segue.destination as? StationsViewController {
                if let series = sender as? Series {
                    vc.radio = radio
                    vc.series = series
                }
            }
        }
    }

    func seriesCollectionView(_ seriesCollectionView: SeriesCollectionView, didSelectSeries series: Series) {
        performSegue(withIdentifier: "showStations", sender: series)
    }
}

extension SeriesViewController {
    @IBAction func add(_ sender: Any) {
        showURLInputDialog()
    }

    func showURLInputDialog() {
        let alertController = UIAlertController(title: "Add radio station",
                                                message: "Enter station or series URL",
                                                preferredStyle: .alert)
        alertController.addTextField { $0.placeholder = "URL" }
        alertController.addAction(UIAlertAction(title: "Enter", style: .default) { _ in
            guard let url = URL(string: alertController.textFields![0].text ?? "") else {
                return
            }
            self.radio.library.download(url: url)
        })
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        self.present(alertController, animated: true, completion: nil)
    }
}
