require "json"
require "securerandom"
require "set"

require_relative "stock_order.rb"

# https://github.com/Aearnus/stocks-2/blob/e4ae65a5240a7acf82a6181a4df1a02f5d3362ec/json-structure-docs#L8
class UserOwnedStocks < Hash
    def changeShareAmount(name, shares)
        self[name] = shares
        if shares == 0
            self.delete name
        end
    end
    def modifyShareAmount(name, shares)
        if self[name].nil?
            self[name] = shares
        else
            self[name] += shares
        end
        if self[name] == 0
            self.delete name
        end
    end
    def getShareAmount(name)
        out = self[name]
        if out.nil?
            0
        else
            out
        end
    end
end

# https://github.com/Aearnus/stocks-2/blob/e4ae65a5240a7acf82a6181a4df1a02f5d3362ec/json-structure-docs#L18
class UserOpenOrders < Array
    def openOrder(name, id)
        self << {"name" => name, "uuid" => id}
    end
end

# https://github.com/Aearnus/stocks-2/blob/e4ae65a5240a7acf82a6181a4df1a02f5d3362ec/json-structure-docs#L3
class User
    # These two are simple enough, they are single values
    attr_accessor(
        # String
        :id,
        # Rational
        :money
    )

    attr_reader(
        :createdStocks,
        :ownedStocks,
        :openOrders
    )

    # Completely new user
    def initialize
        @id = "#{SecureRandom.uuid}#{SecureRandom.uuid}"
        @money = 100
        @createdStocks = []
        @ownedStocks = UserOwnedStocks.new
        @openOrders = UserOpenOrders.new
    end

    # Loaded user
    def initialize(pickled)
        structure = JSON.parse(pickled)
        @id = structure["id"]
        @money = structure["money"]
        @ownedStocks = UserOwnedStocks.new
        structure["ownedStocks"].each do |ownedStock|
            @ownedStocks.modifyShareAmount(ownedStock[0], ownedStock[1]["shares"])
        end
        @openOrders = UserOpenOrders.new
        structure["openOrders"].each do |order|
            @openOrders.openOrder(order["name"], order["uuid"])
        end
    end

    def pickle
        %Q~
        {
            "id": #{@id},
            "money": #{@money},
            "createdStocks": #{JSON.generate(@createdStocks)},
            "ownedStocks": #{JSON.generate(@ownedStocks)},
            "openOrders": #{JSON.generate(@openOrders)}
        }
        ~
    end
end
