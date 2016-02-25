import UIKit

class SigninMagicLinkViewController: UIViewController
{

    @IBOutlet var label: UILabel!
    @IBOutlet var requestLinkButton: UIButton!
    @IBOutlet var usePasswordButton: UIButton!


    var didRequestLinkCallback: SigninCallbackBlock?
    var signinWithPasswordCallback: SigninCallbackBlock?
    var email: String?

    class func controller(email: String, requestLinkBlock: SigninCallbackBlock, signinWithPasswordBlock: SigninCallbackBlock) -> SigninMagicLinkViewController {
        let storyboard = UIStoryboard(name: "Signin", bundle: NSBundle.mainBundle())
        let controller = storyboard.instantiateViewControllerWithIdentifier("SigninMagicLinkViewController") as! SigninMagicLinkViewController

        controller.email = email
        controller.didRequestLinkCallback = requestLinkBlock
        controller.signinWithPasswordCallback = signinWithPasswordBlock

        return controller
    }


    // MARK: - Lifecycle Methods

    override func viewDidLoad() {
        super.viewDidLoad()

        if let email = email {
            label.text = "Email me a link that will automatically sign me in to \(email)"
        }
    }


    // MARK: - Actions


    @IBAction func handleRequestLinkTapped(sender: UIButton) {
        requestAuthenticationLink()
    }


    @IBAction func handleUsePasswordTapped(sender: UIButton) {
        signinWithPasswordCallback?()
    }


    // MARK: - Instance Methods

    func requestAuthenticationLink() {
        guard let email = email else {
            return
        }

        requestLinkButton.enabled = false
        let service = AccountService(managedObjectContext: ContextManager.sharedInstance().mainContext)
        service.requestAuthenticationLink(email,
            success: { [weak self] in
                self?.didRequestAuthenticationLink()
            }, failure: { [weak self] (error: NSError!) in
                DDLogSwift.logError(error.description)
                self?.requestLinkButton.enabled = true
        })
    }


    func didRequestAuthenticationLink() {
        didRequestLinkCallback?()
    }

}