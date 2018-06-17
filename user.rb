require "json"
require "securerandom"
require "set"

require_relative "stock_order.rb"

# https://github.com/Aearnus/stocks-2/blob/e4ae65a5240a7acf82a6181a4df1a02f5d3362ec/json-structure-docs#L8
class UserOwnedStocks < Hash
    def change_share_amount(name, shares)
        self[name] = shares
        if shares == 0
            self.delete name
        end
    end
    def modify_share_amount(name, shares)
        if self[name].nil?
            self[name] = shares
        else
            self[name] += shares
        end
        if self[name] == 0
            self.delete name
        end
    end
    def get_share_amount(name)
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
    def open_order(name, id)
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
        :money,
        # TODO: createdStocks interface that isn't just a list
        :createdStocks
    )

    attr_reader(
        :ownedStocks,
        :openOrders
    )

    def initialize(*args)
        if args.length == 0
            # Completely new user
            @id = "#{SecureRandom.uuid}#{SecureRandom.uuid}"
            @money = 100
            @createdStocks = []
            @ownedStocks = UserOwnedStocks.new
            @openOrders = UserOpenOrders.new
        else
            # Loaded user
            structure = JSON.parse(args[0])
            @id = structure["id"]
            @money = structure["money"]
            @createdStocks = structure["createdStocks"]
            @ownedStocks = UserOwnedStocks.new
            structure["ownedStocks"].each do |ownedStock|
                @ownedStocks.change_share_amount(ownedStock[0], ownedStock[1])
            end
            @openOrders = UserOpenOrders.new
            structure["openOrders"].each do |order|
                @openOrders.open_order(order["name"], order["uuid"])
            end
        end
    end

    def pickle
        %Q~
{
    "id": "#{@id}",
    "money": #{@money},
    "createdStocks": #{JSON.generate(@createdStocks)},
    "ownedStocks": #{JSON.generate(@ownedStocks)},
    "openOrders": #{JSON.generate(@openOrders)}
}
        ~.strip
    end
end
