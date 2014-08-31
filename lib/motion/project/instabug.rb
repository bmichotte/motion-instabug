# Copyright (c) 2014, Benjamin Michotte <bmichotte@gmail.com>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
# ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

unless defined?(Motion::Project::Config)
  raise 'This file must be required within a RubyMotion project Rakefile.'
end

Motion::Project::App.setup do |app|
  app.pods do
    pod 'Instabug'
  end
end

class InstabugConfig
  attr_accessor :api_token

  def initialize(config)
    @config = config
  end

  def sdk=(sdk)
    if @sdk != sdk
      @config.unvendor_project(@sdk)
      @sdk = sdk
      @config.vendor_project(sdk, :static)
      libz = '/usr/lib/libz.dylib'
      @config.libs << libz unless @config.libs.index(libz)
    end
  end

  def api_token=(api_token)
    @api_token = api_token
    create_launcher
  end

  def inspect
    {:api_token => api_token}.inspect
  end

  private

  def create_launcher
    return unless api_token
    launcher_code = <<EOF
# This file is automatically generated. Do not edit.

if Object.const_defined?('Instabug') and !UIDevice.currentDevice.model.include?('Simulator')
  NSNotificationCenter.defaultCenter.addObserverForName(UIApplicationDidFinishLaunchingNotification, object:nil, queue:nil, usingBlock:lambda do |notification|
  Instabug.startWithToken('#{api_token}', captureSource: IBGCaptureSourceUIKit, invocationEvent: IBGInvocationEventShake)
  end)
end
EOF
    launcher_file = './app/instabug_launcher.rb'
    if !File.exist?(launcher_file) or File.read(launcher_file) != launcher_code
      File.open(launcher_file, 'w') { |io| io.write(launcher_code) }
    end
    files = @config.files.flatten
    files << launcher_file unless files.find { |x| File.expand_path(x) == File.expand_path(launcher_file) }
  end
end

module Motion; module Project; class Config

  attr_accessor :instabug_mode

  variable :instabug

  def instabug
    @instabug ||= InstabugConfig.new(self)
    yield @instabug if block_given? && instabug?
    @instabug
  end

  def instabug?
    @instabug_mode == true
  end

end; end; end

namespace 'instabug' do
  desc "Submit an archive to Instabug"
  task :submit do

    App.config_without_setup.instabug_mode = true

    # Retrieve configuration settings.
    prefs = App.config.instabug
    App.fail "A value for app.instabug.api_token is mandatory" unless prefs.api_token

    Rake::Task["archive"].invoke
  
    # An archived version of the .dSYM bundle is needed.
    app_dsym = App.config.app_bundle_dsym('iPhoneOS')
    app_dsym_zip = app_dsym + '.zip'
    if !File.exist?(app_dsym_zip) or File.mtime(app_dsym) > File.mtime(app_dsym_zip)
      Dir.chdir(File.dirname(app_dsym)) do
        sh "/usr/bin/zip -q -r \"#{File.basename(app_dsym)}.zip\" \"#{File.basename(app_dsym)}\""
      end
    end
    curl = "/usr/bin/curl https://www.instabug.com/api/ios/v1/dsym --write-out %{http_code} --silent --output /dev/null -F dsym=@\"#{app_dsym_zip}\" -F token=\"#{prefs.api_token}\""
    App.info 'Run', curl
    sh curl
  end

  desc "Records if the device build is created in instabug mode, so some things can be cleaned up between mode switches"
  task :record_mode do
    instabug_mode = App.config_without_setup.instabug_mode ? "True" : "False"

    platform = 'iPhoneOS'
    bundle_path = App.config.app_bundle(platform)
    build_dir = File.join(App.config.versionized_build_dir(platform))
    FileUtils.mkdir_p(build_dir)
    previous_instabug_mode_file = File.join(build_dir, '.instabug_mode')

    previous_instabug_mode = "False"
    if File.exist?(previous_instabug_mode_file)
      previous_instabug_mode = File.read(previous_instabug_mode_file).strip
    end
    if previous_instabug_mode != instabug_mode
      App.info "Instabug", "Cleaning executable, Info.plist, and PkgInfo for mode change (was: #{previous_instabug_mode}, now: #{instabug_mode})"
      [
        App.config.app_bundle_executable(platform), # main_exec
        File.join(bundle_path, 'Info.plist'), # bundle_info_plist
        File.join(bundle_path, 'PkgInfo') # bundle_pkginfo
      ].each do |path|
        rm_rf(path) if File.exist?(path)
      end
    end
    File.open(previous_instabug_mode_file, 'w') do |f|
      f.write instabug_mode
    end
  end
end

desc 'Same as instabug:submit'
task 'instabug' => 'instabug:submit'

# record instabug mode before every device build
task 'build:device' => 'instabug:record_mode'