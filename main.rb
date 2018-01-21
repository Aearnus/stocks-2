require "sinatra"
require "fileutils"
require "securerandom"
require "json"

require_relative "helper-functions.rb"

set :bind, "0.0.0.0"
set :port, 4567
set :public_folder, "public"

assert_dir "ids"
assert_dir "stocks"
assert_dir "market"
assert_file "id-list", ""
assert_file "stock-list", ""

############################################################
# GET /
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
# GET /newId
# Creates a new user ID to use for login and requests
# GET params:
#   none
# Return value:
#   {"id": "<user id>"}
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
    return "{\"id\":\"#{userId}\"}"
end

############################################################
# POST /login
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
# POST /verifylogin
# Checks a user ID to see if it exists, through check_login_validity
# POSSIBLE EXPLOIT: user enumeration. Is this actually a bad thing?
# I'm not sure, due to the improbability of an ID conflict
# POST params:
#   userId: the user ID to check
# Return value:
#   On verification:
#       {"result": true}
#   On verification failure:
#       {"result": false}
############################################################
post "/verifylogin" do
    userId = params["userId"]
    if check_login_validity(userId)
        return boolnum_return(true)
    else
        return boolnum_return(false)
    end
end



############################################################
# POST /createstock
# Hook to create a new publicly traded stock
# POST params:
#   stockName: the name of the stock to create. 2-9 alphanumeric characters
#   stockDesc: the description of the stock to be created. 4-100 alphanumeric characters
#   stockAmount: the amount of stocks to create. integer > 200
#   userId: the id of the user that wishes to buy a stock
# Return value:
#   On success:
#       {"result": true}
#   On failure:
#       {
#           "result": false,
#           "data": {
#               "error": "<error message>",
#               "errorWith": "<param>"
#           }
#       }
############################################################
post "/createstock" do
    return if !assert_params(params, "stockName", "stockDesc", "stockAmount", "userId")
    shareCost = 100
    stockName = params["stockName"].upcase;
    stockDesc = params["stockDesc"];
    stockAmount = params["stockAmount"].to_i;
    userId = params["userId"];
    #make sure user exists
    if !check_login_validity(userId)
        return data_return(false, JSON.generate({error: "Invalid login token!", errorWith: "userId"}))
    end
    #make sure stock doesn't already exist
    if check_if_stock_exists(stockName)
        return data_return(false, JSON.generate({error: "This stock already exists!", errorWith: "stockName"}))
    end
    #make sure stock is only alphanumeric
    if stockName =~ /[^a-zA-Z0-9]/
        return data_return(false, JSON.generate({error: "The stock name contains invalid characters!", errorWith: "stockDesc"}))
    end
    if stockDesc =~ /[^a-zA-Z0-9] /
        return data_return(false, JSON.generate({error: "The stock description contains invalid characters!", errorWith: "stockDesc"}))
    end
    #make sure that name and description are okay length
    if (stockName.length > 10) || (stockName.length < 1)
        return data_return(false, JSON.generate({error: "Stock names have to be from 1 to 10 letters long!", errorWith: "stockName"}))
    end
    if (stockDesc.length > 100) || (stockDesc.length < 4)
        return data_return(false, JSON.generate({error: "Stock descriptions have to be from 4 to 100 letters long!", errorWith: "stockDesc"}))
    end
    #make sure they bought at least 200 shares for $100 each - the minimum
    if (stockAmount < 200)
        return data_return(false, JSON.generate({error: "You must buy at least 200 shares to create a stock!", errorWith: "stockAmount"}))
    end
    user = JSON.parse(File.read("ids/#{userId}"))
    #make sure the user has enough money
    if (stockAmount * shareCost > user["money"])
        return data_return(false, JSON.generate({error: "You don't have enough money to buy #{stockAmount} shares! (required: $#{stockAmount * shareCost})", errorWith: "stockAmount"}))
    end
    #finally, it's gucci - create the stock
    defaultStock = {
        name: stockName,
        desc: stockDesc,
        time: Time.now.to_i,
        shares: stockAmount,
        createdBy: "#{userId}",
        history: [
            {
                transaction: "buy",
                time: Time.now.to_i,
                amount: stockAmount,
                value: shareCost
            }
        ],
        averageValue: shareCost
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
    boolnum_return(true)
end

############################################################
# POST /buystock
# Hook to buy a stock
# POST params:
#   stockName: the stock to buy
#   stockAmount: the amount of stocks to buy
#   userId: the id of the user that wishes to buy a stock
#   On success:
#       {"result": true}
#   On failure:
#       {
#           "result": false,
#           "data": {
#               "error": "<error message>",
#               "errorWith": "<param>"
#           }
#       }
############################################################
post "/buystock" do
    stockName = params["stockName"].upcase;
    shareAmount = params["stockAmount"].to_i;
    userId = params["userId"];
    #make sure user exists
    if !check_login_validity(userId)
        return data_return(false, JSON.generate({error: "Invalid login token!", errorWith: "userId"}))
    end
    #make sure stock exists
    if !check_if_stock_exists(stockName)
        return data_return(false, JSON.generate({error: "This stock doesn't exist!", errorWith: "stockName"}))
    end
    user = JSON.parse(File.read("ids/#{userId}"))
    #make sure the user has enough money
    #TODO: market listings, do those first. (aka /sellstock)
    #if (shareAmount * shareCost > user["money"])
    #    data_return(false, JSON.generate({error: "You don't have enough money to buy #{stockAmount} shares! (required: $#{stockAmount * shareCost})", errorWith: "stockAmount"}))
    #end
end

############################################################
# GET /stockinfo/<stock name>
# Gets information about a certain named stock
# GET params:
#   URL param: stockName
# Return value:
#   On success:
#       {
#           "result": true,
#           "data": {
#               <check json-structure-docs for stocks/ format>
#           }
#       }
#   On failure:
#       {
#           "result": false,
#           "data": {
#               "error": "<error message>",
#               "errorWith": "<param>"
#           }
#       }
############################################################
get "/stockinfo/*" do |stockName|
    stockName.upcase!
    if !check_if_stock_exists(stockName)
        return data_return(false, JSON.generate({error: "Invalid stock name!", errorWith: "stockName"}))
    else
        return data_return(true, File.read("stocks/#{stockName}"))
    end
end

get "/idinfo/*" do |id|
    if !check_login_validity(id)
        return data_return(false, JSON.generate({error: "Invalid user ID!", errorWith: "userId"}))
    else
        return data_return(true, File.read("ids/#{id}"))
    end
end

############################################################
# GET /liststocks
# Lists out the top n stocks by some criteria
# GET params:
#   criteria: How the stocks are sorted. Possible values:
#       criteria=top: The top n stocks by value
#       criteria=new: The newest n stocks
#   n: The amount of stocks to return. 1 <= n <= 100
# Return value:
#   [
#       <top stock (check json-structure-docs for stocks/ format)>,
#       <second stock (check json-structure-docs for stocks/ format)>,
#       ...
#   ]
# Important note: this will only return as many stocks as exist, no more.
# So, n may not always be exactly the amount returned.
############################################################
get "/liststocks" do
    # this has to slurp every stock in memory before running! this is bad!
    # TODO: load and keep stocks in memory before running this function
    return if !assert_params(params, "criteria", "n")
    criteria = params["criteria"]
    n = params["n"].to_i
    stocksList = []
    File.readlines("stock-list") do |stock|
        stocksList << JSON.parse(File.read("stocks/#{stock}"))
    end
    if n > stocksList.length
        n = stocksList.length
    end
    if criteria == "top"
        return stocksList.sort_by { |stock| stock["averageValue"] }[-n .. -1].reverse
    end
    if criteria == "new"
        return stocksList.sort_by { |stock| stock["time"] }[-n .. -1].reverse
    end
end
