import UIKit
import SVProgressHUD
import WordPressShared

/// Implements site management services triggered from SiteSettingsViewController
///
public extension SiteSettingsViewController
{
    /// Presents confirmation alert for Export Content
    ///
    public func confirmExportContent() {
        tableView.deselectSelectedRowWithAnimation(true)

        presentViewController(confirmExportController(), animated: true, completion: nil)
    }

    /// Creates confirmation alert for Export Content
    ///
    /// - Returns: UIAlertController
    ///
    private func confirmExportController() -> UIAlertController {
        let confirmTitle = NSLocalizedString("Export Your Content", comment: "Title of Export Content confirmation alert")
        let messageFormat = NSLocalizedString("Your posts, pages, and settings will be mailed to you at %@.", comment: "Message of Export Content confirmation alert; substitution is user's email address")
        let message = String(format: messageFormat, blog.account.email)
        let alertController = UIAlertController(title: confirmTitle, message: message, preferredStyle: .Alert)
        
        let cancelTitle = NSLocalizedString("Cancel", comment: "Alert dismissal title")
        alertController.addCancelActionWithTitle(cancelTitle, handler: nil)
        
        let exportTitle = NSLocalizedString("Export Content", comment: "Export Content confirmation action title")
        alertController.addDefaultActionWithTitle(exportTitle, handler: { _ in
            self.exportContent()
        })
        
        return alertController
    }

    /// Handles triggering content export to XML file via API
    ///
    /// - Note: Email is sent on completion
    ///
    private func exportContent() {
        let status = NSLocalizedString("Exporting content…", comment: "Overlay message displayed while starting content export")
        SVProgressHUD.showWithStatus(status, maskType: .Black)
        
        let service = SiteManagementService(managedObjectContext: ContextManager.sharedInstance().mainContext)
        service.exportContentForBlog(blog,
            success: {
                let status = NSLocalizedString("Email sent!", comment: "Overlay message displayed when export content started")
                SVProgressHUD.showSuccessWithStatus(status)
            },
            failure: { error in
                DDLogSwift.logError("Error exporting content: \(error.localizedDescription)")
                SVProgressHUD.dismiss()
                
                let errorTitle = NSLocalizedString("Export Content Error", comment: "Title of alert when export content fails")
                let alertController = UIAlertController(title: errorTitle, message: error.localizedDescription, preferredStyle: .Alert)

                let okTitle = NSLocalizedString("OK", comment: "Alert dismissal title")
                alertController.addDefaultActionWithTitle(okTitle, handler: nil)
                
                alertController.presentFromRootViewController()
            })
    }    

    /// Presents confirmation alert for Delete Site
    ///
    public func confirmDeleteSite() {
        tableView.deselectSelectedRowWithAnimation(true)
        
        presentViewController(confirmDeleteController(), animated: true, completion: nil)
    }

    /// Creates confirmation alert for Delete Site
    ///
    /// - Returns: UIAlertController
    ///
    private func confirmDeleteController() -> UIAlertController {
        let confirmTitle = NSLocalizedString("Confirm Delete Site", comment: "Title of Delete Site confirmation alert")
        let messageFormat = NSLocalizedString("Please type in \n\n%@\n\n in the field below to confirm. Your site will then be gone forever.", comment: "Message of Delete Site confirmation alert; substitution is site's host")
        let message = String(format: messageFormat, blog.displayURL!)
        let alertController = UIAlertController(title: confirmTitle, message: message, preferredStyle: .Alert)
        
        let cancelTitle = NSLocalizedString("Cancel", comment: "Alert dismissal title")
        alertController.addCancelActionWithTitle(cancelTitle, handler: nil)
        
        let deleteTitle = NSLocalizedString("Delete this site", comment: "Delete Site confirmation action title")
        let deleteAction = UIAlertAction(title: deleteTitle, style: .Destructive, handler: { action in
            self.deleteSiteConfirmed()
        })
        deleteAction.enabled = false
        alertController.addAction(deleteAction)
        
        alertController.addTextFieldWithConfigurationHandler({ textField in
            textField.addTarget(self, action: "alertTextFieldDidChange:", forControlEvents: .EditingChanged)
        })
        
        return alertController
    }
    
    /// Verifies site address as password for Delete Site
    ///
    func alertTextFieldDidChange(sender: UITextField) {
        guard let deleteAction = (presentedViewController as? UIAlertController)?.actions.last else {
            return
        }
        
        let prompt = blog.displayURL?.lowercaseString.trim()
        let password = sender.text?.lowercaseString.trim()
        deleteAction.enabled = prompt == password
    }

    /// Handles deletion of the blog's site and all content from WordPress.com
    ///
    /// - Note: This is permanent and cannot be reversed by user
    ///
    private func deleteSiteConfirmed() {
        let status = NSLocalizedString("Deleting site…", comment: "Overlay message displayed while deleting site")
        SVProgressHUD.showWithStatus(status, maskType: .Black)
        
        let service = SiteManagementService(managedObjectContext: ContextManager.sharedInstance().mainContext)
        service.deleteSiteForBlog(blog,
            success: { [weak self] in
                let status = NSLocalizedString("Site deleted", comment: "Overlay message displayed when site successfully deleted")
                SVProgressHUD.showSuccessWithStatus(status)
                
                if let navController = self?.navigationController {
                    navController.popToRootViewControllerAnimated(true)
                }
            },
            failure: { error in
                DDLogSwift.logError("Error deleting site: \(error.localizedDescription)")
                SVProgressHUD.dismiss()
                
                let errorTitle = NSLocalizedString("Delete Site Error", comment: "Title of alert when site deletion fails")
                let alertController = UIAlertController(title: errorTitle, message: error.localizedDescription, preferredStyle: .Alert)
                
                let okTitle = NSLocalizedString("OK", comment: "Alert dismissal title")
                alertController.addDefaultActionWithTitle(okTitle, handler: nil)
                
                alertController.presentFromRootViewController()
            })
    }
}