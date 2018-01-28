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
assert_file "id-list"
assert_file "stock-list"

############################################################
# Make sure to load the stock list and ID list into RAM so we don't
# have to do a lot of disk I/O to search through it
############################################################
$stockCache = {}
load_stock_cache()
$idCache = {}
load_id_cache()

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
        "id" => "#{userId}",
        "money" => 100,
        "createdStocks" => [],
        "ownedStocks" => []
    }
    # Write the ID to disk and to cache
    write_id(defaultIdStats, true)
    update_id_cache(defaultIdStats)

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
    return if !assert_params(params, "userId")
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
    return if !assert_params(params, "userId")
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

    user = $idCache[userId]
    #make sure the user has enough money
    if (stockAmount * shareCost > user["money"])
        return data_return(false, JSON.generate({error: "You don't have enough money to buy #{stockAmount} shares! (required: $#{stockAmount * shareCost})", errorWith: "stockAmount"}))
    end
    #finally, it's gucci - create the stock
    #first, take the money from the user
    user["money"] -= stockAmount * shareCost
    #then create the stock
    defaultStock = {
        "name" => stockName,
        "desc" => stockDesc,
        "time" => Time.now.to_i,
        "shares" => stockAmount,
        "createdBy" => userId,
        "history" => [
            {
                "transaction" => "buy",
                "time" => Time.now.to_i,
                "amount" => stockAmount,
                "value" => shareCost,
                "uuid" => SecureRandom.uuid,
                "userId" => userId
            }
        ],
        "averageValue" => shareCost
    }
    #write the stock to disk and to cache
    write_stock(defaultStock, true)
    update_stock_cache(defaultStock)
    #write the user's new stock portfolio, now containing this stock
    user["createdStocks"] << stockName
    user["ownedStocks"] << {name: stockName, shares: stockAmount}
    write_id(user, false)
    update_id_cache(user)

    boolnum_return(true)
end

############################################################
# POST /sellstock
# Hook to sell a stock
# POST params:
#   stockName: the stock to buy
#   shareAmount: the amount of shares to sell
#   sharePrice: what price to sell each share at
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
post "/sellstock" do
    return if !assert_params(params, "stockName", "shareAmount", "sharePrice", "userId", "transactionId")
    stockName = params["stockName"].upcase;
    shareAmount = params["shareAmount"].to_i;
    sharePrice = params["sharePrice"].to_i;
    userId = params["userId"];
    #make sure user exists
    if !check_login_validity(userId)
        return data_return(false, JSON.generate({error: "Invalid login token!", errorWith: "userId"}))
    end
    #make sure stock exists
    if !check_if_stock_exists(stockName)
        return data_return(false, JSON.generate({error: "This stock doesn't exist!", errorWith: "stockName"}))
    end
    user = $idCache[userId]
    #make sure user has stock
    if user["ownedStocks"][stockName].nil?
        return data_return(false, JSON.generate({error: "This stock isn't in your portfolio!", errorWith: "stockName"}))
    end
    #make sure user has enough of stock
    if user["ownedStocks"][stockName]["shares"] - shareAmount < 0
        return data_return(false, JSON.generate({error: "You don't have enough of #{stockName}!", errorWith: "stockAmount"}))
    end

    #if all this is good, actually sell the stock!
    stock = $stockCache[stockName]
    #take the stock away from the user
    user = modify_user_stocks(user, stockName, -shareAmount)
    #add the transaction to the stock
    stock["history"] << {
        "transaction" => "sell",
        "time" => Time.now.to_i,
        "amount" => shareAmount,
        "value" => sharePrice,
        "uuid" => SecureRandom.uuid,
        "userId" => userId
    }
    #finally, apply the changes to cache and disk
    update_stock_cache(stock)
    update_id_cache(user)
    write_stock(stock)
    write_id(user)
end

