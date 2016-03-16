import UIKit

typealias SigninValidateEmailBlock = (String) -> Void


/// This vc is the entry point for the normal sign in flow.
///
///
class SigninEmailViewController : UIViewController, UITextFieldDelegate
{
    var emailValidationSuccessCallback: SigninValidateEmailBlock?
    var emailValidationFailureCallback: SigninValidateEmailBlock?

    lazy var accountServiceRemote = AccountServiceRemoteREST()

    @IBOutlet var onePasswordButton: UIButton!
    @IBOutlet var emailTextField: WPWalkthroughTextField!
    @IBOutlet var submitButton: WPNUXMainButton!


    /// A convenience method for obtaining an instance of the controller from a storyboard.
    ///
    class func controller(success: SigninValidateEmailBlock, failure: SigninValidateEmailBlock) -> SigninEmailViewController {
        let storyboard = UIStoryboard(name: "Signin", bundle: NSBundle.mainBundle())
        let controller = storyboard.instantiateViewControllerWithIdentifier("SigninEmailViewController") as! SigninEmailViewController

        controller.emailValidationSuccessCallback = success
        controller.emailValidationFailureCallback = failure
        
        return controller
    }


    // MARK: Lifecycle Methods


    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureEmailField()
    }


    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        emailTextField.becomeFirstResponder()
    }


    // MARK: - Configuration


    private func configureEmailField() {

        if !OnePasswordFacade().isOnePasswordEnabled() {
            return
        }

        onePasswordButton.sizeToFit()
        emailTextField.rightView = onePasswordButton
        emailTextField.rightViewPadding = UIOffset(horizontal: 9.0, vertical: 0.0)
        emailTextField.rightViewMode = .Always
    }


    // MARK: - Instance Methods


    func checkEmailAddress(email: String) {
        // TODO: Need some basic validation

        setLoading(true)
        
        let service = AccountService(managedObjectContext: ContextManager.sharedInstance().mainContext)
        service.findExistingAccountByEmail(email,
            success: { [weak self] in
                self?.emailValidationSuccessCallback?(email)
                self?.setLoading(false)
            }, failure: { [weak self] (error: NSError!) in
                DDLogSwift.logError(error.localizedDescription)
                self?.emailValidationFailureCallback?(email)
                self?.setLoading(false)                
        })
    }


    private func setLoading(loading: Bool) {
        emailTextField.enabled = !loading
        submitButton.enabled = !loading
        submitButton.showActivityIndicator(loading)
    }



    // MARK: - Actions


    @IBAction func handleSubmitTapped() {
        if let email = emailTextField.text  {
            checkEmailAddress(email)
        }
    }


    @IBAction private func handleOnePasswordButtonTapped(sender: UIButton) {
        print("1Password button tapped")
    }

}

extension SigninEmailViewController : SigninChildViewController {
    var backButtonEnabled: Bool {
        return true
    }
    
    var loginFields: LoginFields? {
        get {
            return LoginFields(username: emailTextField.text, password: nil, siteUrl: nil, multifactorCode: nil, userIsDotCom: true, shouldDisplayMultiFactor: false)
        }
        set {}
    }
}
