require "json"
require "securerandom"
require "pp"

class Transaction
    BUY = :buy
    SELL = :sell
    DONE = :done
    attr_accessor(
        # Symbol (either :buy, :sell, or :done)
        :transaction,
        # Bignum (UNIX timestamp)
        :time,
        # Bignum
        :amount,
        # Bignum
        :amountDone,
        # Fixnum
        :value,
        # String
        :uuid,
        # String
        :userId
    )

    # Implicitly called by JSON.generate
    def to_h
        {
            transaction: @transaction,
            time: @time,
            amount: @amount,
            amountDone: @amountDone,
            value: @value,
            uuid: @uuid,
            userId: @userId
        }
    end

    def pickle
        JSON.generate(self.to_h)
    end


    def initialize(transaction, amount, value, userId)
        if !(transaction == :buy || transaction == :sell || transaction == :done)
            puts "Note: Transaction created with incorrect type."
            # TODO: Proper error handling
            exit
        end

        @transaction = transaction
        @time = Time.now.to_i
        @amount = amount
        @amountDone = 0
        @value = value
        @uuid = SecureRandom.uuid
        @userId = userId
    end
end

class Stock
    attr_accessor(
        # String
        :name,
        # String
        :desc,
        # Bignum (UNIX timestamp)
        :time,
        # Bignum
        :shares,
        # String (user ID)
        :createdBy,
        # [Transaction]
        :history
    )

    def to_sanitary_h
        {
            name: @name,
            desc: @desc,
            time: @time,
            shares: @shares,
            createdBy: "",
            history: @history.map{|t| t.to_h},
            averageValue: self.averageValue
        }
    end

    def to_h
        {
            name: @name,
            desc: @desc,
            time: @time,
            shares: @shares,
            createdBy: @createdBy,
            history: @history.map{|t| t.to_h},
            averageValue: self.averageValue
        }
    end

    def pickle
        JSON.generate(self.to_h)
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
    def sanitize
        deepCopy = Marshal.load(Marshal.dump(self))
        deepCopy.createdBy = ""
        deepCopy.history = ([] << deepCopy.history.select{|t| t.transaction == :buy}.sample(6) << deepCopy.history.select{|t| t.transaction == :sell}.sample(6) << deepCopy.history.select{|t| t.transaction == :done}.sort_by{|t| -t.time}[0..100].reverse).flatten
        deepCopy.history.map! do |t|
            t.userId = ""
        end
        return deepCopy
    end

    def sanitize!
        @createdBy = ""
        @history = ([] << @history.select{|t| t.transaction == :buy}.sample(6) << @history.select{|t| t.transaction == :sell}.sample(6) << @history.select{|t| t.transaction == :done}.sort_by{|t| -t.time}[0..100].reverse).flatten
        @history.map! do |t|
            t.userId = ""
        end
    end

    def sanitary_pickle
        historyCopy = Marshal.load(Marshal.dump(@history))
        historyCopy = ([] << historyCopy.select{|t| t.transaction == :buy}.sample(6) << historyCopy.select{|t| t.transaction == :sell}.sample(6) << historyCopy.select{|t| t.transaction == :done}.sort_by{|t| -t.time}[0..100].reverse).flatten
        historyCopy.map! do |t|
            t.userId = ""
            t
        end
        JSON.generate(self.to_sanitary_h.yield_self{ |h| h[:history] = historyCopy.map{ |t| t.to_h } })
    end

    def averageValue(transactions = 25)
        doneHistory = @history.select{|t| t.transaction == Transaction::DONE}
        transactions = doneHistory.length if transactions > doneHistory.length
        validTransactions = doneHistory[-transactions .. -1]
        totalValue = 0
        validTransactions.each do |t|
            totalValue += t.value
        end
        return totalValue / transactions
    end

    def new_transaction(type, amount, value, userId, time: nil, amountDone: nil, uuid: nil)
        @history << Transaction.new(type, amount, value, userId)
        if !time.nil?
            @history[-1].time = time
        end
        if !amountDone.nil?
            @history[-1].amountDone = amountDone
        end
        if !uuid.nil?
            @history[-1].uuid = uuid
        end
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
    def get_transaction(uuid)
        @history.each do |currentTransaction|
            if currentTransaction.uuid == uuid
                return currentTransaction
            end
        end
        return nil
    end

    def initialize(*args)
        if args.length == 1
            # Loaded user
            structure = JSON.parse(args[0])

            @name = structure["name"]
            @desc = structure["desc"]
            @time = structure["time"]
            @shares = structure["shares"]
            @createdBy = structure["createdBy"]
            @history = []
            structure["history"].each do |transaction|
                new_transaction(
                    transaction["transaction"].to_sym,
                    transaction["amount"],
                    transaction["value"],
                    transaction["userId"],
                    time: transaction["time"],
                    amountDone: transaction["amountDone"],
                    uuid: transaction["uuid"]
                )
            end
        elsif args.length == 4
            # New user
            name = args[0]
            desc = args[1]
            shares = args[2]
            createdBy = args[3]

            @name = name
            @desc = desc
            @time = Time.now.to_i
            @shares = shares
            @createdBy = createdBy
            @history = []
            new_transaction(Transaction::DONE, shares, 100, createdBy)
        else
            puts "Invalid arguments to init stock."
            exit
        end
    end
end
