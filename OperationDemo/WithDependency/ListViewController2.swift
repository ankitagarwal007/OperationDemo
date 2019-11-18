

import UIKit

class ListViewController2: UITableViewController {

    var photos: [PhotoRecord] = [PhotoRecord(name: "Hello", url: URL(string: "http://www.freeimages.com/pic/m/r/ro/rockberto/489872_lago_todos_los_santos.jpg")!)]
    let pendingOperations = PendingOperations()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = "Classic Photos"
        //fetchPhotoDetails()
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

    override func tableView(_ tableView: UITableView?, numberOfRowsInSection section: Int) -> Int {
        return photos.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CellIdentifier2", for: indexPath)
        if cell.accessoryView == nil {
            let indicator = UIActivityIndicatorView(style: .gray)
            cell.accessoryView = indicator
        }
        let indicator = cell.accessoryView as! UIActivityIndicatorView
        
        let photoDetails = photos[indexPath.row]
        cell.textLabel?.text = photoDetails.name
        cell.imageView?.image = photoDetails.image
        
        switch photoDetails.state {
        case .new:
            indicator.startAnimating()
            if !tableView.isDragging && !tableView.isDecelerating {
                startOperations(for: photoDetails, at: indexPath)
            }
        case .failed,.filtered:
            indicator.stopAnimating()
        default:
            break
        }
        return cell
    }
    
    func startOperations(for photoRecord: PhotoRecord, at indexPath: IndexPath) {
        switch (photoRecord.state) {
        case .new:
            startDownloadAndFiltration(for: photoRecord, at: indexPath)
        default:
            NSLog("do nothing")
        }
    }

    
    func startDownloadAndFiltration(for photoRecord: PhotoRecord, at indexPath: IndexPath) {
        guard pendingOperations.downloadInProgress[indexPath] == nil else {
            return
        }
        let downloadOperation = ImageDownloader(photoRecord)
        let imageFiltrationOperation = ImageFiltration(photoRecord)
        imageFiltrationOperation.addDependency(downloadOperation)
        self.pendingOperations.downloadInProgress[indexPath] = downloadOperation
        self.pendingOperations.filtrationsInProgress[indexPath] = imageFiltrationOperation
        self.pendingOperations.downloadQueue.addOperation(downloadOperation)
        self.pendingOperations.filtrationQueue.addOperation(imageFiltrationOperation)
        downloadOperation.completionBlock = {
            self.pendingOperations.downloadInProgress.removeValue(forKey: indexPath)

            if downloadOperation.isCancelled{
                print(">>>>>>>>>>>>>>>>>>>>>Inside competion of download cancelled")
                imageFiltrationOperation.cancel()
                return
            }
            print(">>>>>>>>>>>>>>>>>>>>>Inside competion of download")

            DispatchQueue.main.async {
                print(">>>>>>>>>>>>>>>>>>>>>Inside competion of download on main queue")
                self.tableView.reloadRows(at: [indexPath], with: .fade)
            }
        }
        imageFiltrationOperation.completionBlock = {
            self.pendingOperations.filtrationsInProgress.removeValue(forKey: indexPath)
            if imageFiltrationOperation.isCancelled || downloadOperation.isCancelled{
                print(">>>>>>>>>>>>>>>>>>>>>Inside competion of filteration cancelled")
                return
            }
            print(">>>>>>>>>>>>>>>>>>>>>Inside competion of filteration")
            DispatchQueue.main.async {
                print(">>>>>>>>>>>>>>>>>>>>>Inside competion of filteration on main queue")
                self.tableView.reloadRows(at: [indexPath], with: .fade)
            }
        }
    }
}
