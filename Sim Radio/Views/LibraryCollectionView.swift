//
//  LibraryCollectionView.swift
//  Sim Radio
//

import UIKit

struct LibraryConstants {
    static let leftDistanceToView: CGFloat = 20
    static let rightDistanceToView: CGFloat = 20
    static let minimumLineSpacing: CGFloat = 20
    static let itemWidth = (UIScreen.main.bounds.width - leftDistanceToView - rightDistanceToView - minimumLineSpacing) / 2
    static let itemHeight = itemWidth + 20
}

protocol LibraryCollectionViewDelegate {
    func libraryCollectionView(_ libraryCollectionView: LibraryCollectionView, didSelectSeries series: Series)
}

class LibraryCollectionView: UICollectionView {
    var library: MediaLibrary!
    var libraryDelegate: LibraryCollectionViewDelegate?

    init() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        super.init(frame: .zero, collectionViewLayout: layout)

        backgroundColor = .white
        delegate = self
        dataSource = self
        register(LibraryCollectionViewCell.self, forCellWithReuseIdentifier: LibraryCollectionViewCell.reuseId)
        translatesAutoresizingMaskIntoConstraints = false
        layout.minimumLineSpacing = LibraryConstants.minimumLineSpacing
        contentInset = UIEdgeInsets(top: 0, left: LibraryConstants.leftDistanceToView, bottom: 0, right: LibraryConstants.rightDistanceToView)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension LibraryCollectionView: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        return CGSize(width: frame.width, height: 65)
    }
}

extension LibraryCollectionView: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return library.series.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = dequeueReusableCell(withReuseIdentifier: LibraryCollectionViewCell.reuseId, for: indexPath) as! LibraryCollectionViewCell
        let series = Array(library.series.values)[indexPath.row]
        cell.logoImageView.image = series.logo
        cell.titleLabel.text = series.model.info.title
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath)  {
        let series = Array(library.series.values)[indexPath.row]
        libraryDelegate?.libraryCollectionView(self, didSelectSeries: series)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: LibraryConstants.itemWidth, height: LibraryConstants.itemHeight)
    }
}
