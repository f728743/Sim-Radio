//
//  StationsViewController.swift
//  Sim Radio
//

import UIKit

class StationsViewController: UIViewController {
    private var tableView = UITableView()

    var series: Series?
    weak var radio: Radio!

    override func viewDidLoad() {
        super.viewDidLoad()
        radio.addObserver(self)
        radio.library.addObserver(self)

        view.addSubview(tableView)
        tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        tableView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true

        tableView.register(StationsHeaderTableViewCell.self,
                           forCellReuseIdentifier: StationsHeaderTableViewCell.reuseId)
        tableView.register(StationTableViewCell.self, forCellReuseIdentifier: StationTableViewCell.reuseId)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.tableFooterView = UIView(frame: .zero)

        tableView.delegate = self
        tableView.dataSource = self

        tableView.separatorColor = .lightGray

        let customView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 65))
        customView.backgroundColor = UIColor.clear
        tableView.tableFooterView = customView
    }

    private func forEachVisibleCellWithStation(_ station: Station, _ body: ((StationTableViewCell) -> Void)) {
        tableView.visibleCells.forEach { cell in
            if let cell = cell as? StationTableViewCell {
                if cell.station === station {
                    body(cell)
                }
            }
        }
    }
}

extension StationsViewController: RadioObserver {
    func radio(_ raio: Radio, didStartPlaying station: Station) {
        tableView.visibleCells.forEach { cell in
            if let cell = cell as? StationTableViewCell {
                cell.state = cell.station === station ? .playing : .stopped
            }
        }
    }

    func radio(_ raio: Radio, didPausePlaybackOf station: Station) {
        tableView.visibleCells.forEach { cell in
            if let cell = cell as? StationTableViewCell {
                cell.state = cell.station === station ? .paused : .stopped
            }
        }
    }

    func radioDidStop(_ radio: Radio) {
        tableView.visibleCells.forEach { cell in
            if let cell = cell as? StationTableViewCell {
                cell.state = .stopped
            }
        }
    }
}

extension StationsViewController: MediaLibraryObserver {
    func mediaLibrary(mediaLibrary: MediaLibrary, didStartDownloadOf series: Series) {
        tableView.visibleCells.forEach { cell in
            if let headerCell = cell as? StationsHeaderTableViewCell {
                headerCell.progressView.isHidden = false
                headerCell.progressView.animateAppearance()
                headerCell.progressView.state = .progress(value: 0)
            }
        }
    }

    func mediaLibrary(mediaLibrary: MediaLibrary,
                      didUpdateTotalDownloadProgress fractionCompleted: Double,
                      of series: Series) {
        tableView.visibleCells.forEach { cell in
            if let headerCell = cell as? StationsHeaderTableViewCell {
                headerCell.progressView.isHidden = false
                headerCell.progressView.state = .progress(value: fractionCompleted)
            }
        }
    }

    func mediaLibrary(mediaLibrary: MediaLibrary, didCompleteDownloadOf series: Series) {
        tableView.visibleCells.forEach { cell in
            if let headerCell = cell as? StationsHeaderTableViewCell {
                headerCell.progressView.isHidden = false
                headerCell.progressView.animateDisappearance()
                headerCell.progressView.state = .finished
            }
        }
    }

    func mediaLibrary(mediaLibrary: MediaLibrary,
                      didUpdateDownloadProgress fractionCompleted: Double,
                      of station: Station,
                      of series: Series) {
        forEachVisibleCellWithStation(station) {
            $0.progressView.isHidden = false
            $0.progressView.state = .progress(value: fractionCompleted)
        }
    }

    func mediaLibrary(mediaLibrary: MediaLibrary, didStartDownloadOf station: Station, of series: Series) {
        forEachVisibleCellWithStation(station) {
            $0.progressView.isHidden = false
            $0.progressView.animateAppearance()
            $0.progressView.state = .progress(value: 0)
        }
    }

    func mediaLibrary(mediaLibrary: MediaLibrary, didCompleteDownloadOf station: Station, of series: Series) {
        forEachVisibleCellWithStation(station) {
            $0.progressView.isHidden = false
            $0.progressView.animateDisappearance()
            $0.progressView.state = .finished
        }
    }
}

extension StationsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 1 {
            if let series = series {
                let station = series.stations[indexPath.row]
                radio.play(station: station)
                tableView.deselectRow(at: indexPath, animated: true)
            }
        }
    }
}

extension StationsViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        }
        return series?.stations.count ?? 0
    }

    private func setHeaderCellContent(headerCell: StationsHeaderTableViewCell, series: Series) {
        headerCell.logoImageView.image = series.logo
        headerCell.titleLabel.text = series.model.info.title
        if let downloadProgress = series.downloadProgress {
            headerCell.progressView.isHidden = false
            if downloadProgress == 0 {
                headerCell.progressView.state = .new
            } else if downloadProgress == 1.0 {
                headerCell.progressView.state = .finished
            } else {
                headerCell.progressView.state = .progress(value: downloadProgress)
            }
        } else {
            headerCell.progressView.isHidden = true
        }
    }

    private func setCellContent(cell: StationTableViewCell, station: Station) {
        cell.station = station
        cell.logoImageView.image = station.logo
        cell.titleLabel.text = station.title
        cell.infoLabel.text = station.genre
        cell.state = .stopped
        if let downloadProgress = station.downloadProgress {
            cell.progressView.isHidden = false
            if downloadProgress == 0 {
                cell.progressView.state = .new
            } else if downloadProgress == 1.0 {
                cell.progressView.state = .finished
            } else {
                cell.progressView.state = .progress(value: downloadProgress)
            }
        } else {
            cell.progressView.isHidden = true
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let headerCell = tableView.dequeueReusableCell(
                withIdentifier: StationsHeaderTableViewCell.reuseId) as? StationsHeaderTableViewCell ??
                StationsHeaderTableViewCell()
            if let series = series {
                setHeaderCellContent(headerCell: headerCell, series: series)
            }
            return headerCell
        }
        let cell = tableView.dequeueReusableCell(
            withIdentifier: StationTableViewCell.reuseId, for: indexPath) as? StationTableViewCell ??
            StationTableViewCell()
        let station = series!.stations[indexPath.row]
        setCellContent(cell: cell, station: station)
        switch radio.state {
        case .idle:
            cell.state = .stopped
        case let .paused(station):
            if cell.station === station {
                cell.state = .paused
            }
        case let .playing(station):
            if cell.station === station {
                cell.state = .playing
            }
        }
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return indexPath.section == 0 ? 156 : 56
    }
}
