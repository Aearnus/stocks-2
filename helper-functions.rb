require 'fileutils'

require_relative "user.rb"

############################################################
# File assertion functions
############################################################
def assert_dir(dirName)
    if !File.directory?(dirName)
    	Dir.mkdir(dirName)
    end
end
def assert_file(fileName)
    if !File.exist?(fileName)
    	FileUtils.touch(fileName)
    end
end

def assert_params(params, *neededParams)
    neededParams.each do |param|
        if params[param].nil?
            puts "Dropped a request because the parameter `#{param}` was nil."
            return false
        end
    end
    return true
end

############################################################
# HTML/JSON return functions
############################################################
def string_return(res)
    "{\"result\": \"#{res}\"}"
end
def boolnum_return(res)
    "{\"result\": #{res}}"
end
def data_return(res, data)
    "{\"result\": #{res}, \"data\": #{JSON.generate(data)}}"
end

############################################################
# Cache loading functions
# NOTE: do not run these functions unless $stockCache and
# $idCache have been defined
############################################################
def load_stock_cache
    $stockCache = {}
    File.foreach("stock-list") do |stock|
        stock.chomp!
        next if stock.empty?
        stockObject = JSON.parse(File.read("stocks/#{stock.chomp}"))
        stockObject["averageValue"] = stockObject["averageValue"].to_f
        stockObject["history"].each do |transaction|
            transaction["value"] = transaction["value"].to_f
        end
        $stockCache[stock] = stockObject
    end
end
def update_stock_cache(stockObject)
    $stockCache[stockObject["name"]] = stockObject
end

def load_id_cache
    $idCache = {}
    File.foreach("id-list") do |id|
        id.chomp!
        next if id.empty?
        idObject = User.new(File.read("ids/#{id.chomp}"))
        #idObject.money = idObject["money"].to_r.round(2)
        $idCache[id] = idObject
    end
end
def update_id_cache(idObject)
    $idCache[idObject.id] = idObject
end

############################################################
# Disk IO functions
############################################################
def write_stock(stock, writeStockList)
    if writeStockList
        File.open("stock-list", "a") do |f|
            f.puts "#{stock["name"]}"
        end
    end
    File.open("stocks/#{stock["name"]}", "w") do |f|
        f.write JSON.generate(stock)
    end
end
def write_id(user, writeIdList)
    if writeIdList
        File.open("id-list", "a") do |f|
            f.puts "#{user.id}"
        end
    end
    File.open("ids/#{user.id}", "w") do |f|
        f.write user.pickle
    end
end

############################################################
# check_login_validity(uuid)
# Arguments:
#   uuid (string): the user ID to check
# Return value:
#   true/false
############################################################
def check_login_validity(uuid)
    puts "TESTING UUID #{uuid}"
    # Allow single or double strength IDs
    if (uuid.length != 36) && (uuid.length != 72)
        return false
    end
    if ($idCache.keys.include? uuid)
        puts "UUID GOOD"
        return true
    end
    puts "UUID BAD"
    return false
end

############################################################
# check_if_stock_exists(stock)
# Arguments:
#   stock (string): which stock to check for
# Return value:
#   true/false
############################################################
def check_if_stock_exists(stock)
    puts "TESTING STOCK #{stock}"
    if stock.length > 10
        return false
    end
    if ($stockCache.keys.include? stock)
        puts "STOCK EXISTS"
        return true
    end
    puts "STOCK DOESN'T EXIST"
    return false
end

############################################################
# get_transaction(stockName, uuid)
# Arguments:
#   stockName: the name of the stock to get the transaction of
#   uuid: the uuid of the desired transaction
# Return value:
#   On success:
#       {Transaction object}
#   On failure:
#       nil
############################################################
def get_transaction(stockName, uuid)
    $stockCache[stockName]["history"].each do |currentTransaction|
        if currentTransaction["uuid"] == uuid
            return currentTransaction
        end
    end
    return nil
end

############################################################
# get_stock_value(stockObject, transactions)
# Arguments:
#   stockObject (object, parsed from stock json): stock to find the average value of
#   transactions (integer): how many of the most recent transactions to average
# Return value:
#   Number -- the average value of the stock
############################################################
def get_stock_value(stockIn, transactions=25)
    history = stockIn["history"].select{|t| t["transaction"] == "done"}
    if transactions > history.length
        transactions = history.length
    end
    validTransactions = history[-transactions .. -1]
    totalValue = 0
    validTransactions.each do |t|
        totalValue += t["value"]
    end
    return totalValue / transactions
end

############################################################
# sanitize_stock(stock)
# Removes sensitive information from the stock object
# Also, convert the values to their proper return values
# Also, only take 6 of the stock transactions at random -- but keep all the "done"s
# Also, drop all but the 100 newest done transactions
# Arguments:
#   stock: the stock object to sanitize
# Return value:
#   A stock object, minus transaction userId, or stock createdBy
############################################################
def sanitize_stock(stock)
    #deep copy the object
    out = Marshal.load(Marshal.dump(stock))
    out["createdBy"] = ""
    buys = out["history"].select{|t| t["transaction"] == "buy"}.sample(6)
    sells = out["history"].select{|t| t["transaction"] == "sell"}.sample(6)
    dones = out["history"].select{|t| t["transaction"] == "done"}
    dones = dones.sort_by{|t| -t["time"]}[0..100].reverse
    out["history"] = ([] << buys << sells << dones).flatten
    out["history"].each_with_index do |_, index|
        out["history"][index]["userId"] = ""
    end
    out["averageValue"] = out["averageValue"].to_f
    out["history"].each do |transaction|
        transaction["value"] = transaction["value"].to_f
    end
    return out
end

############################################################
# sanitize_user(user)
# Convert the values to their proper return values (rational -> float)
# Arguments:
#   user: the user object to sanitize
# Return value:
#   A user object, with "money" changed
############################################################
def sanitize_user(user)
    out = Marshal.load(Marshal.dump(user))
    return out
end

############################################################
# modify_user_stocks(user, stockName, stockChange)
# Arguments:
#   user (user object): the user to be modified
#   stockName (string): the stock which will be added/removed from the user
#   stockChange (number): the amount to change the stock
# Return value:
#   user object on success
#   unchanged user object on failure
############################################################
def modify_user_stocks(user, stockName, stockChange)
    puts "MODIFY_USER_STOCKS"
    pp user
    originalUser = user
    #if they don't already own any of this stock and it would cause it to go negative
    if (user.ownedStocks.getShareAmount(stockName) <= 0) && (stockChange < 0)
        return originalUser
    end
    #if it's good, go ahead and do it
    user.ownedStocks.modifyShareAmount(stockName, stockChange)

    return user
end
