source 'https://github.com/CocoaPods/Specs.git'

xcodeproj 'WordPress/WordPress.xcodeproj'

inhibit_all_warnings!

use_frameworks!

platform :ios, '9.0'

target 'WordPress', :exclusive => true do
  # ---------------------
  # Third party libraries
  # ---------------------
  pod '1PasswordExtension', '1.6.4'
  pod 'AFNetworking',	'2.6.3'
  pod 'AMPopTip', '~> 0.7'
  pod 'CocoaLumberjack', '~> 2.2.0'
  pod 'DTCoreText',   '1.6.16'
  pod 'FormatterKit', '~> 1.8.0'
  pod 'Helpshift', '~> 5.5.0'
  pod 'HockeySDK', '~>3.8.0'
  pod 'Lookback', '1.1.4', :configurations => ['Release-Internal', 'Release-Alpha']
  pod 'MRProgress', '~>0.7.0'
  pod 'Mixpanel', '2.9.4'
  pod 'Reachability',	'3.2'
  pod 'ReactiveCocoa', '~> 2.4.7'
  # Point to xcode/7.3 branch until there's a new release with the fixes.
  # Otherwise RxTests fails to build.
  # @koke 2016-03-22
  pod 'RxCocoa', :git => 'https://github.com/ReactiveX/RxSwift.git', :branch => 'develop'
  pod 'RxSwift', :git => 'https://github.com/ReactiveX/RxSwift.git', :branch => 'develop'
  pod 'SVProgressHUD', '~>1.1.3'
  pod 'UIDeviceIdentifier', '~> 0.1'
  pod 'Crashlytics'
  # ----------------------------
  # Forked third party libraries
  # ----------------------------
  pod 'MGImageUtilities', :git => 'git://github.com/wordpress-mobile/MGImageUtilities.git', :branch => 'gifsupport'
  pod 'WordPress-AppbotX', :git => 'https://github.com/wordpress-mobile/appbotx.git', :commit => '87bae8c770cfc4e053119f2d00f76b2f653b26ce'

  # --------------------
  # WordPress components
  # --------------------
  pod 'Automattic-Tracks-iOS', :git => 'https://github.com/Automattic/Automattic-Tracks-iOS.git', :tag => '0.0.13'
  pod 'EmailChecker', :podspec => 'https://raw.github.com/wordpress-mobile/EmailChecker/develop/ios/EmailChecker.podspec'
  pod 'NSObject-SafeExpectations', '0.0.2'
  pod 'NSURL+IDN', '0.3'
  pod 'Simperium', '0.8.12'
  pod 'WPMediaPicker', '~> 0.9.0'
  pod 'WordPress-iOS-Editor', '1.2'
  pod 'WordPress-iOS-Shared', '0.5.3'
  pod 'WordPressApi', :git => "https://github.com/wordpress-mobile/WordPress-API-iOS.git"
  pod 'WordPressCom-Analytics-iOS', '0.1.4'
  pod 'WordPressCom-Stats-iOS/UI', '0.6.3'
  pod 'wpxmlrpc', '~> 0.8'
end

target 'WordPressTodayWidget', :exclusive => true do
  pod 'WordPress-iOS-Shared', '0.5.3'
  pod 'WordPressCom-Stats-iOS/Services', '0.6.3'
end

target :WordPressTest, :exclusive => true do
  pod 'OHHTTPStubs', '~> 4.6.0'
  pod 'OHHTTPStubs/Swift', '~> 4.6.0'
  pod 'OCMock', '3.1.2'
  pod 'Specta', '1.0.5'
  pod 'Expecta', '0.3.2'
  pod 'Nimble', '~> 3.2.0'
  pod 'RxSwift', :git => 'https://github.com/ReactiveX/RxSwift.git', :branch => 'develop'
  pod 'RxTests', :git => 'https://github.com/ReactiveX/RxSwift.git', :branch => 'develop'
end

target 'UITests', :exclusive => true do
    pod 'KIF/IdentifierTests', '~>3.1'
end

post_install do |installer_representation|
  # We need to add in AF_APP_EXTENSIONS=1 to AFNetworking used by the Today Extension otherwise the build will fail. See - https://github.com/AFNetworking/AFNetworking/pull/2589
  installer_representation.pods_project.targets.each do |target|
    if ["Pods-WordPressTodayWidget-WordPressCom-Stats-iOS", "Pods-WordPressTodayWidget-AFNetworking"].include?(target.name)
      target.build_configurations.each do |config|
        config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['$(inherited)', 'AF_APP_EXTENSIONS=1']
      end
    end

    # See https://github.com/CocoaPods/CocoaPods/issues/3838
    if target.name.end_with?('WordPressCom-Stats-iOS')
      target.build_configurations.each do |config|
        config.build_settings['FRAMEWORK_SEARCH_PATHS'] ||= ['$(inherited)', '$PODS_FRAMEWORK_BUILD_PATH', '$PODS_FRAMEWORK_BUILD_PATH/..']
      end
    end
  end

  # Directly set the Targeted Device Family
  # See https://github.com/CocoaPods/CocoaPods/issues/2292
  installer_representation.pods_project.build_configurations.each do |config|
      config.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
  end
end
