//
//  JetpackSettingsViewControllerNew.m
//  WordPress
//
//  Created by Leonardo Amigoni on 3/24/16.
//  Copyright © 2016 WordPress. All rights reserved.
//
#import "JetpackSettingsViewController.h"
#import "Blog.h"
#import "WordPressComApi.h"
#import "WPWebViewController.h"
#import "WPAccount.h"
#import "WPNUXUtility.h"
#import "UILabel+SuggestSize.h"
#import "NSAttributedString+Util.h"
#import "WordPressComOAuthClient.h"
#import "AccountService.h"
#import "BlogService.h"
#import "JetpackService.h"
#import "ContextManager.h"



#pragma mark ====================================================================================
#pragma mark Constants
#pragma mark ====================================================================================

static NSString *JetpackInstallRelativePath                 = @"plugin-install.php?tab=plugin-information&plugin=jetpack";
static NSString *JetpackMoreInformationURL                  = @"https://apps.wordpress.org/support/#faq-ios-15";
/*
static CGFloat const JetpackiOS7StatusBarOffset             = 20.0;
static CGFloat const JetpackStandardOffset                  = 16;
static CGFloat const JetpackTextFieldWidth                  = 320.0;
static CGFloat const JetpackMaxTextWidth                    = 289.0;
static CGFloat const JetpackTextFieldHeight                 = 44.0;
static CGFloat const JetpackIconVerticalOffset              = 77;
static CGFloat const JetpackSignInButtonWidth               = 289.0;
static CGFloat const JetpackSignInButtonHeight              = 41.0;

static NSTimeInterval const JetpackAnimationDuration        = 0.3f;
*/
static CGFloat const JetpackTextFieldAlphaHidden            = 0.0f;
static CGFloat const JetpackTextFieldAlphaDisabled          = 0.5f;
static CGFloat const JetpackTextFieldAlphaEnabled           = 1.0f;

static NSInteger const JetpackVerificationCodeNumberOfLines = 2;

#pragma mark ====================================================================================
#pragma mark Private
#pragma mark ====================================================================================

@interface JetpackSettingsViewController () <UITextFieldDelegate, UIGestureRecognizerDelegate>

@property (nonatomic, strong) Blog                      *blog;
@property (nonatomic, assign) CGFloat                   keyboardOffset;
@property (nonatomic, assign) BOOL                      authenticating;
@property (nonatomic, assign) BOOL                      shouldDisplayMultifactor;
@property (weak, nonatomic) UITextField *activeField;

@end


#pragma mark ====================================================================================
#pragma mark JetpackSettingsViewController
#pragma mark ====================================================================================


@implementation JetpackSettingsViewController

- (instancetype)initWithBlog:(Blog *)blog
{
    self = [self init];
    if (self) {
        _blog = blog;
        _showFullScreen = YES;
    }
    return self;
}

- (void)setBlog:(Blog *)blog
{
    _blog = blog;
    _showFullScreen = YES;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (BOOL)hidesBottomBarWhenPushed
{
    return YES;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
}

#pragma mark - LifeCycle Methods

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self.navigationController setNavigationBarHidden:self.showFullScreen animated:animated];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    [self reloadInterface];
    [self updateForm];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [self checkForJetpack];
}

