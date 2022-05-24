// - - - - - - - - - - - - - - - - - - - -
//
// Digimarc Confidential
// Copyright Digimarc Corporation, 2014-2017
//
// - - - - - - - - - - - - - - - - - - - -

import UIKit
import DMSDK
import SafariServices

class ResultsTableViewController: UITableViewController
{
    public var resolvedContent: [String : ResolvedContent] = [:]

    var payloads: [Payload] = []
    
    func payload(for indexPath: IndexPath) -> Payload?
    {
        if indexPath.row < 0 || indexPath.row >= self.payloads.count
        {
            return nil
        }
        
        return self.payloads[indexPath.row]
    }
    
    func update(with payload: Payload)
    {
        self.tableView.beginUpdates()
        
        defer { self.tableView.endUpdates() }

        if let index = self.payloads.firstIndex(of: payload)
        {
            if index == 0 { return }
            
            self.payloads.remove(at: index)
            self.tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
        }

        self.payloads.insert(payload, at: 0)
        self.tableView.insertRows(at: [IndexPath(row: 0, section: 0)], with: .automatic)
    }
    
    override func viewDidAppear(_ animated: Bool)
    {
        self.tableView.indexPathsForSelectedRows?.forEach
        {
            self.tableView.deselectRow(at: $0, animated: true)
        }
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int
    {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        let itemCount = self.payloads.count
        self.tableView.separatorStyle = (itemCount == 0) ? .none : .singleLine
        return itemCount
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        guard
        let cell = tableView.dequeueReusableCell(withIdentifier: "PayloadCell", for: indexPath) as? ResultTableViewCell,
        let payload = self.payload(for: indexPath),
            let resolvedContentItem = self.resolvedContent[payload.id]?.items.first
        else
        {
            return UITableViewCell()
        }

        cell.titleLabel?.text = resolvedContentItem.title
        cell.subtitleLabel?.text = resolvedContentItem.subtitle
        cell.thumbnailURL = resolvedContentItem.thumbnailURL
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        guard
        let payload = self.payload(for: indexPath),
            let resolvedContentItem = self.resolvedContent[payload.id]?.items.first,
        let url = resolvedContentItem.url
        else
        {
            return
        }
        
        UIApplication.shared.open(url, options: convertToUIApplicationOpenExternalURLOptionsKeyDictionary([:]), completionHandler: nil)
    }
    
    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 54
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToUIApplicationOpenExternalURLOptionsKeyDictionary(_ input: [String: Any]) -> [UIApplication.OpenExternalURLOptionsKey: Any] {
	return Dictionary(uniqueKeysWithValues: input.map { key, value in (UIApplication.OpenExternalURLOptionsKey(rawValue: key), value)})
}
