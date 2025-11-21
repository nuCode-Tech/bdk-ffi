Pod::Spec.new do |spec|
  spec.name         = 'bdk_flutter'
  spec.version      = '0.0.1'
  spec.summary      = 'Flutter wrapper that bundles BDK native binaries for iOS.'
  spec.description  = 'Builds BDK Rust library as an XCFramework and vendors it for runtime FFI from Dart.'
  spec.homepage     = 'https://github.com/nuCode-Tech/bdk-ffi'
  spec.license      = { :type => 'MIT' }
  spec.author       = { 'Bitcoin Dev Kit Developers' => 'dev@bitcoindevkit.org' }
  spec.source       = { :path => '.' }
  spec.source_files = 'Classes/**/*'
  spec.platform     = :ios, '12.0'

  # Vendored framework produced by our build script.
  spec.vendored_frameworks = 'Frameworks/BdkFFI.xcframework'

  # Ensure we run our builder before compilation so the XCFramework exists.
  spec.script_phase = {
    :name => 'Build BDK XCFramework',
    :execution_position => :before_compile,
    :script => 'bash "${PODS_TARGET_SRCROOT}/scripts/build_ios_xcframework.sh"'
  }
end


