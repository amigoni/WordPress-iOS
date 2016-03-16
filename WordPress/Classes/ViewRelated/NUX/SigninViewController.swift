import UIKit
import NSURL_IDN
import WordPressComAnalytics
import wpxmlrpc

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
    @IBOutlet var backButton: UIButton!
    @IBOutlet var cancelButton: UIButton!
    @IBOutlet var wpcomSigninButton: UIButton!
    @IBOutlet var selfHostedSigninButton: UIButton!
    @IBOutlet var createAccountButton: UIButton!
    var pageViewController: UIPageViewController!

    let loginFields = LoginFields()
    var autofilledUsernameCredentailHash: Int?
    var autofilledPasswordCredentailHash: Int?

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

        presentWPComSigninFlow()

        autoFillLoginWithSharedWebCredentialsIfAvailable()
    }
    

    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return .LightContent
    }


    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        pageViewController = segue.destinationViewController as? UIPageViewController
    }


    // MARK: Setup and Configuration


    // Sign up flow entry points.

    // Default flow. Sign into wpcom begining with their email address.
    func presentWPComSigninFlow() {
        wpcomSigninButton.hidden = true
        selfHostedSigninButton.hidden = false
        createAccountButton.hidden = false

        showSigninEmailViewController()
    }


    // Sign in to a self hosted blog
    func presentSelfHostedSigninFlow() {
        wpcomSigninButton.hidden = false
        selfHostedSigninButton.hidden = true
        createAccountButton.hidden = false

        showSelfHostedSignInViewController("")
    }


    // Create a new wpcom account and blog
    func presentCreateAccountFlow() {
        wpcomSigninButton.hidden = false
        selfHostedSigninButton.hidden = false
        createAccountButton.hidden = true

        // TODO:
        let controller = CreateAccountAndBlogViewController()
        navigationController?.pushViewController(controller, animated: true)
    }


    // Handle returning to the app after obtaining a "magic" auth link
    func presentLinkValidationFlow() {
        wpcomSigninButton.hidden = false
        selfHostedSigninButton.hidden = false
        createAccountButton.hidden = false

        showSigninLinkRequestViewController("")
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


    /// Call this as the final step in any sign up flow.
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


    /// Displays the support vc.
    ///
    func displaySupportViewController() {
        let controller = SupportViewController()
        let navController = UINavigationController(rootViewController: controller)
        navController.navigationBar.translucent = false
        navController.modalPresentationStyle = .FormSheet

        navigationController?.presentViewController(navController, animated: true, completion: nil)
    }


    /// Displays the Helpshift conversation feature.
    ///
    func displayHelpshiftConversationView() {
        let metaData = [
            "Source": "Failed login",
            "Username": loginFields.username,
            "SiteURL": loginFields.siteUrl
        ]
        HelpshiftSupport.showConversation(self, withOptions: [HelpshiftSupportCustomMetadataKey: metaData])
        WPAppAnalytics.track(.SupportOpenedHelpshiftScreen)
    }


    /// Presents an instance of WPWebViewController set to the specified URl. 
    /// Accepts a username and password if authentication is needed. 
    ///
    /// - Parameters:
    ///     - url: The URL to view.
    ///     - username: Optional. A username if authentication is needed. 
    ///     - password: Optional. A password if authentication is needed.
    ///
    func displayWebviewForURL(url: NSURL, username: String?, password: String?) {
        let controller = WPWebViewController(URL: url)

        if let username = username,
            password = password
        {
            controller.username = username
            controller.password = password
        }
        let navController = UINavigationController(rootViewController: controller)
        navigationController?.presentViewController(navController, animated: true, completion: nil)
    }


    /// The base site URL path derived from `loginFields.siteUrl`
    ///
    /// - Returns: The base url path or an empty string.
    ///
    func baseSiteURL() -> String {
        guard let siteURL = NSURL(string: NSURL.IDNDecodedURL(loginFields.siteUrl)) else {
            return ""
        }

        var path = siteURL.absoluteString.lowercaseString

        if path.isWordPressComPath() {
            if siteURL.scheme.characters.count == 0 {
                path = "https://\(path)"
            } else if path.rangeOfString("http://") != nil {
                path = path.stringByReplacingOccurrencesOfString("http://", withString: "https://")
            }
        } else if siteURL.scheme.characters.count == 0 {
            path = "http://\(path)"
        }

        let wpLogin = try! NSRegularExpression(pattern: "/wp-login.php$", options: .CaseInsensitive)
        let wpadmin = try! NSRegularExpression(pattern: "/wp-admin/?$", options: .CaseInsensitive)
        let trailingSlash = try! NSRegularExpression(pattern: "/?$", options: .CaseInsensitive)

        path = wpLogin.stringByReplacingMatchesInString(path, options: .ReportCompletion, range: NSRange(location: 0, length: path.characters.count), withTemplate: "")
        path = wpadmin.stringByReplacingMatchesInString(path, options: .ReportCompletion, range: NSRange(location: 0, length: path.characters.count), withTemplate: "")
        path = trailingSlash.stringByReplacingMatchesInString(path, options: .ReportCompletion, range: NSRange(location: 0, length: path.characters.count), withTemplate: "")
        
        return path
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

        setChildViewController(controller)
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
        setChildViewController(controller)
    }


    /// Shows the self hosted form which includes, username/email, password and url fields.
    ///
    /// - Parameters:
    ///     - email: The user's email address.
    ///
    func showSelfHostedSignInViewController(email: String) {
        let controller = SigninSelfHostedViewController.controller(email,
            success: { [weak self] in
                self?.finishSignIn()
                self?.dismissViewControllerAnimated(true, completion: nil)
            },
            failure: { [weak self] error in
                if error is NSError {
                    self?.displayError(error as NSError)
                    return
                }

                switch (error as! SigninFailureError) {
                case .NeedsMultifactorCode:
                    if let currentChild = self?.currentChildViewController as? SigninChildViewController,
                        let loginFields = currentChild.loginFields {
                            self?.showSignin2FAViewController(loginFields)
                    }
                }
            })

        setChildViewController(controller)
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
        presentCreateAccountFlow()
    }


    @IBAction func handleWPComSigninButtonTapped(sender: UIButton) {
        presentWPComSigninFlow()
    }


    @IBAction func handleSelfHostedSigninButtonTapped(sender: UIButton) {
        presentSelfHostedSigninFlow()
    }


    @IBAction func handleHelpTapped(sender: UIButton) {
        displaySupportViewController()
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


    // MARK: - Error Handling


    typealias OverlayViewCallback = ((WPWalkthroughOverlayView!) -> Void)


    /// Displays an instance of WPWalkthroughOverlayView configured to show an error message.
    /// 
    /// - Parameters:
    ///     - message: The error message to display to the user. 
    ///     - firstButtonText: Optional. The label for the bottom right button.
    ///     - firstButtonCallback: Optional. The callback block to execute when the first button is tapped.
    ///     - secondButtonText: Optional. The label for the bottom left button.
    ///     - secondButtonCallback: The callback block to execute when the second button is tapped.
    ///     - accessibilityIdentifier: Optional. Used to identify the view to accessibiity features.
    ///
    func displayOverlayView(message: String, firstButtonText: String?, firstButtonCallback: OverlayViewCallback?, secondButtonText: String?, secondButtonCallback: OverlayViewCallback, accessibilityIdentifier: String?) {
        assert(message.characters.count > 0)

        let dismissBlock: OverlayViewCallback = { (overlayView) in
            overlayView.dismiss()
        }

        let overlayView = WPWalkthroughOverlayView(frame: view.bounds)
        overlayView.overlayMode = .GrayOverlayViewOverlayModeTwoButtonMode
        overlayView.overlayTitle = NSLocalizedString("Sorry, we can't log you in.", comment: "")
        overlayView.overlayDescription = message
        overlayView.primaryButtonText = NSLocalizedString("OK", comment: "")
        overlayView.secondaryButtonText = NSLocalizedString("Need Help?", comment: "")
        overlayView.dismissCompletionBlock = dismissBlock
        overlayView.primaryButtonCompletionBlock = dismissBlock
        overlayView.secondaryButtonCompletionBlock = secondButtonCallback

        if firstButtonText != nil {
            overlayView.primaryButtonText = firstButtonText!
        }

        if secondButtonText != nil {
            overlayView.secondaryButtonText = secondButtonText!
        }

        if firstButtonCallback != nil {
            overlayView.primaryButtonCompletionBlock = firstButtonCallback!
        }

        if let accessibilityIdentifier = accessibilityIdentifier {
            overlayView.accessibilityIdentifier = accessibilityIdentifier
        }

        overlayView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(overlayView)
        view.pinSubviewToAllEdges(overlayView)
    }


    /// Display the specified error in a WPWalkthroughOverlayView. 
    /// The view is configured differently depending on the kind of error.
    ///
    /// - Parameters:
    ///     - error: An NSError instance
    ///
    func displayError(error: NSError) {
        var message = error.localizedDescription

        DDLogSwift.logError(message)

        if error.domain != WPXMLRPCFaultErrorDomain && error.code != NSURLErrorBadURL {
            if HelpshiftUtils.isHelpshiftEnabled() {
                displayGenericErrorMessageWithHelpshiftButton(message)

            } else {
                displayGenericErrorMessage(message)
            }
            return
        }

        if error.code == 403 {
            message = NSLocalizedString("Incorrect username or password. Please try entering your login details again.", comment: "")
        }

        if message.trim().characters.count == 0 {
            message = NSLocalizedString("Sign in failed. Please try again.", comment: "")
        }

        if error.code == 405 {
            displayErrorMessageForXMLRPC(message)
        } else  if error.code == NSURLErrorBadURL {
            displayErrorMessageForBadURL(message)
        } else {
            displayGenericErrorMessage(message)
        }
    }


    /// Shows a WPWalkthroughOverlayView for a generic error message.
    ///
    /// - Parameters:
    ///     - message: The error message to show.
    ///
    func displayGenericErrorMessage(message: String) {
        let callback: OverlayViewCallback = { [weak self] (overlayView) in
            overlayView.dismiss()
            self?.displaySupportViewController()
        }

        displayOverlayView(message,
            firstButtonText: nil,
            firstButtonCallback: nil,
            secondButtonText: nil,
            secondButtonCallback: callback,
            accessibilityIdentifier: "GenericErrorMessage")
    }


    /// Shows a WPWalkthroughOverlayView for a generic error message. The view
    /// is configured so the user can open Helpshift for assistance.
    ///
    /// - Parameters:
    ///     - message: The error message to show.
    ///
    func displayGenericErrorMessageWithHelpshiftButton(message: String) {
        let callback: OverlayViewCallback = { [unowned self] (overlayView) in
            overlayView.dismiss()
            self.displayHelpshiftConversationView()
        }

        displayOverlayView(message,
            firstButtonText: nil,
            firstButtonCallback: nil,
            secondButtonText: NSLocalizedString("Contact Us", comment:"The text on the button at the bottom of the error message when a user has repeated trouble logging in"),
            secondButtonCallback: callback,
            accessibilityIdentifier: "GenericErrorMessage")
    }


    /// Shows a WPWalkthroughOverlayView for an XML-RPC error message.
    ///
    /// - Parameters:
    ///     - message: The error message to show.
    ///
    func displayErrorMessageForXMLRPC(message: String) {
        let firstCallback: OverlayViewCallback = { [unowned self] (overlayView) in
            overlayView.dismiss()

            var path: NSString
            let regex = try! NSRegularExpression(pattern: "http\\S+writing.php", options: .CaseInsensitive)
            let rng = regex.rangeOfFirstMatchInString(message, options: .ReportCompletion, range: NSRange(location: 0, length: message.characters.count))
            if rng.location == NSNotFound {
                path = self.baseSiteURL()
                path = path.stringByReplacingOccurrencesOfString("xmlrpc.php", withString: "")
                path = path.stringByAppendingString("/wp-admin/options-writing.php")
            } else {
                path = NSString(string: message).substringWithRange(rng)
            }

            self.displayWebviewForURL(NSURL(string: path as String)!, username: self.loginFields.username, password: self.loginFields.password)
        }

        let secondCallback: OverlayViewCallback = { [unowned self] (overlayView) in
            overlayView.dismiss()
            self.displaySupportViewController()
        }

        displayOverlayView(message,
            firstButtonText: NSLocalizedString("Enable Now", comment: ""),
            firstButtonCallback: firstCallback,
            secondButtonText: nil,
            secondButtonCallback: secondCallback,
            accessibilityIdentifier: nil)
    }


    /// Shows a WPWalkthroughOverlayView for a bad url error message.
    ///
    /// - Parameters:
    ///     - message: The error message to show.
    ///
    func displayErrorMessageForBadURL(message: String) {
        let callback: OverlayViewCallback = { [unowned self] (overlayView) in
            overlayView.dismiss()
            self.displayWebviewForURL(NSURL(string: "https://apps.wordpress.org/support/#faq-ios-3")!, username: nil, password: nil)
        }

        displayOverlayView(message,
            firstButtonText: nil,
            firstButtonCallback: nil,
            secondButtonText: nil,
            secondButtonCallback: callback,
            accessibilityIdentifier: nil)
    }


    // MARK: - Child Controller Wrangling


    ///
    ///
    func setChildViewController(viewController: UIViewController) {
        let animated = childViewControllerStack.count > 1
        childViewControllerStack.removeAll()
        childViewControllerStack.append(viewController)
        viewController.view.layoutIfNeeded()
        pageViewController.setViewControllers([childViewControllerStack.last!],
            direction: .Reverse,
            animated: animated,
            completion: nil)
    }


    ///
    ///
    func pushChildViewController(viewController: UIViewController, animated: Bool) {
        childViewControllerStack.append(viewController)
        viewController.view.layoutIfNeeded()
        pageViewController.setViewControllers([childViewControllerStack.last!],
            direction: .Forward,
            animated: animated,
            completion: nil)
        
        configureBackAndCancelButtons(animated)
    }


    ///
    ///
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


    // MARK: - Shared Web Credentials

    typealias SharedWebCredentialsCallback = ((username: String?, password: String?) -> Void)
    typealias SecRequestCompletionHandler = ((credentials: CFArray?, error: CFError?) -> Void)

    var shouldAvoidRequestingSharedCredentials = false
    let LoginSharedWebCredentialFQDN: CFString = "wordpress.com"


    /// Attempt to auto fill credentials.
    ///
    func autoFillLoginWithSharedWebCredentialsIfAvailable() {
        // TODO: Need to show a spinner if this is called as the first step in the login flow.
        requestSharedWebCredentials { [unowned self] (username, password) -> Void in
            guard let username = username, password = password else {
                return
            }

            // Update the login fields
            self.loginFields.username = username
            self.loginFields.password = password

            // Persist credentials as autofilled credentials so we can update them later if needed.
            self.autofilledUsernameCredentailHash = username.hash
            self.autofilledPasswordCredentailHash = password.hash

            // TOOD: show the wpcom login form.


            WPAppAnalytics.track(WPAnalyticsStat.SafariCredentialsLoginFilled)
        }
    }


    /// Update safari stored credentials.
    ///
    /// - Parameters:
    ///     - username: 
    ///     - password:
    ///
    func updateAutoFillLoginCredentialsIfNeeded(username: String, password: String) {
        // Don't try and update credentials for self-hosted.
        if !loginFields.userIsDotCom {
            return;
        }

        // If the user changed screen names, don't try and update/create a new shared web credential.
        // We'll let Safari handle creating newly saved usernames/passwords.
        if autofilledUsernameCredentailHash != loginFields.username.hash {
            return
        }

        // If the user didn't change the password from previousl filled password no update is needed.
        if autofilledPasswordCredentailHash == loginFields.password.hash {
            return
        }

        // Update the shared credential
        let username: CFString = loginFields.username
        let password: CFString = loginFields.password

        SecAddSharedWebCredential(LoginSharedWebCredentialFQDN, username, password, { (error: CFError?) in
            guard error == nil else {
                let err = error! as NSError
                DDLogSwift.logError("Error occurred updating shared web credential: \(err.localizedDescription)");
                return
            }
            dispatch_async(dispatch_get_main_queue(), {
                WPAppAnalytics.track(WPAnalyticsStat.SafariCredentialsLoginUpdated)
            })
        })
    }


    /// Request shared safari credentials if they exist.
    ///
    /// - Parameters:
    ///     - completion: A completion block.
    ///
    func requestSharedWebCredentials(completion: SharedWebCredentialsCallback) {
        if shouldAvoidRequestingSharedCredentials {
            return
        }

        shouldAvoidRequestingSharedCredentials = true
        SecRequestSharedWebCredential(LoginSharedWebCredentialFQDN, nil, { (credentials: CFArray?, error: CFError?) in

            guard error == nil else {
                let err = error! as NSError
                DDLogSwift.logError("Completed requesting shared web credentials with: \(err.localizedDescription)")
                dispatch_async(dispatch_get_main_queue(), {
                    completion(username: nil, password: nil)
                })
                return
            }

            guard let credentials = credentials where CFArrayGetCount(credentials) > 0 else {
                // Did not find a shared web credential.
                return
            }

            // What a chore!
            let unsafeCredentials = CFArrayGetValueAtIndex(credentials, 0)
            let credentialsDict = unsafeBitCast(unsafeCredentials, CFDictionaryRef.self)

            let unsafeUsername = CFDictionaryGetValue(credentialsDict, unsafeAddressOf(kSecAttrAccount))
            let usernameStr = unsafeBitCast(unsafeUsername, CFString.self) as String

            let unsafePassword = CFDictionaryGetValue(credentialsDict, unsafeAddressOf(kSecSharedPassword))
            let passwordStr = unsafeBitCast(unsafePassword, CFString.self) as String

            dispatch_async(dispatch_get_main_queue(), {
                completion(username: usernameStr, password: passwordStr)
            })
        })

    }


    //MARK: - 1Password Support


    /// Displays an alert prompting that a site address is needed before 1Password can be used.
    ///
    func displayOnePasswordEmptySiteAlert() {
        let message = NSLocalizedString("A site address is required before 1Password can be used.",
            comment: "Error message displayed when the user is Signing into a self hosted site and tapped the 1Password Button before typing his siteURL")

        let alertController = UIAlertController(title: nil, message: message, preferredStyle: .Alert)
        alertController.addCancelActionWithTitle(NSLocalizedString("Accept", comment: "Accept Button Title"), handler: nil)

        presentViewController(alertController, animated: true, completion: nil)
    }


    /// Handle a one password request.
    ///
    /// - Parameters:
    ///     - sender: A UIView. Typically the button the user tapped on.
    ///
    func handleOnePasswordButtonTapped(sender: UIView) {
        view.endEditing(true)

        if loginFields.userIsDotCom == false && loginFields.siteUrl.isEmpty {
            displayOnePasswordEmptySiteAlert()
            return
        }

        let loginURL = loginFields.userIsDotCom ? "wordpress.com" : loginFields.siteUrl

        let onePasswordFacade = OnePasswordFacade()
        onePasswordFacade.findLoginForURLString(loginURL, viewController: self, sender: sender, completion: { (username: String!, password: String!, oneTimePassword: String!, error: NSError!) in
            guard error == nil else {
                DDLogSwift.logError("OnePassword Error: \(error.localizedDescription)")
                WPAppAnalytics.track(.OnePasswordFailed)
                return
            }

            guard let username = username, password = password else {
                return
            }

            if username.characters.count == 0 || password.characters.count == 0 {
                return
            }

            self.loginFields.username = username
            self.loginFields.password = password
            self.loginFields.multifactorCode = oneTimePassword

            WPAppAnalytics.track(.OnePasswordLogin)

            // TODO: sign in
        })

    }

}