- (void)viewDidLoad
{
    DDLogMethod();
    [super viewDidLoad];
    
    self.title = NSLocalizedString(@"Jetpack Connect", @"");
    self.view.backgroundColor = [WPStyleGuide itsEverywhereGrey];
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [nc addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    
    [nc addObserver:self selector:@selector(textFieldDidChangeNotificationReceived:) name:UITextFieldTextDidChangeNotification object:self.usernameTextField];
    [nc addObserver:self selector:@selector(textFieldDidChangeNotificationReceived:) name:UITextFieldTextDidChangeNotification object:self.passwordTextField];
    
    [self configureControls];
    [self addGesturesRecognizer];
    [self addSkipButtonIfNeeded];
}

- (void)configureControls
{
    // Add Description
    self.descriptionLabel.backgroundColor = [UIColor clearColor];
    self.descriptionLabel.textAlignment = NSTextAlignmentCenter;
    self.descriptionLabel.font = [WPNUXUtility descriptionTextFont];
    self.descriptionLabel.text = NSLocalizedString(@"Hold the web in the palm of your hand. Full publishing power in a pint-sized package.", @"NUX First Walkthrough Page 1 Description");
    self.descriptionLabel.textColor = [WPStyleGuide allTAllShadeGrey];
    
    // Add Username
    [self.usernameTextField configureTextField];
    UIImage *iconUserName = [UIImage imageNamed:@"icon-username-field"];
    self.usernameTextField.leftViewImage = iconUserName;
    self.usernameTextField.leftView = [[UIImageView alloc] initWithImage:iconUserName];
    self.usernameTextField.leftViewMode = UITextFieldViewModeAlways;
   
    self.usernameTextField.backgroundColor = [UIColor whiteColor];
    self.usernameTextField.placeholder = NSLocalizedString(@"WordPress.com username", @"");
    self.usernameTextField.font = [WPNUXUtility textFieldFont];
    self.usernameTextField.adjustsFontSizeToFitWidth = YES;
    self.usernameTextField.delegate = self;
    self.usernameTextField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.usernameTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.usernameTextField.text = self.blog.jetpack.connectedUsername;
    self.usernameTextField.clearButtonMode = UITextFieldViewModeWhileEditing;
   
    // Add Password
    [self.passwordTextField configureTextField];
    UIImage *iconPassword = [UIImage imageNamed:@"icon-password-field"];
    self.passwordTextField.leftViewImage = iconPassword;
    self.passwordTextField.leftView = [[UIImageView alloc] initWithImage:iconPassword];
    self.passwordTextField.leftViewMode = UITextFieldViewModeAlways;
    self.passwordTextField.backgroundColor = [UIColor whiteColor];
    self.passwordTextField.placeholder = NSLocalizedString(@"WordPress.com password", @"");
    self.passwordTextField.font = [WPNUXUtility textFieldFont];
    self.passwordTextField.delegate = self;
    self.passwordTextField.secureTextEntry = YES;
    self.passwordTextField.showSecureTextEntryToggle = YES;
    self.passwordTextField.text = @"";
    self.passwordTextField.clearsOnBeginEditing = YES;
    self.passwordTextField.showTopLineSeparator = YES;
    
    // Add Multifactor
    [self.multifactorTextField configureTextField];
    self.multifactorTextField.backgroundColor = [UIColor whiteColor];
    self.multifactorTextField.placeholder = NSLocalizedString(@"Verification Code", nil);
    self.multifactorTextField.font = [WPNUXUtility textFieldFont];
    self.multifactorTextField.delegate = self;
    self.multifactorTextField.keyboardType = UIKeyboardTypeNumberPad;
    self.multifactorTextField.textAlignment = NSTextAlignmentCenter;
    self.multifactorTextField.returnKeyType = UIReturnKeyDone;
    self.multifactorTextField.showTopLineSeparator = YES;
    self.multifactorTextField.accessibilityIdentifier = @"Verification Code";
    
    // Add Sign In Button
    [self.signInButton addTarget:self action:@selector(saveAction:) forControlEvents:UIControlEventTouchUpInside];
    self.signInButton.enabled = NO;
    
    // Text: Verification Code SMS
    NSString *codeText = NSLocalizedString(@"Enter the code on your authenticator app or ", @"Message displayed when a verification code is needed");
    NSMutableAttributedString *attributedCodeText = [[NSMutableAttributedString alloc] initWithString:codeText];
    
    NSString *smsText = NSLocalizedString(@"send the code via text message.", @"Sends an SMS with the Multifactor Auth Code");
    NSMutableAttributedString *attributedSmsText = [[NSMutableAttributedString alloc] initWithString:smsText];
    [attributedSmsText applyUnderline];
    
    [attributedCodeText appendAttributedString:attributedSmsText];
    [attributedCodeText applyFont:[WPNUXUtility confirmationLabelFont]];
    [attributedCodeText applyForegroundColor:[WPStyleGuide allTAllShadeGrey]];
    
    NSMutableAttributedString *attributedCodeHighlighted = [attributedCodeText mutableCopy];
    [attributedCodeHighlighted applyForegroundColor:[WPNUXUtility confirmationLabelColor]];
    
    // Add Verification Code SMS Button
    self.sendVerificationCodeButton.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.sendVerificationCodeButton.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.sendVerificationCodeButton.titleLabel.numberOfLines = JetpackVerificationCodeNumberOfLines;
    [self.sendVerificationCodeButton setAttributedTitle:attributedCodeText forState:UIControlStateNormal];
    [self.sendVerificationCodeButton setAttributedTitle:attributedCodeHighlighted forState:UIControlStateHighlighted];
    [self.sendVerificationCodeButton addTarget:self action:@selector(sendVerificationCode:) forControlEvents:UIControlEventTouchUpInside];
    
    // Add Download Button
    [self.installJetpackButton setTitle:NSLocalizedString(@"Install Jetpack", @"") forState:UIControlStateNormal];
    [self.installJetpackButton addTarget:self action:@selector(openInstallJetpackURL) forControlEvents:UIControlEventTouchUpInside];
    
    // Add More Information Button
    [self.moreInformationButton setTitle:NSLocalizedString(@"More information", @"") forState:UIControlStateNormal];
    [self.moreInformationButton addTarget:self action:@selector(openMoreInformationURL) forControlEvents:UIControlEventTouchUpInside];
    [self.moreInformationButton setTitleColor:[WPStyleGuide allTAllShadeGrey] forState:UIControlStateNormal];
    self.moreInformationButton.titleLabel.font = [WPNUXUtility confirmationLabelFont];
    
    // Add Skip Button (hidden if not fullscreen)
    [self.skipButton setTitle:NSLocalizedString(@"Skip", @"") forState:UIControlStateNormal];
    [self.skipButton setTitleColor:[WPStyleGuide allTAllShadeGrey] forState:UIControlStateNormal];
    [self.skipButton addTarget:self action:@selector(skipAction:) forControlEvents:UIControlEventTouchUpInside];
    self.skipButton.accessibilityIdentifier = @"Skip";
    [self.skipButton sizeToFit];
}

- (void)addGesturesRecognizer
{
    UITapGestureRecognizer *dismissKeyboardTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    dismissKeyboardTapRecognizer.cancelsTouchesInView = YES;
    dismissKeyboardTapRecognizer.delegate = self;
    [self.view addGestureRecognizer:dismissKeyboardTapRecognizer];
}

- (void)addSkipButtonIfNeeded
{

    if (!self.canBeSkipped) {
        return;
    }
    
    if (self.showFullScreen) {
        //Show skip button if fullscreen
        self.skipButton.hidden = NO;
    } else {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Skip", @"")
                                                                                  style:UIBarButtonItemStylePlain
                                                                                 target:self
                                                                                 action:@selector(skipAction:)];
    }
    
    self.navigationItem.hidesBackButton = YES;
}

