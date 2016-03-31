//
//  JetpackSettingsViewControllerNew.h
//  WordPress
//
//  Created by Leonardo Amigoni on 3/24/16.
//  Copyright © 2016 WordPress. All rights reserved.
//
#import <UIKit/UIKit.h>


#import "WPNUXMainButton.h"
#import "WPWalkthroughTextField.h"
#import "WPNUXSecondaryButton.h"


@class Blog;

typedef void(^JetpackSettingsCompletionBlock)(BOOL didAuthenticate);


@interface JetpackSettingsViewController : UIViewController

@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;
@property (weak, nonatomic) IBOutlet UIView *contentView;
@property (weak, nonatomic) IBOutlet UIImageView *icon;
@property (weak, nonatomic) IBOutlet UILabel *descriptionLabel;
@property (weak, nonatomic) IBOutlet WPWalkthroughTextField *usernameTextField;
@property (weak, nonatomic) IBOutlet WPWalkthroughTextField *passwordTextField;
@property (weak, nonatomic) IBOutlet WPNUXMainButton *signInButton;
@property (weak, nonatomic) IBOutlet WPWalkthroughTextField *multifactorTextField;
@property (weak, nonatomic) IBOutlet UIButton *sendVerificationCodeButton;
@property (weak, nonatomic) IBOutlet UIButton *moreInformationButton;
@property (weak, nonatomic) IBOutlet WPNUXSecondaryButton *skipButton;
@property (weak, nonatomic) IBOutlet WPNUXMainButton *installJetpackButton;

// Navigation bar is hidden and all buttons are added into the view on initial sign in
@property (nonatomic, assign) BOOL                              showFullScreen;
@property (nonatomic, assign) BOOL                              canBeSkipped;
@property (nonatomic,   copy) JetpackSettingsCompletionBlock    completionBlock;

- (instancetype)initWithBlog:(Blog *)blog;
- (void)setBlog:(Blog *)blog;

@end
