//
//  LibraryViewController.swift
//  Sim Radio
//

import UIKit

class LibraryViewController: UIViewController, LibraryCollectionViewDelegate {
    weak var radio: Radio!
    private var libraryCollectionView = LibraryCollectionView()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(libraryCollectionView)

        libraryCollectionView.library = radio.library
        libraryCollectionView.libraryDelegate = self

        libraryCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        libraryCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        libraryCollectionView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        libraryCollectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showSeries" {
            if let vc = segue.destination as? SeriesViewController {
                if let series = sender as? Series {
                    vc.radio = radio
                    vc.series = series
                }
            }
        }
    }

    func libraryCollectionView(_ libraryCollectionView: LibraryCollectionView, didSelectSeries series: Series) {
        performSegue(withIdentifier: "showSeries", sender: series)
    }
}

extension LibraryViewController {
    @IBAction func add(_ sender: Any) {
        showURLInputDialog()
//        self.radio.downloader.download(urlString:"")
    }

    func showURLInputDialog() {
        let alertController = UIAlertController(title: "Add radio station", message: "Enter station or series URL", preferredStyle: .alert)
        alertController.addTextField { (textField) in
            textField.placeholder = "URL"
        }
        let confirmAction = UIAlertAction(title: "Enter", style: .default) { (_) in
            guard let url = URL(string: "https://raw.githubusercontent.com/tmp-acc/" +
            "GTA-V-Radio-Stations/master/series.json") else {
                    return
            }
            self.radio.library.download(url: url)
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (_) in }
        alertController.addAction(confirmAction)
        alertController.addAction(cancelAction)
        self.present(alertController, animated: true, completion: nil)
    }
}
