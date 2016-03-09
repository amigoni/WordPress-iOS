import UIKit

enum SigninFailureError: ErrorType {
    case NeedsMultifactorCode
}

typealias SigninCallbackBlock = () -> Void
typealias SigninSuccessBlock = () -> Void
typealias SigninFailureBlock = (error: ErrorType) -> Void

/// This is the starting point for signing into the app. The SigninViewController acts
/// as the parent view control, loading and displaying child view controllers that
/// hanadle each step in the signin flow.
/// It is expected that the controller will always be presented modally.
///
class SigninViewController : UIViewController
{
    @IBOutlet var containerView: UIView!
    @IBOutlet var helpButton: UIButton!
    @IBOutlet var backButton: UIButton!
    @IBOutlet var cancelButton: UIButton!
    @IBOutlet var icon: UIImageView!
    @IBOutlet var toggleSigninButton: UIButton!
    @IBOutlet var createAccountButton: UIButton!

    var pageViewController: UIPageViewController!
    
    // This key is used with NSUserDefaults to persist an email address while the
    // app is suspended and the mail app is launched.
    let AuthenticationEmailKey = "AuthenticationEmailKey"

    var childViewControllerStack = [UIViewController]()
    
    private var currentChildViewController: UIViewController? {
        return childViewControllerStack.last
    }


    /// A convenience method for instanciating an instance of the controller from
    /// the storyboard.
    ///
    class func controller(params: NSDictionary) -> SigninViewController {
        let storyboard = UIStoryboard(name: "Signin", bundle: NSBundle.mainBundle())
        let controller = storyboard.instantiateViewControllerWithIdentifier("SigninViewController") as! SigninViewController

        return controller
    }


    // MARK: - Lifecycle Methods


