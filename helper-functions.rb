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
