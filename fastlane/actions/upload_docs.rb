require 'fileutils'
require 'double_bag_ftps'

module Fastlane
  module Actions
    class UploadDocsAction < Action

      def self.remote_item_is_file? (ftp, item)
          begin
            size = ftp.size(item)
            if size.is_a? Numeric
                return true
          end
          rescue Net::FTPPermError
            return false
          end
      end

      # remove all files recursively at ftp path
      def self.rm_r (ftp, path)
        if remote_item_is_file?(ftp, path)
          ftp.delete(path)
        else
          ftp.chdir(path)

          begin
            files = ftp.nlst
            files.each {|file|
              rm_r(ftp, "#{path}/#{file}")
            }
          rescue Net::FTPTempError
            # maybe all files were deleted already
          end
          UI.message "Delete folder #{path}"
          ftp.rmdir(path)
        end
      end

      def self.run(params)
        UI.message("Current local dir " + Dir.pwd)
        if Helper.ci?
          Dir.chdir(ENV['WORKSPACE'])
        end

        host = params[:host] || ENV['FTP_REM_HOST']
        folder = params[:upload_from]
        Dir.chdir(folder)
        user = params[:user] || ENV['FTP_REM_USER']
        password = params[:password] || ENV['FTP_REM_PASSWORD']

        # Microsoft host only allows FTPS
        ftp = DoubleBagFTPS.new
        ftp.ssl_context = DoubleBagFTPS.create_ssl_context(:verify_mode => OpenSSL::SSL::VERIFY_NONE)

        ftp.connect(host)
        ftp.login(user, password)
        ftp.passive = true
        UI.success("Successful login to #{host}. Now attempt to upload contents of #{folder}.")

        ftproot = '/site/wwwroot/ios-sdk'
        if params[:testing]
          ftproot = ftproot + '/_test'
        end

        ftp.chdir(ftproot)
        UI.message 'Changed remote dir to ' + ftp.pwd

        localFiles = Dir.glob("**/*").sort
        UI.message "Folder listing for #{folder}: \n#{Dir.glob("*")}"

        localFiles.each do |name|
          if File::directory? name
            UI.message 'Create remote dir ' + name
            begin
              ftp.mkdir(name)
            rescue
              UI.message "Remote folder #{name} already exists so deleting it now..."
              rm_r(ftp, "#{ftproot}/#{name}")
              UI.message "After deleting #{ftproot}/#{name} the remote dir is #{ftp.pwd}"
              ftp.chdir(ftproot)
              ftp.mkdir(name)
            end
          else
            File.open(name) { |file|
              #UI.message 'Put file ' + name
              ftp.putbinaryfile(file, name)
            }
          end
        end
        UI.success("Documentation upload complete")
        ftp.close()
      end

      def self.description
        "Upload documentation for SDK module"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :upload_from,
                                       description: "Folder to upload",
                                       default_value: "artifacts/docs",
                                       optional: true
                                      ),
          FastlaneCore::ConfigItem.new(key: :host,
                                       description: "FTP host",
                                       optional: true
                                      ),
          FastlaneCore::ConfigItem.new(key: :user,
                                       description: "Username",
                                       optional: true
                                      ),
          FastlaneCore::ConfigItem.new(key: :password,
                                       description: "Password",
                                       optional: true
                                      ),
          FastlaneCore::ConfigItem.new(key: :testing,
                                       description: "Set true if testing (will upload to ios-sdk/_test)",
                                       default_value: false,
                                       is_string: false,
                                       optional: true
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