#pragma mark Interface Helpers

- (void)updateSaveButton
{
    BOOL enabled = (!_authenticating && _usernameTextField.text.length && _passwordTextField.text.length);
    self.signInButton.enabled = enabled;
}

- (void)dismissKeyboard
{
    [self.view endEditing:YES];
    [self hideMultifactorTextfieldIfNeeded];
}

- (void)reloadInterface
{
    [self updateMessage];
    [self updateControls];
}

- (void)updateControls
{
    BOOL hasJetpack                         = [self canSetupJetpack];
    
    self.usernameTextField.alpha            = self.shouldDisplayMultifactor ? JetpackTextFieldAlphaDisabled : JetpackTextFieldAlphaEnabled;
    self.passwordTextField.alpha            = self.shouldDisplayMultifactor ? JetpackTextFieldAlphaDisabled : JetpackTextFieldAlphaEnabled;
    self.multifactorTextField.alpha         = self.shouldDisplayMultifactor ? JetpackTextFieldAlphaEnabled  : JetpackTextFieldAlphaHidden;
    
    self.usernameTextField.enabled          = !self.shouldDisplayMultifactor;
    self.passwordTextField.enabled          = !self.shouldDisplayMultifactor;
    self.multifactorTextField.enabled       = self.shouldDisplayMultifactor;
    
    self.usernameTextField.hidden           = !hasJetpack;
    self.passwordTextField.hidden           = !hasJetpack;
    self.multifactorTextField.hidden        = !hasJetpack;
    self.signInButton.hidden                = !hasJetpack;
    self.sendVerificationCodeButton.hidden  = !self.shouldDisplayMultifactor || self.authenticating;
    self.installJetpackButton.hidden        = hasJetpack;
    self.moreInformationButton.hidden       = hasJetpack;
    
    
    NSString *title = NSLocalizedString(@"Save", nil);
    if (_shouldDisplayMultifactor) {
        title = NSLocalizedString(@"Verify", nil);
    } else if (self.showFullScreen) {
        title = NSLocalizedString(@"Sign In", nil);
    }
    
    [self.signInButton setTitle:title forState:UIControlStateNormal];
    
}

- (BOOL)canSetupJetpack
{
    return self.blog.jetpack.isInstalled && self.blog.jetpack.isUpdatedToRequiredVersion;
}

#pragma mark - Button Helpers

- (IBAction)skipAction:(id)sender
{
    if (self.completionBlock) {
        self.completionBlock(NO);
    }
}

- (IBAction)saveAction:(id)sender
{
    [self.view endEditing:YES];
    [self setAuthenticating:YES];
    
    void (^finishedBlock)() = ^() {
        // Ensure options are up to date after connecting Jetpack as there may
        // now be new info.
        BlogService *service = [[BlogService alloc] initWithManagedObjectContext:[[ContextManager sharedInstance] mainContext]];
        [service syncBlog:self.blog completionHandler:^() {
            [self setAuthenticating:NO];
            if (self.completionBlock) {
                self.completionBlock(YES);
            }
        }];
    };
    
    void (^failureBlock)(NSError *error) = ^(NSError *error) {
        [self setAuthenticating:NO];
        [self handleSignInError:error];
    };
    
    NSManagedObjectContext *context = [[ContextManager sharedInstance] mainContext];
    JetpackService *jetpackService = [[JetpackService alloc] initWithManagedObjectContext:context];
    [jetpackService validateAndLoginWithUsername:self.usernameTextField.text
                                        password:self.passwordTextField.text
                                 multifactorCode:self.multifactorTextField.text
                                          siteID:self.blog.jetpack.siteID
                                         success:finishedBlock
                                         failure:failureBlock];
}

- (IBAction)sendVerificationCode:(id)sender
{
    WordPressComOAuthClient *client = [WordPressComOAuthClient client];
    [client requestOneTimeCodeWithUsername:self.usernameTextField.text
                                  password:self.passwordTextField.text
                                   success:^{
                                       [WPAnalytics track:WPAnalyticsStatTwoFactorSentSMS];
                                   }
                                   failure:nil];
}


#pragma mark - Helpers

- (void)handleSignInError:(NSError *)error
{
    // If needed, show the multifactor field
    if (error.code == WordPressComOAuthErrorNeedsMultifactorCode) {
        [self displayMultifactorTextfield];
        return;
    }
    
    [WPError showNetworkingAlertWithError:error];
}


#pragma mark - Multifactor Helpers

- (void)displayMultifactorTextfield
{
    [WPAnalytics track:WPAnalyticsStatTwoFactorCodeRequested];
    self.shouldDisplayMultifactor = YES;
    
    [self reloadInterface];
    [self.multifactorTextField becomeFirstResponder];
}

- (void)hideMultifactorTextfieldIfNeeded
{
    if (!self.shouldDisplayMultifactor) {
        return;
    }
    
    self.shouldDisplayMultifactor = NO;
    [self reloadInterface];
    self.multifactorTextField.text = nil;
}


#pragma mark - UITextField delegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (textField == self.usernameTextField) {
        [self.passwordTextField becomeFirstResponder];
    } else if (textField == self.passwordTextField || textField == self.multifactorTextField) {
        [self saveAction:nil];
    }
    
    return YES;
}

- (void)textFieldDidChangeNotificationReceived:(NSNotification *)notification
{
    [self updateSaveButton];
}

- (IBAction)textFieldDidBeginEditing:(UITextField *)sender
{
    self.activeField = sender;
}

- (IBAction)textFieldDidEndEditing:(UITextField *)sender
{
    self.activeField = nil;
}

#pragma mark - Keyboard Helpers

