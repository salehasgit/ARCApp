platform :osx, '10.12'
use_frameworks!

source 'https://github.com/CocoaPods/Specs.git'

target 'ARCApp' do

    # RAW converter
    pod 'AppleRawConverter', '1.1.6'
    pod 'SwiftyJSON', '~> 4.2.0'
    
    pod 'Fabric'
    pod 'Crashlytics'

    target 'ARCAppTests' do
      pod 'Nimble', '~> 7.1.2'
    end
    
end

post_install do |installer|
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            #puts "#{config.name}"
            if config.name == 'Debug'
                config.build_settings['OTHER_SWIFT_FLAGS'] = '-DDEBUG'
            end
            config.build_settings['SWIFT_VERSION'] = '4.2'
            config.build_settings['ONLY_ACTIVE_ARCH'] = 'NO'
        end
    end
end
