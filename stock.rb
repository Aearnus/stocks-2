module Transaction
    BUY = :buy
    SELL = :sell
    DONE = :done
end
class Transaction
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

    def averageValue
        # TODO
        return 0
    end
end