- (void)keyboardWillShow:(NSNotification *)notification
{
    NSDictionary* info = [notification userInfo];
    CGRect kbRect = [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue];
    // There is a bug when you
    // rotated the device to landscape. It reported the keyboard as the wrong size as if it was still in portrait mode.
    //kbRect = [self.view convertRect:kbRect fromView:nil];
    
    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0, 0.0, kbRect.size.height, 0.0);
    self.scrollView.contentInset = contentInsets;
    self.scrollView.scrollIndicatorInsets = contentInsets;
    
    CGRect aRect = self.view.frame;
    aRect.size.height -= kbRect.size.height;
    if (!CGRectContainsPoint(aRect, self.activeField.frame.origin) ) {
        [self.scrollView scrollRectToVisible:self.activeField.frame animated:YES];
    }
}

- (void)keyboardWillHide:(NSNotification *)notification
{
    UIEdgeInsets contentInsets = UIEdgeInsetsZero;
    self.scrollView.contentInset = contentInsets;
    self.scrollView.scrollIndicatorInsets = contentInsets;
}

#pragma mark - Custom methods

- (void)setAuthenticating:(BOOL)authenticating
{
    _authenticating = authenticating;
    self.usernameTextField.enabled = !authenticating;
    self.passwordTextField.enabled = !authenticating;
    [self updateSaveButton];
    [self.signInButton showActivityIndicator:authenticating];
}


#pragma mark - Browser

- (void)openInstallJetpackURL
{
    [WPAnalytics track:WPAnalyticsStatSelectedInstallJetpack];
    
    NSString *targetURL = [_blog adminUrlWithPath:JetpackInstallRelativePath];
    [self openURL:[NSURL URLWithString:targetURL] username:_blog.usernameForSite password:_blog.password wpLoginURL:[NSURL URLWithString:_blog.loginUrl]];
}

- (void)openMoreInformationURL
{
    NSURL *targetURL = [NSURL URLWithString:JetpackMoreInformationURL];
    [self openURL:targetURL username:nil password:nil wpLoginURL:nil];
}

- (void)openURL:(NSURL *)url username:(NSString *)username password:(NSString *)password wpLoginURL:(NSURL *)wpLoginURL
{
    WPWebViewController *webViewController = [WPWebViewController webViewControllerWithURL:url];
    webViewController.username = username;
    webViewController.password = password;
    webViewController.wpLoginURL = wpLoginURL;
    
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:webViewController];
    navController.modalPresentationStyle = UIModalPresentationPageSheet;
    [self presentViewController:navController animated:YES completion:nil];
}

- (void)updateMessage
{
    if (self.blog.jetpack.isInstalled) {
        if (self.blog.jetpack.isUpdatedToRequiredVersion) {
            self.descriptionLabel.text = NSLocalizedString(@"Looks like you have Jetpack set up on your site. Congrats!\nSign in with your WordPress.com credentials below to enable Stats and Notifications.", @"");
        } else {
            self.descriptionLabel.text = [NSString stringWithFormat:NSLocalizedString(@"Jetpack %@ or later is required for stats. Do you want to update Jetpack?", @""), JetpackVersionMinimumRequired];
            [self.installJetpackButton setTitle:NSLocalizedString(@"Update Jetpack", @"") forState:UIControlStateNormal];
        }
    } else {
        self.descriptionLabel.text = NSLocalizedString(@"Jetpack is required for stats. Do you want to install Jetpack?", @"");
        [self.installJetpackButton setTitle:NSLocalizedString(@"Install Jetpack", @"") forState:UIControlStateNormal];
    }
    [self.descriptionLabel sizeToFit];
}

- (void)updateForm
{
    if (self.blog.jetpack.isConnected) {
        if (self.blog.jetpack.connectedUsername) {
            self.usernameTextField.text = self.blog.jetpack.connectedUsername;
        }
        [self updateSaveButton];
    }
}

- (void)checkForJetpack
{
    NSManagedObjectContext *context = [[ContextManager sharedInstance] mainContext];
    BlogService *blogService = [[BlogService alloc] initWithManagedObjectContext:context];
    [blogService syncOptionsForBlog:self.blog success:^{
        if (self.blog.jetpack.isInstalled) {
            [self updateForm];
        }
        [self reloadInterface];
    } failure:^(NSError *error) {
        [WPError showNetworkingAlertWithError:error];
    }];
}


#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    BOOL isUsernameTextField = [touch.view isDescendantOfView:self.usernameTextField];
    BOOL isSigninButton = [touch.view isDescendantOfView:self.signInButton];
    
    if (isUsernameTextField || isSigninButton) {
        return NO;
    }
    
    return YES;
}

@end
