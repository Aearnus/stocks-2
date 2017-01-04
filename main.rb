require "sinatra"
require "fileutils"
require "securerandom"

set :bind, "10.0.1.22"
set :port, 4567
set :public_folder, "public"

def assert_dir(dirName)
    if !File.directory?(dirName)
    	Dir.mkdir(dirName)
    end
end
def assert_file(fileName, defaultText)
    if !File.exist?(fileName)
    	File.open(fileName, "w") do |f|
            f.write defaultText
        end
    end
end

assert_dir "ids"
assert_dir "stocks"
assert_file "id-list", ""

get "/" do
    redirect "/index.html"
end

get "/newId" do
    userId = SecureRandom.uuid
    File.open("ids/#{userId}", "w") do |f|
        f.write "{\"id\": \"#{userId}\"}"
    end
    File.open("id-list", "a") do |f|
        f.puts "#{userId}"
    end
    "{\"id\":\"#{userId}\"}"
end

def check_login_validity(uuid)
    File.foreach("id-list") do |fileUuid|
        if uuid == fileUuid
            return true
        end
    end
    return false
end
post "/login" do
    uuid = params["userId"]
    if !check_login_validity(uuid)
        redirect "/login-fail.html"
    end
end
