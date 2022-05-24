// - - - - - - - - - - - - - - - - - - - -
//
// Digimarc Confidential
// Copyright Digimarc Corporation, 2014-2017
//
// - - - - - - - - - - - - - - - - - - - -

import UIKit

class ResultTableViewCell: UITableViewCell
{
    static var imageCache: [URL : UIImage] = [:]

    @IBOutlet weak var titleLabel: UILabel?
    @IBOutlet weak var subtitleLabel: UILabel?
    @IBOutlet weak var thumbnailImageView: UIImageView?
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView?

    public var thumbnailURL: URL?
    {
        willSet
        {
            // If we're setting thumbnailURL to nil, clear the image and return
            guard let newURL = newValue else
            {
                self.thumbnailImageView?.image = nil
                return
            }
        
            // If we've already downloaded the image, use the cached version
            if ResultTableViewCell.imageCache.keys.contains(newURL)
            {
                self.thumbnailImageView?.image = ResultTableViewCell.imageCache[newURL]
                
                return
            }
            
            self.activityIndicator?.startAnimating()
            
            let task = URLSession.shared.dataTask(with: newURL)
            {
                (data: Data?, response: URLResponse?, error: Error?) in
                
                DispatchQueue.main.sync
                {
                    self.activityIndicator?.stopAnimating()
                
                    guard
                    let data = data,
                    let image = UIImage(data: data)
                    else
                    {
                        return
                    }

                    ResultTableViewCell.imageCache[newURL] = image

                    // If this is false, the thumbnail url has changed since we started the download and we can ignore it
                    if self.thumbnailURL == newURL
                    {
                        self.thumbnailImageView?.image = image
                    }
                }
            }
            
            task.resume()
        }
    }

    override func prepareForReuse()
    {
        super.prepareForReuse()
        
        self.thumbnailImageView?.image = nil
    }
}
