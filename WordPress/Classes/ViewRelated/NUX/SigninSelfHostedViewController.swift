import UIKit
import NSURL_IDN

///
///
class SigninSelfHostedViewController: UIViewController {
    var signInSuccessBlock: SigninSuccessBlock?
    var signInFailureBlock: SigninFailureBlock?
    
    var email: String!

    @IBOutlet var onePasswordButton: UIButton!
    @IBOutlet weak var emailField: WPWalkthroughTextField!
    @IBOutlet weak var passwordField: WPWalkthroughTextField!
    @IBOutlet weak var siteURLField: WPWalkthroughTextField!
    @IBOutlet weak var addSiteButton: WPNUXMainButton!
    
    lazy var loginFacade: LoginFacade = {
        let facade = LoginFacade()
        facade.delegate = self
        return facade
    }()
    
    lazy var blogSyncFacade = BlogSyncFacade()


    /// A convenience method for obtaining an instance of the controller from a storyboard.
    ///
    class func controller(email: String, success: SigninSuccessBlock, failure: SigninFailureBlock) -> SigninSelfHostedViewController {
        let storyboard = UIStoryboard(name: "Signin", bundle: NSBundle.mainBundle())
        let controller = storyboard.instantiateViewControllerWithIdentifier("SigninSelfHostedViewController") as! SigninSelfHostedViewController
        
        controller.email = email
        controller.signInSuccessBlock = success
        controller.signInFailureBlock = failure
        
        return controller
    }


    // MARK: - Lifecycle Methods

    override func viewDidLoad() {
        super.viewDidLoad()

        configureEmailField()
    }


    func configureEmailField() {
        emailField.text = email

        if !OnePasswordFacade().isOnePasswordEnabled() {
            return
        }

        onePasswordButton.sizeToFit()

        emailField.rightView = onePasswordButton
        emailField.rightViewMode = .Always
        emailField.rightViewPadding = UIOffset(horizontal: 9.0, vertical: 0.0)
    }


    // MARK: - Actions

    @IBAction func handleOnePasswordButtonTapped(sender: UIButton) {
        // TODO: Populate fields with credentials from one password if they exist. 
        
    }


    @IBAction func addSiteTapped() {
        view.endEditing(true)

        // is reachable?
        if !ReachabilityUtils.isInternetReachable() {
            ReachabilityUtils.showAlertNoInternetConnection()
            return
        }

        let loginFields = LoginFields(username: emailField.text?.trim(),
            password: passwordField.text?.trim(),
            siteUrl: siteURLField.text?.trim(),
            multifactorCode: nil,
            userIsDotCom: false,
            shouldDisplayMultiFactor: false)


        // all fields fileld out?
        if !areFieldsValid(loginFields) {
            WPError.showAlertWithTitle(NSLocalizedString("Error", comment: "Title of an error message"),
                message: NSLocalizedString("Please fill out all the fields", comment: "A short prompt asking the user to properly fill out all login fields."),
                withSupportButton: false)

            return
        }

        addSiteButton.showActivityIndicator(true)

        loginFacade.signInWithLoginFields(loginFields)
    }


    func areFieldsValid(loginFields: LoginFields) -> Bool {
        return loginFields.username.characters.count > 0 &&
            loginFields.password.characters.count > 0 &&
            loginFields.siteUrl.characters.count > 0 &&
            NSURL(string: NSURL.IDNEncodedURL(loginFields.siteUrl)) != nil
    }


    func displayError(error: NSError) {
        signInFailureBlock?(error: error)
    }
}


extension SigninSelfHostedViewController: LoginFacadeDelegate {

    func finishedLoginWithUsername(username: String!, password: String!, xmlrpc: String!, options: [NSObject : AnyObject]!) {
        blogSyncFacade.syncBlogWithUsername(username, password: password, xmlrpc: xmlrpc, options: options) {
            self.addSiteButton.showActivityIndicator(false)
            // Finish login
            self.signInSuccessBlock?()
        }
    }


    func finishedLoginWithUsername(username: String!, authToken: String!, requiredMultifactorCode: Bool) {
        print("Finished")
    }


    func displayLoginMessage(message: String!) {
        print("message: \(message)")
    }


    func displayRemoteError(error: NSError!) {
        print("error: \(error.description)")
        addSiteButton.showActivityIndicator(false)

        displayError(error)
    }


    func needsMultifactorCode() {
        self.signInFailureBlock?(error: SigninFailureError.NeedsMultifactorCode)
    }
}


extension SigninSelfHostedViewController: UITextFieldDelegate {
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        if textField == emailField {
            passwordField.becomeFirstResponder()
        } else if textField == passwordField {
            siteURLField.becomeFirstResponder()
        }
        return true
    }
}


extension SigninSelfHostedViewController: SigninChildViewController {
    var backButtonEnabled: Bool {
        return true
    }
    
    var loginFields: LoginFields? {
        get {
            return LoginFields(username: emailField.text, password: passwordField.text, siteUrl: siteURLField.text, multifactorCode: nil, userIsDotCom: false, shouldDisplayMultiFactor: true)
        }
        set {}
    }
}
