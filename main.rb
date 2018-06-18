#!/usr/bin/env ruby

require "sinatra"
require "fileutils"
require "securerandom"
require "json"
require "pp"

require_relative "helper-functions.rb"
require_relative "user.rb"
require_relative "stock.rb"

# Provide a `./main.rb clean` command to reset the directories
# USE WITH CAUTION
if ARGV[0] == "clean"
    def run(cmd)
        puts cmd
        puts `#{cmd}`
    end
    puts "Cleaning directory..."
    run "rm id-list"
    run "rm stock-list"
    run "rm -r ids/"
    run "rm -r stocks/"
    exit
end

set :bind, "0.0.0.0"
#set :port, 25565
set :public_folder, "public"

#set :server, 'webrick'

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
# Establish a list of people who are rate limited for new IDs
############################################################
$rateLimitedIPs = {}

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
    # If the IP has created an ID before...
    if $rateLimitedIPs.keys.include?(request.ip)
        # ... And it was within the past hour...
        timeSinceId = Time.now.to_i - $rateLimitedIPs[request.ip]
        if timeSinceId < 3600
            # ... then don't allow the ID to be created.
            # Note: I'm not bothering with formatting because the website
            # will handle it properly on its end.
            return "{\"id\":\"This IP address (#{request.ip}) created an ID #{timeSinceId} seconds ago. Please wait #{3600 - timeSinceId} seconds to create another.\"}"
        end
    end
    newUser = User.new
    # Write the ID to disk and to cache
    write_id(newUser, true)
    update_id_cache(newUser)

    # Apply rate limiting
    if !($rateLimitedIPs.keys.include? request.ip)
        $rateLimitedIPs[request.ip] = Time.now.to_i
    end

    return "{\"id\":\"#{newUser.id}\"}"
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
    #try converting to json if arguments aren't supplied
    if params["stockName"].nil?
        params = JSON.parse(request.body.read)
    end
    return if !assert_params(params, "stockName", "stockDesc", "stockAmount", "userId")
    shareCost = 100
    stockName = params["stockName"].upcase;
    stockDesc = params["stockDesc"];
    stockAmount = params["stockAmount"].to_i;
    userId = params["userId"];
    #make sure user exists
    if !check_login_validity(userId)
        return data_return(false, {error: "Invalid login token!", errorWith: "userId"})
    end
    #make sure stock doesn't already exist
    if check_if_stock_exists(stockName)
        return data_return(false, {error: "This stock already exists!", errorWith: "stockName"})
    end
    #make sure stock is only alphanumeric
    if stockName =~ /[^a-zA-Z0-9]/
        return data_return(false, {error: "The stock name contains invalid characters!", errorWith: "stockDesc"})
    end
    if stockDesc =~ /[^a-zA-Z0-9] /
        return data_return(false, {error: "The stock description contains invalid characters!", errorWith: "stockDesc"})
    end
    #make sure that name and description are okay length
    if (stockName.length > 10) || (stockName.length < 1)
        return data_return(false, {error: "Stock names have to be from 1 to 10 letters long!", errorWith: "stockName"})
    end
    if (stockDesc.length > 100) || (stockDesc.length < 4)
        return data_return(false, {error: "Stock descriptions have to be from 4 to 100 letters long!", errorWith: "stockDesc"})
    end
    #make sure they bought at least 200 shares for $100 each - the minimum
    if (stockAmount < 200)
        return data_return(false, {error: "You must buy at least 200 shares to create a stock!", errorWith: "stockAmount"})
    end

    user = $idCache[userId]
    #make sure the user has enough money
    if (stockAmount * shareCost > user.money)
        return data_return(false, {error: "You don't have enough money to buy #{stockAmount} shares! (required: $#{stockAmount * shareCost})", errorWith: "stockAmount"})
    end
    #finally, it's gucci - create the stock
    #first, take the money from the user
    user.money -= stockAmount * shareCost
    #then create the stock
    stock = Stock.new(stockName, stockDesc, stockAmount, userId)
    #write the stock to disk and to cache
    write_stock(stock, true)
    update_stock_cache(stock)
    #write the user's new stock portfolio, now containing this stock
    user.createdStocks << stockName
    user.ownedStocks.change_share_amount(stockName, stockAmount)
    write_id(user, false)
    update_id_cache(user)

    boolnum_return(true)
