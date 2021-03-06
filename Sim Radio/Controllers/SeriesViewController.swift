//
//  SeriesViewController.swift
//  Sim Radio
//

import UIKit

class SeriesViewController: UIViewController {
    weak var radio: Radio!
    private var collectionView: SeriesCollectionView = {
        let view = SeriesCollectionView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        radio.library.addObserver(collectionView)
        view.addSubview(collectionView)

        collectionView.library = radio.library
        collectionView.libraryDelegate = self

        collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        collectionView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showStations" {
            guard let vc = segue.destination as? StationsViewController,
                let series = sender as? Series else { return }
            vc.radio = radio
            vc.series = series
        }
    }
}

extension SeriesViewController: SeriesCollectionViewDelegate {
    func seriesCollectionView(_ seriesCollectionView: SeriesCollectionView, didSelectSeries series: Series) {
        performSegue(withIdentifier: "showStations", sender: series)
    }

    func seriesCollectionView(_ seriesCollectionView: SeriesCollectionView,
                              didSelectSeriesWithLongPress series: Series) {
        contextMenu(series: series)
    }
}

extension SeriesViewController {
    @IBAction func add(_ sender: Any) {
        addNewSeies()
    }

    func contextMenu(series: Series) {
        guard let appearance = series.appearance else { return }

        let contextMenu = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        let playAction = UIAlertAction(title: "", style: .default) { _ in
            self.radio.playAnyStationOf(series: series)
        }
        let headerItem = PopMenuHeaderViewController()
        headerItem.logoImageView.image = appearance.logo
        headerItem.label.text = appearance.title
        playAction.setValue(headerItem, forKey: "contentViewController")

        let deleteAction = UIAlertAction(title: "", style: .default) { _ in
            self.radio.library.delete(series: series)
        }
        let deleteItem = PopMenuItemViewController()
        deleteItem.logoImageView.image = UIImage(named: "Trash")
        deleteItem.label.text = "Delete from Library"
        deleteItem.label.textColor = .systemPink
        deleteAction.setValue(deleteItem, forKey: "contentViewController")

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)

        contextMenu.addAction(playAction)
        contextMenu.addAction(deleteAction)
        contextMenu.addAction(cancelAction)

        let popPresenter = contextMenu.popoverPresentationController
        popPresenter?.sourceView = view
        contextMenu.pruneNegativeWidthConstraints()
        contextMenu.view.tintColor = .systemPink
        present(contextMenu, animated: true)
    }

    func addNewSeies() {
        let urlInput = UIAlertController(title: "Add radio stations",
                                         message: "Enter URL of series.json file",
                                         preferredStyle: .alert)
        urlInput.addTextField { $0.placeholder = "URL" }
        urlInput.addAction(UIAlertAction(title: "Enter", style: .default) { _ in
            let urlString = urlInput.textFields![0].text ?? ""
            guard let url = URL(string: urlString) else {
                return
            }
            self.radio.library.downloadSeriesFrom(
                url: url,
                confirmDownloading: { seriesName, downloadSize, confitm in
                    let downloadSizeWithUnit = ByteCountFormatter.string(fromByteCount: downloadSize,
                                                                         countStyle: .file)
                    let confirmation = UIAlertController(title: "Do you want to download?",
                                                         message: "\(seriesName), \(downloadSizeWithUnit)" ,
                        preferredStyle: .alert)
                    confirmation.addAction(UIAlertAction(title: "OK", style: .default) { _ in confitm(true) })
                    confirmation.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in confitm(false) })
                    confirmation.view.tintColor = .systemPink
                    self.present(confirmation, animated: true)
            },
                errorHandler: { _ in
                    let errorMessge = UIAlertController(title: "Error",
                                                        message: "Failed to download series.json",
                                                        preferredStyle: .alert)
                    errorMessge.addAction(UIAlertAction(title: "OK", style: .cancel))
                    errorMessge.view.tintColor = .systemPink
                    self.present(errorMessge, animated: true)
            })
        })
        urlInput.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        urlInput.view.tintColor = .systemPink
        self.present(urlInput, animated: true)
    }
}

// suppress error message from UIAlertController layouts
extension UIAlertController {
    func pruneNegativeWidthConstraints() {
        for subView in self.view.subviews {
            for constraint in subView.constraints where constraint.debugDescription.contains("width == - 16") {
                subView.removeConstraint(constraint)
            }
        }
    }
}
