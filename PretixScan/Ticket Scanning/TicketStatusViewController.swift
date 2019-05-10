//
//  TicketStatusViewController.swift
//  PretixScan
//
//  Created by Daniel Jilg on 25.03.19.
//  Copyright © 2019 rami.io. All rights reserved.
//

import UIKit

class TicketStatusViewController: UIViewController, Configurable, AppCoordinatorReceiver {
    var appCoordinator: AppCoordinator?
    var configStore: ConfigStore?
    var configuration: Configuration? { didSet { update() } }
    var redemptionResponse: RedemptionResponse? { didSet { update() } }

    private var beganRedeeming = false
    private var error: Error? { didSet { update() } }

    struct Configuration {
        let secret: String
        var force: Bool
        var ignoreUnpaid: Bool
    }

    private let presentationTime: TimeInterval = 5
    @IBOutlet private weak var backgroundColorView: UIView!
    @IBOutlet private weak var iconLabel: UILabel!
    @IBOutlet private weak var ticketStatusLabel: UILabel!
    @IBOutlet private weak var productNameLabel: UILabel!
    @IBOutlet private weak var attendeeNameLabel: UILabel!
    @IBOutlet private weak var orderIDLabel: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!

    // MARK: - Updating
    private func update() {
        guard isViewLoaded else { return }
        DispatchQueue.main.async {
            self.updateMain()
        }
    }

    private func updateMain() {
        if configuration != nil, redemptionResponse == nil, beganRedeeming == false {
            redeem()
        }

        guard error == nil else {
            resetToEmpty()

            productNameLabel.text = self.error?.localized

            if let apiError = error as? APIError {
                switch apiError {
                case .notFound:
                    productNameLabel.text = Localization.Errors.TicketNotFound
                default:
                    productNameLabel.text = self.error?.localized
                }
            }

            let newBackgroundColor = Color.error
            iconLabel.text = Icon.error
            ticketStatusLabel.text = Localization.TicketStatusViewController.Error
            productNameLabel.text = self.error?.localized
            appCoordinator?.performHapticNotification(ofType: .error)

            UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: [], animations: {
                self.backgroundColorView.backgroundColor = newBackgroundColor
                self.view.layoutIfNeeded()
            })

            return
        }

        guard let redemptionResponse = self.redemptionResponse else {
            resetToEmpty()
            return
        }

        productNameLabel.text = "\(redemptionResponse.position?.item ?? 0)"
        attendeeNameLabel.text = redemptionResponse.position?.attendeeName
        orderIDLabel.text = redemptionResponse.position?.order

        var newBackgroundColor = Color.grayBackground
        self.activityIndicator.stopAnimating()

        switch redemptionResponse.status {
        case .redeemed:
            newBackgroundColor = Color.okay
            iconLabel.text = Icon.okay
            ticketStatusLabel.text = Localization.TicketStatusViewController.ValidTicket
            appCoordinator?.performHapticNotification(ofType: .success)
        case .incomplete:
            newBackgroundColor = Color.warning
            iconLabel.text = Icon.warning
            ticketStatusLabel.text = Localization.TicketStatusViewController.IncompleteInformation
            appCoordinator?.performHapticNotification(ofType: .warning)
        case .error:
            if redemptionResponse.errorReason == .alreadyRedeemed {
                newBackgroundColor = Color.warning
                iconLabel.text = Icon.warning
                ticketStatusLabel.text = Localization.TicketStatusViewController.TicketAlreadyRedeemed
                appCoordinator?.performHapticNotification(ofType: .warning)
            } else {
                newBackgroundColor = Color.error
                iconLabel.text = Icon.error
                ticketStatusLabel.text = Localization.TicketStatusViewController.InvalidTicket
                productNameLabel.text = redemptionResponse.errorReason.map { $0.rawValue }
                appCoordinator?.performHapticNotification(ofType: .error)
            }
        }

        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: [], animations: {
            self.backgroundColorView.backgroundColor = newBackgroundColor
            self.view.layoutIfNeeded()
        })
    }

    private func resetToEmpty() {
        backgroundColorView.backgroundColor = Color.grayBackground
        iconLabel.text = Icon.general
        ticketStatusLabel.text = nil
        productNameLabel.text = nil
        attendeeNameLabel.text = nil
        orderIDLabel.text = nil
    }

    private func redeem() {
        beganRedeeming = true
        guard let configuration = configuration else { return }

        activityIndicator.startAnimating()

        // The wait here fixes a timing issue with presentation animations
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            self.configStore?.ticketValidator?.redeem(
                secret: configuration.secret,
                force: configuration.force,
                ignoreUnpaid: configuration.ignoreUnpaid
            ) { (redemptionResponse, error) in
                self.error = error
                self.redemptionResponse = redemptionResponse

                // Dismiss
                DispatchQueue.main.asyncAfter(deadline: .now() + self.presentationTime) {
                    self.dismiss(animated: true, completion: nil)
                }
            }
        }
    }

    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        preferredContentSize = CGSize(width: 0, height: UIScreen.main.bounds.height * 0.50)
        update()
    }

    @IBAction func tap(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
}