end

############################################################
# POST /sellstock
# Hook to post a sell order
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
    #try converting to json if arguments aren't supplied
    if params["stockName"].nil?
        params = JSON.parse(request.body.read)
    end
    pp params
    return if !assert_params(params, "stockName", "shareAmount", "sharePrice", "userId")
    stockName = params["stockName"].upcase;
    shareAmount = params["shareAmount"].to_i;
    sharePrice = params["sharePrice"].to_f;
    userId = params["userId"];
    #make sure user exists
    if !check_login_validity(userId)
        return data_return(false, {error: "Invalid login token!", errorWith: "userId"})
    end
    #make sure stock exists
    if !check_if_stock_exists(stockName)
        return data_return(false, {error: "This stock doesn't exist!", errorWith: "stockName"})
    end
    user = $idCache[userId]
    #make sure user has stock
    if user.ownedStocks.get_share_amount(stockName) == 0
        return data_return(false, {error: "This stock isn't in your portfolio!", errorWith: "stockName"})
    end
    #make sure user has enough of stock
    pp user.ownedStocks
    pp shareAmount
    if user.ownedStocks.get_share_amount(stockName) - shareAmount < 0
        return data_return(false, {error: "You don't have enough of #{stockName}!", errorWith: "shareAmount"})
    end
    #make sure they don't try to sell negative stocks
    if shareAmount <= 0
        return data_return(false, {error: "Invalid share amount!", errorWith: "shareAmount"})
    end
    #...for a negative price
    if sharePrice <= 0
        return data_return(false, {error: "Invalid share price!", errorWith: "sharePrice"})
    end

    #if all this is good, actually sell the stock!
    stock = $stockCache[stockName]
    #take the stock away from the user
    modify_user_stocks(user, stockName, -shareAmount)
    #add the transaction to the stock
    stock.new_transaction(Transaction::SELL, shareAmount, sharePrice, userId)
    #finally, apply the changes to cache and disk
    update_stock_cache(stock)
    update_id_cache(user)
    write_stock(stock, false)
    write_id(user, false)

    boolnum_return(true)
end

############################################################
# POST /buystock
# Hook to post a buy order
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
post "/buystock" do
    #try converting to json if arguments aren't supplied
    if params["stockName"].nil?
        params = JSON.parse(request.body.read)
    end
    return if !assert_params(params, "stockName", "shareAmount", "sharePrice", "userId")
    stockName = params["stockName"].upcase;
    shareAmount = params["shareAmount"].to_i;
    sharePrice = params["sharePrice"].to_f;
    userId = params["userId"];
    #make sure user exists
    if !check_login_validity(userId)
        return data_return(false, {error: "Invalid login token!", errorWith: "userId"})
    end
    #make sure stock exists
    if !check_if_stock_exists(stockName)
        return data_return(false, {error: "This stock doesn't exist!", errorWith: "stockName"})
    end
    user = $idCache[userId]
    #make sure user has enough money
    transactionPrice = shareAmount * sharePrice
    if user.money - transactionPrice < 0
        return data_return(false, {error: "You don't have enough money! You need $#{transactionPrice}.", errorWith: "stockAmount"})
    end
    #make sure they don't try to sell negative stocks
    if shareAmount <= 0
        return data_return(false, {error: "Invalid share amount!", errorWith: "shareAmount"})
    end
    #...for a negative price
    if sharePrice <= 0
        return data_return(false, {error: "Invalid share price!", errorWith: "sharePrice"})
    end

    #if all this is good, actually post the buy order!
    stock = $stockCache[stockName]
    #take the money away from the user
    user.money -= transactionPrice
    #add the transaction to the stock
    stock.new_transaction(Transaction::BUY, shareAmount, sharePrice, userId)
    #finally, apply the changes to cache and disk
    update_stock_cache(stock)
    update_id_cache(user)
    write_stock(stock, false)
    write_id(user, false)

    boolnum_return(true)
