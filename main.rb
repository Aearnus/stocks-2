require "sinatra"
require "fileutils"
require "securerandom"
require "json"

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
def string_return(res)
    "{\"result\": \"#{res}\"}"
end
def boolnum_return(res)
    "{\"result\": #{res}}"
end
def data_return(res, data)
    "{\"result\": #{res}, \"data\": #{data}}"
end

assert_dir "ids"
assert_dir "stocks"
assert_file "id-list", ""
assert_file "stock-list", ""

get "/" do
    redirect "/index.html"
end

#login stuff
get "/newId" do
    userId = SecureRandom.uuid
    defaultIdStats = {
        id: "#{userId}",
        money: 100,
        createdStocks: [],
        ownedStocks: {}
    }
    File.open("id-list", "a") do |f|
        f.puts "#{userId}"
    end
    File.open("ids/#{userId}", "w") do |f|
        f.write JSON.generate(defaultIdStats)
    end
    "{\"id\":\"#{userId}\"}"
end
def check_login_validity(uuid)
    puts "TESTING UUID #{uuid}"
    if uuid.length != 36
        return false
    end
    File.foreach("id-list") do |fileUuid|
        if uuid == fileUuid.chomp
            puts "UUID GOOD"
            return true
        end
    end
    puts "UUID BAD"
    return false
end
post "/login" do
    userId = params["userId"]
    if !check_login_validity(userId)
        redirect "/login-fail.html"
    else
        redirect "/trade.html"
    end
end
post "/verifylogin" do
    userId = params["userId"]
    if check_login_validity(userId)
        boolnum_return(true)
    else
        boolnum_return(false)
    end
end

#begin game functions
def check_if_stock_exists(stock)
    puts "TESTING STOCK #{stock}"
    if stock.length > 10
        return false
    end
    File.foreach("stock-list") do |fileStock|
        if uuid == fileUuid.chomp
            puts "STOCK EXISTS"
            return true
        end
    end
    puts "STOCK DOESN'T EXIST"
    return false
end
#create a stock
post "/createstock" do
    shareCost = 100
    stockName = params["stockName"];
    stockDesc = params["stockDesc"];
    stockAmount = params["stockAmount"].to_i;
    userId = params["userId"];
    #make sure user exists
    if !check_login_validity(userId)
        data_return(false, JSON.generate({error: "Invalid login token!", errorWith: "userId"}))
    end
    #make sure stock doesn't already exist
    if check_if_stock_exists(stockName)
        data_return(false, JSON.generate({error: "This stock already exists!", errorWith: "stockName"}))
    end
    #make sure stock is only alphanumeric
    if stockName =~ /[^a-zA-Z0-9]/
        data_return(false, JSON.generate({error: "The stock name contains invalid characters!", errorWith: "stockDesc"}))
    end
    if stockDesc =~ /[^a-zA-Z0-9] /
        data_return(false, JSON.generate({error: "The stock description contains invalid characters!", errorWith: "stockDesc"}))
    end
    #make sure that name and description are okay length
    if (stockName.length > 10) || (stockName.length < 1)
        data_return(false, JSON.generate({error: "Stock names have to be from 1 to 10 letters long!", errorWith: "stockName"}))
    end
    if (stockDesc.length > 100) || (stockDesc.length < 4)
        data_return(false, JSON.generate({error: "Stock descriptions have to be from 4 to 100 letters long!", errorWith: "stockDesc"}))
    end
    #make sure they bought at least 200 shares for $100 each - the minimum
    if (stockAmount < 200)
        data_return(false, JSON.generate({error: "You must buy at least 200 shares to create a stock!", errorWith: "stockAmount"}))
    end
    user = JSON.parse(File.read("ids/#{userId}"))
    #make sure the user has enough money
    if (stockAmount * shareCost > user["money"])
        data_return(false, JSON.generate({error: "You don't have enough money to buy #{stockAmount} shares! (required: $#{stockAmount * shareCost})", errorWith: "stockAmount"}))
    end
    #finally, it's gucci - create the stock
    defaultStock = {
        name: stockName.upcase,
        desc: stockDesc,
        shares: stockAmount,
        createdBy: "#{userId}",
        history: [
            {
                transaction: "buy",
                time: Time.now.to_i,
                amount: stockAmount,
                value: shareCost
            }
        ]
    }
    File.open("stock-list", "a") do |f|
        f.puts "#{stockName}"
    end
    File.open("stocks/#{stockName}", "w") do |f|
        f.write JSON.generate(defaultStock)
    end
end
