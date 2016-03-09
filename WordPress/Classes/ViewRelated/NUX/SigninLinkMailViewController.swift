import UIKit

/// Step two in the auth link flow. This VC prompts the user to open their email
/// app to look for the emailed authentication link.
///
class SigninLinkMailViewController: UIViewController
{
    @IBOutlet var openMailButton: UIButton!
    @IBOutlet var skipButton: UIButton!

    var email: String?
    var skipCallback: SigninCallbackBlock?


    class func controller(email: String, skipBlock: SigninCallbackBlock) -> SigninLinkMailViewController {
        let storyboard = UIStoryboard(name: "Signin", bundle: NSBundle.mainBundle())
        let controller = storyboard.instantiateViewControllerWithIdentifier("SigninLinkMailViewController") as! SigninLinkMailViewController

        controller.email = email
        controller.skipCallback = skipBlock

        return controller
    }


    // MARK: - Actions


    @IBAction func handleOpenMailTapped(sender: UIButton) {
        let url = NSURL(string: "message://")!
        UIApplication.sharedApplication().openURL(url)
    }


    @IBAction func handleSkipTapped(sender: UIButton) {
        skipCallback?()
    }
    
}

extension SigninLinkMailViewController : SigninChildViewController {
    var backButtonEnabled: Bool {
        return true
    }

    var loginFields: LoginFields? {
        get {
            return LoginFields(username: email, password: nil, siteUrl: nil, multifactorCode: nil, userIsDotCom: true, shouldDisplayMultiFactor: false)
        }
        set {}
    }
}
