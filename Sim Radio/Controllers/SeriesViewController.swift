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
//        showURLInputDialog()
        showContextMenu(item: radio.library.items[0])
    }

    func showContextMenu(item: LibraryItem) {
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)


        let playAction = UIAlertAction(title: "", style: .default, handler: nil)
        let headerItem = PopMenuHeaderViewController()
        headerItem.logoImageView.image = UIImage(named: "Cover Artwork")
        headerItem.label.text = "Radiostation name"
        playAction.setValue(headerItem, forKey: "contentViewController")

        let deleteAction = UIAlertAction(title: "", style: .default, handler: nil)
        let deleteItem = PopMenuItemViewController()
        deleteItem.logoImageView.image = UIImage(named:"Trash")
        deleteItem.label.text = "Delete from Library"
        deleteItem.label.textColor = .systemPink
        deleteAction.setValue(deleteItem, forKey: "contentViewController")

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        cancelAction.setValue(UIColor.systemPink, forKey: "titleTextColor")

        alertController.addAction(playAction)
        alertController.addAction(deleteAction)
        alertController.addAction(cancelAction)

        alertController.pruneNegativeWidthConstraints()


//        let popPresenter = alertController.popoverPresentationController
//        popPresenter?.sourceView = view
        present(alertController, animated: true, completion: nil)
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



extension UIAlertController {
    func pruneNegativeWidthConstraints() {
        for subView in self.view.subviews {
            for constraint in subView.constraints where constraint.debugDescription.contains("width == - 16") {
                subView.removeConstraint(constraint)
            }
        }
    }
}
