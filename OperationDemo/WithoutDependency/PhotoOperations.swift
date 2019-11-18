

import UIKit

enum PhotoRecordState{
    case new,downloaded,filtered,failed
}

class PhotoRecord{
    let name: String
    let url: URL
    var state = PhotoRecordState.new
    var image = UIImage(named: "Placeholder")
    
    init(name:String, url:URL) {
        self.name = name
        self.url = url
    }
}

class PendingOperations{
    lazy var downloadInProgress:[IndexPath:Operation] = [:]
    lazy var filtrationsInProgress:[IndexPath:Operation] = [:]
    lazy var downloadQueue:OperationQueue = {
        var queue = OperationQueue()
        queue.name = "Download Queue"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    lazy var filtrationQueue: OperationQueue = {
        var queue = OperationQueue()
        queue.name = "Filtration Queue"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
}


class ImageDownloader:Operation{
    let photoRecord : PhotoRecord
    
    init(_ photoRecord:PhotoRecord) {
        self.photoRecord = photoRecord
    }
    
    override func main() {
        
        if isCancelled{
            return
        }
        
        guard let imageData = try? Data(contentsOf: photoRecord.url) else {return}
        self.cancel()
        if isCancelled{
            return
        }
        
        if !imageData.isEmpty{
            photoRecord.image = UIImage(data: imageData)
            photoRecord.state = .downloaded
        }else{
            photoRecord.image = UIImage(named: "Failed")
            photoRecord.state = .failed
            
        }
    }
}

class ImageFiltration:Operation{
    let photoRecord : PhotoRecord
    init(_ photoRecord:PhotoRecord) {
        self.photoRecord = photoRecord
    }
    
    
    override func main() {
        if isCancelled{
            return
        }
        if self.photoRecord.state == .downloaded{} else {
            return
        }
        if let image = photoRecord.image, let filteredImage = applySepiaFilter(image){
            photoRecord.image = filteredImage
            photoRecord.state = .filtered
        }
    }
    func applySepiaFilter(_ image: UIImage) -> UIImage? {
        guard let data = image.pngData() else { return nil }
        let inputImage = CIImage(data: data)
        
        if isCancelled {
            return nil
        }
        
        let context = CIContext(options: nil)
        
        guard let filter = CIFilter(name: "CISepiaTone") else { return nil }
        filter.setValue(inputImage, forKey: kCIInputImageKey)
        filter.setValue(0.8, forKey: "inputIntensity")
        
        if isCancelled {
            return nil
        }
        
        guard
            let outputImage = filter.outputImage,
            let outImage = context.createCGImage(outputImage, from: outputImage.extent)
            else {
                return nil
        }
        
        return UIImage(cgImage: outImage)
    }
    
}
