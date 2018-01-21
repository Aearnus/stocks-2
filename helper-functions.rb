require 'fileutils'

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
    # TODO: USE THE CACHE
    File.foreach("id-list") do |fileUuid|
        if uuid == fileUuid.chomp
            puts "UUID GOOD"
            return true
        end
    end
    puts "UUID BAD"
    return false
end

############################################################
# Cache loading functions
# NOTE: do not run these functions unless $stockCache and
# $idCache have been defined
############################################################
def load_stock_cache
    $stockCache = {}
    File.foreach("stock-list") do |stock|
        $stockCache[stock] = JSON.parse(File.read("stocks/#{stock.chomp}"))
    end
end
def update_stock_cache(stockObject)
    $stockCache[stockObject["name"]] = stockObject
end

def load_id_cache
    $idCache = {}
    File.foreach("id-list") do |id|
        $idCache[id] = JSON.parse(File.read("ids/#{id.chomp}"))
    end
end
def update_id_cache(idObject)
    $idCache[idObject["id"]] = idObject
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
    File.foreach("stock-list") do |fileStock|
        if stock == fileStock.chomp
            puts "STOCK EXISTS"
            return true
        end
    end
    puts "STOCK DOESN'T EXIST"
    return false
end

############################################################
# get_stock_value(stockObject, transactions)
# Arguments:
#   stockObject (object, parsed from stock json): stock to find the average value of
#   transactions (integer): how many of the most recent transactions to average
# Return value:
#   Number -- the average value of the stock
############################################################
def get_stock_value(stockObject, transactions)
    if transactions > stockObject["history"].length
        transactions = stockObject["history"].length
    end
    validTransactions = stockObject["history"][-transactions .. -1]
    totalValue = 0
    validTransactions.each do |t|
        totalValue += t["value"]
    end
    return totalValue / transactions
end

############################################################
# sanitize_stock(stock)
# Removes sensitive information from the stock object
# Arguments:
#   stock: the stock object to sanitize
# Return value:
#   A stock object, minus transaction userId, or stock createdBy
############################################################
def sanitize_stock(stock)
    stock["createdBy"] = ""
    stock["history"].each_with_index do |_, index|
        stock["history"][index]["userId"] = ""
    end
    return stock
end
