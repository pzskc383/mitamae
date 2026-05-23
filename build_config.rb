MACOS_SDK= File.expand_path('./MacOSX.sdk', __dir__)
MACOS_SDK_VER = "11.3".freeze

TRIPLETS = {
  'linux-x86_64' => 'x86_64-linux-musl',
  'linux-i386' => 'x86-linux-musl',
  'linux-armhf' => 'arm-linux-musleabihf',
  'linux-aarch64' => 'aarch64-linux-musl',
  'linux-ppc64le' => 'powerpc64le-linux-musl',
  'linux-s390x' => 's390x-linux-musl',
  'darwin-x86_64' => 'x86_64-macos-none',
  'darwin-aarch64' => 'aarch64-macos-none',
  'freebsd-x86_64' => 'x86_64-freebsd-none',
  'freebsd-aarch64' => 'aarch64-freebsd-none',
  'openbsd-x86_64' => 'x86_64-openbsd-none',
  'openbsd-aarch64' => 'aarch64-openbsd-none'
}.freeze

def gem_config(conf)
  conf.gem File.expand_path(File.dirname(__FILE__))
end

def debug_config(conf)
  conf.instance_eval do
    # In `enable_debug`, use this for release build too.
    # Allow showing backtrace and prevent "fptr_finalize failed" error in mruby-io.
    @mrbc.compile_options += ' -g'
  end
  # conf.enable_debug
end

def enable_zig(conf, triplet)
  conf.host_target = triplet
  [conf.cc, conf.linker].each do |tool|
    tool.command = "zig cc -target #{triplet}"
  end
  conf.archiver.command = 'zig ar'

  ENV['RANLIB'] ||= 'zig ranlib' unless triplet.include?('linux')
end

def common_config(conf)
  conf.toolchain :gcc

  # conf.toolchain :clang
  # conf.enable_sanitizer "address,undefined"

  # conf.enable_bintest
  # conf.enable_test
end

def download_macos_sdk(path)
  system('wget', "https://github.com/phracker/MacOSX-SDKs/releases/download/#{MACOS_SDK_VER}/MacOSX#{MACOS_SDK_VER}.sdk.tar.xz", exception: true)
  system('tar', 'xf', "MacOSX#{MACOS_SDK_VER}.sdk.tar.xz", exception: true)
  system('rm', "MacOSX#{MACOS_SDK_VER}.sdk.tar.xz", exception: true)
  system('mv', "MacOSX#{MACOS_SDK_VER}.sdk", path, exception: true)
end

def add_macos_arguments(conf)
  macosx_min_ver = target.include?('aarch64') ? '11.1' : '10.14'
  unless Dir.exist?(MACOS_SDK)
    download_macos_sdk(MACOS_SDK)
  end

  conf.cc.command += " -mmacosx-version-min=#{macosx_min_ver} -isysroot #{MACOS_SDK.shellescape}"
  conf.cc.command += " -iwithsysroot /usr/include -iframeworkwithsysroot /System/Library/Frameworks"
  conf.linker.command += " -mmacosx-version-min=#{macosx_min_ver} --sysroot #{MACOS_SDK.shellescape}"
  conf.linker.command += " -F/System/Library/Frameworks -L/usr/lib"
end

MRuby::Build.new do |conf|
  common_config(conf)
  debug_config(conf)
  gem_config(conf)
end

build_targets = ENV.fetch('BUILD_TARGET', '').split(',')
TRIPLETS.each do |target, triplet|
  next unless build_targets.include?(target)

  MRuby::CrossBuild.new(target) do |conf|
    common_config(conf)
    debug_config(conf)
    gem_config(conf)

    enable_zig(conf, triplet)
    add_macos_arguments(conf) if target.include?('darwin')
  end
end
