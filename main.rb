require "sinatra"
require "fileutils"
require "securerandom"
require "json"

set :bind, "0.0.0.0"
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
def check_if_stock_exists(stock)
    puts "TESTING STOCK #{stock}"
    if stock.length > 10
        return false
    end
    File.foreach("stock-list") do |fileStock|
        if stock == fileStock.chomp
            puts "STOCK EXISTS"
            return true
        end
    end
    puts "STOCK DOESN'T EXIST"
    return false
end

assert_dir "ids"
assert_dir "stocks"
assert_dir "market"
assert_file "id-list", ""
assert_file "stock-list", ""

############################################################
# Automatic redirect to homepage
# GET params:
#   none
# Return value:
#   Redirect to index.html
############################################################
get "/" do
    redirect "/index.html"
end

############################################################
# Creates a new user ID to use for login and requests
# GET params:
#   none
# Return value:
#   JSON: {"id": "<user id>"}
############################################################
get "/newId" do
    userId = SecureRandom.uuid
    defaultIdStats = {
        id: "#{userId}",
        money: 100,
        createdStocks: [],
        ownedStocks: []
    }
    File.open("id-list", "a") do |f|
        f.puts "#{userId}"
    end
    File.open("ids/#{userId}", "w") do |f|
        f.write JSON.generate(defaultIdStats)
    end
    "{\"id\":\"#{userId}\"}"
end

############################################################
# Logs into an account using a user ID
# POST params:
#   userId: the user ID of the user wishing to log in
# Return value:
#   Redirect to either /login-fail.html or /trade.html
############################################################
post "/login" do
    userId = params["userId"]
    if !check_login_validity(userId)
        redirect "/login-fail.html"
    else
        redirect "/trade.html"
    end
end

############################################################
# Checks a user ID to see if it exists, through check_login_validity
# POSSIBLE EXPLOIT: user enumeration. Is this actually a bad thing?
# I'm not sure, due to the improbability of an ID conflict
# POST params:
#   userId: the user ID to check
# Return value:
#   JSON: {"result": true/false}
############################################################
post "/verifylogin" do
    userId = params["userId"]
    if check_login_validity(userId)
        boolnum_return(true)
    else
        boolnum_return(false)
    end
end



############################################################
# Hook to create a new publicly traded stock
# POST params:
#   stockName: the name of the stock to create. 2-9 alphanumeric characters
#   stockDesc: the description of the stock to be created. 4-100 alphanumeric characters
#   stockAmount: the amount of stocks to create. integer > 200
#   userId: the id of the user that wishes to buy a stock
# Return value:
#   none
############################################################
post "/createstock" do
    shareCost = 100
    stockName = params["stockName"].upcase;
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
        name: stockName,
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
    #write the stock to disk
    File.open("stock-list", "a") do |f|
        f.puts "#{stockName}"
    end
    File.open("stocks/#{stockName}", "w") do |f|
        f.write JSON.generate(defaultStock)
    end
    #make the market listing folder
    Dir.mkdir("market/#{stockName}")
    #write the user's new stock portfolio, now containing this stock
    user["createdStocks"] << stockName
    user["ownedStocks"] << {name: stockName, shares: stockAmount}
    File.open("ids/#{userId}", "w") do |f|
        f.write JSON.generate(user)
    end
end

############################################################
# Hook to buy a stock
# POST params:
#   stockName: the stock to buy
#   stockAmount: the amount of stocks to buy
#   userId: the id of the user that wishes to buy a stock
############################################################
post "/buystock" do
    stockName = params["stockName"].upcase;
    shareAmount = params["stockAmount"].to_i;
    userId = params["userId"];
    #make sure user exists
    if !check_login_validity(userId)
        data_return(false, JSON.generate({error: "Invalid login token!", errorWith: "userId"}))
    end
    #make sure stock exists
    if !check_if_stock_exists(stockName)
        data_return(false, JSON.generate({error: "This stock doesn't exist!", errorWith: "stockName"}))
    end
    user = JSON.parse(File.read("ids/#{userId}"))
    #make sure the user has enough money
    #TODO: market listings, do those first. (aka /sellstock)
    #if (shareAmount * shareCost > user["money"])
    #    data_return(false, JSON.generate({error: "You don't have enough money to buy #{stockAmount} shares! (required: $#{stockAmount * shareCost})", errorWith: "stockAmount"}))
    #end
end

############################################################
# Creates a new user ID to use for login and requests
# GET params:
#   none
# Return value:
#   JSON: {"id": "<user id>"}
############################################################
get "/stock/*" do
