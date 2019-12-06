//
//  SeriesViewController.swift
//  Sim Radio
//

import UIKit

class SeriesViewController: UIViewController {
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
        showContextMenu(series: series)
    }
}

extension SeriesViewController {
    @IBAction func add(_ sender: Any) {
        showAddSeiesDialog()
    }

    func showContextMenu(series: Series) {
        guard let appearance = series.appearance else { return }

        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

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

        alertController.addAction(playAction)
        alertController.addAction(deleteAction)
        alertController.addAction(cancelAction)

        let popPresenter = alertController.popoverPresentationController
        popPresenter?.sourceView = view
        alertController.pruneNegativeWidthConstraints()
        alertController.view.tintColor = .systemPink
        present(alertController, animated: true, completion: nil)
    }

    func showAddSeiesDialog() {
        let alertController = UIAlertController(title: "Add radio stations",
                                                message: "Enter URL of series.json file",
                                                preferredStyle: .alert)
        alertController.addTextField { $0.placeholder = "URL" }
        alertController.addAction(UIAlertAction(title: "Enter", style: .default) { _ in
            guard let url = URL(string: alertController.textFields![0].text ?? "") else {
                return
            }
            self.radio.library.downloadSeriesFrom(url: url)
        })
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alertController.view.tintColor = .systemPink
        self.present(alertController, animated: true, completion: nil)
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