    override func viewDidLoad() {
        super.viewDidLoad();
        navigationController?.navigationBarHidden = true

        backButton.sizeToFit()
        cancelButton.sizeToFit()
        configureBackAndCancelButtons(false)

        initializePageViewController()
        
        showSigninEmailViewController()
    }
    

    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return .LightContent
    }


    // MARK: Setup and Configuration


    ///
    ///
    func initializePageViewController() {
        pageViewController = UIPageViewController(transitionStyle: .Scroll, navigationOrientation: .Horizontal, options: nil)
        addChildViewController(pageViewController)
        containerView.addSubview(pageViewController.view)
        pageViewController.view.translatesAutoresizingMaskIntoConstraints = false
        pageViewController.didMoveToParentViewController(self)
        
        containerView.pinSubviewToAllEdges(pageViewController.view)
    }


    /// Configure the presense of the back and cancel buttons. Optionally animated.
    ///
    /// - Parameters: 
    ///     - animated: Whether a change to the presense of the back or cancel buttons
    /// should be animated.
    ///
    func configureBackAndCancelButtons(animated: Bool) {
        // We want to show a cancel button if there is already a blog or wpcom account,
        // but only on the first "screen". 
        // Otherwise we want to show a back button if the child VC allows it, and no
        // previous child vcs disallow it (no going back once you have a blocking action).
        // Nicely transition the alpha and visibility of the buttons.

        var buttonToShow: UIButton?
        var buttonsToHide = [UIButton]()

        if childViewControllerStack.count == 1 && isCancellable() {
            buttonToShow = cancelButton
            buttonsToHide.append(backButton)

        } else if childViewControllerStack.count > 1 && shouldShowBackButton() {
            buttonToShow = backButton
            buttonsToHide.append(cancelButton)

        } else {
            buttonsToHide.append(cancelButton)
            buttonsToHide.append(backButton)
        }

        if !animated {
            buttonToShow?.alpha = 1.0
            buttonToShow?.hidden = false
            for button in buttonsToHide {
                button.hidden = true
                button.alpha = 0.0
            }
            return
        }

        buttonToShow?.hidden = false
        UIView.animateWithDuration(0.2,
            animations: {
                buttonToShow?.alpha = 1.0
                for button in buttonsToHide {
                    button.alpha = 0.0
                }
            },
            completion: { (completed) in
                for button in buttonsToHide {
                    button.hidden = true
                }
        })
    }


    // MARK: - Instance Methods


    /// Checks if the signin vc modal should show a back button. The back button 
    /// visible when there is more than one child vc presented, and there is not
    /// a case where a `SigninChildViewController.backButtonEnabled` in the stack 
    /// returns false.
    ///
    /// - Returns: True if the back button should be visible. False otherwise.
    ///
    func shouldShowBackButton() -> Bool {
        for childController in childViewControllerStack {
            if let controller = childController as? SigninChildViewController {
                if !controller.backButtonEnabled {
                    return false
                }
            }
        }
        return true
    }


    /// Checks if the signin vc modal should be cancellable. The controller is
    /// cancellable when there is a default wpcom account, or at least one 
    /// self-hosted blog.
    ///
    /// - Returns: True if cancellable. False otherwise. 
    ///
    func isCancellable() -> Bool {
        // if there is an existing blog, or an existing account return true.
        let context = ContextManager.sharedInstance().mainContext
        let blogService = BlogService(managedObjectContext: context)
        let accountService = AccountService(managedObjectContext: context)

        return accountService.defaultWordPressComAccount() != nil || blogService.blogCountForAllAccounts() > 0
    }


    /// Call this method passing a one-time token to sign in to wpcom.
    ///
    /// - Parameters:
    ///     - token: A one time authentication token that is used in lieu of a password.
    ///
    func authenticateWithToken(token: String) {
        // retrieve email from nsdefaults
        guard let email = NSUserDefaults.standardUserDefaults().stringForKey(AuthenticationEmailKey) else {
            showSigninEmailViewController()
            return
        }

        showLinkAuthController(email, token: token)
    }


    ///
    ///
    private func finishSignIn() {
        // Check if there is an active WordPress.com account. If not, switch tab bar
        // away from Reader to blog list view
        let context = ContextManager.sharedInstance().mainContext
        let accountService = AccountService(managedObjectContext: context)
        let defaultAccount = accountService.defaultWordPressComAccount()
        
        if defaultAccount == nil {
            WPTabBarController.sharedInstance().showMySitesTab()
        }
    }


    // MARK: - Controller Factories


    /// Shows the email form.  This is the first step
    /// in the signin flow.
    ///
    func showSigninEmailViewController() {
        let controller = SigninEmailViewController.controller({ [weak self] email in
                self?.emailValidationSuccess(email)
            },
            failure: { [weak self] email in
                self?.emailValidationFailure(email)
            })

        pushChildViewController(controller, animated: false)
    }


    /// Shows the password form.
    ///
    /// - Parameters:
    ///     - email: The user's email address.
    ///
    func showSigninPasswordViewController(email: String) {
        let controller = SigninPasswordViewController.controller(email, success: { [weak self] in
                self?.finishSignIn()
                self?.dismissViewControllerAnimated(true, completion: nil)
            },
            failure: { [weak self] error in
                switch (error as! SigninFailureError) {
                case .NeedsMultifactorCode:
                    if let currentChild = self?.currentChildViewController as? SigninChildViewController,
                        let loginFields = currentChild.loginFields {
                        self?.showSignin2FAViewController(loginFields)
                    }
                }
                
                DDLogSwift.logError("Error: \(error)")
            })
        
        pushChildViewController(controller, animated: true)
    }


    /// Shows the 2FA form.
    ///
    func showSignin2FAViewController(loginFields: LoginFields) {
        let controller = SignIn2FAViewController.controller(loginFields, success:  { [weak self] in
            self?.finishSignIn()
            self?.dismissViewControllerAnimated(true, completion: nil)
        })
        
        pushChildViewController(controller, animated: true)
    }


    /// Shows the "email link" form.
    ///
    /// - Parameters:
    ///     - email: The user's email address.
    ///
    func showSigninLinkRequestViewController(email: String) {
        let controller = SigninLinkRequestViewController.controller(email,
            requestLinkBlock: {  [weak self] in
                self?.didRequestAuthenticationLink(email)
            },
            signinWithPasswordBlock: { [weak self] in
                self?.signinWithPassword(email)
            })

        pushChildViewController(controller, animated: true)
    }


    /// Shows the self hosted form which includes, username/email, password and url fields.
    ///
    /// - Parameters:
    ///     - email: The user's email address.
    ///
    func showSelfHostedSignInViewController(email: String) {
        let controller = SigninSelfHostedViewController.controller(email, success: { [weak self] in
            self?.finishSignIn()
            self?.dismissViewControllerAnimated(true, completion: nil)
        }, failure: { [weak self] error in
            switch (error as! SigninFailureError) {
            case .NeedsMultifactorCode:
                if let currentChild = self?.currentChildViewController as? SigninChildViewController,
                    let loginFields = currentChild.loginFields {
                        self?.showSignin2FAViewController(loginFields)
                }
            }
            
            DDLogSwift.logError("Error: \(error)")
        })
        
        pushChildViewController(controller, animated: true)
    }


    /// Shows the "open mail" form.
    ///
    /// - Parameters:
    ///     - email: The user's email address.
    ///
    func showLinkMailViewController(email: String) {
        // Save email in nsuserdefaults and retrieve it if necessary
        NSUserDefaults.standardUserDefaults().setObject(email, forKey: AuthenticationEmailKey)

        let controller = SigninLinkMailViewController.controller(email, skipBlock: {[weak self] in
            self?.signinWithPassword(email)
        })

        pushChildViewController(controller, animated: true)
    }


    /// Shows the "magic link" authentication form. This is basically a progress
    /// indicator while signin in the user.
    ///
    /// - Parameters:
    ///     - email: The user's email address.
    ///     - token: A one time authentication token that is used in lieu of a password.
    ///
    func showLinkAuthController(email: String, token: String) {
        let controller = SigninLinkAuthViewController.controller(email,
            token: token,
            successCallback: { [weak self] in
                self?.dismissViewControllerAnimated(true, completion: nil)
            },
            failureCallback: {
                // TODO: handle auth failure callback
        })
        pushChildViewController(controller, animated: true)
    }


    // MARK: - Child Controller Callbacks


    func emailValidationSuccess(email: String) {
        showSigninLinkRequestViewController(email)
    }

    func emailValidationFailure(email: String) {
        showSelfHostedSignInViewController(email)
    }
    
    func didRequestAuthenticationLink(email: String) {
        showLinkMailViewController(email)
    }

    func signinWithPassword(email: String) {
        showSigninPasswordViewController(email)
    }


    // MARK: - Actions

    @IBAction func handleCreateAccountTapped(sender: UIButton) {
        let controller = CreateAccountAndBlogViewController()
        navigationController?.pushViewController(controller, animated: true)
    }


    @IBAction func handleToggleSigninTapped(sender: UIButton) {
        let storyboard = UIStoryboard(name: "Signin", bundle: NSBundle.mainBundle())
        let vc = storyboard.instantiateViewControllerWithIdentifier("SigninSelfHostedViewController")
        pushChildViewController(vc, animated: true)

    }


    @IBAction func handleHelpTapped(sender: UIButton) {
        let controller = SupportViewController()
        let navController = UINavigationController(rootViewController: controller)
        navController.navigationBar.translucent = false
        navController.modalPresentationStyle = .FormSheet

        navigationController?.presentViewController(navController, animated: true, completion: nil)
    }


    @IBAction func handleBackgroundViewTapGesture(tgr: UITapGestureRecognizer) {
        view.endEditing(true)
    }


    @IBAction func handleBackButtonTapped(sender: UIButton) {
        popChildViewController(true)
    }


    @IBAction func handleCancelButtonTapped(sender: UIButton) {
        dismissViewControllerAnimated(true, completion: nil)
    }


    // MARK: - Child Controller Wrangling

    func pushChildViewController(viewController: UIViewController, animated: Bool) {
        childViewControllerStack.append(viewController)
        viewController.view.layoutIfNeeded()
        pageViewController.setViewControllers([childViewControllerStack.last!],
            direction: .Forward, animated: animated, completion: nil)
        
        configureBackAndCancelButtons(animated)
    }
    
    func popChildViewController(animated: Bool) {
        // Keep at least one child vc. 
        guard childViewControllerStack.count > 1 else {
            return
        }

        childViewControllerStack.removeLast()
        
        if let previousChild = childViewControllerStack.last {
            pageViewController.setViewControllers([previousChild], direction: .Reverse, animated: animated, completion: nil)
            
            configureBackAndCancelButtons(animated)
        }
    }
}
