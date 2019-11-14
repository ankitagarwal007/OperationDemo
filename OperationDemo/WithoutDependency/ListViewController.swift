

import UIKit
import CoreImage

let dataSourceURL = URL(string:"http://www.raywenderlich.com/downloads/ClassicPhotosDictionary.plist")!

class ListViewController: UITableViewController {
    
    var photos: [PhotoRecord] = []
    let pendingOperations = PendingOperations()
    
  override func viewDidLoad() {
    super.viewDidLoad()
    self.title = "Classic Photos"
    fetchPhotoDetails()
  }
  
    func fetchPhotoDetails() {
        let request = URLRequest(url: dataSourceURL)
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        
        // 1
        let task = URLSession(configuration: .default).dataTask(with: request) { data, response, error in
            
            // 2
            let alertController = UIAlertController(title: "Oops!",
                                                    message: "There was an error fetching photo details.",
                                                    preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK", style: .default)
            alertController.addAction(okAction)
            
            if let data = data {
                do {
                    // 3
                    let datasourceDictionary =
                        try PropertyListSerialization.propertyList(from: data,
                                                                   options: [],
                                                                   format: nil) as! [String: String]
                    
                    // 4
                    for (name, value) in datasourceDictionary {
                        let url = URL(string: value)
                        if let url = url {
                            let photoRecord = PhotoRecord(name: name, url: url)
                            self.photos.append(photoRecord)
                        }
                    }
                    
                    // 5
                    DispatchQueue.main.async {
                        UIApplication.shared.isNetworkActivityIndicatorVisible = false
                        self.tableView.reloadData()
                    }
                    // 6
                } catch {
                    DispatchQueue.main.async {
                        self.present(alertController, animated: true, completion: nil)
                    }
                }
            }
            
            // 6
            if error != nil {
                DispatchQueue.main.async {
                    UIApplication.shared.isNetworkActivityIndicatorVisible = false
                    self.present(alertController, animated: true, completion: nil)
                }
            }
        }
        // 7
        task.resume()
    }
  // MARK: - Table view data source

  override func tableView(_ tableView: UITableView?, numberOfRowsInSection section: Int) -> Int {
    return photos.count
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "CellIdentifier", for: indexPath)
    if cell.accessoryView == nil {
        let indicator = UIActivityIndicatorView(style: .gray)
        cell.accessoryView = indicator
    }
    let indicator = cell.accessoryView as! UIActivityIndicatorView

    let photoDetails = photos[indexPath.row]
    cell.textLabel?.text = photoDetails.name
    cell.imageView?.image = photoDetails.image
    
    switch photoDetails.state {
    case .new,.downloaded:
        indicator.startAnimating()
        if !tableView.isDragging && !tableView.isDecelerating {
            startOperations(for: photoDetails, at: indexPath)
        }
    case .filtered:
        indicator.stopAnimating()
    case .failed:
        indicator.stopAnimating()
        cell.textLabel?.text = "Failed to load"
    }
    return cell
  }
  
    func startOperations(for photoRecord: PhotoRecord, at indexPath: IndexPath) {
        switch (photoRecord.state) {
        case .new:
            startDownload(for: photoRecord, at: indexPath)
        case .downloaded:
           // startFiltration(for: photoRecord, at: indexPath)
            break
        default:
            NSLog("do nothing")
        }
    }

    func startDownload(for photoRecord: PhotoRecord, at indexPath: IndexPath) {
        guard pendingOperations.downloadInProgress[indexPath] == nil else {
            return
        }
        let downloadOperation = ImageDownloader(photoRecord)
        self.pendingOperations.downloadInProgress[indexPath] = downloadOperation
        self.pendingOperations.downloadQueue.addOperation(downloadOperation)
        downloadOperation.completionBlock = {
            if downloadOperation.isCancelled{
                return
            }
            DispatchQueue.main.async {
                self.pendingOperations.downloadInProgress.removeValue(forKey: indexPath)
                self.tableView.reloadRows(at: [indexPath], with: .fade)
            }
        }
    }
    func startFiltration(for photoRecord: PhotoRecord, at indexPath: IndexPath) {
        guard pendingOperations.filtrationsInProgress[indexPath] == nil else {
            return
        }
        let imageFiltrationOperation = ImageFiltration(photoRecord)
        self.pendingOperations.filtrationsInProgress[indexPath] = imageFiltrationOperation
        self.pendingOperations.filtrationQueue.addOperation(imageFiltrationOperation)
        
        imageFiltrationOperation.completionBlock = {
            if imageFiltrationOperation.isCancelled{
                return
            }
            DispatchQueue.main.async {
                self.pendingOperations.filtrationsInProgress.removeValue(forKey: indexPath)
                self.tableView.reloadRows(at: [indexPath], with: .fade)

            }
        }
        
        
    }
    
    override func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        suspendAllOperations()
    }
    override func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate{
            loadImagesForOnscreenCells()
            resumeAllOperations()
        }
    }
    override func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        loadImagesForOnscreenCells()
        resumeAllOperations()
    }
    
    func suspendAllOperations() {
        pendingOperations.downloadQueue.isSuspended = true
        pendingOperations.filtrationQueue.isSuspended = true
    }
    
    func resumeAllOperations() {
        pendingOperations.downloadQueue.isSuspended = false
        pendingOperations.filtrationQueue.isSuspended = false
    }
    
    func loadImagesForOnscreenCells() {
        //1
        if let pathsArray = tableView.indexPathsForVisibleRows {
            //2
            var allPendingOperations = Set(pendingOperations.downloadInProgress.keys)
            allPendingOperations.formUnion(pendingOperations.filtrationsInProgress.keys)
            
            //3
            var toBeCancelled = allPendingOperations
            let visiblePaths = Set(pathsArray)
            toBeCancelled.subtract(visiblePaths)
            
            //4
            var toBeStarted = visiblePaths
            toBeStarted.subtract(allPendingOperations)
            
            // 5 Cancel tasks and remove from dict
            for indexPath in toBeCancelled {
                if let pendingDownload = pendingOperations.downloadInProgress[indexPath] {
                    pendingDownload.cancel()
                }
                pendingOperations.downloadInProgress.removeValue(forKey: indexPath)
                if let pendingFiltration = pendingOperations.filtrationsInProgress[indexPath] {
                    pendingFiltration.cancel()
                }
                pendingOperations.filtrationsInProgress.removeValue(forKey: indexPath)
            }
            
            // 6
            for indexPath in toBeStarted {
                let recordToProcess = photos[indexPath.row]
                startOperations(for: recordToProcess, at: indexPath)
            }
        }
    }
 
}


