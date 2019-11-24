//
//  SeriesCollectionView.swift
//  Sim Radio
//

import UIKit

struct SeriesCollectionViewConstants {
    static let leftDistanceToView: CGFloat = 20
    static let rightDistanceToView: CGFloat = 20
    static let minimumLineSpacing: CGFloat = 20
    static let itemWidth = (UIScreen.main.bounds.width - leftDistanceToView -
        rightDistanceToView - minimumLineSpacing) / 2
    static let itemHeight = itemWidth + 20
}

protocol SeriesCollectionViewDelegate: AnyObject {
    func seriesCollectionView(_ seriesCollectionView: SeriesCollectionView, didSelectSeries series: Series)
}

class SeriesCollectionView: UICollectionView {
    var library: MediaLibrary!
    weak var libraryDelegate: SeriesCollectionViewDelegate?

    init() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        super.init(frame: .zero, collectionViewLayout: layout)

        backgroundColor = .white
        delegate = self
        dataSource = self
        register(SeriesCollectionViewCell.self, forCellWithReuseIdentifier: SeriesCollectionViewCell.reuseId)
        translatesAutoresizingMaskIntoConstraints = false
        layout.minimumLineSpacing = SeriesCollectionViewConstants.minimumLineSpacing
        contentInset = UIEdgeInsets(top: 0,
                                    left: SeriesCollectionViewConstants.leftDistanceToView,
                                    bottom: 0,
                                    right: SeriesCollectionViewConstants.rightDistanceToView)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension SeriesCollectionView: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        referenceSizeForFooterInSection section: Int) -> CGSize {
        return CGSize(width: frame.width, height: 65)
    }
}

extension SeriesCollectionView: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return library.items.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = dequeueReusableCell(
            withReuseIdentifier: SeriesCollectionViewCell.reuseId, for: indexPath) as? SeriesCollectionViewCell ??
            SeriesCollectionViewCell()
        cell.appearance = library.items[indexPath.row].appearance
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let series = library.items[indexPath.row] as? Series else { return }
        libraryDelegate?.seriesCollectionView(self, didSelectSeries: series)
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: SeriesCollectionViewConstants.itemWidth,
                      height: SeriesCollectionViewConstants.itemHeight)
    }
}

extension SeriesCollectionView: MediaLibraryObserver {

    private func forEachVisibleCellWithSeries(_ series: Series, _ body: ((SeriesCollectionViewCell) -> Void)) {
        visibleCells.forEach { visibleCell in
            if let cell = visibleCell as? SeriesCollectionViewCell {
                if let seriesAppearance = cell.appearance as? Series.Appearance,
                    seriesAppearance.series === series {
                        body(cell)
                }
            }
        }
    }

    func mediaLibrary(didUpdateItemsOfMediaLibrary: MediaLibrary) {
        reloadData()
    }

    func mediaLibrary(mediaLibrary: MediaLibrary, didStartDownloadOf series: Series) {
        forEachVisibleCellWithSeries(series) {
            $0.progressView.isHidden = false
            $0.progressView.animateAppearance()
            $0.progressView.state = .progress(value: 0)
        }
    }

    func mediaLibrary(mediaLibrary: MediaLibrary,
                      didUpdateTotalDownloadProgress fractionCompleted: Double,
                      of series: Series) {
        forEachVisibleCellWithSeries(series) {
            $0.progressView.isHidden = false
            $0.progressView.state = .progress(value: fractionCompleted)
        }
    }

    func mediaLibrary(mediaLibrary: MediaLibrary, didCompleteDownloadOf series: Series) {
        forEachVisibleCellWithSeries(series) {
            $0.progressView.isHidden = false
            $0.progressView.animateDisappearance()
            $0.progressView.state = .finished
        }
    }
}
