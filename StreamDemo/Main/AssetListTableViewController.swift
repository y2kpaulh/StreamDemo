/*
 See LICENSE folder for this sample’s licensing information.

 Abstract:
 `AssetListTableViewController` is the main interface of this sample.  It provides
 a list of the assets the sample can play, download, cancel download, and delete.
 To play an item, tap on the tableViewCell, to interact with the download APIs,
 long press on the cell and you will be provided options based on the download
 state associated with the Asset on the cell.
 */

import UIKit
import AVFoundation
import AVKit

/// - Tag: AssetListTableViewController
class AssetListTableViewController: UITableViewController {
  // MARK: Properties
  let preferences = UserDefaults.standard

  // MARK: Deinitialization

  deinit {
    NotificationCenter.default.removeObserver(self,
                                              name: .AssetListManagerDidLoad,
                                              object: nil)
  }

  // MARK: UIViewController

  let sb = UIStoryboard(name: "Main", bundle: nil)

  override func viewDidLoad() {
    super.viewDidLoad()

    let versionNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? "1.0"
    let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") ?? "1.0"
    let versionAndBuildNumber = "v\(versionNumber)(\(buildNumber))"
    print(versionAndBuildNumber)

    self.title = "Epiens Stream Demo \(versionAndBuildNumber)"

    // General setup for auto sizing UITableViewCells.
    tableView.estimatedRowHeight = 75.0
    tableView.rowHeight = UITableView.automaticDimension
    tableView.tableFooterView = nil

    NotificationCenter.default.addObserver(self,
                                           selector: #selector(handleAssetListManagerDidLoad(_:)),
                                           name: .AssetListManagerDidLoad, object: nil)
    tableView.tableFooterView = UIView()

  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
  }

  // MARK: - Table view data source

  override func numberOfSections(in tableView: UITableView) -> Int {
    return 1
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return AssetListManager.sharedManager.numberOfAssets()
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: AssetListTableViewCell.reuseIdentifier, for: indexPath)

    let asset = AssetListManager.sharedManager.asset(at: indexPath.row)

    if let cell = cell as? AssetListTableViewCell {
      cell.asset = asset
      cell.delegate = self

      if !asset.stream.name.contains("Epiens") {
        cell.accessoryType = .none
      }

      if asset.stream.name.contains("Epiens Push") {
        cell.downloadStateLabel.text = preferences.string(forKey: "pushUrl")
      } else if asset.stream.name.contains("Epiens Pull") {
        cell.downloadStateLabel.text = preferences.string(forKey: "pullUrl")
      }

    }

    return cell
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    guard let cell = tableView.cellForRow(at: indexPath) as? AssetListTableViewCell, let asset = cell.asset
      else { return }
    print(asset.stream.playlistURL)

    if asset.stream.name.contains("Push") {
      let vc: PushStreamViewController = sb.instantiateViewController(withIdentifier: "PushStreamViewController") as! PushStreamViewController
      //self.navigationController?.pushViewController(vc, animated: true)
      self.present(vc, animated: true, completion: nil)
    } else {
      let vc: PullStreamViewController = sb.instantiateViewController(withIdentifier: "PullStreamViewController") as! PullStreamViewController

      let urlStr = asset.stream.playlistURL
      vc.url = urlStr

      self.present(vc, animated: true, completion: {
        self.tableView.deselectRow(at: indexPath, animated: true)
      })
    }
  }

  override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
    guard let cell = tableView.cellForRow(at: indexPath) as? AssetListTableViewCell, let asset = cell.asset else { return }

    print(asset.stream.name)

    if asset.stream.name.contains("Epiens") {

      let vc: PreferenceViewController = sb.instantiateViewController(withIdentifier: "PreferenceViewController") as! PreferenceViewController

      if asset.stream.name.contains("Push") {
        vc.urlType = "Push"
      } else if asset.stream.name.contains("Pull") {
        vc.urlType = "Pull"
      }

      self.present(vc, animated: true, completion: nil)
    }

  }

  // MARK: Notification handling

  @objc
  func handleAssetListManagerDidLoad(_: Notification) {
    DispatchQueue.main.async {
      self.tableView.reloadData()
    }
  }

  @IBAction func tapDebugBtn(_ sender: Any) {

  }
}

/**
 Extend `AssetListTableViewController` to conform to the `AssetListTableViewCellDelegate` protocol.
 */
extension AssetListTableViewController: AssetListTableViewCellDelegate {

  func assetListTableViewCell(_ cell: AssetListTableViewCell, downloadStateDidChange newState: Asset.DownloadState) {
    guard let indexPath = tableView.indexPath(for: cell) else { return }

    tableView.reloadRows(at: [indexPath], with: .automatic)
  }
}