end

############################################################
# POST /fillorder
# Hook to fill a buy/sell order
# POST params:
#   stockName: the stock to buy
#   userId: the id of the user that wishes to buy a stock
#   transactionId: the uuid of the transaction
# Optional POST params:
#   amountToFill: the amount of the order to fill. if this
#       is not provided, fill the whole order
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
#
# Major thanks to
#   http://willschenk.com/receiving-posted-json-with-sinatra/
# for an idea to process both form encoded and JSON data
############################################################
post "/fillorder" do
    #try converting to json if arguments aren't supplied
    if params["stockName"].nil?
        params = JSON.parse(request.body.read)
    end
    return if !assert_params(params, "stockName", "userId", "transactionId")
    stockName = params["stockName"].upcase;
    userId = params["userId"];
    transactionId = params["transactionId"];
    amountToFill = params["amountToFill"].to_i;
    #make sure user exists
    if !check_login_validity(userId)
        return data_return(false, {error: "Invalid login token!", errorWith: "userId"})
    end
    #make sure stock exists
    if !check_if_stock_exists(stockName)
        return data_return(false, {error: "This stock doesn't exist!", errorWith: "stockName"})
    end
    stock = $stockCache[stockName]
    #make sure transaction exists, and if so, save it
    transaction = stock.get_transaction transactionId
    if transaction.nil?
        return data_return(false, {error: "This transaction does not exist!", errorWith: "transactionId"})
    end
    #make sure that the user requested a valid amount to fill, if they requested any at all
    if !amountToFill.nil?
        if amountToFill < 0 || amountToFill > (transaction.amount - transaction.amountDone)
            return data_return(false, {error: "Invalid amount of shares to fill an order!", errorWith: "amountToFill"})
        end
    end
    #or, if the transaction already went through
    if transaction.transaction == Transaction::DONE
        return data_return(false, {error: "This transaction no longer exists!", errorWith: "transactionId"})
    end
    # distinguish between the two types of transactions
    buyerUser = nil
    sellerUser = nil

    # very large if block incoming
    # we check if we're making a partial order or a full order
    
    # if we're making a full order, just mark the transaction as 
    # done and be done with it
    if !amountToFill.nil?
        #if a sell transaction was already posted (shares were moved from the seller)
        #what needs to be done:
        # money moved from the buyer (w/ check)
        # shares moved to the buyer
        # money moved to the seller
        if transaction.transaction == Transaction::SELL
            buyerUser = $idCache[userId]
            sellerUser = $idCache[transaction.userId]
            pp transaction
            pp sellerUser
            pp buyerUser
            #make sure the buyer has enough money
            transactionCost = transaction.amount * transaction.value
            puts "TRANSACTION COST: #{transactionCost}, BUYER MONEY: #{buyerUser.money}"
            if (transactionCost > buyerUser.money)
                puts "RETURNING FALSE"
                return data_return(false, {error: "You don't have enough money to buy #{transaction.amount} shares! (required: $#{transactionCost})", errorWith: "stockAmount"})
            end

            #then move the money out of the buyer's and into the seller's account
            sellerUser.money += transactionCost
            buyerUser.money -= transactionCost
            #move the stocks into the buyer's account
            #/sellstock alredy moved them out of the seller's account
            buyerUser = modify_user_stocks(buyerUser, stockName, transaction.amount)

        #if a buy transaction was already posted (money was moved from the buyer)
        #what needs to be done:
        # shares moved from the seller (w/ check)
        # money moved to the seller
        # shares moved to the buyer
        elsif transaction.transaction == Transaction::BUY
            buyerUser = $idCache[transaction.userId]
            sellerUser = $idCache[userId]
            #make sure the seller has enough shares to fill the buy order
            if (transaction.amount > sellerUser.ownedStocks[stockName])
                return data_return(false, {error: "You don't have enough shares to sell #{transaction.amount} shares!", errorWith: "stockAmount"})
            end

            #then move the money into the seller's account
            #/buystock already moved money out of the buyer's account
            sellerUser.money += transaction.amount * transaction.value
            #move the shares into the buyer's account and out of the seller's account
            buyerUser = modify_user_stocks(buyerUser, stockName, transaction.amount)
            sellerUser = modify_user_stocks(sellerUser, stockName, -transaction.amount)
        end
        #everything is good, let's commit the transaction
        transaction.transaction = Transaction::DONE
    else
        # if we're not making a full order, then we're gonna do some extra business
        # we do the whole process, but we only mark the transaction as done
        # if the amountDone == amount
        # note: we already did bounds checking on amountToFill
        if transaction.transaction == Transaction::SELL
            buyerUser = $idCache[userId]
            sellerUser = $idCache[transaction.userId]
            pp transaction
            pp sellerUser
            pp buyerUser
            
            transactionCost = amountToFill * transaction.value
            puts "TRANSACTION COST: #{transactionCost}, BUYER MONEY: #{buyerUser.money}"
            if (transactionCost > buyerUser.money)
                puts "RETURNING FALSE"
                return data_return(false, {error: "You don't have enough money to buy #{transaction.amount} shares! (required: $#{transactionCost})", errorWith: "stockAmount"})
            end

            sellerUser.money += transactionCost
            buyerUser.money -= transactionCost
            buyerUser = modify_user_stocks(buyerUser, stockName, amountToFill)
            # the only thing we do different: 
            # we increase the amountDone and check that later, instead of immediately marking it as done
            transaction.amountDone += amountToFill
        elsif transaction.transaction == Transaction::BUY
            buyerUser = $idCache[transaction.userId]
            sellerUser = $idCache[userId]
            if (amountToFill > sellerUser.ownedStocks[stockName])
                return data_return(false, {error: "You don't have enough shares to sell #{transaction.amount} shares!", errorWith: "stockAmount"})
            end
            sellerUser.money += amountToFill * transaction.value
            buyerUser = modify_user_stocks(buyerUser, stockName, amountToFill)
            sellerUser = modify_user_stocks(sellerUser, stockName, -amountToFill)
            
            transaction.amountDone += amountToFill
        end
        # check the transaction status and (maybe) commit it
        transaction.transaction = Transaction::DONE if transaction.amount >= transaction.amountDone
    end

    #touch the time
    transaction.time = Time.now.to_i

    #finally, update the caches and write to disk
    #this happens regardless of who buys and who sells
    update_stock_cache(stock)
    update_id_cache(buyerUser)
    update_id_cache(sellerUser)
    write_stock(stock, false)
    write_id(buyerUser, false)
    write_id(sellerUser, false)

    boolnum_return(true)
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
#       Redirect to stock-fail.erb
############################################################
get "/stock/*" do |stockName|
    if check_if_stock_exists(stockName)
        erb :stock, :locals => {:stockObject => $stockCache[stockName]}
    else
        erb :'stock-fail', :locals => {:stockName => stockName}
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
        return data_return(false, {error: "Invalid stock name!", errorWith: "stockName"})
    else
        return data_return(true, $stockCache[stockName].to_sanitary_h)
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
        return data_return(false, {error: "Invalid user ID!", errorWith: "userId"})
    else
        return data_return(true, sanitize_user($idCache[id]).to_h)
    end
end

############################################################
# GET /liststocks
# Lists out the top n stocks by some criteria
# GET params:
#   criteria: How the stocks are sorted. Possible values:
#       criteria=top: The top n stocks by value
#       criteria=new: The newest n stocks
#       criteria=random: A random selection of n stocks
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
        return data_return(true, $stockCache.values.sort_by { |stock| stock.averageValue }[-n .. -1].reverse.map{|stock| stock.to_sanitary_h})
    elsif criteria == "new"
        return data_return(true, $stockCache.values.sort_by { |stock| stock.time }[-n .. -1].reverse.map{|stock| stock.to_sanitary_h})
    elsif criteria == "random"
        return data_return(true, $stockCache.values.sample(n).map{|stock| stock.to_sanitary_h})
    else
        return data_return(false, {error: "Unknown criteria: #{criteria}", errorWith: "criteria"})
    end
end
