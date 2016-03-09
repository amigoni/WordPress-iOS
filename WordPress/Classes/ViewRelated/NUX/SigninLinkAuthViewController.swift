import UIKit

/// Step three in the auth link flow. This vc displays a loading spinner and 
/// status updates as the user is signed into the app with their email address
/// and one time authentication token from the magic link.
///
class SigninLinkAuthViewController: UIViewController
{

    @IBOutlet var activityIndicator: UIActivityIndicatorView!
    @IBOutlet var label: UILabel!


    var email: String?
    var token: String?
    var authSuccessCallback: SigninCallbackBlock?
    var authFailedCallback: SigninCallbackBlock?


    class func controller(email: String, token: String, successCallback: SigninCallbackBlock, failureCallback: SigninCallbackBlock) -> SigninLinkAuthViewController {
        let storyboard = UIStoryboard(name: "Signin", bundle: NSBundle.mainBundle())
        let controller = storyboard.instantiateViewControllerWithIdentifier("SigninLinkAuthViewController") as! SigninLinkAuthViewController

        controller.authSuccessCallback = successCallback
        controller.authFailedCallback = failureCallback
        controller.token = token
        controller.email = email

        return controller
    }


    override func viewDidLoad() {
        super.viewDidLoad()

        performAuth()
    }


    // MARK: - Instance Methods


    /// Makes the call to authenticate the user with the one-time token.
    ///
    func performAuth() {
        guard let token = token, email = email else {
            // TODO: This is a falure condition that needs to be handled.
            authFailedCallback?()
            return
        }

        let format = NSLocalizedString("Signing in to WordPress.com as %@", comment: "Status message shown to the user. The %@ symbol is a placeholder for their email address.")
        label.text = NSString(format: format, email) as String

        activityIndicator.startAnimating()

        let loginFields = LoginFields(username: email,
            password: token,
            siteUrl: nil,
            multifactorCode: nil,
            userIsDotCom: true,
            shouldDisplayMultiFactor: false)

        let facade = LoginFacade()
        facade.delegate = self
        facade.signInWithLoginFields(loginFields)
    }


    /// Once an auth token is acquired, call this method to update account information.
    ///
    /// - Parameters:
    ///     - username: The username or email address used to sign in.
    ///     - authToken: The user's bearer token to the wpcom REST API.
    ///
    func didReceiveOAuthToken(username: String, authToken: String) {
        label.text = NSLocalizedString("Getting account information", comment:"")
        let facade = AccountServiceFacade()
        let account = facade.createOrUpdateWordPressComAccountWithUsername(username, authToken: authToken)
        facade.updateUserDetailsForAccount(account,
            success: { [weak self] in
                self?.syncBlogsForAccount(account)
            },
            failure: { [weak self] (error: NSError!) in
                // TODO: The account was created successfully but there was a
                // problem updating. Since the user is logged in at this point
                // log the error and end the login flow successfully
                self?.authSuccessCallback?()
        })
    }


    /// Once account information is updated, call this method to sync blogs.
    ///
    /// - Parameters:
    ///     - account: The account for which to sync blogs.
    ///
    func syncBlogsForAccount(account: WPAccount) {
        label.text = NSLocalizedString("Syncing blogs", comment:"")

        let blogFacade = BlogSyncFacade()
        blogFacade.syncBlogsForAccount(account,
            success: { [weak self] in
                self?.authSuccessCallback?()
            },
            failure: { [weak self] (error: NSError!) in
                // TODO: The account was created successfully but there was a
                // problem updating. Since the user is logged in at this point
                // log the error and end the login flow successfully.
                self?.authSuccessCallback?()
        })
    }

}


extension SigninLinkAuthViewController : LoginFacadeDelegate
{
    func displayLoginMessage(message: String) {

    }


    func displayRemoteError(error: NSError) {
        // TODO: Need to handle errors when getting the oauth token from the facade.
    }


    func finishedLoginWithUsername(username: String!, authToken: String!, requiredMultifactorCode: Bool) {
        didReceiveOAuthToken(username, authToken: authToken)
    }


    func finishedLoginWithUsername(username: String!, password: String!, xmlrpc: String!, options: [NSObject : AnyObject]!) {
        // Unused as this controller only supports wpcom logins.
    }


    func needsMultifactorCode() {
        // Unused as the magic link flow does not present the 2fa
    }
}

extension SigninLinkAuthViewController : SigninChildViewController
{
    var backButtonEnabled: Bool {
        return false
    }
    
    var loginFields: LoginFields? {
        get {
            return LoginFields(username: email, password: token, siteUrl: nil, multifactorCode: nil, userIsDotCom: true, shouldDisplayMultiFactor: false)
        }
        set {}
    }
}
