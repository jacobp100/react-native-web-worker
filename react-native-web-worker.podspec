require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))
folly_compiler_flags = '-DFOLLY_NO_CONFIG -DFOLLY_MOBILE=1 -DFOLLY_USE_LIBCPP=1 -Wno-comma -Wno-shorten-64-to-32'

Pod::Spec.new do |s|
  s.name         = "react-native-web-worker"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => min_ios_version_supported }
  s.source       = { :git => "https://github.com/jacobp100/react-native-web-worker.git", :tag => "#{s.version}" }

  s.source_files = "ios/**/*.{h,m,mm}"

  # Use install_modules_dependencies helper to install the dependencies if React Native version >=0.71.0.
  # See https://github.com/facebook/react-native/blob/febf6b7f33fdb4904669f99d795eba4c0f95d7bf/scripts/cocoapods/new_architecture.rb#L79.
  if respond_to?(:install_modules_dependencies, true)
    install_modules_dependencies(s)
  else
    s.dependency "React-Core"
  end

  use_hermes = false
  # Hermes is default so env var may be unset
  if ENV['USE_HERMES'] == nil || ENV['USE_HERMES'] == '1' then
    use_hermes = true
  elsif ENV['RNWW_USE_HERMES'] != nil then
    # Use Hermes for the worker, but not for RN
    # The only real use-case is if Hermes does not work with some libraries you use
    # But it does work for the worker - AND you need to be able to terminate the worker
    # To do this, open your Podfile andmake the following changes
    #
    # + ENV['RNWW_USE_HERMES'] = '1'
    #
    #   target 'YourProject' do
    #     ...
    #     use_react_native!(...)
    #     ...
    # +   setup_hermes!()
    # +
    # +   pre_install do |installer|
    # +     installer.pod_targets.each do |pod|
    # +       if pod.name == 'React-jsi'
    # +         s = pod.root_spec
    # +         s.dependency 'hermes-engine'
    # +         s.exclude_files = [
    # +           'jsi/jsilib-posix.cpp',
    # +           'jsi/jsilib-windows.cpp',
    # +           '**/test/*',
    # +           'jsi/jsi.cpp'
    # +         ]
    # +       end
    # +     end
    # +   end
    #
    #     post_install do |installer|
    #       ...
    #     end
    #   end
    #
    # Check the pre_install against the current source for React-jsi.podspec
    # It may have changed, and you may need to reflect some of the changes
    use_hermes = true
  end

  if use_hermes then
    s.dependency "hermes-engine"
  end

  # Don't install the dependencies when we run `pod install` in the old architecture.
  if ENV['RCT_NEW_ARCH_ENABLED'] == '1' then
    s.compiler_flags = folly_compiler_flags + " -DRCT_NEW_ARCH_ENABLED=1"
    s.pod_target_xcconfig = {
      "HEADER_SEARCH_PATHS" => "\"$(PODS_ROOT)/boost\" \"$(PODS_ROOT)/Headers/Private/React-Core\" \"$(PODS_ROOT)/Headers/Private/React-Fabric\"",
      "OTHER_CPLUSPLUSFLAGS" => "-DFOLLY_NO_CONFIG -DFOLLY_MOBILE=1 -DFOLLY_USE_LIBCPP=1",
      "CLANG_CXX_LANGUAGE_STANDARD" => "c++17"
    }
    s.dependency "React-Codegen"
    s.dependency "RCT-Folly"
    s.dependency "RCTRequired"
    s.dependency "RCTTypeSafety"
    s.dependency "ReactCommon/turbomodule/core"

    # Needed for AppSetupUtils
    s.dependency "React-RCTAppDelegate"
  end
end
