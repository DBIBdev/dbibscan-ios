//
//  SelectEventTableViewController.swift
//  PretixScan
//
//  Created by Daniel Jilg on 18.03.19.
//  Copyright © 2019 rami.io. All rights reserved.
//

import UIKit

class SelectEventTableViewController: UITableViewController, Configurable {
    var configStore: ConfigStore?

    private var isLoading = true {
        didSet {
            DispatchQueue.main.async {
                if self.isLoading {
                    self.tableView.refreshControl?.beginRefreshing()
                } else {
                    self.tableView.refreshControl?.endRefreshing()
                }
                self.tableView.reloadData()
            }
        }
    }

    private var events: [Event]?
    private var subEvents: [Event: [SubEvent]]?

    private let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .none
        dateFormatter.dateStyle = .medium
        return dateFormatter
    }()

    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = Localization.SelectEventTableViewController.Title
        refreshControl?.addTarget(self, action: #selector(updateView), for: .valueChanged)
    }

    override func viewWillAppear(_ animated: Bool) {
        updateView()
    }

    @objc private func updateView() {
        isLoading = true
        events = nil
        subEvents = nil

        var subEventsLoading = 0

        configStore?.ticketValidator?.getEvents { (eventList, error) in
            self.presentErrorAlert(ifError: error)
            self.events = eventList
            if let events = self.events {
                subEventsLoading = events.count
                for event in events {
                    guard event.hasSubEvents else {
                        subEventsLoading -= 1
                        if subEventsLoading < 1 {
                            self.isLoading = false
                        }

                        continue
                    }

                    self.configStore?.ticketValidator?.getSubEvents(event: event) { (subeventList, error) in
                        subEventsLoading -= 1
                        self.presentErrorAlert(ifError: error)

                        if let subeventList = subeventList {
                            self.subEvents?[event] = subeventList
                        }

                        if subEventsLoading < 1 {
                            self.isLoading = false
                        }
                    }
                }
            } else {
                self.isLoading = false
            }
        }
    }

    // MARK: - Table view data source
    private static let reuseIdentifier = "SelectEventTableViewControllerCell"
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return events?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SelectEventTableViewController.reuseIdentifier, for: indexPath)
        if let event = event(for: indexPath) {
            cell.textLabel?.text = event.name.description
            if let date = event.dateFrom {
                cell.detailTextLabel?.text = dateFormatter.string(from: date)
            }
        }
        return cell
    }

    private func event(for indexPath: IndexPath) -> Event? {
        guard let events = events else { return nil }
        guard events.count > indexPath.row else { return nil }
        return events[indexPath.row]
    }

    // MARK: View Communication
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if let selectCheckInListViewController = segue.destination as? SelectCheckInListTableViewController,
            let selectedCell = sender as? UITableViewCell,
            let selectedIndexPath = tableView.indexPath(for: selectedCell) {

            let selectedEvent = event(for: selectedIndexPath)
            selectCheckInListViewController.event = selectedEvent
        }
    }
}