############################################################
# POST /buystock
# Hook to buy a stock
# POST params:
#   stockName: the stock to buy
#   stockAmount: the amount of stocks to buy
#   userId: the id of the user that wishes to buy a stock
#   transactionId: the uuid of the transaction
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
    return if !assert_params(params, "stockName", "stockAmount", "userId", "transactionId")
    stockName = params["stockName"].upcase;
    shareAmount = params["stockAmount"].to_i;
    userId = params["userId"];
    transactionId = params["transactionId"];
    #make sure user exists
    if !check_login_validity(userId)
        return data_return(false, JSON.generate({error: "Invalid login token!", errorWith: "userId"}))
    end
    #make sure stock exists
    if !check_if_stock_exists(stockName)
        return data_return(false, JSON.generate({error: "This stock doesn't exist!", errorWith: "stockName"}))
    end
    stock = $stockCache[stockName]
    #make sure transaction exists, and if so, save it
    transaction = {}
    transactionIndex = 0
    stock["history"].each_with_index do |currentTransaction, i|
        if currentTransaction["uuid"] == transactionId
            transaction = currentTransaction
            transactionIndex = i
            break
        end
    end
    #if the transaction didn't exist
    if transaction == {}
        return data_return(false, JSON.generate({error: "This transaction does not or no longer exists!", errorWith: "transactionId"}))
    end
    #if the transaction is of the wrong type
    if transaction["transaction"] != "sell"
        return data_return(false, JSON.generate({error: "This transaction has an invalid type!", errorWith: "transaction"}))
    end

    buyerUser = $idCache[userId]
    sellerUser = $idCache[stock["createdBy"]]
    #make sure the user has enough money
    transactionCost = transaction["amount"] * transaction["value"]
    if (transactionCost > user["money"])
        data_return(false, JSON.generate({error: "You don't have enough money to buy #{stockAmount} shares! (required: $#{stockAmount * shareCost})", errorWith: "stockAmount"}))
    end

    #everything is good, let's commit the transaction
    #first, change the "sell" to "buy"
    stock["history"][transactionIndex]["transaction"] = "buy"
    #then move the money out of the buyer's and into the seller's account
    sellerUser["money"] += transactionCost
    buyerUser["money"] -= transactionCost
    #move the stocks into the buyer's account and out of the seller's account
    buyerUser = modify_user_stocks(buyerUser, stockName, transaction["amount"])
    sellerUser = modify_user_stocks(sellerUser, stockName, transaction["amount"])
    #finally, update the caches and write to disk
    update_stock_cache(stock)
    update_id_cache(buyerUser)
    update_id_cache(sellerUser)
    write_stock(stock)
    write_id(buyerUser)
    write_id(sellerUser)
end

############################################################
# GET /stock/<stock name>
# Renders a webpage with info about the stock
# GET params:
#   URL param: stockName
# Return value:
#   On existing stock:
#       Redirect to stock.erb
#   On nonexistant stock:
#       Redirect to stock-fail.html
############################################################
get "/stock/*" do |stockName|
    if check_if_stock_exists(stockName)
        erb :stock
    else
        redirect "/stock-fail.html"
    end
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
        return data_return(true, sanitize_stock($stockCache[stockName]))
    end
end

############################################################
# GET /idinfo/<stock name>
# Gets information about a certain user
# GET params:
#   URL param: user ID
# Return value:
#   On success:
#       {
#           "result": true,
#           "data": {
#               <check json-structure-docs for ids/ format>
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
get "/idinfo/*" do |id|
    if !check_login_validity(id)
        return data_return(false, JSON.generate({error: "Invalid user ID!", errorWith: "userId"}))
    else
        return data_return(true, JSON.generate($idCache[id]))
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
#   On success:
#       {
#           "result": true,
#           "data": [
#               <top stock (check json-structure-docs for stocks/ format)>,
#               <second stock (check json-structure-docs for stocks/ format)>,
#               ...
#           ]
#       }
#   On failure:
#       {
#           "result": false,
#           "data": {
#               "error": "<error message>",
#               "errorWith": "<param>"
#           }
#       }
# Important note: this will only return as many stocks as exist, no more.
# So, n may not always be exactly the amount returned.
############################################################
get "/liststocks" do
    return if !assert_params(params, "criteria", "n")
    criteria = params["criteria"].chomp
    n = params["n"].to_i

    if n > $stockCache.length
        n = $stockCache.length
    end
    if criteria == "top"
        return data_return(true, $stockCache.values.sort_by { |stock| stock["averageValue"] }[-n .. -1].reverse.map{|stock| sanitize_stock(stock)})
    elsif criteria == "new"
        return data_return(true, $stockCache.values.sort_by { |stock| stock["time"] }[-n .. -1].reverse.map{|stock| sanitize_stock(stock)})
    else
        return data_return(false, JSON.generate({error: "Unknown criteria: #{criteria}", errorWith: "criteria"}))
    end
end
