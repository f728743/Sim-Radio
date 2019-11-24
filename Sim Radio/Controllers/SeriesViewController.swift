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
        radio.library.addObserver(self)
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
//        self.radio.downloader.download(urlString:"")
    }

    func showURLInputDialog() {
        let alertController = UIAlertController(title: "Add radio station",
                                                message: "Enter station or series URL",
                                                preferredStyle: .alert)
        alertController.addTextField { (textField) in
            textField.placeholder = "URL"
        }
        let confirmAction = UIAlertAction(title: "Enter", style: .default) { (_) in
            guard let url = URL(string: "https://raw.githubusercontent.com/tmp-acc/" +
                "GTA-V-Radio-Stations-TestDownload/master/series.json") else {
                    return
            }

//            guard let url = URL(string: "https://raw.githubusercontent.com/tmp-acc/" +
//            "GTA-V-Radio-Stations/master/series.json") else {
//                    return
//            }
            self.radio.library.download(url: url)
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (_) in }
        alertController.addAction(confirmAction)
        alertController.addAction(cancelAction)
        self.present(alertController, animated: true, completion: nil)
    }
}

extension SeriesViewController: MediaLibraryObserver {
    func mediaLibrary(didUpdateItemsOfMediaLibrary: MediaLibrary) {
        seriesCollectionView.reloadData()
    }

    func mediaLibrary(mediaLibrary: MediaLibrary,
                      didUpdateDownloadProgress fractionCompleted: Double,
                      of station: Station,
                      of series: Series) {}
}
