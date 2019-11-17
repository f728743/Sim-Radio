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
        return library.series.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = dequeueReusableCell(
            withReuseIdentifier: SeriesCollectionViewCell.reuseId, for: indexPath) as? SeriesCollectionViewCell ??
            SeriesCollectionViewCell()
        let series = library.series[indexPath.row]
        cell.logoImageView.image = series.logo
        cell.titleLabel.text = series.model.info.title
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let series = library.series[indexPath.row]
        libraryDelegate?.seriesCollectionView(self, didSelectSeries: series)
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: SeriesCollectionViewConstants.itemWidth,
                      height: SeriesCollectionViewConstants.itemHeight)
    }
}
