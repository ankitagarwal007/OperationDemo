

import UIKit

enum PhotoRecordState2{
    
    case new,downloaded,filtered,failed
}

class PhotoRecord2{
    let name: String
    let url: URL
    var state = PhotoRecordState.new
    var image = UIImage(named: "Placeholder")
    
    init(name:String, url:URL) {
        self.name = name
        self.url = url
    }
}

class PendingOperations2{
    lazy var downloadInProgress:[IndexPath:Operation] = [:]
    lazy var downloadQueue:OperationQueue = {
        var queue = OperationQueue()
        queue.name = "Download Queue"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
}

