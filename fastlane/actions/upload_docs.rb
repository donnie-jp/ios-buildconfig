require 'fileutils'
require 'double_bag_ftps'

module Fastlane
  module Actions
    class UploadDocsAction < Action
      def self.run(params)

      UI.message("Current local dir " + Dir.pwd)
      if Helper.ci?
        Dir.chdir(ENV['WORKSPACE'])
      end
      Dir.chdir('artifacts/docs')

      host = params[:host] || ENV['FTP_REM_HOST']
      folder = params[:module_folder]

      ftp = DoubleBagFTPS.new
      ftp.ssl_context = DoubleBagFTPS.create_ssl_context(:verify_mode => OpenSSL::SSL::VERIFY_NONE)

      ftp.connect(host)
      ftp.login(params[:user] || ENV['FTP_REM_USER'], params[:password] || ENV['FTP_REM_PASSWORD'])
      ftp.passive = true
      UI.success("Successful login to #{host}. Now attempt to upload #{folder}.")

      ftproot = 'site/wwwroot/ios-sdk'
      if params[:testing]
        ftproot = ftproot + '/_test'
      end
      ftp.chdir(ftproot)
      UI.message 'Changed remote dir to ' + ftp.pwd

      entries = Dir.glob("#{folder}/**/*").sort
      # print entries

      begin
        ftp.mkdir(folder)
      rescue
        # TODO: folder exists - need to empty contents and delete folder
        # before uploading files
      end

      entries.each do |name|
        if File::directory? name
          ftp.mkdir name
        else
          File.open(name) { |file| ftp.putbinaryfile(file, name) }
        end
      end
      UI.success("Upload complete: folder listing\n")
      puts ftp.nlst
      ftp.close()
      end

      def self.description
        "Upload documentation for SDK module"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :module_folder,
                                       description: "Folder to upload"
                                      ),
          FastlaneCore::ConfigItem.new(key: :host,
                                       description: "FTP host"
                                      ),
          FastlaneCore::ConfigItem.new(key: :user,
                                       description: "Username"
                                      ),
          FastlaneCore::ConfigItem.new(key: :password,
                                       description: "Password"
                                      ),
          FastlaneCore::ConfigItem.new(key: :testing,
                                       description: "Set true if testing (will upload to ios-sdk/_test)",
                                       default_value: false,
                                       is_string: false
                                       )
        ]
      end

      def self.output
      end

      def self.authors
        ["rem"]
      end

      def self.is_supported?(platform)
        [:ios, :mac].include?(platform)
      end
    end
  end
end
# vim:syntax=ruby:et:sts=2:sw=2:ts=2:ff=unix:
